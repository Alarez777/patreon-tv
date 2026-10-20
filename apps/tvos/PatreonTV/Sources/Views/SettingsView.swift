//
//  SettingsView.swift
//  PatreonTV
//
//  App settings: mature content, playback, launch tab, comment order and
//  sign out.
//

import NukeUI
import SwiftUI

struct SettingsView: View {

    @Environment(AuthStore.self) private var auth
    @State private var prefs = ContentPreferences.shared

    var body: some View {
        @Bindable var prefs = prefs

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Language")
                        .foregroundStyle(PatreonColors.primaryText)
                    Text("The app language. Defaults to your Apple TV language.")
                        .font(.caption)
                        .foregroundStyle(PatreonColors.secondaryText)
                    Picker("Language", selection: $prefs.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: 700, alignment: .leading)

                Toggle(isOn: $prefs.showMatureContent) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show mature content")
                            .foregroundStyle(PatreonColors.primaryText)
                        Text("Reveal creators and posts flagged as NSFW.")
                            .font(.caption)
                            .foregroundStyle(PatreonColors.secondaryText)
                    }
                }
                .frame(maxWidth: 700)

                Toggle(isOn: $prefs.autoplayNext) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Autoplay next")
                            .foregroundStyle(PatreonColors.primaryText)
                        Text("When something ends, start the creator's next post after a countdown.")
                            .font(.caption)
                            .foregroundStyle(PatreonColors.secondaryText)
                    }
                }
                .frame(maxWidth: 700)

                Toggle(isOn: $prefs.showContinueCollection) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Continue Collection")
                            .foregroundStyle(PatreonColors.primaryText)
                        Text("Show the collection you opened most recently on Home.")
                            .font(.caption)
                            .foregroundStyle(PatreonColors.secondaryText)
                    }
                }
                .frame(maxWidth: 700)

                Toggle(isOn: $prefs.collectionOldestFirst) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Oldest episodes first")
                            .foregroundStyle(PatreonColors.primaryText)
                        Text("Open a collection's episodes oldest-first; off lists newest first.")
                            .font(.caption)
                            .foregroundStyle(PatreonColors.secondaryText)
                    }
                }
                .frame(maxWidth: 700)

                VStack(alignment: .leading, spacing: 12) {
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

                VStack(alignment: .leading, spacing: 12) {
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
