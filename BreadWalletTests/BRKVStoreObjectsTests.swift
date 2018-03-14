//
//  BRKVStoreObjectsTests.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/14/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import XCTest
@testable import breadwallet

class BRKVStoreObjectsTests: XCTestCase {
    var adaptor: BRReplicatedKVStoreTestAdapter!
    var store: BRReplicatedKVStore!
    var key = BRKey(privateKey: "S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy")!

    override func setUp() {
        super.setUp()
        adaptor = BRReplicatedKVStoreTestAdapter(testCase: self)
        store = try! BRReplicatedKVStore(encryptionKey: key, remoteAdaptor: adaptor)
    }
    
    override func tearDown() {
        try! store.rmdb()
        store = nil
        adaptor = nil
        super.tearDown()
    }

    func getTxn() -> BRTransaction {
        let script = NSMutableData()
        let s = "0000000000000000000000000000000000000000000000000000000000000001".hexToData()!
//        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<UInt256>.size)
//        s.copyBytes(to: p, count: 32)
//        let sec = p.move()
        let k = s.withUnsafeBytes { (p: UnsafePointer<UInt256>) -> BRKey in
            return BRKey(secret: p.pointee, compressed: true)!
        }
//        let k = BRKey(secret: sec, compressed: true)!
        let hash = NSValue(uInt256: UInt256(u64: (0, 0, 0, 0)))
        script.appendScriptPubKey(forAddress: k.address)
        let tx = BRTransaction(inputHashes: [hash], inputIndexes: [NSNumber(value: 0 as Int32)], inputScripts: [script],
                               outputAddresses: [k.address!, k.address!],
                               outputAmounts: [NSNumber(value: 0 as Int32), NSNumber(value: 0 as Int32)])!
        tx.sign(withPrivateKeys: [k.privateKey!])
        return tx
    }
    
    func testTxnMetadataGetSet() {
        let tx = getTxn()
        
        let notThere = BRTxMetadataObject(txHash: tx.txHash, store: store)
        XCTAssertNil(notThere)
        
        let newObj = BRTxMetadataObject(transaction: tx, exchangeRate: 500.0, exchangeRateCurrency: "USD", feeRate: 33784, deviceId: "ABC123")
        XCTAssertEqual(newObj.blockHeight, Int(tx.blockHeight))
        _ = try! store.set(newObj)
        
        guard let fetchedObj = BRTxMetadataObject(txHash: tx.txHash, store: store) else {
            XCTFail()
            return
        }
        XCTAssertEqual(fetchedObj.blockHeight, Int(tx.blockHeight))
        
        let otherNewObj = BRTxMetadataObject(transaction: tx, exchangeRate: 500.0, exchangeRateCurrency: "USD", feeRate: 33784, deviceId: "ABC123")
        XCTAssertThrowsError(try store.set(otherNewObj))
    }
}
