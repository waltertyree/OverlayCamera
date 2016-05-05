//
//  ViewController.swift
//  OverlayCamera
//
//  Created by Walter Tyree on 4/1/16.
//  Copyright © 2016 Tyree Apps, LLC. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation
import CoreImage

class ViewController: GLKViewController {

    private let videoQueue : dispatch_queue_t

    let glContext = EAGLContext(API: .OpenGLES2)
    var captureSession : AVCaptureSession?
    
    required init?(coder aDecoder: NSCoder) {
        videoQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let glView = self.view as? GLKView {
            glView.context = self.glContext
            glView.drawableDepthFormat = .Format24
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setupAVCapture()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        tearDownAVCapture()
        
    }
    
    func setupAVCapture() {
        
        let captureSession = AVCaptureSession()
        
        captureSession.beginConfiguration()
        
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        do {
        let deviceInput = try AVCaptureDeviceInput(device: device)
        
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
            
            if captureSession.canSetSessionPreset(AVCaptureSessionPresetHigh) {
                captureSession.sessionPreset = AVCaptureSessionPresetHigh
            }
        } catch let error as NSError {
            print(error)
        }
        
        // Video data output
        
        let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
                  }
        
        if let connection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo) {
            connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        }
        
        captureSession.commitConfiguration()
        
            dispatch_async(videoQueue, { 
                captureSession.startRunning()
            })
       
        
        self.captureSession = captureSession
    }
    
    func tearDownAVCapture() {
        if let captureSession = self.captureSession {
            captureSession.stopRunning()
        }
        
        self.captureSession = nil
        
    }
}

extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
            
            let ciImage : CIImage
            
            if let attachments = attachments as? [String : AnyObject] {
                ciImage = CIImage(CVPixelBuffer: pixelBuffer, options: attachments)
            } else {
                ciImage = CIImage(CVPixelBuffer: pixelBuffer, options: nil)
            }
            let middleImage = rectangleSearch(ciImage)
            //let outputImage = middleImage.imageByApplyingFilter("CISepiaTone", withInputParameters: nil)
            let outputImage = middleImage
            
            let extent = outputImage.extent
            
            dispatch_async(dispatch_get_main_queue(), { 
                
                let view = self.view
                let bounds = view.bounds
                let scale = view.contentScaleFactor
                
                let extentFitWidth = extent.size.height / (bounds.size.height / bounds.size.width)
                let extentFit = CGRect(x: (extent.size.width - extentFitWidth) / 2, y: 0, width: extentFitWidth, height: extent.size.height)
                
                let scaledBounds = CGRect(x: bounds.origin.x * scale, y: bounds.origin.y * scale, width: bounds.size.width * scale, height: bounds.size.height * scale)
                
                let ciContext = CIContext(EAGLContext: self.glContext)
                ciContext.drawImage(outputImage, inRect: scaledBounds, fromRect: extentFit)

                self.glContext.presentRenderbuffer(Int(GL_RENDERBUFFER))
                
                
                if let glView = self.view as? GLKView {
                    glView.display()
                }
            })
        }
        
        
    }
    
    func rectangleSearch(image : CIImage) -> CIImage {
    
        var returnImage = image
        
        let checkDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: CIContext(EAGLContext: self.glContext), options: [CIDetectorAccuracy:CIDetectorAccuracyHigh,CIDetectorAspectRatio:1.5])
        
        let checks = checkDetector.featuresInImage(image) as! [CIRectangleFeature]
        //var overlay = CIImage(color: CIColor(red: 0.0, green: 0, blue: 1.0, alpha: 0.22))
       var overlay = CIFilter(name: "CIRandomGenerator")!.outputImage!
        for check : CIRectangleFeature in checks {
            overlay = overlay.imageByCroppingToRect(image.extent)
            overlay = overlay.imageByApplyingFilter("CIPerspectiveTransformWithExtent",
                                                    withInputParameters: [
                                                        "inputExtent": CIVector(CGRect: image.extent),
                                                        "inputTopLeft": CIVector(CGPoint: check.topLeft),
                                                        "inputTopRight": CIVector(CGPoint: check.topRight),
                                                        "inputBottomLeft": CIVector(CGPoint: check.bottomLeft),
                                                        "inputBottomRight": CIVector(CGPoint: check.bottomRight)
                ])
       


            //overlay = overlay.imageByApplyingFilter("CIPixelate", withInputParameters: nil)
            returnImage = overlay.imageByCompositingOverImage(returnImage)
        }
        
        return returnImage
    }
}

