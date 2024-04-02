
import Foundation
import CoreVideo
import QuartzCore
#if !os(macOS)
import UIKit
#endif

// Inspired by Imagine Engine

public typealias FrameLoop = (id: UUID, action: () -> ())

public protocol DisplayLinkProtocol: ObservableObject {
    
    var maxFps: Double { get }
    var fps: Double { get }
    
    var frameLoops: [FrameLoop] { get set }
    
    init(preferredFps: Float?)
    
    @discardableResult
    func listen(frameLoop: @escaping () -> ()) -> UUID
    func unlisten(id: UUID)
    func start()
    func stop()
}

extension DisplayLinkProtocol {
    
    @discardableResult
    public func listen(frameLoop: @escaping () -> ()) -> UUID {
        let id = UUID()
        frameLoops.append((id: id, action: frameLoop))
        return id
    }
    
    public func unlisten(id: UUID) {
        frameLoops.removeAll(where: { $0.id == id })
    }
}

#if !os(macOS)
public final class DisplayLink: DisplayLinkProtocol {
    
    public var maxFps: Double {
        #if os(visionOS)
        90
        #else
        Double(UIScreen.main.maximumFramesPerSecond)
        #endif
    }
    
    @Published public var fps: Double = 1.0
    
    public var frameLoops: [FrameLoop] = []

    private lazy var link = CADisplayLink(target: self, selector: #selector(loop))
    
    private var lastFrameDate: Date?
    
    public init(preferredFps: Float? = 120) {
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 10,
                                                            maximum: 120,
                                                            preferred: preferredFps)
        }
        start()
    }
    
    deinit {
        stop()
    }

    public func start() {
        link.add(to: .main, forMode: .common)
    }
    
    public func stop()  {
        link.remove(from: .main, forMode: .common)
    }

    @objc private func loop() {
        
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
#endif

#if os(macOS)
public final class DisplayLink: DisplayLinkProtocol {
    
    public var maxFps: Double {
        let id = CGMainDisplayID()
        guard let mode = CGDisplayCopyDisplayMode(id) else { return 60 }
        return mode.refreshRate
    }
    
    @Published public var fps: Double = 1.0
    
    public var frameLoops: [FrameLoop] = []
    
    private var link: CVDisplayLink?

    private var lastFrameDate: Date?
    
    public init(preferredFps: Float? = 120) {
        start()
    }
    
    deinit {
        stop()
    }

    public func start() {
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let link = link else {
            return
        }

        let opaquePointerToSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, _displayLinkCallback, opaquePointerToSelf)

        CVDisplayLinkStart(link)
    }
    
    public func stop() {
        guard let link = link else { return }
        CVDisplayLinkStop(link)
    }

    @objc func loop() {
        
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

private func _displayLinkCallback(displayLink: CVDisplayLink,
                                  _ now: UnsafePointer<CVTimeStamp>,
                                  _ outputTime: UnsafePointer<CVTimeStamp>,
                                  _ flagsIn: CVOptionFlags,
                                  _ flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                  _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
    unsafeBitCast(displayLinkContext, to: DisplayLink.self).loop()
    return kCVReturnSuccess
}
#endif
