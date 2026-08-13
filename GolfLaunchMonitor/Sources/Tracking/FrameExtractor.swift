import AVFoundation
import CoreImage
import CoreGraphics

/// A single decoded video frame, downsampled and converted to 8-bit grayscale for
/// cheap frame-differencing. `scaleToFullRes` maps a pixel coordinate in this frame
/// back to the original recorded resolution (which is what CameraCalibration used).
struct GrayscaleFrame {
    let width: Int
    let height: Int
    let pixels: [UInt8]
    let timestamp: Double
    let scaleToFullRes: Double
}

enum FrameExtractionError: LocalizedError {
    case noVideoTrack
    case readerFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "The recording has no video track."
        case .readerFailed: return "Couldn't read the recorded video."
        }
    }
}

enum FrameExtractor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Decodes every frame of `url` in native sensor orientation (no rotation applied —
    /// CaptureSession locks recording to landscapeRight so sensor space and display
    /// space line up), downsampled to `workingWidth` for fast processing.
    static func extractGrayscaleFrames(from url: URL, workingWidth: Int = 480) async throws -> [GrayscaleFrame] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw FrameExtractionError.noVideoTrack
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw FrameExtractionError.readerFailed }
        reader.add(output)
        reader.startReading()

        let colorSpace = CGColorSpaceCreateDeviceGray()
        var frames: [GrayscaleFrame] = []

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let fullWidth = ciImage.extent.width
            let fullHeight = ciImage.extent.height
            guard fullWidth > 0, fullHeight > 0 else { continue }

            let scale = fullWidth / CGFloat(workingWidth)
            let workingHeight = max(1, Int(fullHeight / scale))

            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { continue }
            guard let context = CGContext(
                data: nil,
                width: workingWidth,
                height: workingHeight,
                bitsPerComponent: 8,
                bytesPerRow: workingWidth,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { continue }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: workingWidth, height: workingHeight))

            guard let data = context.data else { continue }
            let buffer = data.bindMemory(to: UInt8.self, capacity: workingWidth * workingHeight)
            let pixels = [UInt8](UnsafeBufferPointer(start: buffer, count: workingWidth * workingHeight))

            frames.append(GrayscaleFrame(
                width: workingWidth,
                height: workingHeight,
                pixels: pixels,
                timestamp: timestamp,
                scaleToFullRes: Double(scale)
            ))
        }

        if reader.status == .failed {
            throw FrameExtractionError.readerFailed
        }

        return frames
    }
}
