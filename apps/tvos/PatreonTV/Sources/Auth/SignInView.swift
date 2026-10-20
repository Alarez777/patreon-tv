//
//  SignInView.swift
//  PatreonTV
//
//  Manual sign-in. The TV has no browser, so the user copies the Patreon
//  `session_id` cookie from a desktop browser and pastes it here. The session
//  is validated against Patreon and stored in the Keychain.
//

import SwiftUI

struct SignInView: View {

    /// True when the stored session was rejected mid-use.
    var sessionExpired: Bool = false

    @Environment(AuthStore.self) private var auth
    @State private var sessionID = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    private var parsedSessionID: String? {
        SessionIDParser.parse(sessionID)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 64) {
                    instructions
                        .frame(maxWidth: 680, alignment: .leading)

                    form
                        .frame(maxWidth: 700, alignment: .leading)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 60)
                .frame(maxWidth: 1500)
            }
        }
        .task {
            // Focusing the field brings up the iPhone/iPad keyboard prompt,
            // which is the practical way to paste a long cookie value.
            try? await Task.sleep(for: .milliseconds(250))
            fieldFocused = true
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image("PTVWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 110)
                .accessibilityLabel("PatreonTV")

            VStack(alignment: .leading, spacing: 10) {
                Text("Sign in with Patreon")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                Text("Paste your Patreon session ID to connect this TV.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if sessionExpired {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Your Patreon session expired. Paste a fresh session ID to reconnect this TV.")
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.title3.weight(.medium))
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 16) {
                step(1, "On a computer, sign in at patreon.com.")
                step(2, "Open developer tools (F12 on Windows, ⌥⌘I on Mac).")
                step(3, "Go to Application (Chrome) or Storage (Firefox/Safari) → Cookies → https://www.patreon.com.")
                step(4, "Copy the value of the session_id cookie.")
                step(5, "Paste it below using your iPhone/iPad keyboard, or type it with the Siri Remote.")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("The session_id cookie is HttpOnly, so it only appears in a desktop browser's developer tools.")
                Text("Signing out of that browser also signs out this TV.")
                Text("It works like a password: keep it private. Settings → Sign Out removes it from this TV.")
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Session ID")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            TextField("Paste the session_id value", text: $sessionID)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .padding(20)
                .background(PatreonColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .focused($fieldFocused)
                .onSubmit { Task { await submit() } }

            if let errorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
            }

            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 12) {
                    if isSigningIn {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSigningIn ? "Signing in…" : "Continue")
                }
                .font(.title3.weight(.semibold))
                .frame(minWidth: 280)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(PatreonColors.brand)
            .disabled(parsedSessionID == nil || isSigningIn)

            Text("PatreonTV is not affiliated with Patreon.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 8)
        }
        .padding(36)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(PatreonColors.brand.opacity(0.9), in: Circle())
                .foregroundStyle(.white)

            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submit() async {
        guard let id = parsedSessionID, !isSigningIn else { return }

        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            try await auth.completeSignIn(sessionID: id)
        } catch {
            errorMessage = error.localizedDescription
            fieldFocused = true
        }
    }
}
