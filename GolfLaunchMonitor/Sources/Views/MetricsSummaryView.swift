import SwiftUI

/// Shared metrics display used by both the just-recorded results screen and the
/// history detail screen, so the two stay visually consistent.
struct MetricsSummaryView: View {
    let ballSpeedMPH: Double
    let launchAngleDegrees: Double
    let directionDegrees: Double
    let estimatedCarryYards: Double
    let confidenceLabel: String

    var directionText: String {
        let magnitude = abs(directionDegrees)
        if magnitude < 1.5 { return "Straight" }
        return String(format: "%.0f° %@", magnitude, directionDegrees < 0 ? "left" : "right")
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                metricTile(title: "Ball Speed", value: String(format: "%.0f", ballSpeedMPH), unit: "mph")
                metricTile(title: "Launch Angle", value: String(format: "%.1f", launchAngleDegrees), unit: "°")
            }
            HStack(spacing: 16) {
                metricTile(title: "Direction", value: directionText, unit: nil)
                metricTile(title: "Est. Carry", value: String(format: "%.0f", estimatedCarryYards), unit: "yds")
            }

            FlightSketchView(launchAngleDegrees: launchAngleDegrees, directionDegrees: directionDegrees)

            Text(confidenceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func metricTile(title: String, value: String, unit: String?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MetricsSummaryView(
        ballSpeedMPH: 128,
        launchAngleDegrees: 14.5,
        directionDegrees: -6,
        estimatedCarryYards: 214,
        confidenceLabel: "Good confidence"
    )
    .padding()
}
