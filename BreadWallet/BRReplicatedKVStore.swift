//
//  BRReplicatedKVStore.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/10/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import Foundation

public enum BRReplicatedKVStoreError: ErrorType {
    case SQLiteError
    case ReplicationError
    case AlreadyReplicating
    case Conflict
    case NotFound
    case Unknown
}

public enum BRRemoteKVStoreError: ErrorType {
    case NotFound
    case Conflict
    case Tombstone
    case Unknown
}

public protocol BRRemoteKVStoreAdaptor {
    func ver(key: String, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ())
    func put(key: String, value: [UInt8], version: UInt64, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ())
    func del(key: String, version: UInt64, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ())
    func get(key: String, version: UInt64, completionFunc: (UInt64, NSDate, [UInt8], BRRemoteKVStoreError?) -> ())
    func keys(completionFunc: ([(String, UInt64, NSDate, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> ())
}

public class BRReplicatedKVStore {
    var db: COpaquePointer = nil // sqlite3*
    var key: BRKey
    var remote: BRRemoteKVStoreAdaptor
    var syncRunning = false
    
    var path: NSURL {
        let fm = NSFileManager.defaultManager()
        let docsUrl = fm.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let bundleDirUrl = docsUrl.URLByAppendingPathComponent("kvstore.sqlite3")
        return bundleDirUrl
    }
    
    init(encryptionKey: BRKey, remoteAdaptor: BRRemoteKVStoreAdaptor) throws {
        key = encryptionKey
        remote = remoteAdaptor
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
            "   version         BIGINT  NOT NULL, " +
            "   remote_version  BIGINT  NOT NULL DEFAULT 0, " +
            "   key             TEXT    NOT NULL, " +
            "   value           BLOB    NOT NULL, " +
            "   thetime         BIGINT  NOT NULL, " + // server unix timestamp in MS
            "   deleted         BOOL    NOT NULL, " +
            "   PRIMARY KEY (key, version) " +
            ");"
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
    
    // get a key from the local database, optionally specifying a version
    func get(key: String, version: UInt64 = 0) throws -> (UInt64, NSDate, Bool, [UInt8]) {
        var ret = [UInt8]()
        var curVer: UInt64 = 0
        var deleted = false
        var time = NSDate()
        try txn({
            if version == 0 {
                (curVer, _) = try self.localVersion(key)
            } else {
                // check for the existence of such a version
                var vStmt: COpaquePointer = nil
                defer {
                    sqlite3_finalize(vStmt)
                }
                try self.checkErr(sqlite3_prepare_v2(
                    self.db, "SELECT version FROM kvstore WHERE key = ? AND version = ? ORDER BY version DESC LIMIT 1",
                    -1, &vStmt, nil
                ), s: "get - get version - prepare")
                sqlite3_bind_text(vStmt, 1, NSString(string: key).UTF8String, -1, nil)
                sqlite3_bind_int64(vStmt, 2, Int64(version))
                try self.checkErr(sqlite3_step(vStmt), s: "get - get version - exec", r: SQLITE_ROW)
                curVer = UInt64(sqlite3_column_int64(vStmt, 0))
            }
            if curVer == 0 {
                throw BRReplicatedKVStoreError.NotFound
            }
            
            
            self.log("GET key: \(key) ver: \(curVer)")
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "SELECT value, length(value), thetime, deleted FROM kvstore WHERE key=? AND version=? LIMIT 1",
                -1, &stmt, nil
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
        return (curVer, time, deleted, try decrypt(ret))
    }
    
    // set a key in the database
    func set(key: String, value: [UInt8], localVer: UInt64) throws -> (UInt64, NSDate) {
        var newVer: UInt64 = 0
        var time = NSDate(timeIntervalSince1970: Double(Int64(NSDate().timeIntervalSince1970*1000)))
        try txn({
            let (curVer, _) = try self.localVersion(key)
            if curVer != localVer {
                throw BRReplicatedKVStoreError.Conflict
            }
            self.log("SET key: \(key) ver: \(curVer)")
            newVer = curVer + 1
            let encryptedData = try self.encrypt(value)
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
            sqlite3_bind_blob(stmt, 3, encryptedData, Int32(encryptedData.count), nil)
            sqlite3_bind_int64(stmt, 4, Int64(time.timeIntervalSince1970*1000))
            sqlite3_bind_int(stmt, 5, 0)
            try self.checkErr(sqlite3_step(stmt), s: "set - step stmt")
        })
        try syncKey(key) { _ in
            self.log("SET key synced: \(key)")
        }
        return (newVer, time)
    }
    
    func del(key: String, localVer: UInt64) throws -> (UInt64, NSDate) {
        if localVer == 0 {
            throw BRReplicatedKVStoreError.NotFound
        }
        var newVer: UInt64 = 0
        var time = NSDate(timeIntervalSince1970: Double(Int64(NSDate().timeIntervalSince1970*1000)))
        try txn({ 
            let (curVer, _) = try self.localVersion(key)
            if curVer != localVer {
                throw BRReplicatedKVStoreError.Conflict
            }
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
        try syncKey(key) { _ in
            self.log("DEL key synced: \(key)")
        }
        return (newVer, time)
    }
    
    func localVersion(key: String) throws -> (UInt64, NSDate) {
        var stmt: COpaquePointer = nil
        defer {
            sqlite3_finalize(stmt)
        }
        try checkErr(sqlite3_prepare_v2(
            db, "SELECT version, thetime FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1, &stmt, nil
        ), s: "get version - prepare")
        sqlite3_bind_text(stmt, 1, NSString(string: key).UTF8String, -1, nil)
        try checkErr(sqlite3_step(stmt), s: "get version - exec", r: SQLITE_ROW)
        return (UInt64(sqlite3_column_int64(stmt, 0)), NSDate(timeIntervalSince1970: sqlite3_column_double(stmt, 1)))
    }
    
    func remoteVersion(key: String) throws -> UInt64 {
        var stmt: COpaquePointer = nil
        defer {
            sqlite3_finalize(stmt)
        }
        try checkErr(sqlite3_prepare_v2(
            db, "SELECT remote_version FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1, &stmt, nil
            ), s: "get remote version - prepare")
        sqlite3_bind_text(stmt, 1, NSString(string: key).UTF8String, -1, nil)
        try checkErr(sqlite3_step(stmt), s: "get remote version - exec", r: SQLITE_ROW)
        return UInt64(sqlite3_column_int64(stmt, 0))
    }
    
    func setRemoteVersion(key: String, localVer: UInt64, remoteVer: UInt64) throws -> (UInt64, NSDate) {
        var newVer: UInt64 = 0
        var time = NSDate(timeIntervalSince1970: Double(Int64(NSDate().timeIntervalSince1970*1000)))
        try txn {
            let (locV, _) = try self.localVersion(key)
            if locV != localVer {
                throw BRReplicatedKVStoreError.Conflict
            }
            self.log("UPDATE REMOTE VERSION: \(key) ver: \(localVer)")
            newVer = locV + 1
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "INSERT INTO kvstore (version, key, value, thetime, deleted, remote_version) " +
                         "SELECT ?, key, value, ?, deleted, ? " +
                         "FROM kvstore WHERE key=? AND version=? ORDER BY version DESC LIMIT 1",
                -1, &stmt, nil
            ), s: "update remote version - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_int64(stmt, 2, Int64(time.timeIntervalSince1970*1000))
            sqlite3_bind_int64(stmt, 3, Int64(remoteVer))
            sqlite3_bind_text(stmt, 4, NSString(string: key).UTF8String, -1, nil)
            sqlite3_bind_int64(stmt, 4, Int64(locV))
            try self.checkErr(sqlite3_step(stmt), s: "update remote - exec stmt")
        }
        return (newVer, time)
    }
    
    /// Get a list of (key, localVer, localTime, remoteVer, deleted)
    func localKeys() throws -> [(String, UInt64, NSDate, UInt64, Bool)] {
        var stmt: COpaquePointer = nil
        defer {
            sqlite3_finalize(stmt)
        }
        try self.checkErr(sqlite3_prepare_v2(db,
            "SELECT kvs.key, kvs.version, kvs.thetime, kvs.remote_version, kvs.deleted " +
            "FROM kvstore kvs " +
            "INNER JOIN ( " +
            "   SELECT MAX(version) AS latest_version, key " +
            "   FROM kvstore " +
            "   GROUP BY key " +
            ") vermax " +
            "ON kvs.version = vermax.latest_version " +
            "AND kvs.key = vermax.key", -1, &stmt, nil),
                          s: "local keys - prepare stmt")
        var ret = [(String, UInt64, NSDate, UInt64, Bool)]()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let key = UnsafePointer<Int8>(sqlite3_column_text(stmt, 0))
            let ver = sqlite3_column_int64(stmt, 1)
            let date = sqlite3_column_int64(stmt, 2)
            let rver = sqlite3_column_int64(stmt, 3)
            let del = sqlite3_column_int(stmt, 4)
            ret.append((
                String.fromCString(key) ?? "",
                UInt64(ver),
                NSDate(timeIntervalSince1970: Double(date) / 1000.0),
                UInt64(rver),
                del > 0
            ))
        }
        return ret
    }
    
    func syncAllKeys(completionHandler: (BRReplicatedKVStoreError?) -> ()) {
        // update all keys locally and on the remote server, replacing missing keys
        //
        // 1. get a list of all keys from the server
        // 2. for keys that we don't have, add em
        // 3. for keys that we do have, sync em
        // 4. for keys that they don't have that we do, upload em
        if syncRunning {
            dispatch_async(dispatch_get_main_queue(), { 
                completionHandler(.AlreadyReplicating)
            })
            return
        }
        syncRunning = true
        let startTime = NSDate()
        remote.keys { (keyData, err) in
            if let err = err {
                self.log("Error fetching remote key data: \(err)")
                return
            }
            self.log("Syncing \(keyData.count) keys")
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
                var failures = 0
                var jobs = keyData
                var concurrency = 0
                let grp = dispatch_group_create()
                var runner: () -> () = { }
                runner = {
                    if concurrency < 10 && jobs.count > 0 { // run 10 concurrent jobs
                        runner()
                    }
                    if let k = jobs.popLast() {
                        dispatch_group_enter(grp)
                        concurrency += 1
                        dispatch_async(dispatch_get_main_queue()) {
                            do {
                                try self.syncKey(k.0, remoteVersion: k.1, remoteTime: k.2, remoteErr: k.3,
                                    completionHandler: { (err) in
                                        if err != nil {
                                            failures += 1
                                        }
                                        concurrency -= 1
                                        dispatch_group_leave(grp)
                                        runner()
                                })
                            } catch {
                                failures += 1
                            }
                            concurrency -= 1
                            dispatch_group_leave(grp)
                            runner()
                        }
                    }
                }
                dispatch_group_wait(grp, DISPATCH_TIME_FOREVER)
                self.syncRunning = false
                self.log("Finished syncing in \(NSDate().timeIntervalSinceDate(startTime))")
            }
        }
    }
    
    func syncKey(key: String,
                 remoteVersion: UInt64? = nil, remoteTime: NSDate? = nil, remoteErr: BRRemoteKVStoreError? = nil,
                 completionHandler: (BRReplicatedKVStoreError?) -> ()) throws {
        if let RV = remoteVersion, RT = remoteTime {
            try _syncKey(key, remoteVer: RV, remoteTime: RT, remoteErr: remoteErr, completionHandler: completionHandler)
        } else {
            remote.ver(key) { (remoteVer, remoteTime, err) in
                _ = try? self._syncKey(key, remoteVer: remoteVer, remoteTime: remoteTime, remoteErr: remoteErr,
                                       completionHandler: completionHandler)
            }
        }
    }
    
    // the syncKey kernel - this is provided so syncAllKeys can provide get a bunch of key versions at once
    // and fan out the _syncKey operations
    func _syncKey(key: String, remoteVer: UInt64, remoteTime: NSDate, remoteErr: BRRemoteKVStoreError?,
                  completionHandler: (BRReplicatedKVStoreError?) -> ()) throws {
        // this is a basic last-write-wins strategy. data loss is possible but in general
        // we will attempt to sync before making any local modifications to the data
        // and concurrency will be so low that we don't really need a fancier solution than this.
        // the strategy is:
        //
        // 1. get the remote version. this is our "lock"
        // 2. along with the remote version will come the last-modified date of the remote object
        // 3. if their last-modified date is newer than ours, overwrite ours
        // 4. if their last-modified date is older than ours, overwrite theirs
        
        // one optimization is we keep the remote version on the most recent local version, if they match,
        // there is nothing to do
        if try remoteVersion(key) == remoteVer {
            completionHandler(nil) // this key is already up to date
        }
        
        let (localVer, localTime, localDeleted, localValue) = try get(key)
        switch remoteErr {
        case nil, .Some(.Tombstone):
            let (lt, rt) = (localTime.timeIntervalSince1970, remoteTime.timeIntervalSince1970)
            if lt > rt || lt == rt {
                // local is newer (or a tiebreaker)
                if localDeleted {
                    log("Local key \(key) was deleted, removing remotely...")
                    self.remote.del(key, version: remoteVer, completionFunc: { (newRemoteVer, _, delErr) in
                        if let delErr = delErr {
                            self.log("Error deleting remote version for key \(key), error: \(delErr)")
                            return completionHandler(.ReplicationError)
                        }
                        do {
                            try self.setRemoteVersion(key, localVer: localVer, remoteVer: newRemoteVer)
                        } catch let e where e is BRReplicatedKVStoreError {
                            return completionHandler((e as! BRReplicatedKVStoreError))
                        } catch {
                            return completionHandler(.ReplicationError)
                        }
                        self.log("Local key \(key) removed on server")
                        completionHandler(nil)
                    })
                } else {
                    log("Local key \(key) is newer, updating remotely...")
                    self.remote.put(key, value: localValue, version: remoteVer, completionFunc: { (newRemoteVer, _, putErr) in
                        if let putErr = putErr {
                            self.log("Error updating remote version for key \(key), error: \(putErr)")
                            return completionHandler(.ReplicationError)
                        }
                        do {
                            try self.setRemoteVersion(key, localVer: localVer, remoteVer: newRemoteVer)
                        } catch let e where e is BRReplicatedKVStoreError {
                            return completionHandler((e as! BRReplicatedKVStoreError))
                        } catch {
                            return completionHandler(.ReplicationError)
                        }
                        self.log("Local key \(key) updated on server")
                        completionHandler(nil)
                    })
                }
            } else {
                // local is out-of-date
                if remoteErr == .Some(.Tombstone) {
                    // remote is deleted
                    log("Remote key \(key) deleted, removing locally")
                    do {
                        let (newLocalVer, _) = try self.del(key, localVer: localVer)
                        try self.setRemoteVersion(key, localVer: newLocalVer, remoteVer: remoteVer)
                    } catch let e where e is BRReplicatedKVStoreError {
                        return completionHandler((e as! BRReplicatedKVStoreError))
                    } catch {
                        return completionHandler(.ReplicationError)
                    }
                } else {
                    log("Remote key \(key) is newer, fetching...")
                    // get the remote version
                    self.remote.get(key, version: remoteVer, completionFunc: { (newRemoteVer, _, remoteData, getErr) in
                        if let getErr = getErr {
                            self.log("Error fetching the remote value for key \(getErr), error: \(getErr)")
                            return completionHandler(.ReplicationError)
                        }
                        do {
                            let (newLocalVer, _) = try self.set(key, value: remoteData, localVer: localVer)
                            try self.setRemoteVersion(key, localVer: newLocalVer, remoteVer: newRemoteVer)
                        } catch let e where e is BRReplicatedKVStoreError {
                            return completionHandler((e as! BRReplicatedKVStoreError))
                        } catch {
                            return completionHandler(.ReplicationError)
                        }
                        self.log("Updated local key \(key)")
                        completionHandler(nil)
                    })
                }
            }
        default:
            log("Error fetching remote version for key \(key), error: \(remoteErr)")
            completionHandler(.ReplicationError)
        }
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
    
    func encrypt(data: [UInt8]) throws -> [UInt8] {
        let inData = UnsafePointer<UInt8>(data)
        let nonce = genNonce()
        let outSize = chacha20Poly1305AEADEncrypt(nil, 0, key.secretKey, nonce, inData, data.count, nil, 0)
        var outData = [UInt8](count: outSize, repeatedValue: 0)
        chacha20Poly1305AEADEncrypt(&outData, outSize, key.secretKey, nonce, inData, data.count, nil, 0)
        return nonce + outData
    }
    
    func decrypt(data: [UInt8]) throws -> [UInt8] {
        let nonce = Array(data[data.startIndex...data.startIndex.advancedBy(12)])
        let inData = Array(data[data.startIndex.advancedBy(12)...(data.endIndex-1)])
        let outSize = chacha20Poly1305AEADDecrypt(nil, 0, key.secretKey, nonce, inData, inData.count, nil, 0)
        var outData = [UInt8](count: outSize, repeatedValue: 0)
        chacha20Poly1305AEADDecrypt(&outData, outSize, key.secretKey, nonce, inData, inData.count, nil, 0)
        return outData
    }
    
    func genNonce() -> [UInt8] {
        var tv = timeval()
        gettimeofday(&tv, nil)
        var t = UInt64(tv.tv_usec) * 1_000_000 + UInt64(tv.tv_usec)
        let p = [UInt8](count: 4, repeatedValue: 0)
        let dat = UnsafePointer<UInt8>(NSData(bytes: &t, length: sizeof(UInt64)).bytes)
        let buf = UnsafeBufferPointer(start: dat, count: sizeof(UInt64))
        return p + Array(buf)
    }
    
    func log(s: String) {
        print("[KVStore] \(s)")
    }
}
