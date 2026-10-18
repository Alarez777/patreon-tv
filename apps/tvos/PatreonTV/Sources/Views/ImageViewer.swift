//
//  ImageViewer.swift
//  PatreonTV
//
//  Full-screen viewer for an image post: black background, centered image.
//
//  Navigation uses the tvOS-native focus + move-command pipeline (left/right),
//  because TabView(.page) doesn't react to the Siri Remote and
//  UISwipeGestureRecognizer isn't available on tvOS. A transient "n/N" counter
//  appears while navigating and fades out when idle.
//

import NukeUI
import SwiftUI

struct ImageViewer: View {

    let images: [URL]

    @State private var index = 0
    @FocusState private var isFocused: Bool
    @State private var showCounter = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            image(images.indices.contains(index) ? images[index] : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .onMoveCommand { direction in
                    switch direction {
                    case .left: step(-1)
                    case .right: step(1)
                    default: break
                    }
                }

            if images.count > 1, showCounter {
                counter
            }
        }
        .task {
            // Let the focus engine settle inside the cover, then take focus.
            try? await Task.sleep(for: .milliseconds(300))
            isFocused = true
        }
        .onAppear { flashCounter() }
        .onDisappear { hideTask?.cancel() }
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

    /// Move by `delta` when there is a neighbouring image.
    private func step(_ delta: Int) {
        let next = index + delta
        guard images.indices.contains(next) else { return }
        index = next
        flashCounter()
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
