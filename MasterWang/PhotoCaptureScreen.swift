//
//  PhotoCaptureScreen.swift
//  MasterWang
//
//  Created by Dong Wang on 2024/3/27.
//

import Foundation
import SwiftUI

struct PhotoCaptureScreen: View {
    @State private var isShowingPhotoCaptureView = false
    @State private var capturedImage: UIImage? // This will hold the captured image

    var body: some View {
        VStack {
            // Display the captured image if available
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300) // Adjust the frame size as needed
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                // Placeholder content
                Text("Tap 'Take Photo' to capture an image.")
                    .foregroundColor(.secondary)
            }

            Button("Take Photo") {
                isShowingPhotoCaptureView = true
            }
            .padding()
            .background(Capsule().foregroundColor(.blue))
            .foregroundColor(.white)
        }
        .padding()
        .sheet(isPresented: $isShowingPhotoCaptureView) {
            PhotoCaptureView(image: $capturedImage) // Binding capturedImage to PhotoCaptureView
        }
        .navigationTitle("Take a Photo")
        .navigationBarTitleDisplayMode(.inline)
    }
}
