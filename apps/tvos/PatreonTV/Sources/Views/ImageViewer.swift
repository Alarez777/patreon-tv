//
//  ImageViewer.swift
//  PatreonTV
//
//  Full-screen viewer for an image post: black background, centered image, and
//  swiping moves between images. A transient "n/N" counter appears while
//  navigating and fades out when the viewer stops moving.
//

import NukeUI
import SwiftUI

struct ImageViewer: View {

    let images: [URL]

    @State private var index = 0
    @State private var showCounter = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if images.count <= 1 {
                image(images.first)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(images.enumerated()), id: \.offset) { offset, url in
                        image(url)
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            if images.count > 1, showCounter {
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
        }
        .onAppear { flashCounter() }
        .onChange(of: index) { _, _ in flashCounter() }
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
