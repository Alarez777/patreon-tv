//
//  SettingsView.swift
//  PatreonTV
//
//  App settings: language, mature content, autoplay sources, collections,
//  launch tab, comment order and sign out.
//

import NukeUI
import SwiftUI

struct SettingsView: View {

    @Environment(AuthStore.self) private var auth
    @State private var prefs = ContentPreferences.shared
    @FocusState private var focusedSetting: SettingID?

    private enum SettingID: Hashable {
        case mature
        case autoplayNew
        case autoplayContinueWatching
        case autoplayChannels
        case autoplayCollections
        case continueCollection
        case oldestFirst
    }

    var body: some View {
        @Bindable var prefs = prefs

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                userHeader

                languageSection

                settingToggle(
                    .mature,
                    isOn: $prefs.showMatureContent,
                    title: "Show mature content",
                    detail: "Reveal creators and posts flagged as NSFW."
                )

                autoplayHeader

                settingToggle(
                    .autoplayNew,
                    isOn: $prefs.autoplayNew,
                    title: "New",
                    detail: "Auto-advance to the next post from the New shelf."
                )
                settingToggle(
                    .autoplayContinueWatching,
                    isOn: $prefs.autoplayContinueWatching,
                    title: "Continue Watching",
                    detail: "Auto-advance from the Continue Watching shelf."
                )
                settingToggle(
                    .autoplayChannels,
                    isOn: $prefs.autoplayChannels,
                    title: "Channels",
                    detail: "Auto-advance from creator pages and their carousels."
                )
                settingToggle(
                    .autoplayCollections,
                    isOn: $prefs.autoplayCollections,
                    title: "Collections",
                    detail: "Auto-advance through collection episodes."
                )

                settingToggle(
                    .continueCollection,
                    isOn: $prefs.showContinueCollection,
                    title: "Show Continue Collection",
                    detail: "Show the collection you opened most recently on Home."
                )

                settingToggle(
                    .oldestFirst,
                    isOn: $prefs.collectionOldestFirst,
                    title: "Oldest episodes first",
                    detail: "Open a collection's episodes oldest-first; off lists newest first."
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
                Label(prefs.language.displayName, systemImage: "globe")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text("Language"))
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    private var autoplayHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Autoplay next")
                .foregroundStyle(PatreonColors.primaryText)
            Text("Choose where playback advances to the next post automatically.")
                .font(.caption)
                .foregroundStyle(PatreonColors.secondaryText)
        }
        .frame(maxWidth: 700, alignment: .leading)
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

    private func settingToggle(
        _ id: SettingID,
        isOn: Binding<Bool>,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(
                        focusedSetting == id ? Color.black : PatreonColors.primaryText
                    )
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(
                        focusedSetting == id
                            ? Color.black.opacity(0.7)
                            : PatreonColors.secondaryText
                    )
            }
        }
        .frame(maxWidth: 700)
        .focused($focusedSetting, equals: id)
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
