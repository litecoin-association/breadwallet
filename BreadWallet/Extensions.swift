//
//  Extensions.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 1/30/16.
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


public extension String {
    func md5() -> String {
        let data = (self as NSString).dataUsingEncoding(NSUTF8StringEncoding)!
        let result = NSMutableData(length: Int(128/8))!
        let resultBytes = UnsafeMutablePointer<CUnsignedChar>(result.mutableBytes)
        MD5(resultBytes, data.bytes, data.length)
        
        let a = UnsafeBufferPointer<CUnsignedChar>(start: resultBytes, count: result.length)
        let hash = NSMutableString()
        
        for i in a {
            hash.appendFormat("%02x", i)
        }
        
        return hash as String
    }
    
    func parseQueryString() -> [String: [String]] {
        var ret = [String: [String]]()
        var strippedString = self
        if self.substringToIndex(self.startIndex.advancedBy(1)) == "?" {
            strippedString = self.substringFromIndex(self.startIndex.advancedBy(1))
        }
        strippedString = strippedString.stringByReplacingOccurrencesOfString("+", withString: " ")
        strippedString = strippedString.stringByRemovingPercentEncoding!
        for s in strippedString.componentsSeparatedByString("&") {
            let kp = s.componentsSeparatedByString("=")
            if kp.count == 2 {
                if var k = ret[kp[0]] {
                    k.append(kp[1])
                } else {
                    ret[kp[0]] = [kp[1]]
                }
            }
        }
        return ret
    }
    
    static func buildQueryString(options: [String: [String]]?, includeQ: Bool = false) -> String {
        var s = ""
        if let options = options where options.count > 0 {
            s = includeQ ? "?" : ""
            var i = 0
            for (k, vals) in options {
                for v in vals {
                    if i != 0 {
                        s += "&"
                    }
                    i += 1
                    s += "\(k.urlEscapedString)=\(v.urlEscapedString)"
                }
            }
        }
        return s
    }
}

var BZCompressionBufferSize: UInt32 = 1024
var BZDefaultBlockSize: Int32 = 7
var BZDefaultWorkFactor: Int32 = 100

public extension NSData {
    var hexString : String {
        let buf = UnsafePointer<UInt8>(bytes)
        let charA = UInt8(UnicodeScalar("a").value)
        let char0 = UInt8(UnicodeScalar("0").value)
        
        func itoh(i: UInt8) -> UInt8 {
            return (i > 9) ? (charA + i - 10) : (char0 + i)
        }
        
        let p = UnsafeMutablePointer<UInt8>.alloc(length * 2)
        
        for i in 0..<length {
            p[i*2] = itoh((buf[i] >> 4) & 0xF)
            p[i*2+1] = itoh(buf[i] & 0xF)
        }
        
        return NSString(bytesNoCopy: p, length: length*2, encoding: NSUTF8StringEncoding, freeWhenDone: true) as! String
    }
    
    var bzCompressedData: NSData? {
        get {
            if self.length == 0 {
                return self
            }
            var stream = bz_stream()
            stream.next_in = UnsafeMutablePointer<Int8>(self.bytes)
            stream.avail_in = UInt32(self.length)
            let buffer = NSMutableData(length: Int(BZCompressionBufferSize))!
            stream.next_out = UnsafeMutablePointer<Int8>(buffer.bytes)
            stream.avail_out = BZCompressionBufferSize
            var bzret = BZ2_bzCompressInit(&stream, BZDefaultBlockSize, 0, BZDefaultWorkFactor)
            if bzret != BZ_OK {
                print("failed compression init")
                return nil
            }
            let compressed = NSMutableData()
            repeat {
                bzret = BZ2_bzCompress(&stream, stream.avail_in > 0 ? BZ_RUN : BZ_FINISH)
                if bzret < BZ_OK {
                    print("failed compress")
                    return nil
                }
                compressed.appendBytes(buffer.bytes, length: (Int(BZCompressionBufferSize) - Int(stream.avail_out)))
                stream.next_out = UnsafeMutablePointer<Int8>(buffer.bytes)
                stream.avail_out = BZCompressionBufferSize
            } while bzret != BZ_STREAM_END
            BZ2_bzCompressEnd(&stream)
            return compressed
        }
    }
    
    convenience init?(bzCompressedData data: NSData) {
        if data.length == 0 {
            self.init()
            return
        }
        var stream = bz_stream()
        stream.next_in = UnsafeMutablePointer<CChar>(data.bytes)
        stream.avail_in = UInt32(data.length)
        let buffer = [UInt8](count: Int(BZCompressionBufferSize), repeatedValue: 0)
        stream.next_out = UnsafeMutablePointer<CChar>(buffer)
        stream.avail_out = BZCompressionBufferSize
        var bzret = BZ2_bzDecompressInit(&stream, 0, 0)
        if bzret != BZ_OK {
            print("failed decompress init")
            self.init()
            return
        }
        let decompressed = NSMutableData()
        repeat {
            bzret = BZ2_bzDecompress(&stream)
            if bzret < BZ_OK {
                print("failed decompress")
                self.init()
                return
            }
            decompressed.appendBytes(buffer, length: (Int(BZCompressionBufferSize) - Int(stream.avail_out)))
            stream.next_out = UnsafeMutablePointer<CChar>(buffer)
            stream.avail_out = BZCompressionBufferSize
        } while bzret != BZ_STREAM_END
        BZ2_bzDecompressEnd(&stream)
        self.init(data: decompressed)
    }
}

public extension NSDate {
    static func withMsTimestamp(ms: UInt64) -> NSDate {
        return NSDate(timeIntervalSince1970: Double(ms) / 1000.0)
    }
    
    func msTimestamp() -> UInt64 {
        return UInt64((self.timeIntervalSince1970 < 0 ? 0 : self.timeIntervalSince1970) * 1000.0)
    }

    // this is lifted from: https://github.com/Fykec/NSDate-RFC1123/blob/master/NSDate%2BRFC1123.swift
    // Copyright © 2015 Foster Yin. All rights reserved.
    private static func cachedThreadLocalObjectWithKey<T: AnyObject>(key: String, create: () -> T) -> T {
        let threadDictionary = NSThread.currentThread().threadDictionary
        if let cachedObject = threadDictionary[key] as! T? {
            return cachedObject
        }
        else {
            let newObject = create()
            threadDictionary[key] = newObject
            return newObject
        }
    }
    
    private static func RFC1123DateFormatter() -> NSDateFormatter {
        return cachedThreadLocalObjectWithKey("RFC1123DateFormatter") {
            let locale = NSLocale(localeIdentifier: "en_US")
            let timeZone = NSTimeZone(name: "GMT")
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = locale //need locale for some iOS 9 verision, will not select correct default locale
            dateFormatter.timeZone = timeZone
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            return dateFormatter
        }
    }
    
    private static func RFC850DateFormatter() -> NSDateFormatter {
        return cachedThreadLocalObjectWithKey("RFC850DateFormatter") {
            let locale = NSLocale(localeIdentifier: "en_US")
            let timeZone = NSTimeZone(name: "GMT")
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = locale //need locale for some iOS 9 verision, will not select correct default locale
            dateFormatter.timeZone = timeZone
            dateFormatter.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss z"
            return dateFormatter
        }
    }
    
    private static func asctimeDateFormatter() -> NSDateFormatter {
        return cachedThreadLocalObjectWithKey("asctimeDateFormatter") {
            let locale = NSLocale(localeIdentifier: "en_US")
            let timeZone = NSTimeZone(name: "GMT")
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = locale //need locale for some iOS 9 verision, will not select correct default locale
            dateFormatter.timeZone = timeZone
            dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
            return dateFormatter
        }
    }
    
    static func fromRFC1123(dateString: String) -> NSDate? {
        
        var date: NSDate?
        // RFC1123
        date = NSDate.RFC1123DateFormatter().dateFromString(dateString)
        if date != nil {
            return date
        }
        
        // RFC850
        date = NSDate.RFC850DateFormatter().dateFromString(dateString)
        if date != nil {
            return date
        }
        
        // asctime-date
        date = NSDate.asctimeDateFormatter().dateFromString(dateString)
        if date != nil {
            return date
        }
        return nil
    }
    
    func RFC1123String() -> String? {
        return NSDate.RFC1123DateFormatter().stringFromDate(self)
    }
}
