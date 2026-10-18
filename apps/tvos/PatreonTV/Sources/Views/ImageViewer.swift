//
//  ImageViewer.swift
//  PatreonTV
//
//  Full-screen viewer for an image post: black background, centered image.
//
//  Paging is a focus carousel: full-screen focusable pages inside a horizontal
//  ScrollView. The tvOS focus engine moves between pages, which gives the
//  natural swipe direction (right→left = next) and keeps the left/right button
//  presses working as usual. This replaces TabView(.page) and .onMoveCommand,
//  which can't tell a swipe from a button press.
//

import NukeUI
import SwiftUI

struct ImageViewer: View {

    let images: [URL]

    @State private var index = 0
    @FocusState private var focusedIndex: Int?
    @State private var showCounter = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if images.count <= 1 {
                singleImage
            } else {
                pager
            }

            if images.count > 1, showCounter {
                counter
            }
        }
        .task {
            guard images.count > 1 else { return }
            // Let the focus engine settle inside the cover, then focus page 0.
            try? await Task.sleep(for: .milliseconds(300))
            focusedIndex = 0
        }
        .onAppear { flashCounter() }
        .onDisappear { hideTask?.cancel() }
    }

    private var singleImage: some View {
        image(images.first)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .focusable()
            .focusEffectDisabled()
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Plain HStack, not LazyHStack: off-screen pages must be realized so
            // the focus engine can move to them and scroll the pager.
            HStack(spacing: 0) {
                ForEach(Array(images.enumerated()), id: \.offset) { offset, url in
                    page(url, offset: offset)
                        .containerRelativeFrame(.horizontal)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea()
        .onChange(of: focusedIndex) { _, new in
            guard let new else { return }
            index = new
            flashCounter()
        }
    }

    private func page(_ url: URL, offset: Int) -> some View {
        image(url)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .focusable()
            .focusEffectDisabled()
            .focused($focusedIndex, equals: offset)
            .accessibilityLabel("Image \(offset + 1) of \(images.count)")
    }

    @ViewBuilder
    private func image(_ url: URL?) -> some View {
        if let url {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFit()
                } else if state.isLoading {
                    ProgressView()
                } else {
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    private var counter: some View {
        Text("\(index + 1)/\(images.count)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.black.opacity(0.55), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 48)
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    /// Show the counter, then hide it after a short idle delay.
    private func flashCounter() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) { showCounter = true }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { showCounter = false }
        }
    }
}
