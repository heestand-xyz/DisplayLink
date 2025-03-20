//
//  DisplayLinkAnimator.swift
//  DisplayLink
//
//  Created by Anton Heestand on 2025/03/20.
//

import Foundation

@MainActor
@Observable
public final class DisplayLinkAnimator: Sendable, Equatable {
    
    private let displayLink: DisplayLink
        
    private let id: UUID
    private var listenID: UUID?
    
    private let startDate: Date = .now
    private let duration: TimeInterval
    private var index: Int = 0
    
    public struct Progress {
        public let time: TimeInterval
        public let index: Int
        public let fraction: CGFloat
        public var easeInOutFraction: CGFloat {
            cos(fraction * .pi - .pi) / 2.0 + 0.5
        }
        public var easeInFraction: CGFloat {
            cos(fraction * .pi / 2 - .pi) + 1.0
        }
        public var easeOutFraction: CGFloat {
            cos(fraction * .pi / 2 - .pi / 2)
        }
        @MainActor static let zero = Progress(time: 0.0, index: 0, fraction: 0.0)
    }
    public private(set) var progress: Progress = .zero
    
    private var loop: ((Progress) -> Void)?
    private var completion: (() -> Void)?
    
    public enum State {
        case ready
        case running
        case done
        case cancelled
    }
    public private(set) var state: State
    
    public init(
        for duration: TimeInterval
    ) {
        id = UUID()
        self.duration = duration
        displayLink = DisplayLink()
        state = .ready
    }
    
    public func run(
        loop: ((Progress) -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard state == .ready else { return }
        self.loop = loop
        self.completion = completion
        listenID = displayLink.listen { [weak self] in
            Task { @MainActor in
                self?.frameLoop()
            }
        }
        state = .running
    }
    
    private func frameLoop() {
        guard state == .running else { return }
        let time: TimeInterval = startDate.distance(to: .now)
        if time >= duration {
            progress = Progress(
                time: duration,
                index: index,
                fraction: 1.0
            )
            loop?(progress)
            completion?()
            stop()
            state = .done
        } else {
            progress = Progress(
                time: time,
                index: index,
                fraction: time / duration
            )
            loop?(progress)
            index += 1
        }
    }
    
    public func cancel() {
        state = .cancelled
        stop()
    }
    
    private func stop() {
        if let listenID: UUID {
            displayLink.unlisten(id: listenID)
        }
        displayLink.stop()
    }
    
    nonisolated public static func == (lhs: DisplayLinkAnimator, rhs: DisplayLinkAnimator) -> Bool {
        lhs.id == rhs.id
    }
}
