//
//  BRBloomFilter.h
//  BreadWallet
//
//  Created by Aaron Voisine on 10/15/13.
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

#define BLOOM_DEFAULT_FALSEPOSITIVE_RATE 0.0005 // same as bitcoinj, use 0.00005 for less data, 0.001 for good anonymity
#define BLOOM_REDUCED_FALSEPOSITIVE_RATE 0.00005
#define BLOOM_UPDATE_NONE                0
#define BLOOM_UPDATE_ALL                 1
#define BLOOM_UPDATE_P2PUBKEY_ONLY       2
#define BLOOM_MAX_FILTER_LENGTH          36000 // this allows for 10,000 elements with a <0.0001% false positive rate

@class BRTransaction;

@interface BRBloomFilter : NSObject

@property (nonatomic, readonly) uint32_t tweak;
@property (nonatomic, readonly) uint8_t flags;
@property (nonatomic, readonly, getter = toData) NSData *data;
@property (nonatomic, readonly) NSUInteger elementCount;
@property (nonatomic, readonly) double falsePositiveRate;
@property (nonatomic, readonly) NSUInteger length;

+ (instancetype)filterWithMessage:(NSData *)message;
+ (instancetype)filterWithFullMatch;

- (instancetype)initWithMessage:(NSData *)message;
- (instancetype)initWithFullMatch;
- (instancetype)initWithFalsePositiveRate:(double)fpRate forElementCount:(NSUInteger)count tweak:(uint32_t)tweak
flags:(uint8_t)flags;
- (BOOL)containsData:(NSData *)data;
- (void)insertData:(NSData *)data;
- (void)updateWithTransaction:(BRTransaction *)tx;

@end
