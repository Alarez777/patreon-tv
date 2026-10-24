//
//  SettingsChoiceRow.swift
//  PatreonTV
//
//  A horizontal row of option buttons that looks like a segmented control but
//  only commits a change when the user presses Select. tvOS's own segmented
//  picker binds its selection to focus, so merely swiping across it changes the
//  preference; here swiping only moves the native focus highlight.
//

import SwiftUI

struct SettingsChoiceRow<Option: Hashable>: View {

    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                segment(for: option)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func segment(for option: Option) -> some View {
        let isSelected = option == selection

        let button = Button {
            selection = option
        } label: {
            HStack(spacing: 8) {
                Text(label(option))
                    .fontWeight(isSelected ? .semibold : .regular)
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(label(option)))
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())

        return Group {
            // Only the committed option is tinted. tvOS derives a bordered
            // button's label colour from its tint, so tinting every segment
            // left the unselected ones dark-on-dark and hard to read.
            if isSelected {
                button.tint(PatreonColors.brand)
            } else {
                button
            }
        }
    }
}
