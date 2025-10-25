//
//  DisplayLinkAnimationProgress.swift
//  DisplayLink
//
//  Created by Anton Heestand on 2025-10-25.
//

import Foundation

public struct DisplayLinkAnimationProgress: Sendable {
    public let time: TimeInterval
    public let index: Int
    public let fraction: CGFloat
    @MainActor static let zero = DisplayLinkAnimationProgress(time: 0.0, index: 0, fraction: 0.0)
}

extension DisplayLinkAnimationProgress {
    
    public func fractionWithEaseInOut(iterations: Int = 1) -> CGFloat {
        guard iterations > 0 else { return fraction }
        var fraction: CGFloat = fraction
        for _ in 0..<iterations {
            fraction = Self.easeInOut(fraction)
        }
        return fraction
    }
    
    public func fractionWithEaseIn(iterations: Int = 1) -> CGFloat {
        guard iterations > 0 else { return fraction }
        var fraction: CGFloat = fraction
        for _ in 0..<iterations {
            fraction = Self.easeIn(fraction)
        }
        return fraction
    }
    
    public func fractionWithEaseOut(iterations: Int = 1) -> CGFloat {
        guard iterations > 0 else { return fraction }
        var fraction: CGFloat = fraction
        for _ in 0..<iterations {
            fraction = Self.easeOut(fraction)
        }
        return fraction
    }
    
    private static func easeInOut(_ fraction: CGFloat) -> CGFloat {
        cos(fraction * .pi - .pi) / 2.0 + 0.5
    }
    
    private static func easeIn(_ fraction: CGFloat) -> CGFloat {
        cos(fraction * .pi / 2 - .pi) + 1.0
    }
    
    private static func easeOut(_ fraction: CGFloat) -> CGFloat {
        cos(fraction * .pi / 2 - .pi / 2)
    }
}
