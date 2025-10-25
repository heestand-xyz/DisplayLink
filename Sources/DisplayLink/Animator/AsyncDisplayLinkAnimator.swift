//
//  AsyncDisplayLinkAnimator.swift
//  DisplayLink
//
//  Created by Anton Heestand on 2025/03/20.
//

import Foundation

@MainActor
@Observable
public final class AsyncDisplayLinkAnimator: Sendable, Equatable {
    
    private let displayLink: DisplayLink
        
    private let id: UUID
    private var listenID: UUID?
    
    private let startDate: Date = .now
    private let duration: TimeInterval
    private var index: Int = 0
    
    public private(set) var progress: DisplayLinkAnimationProgress = .zero
    
    private var loop: ((DisplayLinkAnimationProgress) async -> Void)?
    private var completion: ((Bool) async -> Void)?
    
    public enum State {
        case ready
        case running
        case done
        case cancelled
    }
    public private(set) var state: State
    
    @MainActor
    private var isInFrameLoop: Bool = false
    
    public init(
        duration: TimeInterval
    ) {
        id = UUID()
        self.duration = duration
        displayLink = DisplayLink()
        state = .ready
    }
    
    public func run(
        loop: ((DisplayLinkAnimationProgress) async -> Void)? = nil,
        completion: ((_ finished: Bool) async -> Void)? = nil
    ) {
        guard state == .ready else { return }
        self.loop = loop
        self.completion = completion
        listenID = displayLink.listen { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if isInFrameLoop {
                   return
                }
                isInFrameLoop = true
                await frameLoop()
                isInFrameLoop = false
            }
        }
        state = .running
    }
    
    private func frameLoop() async {
        guard state == .running else { return }
        let time: TimeInterval = startDate.distance(to: .now)
        if time >= duration {
            progress = DisplayLinkAnimationProgress(
                time: duration,
                index: index,
                fraction: 1.0
            )
            await loop?(progress)
            state = .done
            await completion?(true)
            stop()
        } else {
            progress = DisplayLinkAnimationProgress(
                time: time,
                index: index,
                fraction: time / duration
            )
            await loop?(progress)
            index += 1
        }
    }
    
    public func cancel() async {
        let oldState = state
        state = .cancelled
        if oldState == .running {
            await completion?(false)
            stop()
        }
    }
    
    private func stop() {
        if let listenID: UUID {
            displayLink.unlisten(id: listenID)
        }
        displayLink.stop()
    }
    
    nonisolated public static func == (lhs: AsyncDisplayLinkAnimator, rhs: AsyncDisplayLinkAnimator) -> Bool {
        lhs.id == rhs.id
    }
}
