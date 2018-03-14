//
//  BRMerkleBlock.h
//  BreadWallet
//
//  Created by Aaron Voisine on 10/22/13.
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

#define BLOCK_DIFFICULTY_INTERVAL 2016      // number of blocks between difficulty target adjustments
#define BLOCK_UNKNOWN_HEIGHT      INT32_MAX

typedef union _UInt256 UInt256;

@interface BRMerkleBlock : NSObject

@property (nonatomic, readonly) UInt256 blockHash;
@property (nonatomic, readonly) UInt256 powHash;
@property (nonatomic, readonly) uint32_t version;
@property (nonatomic, readonly) UInt256 prevBlock;
@property (nonatomic, readonly) UInt256 merkleRoot;
@property (nonatomic, readonly) uint32_t timestamp; // time interval since unix epoch
@property (nonatomic, readonly) uint32_t target;
@property (nonatomic, readonly) uint32_t nonce;
@property (nonatomic, readonly) uint32_t totalTransactions;
@property (nonatomic, readonly) NSData *hashes;
@property (nonatomic, readonly) NSData *flags;
@property (nonatomic, assign) uint32_t height;

@property (nonatomic, readonly) NSArray *txHashes; // the matched tx hashes in the block

// true if merkle tree and timestamp are valid, and proof-of-work matches the stated difficulty target
// NOTE: This only checks if the block difficulty matches the difficulty target in the header. It does not check if the
// target is correct for the block's height in the chain. Use verifyDifficultyFromPreviousBlock: for that.
@property (nonatomic, readonly, getter = isValid) BOOL valid;

@property (nonatomic, readonly, getter = toData) NSData *data;

// message can be either a merkleblock or header message
+ (instancetype)blockWithMessage:(NSData *)message;

- (instancetype)initWithMessage:(NSData *)message;
- (instancetype)initWithBlockHash:(UInt256)blockHash version:(uint32_t)version prevBlock:(UInt256)prevBlock
merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target nonce:(uint32_t)nonce
totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height;

// true if the given tx hash is known to be included in the block
- (BOOL)containsTxHash:(UInt256)txHash;

// Verifies the block difficulty target is correct for the block's position in the chain. Transition time may be 0 if
// height is not a multiple of BLOCK_DIFFICULTY_INTERVAL.
- (BOOL)verifyDifficultyFromPreviousBlock:(BRMerkleBlock*)previous andTransitionTime:(uint32_t)time;

@end
