import Foundation

/// A ball position sample in full-resolution pixel coordinates (matching CameraCalibration).
struct TrackedPoint {
    let timestamp: Double
    let x: Double
    let y: Double
    let diameterPixels: Double
}

enum TrackingError: LocalizedError {
    case ballNotFoundAtAddress
    case launchNotDetected
    case insufficientFlightSamples

    var errorDescription: String? {
        switch self {
        case .ballNotFoundAtAddress:
            return "Couldn't spot the ball before the swing. Make sure it's clearly visible and well lit against the net."
        case .launchNotDetected:
            return "Didn't see the ball take off. Try again, keeping the ball in frame through impact."
        case .insufficientFlightSamples:
            return "Only tracked the ball for a frame or two after impact — not enough to estimate anything reliably. Try a clip where the ball stays visible a bit longer before it's out of frame."
        }
    }
}

/// Locates the ball at address in a static frame, detects the moment it's struck, then
/// tracks its position frame-by-frame through the first part of its flight.
enum BallTracker {
    static let minFlightSamples = 3

    static func track(from frames: [GrayscaleFrame]) throws -> [TrackedPoint] {
        guard frames.count > minFlightSamples else { throw TrackingError.insufficientFlightSamples }

        guard let address = locateAddressBall(in: frames) else {
            throw TrackingError.ballNotFoundAtAddress
        }

        guard let launchIndex = findLaunchFrameIndex(frames: frames, addressFrameIndex: address.frameIndex, addressBlob: address.blob) else {
            throw TrackingError.launchNotDetected
        }

        let flightPoints = trackFlight(frames: frames, startIndex: launchIndex, seedBlob: address.blob)
        guard flightPoints.count >= minFlightSamples else {
            throw TrackingError.insufficientFlightSamples
        }

        return flightPoints
    }

    /// Scans the first ~20% of the clip (address should happen early) for a bright,
    /// roughly circular, stationary blob — the resting ball.
    private static func locateAddressBall(in frames: [GrayscaleFrame]) -> (frameIndex: Int, blob: Blob)? {
        let searchWindow = max(minFlightSamples, frames.count / 5)

        for frameIndex in 0..<min(searchWindow, frames.count) {
            let frame = frames[frameIndex]
            let candidates = BlobDetector.brightBlobs(in: frame)
                .filter { $0.circularity > 0.55 && $0.diameter >= 3 && $0.diameter <= 80 }

            guard let best = candidates.max(by: { $0.circularity < $1.circularity }) else { continue }
            return (frameIndex, best)
        }
        return nil
    }

    /// Walks forward from address looking for a frame-diff blob near the ball's rest
    /// position whose displacement from address is large relative to the ball's own
    /// size — the signature of impact rather than a waggle or camera shake.
    private static func findLaunchFrameIndex(frames: [GrayscaleFrame], addressFrameIndex: Int, addressBlob: Blob) -> Int? {
        let displacementThreshold = addressBlob.diameter * 1.2
        let searchRadius = addressBlob.diameter * 6

        var previous = frames[addressFrameIndex]
        for i in (addressFrameIndex + 1)..<frames.count {
            let current = frames[i]
            guard current.width == previous.width, current.height == previous.height else {
                previous = current
                continue
            }

            let mask = BlobDetector.diffMask(previous.pixels, current.pixels)
            let blobs = BlobDetector.findBlobs(mask: mask, width: current.width, height: current.height)
                .filter { $0.circularity > 0.35 }

            for blob in blobs {
                let dx = blob.centroidX - addressBlob.centroidX
                let dy = blob.centroidY - addressBlob.centroidY
                let distanceFromAddress = (dx * dx + dy * dy).squareRoot()
                if distanceFromAddress <= searchRadius && distanceFromAddress >= displacementThreshold {
                    return i
                }
            }

            previous = current
        }
        return nil
    }

    /// From the launch frame onward, follow the nearest plausible blob frame-to-frame
    /// using a constant-velocity prediction once we have two points. Stops once the
    /// trail goes cold (ball out of frame, occluded by net, or too small to resolve).
    private static func trackFlight(frames: [GrayscaleFrame], startIndex: Int, seedBlob: Blob) -> [TrackedPoint] {
        var points: [TrackedPoint] = []
        var lastPosition = (x: seedBlob.centroidX, y: seedBlob.centroidY)
        var lastVelocity: (x: Double, y: Double)? = nil
        var missedFrames = 0

        var previousFrame = frames[max(0, startIndex - 1)]

        for i in startIndex..<frames.count {
            let frame = frames[i]
            guard frame.width == previousFrame.width, frame.height == previousFrame.height else {
                previousFrame = frame
                continue
            }

            let mask = BlobDetector.diffMask(previousFrame.pixels, frame.pixels, threshold: 20)
            let blobs = BlobDetector.findBlobs(mask: mask, width: frame.width, height: frame.height)
                .filter { $0.circularity > 0.25 }

            let predicted: (x: Double, y: Double)
            if let v = lastVelocity {
                predicted = (lastPosition.x + v.x, lastPosition.y + v.y)
            } else {
                predicted = lastPosition
            }

            let searchRadius = max(seedBlob.diameter * 3, 15)
            let match = blobs.min(by: { a, b in
                let da = distance(a.centroidX, a.centroidY, predicted.x, predicted.y)
                let db = distance(b.centroidX, b.centroidY, predicted.x, predicted.y)
                return da < db
            }).flatMap { blob -> Blob? in
                let d = distance(blob.centroidX, blob.centroidY, predicted.x, predicted.y)
                return d <= searchRadius ? blob : nil
            }

            previousFrame = frame

            guard let matched = match else {
                missedFrames += 1
                if missedFrames >= 2 { break }
                continue
            }
            missedFrames = 0

            let newVelocity = (x: matched.centroidX - lastPosition.x, y: matched.centroidY - lastPosition.y)
            lastVelocity = newVelocity
            lastPosition = (matched.centroidX, matched.centroidY)

            points.append(TrackedPoint(
                timestamp: frame.timestamp,
                x: matched.centroidX * frame.scaleToFullRes,
                y: matched.centroidY * frame.scaleToFullRes,
                diameterPixels: matched.diameter * frame.scaleToFullRes
            ))
        }

        return points
    }

    private static func distance(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        let dx = x1 - x2, dy = y1 - y2
        return (dx * dx + dy * dy).squareRoot()
    }
}
