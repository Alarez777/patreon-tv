//
//  PatreonAssetResourceLoader.swift
//  PatreonTV
//
//  Injects the Patreon `session_id` cookie into first-party playback requests.
//
//  Why this exists: some `video_external_file` posts (notably ones with a
//  preview) serve the *full* video through
//    https://www.patreon.com/api/video/<id>/manifest.m3u8
//  which authorises the request with the `session_id` cookie instead of a
//  signed token. A plain AVURLAsset gets 403 on it because the player sends no
//  cookie. We can't just put the cookie in `AVURLAssetHTTPHeaderFieldsKey`:
//  those headers go to *every* request the asset makes — including the
//  `*.mux.com` segments — which would leak the session to a third-party CDN.
//
//  Instead this loader handles only `patreon.com` / `*.patreon.com` requests
//  and lets AVFoundation load every other host directly, cookie-free. That
//  mirrors how a browser scopes cookies: it sends `.patreon.com` cookies to
//  patreon.com and never to the Mux edge.
//

import AVFoundation
import Foundation

final class PatreonAssetResourceLoader: NSObject, @unchecked Sendable,
                                        AVAssetResourceLoaderDelegate,
                                        URLSessionDataDelegate {

    private let sessionID: String
    private let headers: [String: String]

    /// Guards the state below. The resource-loader delegate and the URLSession
    /// delegate run on different queues, so all access is locked.
    private let lock = NSLock()
    private var session: URLSession?
    private var requests: [Int: AVAssetResourceLoadingRequest] = [:]
    private var tasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private var buffers: [Int: Data] = [:]

    init(sessionID: String, headers: [String: String] = [:]) {
        self.sessionID = sessionID
        self.headers = headers
        super.init()
    }

    /// True for `patreon.com` and any subdomain. Deliberately excludes
    /// `patreonusercontent.com` (a CDN that uses its own signed tokens) and
    /// anything that merely contains the string.
    static func isPatreonHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "patreon.com" || host.hasSuffix(".patreon.com")
    }

    /// Drops the `Cookie` header when a redirect leaves the Patreon origin, so
    /// the session can never follow the asset to a third-party host.
    static func strippingCookieIfNeeded(from request: URLRequest) -> URLRequest {
        guard !isPatreonHost(request.url?.host) else { return request }
        var request = request
        request.setValue(nil, forHTTPHeaderField: "Cookie")
        return request
    }

    /// Breaks the URLSession → delegate retain cycle. Call when the asset is
    /// torn down.
    func invalidate() {
        lock.lock()
        let session = self.session
        self.session = nil
        lock.unlock()
        session?.invalidateAndCancel()
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url, Self.isPatreonHost(url.host) else {
            // Not ours: let AVFoundation fetch it directly (no cookie).
            return false
        }

        var request = loadingRequest.request
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("session_id=\(sessionID)", forHTTPHeaderField: "Cookie")

        lock.lock()
        let session = self.session ?? makeSession()
        self.session = session
        let task = session.dataTask(with: request)
        requests[task.taskIdentifier] = loadingRequest
        tasks[ObjectIdentifier(loadingRequest)] = task
        buffers[task.taskIdentifier] = Data()
        lock.unlock()

        task.resume()
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        lock.lock()
        let task = tasks.removeValue(forKey: ObjectIdentifier(loadingRequest))
        if let task {
            requests[task.taskIdentifier] = nil
            buffers[task.taskIdentifier] = nil
        }
        lock.unlock()
        task?.cancel()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.lock()
        let loadingRequest = requests[dataTask.taskIdentifier]
        lock.unlock()

        if let loadingRequest,
           let http = response as? HTTPURLResponse,
           (200...299).contains(http.statusCode),
           let info = loadingRequest.contentInformationRequest {
            // Force the HLS MIME type: AVFoundation only parses the manifest we
            // hand back if the content type says so (the server's may vary).
            let ext = loadingRequest.request.url?.pathExtension.lowercased()
            info.contentType = (ext == "m3u8" || ext == "m3u")
                ? "application/vnd.apple.mpegurl"
                : http.mimeType
            info.isByteRangeAccessSupported = true
            if http.expectedContentLength > 0 {
                info.contentLength = http.expectedContentLength
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        buffers[dataTask.taskIdentifier, default: Data()].append(data)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let loadingRequest = requests.removeValue(forKey: task.taskIdentifier)
        let data = buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
        if let loadingRequest {
            tasks[ObjectIdentifier(loadingRequest)] = nil
        }
        lock.unlock()

        guard let loadingRequest else { return }

        if let error {
            loadingRequest.finishLoading(with: error)
            return
        }
        if let http = task.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let error = NSError(
                domain: "PatreonTV.Playback",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
            loadingRequest.finishLoading(with: error)
            return
        }
        respond(to: loadingRequest, with: data)
        loadingRequest.finishLoading()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(Self.strippingCookieIfNeeded(from: request))
    }

    // MARK: - Helpers

    /// Ephemeral, no cookie storage: the only cookie ever sent is the one we add
    /// explicitly for patreon.com hosts.
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Feeds the (whole) resource to the loading request, honouring the byte
    /// range AVFoundation asks for. Manifests are small; the same fetch serves
    /// any subsequent range request.
    private func respond(to loadingRequest: AVAssetResourceLoadingRequest, with data: Data) {
        guard let dataRequest = loadingRequest.dataRequest else { return }
        let offset = Int(dataRequest.currentOffset)
        guard offset >= 0, offset < data.count else { return }
        let length = dataRequest.requestsAllDataToEndOfResource
            ? data.count - offset
            : min(dataRequest.requestedLength, data.count - offset)
        guard length > 0 else { return }
        dataRequest.respond(with: data.subdata(in: offset..<(offset + length)))
    }
}
