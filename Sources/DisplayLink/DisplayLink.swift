
import Foundation
import CoreVideo
import QuartzCore

// Inspired by Imagine Engine

public protocol DisplayLinkProtocol: ObservableObject {
    
    var maxFps: Double { get }
    var fps: Double { get }
    
    init()
    
    func listen(frameLoop: @escaping () -> ())
    func start()
    func stop()
}

#if !os(macOS)
public final class DisplayLink: DisplayLinkProtocol {
    
    public var maxFps: Double {
        Double(link.preferredFramesPerSecond)
    }
    
    @Published public var fps: Double = 1.0
    
    private var frameLoops: [() -> ()] = []

    private lazy var link = CADisplayLink(target: self, selector: #selector(loop))
    
    private var lastFrameDate: Date?
    
    public init() {
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
    
    public func listen(frameLoop: @escaping () -> ()) {
        frameLoops.append(frameLoop)
    }

    @objc private func loop() {
        
        if let date: Date = lastFrameDate {
            let time: Double = -date.timeIntervalSinceNow
            fps = 1.0 / time
        }
        lastFrameDate = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.frameLoops.forEach { frameLoop in
                frameLoop()
            }
        }
    }
}
#endif

#if os(macOS)
public final class DisplayLink: DisplayLinkProtocol {
    
    public var maxFps: Double {
        let id = CGMainDisplayID()
        guard let mode = CGDisplayCopyDisplayMode(id) else { return 1.0 }
        return mode.refreshRate
    }
    
    @Published public var fps: Double = 1.0
    
    private var frameLoops: [() -> ()] = []
    
    private var link: CVDisplayLink?

    private var lastFrameDate: Date?
    
    public init() {
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
    
    public func listen(frameLoop: @escaping () -> ()) {
        frameLoops.append(frameLoop)
    }

    @objc func loop() {
        
        if let date: Date = lastFrameDate {
            let time: Double = -date.timeIntervalSinceNow
            fps = 1.0 / time
        }
        lastFrameDate = Date()

        DispatchQueue.main.async { [weak self] in
            self?.frameLoops.forEach { frameLoop in
                frameLoop()
            }
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
