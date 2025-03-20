//
//  DisplayLinkAnimation.swift
//  DisplayLink
//
//  Created by Anton Heestand on 2025/03/20.
//

import Foundation

@MainActor
public final class DisplayLinkAnimation: Sendable {
    
    private let displayLink: DisplayLink
    
    private var listenID: UUID?
    
    private let startDate: Date = .now
    private let duration: TimeInterval
    private var index: Int = 0
    
    public struct Progress {
        public let time: TimeInterval
        public let index: Int
        public let fraction: CGFloat
    }
    
    private let loop: (Progress) -> Void
    private let completion: () -> Void
    
    public init(
        for duration: TimeInterval,
        loop: @escaping (Progress) -> Void,
        completion: @escaping () -> Void
    ) {
        self.duration = duration
        self.loop = loop
        self.completion = completion
        displayLink = DisplayLink()
        listenID = displayLink.listen { [weak self] in
            Task { @MainActor in
                self?.frameLoop()
            }
        }
    }
    
    @MainActor
    private func frameLoop() {
        let time: TimeInterval = startDate.distance(to: .now)
        if time >= duration {
            if let listenID: UUID {
                displayLink.unlisten(id: listenID)
            }
            displayLink.stop()
            completion()
        } else {
            let progress = Progress(
                time: time,
                index: index,
                fraction: time / duration
            )
            loop(progress)
            index += 1
        }
    }
}
