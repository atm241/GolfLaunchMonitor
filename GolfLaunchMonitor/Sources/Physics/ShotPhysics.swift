import Foundation

struct ShotMetrics {
    let ballSpeedMPH: Double
    let launchAngleDegrees: Double
    let directionDegrees: Double // negative = left, positive = right
    let estimatedCarryYards: Double
    let sampleCount: Int

    var confidence: TrackConfidence {
        switch sampleCount {
        case ..<4: return .low
        case 4...7: return .medium
        default: return .high
        }
    }
}

/// Converts a pixel-space ball track into real-world flight metrics for a camera
/// mounted behind the ball facing the target.
///
/// The key trick: a golf ball's real diameter is fixed and known (42.7mm), so its
/// shrinking pixel diameter as it flies away from the camera lets us solve for depth
/// (distance from camera) frame by frame via similar triangles — turning one 2D pixel
/// track into a 3D position track from a single lens, without any manual calibration.
enum ShotPhysics {
    static let realBallDiameterMeters = 0.04267
    private static let gravity = 9.81 // m/s^2

    /// Vacuum projectile range undershoots real drag losses but overshoots because it
    /// ignores drag entirely while golf ball lift from backspin (which we can't measure)
    /// partially offsets that. This fixed efficiency factor is a rough middle ground
    /// tuned against typical mid-iron/driver carry numbers — treat carry as a ballpark
    /// estimate, not a measurement, since real carry depends heavily on spin we don't track.
    private static let carryEfficiencyFactor = 0.62

    static func computeMetrics(track: [TrackedPoint], calibration: CameraCalibration) -> ShotMetrics? {
        guard track.count >= BallTracker.minFlightSamples else { return nil }

        let f = calibration.focalLengthPixels
        let cx = Double(calibration.imageWidthPixels) / 2.0
        let cy = Double(calibration.imageHeightPixels) / 2.0

        // Reconstruct a 3D position (meters) for each sample using the ball's known
        // real-world size vs. its measured pixel size at that frame.
        var times: [Double] = []
        var xs: [Double] = [] // lateral, +right
        var ys: [Double] = [] // vertical, +up
        var zs: [Double] = [] // depth from camera, +away

        for point in track {
            guard point.diameterPixels > 0 else { continue }
            let depth = (realBallDiameterMeters * f) / point.diameterPixels
            let x = (point.x - cx) * depth / f
            let y = (cy - point.y) * depth / f // image y grows downward; flip so +y is up

            times.append(point.timestamp)
            xs.append(x)
            ys.append(y)
            zs.append(depth)
        }

        guard times.count >= BallTracker.minFlightSamples else { return nil }

        // Least-squares slope of each axis vs. time = that axis's velocity component.
        // Over the short, close-to-launch window we're tracking, treating flight as
        // locally linear (ignoring gravity's curvature) is a reasonable approximation.
        let t0 = times[0]
        let relativeTimes = times.map { $0 - t0 }

        let vx = linearRegressionSlope(t: relativeTimes, v: xs)
        let vy = linearRegressionSlope(t: relativeTimes, v: ys)
        let vz = linearRegressionSlope(t: relativeTimes, v: zs)

        let speedMPS = (vx * vx + vy * vy + vz * vz).squareRoot()
        guard speedMPS.isFinite, speedMPS > 0 else { return nil }

        let launchAngleRad = atan2(vy, vz)
        let directionRad = atan2(vx, vz)

        let launchAngleDeg = launchAngleRad * 180 / .pi
        let directionDeg = directionRad * 180 / .pi

        let vacuumRangeMeters = (speedMPS * speedMPS * sin(2 * launchAngleRad)) / gravity
        let carryMeters = max(0, vacuumRangeMeters * carryEfficiencyFactor)

        return ShotMetrics(
            ballSpeedMPH: speedMPS * 2.23694,
            launchAngleDegrees: launchAngleDeg,
            directionDegrees: directionDeg,
            estimatedCarryYards: carryMeters * 1.09361,
            sampleCount: track.count
        )
    }

    private static func linearRegressionSlope(t: [Double], v: [Double]) -> Double {
        let n = Double(t.count)
        guard n > 1 else { return 0 }
        let sumT = t.reduce(0, +)
        let sumV = v.reduce(0, +)
        let sumTV = zip(t, v).reduce(0) { $0 + $1.0 * $1.1 }
        let sumTT = t.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumTT - sumT * sumT
        guard abs(denominator) > 1e-9 else { return 0 }
        return (n * sumTV - sumT * sumV) / denominator
    }
}
