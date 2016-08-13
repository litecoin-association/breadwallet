//
//  BRReplicatedKVStoreTests.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/10/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import XCTest
@testable import breadwallet

class BRReplicatedKVStoreTestAdapter: BRRemoteKVStoreAdaptor {
    let testCase: XCTestCase
    var db = [String: (UInt64, NSDate, [UInt8], Bool)]()
    
    init(testCase: XCTestCase) {
        self.testCase = testCase
        db["hello"] = (1, NSDate(), [0, 1], false)
        db["removed"] = (2, NSDate(), [0, 2], true)
        for i in 1...20 {
            db["testkey-\(i)"] = (1, NSDate(), [0, UInt8(i + 2)], false)
        }
    }
    
    func keys(completionFunc: ([(String, UInt64, NSDate, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] KEYS")
        dispatch_async(dispatch_get_main_queue()) { 
            let res = self.db.map { (t) -> (String, UInt64, NSDate, BRRemoteKVStoreError?) in
                return (t.0, t.1.0, t.1.1, t.1.3 ? BRRemoteKVStoreError.Tombstone : nil)
            }
            completionFunc(res, nil)
        }
    }
    
    func ver(key: String, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] VER \(key)")
        dispatch_async(dispatch_get_main_queue()) { 
            guard let obj = self.db[key] else {
                return completionFunc(0, NSDate(), .NotFound)
            }
            completionFunc(obj.0, obj.1, obj.3 ? .Tombstone : nil)
        }
    }
    
    func get(key: String, version: UInt64, completionFunc: (UInt64, NSDate, [UInt8], BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] GET \(key) \(version)")
        dispatch_async(dispatch_get_main_queue()) { 
            guard let obj = self.db[key] else {
                return completionFunc(0, NSDate(), [], .NotFound)
            }
            if version != obj.0 {
                return completionFunc(0, NSDate(), [], .Conflict)
            }
            completionFunc(obj.0, obj.1, obj.2, obj.3 ? .Tombstone : nil)
        }
    }
    
    func put(key: String, value: [UInt8], version: UInt64, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] PUT \(key) \(version)")
        dispatch_async(dispatch_get_main_queue()) { 
            guard let obj = self.db[key] else {
                if version != 0 {
                    return completionFunc(1, NSDate(), .NotFound)
                }
                let newObj = (UInt64(1), NSDate(), value, false)
                self.db[key] = newObj
                return completionFunc(1, newObj.1, nil)
            }
            if version != obj.0 {
                return completionFunc(0, NSDate(), .Conflict)
            }
            let newObj = (obj.0 + 1, NSDate(), value, false)
            self.db[key] = newObj
            completionFunc(newObj.0, newObj.1, nil)
        }
    }
    
    func del(key: String, version: UInt64, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] DEL \(key) \(version)")
        dispatch_async(dispatch_get_main_queue()) { 
            guard let obj = self.db[key] else {
                return completionFunc(0, NSDate(), .NotFound)
            }
            if version != obj.0 {
                return completionFunc(0, NSDate(), .Conflict)
            }
            let newObj = (obj.0 + 1, NSDate(), obj.2, true)
            self.db[key] = newObj
            completionFunc(newObj.0, newObj.1, nil)
        }
    }
}

class BRReplicatedKVStoreTest: XCTestCase {
    var store: BRReplicatedKVStore!
    var key = BRKey(privateKey: "S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy")!
    var adapter: BRReplicatedKVStoreTestAdapter!
    
    override func setUp() {
        super.setUp()
        adapter = BRReplicatedKVStoreTestAdapter(testCase: self)
        store = try! BRReplicatedKVStore(encryptionKey: key, remoteAdaptor: adapter)
    }
    
    override func tearDown() {
        super.tearDown()
        try! store.rmdb()
        store = nil
    }
    
    func XCTAssertDatabasesAreSynced() { // this only works for keys that are not marked deleted
        var remoteKV = [String: [UInt8]]()
        for (k, v) in adapter.db {
            if !v.3 {
                remoteKV[k] = v.2
            }
        }
        let allLocalKeys = try! store.localKeys()
        var localKV = [String: [UInt8]]()
        for i in allLocalKeys {
            if !i.4 {
                localKV[i.0] = try! store.get(i.0).3
            }
        }
        for (k, v) in remoteKV {
            XCTAssertEqual(v, localKV[k] ?? [])
        }
        for (k, v) in localKV {
            XCTAssertEqual(v, remoteKV[k] ?? [])
        }
    }
    
    // MARK: - local db tests
    
    func testSetLocalDoesntThrow() {
        let (v1, t1) = try! store.set("hello", value: [0, 0, 0], localVer: 0)
        XCTAssertEqual(1, v1)
        XCTAssertNotNil(t1)
    }
    
    func testSetLocalIncrementsVersion() {
        try! store.set("hello", value: [0, 1], localVer: 0)
        XCTAssertEqual(try! store.localVersion("hello").0, 1)
    }
    
    func testSetThenGet() {
        let (v1, t1) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (v, t, d, val) = try! store.get("hello")
        XCTAssertEqual(val, [0, 1])
        XCTAssertEqual(v1, v)
        XCTAssertEqualWithAccuracy(t1.timeIntervalSince1970, t.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(d, false)
    }
    
    func testSetThenSetIncrementsVersion() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (v2, _) = try! store.set("hello", value: [0, 2], localVer: v1)
        XCTAssertEqual(v2, v1 + 1)
    }
    
    func testSetThenDel() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (v2, _) = try! store.del("hello", localVer: v1)
        XCTAssertEqual(v2, v1 + 1)
    }
    
    func testSetThenDelThenGet() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        try! store.del("hello", localVer: v1)
        let (v2, _, d, _) = try! store.get("hello")
        XCTAssert(d)
        XCTAssertEqual(v2, v1 + 1)
    }
    
    func testSetWithIncorrectFirstVersionFails() {
        XCTAssertThrowsError(try store.set("hello", value: [0, 1], localVer: 1))
    }
    
    func testSetWithStaleVersionFails() {
        try! store.set("hello", value: [0, 1], localVer: 0)
        XCTAssertThrowsError(try store.set("hello", value: [0, 1], localVer: 0))
    }
    
    func testGetNonExistentKeyFails() {
        XCTAssertThrowsError(try store.get("hello"))
    }
    
    func testGetNonExistentKeyVersionFails() {
        XCTAssertThrowsError(try store.get("hello", version: 1))
    }
    
    func testGetAllKeys() {
        let (v1, t1) = try! store.set("hello", value: [0, 1], localVer: 0)
        let lst = try! store.localKeys()
        XCTAssertEqual(1, lst.count)
        XCTAssertEqual("hello", lst[0].0)
        XCTAssertEqual(v1, lst[0].1)
        XCTAssertEqualWithAccuracy(t1.timeIntervalSince1970, lst[0].2.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(0, lst[0].3)
        XCTAssertEqual(false, lst[0].4)
    }
    
    func testSetRemoteVersion() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (newV, _) = try! store.setRemoteVersion("hello", localVer: v1, remoteVer: 1)
        XCTAssertEqual(newV, v1 + 1)
        let rmv = try! store.remoteVersion("hello")
        XCTAssertEqual(rmv, 1)
    }
    
    // MARK: - syncing tests
    
    func testBasicSyncGetAllObjects() {
        let exp = expectationWithDescription("sync")
        store.syncAllKeys { (err) in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        let allKeys = try! store.localKeys()
        XCTAssertEqual(adapter.db.count - 1, allKeys.count) // minus 1: there is a deleted key that needent be synced
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncTenTimes() {
        let exp = expectationWithDescription("sync")
        var n = 10
        var handler: (e: ErrorType?) -> () = { e in return }
        handler = { (e: ErrorType?) in
            XCTAssertNil(e)
            if n > 0 {
                self.store.syncAllKeys(handler)
                n -= 1
            } else {
                exp.fulfill()
            }
        }
        handler(e: nil)
        waitForExpectationsWithTimeout(2, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncAddsLocalKeysToRemote() {
        store.syncImmediately = false
        try! store.set("derp", value: [0, 1], localVer: 0)
        let exp = expectationWithDescription("sync")
        store.syncAllKeys { (err) in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertEqual(adapter.db["derp"]!.2, [0, 1])
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncSavesRemoteVersion() {
        let exp = expectationWithDescription("sync")
        store.syncAllKeys { err in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        let rv = try! store.remoteVersion("hello")
        XCTAssertEqual(adapter.db["hello"]!.0, 1) // it should not have done any mutations
        XCTAssertEqual(adapter.db["hello"]!.0, rv) // only saved the remote version
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncPreventsAnotherConcurrentSync() {
        let exp1 = expectationWithDescription("sync")
        let exp2 = expectationWithDescription("sync2")
        store.syncAllKeys { e in exp1.fulfill() }
        store.syncAllKeys { (e) in
            XCTAssertEqual(e, BRReplicatedKVStoreError.AlreadyReplicating)
            exp2.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testLocalDeleteReplicates() {
        let exp1 = expectationWithDescription("sync1")
        store.syncImmediately = false
        try! store.set("goodbye_cruel_world", value: [0, 1], localVer: 0)
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        try! store.del("goodbye_cruel_world",
                       localVer: try! store.localVersion("goodbye_cruel_world").0)
        let exp2 = expectationWithDescription("sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        XCTAssertEqual(adapter.db["goodbye_cruel_world"]!.3, true)
    }
    
    func testLocalUpdateReplicates() {
        let exp1 = expectationWithDescription("sync1")
        store.syncImmediately = false
        try! store.set("goodbye_cruel_world", value: [0, 1], localVer: 0)
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        try! store.set("goodbye_cruel_world", value: [1, 0, 0, 1],
                       localVer: try! store.localVersion("goodbye_cruel_world").0)
        let exp2 = expectationWithDescription("sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testRemoteDeleteReplicates() {
        let exp1 = expectationWithDescription("sync1")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        adapter.db["hello"]?.0 += 1
        adapter.db["hello"]?.1 = NSDate()
        adapter.db["hello"]?.3 = true
        let exp2 = expectationWithDescription("sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        let h = try! store.get("hello")
        XCTAssertEqual(h.2, true)
        let exp3 = expectationWithDescription("sync3")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp3.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testRemoteUpdateReplicates() {
        let exp1 = expectationWithDescription("sync1")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        adapter.db["hello"]?.0 += 1
        adapter.db["hello"]?.1 = NSDate()
        adapter.db["hello"]?.2 = [0, 1, 1, 1, 1, 1, 11 , 1, 1, 1, 1, 1, 0x8c]
        let exp2 = expectationWithDescription("sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
        let h = try! store.get("hello")
        XCTAssertEqual(h.3, [0, 1, 1, 1, 1, 1, 11 , 1, 1, 1, 1, 1, 0x8c])
        let exp3 = expectationWithDescription("sync3")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp3.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
}
