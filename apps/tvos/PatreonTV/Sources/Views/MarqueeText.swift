//
//  MarqueeText.swift
//  PatreonTV
//
//  A single-line label that horizontally scrolls back and forth when its text
//  is wider than the available space. Used by the Continue Collection card so
//  long episode titles stay readable while the card is focused.
//

import SwiftUI

struct MarqueeText: View {

    let text: String
    var font: Font = .subheadline
    var color: Color = PatreonColors.secondaryText
    /// Width the label is allowed to occupy (the card's text column).
    let availableWidth: CGFloat
    /// Scroll only while the owning card is focused.
    let isActive: Bool

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflow: CGFloat { max(0, textWidth - availableWidth) }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(widthReader)
            .offset(x: offset)
            .frame(width: availableWidth, alignment: .leading)
            .clipped()
            .onAppear { restart() }
            .onChange(of: isActive) { _, _ in restart() }
            .onChange(of: textWidth) { _, _ in restart() }
    }

    /// Measures the text's intrinsic width.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { textWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, width in textWidth = width }
        }
    }

    private func restart() {
        guard isActive, overflow > 0 else {
            withAnimation(.easeOut(duration: 0.15)) { offset = 0 }
            return
        }
        offset = 0
        let duration = max(2, Double(overflow) / 35)   // ~35 pt/s
        withAnimation(.linear(duration: duration).delay(0.7).repeatForever(autoreverses: true)) {
            offset = -overflow
        }
    }
}
