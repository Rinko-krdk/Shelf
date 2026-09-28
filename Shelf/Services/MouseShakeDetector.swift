//
//  MouseShakeDetector.swift
//  Shelf
//

import AppKit
import Foundation

struct MouseShakeDetector {
    struct Configuration {
        var minimumHorizontalStep: CGFloat = 22
        var minimumTotalDistance: CGFloat = 150
        var requiredDirectionChanges = 3
        var maximumInterval: TimeInterval = 0.85
        var cooldown: TimeInterval = 1.4
    }

    private struct Sample {
        let x: CGFloat
        let time: TimeInterval
    }

    private let configuration: Configuration
    private var samples: [Sample] = []
    private var lastActivation: TimeInterval = -.infinity

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    mutating func recordDrag(at point: CGPoint, time: TimeInterval) -> Bool {
        guard time - lastActivation >= configuration.cooldown else { return false }
        if let last = samples.last, time - last.time > configuration.maximumInterval {
            samples.removeAll(keepingCapacity: true)
        }
        if let last = samples.last {
            guard abs(point.x - last.x) >= configuration.minimumHorizontalStep else { return false }
        }
        samples.append(Sample(x: point.x, time: time))

        while let first = samples.first,
              time - first.time > configuration.maximumInterval {
            samples.removeFirst()
        }

        let steps = zip(samples, samples.dropFirst()).map { previous, current in current.x - previous.x }
        guard !steps.isEmpty else { return false }
        let directionChanges = zip(steps, steps.dropFirst()).filter { $0.sign != $1.sign }.count
        let totalDistance = steps.reduce(CGFloat.zero) { $0 + abs($1) }
        guard directionChanges >= configuration.requiredDirectionChanges,
              totalDistance >= configuration.minimumTotalDistance else { return false }

        lastActivation = time
        samples.removeAll(keepingCapacity: true)
        return true
    }

    mutating func endDrag() {
        samples.removeAll(keepingCapacity: true)
    }
}

@MainActor
final class MouseShakeMonitor {
    private var detector: MouseShakeDetector
    private var monitor: Any?
    var onShake: (() -> Void)?

    init(detector: MouseShakeDetector? = nil) {
        self.detector = detector ?? MouseShakeDetector()
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseUp, .rightMouseUp, .otherMouseUp]
        ) { [weak self] event in
            let eventType = event.type
            let eventTime = event.timestamp
            let cursorPoint = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch eventType {
                case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                    detector.endDrag()
                default:
                    if detector.recordDrag(at: cursorPoint, time: eventTime) {
                        onShake?()
                    }
                }
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        detector.endDrag()
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
