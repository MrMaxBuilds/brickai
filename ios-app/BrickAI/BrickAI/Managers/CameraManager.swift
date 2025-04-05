//
//  CameraManager.swift
//  Epic Shots
//
//  Created by Max U on 3/28/25.
//

import AVFoundation
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    @Published var recentImage: UIImage?
    @Published var isPhotoCaptured = false
    
    let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let photoOutput = AVCapturePhotoOutput()
    
    private override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }
    
    // Added to recheck permission when the app resumes
    func recheckPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        default:
            permissionGranted = false
        }
    }
    
    func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                            for: .video,
                                                            position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                // Optionally set cameraAvailable = false here in the future
                return
            }
            
            self.session.addInput(videoDeviceInput)
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            self.session.commitConfiguration()
            // Removed session.startRunning() from here; managed in HomeView instead
        }
    }
    
    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func saveImageToDocuments(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).jpg")
        try? data.write(to: filename)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Added to reset capture state and free memory
    func resetCaptureState() {
        isPhotoCaptured = false
        recentImage = nil
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.recentImage = image
                self.isPhotoCaptured = true
                self.saveImageToDocuments(image)
            }
        }
    }
}
