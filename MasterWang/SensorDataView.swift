//
//  SensorDataView.swift
//  MasterWang
//
//  Created by Dong Wang on 2024/3/27.
//

//import Foundation
import SwiftUI
import CoreMotion

struct SensorDataView: View {
    @StateObject private var sensorDataModel = SensorDataModel()

    var body: some View {
        List {
            if let accelerometerData = sensorDataModel.accelerometerData {
                Text("Accelerometer: x: \(accelerometerData.acceleration.x), y: \(accelerometerData.acceleration.y), z: \(accelerometerData.acceleration.z)")
            }
            if let gyroscopeData = sensorDataModel.gyroscopeData {
                Text("Gyroscope: x: \(gyroscopeData.rotationRate.x), y: \(gyroscopeData.rotationRate.y), z: \(gyroscopeData.rotationRate.z)")
            }
        }
    }
}
