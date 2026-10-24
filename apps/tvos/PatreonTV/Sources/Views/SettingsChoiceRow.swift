//
//  SettingsChoiceRow.swift
//  PatreonTV
//
//  A horizontal row of option buttons that looks like a segmented control but
//  only commits a change when the user presses Select. tvOS's own segmented
//  picker binds its selection to focus, so merely swiping across it changes the
//  preference; here swiping only moves the highlight.
//

import SwiftUI

struct SettingsChoiceRow<Option: Hashable>: View {

    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    @FocusState private var focusedOption: Option?

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
        let isFocused = focusedOption == option

        return Button {
            selection = option
        } label: {
            HStack(spacing: 8) {
                Text(label(option))
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .font(.body.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isFocused ? Color.black : PatreonColors.primaryText)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(fill(isSelected: isSelected, isFocused: isFocused))
            )
        }
        .buttonStyle(.plain)
        .focused($focusedOption, equals: option)
        .accessibilityLabel(Text(label(option)))
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }

    /// Mirrors the focus treatment used by the rest of Settings: the focused
    /// segment turns white with black text. The confirmed value keeps the brand
    /// fill and the checkmark while focus sits on another option.
    private func fill(isSelected: Bool, isFocused: Bool) -> Color {
        if isFocused {
            return .white
        }
        if isSelected {
            return PatreonColors.brand
        }
        return PatreonColors.cardSurface
    }
}
