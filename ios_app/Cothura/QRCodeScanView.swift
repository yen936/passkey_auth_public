//
//  QRCodeScanView.swift
//  Cothura
//
//  Created by Benji Magnelli on 7/6/23.
//

import VisionKit
import SwiftUI
import UIKit
import AVFoundation
import Alamofire

let cothuraCrypto = Crypto()
let cothuraDBM = DataBaseManager()


struct QRCodeScan: UIViewControllerRepresentable {
    
    @Binding var startScanning: Bool
    @Binding var displayedView: String
    @Binding var presentingToast: Bool
    @Binding var authDataDict: AuthData
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ vc: ScannerViewController, context: Context) {
        vc.scanning = startScanning
    }
    
   
    class Coordinator: NSObject, QRCodeScannerDelegate {
        var parent: QRCodeScan
        
        init(_ parent: QRCodeScan) { self.parent = parent }
        
        func codeDidFind(_ code: String) {
            
            let code = code.replacingOccurrences(of: "\'", with: "\"")
            let jsonData = code.data(using: .utf8)!
            if let data: AuthData = try? JSONDecoder().decode(AuthData.self, from: jsonData) {
                if data.function == "register" {
                    // If Biometrics not enabled alert
                    
                    // Else pass
                    let crypto = Crypto()
                    crypto.keyInit(service: data.service, user_id: data.user_id)
                    parent.displayedView = "Home"
                    
                }
                else {
                    login(data: data)
                    
                }
                
            }
            else {
                print("Could not parse auth code data")
            }
    
            // make popup here
            
            parent.startScanning = false
            
            
        }
        
        func login(data: AuthData) {
            
            do {
                let jsonData = try JSONEncoder().encode(data)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                print(jsonString)
                
            } catch { print(error) }
            
            do {
                let signature = try Crypto.signInputSecureEnclaveKey(
                    privKeyName: "\(data.service):\(data.user_id)",
                    inputString: data.nonce)
                print(signature)
                
                // signatureSE
                cothuraCrypto.sendPayloadAuthApi(signature: signature, user_id: data.user_id, service: data.service, nonce: data.nonce)
                { authEventResult in
                    print("Signature Result: \(authEventResult)")
                    // signature_result holds a bool
                    if authEventResult.signature_result {
                        // Writing a new block
                        //cothuraDBM.writeNextBlock(service: data.service, user_id: data.user_id, nonce: data.nonce, timestamp: authEventResult.timestamp)
                        // Changing the displayed view
                        self.parent.displayedView = "LoggedInSuccess"

                    }
                    else{
                        self.parent.displayedView = "LoggedInFailed"
                    }
                }
                
            }
            catch CothuraCryptoError.keyNotFound {
                print("Fail:Key not found")
                self.parent.displayedView = "LoggedInFailed"
                
            }
            catch CothuraCryptoError.algorithmNotSupported {
                print("Fail:Algo not supported")
                self.parent.displayedView = "LoggedInFailed"
            }
            catch {
                print("Unexpected error: \(error).")
                self.parent.displayedView = "LoggedInFailed"
            }
                
            
            
        
            
            
        }
        
    }
    
}
    

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var delegate: QRCodeScannerDelegate?
    var scanning: Bool!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
            
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    
        /* starting capture session */
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
        
        
    }

    func failed() {
        let ac = UIAlertController(
            title: "Scanning not supported",
            message: "Your device does not support scanning a code from an item. Please use a device with a camera.",
            preferredStyle: .alert)
        
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(ac, animated: true)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
        
        dismiss(animated: true)
    }

    func found(code: String) {
        self.delegate?.codeDidFind(code)
    }
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}


protocol QRCodeScannerDelegate {
    func codeDidFind(_ code: String)
    func login(data: AuthData)
}







///// A view that allows for the scanning of a barcode.
//struct ScanView: UIViewControllerRepresentable {
//
//    /// Manages the logic related to scanning data.
//    @ObservedObject var dataScannerManager : DataScannerManager
//
//    func makeUIViewController(context: Context) -> DataScannerViewController {
//        let dataScannerViewController = DataScannerViewController(
//            recognizedDataTypes: [.barcode(symbologies: [.qr])],
//            qualityLevel: .fast,
//            isHighlightingEnabled: true)
//        dataScannerViewController.delegate = dataScannerManager
//        try? dataScannerViewController.startScanning()
//
//        print(DataScannerViewController.isSupported)
//        print(DataScannerViewController.isAvailable)
//
//        return dataScannerViewController
//
//    }
//
//    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
//
//
//}
//
///// TODO: implement these DataScannerViewControllerDelegate protocol methods to handle when the scanner adds, deletes, and updates items in the collection:
//
///// Manages the properties and methods related to data scanning.
//final class DataScannerManager: NSObject, ObservableObject, DataScannerViewControllerDelegate {
//
//    /// Value indicating that scanning has failed.
//    @Published private(set) var dataScannerFailure: DataScannerViewController.ScanningUnavailable?
//
//    /// The string of the recognized barcode.
//    @Published var recognisedBarcodeString: String = ""
//
//    // MARK: - DataScannerViewControllerDelegate
//
//    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
//        switch item {
//        case .text: break
//        case let .barcode(barcode):
//            recognisedBarcodeString = barcode.payloadStringValue ?? ""
//        @unknown default: break
//        }
//    }
//
//    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
//        print("Data Scanner Failed")
//        self.dataScannerFailure = error
//        print(self.dataScannerFailure as Any)
//    }
//}
