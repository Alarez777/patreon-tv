//
//  PollSection.swift
//  PatreonTV
//
//  Read-only rendering of a Patreon poll: the question, each option with its
//  vote share, and a filled radio circle on the option the viewer chose.
//
//  Voting isn't supported yet. The rows are plain views today so they can later
//  become focusable buttons without reworking the layout.
//

import SwiftUI

struct PollSection: View {

    let poll: Poll
    let choices: [PollChoice]
    let selectedChoiceIDs: Set<String>

    @FocusState private var focusedChoiceID: String?

    private var total: Int {
        let sum = choices.reduce(0) { $0 + ($1.attributes.numResponses ?? 0) }
        return max(poll.attributes.numResponses ?? sum, 1)
    }

    private var isClosed: Bool {
        guard let raw = poll.attributes.closesAt else { return false }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else {
            return false
        }
        return date < Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(poll.attributes.questionText ?? L10n.string("Poll"))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PatreonColors.primaryText)

                Spacer()

                Text(L10n.count(total, one: "count.votes.one", other: "count.votes.other"))
                    .font(.subheadline)
                    .foregroundStyle(PatreonColors.secondaryText)

                if isClosed {
                    Text("Closed")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(PatreonColors.background, in: Capsule())
                        .foregroundStyle(PatreonColors.secondaryText)
                }
            }

            VStack(spacing: 10) {
                ForEach(choices) { choice in
                    // Focusable so tvOS can scroll to the poll and the viewer
                    // can move through each line. A plain focusable view avoids
                    // the white Button focus ring. Selecting does nothing yet.
                    PollChoiceRow(
                        choice: choice,
                        total: total,
                        isSelected: selectedChoiceIDs.contains(choice.id)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        focusedChoiceID == choice.id
                            ? Color.black.opacity(0.55)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .contentShape(Rectangle())
                    .focusable()
                    .focusEffectDisabled()
                    .focused($focusedChoiceID, equals: choice.id)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: 1400, alignment: .leading)
        .background(
            PatreonColors.cardSurface.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .focusSection()
    }
}

private struct PollChoiceRow: View {

    let choice: PollChoice
    let total: Int
    let isSelected: Bool

    private var count: Int { choice.attributes.numResponses ?? 0 }
    private var fraction: Double {
        total > 0 ? min(max(Double(count) / Double(total), 0), 1) : 0
    }
    private var percent: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        HStack(spacing: 16) {
            radio

            Text(choice.attributes.textContent ?? L10n.string("Option"))
                .font(.title3)
                .foregroundStyle(PatreonColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            bar

            Text(L10n.format("format.votesSummary", count, percent))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(PatreonColors.secondaryText)
                .frame(width: 140, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.format(
                isSelected ? "format.voteAccessibilitySelected" : "format.voteAccessibility",
                choice.attributes.textContent ?? L10n.string("Option"),
                count,
                percent
            )
        )
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? PatreonColors.brand : PatreonColors.secondaryText.opacity(0.6),
                    lineWidth: 3
                )
            if isSelected {
                Circle()
                    .fill(PatreonColors.secondaryText.opacity(0.75))
                    .padding(7)
            }
        }
        .frame(width: 30, height: 30)
    }

    private var bar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(PatreonColors.primaryText.opacity(0.12))
            Capsule()
                .fill(isSelected ? PatreonColors.brand : PatreonColors.secondaryText.opacity(0.55))
                .frame(width: 320 * fraction)
        }
        .frame(width: 320, height: 10)
    }
}
