import SwiftUI

struct ResultsView: View {
    let metrics: ShotMetrics
    let onSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MetricsSummaryView(
                    ballSpeedMPH: metrics.ballSpeedMPH,
                    launchAngleDegrees: metrics.launchAngleDegrees,
                    directionDegrees: metrics.directionDegrees,
                    estimatedCarryYards: metrics.estimatedCarryYards,
                    confidenceLabel: metrics.confidence.label
                )
                .padding(.top)

                HStack(spacing: 16) {
                    Button("Discard", role: .destructive, action: onDiscard)
                        .buttonStyle(.bordered)
                    Button("Save Shot", action: onSave)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ResultsView(
        metrics: ShotMetrics(
            ballSpeedMPH: 132,
            launchAngleDegrees: 12.4,
            directionDegrees: 5,
            estimatedCarryYards: 221,
            sampleCount: 9
        ),
        onSave: {},
        onDiscard: {}
    )
}
