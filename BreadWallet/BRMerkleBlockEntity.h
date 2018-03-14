//
//  BRMerkleBlockEntity.h
//  BreadWallet
//
//  Created by Aaron Voisine on 10/19/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BRMerkleBlock;

@interface BRMerkleBlockEntity : NSManagedObject

@property (nonatomic, retain) NSData *blockHash;
@property (nonatomic) int32_t height;
@property (nonatomic) int32_t version;
@property (nonatomic, retain) NSData *prevBlock;
@property (nonatomic, retain) NSData *merkleRoot;
@property (nonatomic) NSTimeInterval timestamp;
@property (nonatomic) int32_t target;
@property (nonatomic) int32_t nonce;
@property (nonatomic) int32_t totalTransactions;
@property (nonatomic, retain) NSData *hashes;
@property (nonatomic, retain) NSData *flags;

- (instancetype)setAttributesFromBlock:(BRMerkleBlock *)block;
- (BRMerkleBlock *)merkleBlock;

@end
