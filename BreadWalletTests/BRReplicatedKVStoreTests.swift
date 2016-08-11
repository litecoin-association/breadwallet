//
//  BRReplicatedKVStoreTests.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/10/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import XCTest
@testable import breadwallet

class BRReplicatedKVStoreTest: XCTestCase {
    var store: BRReplicatedKVStore!
    var key = BRKey(privateKey: "S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy")!
    
    override func setUp() {
        super.setUp()
        store = try! BRReplicatedKVStore(encryptionKey: key)
    }
    
    override func tearDown() {
        super.tearDown()
        try! store.rmdb()
        store = nil
    }
    
    // MARK: - local db tests
    
    func testSetLocalDoesntThrow() {
        let (v1, t1) = try! store.set("hello", value: [0, 0, 0])
        XCTAssertEqual(1, v1)
        XCTAssertNotNil(t1)
    }
    
    func testSetLocalIncrementsVersion() {
        try! store.set("hello", value: [0, 1])
        XCTAssertEqual(try! store.localVersion("hello"), 1)
    }
    
    func testSetThenGet() {
        let (v1, t1) = try! store.set("hello", value: [0, 1])
        let (v, t, d, val) = try! store.get("hello")
        XCTAssertEqual(val, [0, 1])
        XCTAssertEqual(v1, v)
        XCTAssertEqualWithAccuracy(t1.timeIntervalSince1970, t.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(d, false)
    }
    
    func testSetThenSetIncrementsVersion() {
        let (v1, _) = try! store.set("hello", value: [0, 1])
        let (v2, _) = try! store.set("hello", value: [0, 2])
        XCTAssertEqual(v2, v1 + 1)
    }
    
    func testSetThenDel() {
        let (v1, _) = try! store.set("hello", value: [0, 1])
        let (v2, _) = try! store.del("hello")
        XCTAssertEqual(v2, v1 + 1)
    }
    
    func testSetThenDelThenGet() {
        let (v1, _) = try! store.set("hello", value: [0, 1])
        try! store.del("hello")
        let (v2, _, d, _) = try! store.get("hello")
        XCTAssert(d)
        XCTAssertEqual(v2, v1 + 1)
    }
}
