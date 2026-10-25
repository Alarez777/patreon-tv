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

    @FocusState private var focusedOption: Option?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                segment(for: option)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: focusedOption) { oldValue, newValue in
            // Focus arriving from another row (nil means nothing in this row
            // was focused) lands on the committed option instead of wherever
            // the focus engine left it last time. Horizontal swipes within the
            // row never pass through nil, so they are left alone.
            if oldValue == nil, let newValue, newValue != selection {
                focusedOption = selection
            }
        }
    }

    private func segment(for option: Option) -> some View {
        let isSelected = option == selection

        return Button {
            selection = option
        } label: {
            HStack(spacing: 6) {
                // Invisible mirror of the check mark keeps the label centred
                // whether or not this option is the selected one.
                Image(systemName: "checkmark")
                    .opacity(0)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(label(option))
                    // "Último usado" / "Dernier utilisé" do not fit a quarter
                    // of the row at the default size: keep every option on one
                    // line and shrink just the long one instead of wrapping.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)

                // Always laid out, so selecting an option does not shift the
                // labels: only the check mark tells them apart.
                Image(systemName: "checkmark")
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 18)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .focused($focusedOption, equals: option)
        .accessibilityLabel(Text(label(option)))
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}
