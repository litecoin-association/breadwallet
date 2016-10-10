//
//  BRHTTPRouter.swift
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


public typealias BRHTTPRouteMatch = [String: [String]]

public typealias BRHTTPRoute = (request: BRHTTPRequest, match: BRHTTPRouteMatch) throws -> BRHTTPResponse

@objc public protocol BRHTTPRouterPlugin {
    func hook(router: BRHTTPRouter)
}

@objc public class BRHTTPRoutePair: NSObject {
    public var method: String = "GET"
    public var path: String = "/"
    public var regex: NSRegularExpression!
    var captureGroups: [Int: String]!
    
    override public var hashValue: Int {
        return method.hashValue ^ path.hashValue
    }
    
    init(method m: String, path p: String) {
        method = m.uppercaseString
        path = p
        super.init()
        parse()
    }
    
    private func parse() {
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        if path.hasSuffix("/") {
            path = path.substringToIndex(path.endIndex.advancedBy(-1))
        }
        let parts = path.componentsSeparatedByString("/")
        captureGroups = [Int: String]()
        var reParts = [String]()
        var i = 0
        for part in parts {
            if part.hasPrefix("(") && part.hasSuffix(")") {
                let wcRange = part.endIndex.advancedBy(-2)..<part.endIndex.advancedBy(-1)
                if part.substringWithRange(wcRange) == "*" { // a wild card capture (part*)
                    captureGroups[i] = part.substringWithRange(part.startIndex.advancedBy(1)..<part.endIndex.advancedBy(-2))
                    reParts.append("(.*)")
                } else {
                    captureGroups[i] = part.substringWithRange(part.startIndex.advancedBy(1)..<part.endIndex.advancedBy(-1))
                    reParts.append("([^/]+)") // a capture (part)
                }
                i += 1
            } else {
                reParts.append(part) // a non-captured component
            }
        }
        
        let re = "^" + reParts.joinWithSeparator("/") + "$"
        //print("\n\nroute: \n\n method: \(method)\n path: \(path)\n regex: \(re)\n captures: \(captureGroups)\n\n")
        regex = try! NSRegularExpression(pattern: re, options: [])
    }
    
    public func match(request: BRHTTPRequest) -> BRHTTPRouteMatch? {
        if request.method.uppercaseString != method {
            return nil
        }
        var p = request.path as NSString // strip trailing slash
        if p.hasSuffix("/") { p = request.path.substringToIndex(request.path.endIndex.advancedBy(-1)) }
        if let m = regex.firstMatchInString(request.path, options: [], range: NSMakeRange(0, p.length))
            where m.numberOfRanges - 1 == captureGroups.count {
                var match = BRHTTPRouteMatch()
                for i in 1..<m.numberOfRanges {
                    let key = captureGroups[i-1]!
                    let captured = p.substringWithRange(m.rangeAtIndex(i))
                    if match[key] == nil {
                        match[key] = [captured]
                    } else {
                        match[key]?.append(captured)
                    }
                    //print("capture range: '\(key)' = '\(captured)'\n\n")
                }
                return match
        }
        return nil
    }
}

@objc public class BRHTTPRouter: NSObject, BRHTTPMiddleware {
    var routes = [(BRHTTPRoutePair, BRHTTPRoute)]()
    var plugins = [BRHTTPRouterPlugin]()
    private var wsServer = BRWebSocketServer()
    
    public func handle(request: BRHTTPRequest, next: (BRHTTPMiddlewareResponse) -> Void) {
        var response: BRHTTPResponse? = nil
        
        for (routePair, route) in routes {
            if let match = routePair.match(request) {
                do {
                    response = try route(request: request, match: match)
                } catch let e {
                    print("[BRHTTPRouter] route \(routePair.method) \(routePair.path) threw an exception \(e)")
                    response = BRHTTPResponse(request: request, code: 500)
                }
                break
            }
        }
        
        return next(BRHTTPMiddlewareResponse(request: request, response: response))
    }
    
    public func get(pattern: String, route: BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "GET", path: pattern), route))
    }
    
    public func post(pattern: String, route: BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "POST", path: pattern), route))
    }
    
    public func put(pattern: String, route: BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "PUT", path: pattern), route))
    }
    
    public func patch(pattern: String, route: BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "PATCH", path: pattern), route))
    }
    
    public func delete(pattern: String, route: BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "DELETE", path: pattern), route))
    }
    
    public func any(pattern: String, route: BRHTTPRoute) {
        for m in ["GET", "POST", "PUT", "PATCH", "DELETE"] {
            routes.append((BRHTTPRoutePair(method: m, path: pattern), route))
        }
    }
    
    public func websocket(pattern: String, client: BRWebSocketClient) {
        self.get(pattern) { (request, match) -> BRHTTPResponse in
            self.wsServer.serveForever()
            let resp = BRHTTPResponse(async: request)
            let ws = BRWebSocketImpl(request: request, response: resp, match: match, client: client)
            if !ws.handshake() {
                print("[BRHTTPRouter] websocket - invalid handshake")
                resp.provide(400, json: ["error": "invalid handshake"])
            } else {
                self.wsServer.add(ws)
            }
            return resp
        }
    }
    
    public func plugin(plugin: BRHTTPRouterPlugin) {
        plugin.hook(self)
        plugins.append(plugin)
    }
    
    public func printDebug() {
        for (r, _) in routes {
            print("[BRHTTPRouter] \(r.method) \(r.path)")
        }
    }
}
