import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let captureSession: CaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        let layer = captureSession.startPreviewLayer()
        view.previewLayer = layer
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}

    final class PreviewContainerView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
