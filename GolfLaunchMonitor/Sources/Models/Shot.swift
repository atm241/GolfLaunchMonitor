import Foundation
import SwiftData

@Model
final class Shot {
    var date: Date
    var ballSpeedMPH: Double
    var launchAngleDegrees: Double
    var directionDegrees: Double // negative = left of target line, positive = right
    var estimatedCarryYards: Double
    var trackedFrameCount: Int
    var confidence: TrackConfidence.RawValue

    init(
        date: Date = .now,
        ballSpeedMPH: Double,
        launchAngleDegrees: Double,
        directionDegrees: Double,
        estimatedCarryYards: Double,
        trackedFrameCount: Int,
        confidence: TrackConfidence
    ) {
        self.date = date
        self.ballSpeedMPH = ballSpeedMPH
        self.launchAngleDegrees = launchAngleDegrees
        self.directionDegrees = directionDegrees
        self.estimatedCarryYards = estimatedCarryYards
        self.trackedFrameCount = trackedFrameCount
        self.confidence = confidence.rawValue
    }
}

/// Rough self-reported quality signal for a shot's tracked data, based on how many
/// frames the ball was actually seen in. This is not a statistical confidence interval —
/// just a hint to the user about whether to trust the number.
enum TrackConfidence: String, Codable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: return "Low confidence"
        case .medium: return "Medium confidence"
        case .high: return "Good confidence"
        }
    }
}
