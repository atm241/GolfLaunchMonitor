import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shot.date, order: .reverse) private var shots: [Shot]

    var body: some View {
        NavigationStack {
            Group {
                if shots.isEmpty {
                    ContentUnavailableView(
                        "No Shots Yet",
                        systemImage: "figure.golf",
                        description: Text("Recorded shots you save will show up here.")
                    )
                } else {
                    List {
                        ForEach(shots) { shot in
                            NavigationLink(value: shot) {
                                row(for: shot)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Shot.self) { shot in
                ShotDetailView(shot: shot)
            }
        }
    }

    private func row(for shot: Shot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(shot.ballSpeedMPH)) mph")
                    .font(.headline)
                Text(shot.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(shot.estimatedCarryYards)) yds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(shots[index])
        }
    }
}

struct ShotDetailView: View {
    let shot: Shot

    var body: some View {
        ScrollView {
            MetricsSummaryView(
                ballSpeedMPH: shot.ballSpeedMPH,
                launchAngleDegrees: shot.launchAngleDegrees,
                directionDegrees: shot.directionDegrees,
                estimatedCarryYards: shot.estimatedCarryYards,
                confidenceLabel: (TrackConfidence(rawValue: shot.confidence) ?? .low).label
            )
            .padding()
        }
        .navigationTitle(shot.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: Shot.self, inMemory: true)
}
