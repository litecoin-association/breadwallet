//
//  BRKey+BIP38.m
//  BreadWallet
//
//  Created by Aaron Voisine on 4/9/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
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

#import "BRKey+BIP38.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"

// BIP38 is a method for encrypting private keys with a passphrase
// https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki

const uint8_t sbox[256] = {
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
};

const uint8_t sboxi[256] = {
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
};

#define xt(x) (((x) << 1) ^ ((((x) >> 7) & 1)*0x1b))

static void AES256ECBEncrypt(const void *key, void *buf)
{
    size_t i, j;
    uint8_t *x = buf, k[32], r = 1, a, b, c, d, e;
    
    memcpy(k, key, sizeof(k));

    for (i = 0; i < 14; i++) {
        for (j = 0; j < 4; j++) ((uint32_t *)x)[j] ^= ((uint32_t *)k)[j + (i & 1)*4]; // add round key

        for (j = 0; j < 16; j++) x[j] = sbox[x[j]]; // sub bytes
        
        // shift rows
        a = x[1], x[1] = x[5], x[5] = x[9], x[9] = x[13], x[13] = a, a = x[10], x[10] = x[2], x[2] = a;
        a = x[3], x[3] = x[15], x[15] = x[11], x[11] = x[7], x[7] = a, a = x[14], x[14] = x[6], x[6] = a;
        
        for (j = 0; i < 13 && j < 16; j += 4) { // mix columns
            a = x[j], b = x[j+1], c = x[j+2], d = x[j+3], e = a ^ b ^ c ^ d;
            x[j] ^= e ^ xt(a ^ b), x[j+1] ^= e ^ xt(b ^ c), x[j+2] ^= e ^ xt(c ^ d), x[j+3] ^= e ^ xt(d ^ a);
        }

        if ((i % 2) != 0) { // expand key
            k[0] ^= sbox[k[29]] ^ r, k[1] ^= sbox[k[30]], k[2] ^= sbox[k[31]], k[3] ^= sbox[k[28]], r = xt(r);
            for (j = 4; j < 16; j += 4) k[j] ^= k[j-4], k[j+1] ^= k[j-3], k[j+2] ^= k[j-2], k[j+3] ^= k[j-1];
            k[16] ^= sbox[k[12]], k[17] ^= sbox[k[13]], k[18] ^= sbox[k[14]], k[19] ^= sbox[k[15]];
            for (j = 20; j < 32; j += 4) k[j] ^= k[j-4], k[j+1] ^= k[j-3], k[j+2] ^= k[j-2], k[j+3] ^= k[j-1];
        }
    }
    
    for (i = 0; i < 4; i++) ((uint32_t *)x)[i] ^= ((uint32_t *)k)[i]; // final add round key
}

static void AES256ECBDecrypt(const void *key, void *buf)
{
    size_t i, j;
    uint8_t *x = buf, k[32], r = 1, a, b, c, d, e, f, g, h;
    
    memcpy(k, key, sizeof(k));

    for (i = 0; i < 7; i++) { // expand key
        k[0] ^= sbox[k[29]] ^ r, k[1] ^= sbox[k[30]], k[2] ^= sbox[k[31]], k[3] ^= sbox[k[28]], r = xt(r);
        for (j = 4; j < 16; j += 4) k[j] ^= k[j-4], k[j+1] ^= k[j-3], k[j+2] ^= k[j-2], k[j+3] ^= k[j-1];
        k[16] ^= sbox[k[12]], k[17] ^= sbox[k[13]], k[18] ^= sbox[k[14]], k[19] ^= sbox[k[15]];
        for (j = 20; j < 32; j += 4) k[j] ^= k[j-4], k[j+1] ^= k[j-3], k[j+2] ^= k[j-2], k[j+3] ^= k[j-1];
    }
    
    for (i = 0; i < 14; i++) {
        for (j = 0; j < 4; j++) ((uint32_t *)x)[j] ^= ((uint32_t *)k)[j + (i & 1)*4]; // add round key

        for (j = 0; i > 0 && j < 16; j += 4) { // unmix columns
            a = x[j], b = x[j+1], c = x[j+2], d = x[j+3], e = a ^ b ^ c ^ d;
            h = xt(e), f = e ^ xt(xt(h ^ a ^ c)), g = e ^ xt(xt(h ^ b ^ d));
            x[j] ^= f ^ xt(a ^ b), x[j+1] ^= g ^ xt(b ^ c), x[j+2] ^= f ^ xt(c ^ d), x[j+3] ^= g ^ xt(d ^ a);
        }

        // unshift rows
        a = x[1], x[1] = x[13], x[13] = x[9], x[9] = x[5], x[5] = a, a = x[2], x[2] = x[10], x[10] = a;
        a = x[3], x[3] = x[7], x[7] = x[11], x[11] = x[15], x[15] = a, a = x[6], x[6] = x[14], x[14] = a;
        
        for (j = 0; j < 16; j++) x[j] = sboxi[x[j]]; // unsub bytes
        
        if ((i % 2) == 0) { // unexpand key
            for (j = 28; j > 16; j -= 4) k[j] ^= k[j-4], k[j+1] ^= k[j-3], k[j+2] ^= k[j-2], k[j+3] ^= k[j-1];
            k[16] ^= sbox[k[12]], k[17] ^= sbox[k[13]], k[18] ^= sbox[k[14]], k[19] ^= sbox[k[15]];
            for (j = 12; j > 0; j -= 4) k[j] ^= k[j-4], k[j+1] ^= k[j-3], k[j+2] ^= k[j-2], k[j+3] ^= k[j-1];
            r = (r >> 1) ^ ((r & 1)*0x8d);
            k[0] ^= sbox[k[29]] ^ r, k[1] ^= sbox[k[30]], k[2] ^= sbox[k[31]], k[3] ^= sbox[k[28]];
        }
    }
    
    for (i = 0; i < 4; i++) ((uint32_t *)x)[i] ^= ((uint32_t *)k)[i]; // final add round key
}

#define BIP38_SCRYPT_N    16384
#define BIP38_SCRYPT_R    8
#define BIP38_SCRYPT_P    8
#define BIP38_SCRYPT_EC_N 1024
#define BIP38_SCRYPT_EC_R 1
#define BIP38_SCRYPT_EC_P 1

// bitwise left rotation, this will typically be compiled into a single instruction
#define rotl(a, b) (((a) << (b)) | ((a) >> (32 - (b))))

// salsa20/8 stream cypher: http://cr.yp.to/snuffle.html
static void salsa20_8(uint32_t b[16])
{
    uint32_t x00 = b[0], x01 = b[1], x02 = b[2], x03 = b[3], x04 = b[4], x05 = b[5], x06 = b[6], x07 = b[7],
             x08 = b[8], x09 = b[9], x10 = b[10], x11 = b[11], x12 = b[12], x13 = b[13], x14 = b[14], x15 = b[15];

    for (int i = 0; i < 8; i += 2) {
        // operate on columns
        x04 ^= rotl(x00 + x12, 7), x08 ^= rotl(x04 + x00, 9), x12 ^= rotl(x08 + x04, 13), x00 ^= rotl(x12 + x08, 18);
        x09 ^= rotl(x05 + x01, 7), x13 ^= rotl(x09 + x05, 9), x01 ^= rotl(x13 + x09, 13), x05 ^= rotl(x01 + x13, 18);
        x14 ^= rotl(x10 + x06, 7), x02 ^= rotl(x14 + x10, 9), x06 ^= rotl(x02 + x14, 13), x10 ^= rotl(x06 + x02, 18);
        x03 ^= rotl(x15 + x11, 7), x07 ^= rotl(x03 + x15, 9), x11 ^= rotl(x07 + x03, 13), x15 ^= rotl(x11 + x07, 18);

        // operate on rows
        x01 ^= rotl(x00 + x03, 7), x02 ^= rotl(x01 + x00, 9), x03 ^= rotl(x02 + x01, 13), x00 ^= rotl(x03 + x02, 18);
        x06 ^= rotl(x05 + x04, 7), x07 ^= rotl(x06 + x05, 9), x04 ^= rotl(x07 + x06, 13), x05 ^= rotl(x04 + x07, 18);
        x11 ^= rotl(x10 + x09, 7), x08 ^= rotl(x11 + x10, 9), x09 ^= rotl(x08 + x11, 13), x10 ^= rotl(x09 + x08, 18);
        x12 ^= rotl(x15 + x14, 7), x13 ^= rotl(x12 + x15, 9), x14 ^= rotl(x13 + x12, 13), x15 ^= rotl(x14 + x13, 18);
    }

    b[0] += x00, b[1] += x01, b[2] += x02, b[3] += x03, b[4] += x04, b[5] += x05, b[6] += x06, b[7] += x07;
    b[8] += x08, b[9] += x09, b[10] += x10, b[11] += x11, b[12] += x12, b[13] += x13, b[14] += x14, b[15] += x15;
}

static void blockmix_salsa8(uint64_t *dest, const uint64_t *src, uint64_t *b, int r)
{
    memcpy(b, &src[(2*r - 1)*8], 64);

    for (int i = 0; i < 2*r; i += 2) {
        for (int j = 0; j < 8; j++) b[j] ^= src[i*8 + j];
        salsa20_8((uint32_t *)b);
        memcpy(&dest[i*4], b, 64);
        for (int j = 0; j < 8; j++) b[j] ^= src[i*8 + 8 + j];
        salsa20_8((uint32_t *)b);
        memcpy(&dest[i*4 + r*8], b, 64);
    }
}

// scrypt key derivation: http://www.tarsnap.com/scrypt.html
void scrypt(const void *pw, size_t pwlen, const void *salt, size_t slen, long n, int r, int p,
                   void *dk, size_t dklen)
{
    uint64_t x[16*r], y[16*r], z[8], *v = malloc(128*r*n), m;
    uint32_t b[32*r*p];

    PBKDF2(b, sizeof(b), SHA256, 32, pw, pwlen, salt, slen, 1);

    for (int i = 0; i < p; i++) {
        for (long j = 0; j < 32*r; j++) {
            ((uint32_t *)x)[j] = CFSwapInt32LittleToHost(b[i*32*r + j]);
        }

        for (long j = 0; j < n; j += 2) {
            memcpy(&v[j*(16*r)], x, 128*r);
            blockmix_salsa8(y, x, z, r);
            memcpy(&v[(j + 1)*(16*r)], y, 128*r);
            blockmix_salsa8(x, y, z, r);
        }

        for (long j = 0; j < n; j += 2) {
            m = CFSwapInt64LittleToHost(x[(2*r - 1)*8]) & (n - 1);
            for (long k = 0; k < 16*r; k++) x[k] ^= v[m*(16*r) + k];
            blockmix_salsa8(y, x, z, r);
            m = CFSwapInt64LittleToHost(y[(2*r - 1)*8]) & (n - 1);
            for (long k = 0; k < 16*r; k++) y[k] ^= v[m*(16*r) + k];
            blockmix_salsa8(x, y, z, r);
        }

        for (long j = 0; j < 32*r; j++) {
            b[i*32*r + j] = CFSwapInt32HostToLittle(((uint32_t *)x)[j]);
        }
    }

    PBKDF2(dk, dklen, SHA256, 32, pw, pwlen, b, sizeof(b), 1);

    memset(b, 0, sizeof(b));
    memset(x, 0, sizeof(x));
    memset(y, 0, sizeof(y));
    memset(z, 0, sizeof(z));
    memset(v, 0, 128*r*n);
    free(v);
    memset(&m, 0, sizeof(m));
}

static NSData *normalize_passphrase(NSString *passphrase)
{
    NSData *password;
    CFMutableStringRef pw = CFStringCreateMutableCopy(SecureAllocator(), 0, (CFStringRef)passphrase);

    CFStringNormalize(pw, kCFStringNormalizationFormC);
    password = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), pw, kCFStringEncodingUTF8, 0));
    CFRelease(pw);
    return password;
}

static UInt256 derive_passfactor(uint8_t flag, uint64_t entropy, NSString *passphrase)
{
    NSData *pw = normalize_passphrase(passphrase);
    UInt256 prefactor;

    scrypt(pw.bytes, pw.length, &entropy, (flag & BIP38_LOTSEQUENCE_FLAG) ? 4 : 8, BIP38_SCRYPT_N, BIP38_SCRYPT_R,
           BIP38_SCRYPT_P, &prefactor, sizeof(prefactor));

    if (flag & BIP38_LOTSEQUENCE_FLAG) { // passfactor = SHA256(SHA256(prefactor + entropy))
        NSMutableData *d = [NSMutableData secureData];
        
        [d appendBytes:&prefactor length:sizeof(prefactor)];
        [d appendBytes:&entropy length:sizeof(entropy)];
        return d.SHA256_2;
    }
    else return prefactor; // passfactor = prefactor
}

static UInt512 derive_key(NSData *passpoint, uint32_t addresshash, uint64_t entropy)
{
    UInt512 dk;
    unsigned char salt[sizeof(addresshash) + sizeof(entropy)];

    *(uint32_t *)salt = addresshash;
    *(uint64_t *)(salt + sizeof(uint32_t)) = entropy; // salt = addresshash + entropy
 
    scrypt(passpoint.bytes, passpoint.length, salt, sizeof(salt), BIP38_SCRYPT_EC_N, BIP38_SCRYPT_EC_R,
           BIP38_SCRYPT_EC_P, &dk, sizeof(dk));
    return dk;
}

static NSData *point_gen(UInt256 factor)
{
    NSMutableData *d = [NSMutableData secureDataWithLength:33];
    
    BRSecp256k1PointGen(d.mutableBytes, &factor);
    return d;
}

static NSData *point_mul(NSData *point, UInt256 factor)
{
    NSMutableData *d = [NSMutableData secureDataWithData:point];
    
    BRSecp256k1PointGen(d.mutableBytes, &factor);
    return d;
}

@implementation BRKey (BIP38)

// decrypts a BIP38 key using the given passphrase or retuns nil if passphrase is incorrect
+ (instancetype)keyWithBIP38Key:(NSString *)key andPassphrase:(NSString *)passphrase
{
    return [[self alloc] initWithBIP38Key:key andPassphrase:passphrase];
}

// generates an "intermediate code" for an EC multiply mode key, salt should be 64bits of random data
+ (NSString *)BIP38IntermediateCodeWithSalt:(uint64_t)salt andPassphrase:(NSString *)passphrase;
{
    if (! passphrase) return nil;
    salt = CFSwapInt64HostToBig(salt);

    NSMutableData *code = [NSMutableData secureData];

    [code appendBytes:"\x2C\xE9\xB3\xE1\xFF\x39\xE2\x53" length:8];
    [code appendBytes:&salt length:sizeof(salt)];
    [code appendData:point_gen(derive_passfactor(0, salt, passphrase))]; // passpoint = G*passfactor
    return [NSString base58checkWithData:code];
}

// generates an "intermediate code" for an EC multiply mode key with a lot and sequence number, lot must be less than
// 1048576, sequence must be less than 4096, and salt should be 32bits of random data
+ (NSString *)BIP38IntermediateCodeWithLot:(uint32_t)lot sequence:(uint16_t)sequence salt:(uint32_t)salt
passphrase:(NSString *)passphrase
{
    if (lot >= 0x100000u || sequence >= 0x1000u || ! passphrase) return nil;
    salt = CFSwapInt32HostToBig(salt);

    uint32_t lotsequence = CFSwapInt32HostToBig(lot*0x1000u + sequence);
    NSMutableData *entropy = [NSMutableData secureData], *code = [NSMutableData secureData];

    [entropy appendBytes:&salt length:sizeof(salt)];
    [entropy appendBytes:&lotsequence length:sizeof(lotsequence)];

    UInt256 passfactor = derive_passfactor(BIP38_LOTSEQUENCE_FLAG, *(const uint64_t *)entropy.bytes, passphrase);

    [code appendBytes:"\x2C\xE9\xB3\xE1\xFF\x39\xE2\x51" length:8];
    [code appendData:entropy];
    [code appendData:point_gen(passfactor)]; // passpoint = G*passfactor
    return [NSString base58checkWithData:code];
}

// generates a BIP38 key from an "intermediate code" and 24 bytes of cryptographically random data (seedb),
// compressed indicates if compressed pubKey format should be used for the bitcoin address
+ (NSString *)BIP38KeyWithIntermediateCode:(NSString *)code seedb:(NSData *)seedb
{
    NSData *d = code.base58checkToData; // d = 0x2C 0xE9 0xB3 0xE1 0xFF 0x39 0xE2 0x51|0x53 + entropy + passpoint

    if (d.length != 49 || seedb.length != 24) return nil;

    NSData *passpoint = [NSData dataWithBytesNoCopy:(uint8_t *)d.bytes + 16 length:33 freeWhenDone:NO];
    UInt256 factorb = seedb.SHA256_2; // factorb = SHA256(SHA256(seedb))
    NSData *pubKey = point_mul(passpoint, factorb), // pubKey = passpoint*factorb
           *address = [[BRKey keyWithPublicKey:pubKey].address dataUsingEncoding:NSUTF8StringEncoding];
    uint16_t prefix = CFSwapInt16HostToBig(BIP38_EC_PREFIX);
    uint8_t flag = BIP38_COMPRESSED_FLAG;
    uint32_t addresshash = (address) ? address.SHA256_2.u32[0] : 0;
    uint64_t entropy = *(const uint64_t *)((const uint8_t *)d.bytes + 8);
    UInt512 derived = derive_key(passpoint, addresshash, entropy);
    UInt256 derived1 = *(UInt256 *)&derived, derived2 = *(UInt256 *)&derived.u64[4];
    UInt128 encrypted1, encrypted2;
    NSMutableData *key = [NSMutableData secureData];

    if (((const uint8_t *)d.bytes)[7] == 0x51) flag |= BIP38_LOTSEQUENCE_FLAG;

    // enctryped1 = AES256Encrypt(seedb[0...15] xor derived1[0...15], derived2)
    encrypted1.u64[0] = ((const uint64_t *)seedb.bytes)[0] ^ derived1.u64[0];
    encrypted1.u64[1] = ((const uint64_t *)seedb.bytes)[1] ^ derived1.u64[1];
    AES256ECBEncrypt(&derived2, &encrypted1);

    // encrypted2 = AES256Encrypt((encrypted1[8...15] + seedb[16...23]) xor derived1[16...31], derived2)
    encrypted2.u64[0] = encrypted1.u64[1] ^ derived1.u64[2];
    encrypted2.u64[1] = ((const uint64_t *)seedb.bytes)[2] ^ derived1.u64[3];
    AES256ECBEncrypt(&derived2, &encrypted2);

    [key appendBytes:&prefix length:sizeof(prefix)];
    [key appendBytes:&flag length:sizeof(flag)];
    [key appendBytes:&addresshash length:sizeof(addresshash)];
    [key appendBytes:&entropy length:sizeof(entropy)];
    [key appendBytes:&encrypted1 length:8];
    [key appendBytes:&encrypted2 length:sizeof(encrypted2)];
    return [NSString base58checkWithData:key];
}

- (instancetype)initWithBIP38Key:(NSString *)key andPassphrase:(NSString *)passphrase
{
    NSData *d = key.base58checkToData;

    if (d.length != 39 || ! passphrase) return nil;

    uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *)d.bytes);
    uint8_t flag = ((const uint8_t *)d.bytes)[2];
    uint32_t addresshash = *(const uint32_t *)((const uint8_t *)d.bytes + 3);
    UInt256 secret;

    if (prefix == BIP38_NOEC_PREFIX) { // non EC multiplied key
        // d = prefix + flag + addresshash + encrypted1 + encrypted2
        NSData *pw = normalize_passphrase(passphrase);
        UInt512 derived;
        
        scrypt(pw.bytes, pw.length, &addresshash, sizeof(addresshash), BIP38_SCRYPT_N, BIP38_SCRYPT_R, BIP38_SCRYPT_P,
               &derived, sizeof(derived));

        UInt256 derived1 = *(UInt256 *)&derived, derived2 = *(UInt256 *)&derived.u64[4];
        UInt128 encrypted1 = *(UInt128 *)((uint8_t *)d.bytes + 7), encrypted2 = *(UInt128 *)((uint8_t *)d.bytes + 23);

        AES256ECBDecrypt(&derived2, &encrypted1);
        secret.u64[0] = encrypted1.u64[0] ^ derived1.u64[0];
        secret.u64[1] = encrypted1.u64[1] ^ derived1.u64[1];
        
        AES256ECBDecrypt(&derived2, &encrypted2);
        secret.u64[2] = encrypted2.u64[0] ^ derived1.u64[2];
        secret.u64[3] = encrypted2.u64[1] ^ derived1.u64[3];
    }
    else if (prefix == BIP38_EC_PREFIX) { // EC multipled key
        // d = prefix + flag + addresshash + entropy + encrypted1[0...7] + encrypted2
        uint64_t entropy = *(const uint64_t *)((const uint8_t *)d.bytes + 7);
        UInt128 encrypted1 = UINT128_ZERO, encrypted2 = *(UInt128 *)((const uint8_t *)d.bytes + 23);
        UInt256 passfactor = derive_passfactor(flag, entropy, passphrase), factorb;
        NSData *passpoint = point_gen(passfactor); // passpoint = G*passfactor
        UInt512 derived = derive_key(passpoint, addresshash, entropy);
        UInt256 derived1 = *(UInt256 *)&derived, derived2 = *(UInt256 *)&derived.u64[4];
        NSMutableData *seedb = [NSMutableData secureDataWithLength:24];

        encrypted1.u64[0] = *(uint64_t *)((const uint8_t *)d.bytes + 15);
        
        // encrypted2 = (encrypted1[8...15] + seedb[16...23]) xor derived1[16...31]
        AES256ECBDecrypt(&derived2, &encrypted2);
        encrypted1.u64[1] = encrypted2.u64[0] ^ derived1.u64[2];
        ((uint64_t *)seedb.mutableBytes)[2] = encrypted2.u64[1] ^ derived1.u64[3];

        // encrypted1 = seedb[0...15] xor derived1[0...15]
        AES256ECBDecrypt(&derived2, &encrypted1);
        ((uint64_t *)seedb.mutableBytes)[0] = encrypted1.u64[0] ^ derived1.u64[0];
        ((uint64_t *)seedb.mutableBytes)[1] = encrypted1.u64[1] ^ derived1.u64[1];

        factorb = seedb.SHA256_2; // factorb = SHA256(SHA256(seedb))
        secret = passfactor;
        BRSecp256k1ModMul(&secret, &factorb); // secret = passfactor*factorb mod N
    }

    if (! (self = [self initWithSecret:secret compressed:flag & BIP38_COMPRESSED_FLAG])) return nil;

    NSData *address = [self.address dataUsingEncoding:NSUTF8StringEncoding];

    if (! address || address.SHA256_2.u32[0] != addresshash) {
        NSLog(@"BIP38 bad passphrase");
        return nil;
    }

    return self;
}

// encrypts receiver with passphrase and returns BIP38 key
- (NSString *)BIP38KeyWithPassphrase:(NSString *)passphrase
{
    NSData *priv = self.privateKey.base58checkToData;

    if (priv.length < 33 || ! passphrase) return nil;

    uint16_t prefix = CFSwapInt16HostToBig(BIP38_NOEC_PREFIX);
    uint8_t flag = BIP38_NOEC_FLAG;
    NSData *pw = normalize_passphrase(passphrase),
           *address = [self.address dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t salt = address.SHA256_2.u32[0];
    UInt512 derived;
    
    scrypt(pw.bytes, pw.length, &salt, sizeof(salt), BIP38_SCRYPT_N, BIP38_SCRYPT_R, BIP38_SCRYPT_P, &derived, 64);

    UInt256 derived1 = *(UInt256 *)&derived, derived2 = *(UInt256 *)&derived.u64[4];
    UInt128 encrypted1, encrypted2;
    NSMutableData *key = [NSMutableData secureData];

    if (priv.length > 33) flag |= BIP38_COMPRESSED_FLAG;
    
    // enctryped1 = AES256Encrypt(privkey[0...15] xor derived1[0...15], derived2)
    encrypted1.u64[0] = ((uint64_t *)((uint8_t *)priv.bytes + 1))[0] ^ derived1.u64[0];
    encrypted1.u64[1] = ((uint64_t *)((uint8_t *)priv.bytes + 1))[1] ^ derived1.u64[1];
    AES256ECBEncrypt(&derived2, &encrypted1);

    // encrypted2 = AES256Encrypt(privkey[16...31] xor derived1[16...31], derived2)
    encrypted2.u64[0] = ((uint64_t *)((uint8_t *)priv.bytes + 1))[2] ^ derived1.u64[2];
    encrypted2.u64[1] = ((uint64_t *)((uint8_t *)priv.bytes + 1))[3] ^ derived1.u64[3];
    AES256ECBEncrypt(&derived2, &encrypted2);

    [key appendBytes:&prefix length:sizeof(prefix)];
    [key appendBytes:&flag length:sizeof(flag)];
    [key appendBytes:&salt length:sizeof(salt)];
    [key appendBytes:&encrypted1 length:sizeof(encrypted1)];
    [key appendBytes:&encrypted2 length:sizeof(encrypted2)];
    
    return [NSString base58checkWithData:key];
}

@end
