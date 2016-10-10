//
//  BRWebViewController.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 12/10/15.
//  Copyright (c) 2016 breadwallet LLC
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
import UIKit
import WebKit


@available(iOS 8.0, *)
@objc public class BRWebViewController : UIViewController, WKNavigationDelegate {
    var wkProcessPool: WKProcessPool
    var webView: WKWebView?
    var bundleName: String
    var server = BRHTTPServer()
    var debugEndpoint: String?
    var mountPoint: String
    
    init(bundleName name: String, mountPoint mp: String = "/") {
        wkProcessPool = WKProcessPool()
        bundleName = name
        mountPoint = mp
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopServer()
    }
    
    override public func loadView() {
        let config = WKWebViewConfiguration()
        config.processPool = wkProcessPool
        config.allowsInlineMediaPlayback = false
        if #available(iOS 9.0, *) {
            config.allowsAirPlayForMediaPlayback = false
            config.requiresUserActionForMediaPlayback = true
            config.allowsPictureInPictureMediaPlayback = false
        }

        let indexUrl = NSURL(string: "http://127.0.0.1:\(server.port)\(mountPoint)")!
        let request = NSURLRequest(URL: indexUrl)
        
        view = UIView(frame: CGRectZero)
        view.backgroundColor = UIColor(red:0.98, green:0.98, blue:0.98, alpha:1.0)
        
        webView = WKWebView(frame: CGRectZero, configuration: config)
        webView?.navigationDelegate = self
        webView?.backgroundColor = UIColor(red:0.98, green:0.98, blue:0.98, alpha:1.0)
        webView?.loadRequest(request)
        webView?.autoresizingMask = [UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleWidth]
        view.addSubview(webView!)
    }
    
    override public func viewWillAppear(animated: Bool) {
        edgesForExtendedLayout = .All
    }
    
    private func closeNow() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    public func startServer() {
        do {
            if !server.isStarted {
                try server.start()
                setupIntegrations()
            }
        } catch let e {
            print("\n\n\nSERVER ERROR! \(e)\n\n\n")
        }
    }
    
    public func stopServer() {
        if server.isStarted {
            server.stop()
            server.resetMiddleware()
        }
    }
    
    private func setupIntegrations() {
        // proxy api for signing and verification
        let apiProxy = BRAPIProxy(mountAt: "/_api", client: BRAPIClient.sharedClient)
        server.prependMiddleware(middleware: apiProxy)
        
        // http router for native functionality
        let router = BRHTTPRouter()
        server.prependMiddleware(middleware: router)
        
        // basic file server for static assets
        let fileMw = BRHTTPFileMiddleware(baseURL: BRAPIClient.bundleURL(bundleName))
        server.prependMiddleware(middleware: fileMw)
        
        // middleware to always return index.html for any unknown GET request (facilitates window.history style SPAs)
        let indexMw = BRHTTPIndexMiddleware(baseURL: fileMw.baseURL)
        server.prependMiddleware(middleware: indexMw)
        
        // geo plugin provides access to onboard geo location functionality
        router.plugin(BRGeoLocationPlugin())
        
        // camera plugin 
        router.plugin(BRCameraPlugin(fromViewController: self))
        
        // wallet plugin provides access to the wallet
        router.plugin(BRWalletPlugin())
        
        // link plugin which allows opening links to other apps
        router.plugin(BRLinkPlugin())
        
        // kvstore plugin provides access to the shared replicated kv store
        router.plugin(BRKVStorePlugin(client: BRAPIClient.sharedClient))
        
        // GET /_close closes the browser modal
        router.get("/_close") { (request, match) -> BRHTTPResponse in
            dispatch_async(dispatch_get_main_queue()) {
                self.closeNow()
            }
            return BRHTTPResponse(request: request, code: 204)
        }
        
        router.printDebug()
        
        // enable debug if it is turned on
        if let debugUrl = debugEndpoint {
            let url = NSURL(string: debugUrl)
            fileMw.debugURL = url
            indexMw.debugURL = url
        }
    }
    
    public func preload() {
        _ = self.view // force webview loading
    }
    
    public func refresh() {
        webView?.reload()
    }
    
    // MARK: - navigation delegate
    
    public func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction,
                        decisionHandler: (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.URL, host = url.host, port = url.port {
            if host == server.listenAddress || port.intValue == Int32(server.port) {
                return decisionHandler(.Allow)
            }
        }
        print("[BRWebViewController disallowing navigation: \(navigationAction)")
        decisionHandler(.Cancel)
    }
}
