import AVFoundation
import SwiftUI

/// The camera, looking for Nocturnal's pairing QR code, drawn right on the page. Reports the first code it reads.
/// Without a camera (the simulator) or without permission it says so plainly, and pasting the code still works.
struct CameraFinder: View {
    let found: (String) -> Void
    @State private var denied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
    private let hasCamera = AVCaptureDevice.default(for: .video) != nil

    var body: some View {
        ZStack {
            Theme.night.opacity(0.55)
            if !hasCamera {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill").font(.system(size: 28, weight: .semibold))
                    Text("No camera here").font(.headline)
                }
            } else if denied {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill").font(.system(size: 28, weight: .semibold))
                    Text("Camera is off for Nocturnal").font(.headline)
                    Button("Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .glassEffect(.clear.interactive(), in: .capsule)
                        .buttonStyle(Press())
                }
            } else {
                CameraView(found: found, denied: { denied = true })
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera viewfinder")
    }
}

private struct CameraView: UIViewRepresentable {
    let found: (String) -> Void
    let denied: () -> Void

    func makeCoordinator() -> Scanner { Scanner(found: found) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = context.coordinator.session
        AVCaptureDevice.requestAccess(for: .video) { ok in
            Task { @MainActor in ok ? context.coordinator.start(preview: view.previewLayer) : denied() }
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    static func dismantleUIView(_ view: PreviewView, coordinator: Scanner) { coordinator.stop() }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Scanner: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        /// Starting and stopping block while the camera spins up; one serial queue keeps them in order, so a
        /// quick Cancel can't land before the start and leave the camera on.
        private let cameraQueue = DispatchQueue(label: "nocturnal.camera")
        private let found: (String) -> Void
        private var done = false
        /// Keeps the picture upright however the phone is held or (on iPhone Duo) folded, opened or turned.
        private var rotation: AVCaptureDevice.RotationCoordinator?
        private var rotationWatch: NSKeyValueObservation?

        init(found: @escaping (String) -> Void) { self.found = found }

        func start(preview: AVCaptureVideoPreviewLayer) {
            guard session.inputs.isEmpty, let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return }
            session.addInput(input)
            let r = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: preview)
            rotation = r
            rotationWatch = r.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak preview] r, _ in
                let angle = r.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async {
                    if let c = preview?.connection, c.isVideoRotationAngleSupported(angle) { c.videoRotationAngle = angle }
                }
            }
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            let s = session
            cameraQueue.async { s.startRunning() }
        }

        func stop() {
            rotationWatch = nil
            let s = session
            cameraQueue.async { s.stopRunning() }
        }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let text = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            MainActor.assumeIsolated {
                guard !done else { return }
                done = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                found(text)
            }
        }
    }
}
