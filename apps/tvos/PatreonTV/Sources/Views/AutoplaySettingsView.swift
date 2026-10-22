//
//  AutoplaySettingsView.swift
//  PatreonTV
//
//  Per-source autoplay switches. The master toggle turns automatic advance on
//  or off; the source toggles choose which feeds may advance.
//

import SwiftUI

struct AutoplaySettingsView: View {

    @State private var prefs = ContentPreferences.shared

    var body: some View {
        @Bindable var prefs = prefs

        return ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 64) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Autoplay next")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PatreonColors.primaryText)
                    Text("Choose where playback advances to the next post automatically.")
                        .font(.body)
                        .foregroundStyle(PatreonColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 560, alignment: .leading)

                VStack(alignment: .leading, spacing: 24) {
                    SettingsToggleRow(
                        title: "Enable autoplay",
                        detail: "Turn automatic advance on or off for the feeds below.",
                        isOn: $prefs.autoplayNext
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Feeds")
                            .font(.headline)
                            .foregroundStyle(PatreonColors.primaryText)

                        SettingsToggleRow(
                            title: "New",
                            detail: "Auto-advance to the next post from the New shelf.",
                            isOn: $prefs.autoplayNew
                        )
                        .disabled(!prefs.autoplayNext)
                        .opacity(prefs.autoplayNext ? 1 : 0.45)

                        SettingsToggleRow(
                            title: "Continue Watching",
                            detail: "Auto-advance from the Continue Watching shelf.",
                            isOn: $prefs.autoplayContinueWatching
                        )
                        .disabled(!prefs.autoplayNext)
                        .opacity(prefs.autoplayNext ? 1 : 0.45)

                        SettingsToggleRow(
                            title: "Channels",
                            detail: "Auto-advance from creator pages and their carousels.",
                            isOn: $prefs.autoplayChannels
                        )
                        .disabled(!prefs.autoplayNext)
                        .opacity(prefs.autoplayNext ? 1 : 0.45)

                        SettingsToggleRow(
                            title: "Collections",
                            detail: "Auto-advance through collection episodes.",
                            isOn: $prefs.autoplayCollections
                        )
                        .disabled(!prefs.autoplayNext)
                        .opacity(prefs.autoplayNext ? 1 : 0.45)
                    }
                }
                .frame(maxWidth: 700, alignment: .leading)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
            .frame(maxWidth: 1500, alignment: .leading)
        }
        .background(PatreonColors.background.ignoresSafeArea())
    }
}
