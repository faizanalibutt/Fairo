//
//  File.swift
//  Fairo
//
//  Created by Faizan Ali Butt on 10/30/21.
//

import Foundation
import CoreNFC
import UIKit

typealias LocationReadingCompletion = (Result<(NFCNDEFMessage?,String?), Error>) -> Void


enum NFCError: LocalizedError {
    case unavailable
    case invalidated(message: String)
    case invalidPayloadSize
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "NFC Reader Not Available"
        case let .invalidated(message):
            return message
        case .invalidPayloadSize:
            return "NDEF payload size exceeds the tag limit"
        }
    }
}

class NFCHandler:NSObject {

    private override init() {
        super.init()
    }
    static let shared = NFCHandler()
    private var session: NFCTagReaderSession?
    private var completion: LocationReadingCompletion?
    
//    var savedTags:[String] {
//        get { UserDefaults.standard.array(forKey: "SavedTags")  as? [String] ?? []}
//        set { UserDefaults.standard.setValue(newValue, forKey: "SavedTags") }
//    }
    
    func checkIfNFCIsAvailable() -> Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
    
    func startScanningForNFCTags(with completion:LocationReadingCompletion? = nil) {
        
        self.session?.invalidate()
        self.session = nil
        self.completion = completion
        self.session = NFCTagReaderSession.init(pollingOption: .iso14443, delegate: self)
//        if self.savedTags.count == 0 {
//            self.session?.alertMessage = "Ready to scan Fairo card"
//
//        } else {
//            self.session?.alertMessage = "Ready to scan second Fairo card"}
        self.session?.alertMessage = "Ready to scan Fairo card"
        self.session?.begin()
        
    }
    
    func stopScanning() {
        self.completion = nil
        self.session?.invalidate()
        self.session?.invalidate()
    }
    
    func restart() {
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {

        if self.session == nil {
            
            self.session = NFCTagReaderSession.init(pollingOption: .iso14443, delegate: self)
            self.session?.alertMessage = "Ready to scan second Fairo card"
            self.session?.begin()
            
        } else {
         
            if let read = self.session?.isReady, !read {
                self.session = NFCTagReaderSession.init(pollingOption: .iso14443, delegate: self)
                self.session?.begin()
            }
            
        }
            
        }
    }
    
}

extension NFCHandler: NFCTagReaderSessionDelegate,NFCNDEFReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first,
            tags.count == 1 else {
            session.alertMessage = "There are too many tags present. Remove all and then try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                session.restartPolling()
            }
            return
        }
        
        // 1
        session.connect(to: tag) { error in
            if let error = error {
                self.handleError(error)
                return
            }
            var UID = ""
            if  case let .miFare(stag) = tag {
                UID = stag.identifier.map{ String(format:"%.2hhx", $0)}.joined()

            }
            self.completion?(.success((nil, UID)))
            self.session?.invalidate()
            self.session?.alertMessage = "Fairo card scanned"
            
        }
    }
    
    
    
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
      

        
    }
    
    
    
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first,
            tags.count == 1 else {
            session.alertMessage = "There are too many tags present. Remove all and then try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                session.restartPolling()
            }
            return
        }
        
        // 1
        session.connect(to: tag) { error in
            if let error = error {
                self.handleError(error)
                return
            }
            
            // 2
           
            tag.queryNDEFStatus { status, _, error in
                if let error = error {
                    self.handleError(error)
                    return
                }
                
                // 3
                switch (status) {
                
                case (.notSupported):
                    session.alertMessage = "Unsupported tag."
                    session.invalidate()
                
                default:
                    self.readTagInformation(with: tag)
                    return
                }
            }
        }
    }
    
    func readTagInformation(with tag:NFCNDEFTag) {
        
        
        tag.readNDEF { message, error in
            
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            // 1
                if let message = message {
                self.session?.alertMessage = "Found one tag"
                let UID = ""
                self.completion?(.success((message,UID)))
                self.session?.invalidate()
                self.session = nil

            } else {
                self.session?.alertMessage = "Could not decode tag data."
                self.completion?(.failure(NFCError.invalidated(message: "Unable to decode tag data.")))
                self.session?.invalidate()
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if
            let error = error as? NFCReaderError,
            error.code != .readerSessionInvalidationErrorFirstNDEFTagRead &&
                error.code != .readerSessionInvalidationErrorUserCanceled {
            completion?(.failure(NFCError.invalidated(message: error.localizedDescription)))
        }
        
        self.session = nil
        completion = nil
        
    }
    
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        
        
    }
    private func handleError(_ error: Error) {
        session?.alertMessage = error.localizedDescription
        session?.invalidate()
        completion?(.failure(NFCError.invalidated(message: error.localizedDescription)))
    }
    
}
