import AVFoundation
import UIKit

/// Everything ShotPhysics needs to turn pixel measurements into real-world units,
/// captured at record time since it depends on which camera/format was actually selected.
struct CameraCalibration {
    let focalLengthPixels: Double
    let imageWidthPixels: Int
    let imageHeightPixels: Int
    let framesPerSecond: Double
}

struct RecordingResult {
    let fileURL: URL
    let calibration: CameraCalibration
}

enum CaptureError: LocalizedError {
    case noCameraAvailable
    case noSlowMotionFormat
    case configurationFailed
    case notRecording

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: return "No back camera is available on this device."
        case .noSlowMotionFormat: return "This device doesn't expose a high-frame-rate format; falling back to standard speed will hurt accuracy."
        case .configurationFailed: return "Couldn't configure the camera session."
        case .notRecording: return "Not currently recording."
        }
    }
}

/// Owns the AVCaptureSession, picks the highest-frame-rate format available on the back
/// camera (slow motion), and records swings to a temp file for later frame-by-frame analysis.
final class CaptureSession: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isConfigured = false
    @Published var selectedFrameRate: Double = 0
    @Published var lastError: CaptureError?

    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private let movieOutput = AVCaptureMovieFileOutput()
    private var onFinish: ((Result<RecordingResult, Error>) -> Void)?
    private var pendingCalibration: CameraCalibration?

    func configure() {
        session.beginConfiguration()
        session.sessionPreset = .inputPriority

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            lastError = .noCameraAvailable
            session.commitConfiguration()
            return
        }
        device = camera

        guard let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            lastError = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        guard session.canAddOutput(movieOutput) else {
            lastError = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addOutput(movieOutput)

        // Lock to landscapeRight (unrotated sensor orientation) so decoded frame buffers
        // during analysis line up 1:1 with the calibration's raw sensor dimensions —
        // avoids reasoning about AVAsset preferredTransform rotation later. The app UI
        // instructs the user to mount the phone in landscape.
        if let connection = movieOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .landscapeRight
        }

        applyBestSlowMotionFormat(to: camera)

        session.commitConfiguration()
        isConfigured = true
    }

    /// Finds the format with the highest supported frame rate (ideally 240fps, the
    /// iPhone slow-mo standard) and locks the device to it.
    private func applyBestSlowMotionFormat(to camera: AVCaptureDevice) {
        let candidates = camera.formats.compactMap { format -> (AVCaptureDevice.Format, Double)? in
            guard let maxRange = format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) else {
                return nil
            }
            return (format, maxRange.maxFrameRate)
        }

        guard let best = candidates.max(by: { $0.1 < $1.1 }) else {
            lastError = .noSlowMotionFormat
            return
        }

        let (format, maxFPS) = best
        do {
            try camera.lockForConfiguration()
            camera.activeFormat = format
            let duration = CMTimeMake(value: 1, timescale: Int32(maxFPS))
            camera.activeVideoMinFrameDuration = duration
            camera.activeVideoMaxFrameDuration = duration
            camera.unlockForConfiguration()

            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let fovDegrees = Double(format.videoFieldOfView)
            let focalLengthPixels = (Double(dims.width) / 2.0) / tan(fovDegrees * .pi / 360.0)

            selectedFrameRate = maxFPS
            pendingCalibration = CameraCalibration(
                focalLengthPixels: focalLengthPixels,
                imageWidthPixels: Int(dims.width),
                imageHeightPixels: Int(dims.height),
                framesPerSecond: maxFPS
            )
        } catch {
            lastError = .configurationFailed
        }
    }

    func startPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func startRecording(completion: @escaping (Result<RecordingResult, Error>) -> Void) {
        guard !movieOutput.isRecording else { return }
        // AVCaptureMovieFileOutput throws an uncaught Objective-C exception (not a Swift
        // error) if asked to record with no active video connection — e.g. no camera was
        // available at configure() time. Guard explicitly so that case surfaces as a normal
        // error instead of crashing the app.
        guard isConfigured, let connection = movieOutput.connection(with: .video), connection.isActive else {
            completion(.failure(lastError ?? CaptureError.configurationFailed))
            return
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        onFinish = completion
        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }
}

extension CaptureSession: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false
        if let error {
            onFinish?(.failure(error))
        } else if let calibration = pendingCalibration {
            onFinish?(.success(RecordingResult(fileURL: outputFileURL, calibration: calibration)))
        } else {
            onFinish?(.failure(CaptureError.configurationFailed))
        }
        onFinish = nil
    }
}
