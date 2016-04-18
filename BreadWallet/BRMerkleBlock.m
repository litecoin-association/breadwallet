//
//  BRMerkleBlock.m
//  BreadWallet
//
//  Created by Aaron Voisine on 10/22/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
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

#import "BRMerkleBlock.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Bitcoin.h"

#define MAX_TIME_DRIFT    (150*60)     // the furthest in the future a block is allowed to be timestamped
#define MAX_PROOF_OF_WORK 0x1e0ffff0u   // highest value for difficulty target (higher values are less difficult)
#define TARGET_TIMESPAN   (84*60*60) // the targeted timespan between difficulty target adjustments

// from https://en.bitcoin.it/wiki/Protocol_specification#Merkle_Trees
// Merkle trees are binary trees of hashes. Merkle trees in bitcoin use a double SHA-256, the SHA-256 hash of the
// SHA-256 hash of something. If, when forming a row in the tree (other than the root of the tree), it would have an odd
// number of elements, the final double-hash is duplicated to ensure that the row has an even number of hashes. First
// form the bottom row of the tree with the ordered double-SHA-256 hashes of the byte streams of the transactions in the
// block. Then the row above it consists of half that number of hashes. Each entry is the double-SHA-256 of the 64-byte
// concatenation of the corresponding two hashes below it in the tree. This procedure repeats recursively until we reach
// a row consisting of just a single double-hash. This is the merkle root of the tree.
//
// from https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki#Partial_Merkle_branch_format
// The encoding works as follows: we traverse the tree in depth-first order, storing a bit for each traversed node,
// signifying whether the node is the parent of at least one matched leaf txid (or a matched txid itself). In case we
// are at the leaf level, or this bit is 0, its merkle node hash is stored, and its children are not explored further.
// Otherwise, no hash is stored, but we recurse into both (or the only) child branch. During decoding, the same
// depth-first traversal is performed, consuming bits and hashes as they written during encoding.
//
// example tree with three transactions, where only tx2 is matched by the bloom filter:
//
//     merkleRoot
//      /     \
//    m1       m2
//   /  \     /  \
// tx1  tx2 tx3  tx3
//
// flag bits (little endian): 00001011 [merkleRoot = 1, m1 = 1, tx1 = 0, tx2 = 1, m2 = 0, byte padding = 000]
// hashes: [tx1, tx2, m2]

@interface BRMerkleBlock ()

@property (nonatomic, assign) UInt256 blockHash;
    
@end

@implementation BRMerkleBlock

// message can be either a merkleblock or header message
+ (instancetype)blockWithMessage:(NSData *)message
{
    return [[self alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(NSData *)message
{
    if (! (self = [self init])) return nil;
    
    if (message.length < 80) return nil;

    NSUInteger off = 0, l = 0, len = 0;
    NSMutableData *d = [NSMutableData data];

    _version = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _prevBlock = [message hashAtOffset:off];
    off += sizeof(UInt256);
    _merkleRoot = [message hashAtOffset:off];
    off += sizeof(UInt256);
    _timestamp = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _target = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _nonce = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _totalTransactions = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    len = (NSUInteger)[message varIntAtOffset:off length:&l]*sizeof(UInt256);
    off += l;
    _hashes = (off + len > message.length) ? nil : [message subdataWithRange:NSMakeRange(off, len)];
    off += len;
    _flags = [message dataAtOffset:off length:&l];
    _height = BLOCK_UNKNOWN_HEIGHT;
    
    [d appendUInt32:_version];
    [d appendBytes:&_prevBlock length:sizeof(_prevBlock)];
    [d appendBytes:&_merkleRoot length:sizeof(_merkleRoot)];
    [d appendUInt32:_timestamp];
    [d appendUInt32:_target];
    [d appendUInt32:_nonce];
    _blockHash = d.SHA256_2;
    _powHash = d.SCRYPT;

    return self;
}

- (instancetype)initWithBlockHash:(UInt256)blockHash version:(uint32_t)version prevBlock:(UInt256)prevBlock
merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target nonce:(uint32_t)nonce
totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height
{
    if (! (self = [self init])) return nil;
    
    _blockHash = blockHash;
    _version = version;
    _prevBlock = prevBlock;
    _merkleRoot = merkleRoot;
    _timestamp = timestamp;
    _target = target;
    _nonce = nonce;
    _totalTransactions = totalTransactions;
    _hashes = hashes;
    _flags = flags;
    _height = height;
    
    return self;
}

// true if merkle tree and timestamp are valid, and proof-of-work matches the stated difficulty target
// NOTE: This only checks if the block difficulty matches the difficulty target in the header. It does not check if the
// target is correct for the block's height in the chain. Use verifyDifficultyFromPreviousBlock: for that.
- (BOOL)isValid
{
    // target is in "compact" format, where the most significant byte is the size of resulting value in bytes, the next
    // bit is the sign, and the remaining 23bits is the value after having been right shifted by (size - 3)*8 bits
    static const uint32_t maxsize = MAX_PROOF_OF_WORK >> 20, maxtarget = MAX_PROOF_OF_WORK & 0x00ffffffu;
    uint32_t size = _target >> 20, target = _target & 0x00ffffffu;
    NSMutableData *d = [NSMutableData data];
    UInt256 merkleRoot, t = UINT256_ZERO;
    int hashIdx = 0, flagIdx = 0;
    NSValue *root =
        [self _walk:&hashIdx :&flagIdx :0 :^id (id hash, BOOL flag) {
            return hash;
        } :^id (id left, id right) {
            UInt256 l, r;

            if (! right) right = left; // if right branch is missing, duplicate left branch
            [left getValue:&l];
            [right getValue:&r];
            d.length = 0;
            [d appendBytes:&l length:sizeof(l)];
            [d appendBytes:&r length:sizeof(r)];
            return uint256_obj(d.SHA256_2);
        }];
    
    [root getValue:&merkleRoot];
    if (_totalTransactions > 0 && ! uint256_eq(merkleRoot, _merkleRoot)) return NO; // merkle root check failed
    
    // check if timestamp is too far in future
    //TODO: use estimated network time instead of system time (avoids timejacking attacks and misconfigured time)
    if (_timestamp > [NSDate timeIntervalSinceReferenceDate] + NSTimeIntervalSince1970 + MAX_TIME_DRIFT) return NO;

    // limit to MAX_PROOF_OF_WORK
    if (size > maxsize || (size == maxsize && target > maxtarget)) target = maxtarget, size = maxsize;
    
    // check if proof-of-work target is out of range
    if (target == 0 || target & 0x00800000u || size > maxsize || (size == maxsize && target > maxtarget)) return NO;

    if (size > 3) *(uint32_t *)&t.u8[size - 3] = CFSwapInt32HostToLittle(target);
    else t.u32[0] = CFSwapInt32HostToLittle(target >> (3 - size)*8);
    
    for (int i = sizeof(t)/sizeof(uint32_t) - 1; i >= 0; i--) { // check proof-of-work
        if (CFSwapInt32LittleToHost(_powHash.u32[i]) < CFSwapInt32LittleToHost(t.u32[i])) break;
        if (CFSwapInt32LittleToHost(_powHash.u32[i]) > CFSwapInt32LittleToHost(t.u32[i])) return NO;
    }
    
    return YES;
}

- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUInt32:_version];
    [d appendBytes:&_prevBlock length:sizeof(_prevBlock)];
    [d appendBytes:&_merkleRoot length:sizeof(_merkleRoot)];
    [d appendUInt32:_timestamp];
    [d appendUInt32:_target];
    [d appendUInt32:_nonce];
    
    if (_totalTransactions > 0) {
        [d appendUInt32:_totalTransactions];
        [d appendVarInt:_hashes.length/sizeof(UInt256)];
        [d appendData:_hashes];
        [d appendVarInt:_flags.length];
        [d appendData:_flags];
    }
    
    return d;
}

// true if the given tx hash is included in the block
- (BOOL)containsTxHash:(UInt256)txHash
{
    for (NSUInteger i = 0; i < _hashes.length/sizeof(UInt256); i += sizeof(UInt256)) {
        if (uint256_eq(txHash, [_hashes hashAtOffset:i])) return YES;
    }
    
    return NO;
}

// returns an array of the matched tx hashes
- (NSArray *)txHashes
{
    int hashIdx = 0, flagIdx = 0;
    NSArray *txHashes =
        [self _walk:&hashIdx :&flagIdx :0 :^id (id hash, BOOL flag) {
            return (flag && hash) ? @[hash] : @[];
        } :^id (id left, id right) {
            return [left arrayByAddingObjectsFromArray:right];
        }];
    
    return txHashes;
}

// Verifies the block difficulty target is correct for the block's position in the chain. Transition time may be 0 if
// height is not a multiple of BLOCK_DIFFICULTY_INTERVAL.
//
// The difficulty target algorithm works as follows:
// The target must be the same as in the previous block unless the block's height is a multiple of 2016. Every 2016
// blocks there is a difficulty transition where a new difficulty is calculated. The new target is the previous target
// multiplied by the time between the last transition block's timestamp and this one (in seconds), divided by the
// targeted time between transitions (14*24*60*60 seconds). If the new difficulty is more than 4x or less than 1/4 of
// the previous difficulty, the change is limited to either 4x or 1/4. There is also a minimum difficulty value
// intuitively named MAX_PROOF_OF_WORK... since larger values are less difficult.
- (BOOL)verifyDifficultyFromPreviousBlock:(BRMerkleBlock *)previous andTransitionTime:(uint32_t)time
{
    if (! uint256_eq(_prevBlock, previous.blockHash) || _height != previous.height + 1) return NO;
    if ((_height % BLOCK_DIFFICULTY_INTERVAL) == 0 && time == 0) return NO;

#if BITCOIN_TESTNET
    //TODO: implement testnet difficulty rule check
    return YES; // don't worry about difficulty on testnet for now
#endif

    if ((_height % BLOCK_DIFFICULTY_INTERVAL) != 0) return (_target == previous.target) ? YES : NO;

    // target is in "compact" format, where the most significant byte is the size of resulting value in bytes, the next
    // bit is the sign, and the remaining 23bits is the value after having been right shifted by (size - 3)*8 bits
    static const uint32_t maxsize = MAX_PROOF_OF_WORK >> 20, maxtarget = MAX_PROOF_OF_WORK & 0x00ffffffu;
    int32_t timespan = (int32_t)((int64_t)previous.timestamp - (int64_t)time), size = previous.target >> 20;
    uint64_t target = previous.target & 0x00ffffffu;

    // limit difficulty transition to -75% or +400%
    if (timespan < TARGET_TIMESPAN/4) timespan = TARGET_TIMESPAN/4;
    if (timespan > TARGET_TIMESPAN*4) timespan = TARGET_TIMESPAN*4;

    // TARGET_TIMESPAN happens to be a multiple of 256, and since timespan is at least TARGET_TIMESPAN/4, we don't lose
    // precision when target is multiplied by timespan and then divided by TARGET_TIMESPAN/256
    target *= timespan;
    target /= TARGET_TIMESPAN >> 8;
    size--; // decrement size since we only divided by TARGET_TIMESPAN/256
    
    while (size < 1 || target > 0x007fffffULL) target >>= 8, size++; // normalize target for "compact" format

    // limit to MAX_PROOF_OF_WORK
    if (size > maxsize || (size == maxsize && target > maxtarget)) target = maxtarget, size = maxsize;

    return (_target == ((uint32_t)target | size << 20)) ? YES : NO;
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(id, BOOL))leaf :(id (^)(id, id))branch
{
    if ((*flagIdx)/8 >= _flags.length || (*hashIdx + 1)*sizeof(UInt256) > _hashes.length) return leaf(nil, NO);
    
    BOOL flag = (((const uint8_t *)_flags.bytes)[*flagIdx/8] & (1 << (*flagIdx % 8)));
    
    (*flagIdx)++;
    
    if (! flag || depth == (int)(ceil(log2(_totalTransactions)))) {
        UInt256 hash = [_hashes hashAtOffset:(*hashIdx)*sizeof(UInt256)];
        
        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }
    
    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    
    return branch(left, right);
}

- (NSUInteger)hash
{
    if (uint256_is_zero(_blockHash)) return super.hash;
    return *(const NSUInteger *)&_blockHash;
}

- (BOOL)isEqual:(id)obj
{
    return self == obj || ([obj isKindOfClass:[BRMerkleBlock class]] && uint256_eq([obj blockHash], _blockHash));
}

@end
