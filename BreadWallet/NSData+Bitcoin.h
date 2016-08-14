//
//  NSData+Bitcoin.h
//  BreadWallet
//
//  Created by Aaron Voisine on 10/9/13.
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

typedef union _UInt512 {
    uint8_t u8[512/8];
    uint16_t u16[512/16];
    uint32_t u32[512/32];
    uint64_t u64[512/64];
} UInt512;

typedef union _UInt256 {
    uint8_t u8[256/8];
    uint16_t u16[256/16];
    uint32_t u32[256/32];
    uint64_t u64[256/64];
} UInt256;

typedef union _UInt160 {
    uint8_t u8[160/8];
    uint16_t u16[160/16];
    uint32_t u32[160/32];
} UInt160;

typedef union _UInt128 {
    uint8_t u8[128/8];
    uint16_t u16[128/16];
    uint32_t u32[128/32];
    uint64_t u64[128/64];
} UInt128;

#define uint512_eq(a, b)\
    ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] &&\
     (a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5] && (a).u64[6] == (b).u64[6] && (a).u64[7] == (b).u64[7])
#define uint256_eq(a, b)\
    ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3])
#define uint160_eq(a, b)\
    ((a).u32[0] == (b).u32[0] && (a).u32[1] == (b).u32[1] && (a).u32[2] == (b).u32[2] && (a).u32[3] == (b).u32[3] &&\
     (a).u32[4] == (b).u32[4])
#define uint128_eq(a, b) ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1])

#define uint512_is_zero(u)\
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7]) == 0)
#define uint256_is_zero(u) (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3]) == 0)
#define uint160_is_zero(u) (((u).u32[0] | (u).u32[1] | (u).u32[2] | (u).u32[3] | (u).u32[4]) == 0)
#define uint128_is_zero(u) (((u).u64[0] | (u).u64[1]) == 0)

#define uint512_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt512)])
#define uint256_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt256)])
#define uint160_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt160)])
#define uint128_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt128)])

#define UINT512_ZERO ((UInt512) { .u64 = { 0, 0, 0, 0, 0, 0, 0, 0 } })
#define UINT256_ZERO ((UInt256) { .u64 = { 0, 0, 0, 0 } })
#define UINT160_ZERO ((UInt160) { .u32 = { 0, 0, 0, 0, 0 } })
#define UINT128_ZERO ((UInt128) { .u64 = { 0, 0 } })

#define RMD160_DIGEST_LENGTH (160/8)
#define MD5_DIGEST_LENGTH    (128/8)

#define VAR_INT16_HEADER 0xfd
#define VAR_INT32_HEADER 0xfe
#define VAR_INT64_HEADER 0xff

// bitcoin script opcodes: https://en.bitcoin.it/wiki/Script#Constants
#define OP_PUSHDATA1   0x4c
#define OP_PUSHDATA2   0x4d
#define OP_PUSHDATA4   0x4e
#define OP_DUP         0x76
#define OP_EQUAL       0x87
#define OP_EQUALVERIFY 0x88
#define OP_HASH160     0xa9
#define OP_CHECKSIG    0xac

void SHA1(void *_Nonnull md, const void *_Nonnull data, size_t len);
void SHA256(void *_Nonnull md, const void *_Nonnull data, size_t len);
void SHA512(void *_Nonnull md, const void *_Nonnull data, size_t len);
void RMD160(void *_Nonnull md, const void *_Nonnull data, size_t len);
void MD5(void *_Nonnull md, const void *_Nonnull data, size_t len);
void HMAC(void *_Nonnull md, void (*_Nonnull hash)(void *_Nonnull , const void *_Nonnull , size_t), size_t hlen,
          const void *_Nonnull key, size_t klen, const void *_Nonnull data, size_t dlen);
void PBKDF2(void *_Nonnull dk, size_t dklen, void (*_Nonnull hash)(void *_Nonnull , const void *_Nonnull , size_t),
            size_t hlen, const void *_Nonnull pw, size_t pwlen, const void *_Nonnull salt, size_t slen,
            unsigned rounds);

// poly1305 authenticator: https://tools.ietf.org/html/rfc7539
// must use constant time mem comparison when verifying mac to defend against timing attacks
void poly1305(void *_Nonnull mac16, const void *_Nonnull key32, const void *_Nonnull data, size_t len);

// chacha20 stream cypher: https://cr.yp.to/chacha.html
void chacha20(void *_Nonnull out, const void *_Nonnull key32, const void *_Nonnull iv8, const void *_Nonnull data,
              size_t len, uint64_t counter);

// chacha20-poly1305 authenticated encryption with associated data (AEAD): https://tools.ietf.org/html/rfc7539
size_t chacha20Poly1305AEADEncrypt(void *_Nullable out, size_t outLen, const void *_Nonnull key32,
                                   const void *_Nonnull nonce12, const void *_Nonnull data, size_t dataLen,
                                   const void *_Nonnull ad, size_t adLen);

size_t chacha20Poly1305AEADDecrypt(void *_Nullable out, size_t outLen, const void *_Nonnull key32,
                                   const void *_Nonnull nonce12, const void *_Nonnull data, size_t dataLen,
                                   const void *_Nonnull ad, size_t adLen);

@interface NSData (Bitcoin)

+ (nonnull instancetype)dataWithUInt256:(UInt256)n;
+ (nonnull instancetype)dataWithUInt160:(UInt160)n;
+ (nonnull instancetype)dataWithUInt128:(UInt128)n;
+ (nonnull instancetype)dataWithBase58String:(NSString *_Nonnull)b58str;

- (UInt160)SHA1;
- (UInt256)SHA256;
- (UInt256)SCRYPT;
- (UInt256)SHA256_2;
- (UInt512)SHA512;
- (UInt160)RMD160;
- (UInt160)hash160;
- (UInt128)MD5;
- (NSData * _Nonnull)reverse;

- (uint8_t)UInt8AtOffset:(NSUInteger)offset;
- (uint16_t)UInt16AtOffset:(NSUInteger)offset;
- (uint32_t)UInt32AtOffset:(NSUInteger)offset;
- (uint64_t)UInt64AtOffset:(NSUInteger)offset;
- (uint64_t)varIntAtOffset:(NSUInteger)offset length:(NSUInteger * _Nonnull)length;
- (UInt256)hashAtOffset:(NSUInteger)offset;
- (NSString *_Nullable)stringAtOffset:(NSUInteger)offset length:(NSUInteger *_Nonnull)length;
- (NSData *_Nonnull)dataAtOffset:(NSUInteger)offset length:(NSUInteger *_Nonnull)length;

- (NSArray *_Nonnull)scriptElements; // an array of NSNumber and NSData objects representing each script element
- (int)intValue; // returns the opcode used to store the receiver in a script (i.e. OP_PUSHDATA1)

- (NSString *_Nonnull)base58String;

@end
