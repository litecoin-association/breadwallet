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

@objc class _TXMetadata: NSObject, BRCoding {
    var classVersion: Int = 1
    
    var blockHeight: Int = 0
    var exchangeRate: Int = 0
    var exchangeRateCurrency: String = ""
    var confirmations: Int = 0
    var size: Int = 0
    var created: NSDate = NSDate.zeroValue()
    var firstConfirmation: NSDate = NSDate.zeroValue()
    
    override init() {
        super.init()
    }
    
    required init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        if classVersion == Int.zeroValue() {
            print("Unable to unarchive _TXMetadata: no version")
            return nil
        }
        blockHeight = decoder.decode("bh")
        exchangeRate = decoder.decode("er")
        exchangeRateCurrency = decoder.decode("erc")
        confirmations = decoder.decode("conf")
        size = decoder.decode("s")
        firstConfirmation = decoder.decode("fconf")
        created = decoder.decode("c")
    }
    
    func encode(coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(blockHeight, key: "blockHeight")
        coder.encode(exchangeRate, key: "exchangeRate")
        coder.encode(exchangeRateCurrency, key: "exchangeRateCurrency")
        coder.encode(confirmations, key: "confirmations")
        coder.encode(size, key: "size")
        coder.encode(firstConfirmation, key: "firstConfirmation")
        coder.encode(created, key: "created")
    }
}

@objc public class BRTxMetadataObject: BRKVStoreObject {
    var blockHeight: Int {
        get { return _meta.blockHeight }
        set(v) { _meta.blockHeight = v }
    }
    var exchangeRate: Int {
        get { return _meta.exchangeRate }
        set(v) { _meta.exchangeRate = v }
    }
    var exchangeRateCurrency: String {
        get { return _meta.exchangeRateCurrency }
        set(v) { _meta.exchangeRateCurrency = v }
    }
    var confirmations: Int {
        get { return _meta.confirmations }
        set(v) { _meta.confirmations = v }
    }
    var size: Int {
        get { return _meta.size }
        set(v) { _meta.size = v }
    }
    var firstConfirmation: NSDate {
        get { return _meta.firstConfirmation }
        set(v) { _meta.firstConfirmation = v }
    }
    var created: NSDate {
        get { return _meta.created }
        set(v) { _meta.created = v }
    }
    
    // this is get and set by the `data` accessor
    // if the data is invalid for some reason it create a fresh instance
    private var _meta: _TXMetadata!
    
    public override var data: NSData {
        get {
            return NSKeyedArchiver.archivedDataWithRootObject(_meta)
        }
        set(v) {
            _meta = (NSKeyedUnarchiver.unarchiveObjectWithData(v) as? _TXMetadata) ?? _TXMetadata()
        }
    }
    
    /// Find metadata object based on the txHash
    public init?(txHash: NSData, store: BRReplicatedKVStore) {
        var sha = txHash.SHA256()
        let txHashHash = NSData(bytes: &sha, length: sizeof(UInt256))
        let key = "txm-\(txHashHash.hexString)"
        var ver: UInt64
        var date: NSDate
        var del: Bool
        var bytes: [UInt8]
        do {
            (ver, date, del, bytes) = try store.get(key)
        } catch let e {
            print("Unable to initialize BRTxMetadataObject: \(e)")
            return nil
        }
        let bytesDat = NSData(bytes: &bytes, length: bytes.count)
        super.init(key: key, version: ver, lastModified: date, deleted: del, data: bytesDat)
    }
    
    /// Create new transaction metadata
    public init(transaction: BRTransaction) {
        var sha = NSData(bytes: &transaction.txHash, length: sizeof(UInt256)).SHA256()
        let txHashHash = NSData(bytes: &sha, length: sizeof(UInt256))
        let k = "txm-\(txHashHash.hexString)"
        super.init(key: k, version: 0, lastModified: NSDate(), deleted: false, data: NSData())
    }
}
