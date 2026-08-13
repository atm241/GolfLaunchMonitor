import SwiftUI
import AVFoundation
import SwiftData

enum RecordFlowState {
    case requestingPermission
    case permissionDenied
    case ready
    case recording
    case processing
    case results(ShotMetrics)
    case failure(String)
}

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var captureSession = CaptureSession()
    @State private var state: RecordFlowState = .requestingPermission
    @State private var pendingCalibration: CameraCalibration?

    var body: some View {
        NavigationStack {
            ZStack {
                switch state {
                case .requestingPermission:
                    ProgressView("Checking camera access…")

                case .permissionDenied:
                    permissionDeniedView

                case .ready, .recording:
                    cameraView

                case .processing:
                    ProgressView("Analyzing swing…")
                        .font(.headline)

                case .results(let metrics):
                    ResultsView(metrics: metrics, onSave: {
                        save(metrics)
                        state = .ready
                    }, onDiscard: {
                        state = .ready
                    })

                case .failure(let message):
                    failureView(message)
                }
            }
            .navigationTitle("Record")
            .task {
                await requestPermissionAndConfigure()
            }
        }
    }

    private var cameraView: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(captureSession: captureSession)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if captureSession.selectedFrameRate > 0 {
                    Text("\(Int(captureSession.selectedFrameRate)) fps slow motion")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Button(action: toggleRecording) {
                    Circle()
                        .fill(state.isRecording ? Color.red : Color.white)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().stroke(.white, lineWidth: 4).padding(-6))
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Camera access is needed to record swings.")
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding()
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                state = .ready
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func requestPermissionAndConfigure() async {
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }

        guard granted else {
            state = .permissionDenied
            return
        }

        captureSession.configure()
        captureSession.start()
        state = .ready
    }

    private func toggleRecording() {
        switch state {
        case .ready:
            state = .recording
            captureSession.startRecording { result in
                Task { await handleRecordingFinished(result) }
            }
        case .recording:
            captureSession.stopRecording()
        default:
            break
        }
    }

    private func handleRecordingFinished(_ result: Result<RecordingResult, Error>) async {
        switch result {
        case .failure(let error):
            state = .failure(error.localizedDescription)
        case .success(let recording):
            state = .processing
            await processRecording(recording)
        }
    }

    private func processRecording(_ recording: RecordingResult) async {
        do {
            let frames = try await FrameExtractor.extractGrayscaleFrames(from: recording.fileURL)
            let track = try BallTracker.track(from: frames)
            guard let metrics = ShotPhysics.computeMetrics(track: track, calibration: recording.calibration) else {
                state = .failure("Tracked the ball but couldn't compute reliable metrics from that clip. Try again.")
                return
            }
            state = .results(metrics)
        } catch {
            state = .failure(error.localizedDescription)
        }

        try? FileManager.default.removeItem(at: recording.fileURL)
    }

    private func save(_ metrics: ShotMetrics) {
        let shot = Shot(
            ballSpeedMPH: metrics.ballSpeedMPH,
            launchAngleDegrees: metrics.launchAngleDegrees,
            directionDegrees: metrics.directionDegrees,
            estimatedCarryYards: metrics.estimatedCarryYards,
            trackedFrameCount: metrics.sampleCount,
            confidence: metrics.confidence
        )
        modelContext.insert(shot)
    }
}

private extension RecordFlowState {
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

#Preview {
    RecordView()
}
