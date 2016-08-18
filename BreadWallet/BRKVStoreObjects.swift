//
//  BRKVStoreObjects.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/13/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
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

// MARK: - Txn Metadata

// Txn metadata stores additional information about a given transaction


@objc public class BRTxMetadataObject: BRKVStoreObject, BRCoding {
    var classVersion: Int = 1
    
    var blockHeight: Int = 0
    var exchangeRate: Int = 0
    var exchangeRateCurrency: String = ""
    var size: Int = 0
    var created: NSDate = NSDate.zeroValue()
    var firstConfirmation: NSDate = NSDate.zeroValue()
    
    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        if classVersion == Int.zeroValue() {
            print("Unable to unarchive _TXMetadata: no version")
            return nil
        }
        blockHeight = decoder.decode("bh")
        exchangeRate = decoder.decode("er")
        exchangeRateCurrency = decoder.decode("erc")
        size = decoder.decode("s")
        firstConfirmation = decoder.decode("fconf")
        created = decoder.decode("c")
        super.init(key: "", version: 0, lastModified: NSDate(), deleted: true, data: NSData())
    }
    
    func encode(coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(blockHeight, key: "bh")
        coder.encode(exchangeRate, key: "er")
        coder.encode(exchangeRateCurrency, key: "erc")
        coder.encode(size, key: "s")
        coder.encode(firstConfirmation, key: "fconf")
        coder.encode(created, key: "c")
    }
    
    /// Find metadata object based on the txHash
    public init?(txHash: UInt256, store: BRReplicatedKVStore) {
        var ver: UInt64
        var date: NSDate
        var del: Bool
        var bytes: [UInt8]
        print("find \(txHash.txKey)")
        do {
            (ver, date, del, bytes) = try store.get(txHash.txKey)
        } catch let e {
            print("Unable to initialize BRTxMetadataObject: \(e)")
            return nil
        }
        let bytesDat = NSData(bytes: &bytes, length: bytes.count)
        super.init(key: txHash.txKey, version: ver, lastModified: date, deleted: del, data: bytesDat)
    }
    
    /// Create new transaction metadata
    public init(transaction: BRTransaction) {
        print("new \(transaction.txHash.txKey)")
        super.init(key: transaction.txHash.txKey, version: 0, lastModified: NSDate(), deleted: false, data: NSData())
        blockHeight = Int(transaction.blockHeight)
        created = NSDate()
    }
    
    override func getData() -> NSData? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    override func dataWasSet(value: NSData) {
        guard let s: BRTxMetadataObject = BRKeyedUnarchiver.unarchiveObjectWithData(value) else {
            print("unable to deserialise tx metadata")
            return
        }
        blockHeight =           s.blockHeight
        exchangeRate =          s.exchangeRate
        exchangeRateCurrency =  s.exchangeRateCurrency
        size =                  s.size
        firstConfirmation =     s.firstConfirmation
        created =               s.created
    }
}

extension UInt256 {
    var txKey: String {
        get {
            var u = self
            return withUnsafePointer(&u) { p in
                let bd = NSData(bytes: p, length: sizeofValue(p)).SHA256()
                return "txn-\(bd.hexString)"
            }
        }
    }
    
    var hexString: String {
        get {
            var u = self
            return withUnsafePointer(&u, { p in
                return NSData(bytes: p, length: sizeofValue(p)).hexString
            })
        }
    }
}
