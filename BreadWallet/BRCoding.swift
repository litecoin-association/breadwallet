//
//  BRCoding.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/14/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import Foundation

// BRCoder/BRCoding works a lot like NSCoder/NSCoding but simpler
// instead of using optionals everywhere we just use zero values, and take advantage
// of the swift type system somewhat to make the whole api a little cleaner
protocol BREncodable {
    // return anything that is JSON-able
    func encode() -> AnyObject
    // zeroValue is a zero-value initializer
    static func zeroValue() -> Self
    // decode can be passed any value which is json-able
    static func decode(value: AnyObject) -> Self
}


// An object which can encode and decode values
public class BRCoder {
    var data: [String: AnyObject]
    
    init(data: [String: AnyObject]) {
        self.data = data
    }
    
    func encode(obj: BREncodable, key: String) {
        self.data[key] = obj.encode()
    }
    
    func decode<T: BREncodable>(key: String) -> T {
        guard let d = self.data[key] else {
            return T.zeroValue()
        }
        return T.decode(d)
    }
}

// An object which may be encoded/decoded using the archiving/unarchiving classes below
protocol BRCoding {
    init?(coder decoder: BRCoder)
    func encode(coder: BRCoder)
}

// A basic analogue of NSKeyedArchiver, except it uses JSON and uses
public class BRKeyedArchiver {
    static func archivedDataWithRootObject(obj: BRCoding, compressed: Bool = true) -> NSData {
        let coder = BRCoder(data: [String : AnyObject]())
        obj.encode(coder)
        do {
            let j = try NSJSONSerialization.dataWithJSONObject(coder.data, options: [])
            guard let bz = (compressed ? j.bzCompressedData : j) else {
                print("compression error")
                return NSData()
            }
            return bz
        } catch let e {
            print("BRKeyedArchiver unable to archive object: \(e)")
            return "{}".dataUsingEncoding(NSUTF8StringEncoding)!
        }
    }
}

// A basic analogue of NSKeyedUnarchiver
public class BRKeyedUnarchiver {
    static func unarchiveObjectWithData<T: BRCoding>(data: NSData, compressed: Bool = true) -> T? {
        do {
            guard let bz = (compressed ? NSData(bzCompressedData: data) : data),
                j = try NSJSONSerialization.JSONObjectWithData(bz, options: []) as? [String: AnyObject] else {
                print("BRKeyedUnarchiver invalid json object, or invalid bz data")
                return nil
            }
            let coder = BRCoder(data: j)
            return T(coder: coder)
        } catch let e {
            print("BRKeyedUnarchiver unable to deserialize JSON: \(e)")
            return nil
        }
        
    }
}

// converters

extension NSDate: BREncodable {
    func encode() -> AnyObject {
        return self.timeIntervalSinceReferenceDate
    }
    
    public class func zeroValue() -> Self {
        return dateFromTimeIntervalSinceReferenceDate(0)
    }
    
    public class func decode(value: AnyObject) -> Self {
        let d = (value as? Double) ?? Double()
        return dateFromTimeIntervalSinceReferenceDate(d)
    }
    
    class func dateFromTimeIntervalSinceReferenceDate<T>(d: Double) -> T {
        return NSDate(timeIntervalSinceReferenceDate: d) as! T
    }
}

extension Int: BREncodable {
    func encode() -> AnyObject {
        return self
    }
    
    static func zeroValue() -> Int {
        return 0
    }
    
    static func decode(s: AnyObject) -> Int {
        return (s as? Int) ?? self.zeroValue()
    }
}

extension String: BREncodable {
    func encode() -> AnyObject {
        return self
    }
    
    static func zeroValue() -> String {
        return ""
    }
    
    static func decode(s: AnyObject) -> String {
        return (s as? String) ?? self.zeroValue()
    }
}