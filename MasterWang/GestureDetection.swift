import Foundation
import SwiftUI
import CoreMotion
import CoreML
import Combine
import AVFoundation
import Network

struct GestureDetectionView: View {
    @State private var isRunning = false
    @State private var imuDataBuffer: [[Double]] = []
    @State private var cancellables = Set<AnyCancellable>()
    @State private var detectedGesture: String = "No Gesture Detected"
    @State private var showingScanner = false
    @State private var connection: NWConnection?
    @State private var connected = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var modelRunTimes: [Double] = []
    @State private var averageRunTime: Double = 0.0
    private let motionManager = CMMotionManager()
    private let publisher = PassthroughSubject<CMDeviceMotion, Never>()
    
    private let labels = ["Attack", "Jump", "Left", "Right"]

    var body: some View {
        VStack {
            Button(action: {
                self.toggleDataCollection()
            }) {
                Text(isRunning ? "Stop" : "Start")
                    .font(.largeTitle)
                    .padding()
                    .background(isRunning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                self.showingScanner = true
            }) {
                Text("Scan QR Code")
                    .font(.title)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Text(detectedGesture)
                .font(.title)
                .padding()
                .foregroundColor(.blue)
            
            Text(String(format: "Average Run Time: %.4f ms", averageRunTime))
                .font(.title)
                .padding()
                .foregroundColor(.black)
        }
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView { result in
                self.showingScanner = false
                switch result {
                case .success(let code):
                    self.processQRCode(code)
                case .failure(let error):
                    self.alertMessage = "Scanning failed: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Connection Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            self.stopIMUDataCollection()
        }
    }

    func toggleDataCollection() {
        if isRunning {
            stopIMUDataCollection()
        } else {
            startIMUDataCollection()
        }
        isRunning.toggle()
    }

    func startIMUDataCollection() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { (deviceMotion, error) in
                if let deviceMotion = deviceMotion {
                    self.publisher.send(deviceMotion)
                }
            }
            
            publisher
                .sink { deviceMotion in
                    let imuData = [
                        deviceMotion.userAcceleration.x,
                        deviceMotion.userAcceleration.y,
                        deviceMotion.userAcceleration.z,
                        deviceMotion.rotationRate.x,
                        deviceMotion.rotationRate.y,
                        deviceMotion.rotationRate.z
                    ]
                    
                    self.imuDataBuffer.append(imuData)
                    
                    // 保持数据缓冲区大小为 50
                    if self.imuDataBuffer.count > 50 {
                        self.imuDataBuffer.removeFirst()
                    }
                    
                    // 检测显著移动
                    if self.detectSignificantMovement(imuData) {
                        self.runModelIfNeeded()
                    }
                }
                .store(in: &cancellables)
        }
    }

    func stopIMUDataCollection() {
        motionManager.stopDeviceMotionUpdates()
        cancellables.removeAll()
        imuDataBuffer.removeAll()
        detectedGesture = "No Gesture Detected"
        isRunning = false
    }

    func detectSignificantMovement(_ imuData: [Double]) -> Bool {
        // 简单的阈值检测
        let threshold = 1.5
        let accelerationMagnitude = sqrt(imuData[0] * imuData[0] + imuData[1] * imuData[1] + imuData[2] * imuData[2])
        return accelerationMagnitude > threshold
    }

    func runModelIfNeeded() {
        // 只有当缓冲区满时才运行模型
        if imuDataBuffer.count == 50 {
            let startTime = DispatchTime.now()
            runCoreMLModel()
            let endTime = DispatchTime.now()
            let runTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0 // Convert to milliseconds
            modelRunTimes.append(runTime)
            updateAverageRunTime()
            print("Model Run Time: \(runTime) ms")
            imuDataBuffer.removeAll()  // 清理数据缓存
        }
    }

    func runCoreMLModel() {
        guard let model = try? newmodel(configuration: MLModelConfiguration()) else {
            print("Failed to load model")
            return
        }
        
        // 将 IMU 数据转换为 MultiArray
        guard let inputArray = try? MLMultiArray(shape: [1, 6, 50], dataType: .double) else {
            print("Failed to create MLMultiArray")
            return
        }
        
        for i in 0..<50 {
            for j in 0..<6 {
                inputArray[[0, j, i] as [NSNumber]] = NSNumber(value: imuDataBuffer[i][j])
            }
        }
        
        // 创建模型输入
        let modelInput = newmodelInput(x_1: inputArray)
        
        // 运行模型
        guard let prediction = try? model.prediction(input: modelInput) else {
            print("Failed to make prediction")
            return
        }
        
        // 获取并处理模型输出
        guard let outputArray = prediction.featureValue(for: "var_61")?.multiArrayValue else {
            print("Failed to get output")
            return
        }
        
        // 将 MLMultiArray 转换为 [Double]
        let output = (0..<outputArray.count).map { outputArray[$0].doubleValue }
        
        // 应用 softmax 函数
        let softmaxOutput = softmax(output)
        
        // 获取概率最高的类别
        if let maxIndex = softmaxOutput.firstIndex(of: softmaxOutput.max()!) {
            print(softmaxOutput)
            DispatchQueue.main.async {
                    self.detectedGesture = labels[maxIndex]
                    self.sendResultToServer(gesture: labels[maxIndex])
//                }
            }
        }
        
        // 运行完模型后清理显示的结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.detectedGesture = "No Gesture Detected"
        }
    }

    func softmax(_ x: [Double]) -> [Double] {
        let expX = x.map { exp($0) }
        let sumExpX = expX.reduce(0, +)
        return expX.map { $0 / sumExpX }
    }
    
    func sendResultToServer(gesture: String) {
        guard let connection = connection else {
            print("No connection available to send result")
            return
        }
        
        let message = gesture.data(using: .utf8) ?? Data()
        connection.send(content: message, completion: .contentProcessed({ error in
            if let error = error {
                print("Failed to send message: \(error.localizedDescription)")
            } else {
                print("Sent message: \(gesture)")
            }
        }))
    }

    func updateAverageRunTime() {
        let totalRunTime = modelRunTimes.reduce(0, +)
        averageRunTime = totalRunTime / Double(modelRunTimes.count)
    }
    
    func processQRCode(_ code: String) {
        // 假设二维码内容格式为 "ip:port"
        let components = code.split(separator: ":")
        if components.count == 2, let ip = components.first, let port = components.last, let portNumber = NWEndpoint.Port(String(port)) {
            print("Find server:", String(ip), portNumber)
            establishConnection(ip: String(ip), port: portNumber)
        } else {
            alertMessage = "Invalid QR code format"
            showAlert = true
        }
    }
    
    func establishConnection(ip: String, port: NWEndpoint.Port) {
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: port, using: .tcp)
        connection.stateUpdateHandler = { newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    print("Connected to \(ip):\(port)")
                    self.connected = true
                    self.alertMessage = "Connected to \(ip):\(port)"
                    self.showAlert = true
                case .failed(let error):
                    print("Failed to connect: \(error.localizedDescription)")
                    self.connected = false
                    self.alertMessage = "Failed to connect: \(error.localizedDescription)"
                    self.showAlert = true
                case .waiting(let error):
                    print("Connection waiting: \(error.localizedDescription)")
                    self.alertMessage = "Connection waiting: \(error.localizedDescription)"
                    self.showAlert = true
                case .setup:
                    print("Connection setup")
                case .cancelled:
                    print("Connection cancelled")
                    self.connected = false
                case .preparing:
                    print("Connection preparing")
                    self.alertMessage = "Connection preparing"
                    self.showAlert = true
                default:
                    break
                }
            }
        }
        connection.start(queue: .global())
        self.connection = connection
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    var didFindCode: (Result<String, QRCodeError>) -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let viewController = QRCodeScannerViewController()
        viewController.didFindCode = didFindCode
        context.coordinator.setupCaptureSession(for: viewController)
        return viewController
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}

    typealias UIViewControllerType = QRCodeScannerViewController

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView
        var captureSession: AVCaptureSession?

        init(parent: QRCodeScannerView) {
            self.parent = parent
            self.captureSession = AVCaptureSession()
        }

        func setupCaptureSession(for viewController: QRCodeScannerViewController) {
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                parent.didFindCode(.failure(.noCameraAvailable))
                return
            }
            let videoInput: AVCaptureDeviceInput

            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                parent.didFindCode(.failure(.initError(error)))
                return
            }

            if (captureSession?.canAddInput(videoInput) == true) {
                captureSession?.addInput(videoInput)
            } else {
                parent.didFindCode(.failure(.invalidDeviceInput))
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if (captureSession?.canAddOutput(metadataOutput) == true) {
                captureSession?.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                parent.didFindCode(.failure(.invalidMetadataOutput))
                return
            }

            viewController.captureSession = captureSession

            DispatchQueue.global(qos: .background).async {
                self.captureSession?.startRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject, let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.didFindCode(.success(stringValue))
                
                // 停止扫描
                captureSession?.stopRunning()
            }
        }
    }
}

class QRCodeScannerViewController: UIViewController {
    var didFindCode: ((Result<String, QRCodeError>) -> Void)?
    var captureSession: AVCaptureSession!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let captureSession = captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            DispatchQueue.global(qos: .background).async {
                captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession.isRunning) {
            captureSession.stopRunning()
        }
    }
}

enum QRCodeError: Error {
    case noCameraAvailable
    case initError(Error)
    case invalidDeviceInput
    case invalidMetadataOutput
}

struct GestureDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        GestureDetectionView()
    }
}
