import SwiftUI
import CoreML
import Vision
import AVFoundation

struct CoreMLDemo: View {
    @StateObject private var viewModel = CoreMLDemoViewModel()

    var body: some View {
        VStack {
            CameraView(session: viewModel.captureSession)
                .frame(height: 300) // Set the height for the camera preview

            Text(viewModel.prediction)
                .padding()
                .foregroundColor(.yellow) // Set the text color to yellow

            Text(viewModel.inferenceTime)
                .padding()
                .foregroundColor(.yellow) // Set the text color to yellow

            Button("Start Recognizing") {
                viewModel.startSession()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())

            Button("Stop Recognizing") {
                viewModel.stopSession()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(Capsule())

            Spacer()
        }
        .onAppear {
            viewModel.setupVision()
        }
        .onDisappear {
            viewModel.stopSession() // Ensure to stop the session when the view disappears
        }
    }
}

class CoreMLDemoViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var prediction = "Press 'Start Recognizing'"
    @Published var inferenceTime = "Inference Time: -"

    var captureSession = AVCaptureSession()
    private var requests = [VNRequest]()
    private var startTime: TimeInterval = 0

    func setupVision() {
        do {
            let config = MLModelConfiguration()
            let model = try Resnet50(configuration: config).model
            let visionModel = try VNCoreMLModel(for: model)
            let classificationRequest = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                guard let self = self else { return }
                let endTime = CACurrentMediaTime()
                if let classifications = request.results as? [VNClassificationObservation],
                   let topClassification = classifications.first {  // Only considering the top-1 result
                    DispatchQueue.main.async {
                        self.prediction = "\(topClassification.identifier) \nConfidence: \(topClassification.confidence)"
                        self.inferenceTime = String(format: "Inference Time: %.2f seconds", endTime - self.startTime)
                    }
                }
            }
            classificationRequest.imageCropAndScaleOption = .centerCrop
            self.requests = [classificationRequest]
        } catch {
            print("Error setting up Core ML model: \(error)")
        }
    }

    func startSession() {
        // 检查会话是否已经在运行，如果是，则先停止会话
        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        // 移除现有的所有输入和输出
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // 重新配置会话
        captureSession.beginConfiguration()
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Unable to access back camera!")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            print("Unable to add input")
            return
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        } else {
            print("Unable to add output")
            return
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }


    func stopSession() {
        captureSession.stopRunning()
        DispatchQueue.main.async {
            self.prediction = "Session Stopped"
            self.inferenceTime = "Inference Time: -"
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        startTime = CACurrentMediaTime() // Start time measurement just before processing
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? imageRequestHandler.perform(requests)
    }
}

struct CameraView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
