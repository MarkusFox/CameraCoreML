//
//  CameraViewController.swift
//  CameraCoreML
//
//  Created by Markus Fox on 28.02.18.
//  Copyright © 2018 Markus Fox. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet var cameraView: UIView!
    @IBOutlet var predictionLabel: UILabel!
    
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCaptureVideoDataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    // After adding your preferred model to the project directory,
    // simply edit this line to YourModelName().model
    let model = try? VNCoreMLModel(for: Inceptionv3().model)
    let documentName = "Inceptionv3.txt"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // create the destination url for the text file to be saved
            let fileURL = documentDirectory.appendingPathComponent(documentName)
            do {
                try Data("Starting measurements\n".utf8).write(to: fileURL)
            } catch {
                print(error)
            }
            
            print("created measuring files")
        }
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCaptureVideoDataOutput()
        cameraOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        let device = AVCaptureDevice.default(for: .video)
        if let input = try? AVCaptureDeviceInput(device: device!) {
            if(captureSession.canAddInput(input)){
                captureSession.addInput(input)
                if(captureSession.canAddOutput(cameraOutput!)){
                    captureSession.addOutput(cameraOutput)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                cameraView.layer.addSublayer(previewLayer)
                previewLayer.frame = cameraView.bounds
                captureSession.startRunning()
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let startTime = NSDate()
        let request = VNCoreMLRequest(model: model!, completionHandler: { request, error in
            guard let results = request.results as? [VNClassificationObservation] else {return}
            guard let observation = results.first else {return}
            
            DispatchQueue.main.async {
                self.predictionLabel.text = "Prediction: \(observation.identifier) \n Confidence: \(observation.confidence * 100) %"
            }
            // Write to document
            // get the documents folder url
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                // create the destination url for the text file to be saved
                let fileURL = documentDirectory.appendingPathComponent(documentName)
                // define the string/text to be saved
                let elapsedTime = abs(startTime.timeIntervalSinceNow)
                var text = String(elapsedTime)
                text.append("\n")
                // writing to disk
                do {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    // convert your string to data or load it from another resource
                    let textData = Data(text.utf8)
                    // append your text to your text file
                    fileHandle.write(textData)
                    // close it when done
                    fileHandle.closeFile()
                } catch {
                    print(error)
                }
                print("write to file was successful. measured time: \(elapsedTime)")
            }
        })
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
