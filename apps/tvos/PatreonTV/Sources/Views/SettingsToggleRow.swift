//
//  SettingsToggleRow.swift
//  PatreonTV
//
//  A settings Toggle whose label turns black on focus so it stays readable on
//  tvOS's light focus background.
//

import SwiftUI

struct SettingsToggleRow: View {

    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @Binding var isOn: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(
                        isFocused ? Color.black : PatreonColors.primaryText
                    )
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(
                        isFocused
                            ? Color.black.opacity(0.7)
                            : PatreonColors.secondaryText
                    )
            }
        }
        .frame(maxWidth: 700)
        .focused($isFocused)
    }
}
