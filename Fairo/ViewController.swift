//
//  ViewController.swift
//  Fairo
//
//  Created by Faizan Ali Butt on 10/3/21.
//

import UIKit
import AVFoundation
import Alamofire
import SwiftyJSON
import CoreNFC

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var takePhoto: UIButton!
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var fairoText: UILabel!
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var fairoButton: UIButton!
    @IBOutlet weak var debugText: UILabel!
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    var device: AVCaptureDevice?
    var captureSession: AVCaptureSession?
    var takesPhoto = false
    var cameraSetup = false
    let scanSuccessText = "Your card has been scanned successfully." + "\n\nWe will now capture a selfie to verify your identity. When you’re ready, press the button below."
    
    var cameraImage: UIImage?
    var isNFCScanned = false
    var faceId = "nothing"
    var isVerified = false
    var nfcSession: NFCNDEFReaderSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.captureSession?.stopRunning()
    }
    
    @IBAction func openCamera(_ sender: UIButton) {
        if isVerified {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let henryHooks = "henrycards://"
                let henryUrl = URL(string: henryHooks)!
                UIApplication.shared.open(henryUrl) { result in
                    if result {
                        print("finally reached henry")
                    }
                }
            }
            isVerified = false
            isNFCScanned = false
            return
        }
        if isNFCScanned {
            self.takePhoto.isHidden = false
            self.cameraImageView.isHidden = false
            self.cameraPreview.isHidden = false
            self.fairoText.isHidden = true
            self.fairoButton.isHidden = true
            self.setupCamera()
            self.cameraSetup = true
            return
        }
        // do nfc first
        if NFCHandler.shared.checkIfNFCIsAvailable() {
            NFCHandler.shared.startScanningForNFCTags { result in
                print(result)
                // do { self.debugText.text = try result.get().1 } catch {}
                DispatchQueue.main.async {
                    // do what you need to do here. update text
                    self.isNFCScanned = true
                    self.fairoText.text = self.scanSuccessText
                    self.fairoButton.setTitle("Take Selfie", for: .normal)
                    //self.uploadFile(image: UIImage(imageLiteralResourceName: "Henry.jpeg"))
                }
                NFCHandler.shared.stopScanning()
            }
        }
        self.debugText.text = "fairo button clicked."
    }
    
    @IBAction func takePhoto(_ sender: UIButton) {
        takesPhoto = true
    }
    
    func setupCamera() {
        if cameraSetup {
            return
        }
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                mediaType: AVMediaType.video, position: .front
        )
        device = discoverySession.devices[0]
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device!)
        } catch {
            return
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        
        let queue = DispatchQueue(label: "cameraQueue")
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: kCVPixelFormatType_32BGRA]
        
        captureSession = AVCaptureSession()
        captureSession?.addInput(input)
        captureSession?.addOutput(output)
        captureSession?.sessionPreset = AVCaptureSession.Preset.photo
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.frame = CGRect(x: 0.0, y: 0.0, width: cameraPreview.frame.width, height: cameraPreview.frame.height)
        cameraPreview.layer.insertSublayer(previewLayer!, at: 0)
        captureSession?.startRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = UnsafeMutableRawPointer(CVPixelBufferGetBaseAddress(imageBuffer!))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo:
                                    CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        connection.videoOrientation = .portrait
        if takesPhoto  {
            let newImage = newContext!.makeImage()
            cameraImage = UIImage(cgImage: newImage!)
            //cameraImage = rotateCameraImageToProperOrientation(imageSource: cameraImage!)
            DispatchQueue.main.sync {
                self.uploadFile(image: self.cameraImage!)
                cameraImageView.image = cameraImage
                fairoButton.isHidden = false
                fairoText.isHidden = false
                takePhoto.isHidden = true
                self.cameraPreview.isHidden = true
                // api call will be followed here.
                fairoText.text = "Your selfie is being verified..."
                fairoButton.isHidden = true
            }
            takesPhoto = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.cameraImageView.isHidden = true
                print("take photo button clicked.")
            }
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    func uploadFile(image: UIImage) {
        let sURL = "https://westus.api.cognitive.microsoft.com/face/v1.0/detect?returnFaceId=true&recognitionModel=recognition_04&returnFaceLandmarks=false&detectionModel=detection_01&returnRecognitionModel=true&faceIdTimeToLive=86400"
        let headers: HTTPHeaders = [
            "Content-Type": "application/octet-stream",
            "Ocp-Apim-Subscription-Key": "217c53b3c7444fa5bd259d95c9856c62"
        ]
        let data = image.jpegData(compressionQuality: 1)
        
        AF.upload(data!, to: sURL, method: .post, headers: headers)
        .uploadProgress { progress in
            print(CGFloat(progress.fractionCompleted))
        }
        .response { response in
            if (response.error == nil) {
                var responseString : String!
                if (response.data != nil) {
                    self.fairoButton.isHidden = false
                    let data = JSON(response.data ?? "")
                    if let jsonArray = data.array {
                        if jsonArray.count == 0 {
                            self.takePhoto.isHidden = true
                            self.cameraImageView.isHidden = true
                            self.cameraPreview.isHidden = true
                            self.fairoText.isHidden = false
                            self.fairoButton.isHidden = false
                            self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
                            return
                        }
                        for item in jsonArray {
                            if let jsonDict = item.dictionary {
                                let faceId1 = jsonDict["faceId"]!.stringValue
                                print(faceId1)
                                // call to verify user
                                self.faceId = faceId1
                                self.getFaceId()
                            }
                        }
                    } else {
                        self.takePhoto.isHidden = true
                        self.cameraImageView.isHidden = true
                        self.cameraPreview.isHidden = true
                        self.fairoText.isHidden = false
                        self.fairoButton.isHidden = false
                        self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
                    }
                } else {
                    responseString = response.response?.description
                    self.takePhoto.isHidden = true
                    self.cameraImageView.isHidden = true
                    self.cameraPreview.isHidden = true
                    self.fairoText.isHidden = false
                    self.fairoButton.isHidden = false
                    self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
                }
                print(responseString ?? "")
            } else {
                print("didn't get much from this api")
                self.takePhoto.isHidden = true
                self.cameraImageView.isHidden = true
                self.cameraPreview.isHidden = true
                self.fairoText.isHidden = false
                self.fairoButton.isHidden = false
                self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
            }
        }
    }
    
    func generateRandomStringWithLength(length: Int) -> String {
        let randomString: NSMutableString = NSMutableString(capacity: length)
        let letters: NSMutableString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var i: Int = 0
        
        while i < length {
            let randomIndex: Int = Int(arc4random_uniform(UInt32(letters.length)))
            randomString.append("\(Character( UnicodeScalar( letters.character(at: randomIndex))!))")
            i += 1
        }
        return String(randomString)
    }
    
    func getFaceId() {
        let vURL = "https://fairo-public.s3.us-west-000.backblazeb2.com/faceid.txt"
        var faceId2: String = "nothing"
        AF.request(vURL, method: .get, encoding: JSONEncoding.default).responseJSON { (response) in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                print("JSON: \(json)")
                if let jsonDict = json.dictionary {
                    faceId2 = jsonDict["faceid"]!.stringValue
                    self.verifyUser(faceId2: faceId2)
                }
            case .failure(let error):
                print(error)
                self.takePhoto.isHidden = true
                self.cameraImageView.isHidden = true
                self.cameraPreview.isHidden = true
                self.fairoText.isHidden = false
                self.fairoButton.isHidden = false
                self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
            }
        }
    }
    
    func verifyUser(faceId2: String) {
        let vURL = "https://westus.api.cognitive.microsoft.com/face/v1.0/verify"
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Ocp-Apim-Subscription-Key": "217c53b3c7444fa5bd259d95c9856c62"
        ]
        let parameters: Parameters = [
            "faceId1": faceId,
            "faceId2": faceId2
        ]
        AF.request(vURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { (response) in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                print("JSON: \(json)")
                if let jsonDict = json.dictionary {
                    let isIdentical = jsonDict["isIdentical"]?.boolValue ?? false
                    if isIdentical {
                        self.takePhoto.isHidden = true
                        self.cameraImageView.isHidden = true
                        self.cameraPreview.isHidden = true
                        self.fairoText.isHidden = false
                        self.fairoButton.isHidden = false
                        self.fairoText.text = "We have successfully authenticated your identity. Please tap below to complete your login to Henry’s Palace."
                        self.fairoButton.setTitle("Complete Login", for: .normal)
                        self.fairoButton.backgroundColor = UIColor(red: 85/255, green: 195/255, blue: 78/255, alpha: 1)
                        self.isVerified = true
                    } else {
                        self.takePhoto.isHidden = true
                        self.cameraImageView.isHidden = true
                        self.cameraPreview.isHidden = true
                        self.fairoText.isHidden = false
                        self.fairoButton.isHidden = false
                        self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
                        self.isVerified = false
                    }
                }
            case .failure(let error):
                print(error)
                self.takePhoto.isHidden = true
                self.cameraImageView.isHidden = true
                self.cameraPreview.isHidden = true
                self.fairoText.isHidden = false
                self.fairoButton.isHidden = false
                self.fairoText.text = "We were unable to verify your selfie.\nPlease try once again."
                self.isVerified = false
            }
        }
    }
}
