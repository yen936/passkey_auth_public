//
//  HomeView.swift
//  Cothura
//
//  Created by Benji Magnelli on 7/6/23.
//

import SwiftUI
import Security
import LocalAuthentication
import ToastUI

struct AppView: View {
    
    @State var startScanning = false
    @State var displayedView = "Home"
    @State var presentingToast = false
    @State var authDataDict = AuthData(service: "", user_id: "", nonce: "", timestamp: "", function: "")
    
    var body: some View {
        return Group {
//            if startScanning {
//                QRCodeScan(startScanning: $startScanning)
//            }
//            else {
//                HomeView(startScanning: $startScanning)
//            }
            
            
            switch displayedView {
                case "QRScan":
                    QRCodeScan(startScanning: $startScanning,
                               displayedView: $displayedView,
                               presentingToast: $presentingToast,
                               authDataDict: $authDataDict)
                case "LoggedInSuccess":
                    LoggedInSucessView(authDataDict: $authDataDict,
                                 displayedView: $displayedView,
                                 presentingToast: $presentingToast)
                case "LoggedInFailed":
                    LoggedInFailedView(authDataDict: $authDataDict,
                             displayedView: $displayedView,
                             presentingToast: $presentingToast)
                default:
                    HomeView(startScanning: $startScanning,
                             displayedView: $displayedView,
                             authDataDict: $authDataDict,
                             presentingToast: $presentingToast)
            }
            
        }
    }
}

struct HomeView: View {
    
    @Binding var startScanning: Bool
    @Binding var displayedView: String
    @Binding var authDataDict: AuthData
    @Binding var presentingToast: Bool
    
    var body: some View {
        
        VStack(alignment: .center) {

            Text("Tap to Scan QR Code")
                .font(.title)
                .padding()

            Button(action: { self.buttonPressed() }) {
                Text("Scan")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(50)
                    .shadow(radius: 5)
            }
            .padding(.top, 25)
            .frame(maxWidth: .infinity, alignment: .bottom)


        }.toast(isPresented: $presentingToast) {
            ToastView {
              VStack {
                Text("Biometrics are not enabled")
                  .multilineTextAlignment(.center)

                Divider()

                Button("OK") {
                    presentingToast = false
                }
              }
            }.padding()

      }.onAppear {

          self.cryptoInit()
          //self.ledgerInit()
          self.checkBiometrics()

      }
      
     
        
    }
    
    func checkBiometrics() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Biometrics are available and enabled, do nothing.
            print("Biometrics are enabled.")
            presentingToast = true
        } else {
            // Biometrics are not available or not enabled, show a toast message.
            print("Biometrics are not enabled.")
            presentingToast = true
        }
    }
    
    func buttonPressed() {
        displayedView = "QRScan"
    }
    
    func cryptoInit() {
        //let c = Crypto()
        //c.keyInit(service: "example.com", user_id: "test12")
        
        
        //c.sendSignature(baseDomain: "example.com", inputString: "GodisLove")

//            let privateKey = try Crypto.makeAndStoreKey(name: "example.com:testUser1", requiresBiometry: true)
            
//        let privateKey = Crypto.loadPrivateKey(privateKeyID: "example.com:testUser1")
//
//
//        let publicKey = Crypto.getPublicKey(privateKeyID: "example.com:test12")
//        print(publicKey)
//
//        do{
//            let derKey = try c.convertSecKeyToDerKeyFormat(publicKey: publicKey!)
//            print(derKey)
//
//        }
//        catch CothuraCryptoError.derConvertionFailure {
//            print("failure to convert DER format")
//            print("TODO: show error to user")
//        }
//        catch {
//            print("Unexpected error: \(error).")
//        }

//        do {
//            let signature = try Crypto.signInputSecureEnclaveKey(privKeyName: "example.com:test12", inputString: "Godislove")
//            print(signature)
//        }
//        catch CothuraCryptoError.keyNotFound {
//            print("Fail:Key not found")
//        }
//        catch CothuraCryptoError.algorithmNotSupported {
//            print("Fail:Algo not supported")
//        }
//        catch {
//            print("Unexpected error: \(error).")
//        }
        
        
        
       // c.generateKeysSE(name: "GodisLove")
            
    }
    
    func ledgerInit() {
//        let currentTimestamp = getCurrentTimestamp()
//        let DBM = DataBaseManager()
        
//        DBM.initBlock(service: "example.com",
//                      user_id: "test12",
//                      nonce: "d29a78286843a1ea55d937fff66e3131662dbcad1f1c11f4b9636737e3be8e65",
//                      timestamp: getCurrentTimestamp(),
//                      block_hash: "11fe5c76bbfc7a4d1e0ba1b8732626e4bdf02692b338cde58160c077a4c422a9")
        
//        let block2 = DBM.getLastBlock(service: "example.com", user_id: "test12")
//        print(block2?.block_hash, block2?.nonce, block2?.timestamp)
        
    }
    
    func notificationReminder() -> Alert {
               Alert(
                   title: Text("Notifications Required"),
                   message: Text("Please authorize notifications by going to Settings > Notifications > Reminder"),
                   dismissButton: .default(Text("Okay")))
    }
       

}

struct LoggedInSucessView: View {
    
    @Binding var authDataDict: AuthData
    @Binding var displayedView: String
    @Binding var presentingToast: Bool
   
    var body: some View {
        
        VStack(alignment: .center) {
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .scaleEffect(true ? 1.5 : 1)
                    .foregroundColor(Color.green)
                Text("Login Successful")
                    .font(.title)
            }
            
//            Text(authDataDict.service)
//                .font(.headline)
//                .padding()
            
//            Text(authDataDict.service)
//                .font(.body)
//                .padding()
//
//            Text(authDataDict.nonce)
//                .font(.body)
//                .padding()
            
//            Button(action: { self.buttonPressed() }) {
//                Text("Home")
//                    .font(.title)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(50)
//                    .shadow(radius: 5)
//            }
//            .padding(.top, 60)
//            .frame(maxWidth: .infinity, alignment: .bottom)
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.displayedView = "Home"
            }
            
        }
    
    }
    
    func buttonPressed() {
        displayedView = "Home"
    }
    
}



struct LoggedInFailedView: View {
    
    @Binding var authDataDict: AuthData
    @Binding var displayedView: String
    @Binding var presentingToast: Bool
   
    var body: some View {
        
        VStack(alignment: .center) {
            
            HStack {
                Image(systemName: "exclamationmark.lock.fill")
                    .scaleEffect(true ? 1.5 : 1)
                    .foregroundColor(Color.orange)
                Text("Login Failed")
                    .font(.title)
            }
            
            Text("Please try again")
                .font(.headline)
                .padding()
            
//            Button(action: { self.buttonPressed() }) {
//                Text("Home")
//                    .font(.title)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(50)
//                    .shadow(radius: 5)
//            }
//            .padding(.top, 60)
//            .frame(maxWidth: .infinity, alignment: .bottom)
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.displayedView = "Home"
            }
            
        }
    
    }
    
    func buttonPressed() {
        displayedView = "Home"
    }
    
}

// Data types
struct AuthData: Decodable, Encodable {
    var service: String
    var user_id: String
    var nonce: String
    var timestamp: String
    var function: String
}

struct UserStatus: Decodable {
    var user_authenticated: Bool
}

struct ContentAccepted: Decodable {
    var accepted: Bool
}

func getCurrentTimestamp() -> String {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]
    let timestamp = Date()
    return dateFormatter.string(from: timestamp)
}


//// View Modifiers
//struct ViewDidLoadModifier: ViewModifier {
//
//    @State private var didLoad = false
//    private let action: (() -> Void)?
//
//    init(perform action: (() -> Void)? = nil) {
//        self.action = action
//    }
//
//    func body(content: Content) -> some View {
//        content.onAppear {
//            if didLoad == false {
//                didLoad = true
//                action?()
//            }
//        }
//    }
//
//}
//
//extension View {
//
//    func onLoad(perform action: (() -> Void)? = nil) -> some View {
//        modifier(ViewDidLoadModifier(perform: action))
//    }
//
//}
