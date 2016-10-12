//
//  BRAWWatchDataManager.swift
//  BreadWallet
//
//  Created by Henry on 10/27/15.
//  Copyright (c) 2015 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import WatchKit
import WatchConnectivity

enum WalletStatus {
    case unknown
    case hasSetup
    case notSetup
}

class BRAWWatchDataManager: NSObject, WCSessionDelegate {
    static let sharedInstance = BRAWWatchDataManager()
    static let ApplicationDataDidUpdateNotification = "ApplicationDataDidUpdateNotification"
    static let WalletStatusDidChangeNotification = "WalletStatusDidChangeNotification"
    static let WalletTxReceiveNotification = "WalletTxReceiveNotification"
    static let applicationContextDataFileName = "applicationContextData.txt"
    
    let session : WCSession =  WCSession.default()
    let timerFireInterval : TimeInterval = 7; // have iphone app sync with peer every 7 seconds
    
    var timer : Timer?
    
    fileprivate var appleWatchData : BRAppleWatchData?

    var balance : String? { return appleWatchData?.balance }
    var balanceInLocalCurrency : String? { return appleWatchData?.balanceInLocalCurrency }
    var receiveMoneyAddress : String? { return appleWatchData?.receiveMoneyAddress }
    var receiveMoneyQRCodeImage : UIImage? { return appleWatchData?.receiveMoneyQRCodeImage }
    var lastestTransction : String? { return appleWatchData?.lastestTransction }
    var transactionHistory : [BRAppleWatchTransactionData] {
        if let unwrappedAppleWatchData: BRAppleWatchData = appleWatchData,
            let transactions :[BRAppleWatchTransactionData] = unwrappedAppleWatchData.transactions{
            return  transactions
        } else {
            return [BRAppleWatchTransactionData]()
        }
    }
    var walletStatus : WalletStatus  {
        if appleWatchData == nil {
            return WalletStatus.unknown
        } else if appleWatchData!.hasWallet {
            return WalletStatus.hasSetup
        } else {
            return WalletStatus.notSetup
        }
    }
    
    lazy var dataFilePath: URL = {
            let filemgr = FileManager.default
            let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask, true)
            let docsDir = dirPaths[0] as String
            return URL(fileURLWithPath: docsDir).appendingPathComponent(applicationContextDataFileName)
        }()
    
    override init() {
        super.init()
        if appleWatchData == nil {
            unarchiveData()
        }
        session.delegate = self
        session.activate()
    }
    
    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }

    func requestAllData() {
        if self.session.isReachable {
            // WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
            let messageToSend = [
                AW_SESSION_REQUEST_TYPE: NSNumber(value: AWSessionRquestTypeFetchData.rawValue as UInt32),
                AW_SESSION_REQUEST_DATA_TYPE_KEY:
                        NSNumber(value: AWSessionRquestDataTypeApplicationContextData.rawValue as UInt32)
            ]
            session.sendMessage(messageToSend, replyHandler: { [unowned self] replyMessage in
                    if let data = replyMessage[AW_SESSION_RESPONSE_KEY] as? Data {
                        if let unwrappedAppleWatchData
                                = NSKeyedUnarchiver.unarchiveObject(with: data) as? BRAppleWatchData {
                            let previousAppleWatchData = self.appleWatchData
                            let previousWalletStatus = self.walletStatus
                            self.appleWatchData = unwrappedAppleWatchData
                            if previousAppleWatchData != self.appleWatchData {
                                self.archiveData(unwrappedAppleWatchData)
//                                WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
                                NotificationCenter.default.post(
                                    name: Notification.Name(rawValue: BRAWWatchDataManager.ApplicationDataDidUpdateNotification), object: nil)
                            }
                            if self.walletStatus != previousWalletStatus {
                                NotificationCenter.default.post(
                                    name: Notification.Name(rawValue: BRAWWatchDataManager.WalletStatusDidChangeNotification), object: nil)
                            }
                        }
                    }
                }, errorHandler: {error in
//                    WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Failure)
                    print(error)
            })
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let applicationContextData = applicationContext[AW_APPLICATION_CONTEXT_KEY] as? Data {
            if let transferedAppleWatchData
                    = NSKeyedUnarchiver.unarchiveObject(with: applicationContextData) as? BRAppleWatchData {
                let previousWalletStatus = self.walletStatus
                appleWatchData = transferedAppleWatchData
                archiveData(transferedAppleWatchData)
                if self.walletStatus != previousWalletStatus {
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: BRAWWatchDataManager.WalletStatusDidChangeNotification), object: nil)
                }
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: BRAWWatchDataManager.ApplicationDataDidUpdateNotification), object: nil)
                
            }
        }
    }
    
    func session(
        _ session: WCSession, didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void) {
            print("Handle message from phone \(message)")
            if let noteV = message[AW_PHONE_NOTIFICATION_KEY],
                let noteStr = noteV as? String,
                let noteTypeV = message[AW_PHONE_NOTIFICATION_TYPE_KEY],
                let noteTypeN = noteTypeV as? NSNumber
                , noteTypeN.uint32Value == AWPhoneNotificationTypeTxReceive.rawValue {
                    let note = Notification(
                        name: Notification.Name(rawValue: BRAWWatchDataManager.WalletTxReceiveNotification), object: nil, userInfo: [
                            NSLocalizedDescriptionKey: noteStr]);
                    NotificationCenter.default.post(note)
            }
    }
    
    func requestQRCodeForBalance(_ bits: String, responseHandler: @escaping (_ qrImage: UIImage?, _ error: NSError?) -> Void) {
        if self.session.isReachable {
            let msg = [
                AW_SESSION_REQUEST_TYPE: NSNumber(value: AWSessionRquestTypeFetchData.rawValue as UInt32),
                AW_SESSION_REQUEST_DATA_TYPE_KEY: NSNumber(value: AWSessionRquestDataTypeQRCodeBits.rawValue as UInt32),
                AW_SESSION_QR_CODE_BITS_KEY: bits
            ] as [String : Any]
            session.sendMessage(msg,
                replyHandler: { (ctx) -> Void in
                    if let dat = ctx[AW_QR_CODE_BITS_KEY],
                        let datDat = dat as? Data,
                        let img = UIImage(data: datDat) {
                            responseHandler(img, nil)
                            return
                    }
                    responseHandler(nil, NSError(domain: "", code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get new qr code"]))
                }, errorHandler: { error in
                    responseHandler(nil, NSError(domain: "", code: 500, userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString("Unable to get new qr code", comment: "")]))
            })
        }
    }
    
    func balanceAttributedString() -> NSAttributedString? {
       if let originalBalanceString = BRAWWatchDataManager.sharedInstance.balance {
            var balanceString = originalBalanceString.replacingOccurrences(of: "Ł", with: "")
            balanceString = balanceString.trimmingCharacters(in: CharacterSet.whitespaces)
            return attributedStringForBalance(balanceString)
        }
        return nil
    }
    
    fileprivate func attributedStringForBalance(_ balance: String?)-> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        attributedString.append(
            NSAttributedString(string: "Ł", attributes: [NSForegroundColorAttributeName : UIColor.gray]))
        
        attributedString.append(
            NSAttributedString(string: balance ?? "0", attributes:
                [NSForegroundColorAttributeName : UIColor.white]))
        
        return attributedString
    }
    
    func archiveData(_ appleWatchData: BRAppleWatchData){
        try? NSKeyedArchiver.archivedData(withRootObject: appleWatchData).write(to: dataFilePath, options: [.atomic])
    }
    
    func unarchiveData() {
        if let data = try? Data(contentsOf: dataFilePath) {
            appleWatchData = NSKeyedUnarchiver.unarchiveObject(with: data) as? BRAppleWatchData
        }
    }
    
    func setupTimer() {
        destoryTimer()
        let weakTimerTarget = BRAWWeakTimerTarget(initTarget: self,
                                                  initSelector: #selector(BRAWWatchDataManager.requestAllData))
        timer = Timer.scheduledTimer(timeInterval: timerFireInterval, target: weakTimerTarget,
                                                       selector: #selector(BRAWWeakTimerTarget.timerDidFire),
                                                       userInfo: nil, repeats: true)
    }
    
    func destoryTimer() {
        if let currentTimer : Timer = timer {
            currentTimer.invalidate();
            timer = nil
        }
    }
}
