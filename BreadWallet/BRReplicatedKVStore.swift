//
//  BRReplicatedKVStore.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/10/16.
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
    func put(key: String, value: [UInt8], version: UInt64,
             completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ())
    func del(key: String, version: UInt64, completionFunc: (UInt64, NSDate, BRRemoteKVStoreError?) -> ())
    func get(key: String, version: UInt64, completionFunc: (UInt64, NSDate, [UInt8], BRRemoteKVStoreError?) -> ())
    func keys(completionFunc: ([(String, UInt64, NSDate, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> ())
}

func dispatch_sync_throws(queue: dispatch_queue_t, f: () throws -> ()) throws {
    var e: ErrorType? = nil
    dispatch_sync(queue) {
        do {
            try f()
        } catch let caught {
            e = caught
        }
    }
    if let e = e {
        throw e
    }
}

public class BRReplicatedKVStore {
    private var db: COpaquePointer = nil // sqlite3*
    private(set) var key: BRKey
    private(set) var remote: BRRemoteKVStoreAdaptor
    private(set) var syncRunning = false
    private var dbQueue: dispatch_queue_t
    
    /// Whether or not we immediately sync a key when set() or del() is called
    public var syncImmediately = true
    
    private var path: NSURL {
        let fm = NSFileManager.defaultManager()
        let docsUrl = fm.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let bundleDirUrl = docsUrl.URLByAppendingPathComponent("kvstore.sqlite3")
        return bundleDirUrl
    }
    
    init(encryptionKey: BRKey, remoteAdaptor: BRRemoteKVStoreAdaptor) throws {
        key = encryptionKey
        remote = remoteAdaptor
        dbQueue = dispatch_queue_create("com.voisine.breadwallet.kvDBQueue", DISPATCH_QUEUE_SERIAL)
        try self.openDatabase()
        try self.migrateDatabase()
    }
    
    /// Removes the entire database all at once. One must call openDatabase() and migrateDatabase()
    /// if one wishes to use this instance again after calling this
    public func rmdb() throws {
        try dispatch_sync_throws(dbQueue) {
            try self.checkErr(sqlite3_close(self.db), s: "rmdb - close")
            try NSFileManager.defaultManager().removeItemAtURL(self.path)
            self.db = nil
        }
    }
    
    /// Creates the internal database connection. Called automatically in init()
    func openDatabase() throws {
        try dispatch_sync_throws(dbQueue) {
            if self.db != nil {
                print("Database already open")
                throw BRReplicatedKVStoreError.SQLiteError
            }
            try self.checkErr(sqlite3_open_v2(
                self.path.absoluteString, &self.db,
                SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil
            ), s: "opening db")
            self.log("opened DB at \(self.path.absoluteString)")
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    /// Creates the local database structure. Called automatically in init()
    func migrateDatabase() throws {
        try dispatch_sync_throws(dbQueue) {
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
                var stmt: COpaquePointer = nil
                defer {
                    sqlite3_finalize(stmt)
                }
                try self.checkErr(sqlite3_prepare_v2(self.db, cmd, -1, &stmt, nil), s: "migrate prepare")
                try self.checkErr(sqlite3_step(stmt), s: "migrate stmt exec")
            }
        }
    }
    
    // get a key from the local database, optionally specifying a version
    func get(key: String, version: UInt64 = 0) throws -> (UInt64, NSDate, Bool, [UInt8]) {
        var ret = [UInt8]()
        var curVer: UInt64 = 0
        var deleted = false
        var time = NSDate(timeIntervalSince1970: Double())
        try txn {
            if version == 0 {
                (curVer, _) = try self._localVersion(key)
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
            time = NSDate.withMsTimestamp(UInt64(sqlite3_column_int64(stmt, 2)))
            deleted = sqlite3_column_int(stmt, 3) > 0
            ret = Array(UnsafeBufferPointer<UInt8>(start: UnsafePointer(blob), count: Int(blobLength)))
        }
        return (curVer, time, deleted, try decrypt(ret))
    }
    
    /// Set the value of a key locally in the database. If syncImmediately is true (the default) then immediately
    /// after successfully saving locally, replicate to server. The `localVer` key must be the same as is currently
    /// stored in the database. To create a new key, pass `0` as `localVer`
    func set(key: String, value: [UInt8], localVer: UInt64) throws -> (UInt64, NSDate) {
        let (newVer, time) = try _set(key, value: value, localVer: localVer)
        if syncImmediately {
            try syncKey(key) { _ in
                self.log("SET key synced: \(key)")
            }
        }
        return (newVer, time)
    }
    
    private func _set(key: String, value: [UInt8], localVer: UInt64) throws -> (UInt64, NSDate) {
        var newVer: UInt64 = 0
        var time = NSDate()
        try txn {
            let (curVer, _) = try self._localVersion(key)
            if curVer != localVer {
                self.log("set key \(key) conflict: version \(localVer) != current version \(curVer)")
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
            sqlite3_bind_int64(stmt, 4, Int64(time.msTimestamp))
            sqlite3_bind_int(stmt, 5, 0)
            try self.checkErr(sqlite3_step(stmt), s: "set - step stmt")
        }
        return (newVer, time)
    }
    
    /// Mark a key as removed locally. If syncImmediately is true (the defualt) then immediately mark the key
    /// as removed on the server as well. `localVer` must match the most recent version in the local database.
    func del(key: String, localVer: UInt64) throws -> (UInt64, NSDate) {
        let (newVer, time) = try _del(key, localVer: localVer)
        if syncImmediately {
            try syncKey(key) { _ in
                self.log("DEL key synced: \(key)")
            }
        }
        return (newVer, time)
    }
    
    func _del(key: String, localVer: UInt64) throws -> (UInt64, NSDate) {
        if localVer == 0 {
            throw BRReplicatedKVStoreError.NotFound
        }
        var newVer: UInt64 = 0
        var time = NSDate()
        try txn {
            let (curVer, _) = try self._localVersion(key)
            if curVer != localVer {
                self.log("del key \(key) conflict: version \(localVer) != current version \(curVer)")
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
                         "FROM kvstore WHERE key=? AND version=?",
                -1, &stmt, nil
            ), s: "del - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_int64(stmt, 2, Int64(time.msTimestamp))
            sqlite3_bind_int(stmt, 3, 1)
            sqlite3_bind_text(stmt, 4, NSString(string: key).UTF8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "del - exec stmt")
        }
        return (newVer, time)
    }
    
    /// Gets the local version of the provided key, or 0 if it doesn't exist
    func localVersion(key: String) throws -> (UInt64, NSDate) {
        var retVer: UInt64 = 0
        var retTime = NSDate(timeIntervalSince1970: Double())
        try txn {
            (retVer, retTime) = try self._localVersion(key)
        }
        return (retVer, retTime)
    }
    
    func _localVersion(key: String) throws -> (UInt64, NSDate) {
        var stmt: COpaquePointer = nil
        defer {
            sqlite3_finalize(stmt)
        }
        try self.checkErr(sqlite3_prepare_v2(
            self.db, "SELECT version, thetime FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1,
            &stmt, nil
        ), s: "get version - prepare")
        sqlite3_bind_text(stmt, 1, NSString(string: key).UTF8String, -1, nil)
        try self.checkErr(sqlite3_step(stmt), s: "get version - exec", r: SQLITE_ROW)
        return (
            UInt64(sqlite3_column_int64(stmt, 0)),
            NSDate.withMsTimestamp(UInt64(sqlite3_column_int64(stmt, 1)))
        )
    }
    
    /// Get the remote version for the key for the most recent local version of the key, if stored.
    // If local key doesn't exist, return 0
    func remoteVersion(key: String) throws -> UInt64 {
        var ret: UInt64 = 0
        try txn {
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "SELECT remote_version FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1, &stmt, nil
                ), s: "get remote version - prepare")
            sqlite3_bind_text(stmt, 1, NSString(string: key).UTF8String, -1, nil)
            try self.checkErr(sqlite3_step(stmt), s: "get remote version - exec", r: SQLITE_ROW)
            ret = UInt64(sqlite3_column_int64(stmt, 0))
        }
        return ret
    }
    
    /// Record the remote version for the object in a new version of the local key
    func setRemoteVersion(key: String, localVer: UInt64, remoteVer: UInt64) throws -> (UInt64, NSDate) {
        if localVer < 1 {
            throw BRReplicatedKVStoreError.Conflict // setRemoteVersion can't be used for creates
        }
        var newVer: UInt64 = 0
        var time = NSDate()
        try txn {
            let (curVer, _) = try self._localVersion(key)
            if curVer != localVer {
                self.log("set remote version key \(key) conflict: version \(localVer) != current version \(curVer)")
                throw BRReplicatedKVStoreError.Conflict
            }
            self.log("SET REMOTE VERSION: \(key) ver: \(localVer) remoteVer=\(remoteVer)")
            newVer = curVer + 1
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "INSERT INTO kvstore (version, key, value, thetime, deleted, remote_version) " +
                         "SELECT               ?,       key, value, ?,       deleted, ? " +
                         "FROM kvstore WHERE key=? AND version=?",
                -1, &stmt, nil
            ), s: "update remote version - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_int64(stmt, 2, Int64(time.msTimestamp))
            sqlite3_bind_int64(stmt, 3, Int64(remoteVer))
            sqlite3_bind_text(stmt, 4, NSString(string: key).UTF8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "update remote - exec stmt")
        }
        return (newVer, time)
    }
    
    /// Get a list of (key, localVer, localTime, remoteVer, deleted)
    func localKeys() throws -> [(String, UInt64, NSDate, UInt64, Bool)] {
        var ret = [(String, UInt64, NSDate, UInt64, Bool)]()
        try txn {
            var stmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(self.db,
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
            while sqlite3_step(stmt) == SQLITE_ROW {
                let key = UnsafePointer<Int8>(sqlite3_column_text(stmt, 0))
                let ver = sqlite3_column_int64(stmt, 1)
                let date = sqlite3_column_int64(stmt, 2)
                let rver = sqlite3_column_int64(stmt, 3)
                let del = sqlite3_column_int(stmt, 4)
                ret.append((
                    String.fromCString(key) ?? "",
                    UInt64(ver),
                    NSDate.withMsTimestamp(UInt64(date)),
                    UInt64(rver),
                    del > 0
                ))
            }
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
                return completionHandler(.ReplicationError)
            }
            var localKeyData: [(String, UInt64, NSDate, UInt64, Bool)]
            do {
                localKeyData = try self.localKeys()
            } catch let e {
                self.log("Error getting local key data: \(e)")
                return completionHandler(.ReplicationError)
            }
            let allRemoteKeys = Set(keyData.map { e in return e.0 })
            var allKeyData = keyData
            for k in localKeyData {
                if !allRemoteKeys.contains(k.0) {
                    // server is missing a key that we have
                    allKeyData.append((k.0, 0, NSDate(timeIntervalSince1970: Double()), nil))
                }
            }
            
            self.log("Syncing \(allKeyData.count) keys")
            var failures = 0
            let q = dispatch_queue_create("com.voisine.breadwallet.kvSyncQueue", DISPATCH_QUEUE_CONCURRENT)
            let grp = dispatch_group_create()
            let seph = dispatch_semaphore_create(10)
            
            dispatch_group_enter(grp)
            dispatch_async(q) {
                dispatch_async(q) {
                    for k in allKeyData {
                        dispatch_semaphore_wait(seph, DISPATCH_TIME_FOREVER)
                        dispatch_group_async(grp, q) {
                            do {
                                try self.syncKey(k.0, remoteVersion: k.1, remoteTime: k.2, remoteErr: k.3,
                                    completionHandler: { (err) in
                                        if err != nil {
                                            failures += 1
                                        }
                                        dispatch_semaphore_signal(seph)
                                })
                            } catch {
                                failures += 1
                                dispatch_semaphore_signal(seph)
                            }
                        }
                    }
                    dispatch_group_leave(grp)
                }
                dispatch_group_wait(grp, DISPATCH_TIME_FOREVER)
                dispatch_async(dispatch_get_main_queue()) {
                    self.syncRunning = false
                    self.log("Finished syncing in \(NSDate().timeIntervalSinceDate(startTime))")
                    completionHandler(failures > 0 ? .ReplicationError : nil)
                }
            }
        }
    }
    
    /// Sync an individual key. Normally this is only called internally and you should call syncAllKeys
    func syncKey(key: String, remoteVersion: UInt64? = nil, remoteTime: NSDate? = nil,
                 remoteErr: BRRemoteKVStoreError? = nil, completionHandler: (BRReplicatedKVStoreError?) -> ()) throws {
        if let remoteVersion = remoteVersion, remoteTime = remoteTime {
            try _syncKey(key, remoteVer: remoteVersion, remoteTime: remoteTime,
                         remoteErr: remoteErr, completionHandler: completionHandler)
        } else {
            remote.ver(key) { (remoteVer, remoteTime, err) in
                _ = try? self._syncKey(key, remoteVer: remoteVer, remoteTime: remoteTime,
                                       remoteErr: remoteErr, completionHandler: completionHandler)
            }
        }
    }
    
    // the syncKey kernel - this is provided so syncAllKeys can provide get a bunch of key versions at once
    // and fan out the _syncKey operations
    private func _syncKey(key: String, remoteVer: UInt64, remoteTime: NSDate, remoteErr: BRRemoteKVStoreError?,
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
            log("Remote version of key \(key) is the same as the one we have")
            completionHandler(nil) // this key is already up to date
        }
        var localVer: UInt64
        var localTime: NSDate
        var localDeleted: Bool
        var localValue: [UInt8]
        do {
            (localVer, localTime, localDeleted, localValue) = try get(key)
        } catch BRReplicatedKVStoreError.NotFound {
            // missing key locally
            (localVer, localTime, localDeleted, localValue) = (0, NSDate(timeIntervalSince1970: Double()), false, [])
        }
        switch remoteErr {
        case nil, .Some(.Tombstone):
            let (lt, rt) = (localTime.msTimestamp, remoteTime.msTimestamp)
            
            if localDeleted && remoteErr == .Some(.Tombstone) { // was removed on both server and locally
                log("Local key \(key) was deleted, and so was the remote key")
                do {
                    try self.setRemoteVersion(key, localVer: localVer, remoteVer: remoteVer)
                } catch let e where e is BRReplicatedKVStoreError {
                    return completionHandler((e as! BRReplicatedKVStoreError))
                } catch {
                    return completionHandler(.ReplicationError)
                }
                return completionHandler(nil)
            }
            
            if lt > rt || lt == rt { // local is newer (or a tiebreaker)
                if localDeleted {
                    log("Local key \(key) was deleted, removing remotely...")
                    self.remote.del(key, version: remoteVer, completionFunc: { (newRemoteVer, _, delErr) in
                        if delErr == .Some(.NotFound) {
                            self.log("Local key \(key) was already missing on the server. Ignoring")
                            return completionHandler(nil)
                        }
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
                    self.remote.put(key, value: localValue, version: remoteVer,
                                    completionFunc: { (newRemoteVer, _, putErr) in
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
                        let (newLocalVer, _) = try self._del(key, localVer: localVer)
                        try self.setRemoteVersion(key, localVer: newLocalVer, remoteVer: remoteVer)
                    } catch BRReplicatedKVStoreError.NotFound {
                        // well a deleted key isn't found, so why do we care
                    } catch let e where e is BRReplicatedKVStoreError {
                        return completionHandler((e as! BRReplicatedKVStoreError))
                    } catch {
                        return completionHandler(.ReplicationError)
                    }
                    log("Remote key \(key) was removed locally")
                    completionHandler(nil)
                } else {
                    log("Remote key \(key) is newer, fetching...")
                    // get the remote version
                    self.remote.get(key, version: remoteVer, completionFunc: { (newRemoteVer, _, remoteData, getErr) in
                        if let getErr = getErr {
                            self.log("Error fetching the remote value for key \(getErr), error: \(getErr)")
                            return completionHandler(.ReplicationError)
                        }
                        do {
                            let (newLocalVer, _) = try self._set(key, value: remoteData, localVer: localVer)
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
    
    // execute a function inside a transaction, if that function throws then rollback, otherwise commit
    // calling txn() from within a txn function will deadlock
    private func txn(fn: () throws -> ()) throws {
        try dispatch_sync_throws(dbQueue) {
            var beginStmt: COpaquePointer = nil
            var finishStmt: COpaquePointer = nil
            defer {
                sqlite3_finalize(beginStmt)
                sqlite3_finalize(finishStmt)
            }
            try self.checkErr(sqlite3_prepare_v2(self.db, "BEGIN", -1, &beginStmt, nil), s: "txn - prepare begin")
            try self.checkErr(sqlite3_step(beginStmt), s: "txn - exec begin begin")
            do {
                try fn()
            } catch let e {
                try self.checkErr(sqlite3_prepare_v2(
                    self.db, "ROLLBACK" , -1, &finishStmt, nil), s: "txn - prepare rollback")
                try self.checkErr(sqlite3_step(finishStmt), s: "txn - execute rollback")
                throw e
            }
            try self.checkErr(sqlite3_prepare_v2(self.db, "COMMIT", -1, &finishStmt, nil), s: "txn - prepare commit")
            try self.checkErr(sqlite3_step(finishStmt), s: "txn - execute commit")
        }
    }
    
    // ensure the sqlite3 error code is an acceptable one (or that its the one you provide as `r`
    // this MUST be called from within the dbQueue
    private func checkErr(e: Int32, s: String, r: Int32 = SQLITE_NULL) throws {
        if (r == SQLITE_NULL && (e != SQLITE_OK && e != SQLITE_DONE && e != SQLITE_ROW))
            && (e != SQLITE_NULL && e != r) {
            let es = NSString(CString: sqlite3_errstr(e), encoding: NSUTF8StringEncoding)
            let em = NSString(CString: sqlite3_errmsg(db), encoding: NSUTF8StringEncoding)
            log("\(s): errcode=\(e) errstr=\(es) errmsg=\(em)")
            throw BRReplicatedKVStoreError.SQLiteError
        }
    }
    
    // encrypt some data using self.key
    private func encrypt(data: [UInt8]) throws -> [UInt8] {
        let inData = UnsafePointer<UInt8>(data)
        let nonce = genNonce()
        let outSize = chacha20Poly1305AEADEncrypt(nil, 0, key.secretKey, nonce, inData, data.count, nil, 0)
        var outData = [UInt8](count: outSize, repeatedValue: 0)
        chacha20Poly1305AEADEncrypt(&outData, outSize, key.secretKey, nonce, inData, data.count, nil, 0)
        return nonce + outData
    }
    
    // decrypt some data using self.key
    private func decrypt(data: [UInt8]) throws -> [UInt8] {
        let nonce = Array(data[data.startIndex...data.startIndex.advancedBy(12)])
        let inData = Array(data[data.startIndex.advancedBy(12)...(data.endIndex-1)])
        let outSize = chacha20Poly1305AEADDecrypt(nil, 0, key.secretKey, nonce, inData, inData.count, nil, 0)
        var outData = [UInt8](count: outSize, repeatedValue: 0)
        chacha20Poly1305AEADDecrypt(&outData, outSize, key.secretKey, nonce, inData, inData.count, nil, 0)
        return outData
    }
    
    // generate a nonce using microseconds-since-epoch
    private func genNonce() -> [UInt8] {
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

extension NSDate {
    static func withMsTimestamp(ms: UInt64) -> NSDate {
        return NSDate(timeIntervalSince1970: Double(ms) / 1000.0)
    }
    
    var msTimestamp: UInt64 {
        get {
            return UInt64(timeIntervalSince1970 * 1000.0)
        }
    }
}
