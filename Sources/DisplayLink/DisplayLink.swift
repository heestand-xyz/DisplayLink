
import Foundation
import CoreVideo
import QuartzCore

// Inspired by Imagine Engine

internal protocol DisplayLinkProtocol: ObservableObject {
    
    var maxFps: Double { get }
    var fps: Double { get }
    
    var frameLoop: () -> () { get set }
    
    init()
    
    func start()
    func stop()
}

#if !os(macOS)
internal final class DisplayLink: DisplayLinkProtocol {
    
    var maxFps: Double {
        Double(link.preferredFramesPerSecond)
    }
    
    @Published var fps: Double = 1.0
    
    var frameLoop: () -> () = {}
    
    private lazy var link = CADisplayLink(target: self, selector: #selector(loop))
    
    private var lastFrameDate: Date?
    
    deinit {
        stop()
    }

    func start() {
        link.add(to: .main, forMode: .common)
    }
    
    func stop()  {
        link.remove(from: .main, forMode: .common)
    }

    @objc private func loop() {
        frameLoop()
        if let date: Date = lastFrameDate {
            let time: Double = -date.timeIntervalSinceNow
            fps = 1.0 / time
        }
        lastFrameDate = Date()
    }
}
#endif

#if os(macOS)
internal final class DisplayLink: DisplayLinkProtocol {
    
    var maxFps: Double {
        let id = CGMainDisplayID()
        guard let mode = CGDisplayCopyDisplayMode(id) else { return 1.0 }
        return mode.refreshRate
    }
    
    @Published var fps: Double = 1.0
    
    var frameLoop: () -> () = {}
    
    private var link: CVDisplayLink?

    private var lastFrameDate: Date?

    deinit {
        stop()
    }

    func start() {
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let link = link else {
            return
        }

        let opaquePointerToSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, _displayLinkCallback, opaquePointerToSelf)

        CVDisplayLinkStart(link)
    }
    
    func stop() {
        guard let link = link else { return }
        CVDisplayLinkStop(link)
    }

    @objc func loop() {
        DispatchQueue.main.async(execute: frameLoop)
        if let date: Date = lastFrameDate {
            let time: Double = -date.timeIntervalSinceNow
            fps = 1.0 / time
        }
        lastFrameDate = Date()
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
