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
    
    public private(set) var progress: DisplayLinkAnimationProgress = .zero
    
    private var loop: ((DisplayLinkAnimationProgress) -> Void)?
    private var completion: ((Bool) -> Void)?
    
    public enum State {
        case ready
        case running
        case done
        case cancelled
    }
    public private(set) var state: State
    
    public init(
        duration: TimeInterval
    ) {
        id = UUID()
        self.duration = duration
        displayLink = DisplayLink()
        state = .ready
    }
    
    public func run(
        loop: ((DisplayLinkAnimationProgress) -> Void)? = nil,
        completion: ((_ finished: Bool) -> Void)? = nil
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
            progress = DisplayLinkAnimationProgress(
                time: duration,
                index: index,
                fraction: 1.0
            )
            loop?(progress)
            state = .done
            completion?(true)
            stop()
        } else {
            progress = DisplayLinkAnimationProgress(
                time: time,
                index: index,
                fraction: time / duration
            )
            loop?(progress)
            index += 1
        }
    }
    
    public func cancel() {
        let oldState = state
        state = .cancelled
        if oldState == .running {
            completion?(false)
            stop()
        }
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
