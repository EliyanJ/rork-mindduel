import AVFoundation
import SwiftUI

/// Sheet that shows the player's own QR code (encoding their friend code as
/// a deep link) plus a camera scanner so a friend can be added instantly by
/// pointing a phone at either code — no typing required.
struct FriendQRView: View {
    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss
    @State private var isScannerPresented = false
    @State private var isShareSheetPresented = false
    @State private var toastMessage: String?

    private var deepLink: String {
        "minduel://friend/\(online.profile?.friendCode ?? "")"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                if let profile = online.profile {
                    VStack(spacing: 16) {
                        Text(profile.emoji)
                            .font(.system(size: 40))
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Theme.primary.opacity(0.12)))
                            .overlay(Circle().stroke(Theme.primary.opacity(0.3), lineWidth: 2))

                        if let image = QRCodeGenerator.image(from: deepLink) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 24).fill(.white))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.line, lineWidth: 1.5))
                                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                        }

                        VStack(spacing: 2) {
                            Text(profile.name)
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                            Text("@\(handle(from: profile.friendCode))")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.inkMuted)
                        }

                        Text("Fais scanner ce code à un ami pour l'ajouter instantanément.")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    Button {
                        Haptics.tap()
                        isShareSheetPresented = true
                    } label: {
                        Label("Partager mon code", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.card, textColor: Theme.ink))
                } else {
                    ProgressView().tint(Theme.primary)
                }

                Spacer(minLength: 0)

                Button {
                    Haptics.medium()
                    isScannerPresented = true
                } label: {
                    Label("Scanner un code ami", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))

                if let toastMessage {
                    Text(toastMessage)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.success)
                }
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Mon QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .sheet(isPresented: $isScannerPresented) {
                QRScannerView { scanned in
                    isScannerPresented = false
                    handleScanned(scanned)
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareLinkSheet(items: [deepLink])
            }
        }
    }

    private func handle(from code: String) -> String {
        code.replacingOccurrences(of: "#", with: "").lowercased()
    }

    private func handleScanned(_ payload: String) {
        guard let code = friendCode(from: payload) else { return }
        Task {
            let success = await online.addFriend(code: code)
            toastMessage = success ? "Demande envoyée ✅" : nil
            if success {
                Haptics.success()
                try? await Task.sleep(for: .seconds(2))
                toastMessage = nil
            } else {
                Haptics.error()
            }
        }
    }

    /// Accepts either a raw friend code or the `minduel://friend/<code>` deep
    /// link format produced by our own QR codes.
    private func friendCode(from payload: String) -> String? {
        if let url = URL(string: payload), url.scheme == "minduel", url.host == "friend" {
            return url.pathComponents.last
        }
        return payload.isEmpty ? nil : payload
    }
}

/// Minimal AVFoundation QR scanner: full-screen camera preview with a
/// viewfinder frame, calling back once with the first code it decodes.
private struct QRScannerView: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            QRScannerRepresentable { code in
                onScanned(code)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 240, height: 240)
                Spacer()
                Text("Vise le QR code de ton ami")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .background(Color.black)
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onScanned = onScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScanned: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var didEmit = false
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if !session.isRunning {
                Task.detached { [session] in session.startRunning() }
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            if session.isRunning {
                Task.detached { [session] in session.stopRunning() }
            }
        }

        private func configureSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didEmit,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            didEmit = true
            onScanned?(value)
        }
    }
}

/// Thin wrapper around `UIActivityViewController` for sharing the friend
/// deep link through any installed app.
private struct ShareLinkSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
