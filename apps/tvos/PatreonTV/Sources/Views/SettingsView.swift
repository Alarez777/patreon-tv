//
//  SettingsView.swift
//  PatreonTV
//
//  App settings: language, mature content, autoplay, collections, launch tab,
//  comment order and sign out.
//

import NukeUI
import SwiftUI

struct SettingsView: View {

    @Environment(AuthStore.self) private var auth
    @State private var prefs = ContentPreferences.shared
    @FocusState private var languageFocused: Bool
    @FocusState private var autoplayRowFocused: Bool

    private let languageControlWidth: CGFloat = 340

    var body: some View {
        @Bindable var prefs = prefs

        return NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    userHeader

                    languageSection

                    SettingsToggleRow(
                        title: "Show mature content",
                        detail: "Reveal creators and posts flagged as NSFW.",
                        isOn: $prefs.showMatureContent
                    )

                    autoplayRow

                    SettingsToggleRow(
                        title: "Show Continue Collection",
                        detail: "Show the collection you opened most recently on Home.",
                        isOn: $prefs.showContinueCollection
                    )

                    SettingsToggleRow(
                        title: "Oldest episodes first",
                        detail: "Open a collection's episodes oldest-first; off lists newest first.",
                        isOn: $prefs.collectionOldestFirst
                    )

                    initialTabSection
                    commentOrderSection

                    Button {
                        auth.signOut()
                    } label: {
                        Text("Sign Out")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 48)
                            .padding(.vertical, 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PatreonColors.brand)
                    .padding(.top, 8)

                    Text("PatreonTV \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.footnote)
                        .foregroundStyle(PatreonColors.tertiaryText)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
            .background(PatreonColors.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var userHeader: some View {
        if let user = auth.currentUser {
            avatar(for: user)

            VStack(spacing: 8) {
                Text(user.attributes.fullName ?? L10n.string("Signed in"))
                    .font(.title)
                    .foregroundStyle(PatreonColors.primaryText)
                if let email = user.attributes.email {
                    Text(email)
                        .foregroundStyle(PatreonColors.secondaryText)
                }
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language")
                .foregroundStyle(PatreonColors.primaryText)
            Text("The app language. Defaults to your Apple TV language.")
                .font(.caption)
                .foregroundStyle(PatreonColors.secondaryText)

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        prefs.language = language
                    } label: {
                        if language == prefs.language {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .foregroundStyle(languageFocused ? Color.black : PatreonColors.primaryText)
                    MarqueeText(
                        text: prefs.language.displayName,
                        font: .body.weight(.medium),
                        color: languageFocused ? .black : PatreonColors.primaryText,
                        availableWidth: languageControlWidth - 58,
                        isActive: languageFocused
                    )
                }
                .padding(.horizontal, 16)
                .frame(width: languageControlWidth, height: 46, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .focused($languageFocused)
            .accessibilityLabel(Text("Language"))
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    private var autoplayRow: some View {
        NavigationLink {
            AutoplaySettingsView()
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Autoplay next")
                        .foregroundStyle(
                            autoplayRowFocused ? Color.black : PatreonColors.primaryText
                        )
                    Text("Choose where playback advances to the next post automatically.")
                        .font(.caption)
                        .foregroundStyle(
                            autoplayRowFocused
                                ? Color.black.opacity(0.7)
                                : PatreonColors.secondaryText
                        )
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(
                        autoplayRowFocused ? Color.black : PatreonColors.tertiaryText
                    )
            }
            .frame(maxWidth: 700)
        }
        .buttonStyle(.bordered)
        .focused($autoplayRowFocused)
    }

    private var initialTabSection: some View {
        @Bindable var prefs = prefs

        return VStack(alignment: .leading, spacing: 12) {
            Text("Initial tab")
                .foregroundStyle(PatreonColors.primaryText)
            Text("Which tab opens when PatreonTV launches.")
                .font(.caption)
                .foregroundStyle(PatreonColors.secondaryText)
            Picker("Initial tab", selection: $prefs.initialTab) {
                ForEach(ContentPreferences.InitialTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    private var commentOrderSection: some View {
        @Bindable var prefs = prefs

        return VStack(alignment: .leading, spacing: 12) {
            Text("Comment order")
                .foregroundStyle(PatreonColors.primaryText)
            Text("How a post's comments open. The comments screen can still reorder them for that visit.")
                .font(.caption)
                .foregroundStyle(PatreonColors.secondaryText)
            Picker("Comment order", selection: $prefs.commentSort) {
                ForEach(CommentSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    private func avatar(for user: PatreonUser) -> some View {
        LazyImage(url: user.attributes.imageURL ?? user.attributes.thumbURL) { state in
            if let image = state.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    PatreonColors.cardSurface
                    Image(systemName: "person.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(PatreonColors.tertiaryText)
                }
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
    }
}
