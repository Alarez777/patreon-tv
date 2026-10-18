//
//  ImageViewer.swift
//  PatreonTV
//
//  Full-screen viewer for an image post: black background, centered image.
//
//  Paging uses the tvOS focus engine (not TabView(.page), which doesn't react
//  to the Siri Remote): each image is a full-screen focusable page, so a swipe
//  or a left/right press moves focus to the neighbouring page. A transient
//  "n/N" counter appears while navigating and fades out when idle.
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
                image(images.first)
                    .padding(40)
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
        .onDisappear { hideTask?.cancel() }
    }

    private var pager: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
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
                proxy.scrollTo(new, anchor: .center)
                flashCounter()
            }
        }
    }

    private func page(_ url: URL, offset: Int) -> some View {
        Button {} label: {
            image(url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
