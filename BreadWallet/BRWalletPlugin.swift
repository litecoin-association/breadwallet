//
//  BRWalletPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/18/16.
//  Copyright (c) 2016 breadwallet LLC
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

import Foundation


@objc class BRWalletPlugin: NSObject, BRHTTPRouterPlugin, BRWebSocketClient {
    var sockets = [String: BRWebSocket]()
 
    let manager = BRWalletManager.sharedInstance()!
    
    func announce(json: [String: AnyObject]) {
        if let jsonData = try? NSJSONSerialization.dataWithJSONObject(json, options: []),
            jsonString = NSString(data: jsonData, encoding: NSUTF8StringEncoding) {
            for sock in sockets {
                sock.1.send(String(jsonString))
            }
        } else {
            print("[BRWalletPlugin] announce() could not encode payload: \(json)")
        }
    }
 
    func hook(router: BRHTTPRouter) {
        router.websocket("/_wallet/_socket", client: self)
        
        let noteCenter = NSNotificationCenter.defaultCenter()
        noteCenter.addObserverForName(BRPeerManagerSyncStartedNotification, object: nil, queue: nil) { (note) in
            self.announce(["type": "sync_started"])
        }
        noteCenter.addObserverForName(BRPeerManagerSyncFailedNotification, object: nil, queue: nil) { (note) in
            self.announce(["type": "sync_failed"])
        }
        noteCenter.addObserverForName(BRPeerManagerSyncFinishedNotification, object: nil, queue: nil) { (note) in
            self.announce(["type": "sync_finished"])
        }
        noteCenter.addObserverForName(BRPeerManagerTxStatusNotification, object: nil, queue: nil) { (note) in
            self.announce(["type": "tx_status"])
        }
        noteCenter.addObserverForName(BRWalletManagerSeedChangedNotification, object: nil, queue: nil) { (note) in
            if let wallet = self.manager.wallet {
                self.announce(["type": "seed_changed", "balance": NSNumber(unsignedLongLong: wallet.balance)])
            }
        }
        noteCenter.addObserverForName(BRWalletBalanceChangedNotification, object: nil, queue: nil) { (note) in
            if let wallet = self.manager.wallet {
                self.announce(["type": "balance_changed", "balance": NSNumber(unsignedLongLong: wallet.balance)])
            }
        }
 
        router.get("/_wallet/info") { (request, match) -> BRHTTPResponse in
            return try BRHTTPResponse(request: request, code: 200, json: self.walletInfo())
        }
 
        router.get("/_wallet/format") { (request, match) -> BRHTTPResponse in
            if let amounts = request.query["amount"] where amounts.count > 0 {
                let amount = amounts[0]
                var intAmount: Int64 = 0
                if amount.containsString(".") { // assume full bitcoins
                    if let x = Float(amount) {
                        intAmount = Int64(x * 100000000.0)
                    }
                } else {
                    if let x = Int64(amount) {
                        intAmount = x
                    }
                }
                return try BRHTTPResponse(request: request, code: 200, json: self.currencyFormat(intAmount))
            } else {
                return BRHTTPResponse(request: request, code: 400)
            }
        }
        
        // POST /_wallet/sign_bitid
        //
        // Sign a message using the user's BitID private key. Calling this WILL trigger authentication
        //
        // Request body: application/json
        //      {
        //          "prompt_string": "Sign in to My Service", // shown to the user in the authentication prompt
        //          "string_to_sign": "https://bitid.org/bitid?x=2783408723", // the string to sign
        //          "bitid_url": "https://bitid.org/bitid", // the bitid url for deriving the private key
        //          "bitid_index": "0" // the bitid index as a string (just pass "0")
        //      }
        //
        // Response body: application/json
        //      {
        //          "signature": "oibwaeofbawoefb" // base64-encoded signature
        //      }
        router.post("/_wallet/sign_bitid") { (request, match) -> BRHTTPResponse in
            guard let cts = request.headers["content-type"] where cts.count == 1 && cts[0] == "application/json" else {
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let data = request.body(),
                      j = try? NSJSONSerialization.JSONObjectWithData(data, options: []),
                      json = j as? [String: String],
                      stringToSign = json["string_to_sign"],
                      bitidUrlString = json["bitid_url"], bitidUrl = NSURL(string: bitidUrlString),
                      bii = json["bitid_index"], bitidIndex = Int(bii) else {
                return BRHTTPResponse(request: request, code: 400)
            }
            var maybeSeed: NSData?
            dispatch_sync(dispatch_get_main_queue()) {
                maybeSeed = self.manager.seedWithPrompt((bitidUrl.host ?? bitidUrl.description), forAmount: 0)
            }
            guard let seed = maybeSeed else {
                return BRHTTPResponse(request: request, code: 401)
            }
            let seq = BRBIP32Sequence()
            guard let kd = seq.bitIdPrivateKey(UInt32(bitidIndex), forURI: bitidUrl.description, fromSeed: seed),
                      key = BRKey(privateKey: kd) else {
                return BRHTTPResponse(request: request, code: 500)
            }
            let sig = BRBitID.signMessage(stringToSign, usingKey: key)
            let ret: [String: AnyObject] = [
                "signature": sig
            ]
            guard let jsonData = try? NSJSONSerialization.dataWithJSONObject(ret, options: []) else {
                return BRHTTPResponse(request: request, code: 500)
            }
            var jsonBytes = [UInt8](count: jsonData.length, repeatedValue: 0)
            jsonData.getBytes(&jsonBytes)
            let headers: [String: [String]] = [
                "Content-Type": ["application/json"]
            ]
            return BRHTTPResponse(
                request: request, statusCode: 200, statusReason: "OK", headers: headers, body: jsonBytes
            )
        }
    }
    
    // MARK: - basic wallet functions
    
    func walletInfo() -> [String: AnyObject] {
        var d = [String: AnyObject]()
        d["no_wallet"] = manager.noWallet
        d["watch_only"] = manager.watchOnly
        d["receive_address"] = manager.wallet?.receiveAddress
        return d
    }
    
    func currencyFormat(amount: Int64) -> [String: AnyObject] {
        var d = [String: AnyObject]()
        d["local_currency_amount"] = manager.localCurrencyStringForAmount(Int64(amount))
        d["currency_amount"] = manager.stringForAmount(amount)
        return d
    }
    
    // MARK: - socket handlers
    
    func sendWalletInfo(socket: BRWebSocket) {
        var d = self.walletInfo()
        d["type"] = "wallet"
        if let jdata = try? NSJSONSerialization.dataWithJSONObject(d, options: []),
            jstring = NSString(data: jdata, encoding: NSUTF8StringEncoding) {
            socket.send(String(jstring))
        }
    }
    
    func socketDidConnect(socket: BRWebSocket) {
        print("WALLET CONNECT \(socket.id)")
        sockets[socket.id] = socket
        sendWalletInfo(socket)
    }
    
    func socketDidDisconnect(socket: BRWebSocket) {
        print("WALLET DISCONNECT \(socket.id)")
        sockets.removeValueForKey(socket.id)
    }
    
    func socket(socket: BRWebSocket, didReceiveText text: String) {
        print("WALLET RECV \(text)")
        socket.send(text)
    }
}