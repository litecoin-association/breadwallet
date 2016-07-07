//
//  BRKey.h
//  BreadWallet
//
//  Created by Aaron Voisine on 5/22/13.
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

typedef union _UInt256 UInt256;
typedef union _UInt160 UInt160;

typedef struct {
    uint8_t p[33];
} BRECPoint;

// adds 256bit big endian ints a and b (mod secp256k1 order) and stores the result in a
// returns true on success
int BRSecp256k1ModAdd(UInt256 * _Nonnull a, const UInt256 * _Nonnull b);

// multiplies 256bit big endian ints a and b (mod secp256k1 order) and stores the result in a
// returns true on success
int BRSecp256k1ModMul(UInt256 * _Nonnull a, const UInt256 * _Nonnull b);

// multiplies secp256k1 generator by 256bit big endian int i and stores the result in p
// returns true on success
int BRSecp256k1PointGen(BRECPoint * _Nonnull p, const UInt256 * _Nonnull i);

// multiplies secp256k1 generator by 256bit big endian int i and adds the result to ec-point p
// returns true on success
int BRSecp256k1PointAdd(BRECPoint * _Nonnull p, const UInt256 * _Nonnull i);

// multiplies secp256k1 ec-point p by 256bit big endian int i and stores the result in p
// returns true on success
int BRSecp256k1PointMul(BRECPoint * _Nonnull p, const UInt256 * _Nonnull i);

@interface BRKey : NSObject

@property (nullable, nonatomic, readonly) NSString *privateKey;
@property (nullable, nonatomic, readonly) NSData *publicKey;
@property (nullable, nonatomic, readonly) NSString *address;
@property (nonatomic, readonly) UInt160 hash160;

+ (nullable instancetype)keyWithPrivateKey:(nonnull NSString *)privateKey;
+ (nullable instancetype)keyWithSecret:(UInt256)secret compressed:(BOOL)compressed;
+ (nullable instancetype)keyWithPublicKey:(nonnull NSData *)publicKey;
+ (nullable instancetype)keyRecoveredFromCompactSig:(nonnull NSData *)compactSig andMessageDigest:(UInt256)md;

- (nullable instancetype)initWithPrivateKey:(nonnull NSString *)privateKey;
- (nullable instancetype)initWithSecret:(UInt256)secret compressed:(BOOL)compressed;
- (nullable instancetype)initWithPublicKey:(nonnull NSData *)publicKey;
- (nullable instancetype)initWithCompactSig:(nonnull NSData *)compactSig andMessageDigest:(UInt256)md;

- (nullable NSData *)sign:(UInt256)md;
- (BOOL)verify:(UInt256)md signature:(nonnull NSData *)sig;

// Pieter Wuille's compact signature encoding used for bitcoin message signing
// to verify a compact signature, recover a public key from the signature and verify that it matches the signer's pubkey
- (nullable NSData *)compactSign:(UInt256)md;

@end
