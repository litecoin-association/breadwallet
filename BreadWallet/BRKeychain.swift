//
//  BRKeychain.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
//  Copyright (c) 2016 breadwallet LLC
//  Copyright © 2016 Litecoin Association <loshan1212@gmail.com>
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


let BreadDefaultService = "com.litecoin.loafwallet"

enum BRKeychainError: String, ErrorType {
    // this is borrowed from the "Locksmith" library: https://github.com/matthewpalmer/Locksmith
    case Allocate = "Failed to allocate memory."
    case AuthFailed = "Authorization/Authentication failed."
    case Decode = "Unable to decode the provided data."
    case Duplicate = "The item already exists."
    case InteractionNotAllowed = "Interaction with the Security Server is not allowed."
    case NoError = "No error."
    case NotAvailable = "No trust results are available."
    case NotFound = "The item cannot be found."
    case Param = "One or more parameters passed to the function were not valid."
    case RequestNotSet = "The request was not set"
    case TypeNotFound = "The type was not found"
    case UnableToClear = "Unable to clear the keychain"
    case Undefined = "An undefined error occurred"
    case Unimplemented = "Function or operation not implemented."
    
    init?(fromStatusCode code: Int) {
        switch code {
        case Int(errSecAllocate):
            self = Allocate
        case Int(errSecAuthFailed):
            self = AuthFailed
        case Int(errSecDecode):
            self = Decode
        case Int(errSecDuplicateItem):
            self = Duplicate
        case Int(errSecInteractionNotAllowed):
            self = InteractionNotAllowed
        case Int(errSecItemNotFound):
            self = NotFound
        case Int(errSecNotAvailable):
            self = NotAvailable
        case Int(errSecParam):
            self = Param
        case Int(errSecUnimplemented):
            self = Unimplemented
        default:
            return nil
        }
    }
}

class BRKeychain {
    // this API is inspired by the aforementioned Locksmith library
    static func loadDataForUserAccount(account: String,
        inService service: String = BreadDefaultService) throws -> [String: AnyObject]? {
            var q = getBaseQuery(account, service: service)
            q[String(kSecReturnData)] = kCFBooleanTrue
            q[String(kSecMatchLimit)] = kSecMatchLimitOne
            var res: AnyObject?
            let status: OSStatus = withUnsafeMutablePointer(&res) {
                SecItemCopyMatching(q, UnsafeMutablePointer($0))
            }
            if let err = BRKeychainError(fromStatusCode: Int(status)) {
                switch err {
                case .NotFound, .NotAvailable:
                    return nil
                default:
                    throw err
                }
            }
            if let res = res as? NSData {
                return NSKeyedUnarchiver.unarchiveObjectWithData(res) as? [String: AnyObject]
            }
            print("Unable to unarchive keychain data... deleting data")
            do {
                try deleteDataForUserAccount(account, inService: service)
            } catch let e as BRKeychainError {
                print("Unable to delete from keychain: \(e)")
            }
            return nil
    }
    
    static func saveData(data: [String: AnyObject], forUserAccount account: String,
        inService service: String = BreadDefaultService) throws {
            do {
                try deleteDataForUserAccount(account, inService: service)
            } catch let e as BRKeychainError {
                print("Unable to delete from keychain: \(e)")
            }
            var q = getBaseQuery(account, service: service)
            q[String(kSecValueData)] = NSKeyedArchiver.archivedDataWithRootObject(data)
            let status: OSStatus = SecItemAdd(q, nil)
            if let err = BRKeychainError(fromStatusCode: Int(status)) {
                throw err
            }
    }
    
    static func deleteDataForUserAccount(account: String, inService service: String = BreadDefaultService) throws {
        let q = getBaseQuery(account, service: service)
        let status: OSStatus = SecItemDelete(q)
        if let err = BRKeychainError(fromStatusCode: Int(status)) {
            throw err
        }
    }
    
    private static func getBaseQuery(account: String, service: String) -> [String: AnyObject] {
        let query = [
            String(kSecClass): String(kSecClassGenericPassword),
            String(kSecAttrAccount): account,
            String(kSecAttrService): service,
            String(kSecAttrAccessible): String(kSecAttrAccessibleAlwaysThisDeviceOnly)
        ]
        return query
    }
}
