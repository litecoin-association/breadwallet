//
//  BRReplicatedKVStore.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/10/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import Foundation

enum BRReplicatedKVStoreError: ErrorType {
    case SQLiteError
}


public class BRReplicatedKVStore {
    var db: COpaquePointer = nil
    
    var path: NSURL {
        let fm = NSFileManager.defaultManager()
        let docsUrl = fm.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let bundleDirUrl = docsUrl.URLByAppendingPathComponent("kvstore.sqlite3")
        return bundleDirUrl
    }
    
    init() throws {
        db = try openDatabase()
        try migrateDatabase()
    }
    
    public func rmdb() throws {
        try checkErr(sqlite3_close(db), s: "rmdb - close")
        try NSFileManager.defaultManager().removeItemAtURL(path)
    }
    
    func openDatabase() throws -> COpaquePointer {
        var dd: COpaquePointer = nil
        try checkErr(sqlite3_open(path.absoluteString, &dd), s: "opening db")
        log("opened DB at \(path.absoluteString)")
        return dd
    }
    
    func migrateDatabase() throws {
        let commands = [
            "CREATE TABLE IF NOT EXISTS dbversion (ver INT NOT NULL PRIMARY KEY ON CONFLICT REPLACE);",
            "INSERT INTO dbversion (ver) VALUES (1);",
            "CREATE TABLE IF NOT EXISTS kvstore (" +
            "   version BIGINT  NOT NULL, " +
            "   key     TEXT    NOT NULL, " +
            "   value   BLOB    NOT NULL, " +
            "   thetime BIGINT  NOT NULL, " + // server unix timestamp in MS
            "   deleted BOOL    NOT NULL, " +
            "   PRIMARY KEY (key, version) " +
            ")"
        ];
        for cmd in commands {
            var cts: COpaquePointer = nil
            defer {
                sqlite3_finalize(cts)
            }
            try checkErr(sqlite3_prepare_v2(db, cmd, -1, &cts, nil), s: "migrate prepare")
            try checkErr(sqlite3_step(cts), s: "migrate stmt exec")
        }
    }
    
    func get(key: String) throws -> (UInt64, NSDate, Bool, [UInt8]) {
        var ret = [UInt8]()
        var curVer: UInt64 = 0
        var deleted = false
        var time = NSDate()
        try txn({
            curVer = try self.localVersion(key)
            self.log("GET key: \(key) ver: \(curVer)")
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "SELECT value, length(value), thetime, deleted FROM kvstore WHERE key=? AND version=? LIMIT 1", -1, &stmt, nil
            ), s: "get - prepare stmt")
            sqlite3_bind_text(stmt, 1, NSString(string: key).UTF8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "get - step stmt", r: SQLITE_ROW)
            let blob = sqlite3_column_blob(stmt, 0)
            let blobLength = sqlite3_column_int(stmt, 1)
            time = NSDate(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 2))/1000.0)
            deleted = sqlite3_column_int(stmt, 3) > 0
            ret = Array(UnsafeBufferPointer<UInt8>(start: UnsafePointer(blob), count: Int(blobLength)))
        })
        return (curVer, time, deleted, ret)
    }
    
    func set(key: String, value: [UInt8], encrypted: Bool = false) throws -> (UInt64, NSDate) {
        var newVer: UInt64 = 0
        var time = NSDate(timeIntervalSince1970: Double(Int64(NSDate().timeIntervalSince1970*1000)))
        try txn({ 
            let curVer = try self.localVersion(key)
            self.log("SET key: \(key) ver: \(curVer)")
            newVer = curVer + 1
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(self.db,
                "INSERT INTO kvstore (version, key, value, thetime, deleted) " +
                "VALUES (?, ?, ?, ?, ?)", -1, &stmt, nil
            ), s: "set - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_text(stmt, 2, NSString(string: key).UTF8String, -1, nil)
            sqlite3_bind_blob(stmt, 3, value, Int32(value.count), nil)
            sqlite3_bind_int64(stmt, 4, Int64(time.timeIntervalSince1970*1000))
            sqlite3_bind_int(stmt, 5, 0)
            try self.checkErr(sqlite3_step(stmt), s: "set - step stmt")
        })
        syncKey(key) { 
            self.log("key synced: \(key)")
        }
        return (newVer, time)
    }
    
    func del(key: String) throws -> (UInt64, NSDate) {
        var newVer: UInt64 = 0
        var time = NSDate(timeIntervalSince1970: Double(Int64(NSDate().timeIntervalSince1970*1000)))
        try txn({ 
            let curVer = try self.localVersion(key)
            self.log("DEL key: \(key) ver: \(curVer)")
            newVer = curVer + 1
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "INSERT INTO kvstore (version, key, value, thetime, deleted) " +
                         "SELECT ?, key, value, ?, ? " +
                         "FROM kvstore WHERE key=? AND version=? ORDER BY version DESC LIMIT 1",
                -1, &stmt, nil
            ), s: "del - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_int64(stmt, 2, Int64(time.timeIntervalSince1970*1000))
            sqlite3_bind_int(stmt, 3, 1)
            sqlite3_bind_text(stmt, 4, NSString(string: key).UTF8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "del - exec stmt")
        })
        return (newVer, time)
    }
    
    func localVersion(key: String) throws -> UInt64 {
        var stmt: COpaquePointer = nil
        defer {
            sqlite3_finalize(stmt)
        }
        try checkErr(sqlite3_prepare_v2(
            db, "SELECT version FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1, &stmt, nil
        ), s: "get version - prepare")
        sqlite3_bind_text(stmt, 1, NSString(string: key).UTF8String, -1, nil)
        try checkErr(sqlite3_step(stmt), s: "get version - exec", r: SQLITE_ROW)
        return UInt64(sqlite3_column_int64(stmt, 0))
    }
    
    func syncAllKeys(completionHandler: () -> ()) {
        
    }
    
    func syncKey(key: String, completionHandler: () -> ()) {
        
    }
    
    func txn(fn: () throws -> ()) throws {
        var beginStmt: COpaquePointer = nil
        var finishStmt: COpaquePointer = nil
        defer {
            sqlite3_finalize(beginStmt)
            sqlite3_finalize(finishStmt)
        }
        try checkErr(sqlite3_prepare_v2(db, "BEGIN", -1, &beginStmt, nil), s: "txn - prepare begin")
        try checkErr(sqlite3_step(beginStmt), s: "txn - exec begin begin")
        do {
            try fn()
        } catch let e {
            try checkErr(sqlite3_prepare_v2(db, "ROLLBACK" , -1, &finishStmt, nil), s: "txn - prepare rollback")
            try checkErr(sqlite3_step(finishStmt), s: "txn - execute rollback")
            throw e
        }
        try checkErr(sqlite3_prepare_v2(db, "COMMIT", -1, &finishStmt, nil), s: "txn - prepare commit")
        try checkErr(sqlite3_step(finishStmt), s: "txn - execute commit")
    }
    
    func checkErr(e: Int32, s: String, r: Int32 = SQLITE_NULL) throws {
        if (r == SQLITE_NULL && (e != SQLITE_OK && e != SQLITE_DONE && e != SQLITE_ROW)) && (e != SQLITE_NULL && e != r) {
            let es = NSString(CString: sqlite3_errstr(e), encoding: NSUTF8StringEncoding)
            let em = NSString(CString: sqlite3_errmsg(db), encoding: NSUTF8StringEncoding)
            log("\(s): errcode=\(e) errstr=\(es) errmsg=\(em)")
            throw BRReplicatedKVStoreError.SQLiteError
        }
    }
    
    func log(s: String) {
        print("[KVStore]: \(s)")
    }
}
