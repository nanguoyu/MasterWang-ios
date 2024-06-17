//
//  SensorDataModel.swift
//  MasterWang
//
//  Created by Dong Wang on 2024/3/27.
//
import CoreMotion
// 传感器数据模型
class SensorDataModel: ObservableObject {
    @Published var accelerometerData: CMAccelerometerData?
    @Published var gyroscopeData: CMGyroData?
    
    private var motionManager: CMMotionManager
    
    init() {
        self.motionManager = CMMotionManager()
        self.startSensors()
    }
    
    func startSensors() {
        // 确保设备有加速度计和陀螺仪
        if motionManager.isAccelerometerAvailable && motionManager.isGyroAvailable {
            motionManager.accelerometerUpdateInterval = 1 / 60 // 60 Hz
            motionManager.gyroUpdateInterval = 1 / 60 // 60 Hz
            
            // 启动加速度计
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, error == nil else { return }
                self?.accelerometerData = data
            }
            
            // 启动陀螺仪
            motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, error == nil else { return }
                self?.gyroscopeData = data
            }
        }
    }
}
