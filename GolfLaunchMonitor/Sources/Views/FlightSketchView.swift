import SwiftUI

/// A simple top-down + side-profile sketch of the estimated flight — not to scale,
/// just enough to see shot shape and trajectory at a glance.
struct FlightSketchView: View {
    let launchAngleDegrees: Double
    let directionDegrees: Double

    var body: some View {
        VStack(spacing: 16) {
            labeledSketch(title: "Top-down (left/right)") { size in
                Canvas { context, canvasSize in
                    drawTopDown(context: context, size: canvasSize)
                }
            }
            labeledSketch(title: "Side profile (launch angle)") { size in
                Canvas { context, canvasSize in
                    drawSideProfile(context: context, size: canvasSize)
                }
            }
        }
    }

    private func labeledSketch<Content: View>(title: String, @ViewBuilder content: (CGSize) -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content(CGSize(width: 200, height: 90))
                .frame(height: 90)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func drawTopDown(context: GraphicsContext, size: CGSize) {
        let start = CGPoint(x: size.width / 2, y: size.height - 8)
        let clampedDirection = max(-45, min(45, directionDegrees))
        let angleFromVertical = clampedDirection * .pi / 180
        let length = size.height - 16
        let end = CGPoint(
            x: start.x + length * sin(angleFromVertical),
            y: start.y - length * cos(angleFromVertical)
        )

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(.accentColor), lineWidth: 3)

        var centerLine = Path()
        centerLine.move(to: CGPoint(x: size.width / 2, y: size.height))
        centerLine.addLine(to: CGPoint(x: size.width / 2, y: 0))
        context.stroke(centerLine, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        context.fill(Path(ellipseIn: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)), with: .color(.accentColor))
    }

    private func drawSideProfile(context: GraphicsContext, size: CGSize) {
        let start = CGPoint(x: 12, y: size.height - 8)
        let clampedAngle = max(0, min(60, launchAngleDegrees))
        let angleRad = clampedAngle * .pi / 180
        let length = size.width - 24
        let end = CGPoint(
            x: start.x + length * cos(angleRad),
            y: start.y - length * sin(angleRad)
        )

        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: size.height - 8))
        ground.addLine(to: CGPoint(x: size.width, y: size.height - 8))
        context.stroke(ground, with: .color(.secondary.opacity(0.3)))

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(.accentColor), lineWidth: 3)
        context.fill(Path(ellipseIn: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)), with: .color(.accentColor))
    }
}

#Preview {
    FlightSketchView(launchAngleDegrees: 18, directionDegrees: -8)
        .padding()
}
