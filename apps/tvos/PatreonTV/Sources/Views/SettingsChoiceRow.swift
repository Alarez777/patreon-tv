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

    private let cornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                segment(for: option)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Every segment keeps the same view hierarchy no matter which option is
    /// selected. Switching view types here (for example with a conditional
    /// `.tint`) makes SwiftUI rebuild the button and tvOS drops focus to a
    /// neighbouring row, so selection is drawn as an overlay instead.
    private func segment(for option: Option) -> some View {
        let isSelected = option == selection

        return Button {
            selection = option
        } label: {
            HStack(spacing: 8) {
                Text(label(option))
                    .fontWeight(isSelected ? .semibold : .regular)
                // Always laid out, so selecting an option does not shift the
                // labels or change the label's structure.
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
        .overlay {
            // Brand outline on the committed value. The focused segment still
            // gets tvOS's own white highlight, so the two never get confused.
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(PatreonColors.brand, lineWidth: 3)
                .opacity(isSelected ? 1 : 0)
        }
        .accessibilityLabel(Text(label(option)))
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}
