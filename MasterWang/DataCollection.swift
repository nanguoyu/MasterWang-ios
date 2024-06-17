//
//  DataCollection.swift
//  MasterWang
//
//  Created by Dong Wang on 2024/4/17.
//

import Foundation
import SwiftUI
import CoreMotion

struct DataCollectionView: View {
    @State private var isCollecting = false
    @State private var label: String = ""
    @State private var showAlert = false  // 添加一个状态来控制警告对话框的显示
    private let sensorDataPublisher = SensorDataPublisher()

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter label for action", text: $label)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(isCollecting ? "Stop Collecting" : "Start Collecting") {
                if label.isEmpty {
                    showAlert = true  // 如果标签为空，显示警告
                } else {
                    isCollecting.toggle()
                    if isCollecting {
                        sensorDataPublisher.startPublishing(label: label)
                    } else {
                        sensorDataPublisher.stopPublishing()
                    }
                }
            }
            .disabled(label.isEmpty) // 禁用按钮如果标签为空

            Button("Send Data") {
                sensorDataPublisher.sendData()
            }
            .disabled(!sensorDataPublisher.dataAvailable || isCollecting) // 禁用发送按钮如果数据不可用或仍在收集

            // 警告对话框
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Invalid Input"),
                    message: Text("Please enter a label before collecting data."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .padding()
    }
}



class SensorDataPublisher {
    private var motionManager = CMMotionManager()
    private var sensorData = [(deviceMotion: CMDeviceMotion, date: Date)]()
    private var label: String = ""
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS" // ISO8601 Format
        dateFormatter.timeZone = TimeZone.current
    }

    var dataAvailable: Bool {
        return !sensorData.isEmpty
    }

    func startPublishing(label: String) {
        self.label = label
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // sample rate = 50Hz
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (deviceMotion, error) in
                guard let strongSelf = self, let deviceMotion = deviceMotion else { return }
                strongSelf.sensorData.append((deviceMotion: deviceMotion, date: Date()))
            }
        }
    }

    func stopPublishing() {
        motionManager.stopDeviceMotionUpdates()
    }

    func sendData() {
        guard let url = URL(string: "https://macbook.wangdongdong.wang/sensor-data") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "label": self.label,
            "data": sensorData.map {
                let formattedDate = dateFormatter.string(from: $0.date)
                return [
                    "timestamp": formattedDate,
                    "ax": $0.deviceMotion.userAcceleration.x,
                    "ay": $0.deviceMotion.userAcceleration.y,
                    "az": $0.deviceMotion.userAcceleration.z,
                    "gx": $0.deviceMotion.rotationRate.x,
                    "gy": $0.deviceMotion.rotationRate.y,
                    "gz": $0.deviceMotion.rotationRate.z
                ]
            }
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending data: \(error)")
            } else {
                print("Data sent successfully")
            }
        }.resume()

        // 清除收集的数据
        sensorData.removeAll()
    }
}

struct DataCollection_Previews: PreviewProvider {
    static var previews: some View {
        DataCollectionView()
    }
}
