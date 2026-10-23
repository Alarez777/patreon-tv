//
//  AppCache.swift
//  PatreonTV
//
//  Accounting and clearing for everything the app caches on-device: the HTTP
//  cache, Nuke's image cache, the in-memory content caches and the Top Shelf
//  snapshot shared with the extension.
//
//  User data (playback progress, Continue Collection, preferences) is NOT
//  part of this: it survives a cache clear and a sign-out unless the caller
//  explicitly wipes it.
//

import Foundation
import Nuke

enum AppCache {

    /// Bytes currently held by the caches this screen can free.
    ///
    /// The app's `Caches` directory already contains the HTTP cache's on-disk
    /// store (and Nuke's, if one is ever configured), so only the in-memory
    /// layers are added on top. The in-memory content caches hold models, not
    /// bytes, so they are cleared but not measured.
    static func size() async -> Int {
        await Task.detached(priority: .utility) {
            var total = directorySize(
                at: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            )
            total += directorySize(at: AppGroup.sharedCachesURL)
            total += URLCache.shared.currentMemoryUsage
            total += ImageCache.shared.totalCost
            return total
        }.value
    }

    /// Clears every cache layer and returns how many bytes were held before.
    @MainActor
    @discardableResult
    static func clear() async -> Int {
        let before = await size()

        URLCache.shared.removeAllCachedResponses()
        ImagePipeline.shared.cache.removeAll()
        CollectionsCache.shared.clear()
        CollectionPostsCache.shared.clear()
        TopShelfSnapshot.delete()

        return before
    }

    private static func directorySize(at url: URL?) -> Int {
        guard let url else { return 0 }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            total += values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0
        }
        return total
    }
}
