//
//  Crypto.swift
//  Cothura
//
//  Created by Benji Magnelli on 7/6/23.
//


import Foundation
import Alamofire
import CryptoKit
import KeychainSwift
import Security
//import themis
import LocalAuthentication

let KCS = KeychainSwift()

let KEY_REGISTER_API: String = "https://x29mctfy3l.execute-api.us-east-2.amazonaws.com/default/key-register"
let AUTH_API: String = "https://dr5hugqwdl.execute-api.us-east-2.amazonaws.com/default/authenticate_docker"


struct authEventResult: Codable {
    let user_id: String
    let service: String
    let timestamp: String
    let signature_result: Bool
}

enum CothuraCryptoError: Swift.Error {
    case algorithmNotSupported
    case keyNotFound
    case derConvertionFailure
}

//TODO: Separate Crypto Code from Networking
class Crypto {
    
    // https://developer.apple.com/forums/thread/708749
    // If you generate a new SE key using Apple CryptoKit, the key is ephemeral; it’s not stored anywhere.
    
    
    func shareKeys(service: String, publicKey: String, userID: String) {
        let parameters: [String: String] = [
            "pub_key": publicKey,
            "service": service,
            "user_id": userID
        ]

        AF.request(KEY_REGISTER_API,
                   method: .post,
                   parameters: parameters,
                   encoder: JSONParameterEncoder.default).responseString { response in
            switch response.result {
            case .success(let value):
                if let respDict = convertStringToDictionary(text: value) {
                    if let success = respDict["Success"] as? Bool, success {
                        // Key exists
                        print("Key shared successfully.")
                        print(respDict)
                    } else {
                        // Key not found or other error
                        print("Failure to Share Key")
                        print(respDict)
                    }
                } else {
                    // Unable to parse the response as a dictionary
                    print("Error: Unable to parse the response as a dictionary.")
                    debugPrint(response)
                }
            case .failure(let error):
                // Request failed
                print("Request failed with error: \(error.localizedDescription)")
                debugPrint(response)
            }
        }
    }

    
    static func makeAndStoreKey(keyID: String, requiresBiometry: Bool = false) throws -> SecKey {
        //Removes old key Reference
        self.removeKey(privateKeyID: keyID)
            
        let flags: SecAccessControlCreateFlags
        if #available(iOS 11.3, *) {
            flags = requiresBiometry ?
                [.privateKeyUsage, .biometryCurrentSet] : .privateKeyUsage
        } else {
            flags = requiresBiometry ?
                [.privateKeyUsage, .touchIDCurrentSet] : .privateKeyUsage
        }
        let access =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                            flags,
                                            nil)!
        let tag = keyID.data(using: .utf8)!
        let attributes: [String: Any] = [
            kSecAttrKeyType as String           : kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits as String     : 256,
            kSecAttrTokenID as String           : kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String : [
                kSecAttrIsPermanent as String       : true,
                kSecAttrApplicationTag as String    : tag,
                kSecAttrAccessControl as String     : access
            ] as [String : Any]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        return privateKey
    }
    
    private func addDerKeyInfo(rawPublicKey:[UInt8]) -> [UInt8] {
        let DerHdrSubjPubKeyInfo:[UInt8]=[
            /* Ref: RFC 5480 - SubjectPublicKeyInfo's ASN encoded header */
            0x30, 0x59, /* SEQUENCE */
            0x30, 0x13, /* SEQUENCE */
            0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, /* oid: 1.2.840.10045.2.1   */
            0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, /* oid: 1.2.840.10045.3.1.7 */
            0x03, 0x42, /* BITSTRING */
            0x00 /* unused number of bits in bitstring, followed by raw public-key bits */]
        let derKeyInfo = DerHdrSubjPubKeyInfo + rawPublicKey
        return derKeyInfo
    }

    
    private func convertbase64StringToByteArray(base64String: String) -> [UInt8]? {
        if let nsdata = NSData(base64Encoded: base64String, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)  {
            var bytes = [UInt8](repeating: 0, count: nsdata.length)
            nsdata.getBytes(&bytes,length: nsdata.length)
            return bytes
        }
        else
        {
            debugPrint("Invalid base64 String")
        }
        return nil
    }
    
    
    func convertSecKeyToDerKeyFormat(publicKey:SecKey) throws -> String {
        
        do {
            let derError : UnsafeMutablePointer<Unmanaged<CFError>?>? = nil
            if let externalRepresentationOfPublicKey = SecKeyCopyExternalRepresentation(publicKey, derError)
            {
                let derKeyFormat = externalRepresentationOfPublicKey as Data
                var publicKeyByteArray = convertbase64StringToByteArray(base64String: derKeyFormat.base64EncodedString())
                publicKeyByteArray =  addDerKeyInfo(rawPublicKey: publicKeyByteArray!)
                let base64EncodedPublicKey:String=Data(publicKeyByteArray!).base64EncodedString()
                return base64EncodedPublicKey
            }
            else
            {
                throw CothuraCryptoError.derConvertionFailure as Error
            }
        }
        catch
        {
            throw CothuraCryptoError.derConvertionFailure as Error
        }
    }

    
    static func loadPrivateKey(privateKeyID: String) -> SecKey? {
            let tag = privateKeyID.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String                 : kSecClassKey,
                kSecAttrApplicationTag as String    : tag,
                kSecAttrKeyType as String           : kSecAttrKeyTypeEC,
                kSecReturnRef as String             : true
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess else {
                return nil
            }
            return (item as! SecKey)
        }
    
    
    static func getPublicKey(privateKeyID: String) -> SecKey? {
        guard let privateKey = Crypto.loadPrivateKey(privateKeyID: privateKeyID) else { return nil }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            // An error occurred.
            return nil
        }
        return publicKey
    }
    
    
    static func removeKey(privateKeyID: String) {
            let tag = privateKeyID.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String                 : kSecClassKey,
                kSecAttrApplicationTag as String    : tag
            ]

            SecItemDelete(query as CFDictionary)
        }
    
    
    static func signInputSecureEnclaveKey(privKeyName: String, inputString: String) throws -> String {
        // Get the private key.
        guard let privateKey = Crypto.loadPrivateKey(privateKeyID: privKeyName) else {
            throw CothuraCryptoError.keyNotFound
        }
        
        
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, .ecdsaSignatureMessageX962SHA256) else {
            throw CothuraCryptoError.algorithmNotSupported
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey,
                                                    .ecdsaSignatureMessageX962SHA256,
                                                    inputString.data(using: .utf8)! as CFData,
                                                    &error) as Data? else {
                                                        throw error!.takeRetainedValue() as Error
        }
     
        return signature.base64EncodedString()
    }
    

    func keyInit(service: String, user_id: String) {
        
        let keyID = "\(service):\(user_id)"
        let publicKey = Crypto.getPublicKey(privateKeyID: keyID)
        
        if publicKey == nil {
            // If not key exists make it
            do {
                _ = try Crypto.makeAndStoreKey(keyID: keyID, requiresBiometry: true)
                // Use the private key here.
                keyInit(service: service, user_id: user_id)
                
            } catch let error {
                // TODO: Display error if bio is not enabled
                // Handle the error here.
                print(error.localizedDescription)
            }
        }
        else {
            // Send key to the server
            do {
                let derKey = try self.convertSecKeyToDerKeyFormat(publicKey: publicKey!)
                shareKeys(service: service, publicKey: derKey, userID: user_id)
            }
            catch CothuraCryptoError.derConvertionFailure {
                print("failure to convert DER format")
                print("TODO: show error to user")
            }
            catch {
                print("Unexpected error: \(error).")
            }
        }
        
        
    }
    

    
    
    private func parseAuthResult(jsonData: Data) -> authEventResult? {
        do {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(authEventResult.self, from: jsonData)
            return payload
        } catch {
            print("Error decoding JSON: \(error)")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("JSON Data: \(jsonString)")
            }
            return nil
        }
    }
    
    
    private func getLastBlockHash(user_id: String, service: String) -> String {

        let DBM = DataBaseManager()
        let lastBlock = DBM.getLastBlock(service: service, user_id: user_id)
        return lastBlock?.block_hash ?? "no_prev_block"
        
    }
    
    
    func sendPayloadAuthApi(signature: String, user_id: String, service: String, nonce: String, completion: @escaping (authEventResult) -> Void){
        
        let parameters: [String: String] = [
            "signature": signature,
            "user_id": user_id,
            "nonce": nonce,
            "service": service,
            "prev_block_hash": "this_is_a_placeholder" //self.getLastBlockHash(user_id: user_id, service: service)
        ]
        print(parameters)
        
        // TODO: upgrade to encrypted messaging
        //        // https://docs.cossacklabs.com/themis/languages/swift/features/#encryption-mode
        
        AF.request(AUTH_API,
                   method: .post,
                   parameters: parameters,
                   encoder: JSONParameterEncoder.default).responseData
        { response in
            
            switch response.result {
                case .success(let jsonData):
                if let authResult = self.parseAuthResult(jsonData: jsonData) {
                        completion(authResult)
                    } else {
                        completion(authEventResult(user_id: user_id, service: service, timestamp: "nill", signature_result: false))
                    }
                case .failure(let error):
                    print("Error making request: \(error)")
                    completion(authEventResult(user_id: user_id, service: service, timestamp: "nill", signature_result: false))
                }
                

        }
    }
    
    
    // Dont Delete: This is the func using CryptoKit
//    func generateKeysSE(name: String) {
//        if CryptoKit.SecureEnclave.isAvailable {
//
//           let requiresBiometry: Bool = true
//            let flags: SecAccessControlCreateFlags
//            if #available(iOS 11.3, *) {
//                flags = requiresBiometry ?
//                    [.privateKeyUsage, .biometryCurrentSet] : .privateKeyUsage
//            } else {
//                flags = requiresBiometry ?
//                    [.privateKeyUsage, .touchIDCurrentSet] : .privateKeyUsage
//            }
//
//            let authContext = LAContext()
//            let accessCtrl = SecAccessControlCreateWithFlags(nil,
//                                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
//                                                            flags,
//                                                            nil)!
//            do {
//
//
//                var privateKey = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey.init(
//                  accessControl: accessCtrl,
//                  authenticationContext: authContext
//                );
//
//
//                let publicKey = privateKey.publicKey
//                print(publicKey.derRepresentation.base64EncodedString())
//
//                let stringToSign = "Godislove"
//                let signBytes = stringToSign.data(using: .utf8)!
//
//                let signature = try privateKey.signature(for: signBytes)
//                print(signature.derRepresentation.base64EncodedString())
//
//            }
//            catch {
//                debugPrint("uh oh, problem with keys")
//                debugPrint(error)
//            }
//
//        }
//
//        else{
//             debugPrint("Failure to Access Secure Enclave")
//        }
//
//    }


//        // If no keys exist then make them
//        if KCS.getData(service + ":PrivateKey") == nil || KCS.getData(service + ":PublicKey") == nil {
//            print("No Keys: Generating Now...")
//
//            // Themis
//            let keypair = TSKeyGen(algorithm: .RSA)!
//
//            let privateKey: Data = keypair.privateKey as Data
//            let publicKey: Data = keypair.publicKey as Data
//
//
//            KCS.set(privateKey, forKey: service + ":PrivateKey")
//            KCS.set(publicKey, forKey: service + ":PublicKey")
            
//            shareKeys(service: service, publicKey: publicKey.base64EncodedString(), userID: "test12")
//        }
//        else {
//            print("keys already there")
            
            // Themis
//            let keypair = TSKeyGen(algorithm: .RSA)!
//
//            let privateKey: Data = keypair.privateKey as Data
//            let publicKey: Data = keypair.publicKey as Data
//
//            KCS.set(privateKey, forKey: service + ":PrivateKey")
//            KCS.set(publicKey, forKey: service + ":PublicKey")
//
//            shareKeys(service: service, publicKey: publicKey.base64EncodedString(), userID: "test12")
//
//        }
    
//    func signInputString(service: String, inputString: String) -> String {
//        /// Returns `nil` if no  value exists for inputed key
//        let privateKey = KCS.getData(service + ":PrivateKey")
//
//        // TODO: upgrade to encrypted messaging
//        // https://docs.cossacklabs.com/themis/languages/swift/features/#encryption-mode
//
//        let secureMessage = TSMessage(inSignVerifyModeWithPrivateKey: privateKey, peerPublicKey: nil)!
//        let signedMessage: Data = try! secureMessage.wrap(Data(inputString.utf8))
//
//        return signedMessage.base64EncodedString()
//    }

    
    
    
}

extension String {

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

}


func convertStringToDictionary(text: String) -> [String:AnyObject]? {
   if let data = text.data(using: .utf8) {
       do {
           let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
           return json
       } catch {
           print("Something went wrong")
       }
   }
   return nil
}
