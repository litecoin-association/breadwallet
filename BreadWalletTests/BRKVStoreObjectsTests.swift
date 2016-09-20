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
        let s = "0000000000000000000000000000000000000000000000000000000000000001".hexToData()
        let p = UnsafeMutablePointer<UInt256>.alloc(sizeof(UInt256))
        s.getBytes(p)
        let sec = p.move()
        let k = BRKey(secret: sec, compressed: true)!
        let hash = NSValue(UInt256: UInt256(u64: (0, 0, 0, 0)))
        script.appendScriptPubKeyForAddress(k.address)
        let tx = BRTransaction(inputHashes: [hash], inputIndexes: [NSNumber(int: 0)], inputScripts: [script],
                               outputAddresses: [k.address!, k.address!],
                               outputAmounts: [NSNumber(int: 0), NSNumber(int: 0)])
        tx.signWithPrivateKeys([k.privateKey!])
        return tx
    }
    
    func testTxnMetadataGetSet() {
        let tx = getTxn()
        
        let notThere = BRTxMetadataObject(txHash: tx.txHash, store: store)
        XCTAssertNil(notThere)
        
        let newObj = BRTxMetadataObject(transaction: tx, exchangeRate: 500.0, exchangeRateCurrency: "USD", feeRate: 33784, deviceId: "ABC123")
        XCTAssertEqual(newObj.blockHeight, Int(tx.blockHeight))
        try! store.set(newObj)
        
        guard let fetchedObj = BRTxMetadataObject(txHash: tx.txHash, store: store) else {
            XCTFail()
            return
        }
        XCTAssertEqual(fetchedObj.blockHeight, Int(tx.blockHeight))
        
        let otherNewObj = BRTxMetadataObject(transaction: tx, exchangeRate: 500.0, exchangeRateCurrency: "USD", feeRate: 33784, deviceId: "ABC123")
        XCTAssertThrowsError(try store.set(otherNewObj))
    }
}
