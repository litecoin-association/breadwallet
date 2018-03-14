//
//  BRTarTests.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 12/1/15.
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

import XCTest
@testable import breadwallet

class BRTarTests: XCTestCase {
    var fileUrl: URL?
    
    override func setUp() {
        // download a test tar file
        let fm = FileManager.default
        let url = URL(string: "https://s3.amazonaws.com/breadwallet-assets/bread-buy/7f5bc5c6cc005df224a6ea4567e508491acaffdc2e4769e5262a52f5b785e261.tar")!
        let documentsUrl =  fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: destinationUrl.path) {
            print("file already exists [\(destinationUrl.path)]")
            fileUrl = destinationUrl
        } else if let dataFromURL = try? Data(contentsOf: url){
            if (try? dataFromURL.write(to: destinationUrl, options: [.atomic])) != nil {
                print("file saved [\(destinationUrl.path)]")
                fileUrl = destinationUrl
            } else {
                XCTFail("error saving file")
            }
        } else {
            XCTFail("error downloading file")
        }
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExtractTar() {
        guard let fileUrl = fileUrl else { XCTFail("file url not defined"); return }
        let fm = FileManager.default
        let docsPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destPath = docsPath.appendingPathComponent("extracted_files")
        do {
            try BRTar.createFilesAndDirectoriesAtPath(destPath.path, withTarPath: fileUrl.path)
        } catch let e {
            XCTFail("failed to extract tar file with \(e)")
        }
    }
    
//    func testPerformanceExample() {
//        self.measureBlock {
//        }
//    }
    
}
