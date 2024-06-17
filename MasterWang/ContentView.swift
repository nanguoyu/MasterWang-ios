//
//  ContentView.swift
//  MasterWang
//
//  Created by Dong Wang on 2024/3/24.
//

import SwiftUI
import CoreMotion



struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image("Background")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 5)
                    .padding(.horizontal, 20)
                List {
                    NavigationLink(destination: SensorDataView()) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            Text("Sensor Data")
                        }
                    }
                    NavigationLink(destination: PhotoCaptureScreen()) {
                        HStack {
                            Image(systemName: "camera")
                                .resizable()
                                .aspectRatio(contentMode: .fit) 
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            Text("Take Photo")
                        }
                    }

                    NavigationLink(destination: CoreMLDemo()) {
                        HStack {
                            Image(systemName: "eye")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            Text("CoreML Demo")
                        }
                    }
                    NavigationLink(destination: DataCollectionView()) {
                        HStack {
                            Image(systemName: "sensor")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            Text("Data Collection")
                        }
                    }
                    NavigationLink(destination: GestureDetectionView()) {
                        HStack {
                            Image(systemName: "sensor")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            Text("Gesture Detection")
                        }
                    }
                }
                .navigationTitle("Features")
            }
        }
    }
}


//#Preview {
//    ContentView()
//}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
