//
//  BRAWReceiveMoneyInterfaceController.swift
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

class BRAWReceiveMoneyInterfaceController: WKInterfaceController, WCSessionDelegate, BRAWKeypadDelegate {

    @IBOutlet var loadingIndicator: WKInterfaceGroup!
    @IBOutlet var imageContainer: WKInterfaceGroup!
    @IBOutlet var qrCodeImage: WKInterfaceImage!
    @IBOutlet var qrCodeButton: WKInterfaceButton!
    var customQR: UIImage?
    
    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }

    override func willActivate() {
        super.willActivate()
        customQR = nil
        updateReceiveUI()
        NotificationCenter.default.addObserver(
            self, selector: #selector(BRAWReceiveMoneyInterfaceController.updateReceiveUI),
            name: NSNotification.Name(rawValue: BRAWWatchDataManager.ApplicationDataDidUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(BRAWReceiveMoneyInterfaceController.txReceive(_:)), name: NSNotification.Name(rawValue: BRAWWatchDataManager.WalletTxReceiveNotification), object: nil)
    }

    override func didDeactivate() {
        super.didDeactivate()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func txReceive(_ notification: Notification?) {
        print("receive view controller received notification: \(notification)")
        if let userData = (notification as NSNotification?)?.userInfo,
            let noteString = userData[NSLocalizedDescriptionKey] as? String {
                self.presentAlert(
                    withTitle: noteString, message: nil, preferredStyle: .alert, actions: [
                        WKAlertAction(title: NSLocalizedString("OK", comment: ""),
                            style: .cancel, handler: { self.dismiss() })])
        }
    }
    
    func updateReceiveUI() {
        if BRAWWatchDataManager.sharedInstance.receiveMoneyQRCodeImage == nil {
            loadingIndicator.setHidden(false)
            qrCodeButton.setHidden(true)
        } else {
            loadingIndicator.setHidden(true)
            qrCodeButton.setHidden(false)
            var qrImg = BRAWWatchDataManager.sharedInstance.receiveMoneyQRCodeImage
            if customQR != nil {
                print("Using custom qr image")
                qrImg = customQR
            }
            qrCodeButton.setBackgroundImage(qrImg)
        }
    }
    
    @IBAction func qrCodeTap(_ sender: AnyObject?) {
        let ctx = BRAWKeypadModel(delegate: self)
        self.presentController(withName: "Keypad", context: ctx)
    }
    
    // - MARK: Keypad delegate
    
    func keypadDidFinish(_ stringValueBits: String) {
        qrCodeButton.setHidden(true)
        loadingIndicator.setHidden(false)
        BRAWWatchDataManager.sharedInstance.requestQRCodeForBalance(stringValueBits) { (qrImage, error) -> Void in
            if let qrImage = qrImage {
                self.customQR = qrImage
            }
            self.updateReceiveUI()
            print("Got new qr image: \(qrImage) error: \(error)")
        }
        self.dismiss()
    }
    
    
}
