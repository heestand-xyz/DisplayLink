
import Foundation
import CoreVideo
import QuartzCore
#if !os(macOS)
import UIKit
#endif

// Inspired by Imagine Engine

@globalActor public actor DisplayLinkActor {
    public static let shared = DisplayLinkActor()
}

public typealias FrameLoop = (id: UUID, action: () -> ())

public protocol DisplayLinkProtocol: AnyObject, Sendable {
    
    @MainActor
    var maxFps: Double { get }
    @DisplayLinkActor
    var fps: Double { get }
    
    @DisplayLinkActor
    var frameLoops: [FrameLoop] { get set }
    
    init(preferredFps: Float?)
    
    @discardableResult
    func listen(frameLoop: sending @escaping () -> ()) -> UUID
    func unlisten(id: UUID)
    func start()
    func stop()
}

extension DisplayLinkProtocol {
    
    @discardableResult
    public func listen(frameLoop: sending @escaping () -> ()) -> UUID {
        let id = UUID()
        Task { @DisplayLinkActor in
            frameLoops.append((id: id, action: frameLoop))
        }
        return id
    }
    
    public func unlisten(id: UUID) {
        Task { @DisplayLinkActor in
            frameLoops.removeAll(where: { $0.id == id })
        }
    }
}

#if !os(macOS)
public final class DisplayLink: DisplayLinkProtocol {
    
    @MainActor
    public var maxFps: Double {
        #if os(visionOS)
        90
        #else
        Double(UIScreen.main.maximumFramesPerSecond)
        #endif
    }
    
    @DisplayLinkActor
    public var fps: Double = 1.0

    @DisplayLinkActor
    public var frameLoops: [FrameLoop] = []

    @DisplayLinkActor
    private var link: CADisplayLink?
    
    @DisplayLinkActor
    private var lastFrameDate: Date?
    
    public init(preferredFps: Float? = 120) {
        Task { @DisplayLinkActor in
            link?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 10,
                maximum: 120,
                preferred: preferredFps
            )
            start()
        }
    }
    
    deinit {
        stop()
    }

    public func start() {
        Task { @DisplayLinkActor in
            if link == nil {
                link = CADisplayLink(target: self, selector: #selector(loop))
            }
            link?.add(to: .main, forMode: .common)
        }
    }
    
    public func stop()  {
        Task { @DisplayLinkActor in
            link?.remove(from: .main, forMode: .common)
        }
    }

    @objc private func loop() {
        Task { @DisplayLinkActor in
            if let date: Date = lastFrameDate {
                let time: Double = -date.timeIntervalSinceNow
                fps = 1.0 / time
            }
            lastFrameDate = Date()
        
            frameLoops.forEach { _, action in
                action()
            }
        }
    }
}
#endif

#if os(macOS)
public final class DisplayLink: DisplayLinkProtocol {
    
    @MainActor
    public var maxFps: Double {
        let id = CGMainDisplayID()
        guard let mode = CGDisplayCopyDisplayMode(id) else { return 60 }
        return mode.refreshRate
    }
    
    @DisplayLinkActor
    public var fps: Double = 1.0 {
        didSet {
            fpsContinuation?.yield(fps)
        }
    }
    @DisplayLinkActor
    private var fpsContinuation: AsyncStream<Double>.Continuation?
    public var fpsStream: AsyncStream<Double> {
        AsyncStream { continuation in
            Task { @DisplayLinkActor in
                fpsContinuation = continuation
            }
        }
    }
    
    @DisplayLinkActor
    public var frameLoops: [FrameLoop] = []
    
    @DisplayLinkActor
    private var link: CVDisplayLink?

    @DisplayLinkActor
    private var lastFrameDate: Date?
    
    public init(preferredFps: Float? = 120) {
        start()
    }
    
    deinit {
        guard let link = link else { return }
        CVDisplayLinkStop(link)
    }

    public func start() {
        Task { @DisplayLinkActor in
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
            
            guard let link = link else {
                return
            }
            
            let opaquePointerToSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkSetOutputCallback(link, _displayLinkCallback, opaquePointerToSelf)
            
            CVDisplayLinkStart(link)
        }
    }
    
    public func stop() {
        Task { @DisplayLinkActor in
            guard let link = link else { return }
            CVDisplayLinkStop(link)
        }
    }

    @objc func loop() {
        Task { @DisplayLinkActor in
            if let date: Date = lastFrameDate {
                let time: Double = -date.timeIntervalSinceNow
                fps = 1.0 / time
            }
            lastFrameDate = Date()
            
            frameLoops.forEach { _, action in
                action()
            }
        }
    }
}

private func _displayLinkCallback(
    displayLink: CVDisplayLink,
    _ now: UnsafePointer<CVTimeStamp>,
    _ outputTime: UnsafePointer<CVTimeStamp>,
    _ flagsIn: CVOptionFlags,
    _ flagsOut: UnsafeMutablePointer<CVOptionFlags>,
    _ displayLinkContext: UnsafeMutableRawPointer?
) -> CVReturn {
    unsafeBitCast(displayLinkContext, to: DisplayLink.self).loop()
    return kCVReturnSuccess
}
#endif
