//
//  AuthStore.swift
//  PatreonTV
//
//  Owns the current session state and the persisted session_id cookie.
//  Uses Keychain for storage.
//
//  See docs/patreon-research.md §14 for why we use the session_id cookie
//  rather than OAuth Bearer: OAuth cannot unlock paid content
//  (current_user_can_view returns false for a paying patron via OAuth).
//  Only a real logged-in web session grants entitlement.
//

import Foundation
import Observation
import os.log

@Observable
@MainActor
final class AuthStore {

    enum State: Equatable {
        case unknown
        case signedOut
        /// The stored session was definitively rejected mid-use (401/403).
        /// Distinct from .signedOut so the sign-in screen can explain why.
        case sessionExpired
        case signedIn(userID: String)
    }

    private(set) var state: State = .unknown
    private(set) var currentUser: PatreonUser?

    static let keychainService = "com.patreontv.PatreonTV"
    static let sessionKey = "patreon_session_id"
    static let userIDKey = "patreon_user_id"

    private let storage: any SessionStorage
    private let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "Auth")
    private var isVerifyingAuthFailure = false

    init(storage: any SessionStorage = KeychainService(service: AuthStore.keychainService)) {
        self.storage = storage
        // Any 401 from the API layer triggers a re-verification; if the
        // session really is dead we surface the re-pair screen instead of
        // leaving each content screen showing a generic error.
        PatreonClient.shared.authFailureHandler = { [weak self] in
            guard let self else { return }
            Task { await self.handleAuthFailure() }
        }
    }

    /// Called from `.task` on app launch. Reads the stored session_id and
    /// verifies it against `/api/current_user`. If valid, transitions to
    /// .signedIn; otherwise .signedOut.
    ///
    /// Only a definitive rejection (401/403) clears the stored credential.
    /// Transient failures — no network, Patreon outage, rate limiting — keep
    /// the session and enter .signedIn optimistically so an offline launch
    /// doesn't force the user to re-pair.
    func restoreSession() async {
        guard let sessionID = storage.string(forKey: Self.sessionKey), !sessionID.isEmpty else {
            log.info("No stored session")
            state = .signedOut
            return
        }

        // Configure the shared API client with the cookie, then verify.
        PatreonClient.shared.sessionID = sessionID
        do {
            let user = try await PatreonClient.shared.currentUser()
            currentUser = user
            state = .signedIn(userID: user.id)
            log.info("Restored session for user \(user.id)")
        } catch {
            log.error("Session restore failed: \(String(describing: error))")
            if Self.shouldClearSession(after: error) {
                // Patreon definitively rejected the session — clear and re-auth.
                await expireSession()
            } else if let storedUserID = storage.string(forKey: Self.userIDKey), !storedUserID.isEmpty {
                // Transient error — keep the credential and proceed. Content
                // screens show their own retryable errors while offline.
                state = .signedIn(userID: storedUserID)
                log.info("Proceeding with stored session despite transient error")
            } else {
                // No cached user id to proceed with; keep the credential in the
                // keychain (a later launch or re-pair will overwrite it).
                state = .signedOut
            }
        }
    }

    /// True only for errors that mean Patreon rejected the credential itself.
    /// Everything else (network failures, 5xx, rate limits, decode errors) is
    /// treated as transient and must NOT destroy the stored session.
    nonisolated static func shouldClearSession(after error: Error) -> Bool {
        switch error {
        case PatreonError.unauthorized, PatreonError.forbidden:
            return true
        default:
            return false
        }
    }

    /// Called by SignInView after the user submits a session_id cookie.
    /// Validates before persisting so an invalid ID never lands in the Keychain.
    func completeSignIn(sessionID: String) async throws {
        let trimmed = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SignInError.invalidSession }

        PatreonClient.shared.sessionID = trimmed

        do {
            let user = try await PatreonClient.shared.currentUser()
            if !storage.set(trimmed, forKey: Self.sessionKey) {
                log.error("Could not persist session to keychain; sign-in will not survive relaunch")
            }
            _ = storage.set(user.id, forKey: Self.userIDKey)
            currentUser = user
            state = .signedIn(userID: user.id)
            log.info("Sign-in complete for user \(user.id)")
        } catch {
            log.error("Sign-in verification failed: \(String(describing: error))")
            clearStoredSession()
            state = .signedOut
            throw Self.signInError(from: error)
        }
    }

    nonisolated static func signInError(from error: Error) -> SignInError {
        switch error {
        case PatreonError.unauthorized, PatreonError.forbidden:
            return .invalidSession
        case PatreonError.rateLimited(let seconds):
            return .rateLimited(retryAfter: seconds)
        case PatreonError.badResponse, PatreonError.decoding:
            return .unexpected
        default:
            return .network
        }
    }

    /// Clears the stored credential and every cache, so the next person to use
    /// this TV sees a clean app. Viewing history is user data and is kept.
    func signOut() async {
        await AppCache.clear()
        clearStoredSession()
        state = .signedOut
        log.info("Signed out")
    }

    // MARK: - Mid-session expiry

    /// Called (debounced) by PatreonClient when a request 401s mid-session.
    /// Re-verifies against `/api/current_user`; only a definitive rejection
    /// there tears the session down, so a flaky endpoint can't log us out.
    func handleAuthFailure() async {
        guard case .signedIn = state, !isVerifyingAuthFailure else { return }
        isVerifyingAuthFailure = true
        defer { isVerifyingAuthFailure = false }

        do {
            let user = try await PatreonClient.shared.currentUser()
            // Session is actually fine — the 401 was endpoint-specific noise.
            currentUser = user
            log.info("Auth re-verification passed; keeping session")
        } catch {
            if Self.shouldClearSession(after: error) {
                log.error("Session rejected mid-use — entering sign-in flow")
                await expireSession()
            } else {
                log.info("Auth re-verification hit transient error; keeping session")
            }
        }
    }

    /// Removes the credential from the Keychain and from the API client. The
    /// caller decides which state to show afterwards.
    private func clearStoredSession() {
        storage.remove(forKey: Self.sessionKey)
        storage.remove(forKey: Self.userIDKey)
        PatreonClient.shared.clearSession()
        currentUser = nil
    }

    private func expireSession() async {
        await AppCache.clear()
        clearStoredSession()
        state = .sessionExpired
    }
}

enum SignInError: LocalizedError, Equatable {
    case invalidSession
    case rateLimited(retryAfter: Double)
    case network
    case unexpected

    var errorDescription: String? {
        switch self {
        case .invalidSession:
            L10n.string("error.invalidSession")
        case .rateLimited(let seconds):
            L10n.format("format.signInRateLimited", Int(seconds))
        case .network:
            L10n.string("error.network")
        case .unexpected:
            L10n.string("error.unexpected")
        }
    }
}
