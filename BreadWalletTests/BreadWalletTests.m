//
//  BreadWalletTests.m
//  BreadWalletTests
//
//  Created by Aaron Voisine on 5/8/13.
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

#import <XCTest/XCTest.h>
#import "BRWalletManager.h"
#import "BRBIP32Sequence.h"
#import "BRBIP39Mnemonic.h"
#import "BRTransaction.h"
#import "BRKey.h"
#import "BRKey+BIP38.h"
#import "BRBloomFilter.h"
#import "BRMerkleBlock.h"
#import "BRPaymentRequest.h"
#import "BRPaymentProtocol.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"
#import "NSString+Bitcoin.h"

//#define SKIP_BIP38 1

@interface BreadWalletTests : XCTestCase

@end

@implementation BreadWalletTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

#pragma mark - testBase58

- (void)testBase58
{
    // test bad input
    NSString *s = [NSString base58WithData:[BTC @"#&$@*^(*#!^" base58ToData]];

    XCTAssertTrue(s.length == 0, @"[NSString base58WithData:]");
    
    s = [NSString base58WithData:[@"" base58ToData]];
    XCTAssertEqualObjects(@"", s, @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz" base58ToData]];
    XCTAssertEqualObjects(@"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", s,
                          @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"1111111111111111111111111111111111111111111111111111111111111111111" base58ToData]];
    XCTAssertEqualObjects(@"1111111111111111111111111111111111111111111111111111111111111111111", s,
                          @"[NSString base58WithData:]");
    
    s = [NSString base58WithData:[@"111111111111111111111111111111111111111111111111111111111111111111z" base58ToData]];
    XCTAssertEqualObjects(@"111111111111111111111111111111111111111111111111111111111111111111z", s,
                          @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"z" base58ToData]];
    XCTAssertEqualObjects(@"z", s, @"[NSString base58WithData:]");
    
    s = [NSString base58checkWithData:nil];
    XCTAssertTrue(s == nil, @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"".hexToData];
    XCTAssertEqualObjects([NSData data], [s base58checkToData], @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"000000000000000000000000000000000000000000".hexToData];
    XCTAssertEqualObjects(@"000000000000000000000000000000000000000000".hexToData, [s base58checkToData],
                          @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"000000000000000000000000000000000000000001".hexToData];
    XCTAssertEqualObjects(@"000000000000000000000000000000000000000001".hexToData, [s base58checkToData],
                          @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"05FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".hexToData];
    XCTAssertEqualObjects(@"05FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".hexToData, [s base58checkToData],
                          @"[NSString base58checkWithData:]");
}

#pragma mark - textSHA1

- (void)testSHA1
{
    UInt160 md = [@"Free online SHA1 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].SHA1;
    
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"6fc2e25172cb15193cb1c6d48f607d42c1d2a215".hexToData.bytes, md),
                  @"[NSData SHA1]");
    
    md = [@"this is some text to test the sha1 implementation with more than 64bytes of data since it's internal "
          "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding].SHA1;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"085194658a9235b2951a83d1b826b987e9385aa3".hexToData.bytes, md),
                  @"[NSData SHA1]");
    
    md = [@"123456789012345678901234567890123456789012345678901234567890"
          dataUsingEncoding:NSUTF8StringEncoding].SHA1;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"245be30091fd392fe191f4bfcec22dcb30a03ae6".hexToData.bytes, md),
                  @"[NSData SHA1]");
    
    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
          dataUsingEncoding:NSUTF8StringEncoding].SHA1; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"c71490fc24aa3d19e11282da77032dd9cdb33103".hexToData.bytes, md),
                  @"[NSData SHA1]");
    
    md = [NSData data].SHA1; // empty
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"da39a3ee5e6b4b0d3255bfef95601890afd80709".hexToData.bytes, md),
                  @"[NSData SHA1]");
    
    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].SHA1;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"86f7e437faa5a7fce15d1ddcb9eaeaea377667b8".hexToData.bytes, md),
                  @"[NSData SHA1]");
}

#pragma mark - textSHA256

- (void)testSHA256
{
    UInt256 md = [@"Free online SHA256 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    
    XCTAssertTrue(uint256_eq(*(UInt256 *)
                             @"43fd9deb93f6e14d41826604514e3d7873a549ac87aebebf3d1c10ad6eb057d0".hexToData.bytes, md),
                  @"[NSData SHA256]");
    
    md = [@"this is some text to test the sha256 implementation with more than 64bytes of data since it's internal "
          "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    XCTAssertTrue(uint256_eq(*(UInt256 *)
                             @"40fd0933df2e7747f19f7d39cd30e1cb89810a7e470638a5f623669f3de9edd4".hexToData.bytes, md),
                  @"[NSData SHA256]");
    
    md = [@"123456789012345678901234567890123456789012345678901234567890"
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    XCTAssertTrue(uint256_eq(*(UInt256 *)
                             @"decc538c077786966ac863b5532c4027b8587ff40f6e3103379af62b44eae44d".hexToData.bytes, md),
                  @"[NSData SHA256]");
    
    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
          dataUsingEncoding:NSUTF8StringEncoding].SHA256; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint256_eq(*(UInt256 *)
                             @"676491965ed3ec50cb7a63ee96315480a95c54426b0b72bca8a0d4ad1285ad55".hexToData.bytes, md),
                  @"[NSData SHA256]");
    
    md = [NSData data].SHA256; // empty
    XCTAssertTrue(uint256_eq(*(UInt256 *)
                             @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".hexToData.bytes, md),
                  @"[NSData SHA256]");
    
    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    XCTAssertTrue(uint256_eq(*(UInt256 *)
                             @"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb".hexToData.bytes, md),
                  @"[NSData SHA256]");
}

#pragma mark - textSHA512

- (void)testSHA512
{
    UInt512 md = [@"Free online SHA512 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].SHA512;

    XCTAssertTrue(uint512_eq(*(UInt512 *)@"04f1154135eecbe42e9adc8e1d532f9c607a8447b786377db8447d11a5b2232cdd419b863922"
                             "4f787a51d110f72591f96451a1bb511c4a829ed0a2ec891321f3".hexToData.bytes, md),
                  @"[NSData SHA512]");
    
    md = [@"this is some text to test the sha512 implementation with more than 128bytes of data since it's internal "
          "digest buffer is 128bytes in size" dataUsingEncoding:NSUTF8StringEncoding].SHA512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"9bd2dc7b05fbbe9934cb3289b6e06b8ca9fd7a55e6de5db7e1e4eeddc6629b575307367cd018"
                             "3a4461d7eb2dfc6a27e41e8b70f6598ebcc7710911d4fb16a390".hexToData.bytes, md),
                  @"[NSData SHA512]");
    
    md = [@"12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567"
          "8901234567890" dataUsingEncoding:NSUTF8StringEncoding].SHA512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"0d9a7df5b6a6ad20da519effda888a7344b6c0c7adcc8e2d504b4af27aaaacd4e7111c713f71"
                             "769539629463cb58c86136c521b0414a3c0edf7dc6349c6edaf3".hexToData.bytes, md),
                  @"[NSData SHA512]");
    
    md = [@"12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567"
          "890123456789012345678" dataUsingEncoding:NSUTF8StringEncoding].SHA512; //exactly 128bytes (internal buf size)
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"222b2f64c285e66996769b5a03ef863cfd3b63ddb0727788291695e8fb84572e4bfe5a80674a"
                             "41fd72eeb48592c9c79f44ae992c76ed1b0d55a670a83fc99ec6".hexToData.bytes, md),
                  @"[NSData SHA512]");
    
    md = [NSData data].SHA512; // empty
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85"
                             "f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e".hexToData.bytes, md),
                  @"[NSData SHA512]");
    
    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].SHA512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"1f40fc92da241694750979ee6cf582f2d5d7d28e18335de05abc54d0560e0f5302860c652bf0"
                             "8d560252aa5e74210546f369fbbbce8c12cfc7957b2652fe9a75".hexToData.bytes, md),
                  @"[NSData SHA512]");
}

#pragma mark - testRMD160

- (void)testRMD160
{
    UInt160 md = [@"Free online RIPEMD160 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].RMD160;
    
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"9501a56fb829132b8748f0ccc491f0ecbc7f945b".hexToData.bytes, md),
                  @"[NSData RMD160]");
    
    md = [@"this is some text to test the ripemd160 implementation with more than 64bytes of data since it's internal "
          "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding].RMD160;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"4402eff42157106a5d92e4d946185856fbc50e09".hexToData.bytes, md),
                  @"[NSData RMD160]");

    md = [@"123456789012345678901234567890123456789012345678901234567890"
          dataUsingEncoding:NSUTF8StringEncoding].RMD160;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"00263b999714e756fa5d02814b842a2634dd31ac".hexToData.bytes, md),
                  @"[NSData RMD160]");

    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
          dataUsingEncoding:NSUTF8StringEncoding].RMD160; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"fa8c1a78eb763bb97d5ea14ce9303d1ce2f33454".hexToData.bytes, md),
                  @"[NSData RMD160]");

    md = [NSData data].RMD160; // empty
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"9c1185a5c5e9fc54612808977ee8f548b2258d31".hexToData.bytes, md),
                  @"[NSData RMD160]");
    
    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].RMD160;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"0bdc9d2d256b3ee9daae347be6f4dc835a467ffe".hexToData.bytes, md),
                  @"[NSData RMD160]");
}

#pragma mark - testScrypt

- (void)testScrypt
{
    UInt256 md = @"01000000f615f7ce3b4fc6b8f61e8f89aedb1d0852507650533a9e3b10b9bbcc30639f279fcaa86746e1ef52d3edb3c4ad8259920d509bd073605c9bf1d59983752a6b06b817bb4ea78e011d012d59d4".hexToData.SCRYPT;
    
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"d9eb8663ffec241c2fb118adb7de97a82c803b6ff46d57667935c81001000000".hexToData.bytes, md),
                  @"[NSData SCRYPT]");
    
    XCTAssertTrue([@"0000000110c8357966576df46f3b802ca897deb7ad18b12f1c24ecff6386ebd9".hexToData.reverse isEqualToData: @"d9eb8663ffec241c2fb118adb7de97a82c803b6ff46d57667935c81001000000".hexToData],
                  @"[NSData SCRYPT]");
}

#pragma mark - testMD5

- (void)testMD5
{
    UInt128 md = [@"Free online MD5 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].MD5;
    
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"0b3b20eaf1696462f50d1a3bbdd30cef".hexToData.bytes, md), @"[NSData MD5]");
    
    md = [@"this is some text to test the md5 implementation with more than 64bytes of data since it's internal "
          "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding].MD5;
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"56a161f24150c62d7857b7f354927ebe".hexToData.bytes, md), @"[NSData MD5]");
    
    md = [@"123456789012345678901234567890123456789012345678901234567890"
          dataUsingEncoding:NSUTF8StringEncoding].MD5;
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"c5b549377c826cc3712418b064fc417e".hexToData.bytes, md), @"[NSData MD5]");
    
    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
          dataUsingEncoding:NSUTF8StringEncoding].MD5; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"eb6c4179c0a7c82cc2828c1e6338e165".hexToData.bytes, md), @"[NSData MD5]");
    
    md = [NSData data].MD5; // empty
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"d41d8cd98f00b204e9800998ecf8427e".hexToData.bytes, md), @"[NSData MD5]");
    
    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].MD5;
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"0cc175b9c0f1b6a831c399e269772661".hexToData.bytes, md), @"[NSData MD5]");
}

#pragma mark - testKey

#if ! BITCOIN_TESTNET
- (void)testKeyWithPrivateKey
{
    XCTAssertFalse([@"S6c56bnXQiBjk9mqSYE7ykVQ7NzrRz" isValidBitcoinPrivateKey],
                  @"[NSString+Base58 isValidBitcoinPrivateKey]");

    // mini private key format
    XCTAssertTrue([@"S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy" isValidBitcoinPrivateKey],
                  @"[NSString+Base58 isValidBitcoinPrivateKey]");

    BRKey *key = [BRKey keyWithPrivateKey:@"S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy"];
    
    NSLog(@"privKey:S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy = %@", key.address);
    XCTAssertEqualObjects(@"1CciesT23BNionJeXrbxmjc7ywfiyM4oLW", key.address, @"[BRKey keyWithPrivateKey:]");

    // old mini private key format
    XCTAssertTrue([@"SzavMBLoXU6kDrqtUVmffv" isValidBitcoinPrivateKey],
                  @"[NSString+Base58 isValidBitcoinPrivateKey]");

    key = [BRKey keyWithPrivateKey:@"SzavMBLoXU6kDrqtUVmffv"];
    
    NSLog(@"privKey:SzavMBLoXU6kDrqtUVmffv = %@", key.address);
    XCTAssertEqualObjects(@"1CC3X2gu58d6wXUWMffpuzN9JAfTUWu4Kj", key.address, @"[BRKey keyWithPrivateKey:]");

    // uncompressed private key
    key = [BRKey keyWithPrivateKey:@"5Kb8kLf9zgWQnogidDA76MzPL6TsZZY36hWXMssSzNydYXYB9KF"];
    
    NSLog(@"privKey:5Kb8kLf9zgWQnogidDA76MzPL6TsZZY36hWXMssSzNydYXYB9KF = %@", key.address);
    XCTAssertEqualObjects(@"1CC3X2gu58d6wXUWMffpuzN9JAfTUWu4Kj", key.address, @"[BRKey keyWithPrivateKey:]");

    // uncompressed private key export
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5Kb8kLf9zgWQnogidDA76MzPL6TsZZY36hWXMssSzNydYXYB9KF", key.privateKey,
                          @"[BRKey privateKey]");

    // compressed private key
    key = [BRKey keyWithPrivateKey:@"KyvGbxRUoofdw3TNydWn2Z78dBHSy2odn1d3wXWN2o3SAtccFNJL"];
    
    NSLog(@"privKey:KyvGbxRUoofdw3TNydWn2Z78dBHSy2odn1d3wXWN2o3SAtccFNJL = %@", key.address);
    XCTAssertEqualObjects(@"1JMsC6fCtYWkTjPPdDrYX3we2aBrewuEM3", key.address, @"[BRKey keyWithPrivateKey:]");

    // compressed private key export
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"KyvGbxRUoofdw3TNydWn2Z78dBHSy2odn1d3wXWN2o3SAtccFNJL", key.privateKey,
                          @"[BRKey privateKey]");
}
#endif

#pragma mark - testKeyWithBIP38Key

#if ! BITCOIN_TESTNET && ! SKIP_BIP38
- (void)testKeyWithBIP38Key
{
    NSString *intercode, *privkey;
    BRKey *key;

    // non EC multiplied, uncompressed
    key = [BRKey keyWithBIP38Key:@"6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg"
           andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5KN7MzqK5wt2TP1fQCYyHBtDrXdJuXbUzm4A9rKAteGu3Qi5CVR", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree"],
                          @"6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg",
                          @"[BRKey BIP38KeyWithPassphrase:]");

    key = [BRKey keyWithBIP38Key:@"6PRNFFkZc2NZ6dJqFfhRoFNMR9Lnyj7dYGrzdgXXVMXcxoKTePPX1dWByq"
           andPassphrase:@"Satoshi"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5HtasZ6ofTHP6HCwTqTkLDuLQisYPah7aUnSKfC7h4hMUVw2gi5", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"Satoshi"],
                          @"6PRNFFkZc2NZ6dJqFfhRoFNMR9Lnyj7dYGrzdgXXVMXcxoKTePPX1dWByq",
                          @"[BRKey BIP38KeyWithPassphrase:]");

    // non EC multiplied, compressed
    key = [BRKey keyWithBIP38Key:@"6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo"
           andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"L44B5gGEpqEDRS9vVPz7QT35jcBG2r3CZwSwQ4fCewXAhAhqGVpP", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree"],
                          @"6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo",
                          @"[BRKey BIP38KeyWithPassphrase:]");

    key = [BRKey keyWithBIP38Key:@"6PYLtMnXvfG3oJde97zRyLYFZCYizPU5T3LwgdYJz1fRhh16bU7u6PPmY7"
           andPassphrase:@"Satoshi"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"KwYgW8gcxj1JWJXhPSu4Fqwzfhp5Yfi42mdYmMa4XqK7NJxXUSK7", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"Satoshi"],
                          @"6PYLtMnXvfG3oJde97zRyLYFZCYizPU5T3LwgdYJz1fRhh16bU7u6PPmY7",
                          @"[BRKey BIP38KeyWithPassphrase:]");

    // EC multiplied, uncompressed, no lot/sequence number
    key = [BRKey keyWithBIP38Key:@"6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX"
           andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5K4caxezwjGCGfnoPTZ8tMcJBLB7Jvyjv4xxeacadhq8nLisLR2", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BRKey BIP38IntermediateCodeWithSalt:0xa50dba6772cb9383 andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BRKey BIP38KeyWithIntermediateCode:intercode
               seedb:@"99241d58245c883896f80843d2846672d7312e6195ca1a6c".hexToData compressed:NO];
    XCTAssertEqualObjects(@"6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");

    key = [BRKey keyWithBIP38Key:@"6PfLGnQs6VZnrNpmVKfjotbnQuaJK4KZoPFrAjx1JMJUa1Ft8gnf5WxfKd"
           andPassphrase:@"Satoshi"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5KJ51SgxWaAYR13zd9ReMhJpwrcX47xTJh2D3fGPG9CM8vkv5sH", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BRKey BIP38IntermediateCodeWithSalt:0x67010a9573418906 andPassphrase:@"Satoshi"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BRKey BIP38KeyWithIntermediateCode:intercode
               seedb:@"49111e301d94eab339ff9f6822ee99d9f49606db3b47a497".hexToData compressed:NO];
    XCTAssertEqualObjects(@"6PfLGnQs6VZnrNpmVKfjotbnQuaJK4KZoPFrAjx1JMJUa1Ft8gnf5WxfKd", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");

    // EC multiplied, uncompressed, with lot/sequence number
    key = [BRKey keyWithBIP38Key:@"6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j"
           andPassphrase:@"MOLON LABE"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5JLdxTtcTHcfYcmJsNVy1v2PMDx432JPoYcBTVVRHpPaxUrdtf8", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BRKey BIP38IntermediateCodeWithLot:263183 sequence:1 salt:0x4fca5a97u passphrase:@"MOLON LABE"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BRKey BIP38KeyWithIntermediateCode:intercode
               seedb:@"87a13b07858fa753cd3ab3f1c5eafb5f12579b6c33c9a53f".hexToData compressed:NO];
    XCTAssertEqualObjects(@"6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");

    key = [BRKey keyWithBIP38Key:@"6PgGWtx25kUg8QWvwuJAgorN6k9FbE25rv5dMRwu5SKMnfpfVe5mar2ngH"
           andPassphrase:@"\u039c\u039f\u039b\u03a9\u039d \u039b\u0391\u0392\u0395"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5KMKKuUmAkiNbA3DazMQiLfDq47qs8MAEThm4yL8R2PhV1ov33D", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BRKey BIP38IntermediateCodeWithLot:806938 sequence:1 salt:0xc40ea76fu
                 passphrase:@"\u039c\u039f\u039b\u03a9\u039d \u039b\u0391\u0392\u0395"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BRKey BIP38KeyWithIntermediateCode:intercode
               seedb:@"03b06a1ea7f9219ae364560d7b985ab1fa27025aaa7e427a".hexToData compressed:NO];
    XCTAssertEqualObjects(@"6PgGWtx25kUg8QWvwuJAgorN6k9FbE25rv5dMRwu5SKMnfpfVe5mar2ngH", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");

    // password NFC unicode normalization test
    key = [BRKey keyWithBIP38Key:@"6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn"
           andPassphrase:@"\u03D2\u0301\0\U00010400\U0001F4A9"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5Jajm8eQ22H3pGWLEVCXyvND8dQZhiQhoLJNKjYXk9roUFTMSZ4", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");

    // incorrect password test
    key = [BRKey keyWithBIP38Key:@"6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn" andPassphrase:@"foobar"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertNil(key, @"[BRKey keyWithBIP38Key:andPassphrase:]");
}
#endif

#pragma mark - testSign

- (void)testSign
{
    NSData *sig;
    UInt256 md, sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    BRKey *key = [BRKey keyWithSecret:sec compressed:YES];

    md = [@"Everything should be made as simple as possible, but not simpler."
         dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3044022033a69cd2065432a30f3d1ce4eb0d59b8ab58c74f27c41a7fdb5696ad4e6108c902206f80798286"
                          "6f785d3f6418d24163ddae117b7db4d5fdf0071de069fa54342262".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");
    
    sec = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"Equations are more important to me, because politics is for the present, but an equation is something for "
          "eternity." dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3044022054c4a33c6423d689378f160a7ff8b61330444abb58fb470f96ea16d99d4a2fed02200708230441"
                          "0efa6b2943111b6a4e0aaa7b7db55a07e9861d1fb3cb1f421044a5".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");

    sec = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"Not only is the Universe stranger than we think, it is stranger than we can think."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100ff466a9f1b7b273e2f4c3ffe032eb2e814121ed18ef84665d0f515360dab3dd002206fc95f51"
                          "32e5ecfdc8e5e6e616cc77151455d46ed48f5589b7db7771a332b283".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");

    sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"How wonderful that we have met with a paradox. Now we have some hope of making progress."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100c0dafec8251f1d5010289d210232220b03202cba34ec11fec58b3e93a85b91d3022075afdc06"
                          "b7d6322a590955bf264e7aaa155847f614d80078a90292fe205064d3".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");

    sec = *(UInt256 *)@"69ec59eaa1f4f2e36b639716b7c30ca86d9a5375c7b38d8918bd9c0ebc80ba64".hexToData.bytes;
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"Computer science is no more about computers than astronomy is about telescopes."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"304402207186363571d65e084e7f02b0b77c3ec44fb1b257dee26274c38c928986fea45d02200de0b38e06"
                          "807e46bda1f1e293f4f6323e854c86d58abdd00c46c16441085df6".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");

    sec = *(UInt256 *)@"00000000000000000000000000007246174ab1e92e9149c6e446fe194d072637".hexToData.bytes;
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"...if you aren't, at any given time, scandalized by code you wrote five or even three years ago, you're not"
          " learning anywhere near enough" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100fbfe5076a15860ba8ed00e75e9bd22e05d230f02a936b653eb55b61c99dda48702200e68880e"
                          "bb0050fe4312b1b1eb0899e1b82da89baa5b895f612619edf34cbd37".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");

    sec = *(UInt256 *)@"000000000000000000000000000000000000000000056916d0f9b31dc9b637f3".hexToData.bytes;
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"The question of whether computers can think is like the question of whether submarines can swim."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100cde1302d83f8dd835d89aef803c74a119f561fbaef3eb9129e45f30de86abbf9022006ce643f"
                          "5049ee1f27890467b77a6a8e11ec4661cc38cd8badf90115fbd03cef".hexToData, @"[BRKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[BRKey verify:signature:]");
}

#pragma mark - testCompactSign

- (void)testCompactSign
{
    NSData *pubkey, *sig;
    UInt256 md, sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    BRKey *key;
    
    key = [BRKey keyWithSecret:sec compressed:YES];
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key compactSign:md];
    pubkey = [BRKey keyRecoveredFromCompactSig:sig andMessageDigest:md].publicKey;
    
    XCTAssertEqualObjects(key.publicKey, pubkey);

    key = [BRKey keyWithSecret:sec compressed:NO];
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key compactSign:md];
    pubkey = [BRKey keyRecoveredFromCompactSig:sig andMessageDigest:md].publicKey;
    
    XCTAssertEqualObjects(key.publicKey, pubkey);

    pubkey = @"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData;
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3kq9e842BzkMfbPSbhKVwGZgspDSkz4YfqjdBYQPWDzqd77gPgR1zq4XG7KtAL5DZTcfFFs2iph4urNyXeBkXsEYY".base58ToData;
    key = [BRKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKey, pubkey);

    pubkey = @"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData;
    md = [@"i am a test signed string do de dah" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3qECEYmb6x4X22sH98Aer68SdfrLwtqvb5Ncv7EqKmzbxeYYJ1hU9irP6R5PeCctCPYo5KQiWFgoJ3H5MkuX18gHu".base58ToData;
    key = [BRKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKey, pubkey);

    pubkey = @"gpRv1sNA3XURB6QEtGrx6Q18DZ5cSgUSDQKX4yYypxpW".base58ToData;
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3oHQhxq5eW8dnp7DquTCbA5tECoNx7ubyiubw4kiFm7wXJF916SZVykFzb8rB1K6dEu7mLspBWbBEJyYk79jAosVR".base58ToData;
    key = [BRKey keyRecoveredFromCompactSig:sig andMessageDigest:md];
    
    XCTAssertEqualObjects(key.publicKey, pubkey);
}

#pragma mark - testPaymentRequest

//TODO: test valid request with unknown arguments
//TODO: test invalid bitcoin address
//TODO: test invalid request with unknown required arguments

- (void)testPaymentRequest
{
    BRPaymentRequest *r = [BRPaymentRequest requestWithString:@"1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW"];
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    r = [BRPaymentRequest requestWithString:@"1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQ"];
    XCTAssertFalse(r.isValid);
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQ", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW"];
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW", r.string,
                          @"[BRPaymentRequest requestWithString:]");
    
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=1"];
    XCTAssertEqual(100000000, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=1", r.string,
                          @"[BRPaymentRequest requestWithString:]");
    
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=0.00000001"];
    XCTAssertEqual(1, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=0.00000001", r.string,
                          @"[BRPaymentRequest requestWithString:]");
    
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=21000000"];
    XCTAssertEqual(2100000000000000, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=21000000", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    // test for floating point rounding issues, these values cannot be exactly represented with an IEEE 754 double
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=20999999.99999999"];
    XCTAssertEqual(2099999999999999, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=20999999.99999999", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=20999999.99999995"];
    XCTAssertEqual(2099999999999995, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=20999999.99999995", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=20999999.9999999"];
    XCTAssertEqual(2099999999999990, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=20999999.9999999", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=0.07433"];
    XCTAssertEqual(7433000, r.amount, @"[BRPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=0.07433", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    // invalid amount string
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?amount=foobar"];
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    // test correct encoding of '&' in argument value
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?label=foo%26bar"];
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?label=foo%26bar", r.string,
                          @"[BRPaymentRequest requestWithString:]");
    
    // test handling of ' ' in label or message
    r = [BRPaymentRequest
         requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?label=foo bar&message=bar foo"];
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?label=foo%20bar&message=bar%20foo", r.string,
                          @"[BRPaymentRequest requestWithString:]");
    
    // test bip73
    r = [BRPaymentRequest requestWithString:@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?r=https://foobar.com"];
    XCTAssertEqualObjects(@"bitcoin:1BTCorgHwCg6u2YSAWKgS17qUad6kHmtQW?r=https://foobar.com", r.string,
                          @"[BRPaymentRequest requestWithString:]");

    r = [BRPaymentRequest requestWithString:@"bitcoin:?r=https://foobar.com"];
    XCTAssertTrue(r.isValid);
    XCTAssertEqualObjects(@"bitcoin:?r=https://foobar.com", r.string, @"[BRPaymentRequest requestWithString:]");
}

#pragma mark - testTransaction

- (void)testTransaction
{
    NSMutableData *script = [NSMutableData data];
    UInt256 secret = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    BRKey *k = [BRKey keyWithSecret:secret compressed:YES];
    NSValue *hash = uint256_obj(UINT256_ZERO);

    [script appendScriptPubKeyForAddress:k.address];

    BRTransaction *tx = [[BRTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@0] inputScripts:@[script]
                         outputAddresses:@[k.address, k.address] outputAmounts:@[@100000000, @4900000000]];

    [tx signWithPrivateKeys:@[k.privateKey]];

    XCTAssertTrue([tx isSigned], @"[BRTransaction signWithPrivateKeys:]");

    NSUInteger height = [tx blockHeightUntilFreeForAmounts:@[@5000000000] withBlockHeights:@[@1]];
    uint64_t priority = [tx priorityForAmounts:@[@5000000000] withAges:@[@(height - 1)]];
    
    NSLog(@"height = %lu", (unsigned long)height);
    NSLog(@"priority = %llu", priority);
    
    XCTAssertTrue(priority >= TX_FREE_MIN_PRIORITY, @"[BRTransaction priorityForAmounts:withAges:]");

    NSData *d = tx.data;

    tx = [BRTransaction transactionWithMessage:d];

    XCTAssertEqualObjects(d, tx.data, @"[BRTransaction transactionWithMessage:]");

    tx = [[BRTransaction alloc] initWithInputHashes:@[hash, hash, hash, hash, hash, hash, hash, hash, hash, hash]
          inputIndexes:@[@0, @0,@0, @0, @0, @0, @0, @0, @0, @0]
          inputScripts:@[script, script, script, script, script, script, script, script, script, script]
          outputAddresses:@[k.address, k.address, k.address, k.address, k.address, k.address, k.address, k.address,
                            k.address, k.address]
          outputAmounts:@[@1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000,
                          @1000000]];

    [tx signWithPrivateKeys:@[k.privateKey]];

    XCTAssertTrue([tx isSigned], @"[BRTransaction signWithPrivateKeys:]");

    height = [tx blockHeightUntilFreeForAmounts:@[@1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000,
                                                  @1000000, @1000000, @1000000]
              withBlockHeights:@[@1, @2, @3, @4, @5, @6, @7, @8, @9, @10]];
    priority = [tx priorityForAmounts:@[@1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000,
                                        @1000000, @1000000]
                withAges:@[@(height - 1), @(height - 2), @(height - 3), @(height - 4), @(height - 5), @(height - 6),
                           @(height - 7), @(height - 8), @(height - 9), @(height - 10)]];
    
    NSLog(@"height = %lu", (unsigned long)height);
    NSLog(@"priority = %llu", priority);
    
    XCTAssertTrue(priority >= TX_FREE_MIN_PRIORITY, @"[BRTransaction priorityForAmounts:withAges:]");
    
    d = tx.data;
    tx = [BRTransaction transactionWithMessage:d];

    XCTAssertEqualObjects(d, tx.data, @"[BRTransaction transactionWithMessage:]");
}

#pragma mark - testBIP39Mnemonic

- (void)testBIP39Mnemonic
{
    BRBIP39Mnemonic *m = [BRBIP39Mnemonic new];
    NSString *s = @"bless cloud wheel regular tiny venue bird web grief security dignity zoo";
    NSData *d, *k;

    XCTAssertFalse([m phraseIsValid:s], @"[BRMnemonic phraseIsValid:]"); // test correct handling of bad checksum
    XCTAssertNil([m normalizePhrase:nil]);
    XCTAssertNil([m deriveKeyFromPhrase:nil withPassphrase:nil]);

    d = @"00000000000000000000000000000000".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon "
                          "about", @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c9"
                          "2f2cf141630c7a3c4ab7c81b2f001698e7463b04".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"legal winner thank year wave sausage worth useful legal winner thank yellow",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6fa457fe1296106559a3c80937"
                          "a1c1069be3a3a5bd381ee6260e8d9739fce1f607".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"80808080808080808080808080808080".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"letter advice cage absurd amount doctor acoustic avoid letter advice cage above",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"d71de856f81a8acc65e6fc851a38d4d7ec216fd0796d0a6827a3ad6ed5511a30fa280f12eb2e47ed2ac03b5c"
                          "462a0358d18d69fe4f985ec81778c1b370b652a8".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"ffffffffffffffffffffffffffffffff".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"ac27495480225222079d7be181583751e86f571027b0497b5b5d11218e0a8a13332572917f0f8e5a589620c6"
                          "f15b11c61dee327651a14c34e18231052e48c069".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"000000000000000000000000000000000000000000000000".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon "
                          "abandon abandon abandon abandon abandon abandon agent",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"035895f2f481b1b0f01fcf8c289c794660b289981a78f8106447707fdd9666ca06da5a9a565181599b79f53b"
                          "844d8a71dd9f439c52a3d7b3e8a79c906ac845fa".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"legal winner thank year wave sausage worth useful legal winner thank year wave sausage "
                          "worth useful legal will",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"f2b94508732bcbacbcc020faefecfc89feafa6649a5491b8c952cede496c214a0c7b3c392d168748f2d4a612"
                          "bada0753b52a1c7ac53c1e93abd5c6320b9e95dd".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"808080808080808080808080808080808080808080808080".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount "
                          "doctor acoustic avoid letter always",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"107d7c02a5aa6f38c58083ff74f04c607c2d2c0ecc55501dadd72d025b751bc27fe913ffb796f841c49b1d33"
                          "b610cf0e91d3aa239027f5e99fe4ce9e5088cd65".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"ffffffffffffffffffffffffffffffffffffffffffffffff".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo when",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"0cd6e5d827bb62eb8fc1e262254223817fd068a74b5b449cc2f667c3f1f985a76379b43348d952e2265b4cd1"
                          "29090758b3e3c2c49103b5051aac2eaeb890a528".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"0000000000000000000000000000000000000000000000000000000000000000".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon "
                          "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon "
                          "abandon art", @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"bda85446c68413707090a52022edd26a1c9462295029f2e60cd7c4f2bbd3097170af7a4d73245cafa9c3cca8"
                          "d561a7c3de6f5d4a10be8ed2a5e608d68f92fcc8".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"legal winner thank year wave sausage worth useful legal winner thank year wave sausage "
                          "worth useful legal winner thank year wave sausage worth title",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"bc09fca1804f7e69da93c2f2028eb238c227f2e9dda30cd63699232578480a4021b146ad717fbb7e451ce9eb"
                          "835f43620bf5c514db0f8add49f5d121449d3e87".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"8080808080808080808080808080808080808080808080808080808080808080".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount "
                          "doctor acoustic avoid letter advice cage absurd amount doctor acoustic bless",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"c0c519bd0e91a2ed54357d9d1ebef6f5af218a153624cf4f2da911a0ed8f7a09e2ef61af0aca007096df4300"
                          "22f7a2b6fb91661a9589097069720d015e4e982f".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo "
                          "zoo vote", @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"dd48c104698c30cfe2b6142103248622fb7bb0ff692eebb00089b32d22484e1613912f0a5b694407be899ffd"
                          "31ed3992c456cdf60f5d4564b8ba3f05a69890ad".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"77c2b00716cec7213839159e404db50d".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"jelly better achieve collect unaware mountain thought cargo oxygen act hood bridge",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"b5b6d0127db1a9d2226af0c3346031d77af31e918dba64287a1b44b8ebf63cdd52676f672a290aae502472cf"
                          "2d602c051f3e6f18055e84e4c43897fc4e51a6ff".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"b63a9c59a6e641f288ebc103017f1da9f8290b3da6bdef7b".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"renew stay biology evidence goat welcome casual join adapt armor shuffle fault little "
                          "machine walk stumble urge swap",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"9248d83e06f4cd98debf5b6f010542760df925ce46cf38a1bdb4e4de7d21f5c39366941c69e1bdbf2966e0f6"
                          "e6dbece898a0e2f0a4c2b3e640953dfe8b7bbdc5".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"3e141609b97933b66a060dcddc71fad1d91677db872031e85f4c015c5e7e8982".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"dignity pass list indicate nasty swamp pool script soccer toe leaf photo multiply desk "
                          "host tomato cradle drill spread actor shine dismiss champion exotic",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"ff7f3184df8696d8bef94b6c03114dbee0ef89ff938712301d27ed8336ca89ef9635da20af07d4175f2bf5f3"
                          "de130f39c9d9e8dd0472489c19b1a020a940da67".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"0460ef47585604c5660618db2e6a7e7f".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"afford alter spike radar gate glance object seek swamp infant panel yellow",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"65f93a9f36b6c85cbe634ffc1f99f2b82cbb10b31edc7f087b4f6cb9e976e9faf76ff41f8f27c99afdf38f7a"
                          "303ba1136ee48a4c1e7fcd3dba7aa876113a36e4".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"72f60ebac5dd8add8d2a25a797102c3ce21bc029c200076f".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"indicate race push merry suffer human cruise dwarf pole review arch keep canvas theme "
                          "poem divorce alter left",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"3bbf9daa0dfad8229786ace5ddb4e00fa98a044ae4c4975ffd5e094dba9e0bb289349dbe2091761f30f382d4"
                          "e35c4a670ee8ab50758d2c55881be69e327117ba".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"2c85efc7f24ee4573d2b81a6ec66cee209b2dcbd09d8eddc51e0215b0b68e416".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"clutch control vehicle tonight unusual clog visa ice plunge glimpse recipe series open "
                          "hour vintage deposit universe tip job dress radar refuse motion taste",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"fe908f96f46668b2d5b37d82f558c77ed0d69dd0e7e043a5b0511c48c2f1064694a956f86360c93dd04052a8"
                          "899497ce9e985ebe0c8c52b955e6ae86d4ff4449".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"eaebabb2383351fd31d703840b32e9e2".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"turtle front uncle idea crush write shrug there lottery flower risk shell",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"bdfb76a0759f301b0b899a1e3985227e53b3f51e67e3f2a65363caedf3e32fde42a66c404f18d7b05818c95e"
                          "f3ca1e5146646856c461c073169467511680876c".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"7ac45cfe7722ee6c7ba84fbc2d5bd61b45cb2fe5eb65aa78".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"kiss carry display unusual confirm curtain upgrade antique rotate hello void custom "
                          "frequent obey nut hole price segment", @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"ed56ff6c833c07982eb7119a8f48fd363c4a9b1601cd2de736b01045c5eb8ab4f57b079403485d1c4924f079"
                          "0dc10a971763337cb9f9c62226f64fff26397c79".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"4fa1a8bc3e6d80ee1316050e862c1812031493212b7ec3f3bb1b08f168cabeef".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"exile ask congress lamp submit jacket era scheme attend cousin alcohol catch course end "
                          "lucky hurt sentence oven short ball bird grab wing top", @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"095ee6f817b4c2cb30a5a797360a81a40ab0f9a4e25ecd672a3f58a0b5ba0687c096a6b14d2c0deb3bdefce4"
                          "f61d01ae07417d502429352e27695163f7447a8c".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"18ab19a9f54a9274f03e5209a2ac8a91".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"board flee heavy tunnel powder denial science ski answer betray cargo cat",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"6eff1bb21562918509c73cb990260db07c0ce34ff0e3cc4a8cb3276129fbcb300bddfe005831350efd633909"
                          "f476c45c88253276d9fd0df6ef48609e8bb7dca8".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"18a2e1d81b8ecfb2a333adcb0c17a5b9eb76cc5d05db91a4".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"board blade invite damage undo sun mimic interest slam gaze truly inherit resist great "
                          "inject rocket museum chief", @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"f84521c777a13b61564234bf8f8b62b3afce27fc4062b51bb5e62bdfecb23864ee6ecf07c1d5a97c0834307c"
                          "5c852d8ceb88e7c97923c0a3b496bedd4e5f88a9".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    d = @"15da872c95a13dd738fbf50e427583ad61f18fd99f628c417a61cf8343c90419".hexToData;
    s = [m encodePhrase:d];
    k = [m deriveKeyFromPhrase:s withPassphrase:@"TREZOR"];
    XCTAssertEqualObjects(d, [m decodePhrase:s], @"[BRBIP39Mnemonic decodePhrase:]");
    XCTAssertEqualObjects(s, @"beyond stage sleep clip because twist token leaf atom beauty genius food business side "
                          "grid unable middle armed observe pair crouch tonight away coconut",
                          @"[BRBIP39Mnemonic encodePhrase:]");
    XCTAssertEqualObjects(k, @"b15509eaa2d09d3efd3e006ef42151b30367dc6e3aa5e44caba3fe4d3e352e65101fbdb86a96776b91946ff0"
                          "6f8eac594dc6ee1d3e82a42dfe1b40fef6bcc3fd".hexToData,
                          @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");

    NSString *words_nfkd = @"Pr\u030ci\u0301s\u030cerne\u030c z\u030clut\u030couc\u030cky\u0301 ku\u030an\u030c "
                           "u\u0301pe\u030cl d\u030ca\u0301belske\u0301 o\u0301dy za\u0301ker\u030cny\u0301 "
                           "uc\u030cen\u030c be\u030cz\u030ci\u0301 pode\u0301l zo\u0301ny u\u0301lu\u030a";
    NSString *words_nfc = @"P\u0159\u00ed\u0161ern\u011b \u017elu\u0165ou\u010dk\u00fd k\u016f\u0148 \u00fap\u011bl "
                          "\u010f\u00e1belsk\u00e9 \u00f3dy z\u00e1ke\u0159n\u00fd u\u010de\u0148 b\u011b\u017e\u00ed "
                          "pod\u00e9l z\u00f3ny \u00fal\u016f";
    NSString *words_nfkc = @"P\u0159\u00ed\u0161ern\u011b \u017elu\u0165ou\u010dk\u00fd k\u016f\u0148 \u00fap\u011bl "
                           "\u010f\u00e1belsk\u00e9 \u00f3dy z\u00e1ke\u0159n\u00fd u\u010de\u0148 b\u011b\u017e\u00ed "
                           "pod\u00e9l z\u00f3ny \u00fal\u016f";
    NSString *words_nfd = @"Pr\u030ci\u0301s\u030cerne\u030c z\u030clut\u030couc\u030cky\u0301 ku\u030an\u030c "
                          "u\u0301pe\u030cl d\u030ca\u0301belske\u0301 o\u0301dy za\u0301ker\u030cny\u0301 "
                          "uc\u030cen\u030c be\u030cz\u030ci\u0301 pode\u0301l zo\u0301ny u\u0301lu\u030a";
    NSString *passphrase_nfkd = @"Neuve\u030cr\u030citelne\u030c bezpec\u030cne\u0301 hesli\u0301c\u030cko";
    NSString *passphrase_nfc = @"Neuv\u011b\u0159iteln\u011b bezpe\u010dn\u00e9 hesl\u00ed\u010dko";
    NSString *passphrase_nfkc = @"Neuv\u011b\u0159iteln\u011b bezpe\u010dn\u00e9 hesl\u00ed\u010dko";
    NSString *passphrase_nfd = @"Neuve\u030cr\u030citelne\u030c bezpec\u030cne\u0301 hesli\u0301c\u030cko";
    NSData *seed_nfkd = [m deriveKeyFromPhrase:words_nfkd withPassphrase:passphrase_nfkd];
    NSData *seed_nfc = [m deriveKeyFromPhrase:words_nfc withPassphrase:passphrase_nfc];
    NSData *seed_nfkc = [m deriveKeyFromPhrase:words_nfkc withPassphrase:passphrase_nfkc];
    NSData *seed_nfd = [m deriveKeyFromPhrase:words_nfd withPassphrase:passphrase_nfd];

    // test multiple different unicode representations of the same phrase
    XCTAssertEqualObjects(seed_nfkd, seed_nfc, @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");
    XCTAssertEqualObjects(seed_nfkd, seed_nfkc, @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");
    XCTAssertEqualObjects(seed_nfkd, seed_nfd, @"[BRBIP39Mnemonic deriveKeyFromPhrase: withPassphrase:]");
}

#pragma mark - testBIP32Sequence

#if ! BITCOIN_TESTNET
- (void)testBIP32SequencePrivateKey
{
    BRBIP32Sequence *seq = [BRBIP32Sequence new];
    NSData *seed = @"000102030405060708090a0b0c0d0e0f".hexToData;
    NSString *pk = [seq privateKey:2 | 0x80000000 internal:YES fromSeed:seed];
    NSData *d = pk.base58checkToData;

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/1/2' prv = %@", [NSString hexWithData:d]);


    XCTAssertEqualObjects(d, @"80cbce0d719ecf7431d88e6a89fa1483e02e35092af60c042b1df2ff59fa424dca01".hexToData,
                         @"[BRBIP32Sequence privateKey:internal:fromSeed:]");

    // Test for correct zero padding of private keys, a nasty potential bug
    pk = [seq privateKey:97 internal:NO fromSeed:seed];
    d = pk.base58checkToData;

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/0/97 prv = %@", [NSString hexWithData:d]);

    XCTAssertEqualObjects(d, @"8000136c1ad038f9a00871895322a487ed14f1cdc4d22ad351cfa1a0d235975dd701".hexToData,
                         @"[BRBIP32Sequence privateKey:internal:fromSeed:]");
}
#endif

- (void)testBIP32SequenceMasterPublicKeyFromSeed
{
    BRBIP32Sequence *seq = [BRBIP32Sequence new];
    NSData *seed = @"000102030405060708090a0b0c0d0e0f".hexToData;
    NSData *mpk = [seq masterPublicKeyFromSeed:seed];
    
    NSLog(@"000102030405060708090a0b0c0d0e0f/0' pub+chain = %@", [NSString hexWithData:mpk]);
    
    XCTAssertEqualObjects(mpk, @"3442193e"
                               "47fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141"
                               "035a784662a4a20a65bf6aab9ae98a6c068a81c52e4b032c0fb5400c706cfccc56".hexToData,
                         @"[BRBIP32Sequence masterPublicKeyFromSeed:]");
}

- (void)testBIP32SequencePublicKey
{
    BRBIP32Sequence *seq = [BRBIP32Sequence new];
    NSData *seed = @"000102030405060708090a0b0c0d0e0f".hexToData;
    NSData *mpk = [seq masterPublicKeyFromSeed:seed];
    NSData *pub = [seq publicKey:0 internal:NO masterPublicKey:mpk];

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/0/0 pub = %@", [NSString hexWithData:pub]);
    
    XCTAssertEqualObjects(pub, @"027b6a7dd645507d775215a9035be06700e1ed8c541da9351b4bd14bd50ab61428".hexToData,
                          @"[BRBIP32Sequence publicKey:internal:masterPublicKey:]");
}

#if ! BITCOIN_TESTNET
- (void)testBIP32SequenceBitIdPrivateKey
{
    BRBIP32Sequence *seq = [BRBIP32Sequence new];
    NSData *seed = [[BRBIP39Mnemonic new]
                    deriveKeyFromPhrase:@"inhale praise target steak garlic cricket paper better evil almost sadness "
                    "crawl city banner amused fringe fox insect roast aunt prefer hollow basic ladder"
                    withPassphrase:nil];
    NSString *privKey = [seq bitIdPrivateKey:0 forURI:@"http://bitid.bitcoin.blue/callback" fromSeed:seed];
    NSString *addr = [BRKey keyWithPrivateKey:privKey].address;

    XCTAssertEqualObjects(addr, @"1J34vj4wowwPYafbeibZGht3zy3qERoUM1");
}
#endif

- (void)testBIP32SequenceSerializedPrivateMasterFromSeed
{
    BRBIP32Sequence *seq = [BRBIP32Sequence new];
    NSData *seed = @"000102030405060708090a0b0c0d0e0f".hexToData;
    NSString *xprv = [seq serializedPrivateMasterFromSeed:seed];
    
    NSLog(@"000102030405060708090a0b0c0d0e0f xpriv = %@", xprv);
    
    XCTAssertEqualObjects(xprv,
     @"xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi",
                         @"[BRBIP32Sequence serializedPrivateMasterFromSeed:]");
}

- (void)testBIP32SequenceSerializedMasterPublicKey
{
    BRBIP32Sequence *seq = [BRBIP32Sequence new];
    NSData *seed = @"000102030405060708090a0b0c0d0e0f".hexToData;
    NSData *mpk = [seq masterPublicKeyFromSeed:seed];
    NSString *xpub = [seq serializedMasterPublicKey:mpk];
    
    NSLog(@"000102030405060708090a0b0c0d0e0f xpub = %@", xpub);
    
    XCTAssertEqualObjects(xpub,
     @"xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw",
                         @"[BRBIP32Sequence serializedMasterPublicKey:]");
}

#pragma mark - testWallet

//TODO: test standard free transaction no change
//TODO: test free transaction who's inputs are too new to hit min free priority
//TODO: test transaction with change below min allowable output
//TODO: test gap limit with gaps in address chain less than the limit
//TODO: test removing a transaction that other transansactions depend on
//TODO: test tx ordering for multiple tx with same block height
//TODO: port all applicable tests from bitcoinj and bitcoincore

- (void)testWallet
{
    NSMutableData *script = [NSMutableData data];
    UInt256 secret = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    BRKey *k = [BRKey keyWithSecret:secret compressed:YES];
    NSValue *hash = uint256_obj(UINT256_ZERO);
    BRWallet *w = [[BRWallet alloc] initWithContext:nil sequence:[BRBIP32Sequence new] masterPublicKey:nil
                   seed:^NSData *(NSString *authprompt, uint64_t amount) { return [NSData data]; }];

    [script appendScriptPubKeyForAddress:k.address];

    BRTransaction *tx = [[BRTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@(0)] inputScripts:@[script]
                         outputAddresses:@[w.receiveAddress] outputAmounts:@[@(SATOSHIS)]];

    [tx signWithPrivateKeys:@[k.privateKey]];
    [w registerTransaction:tx];

    XCTAssertEqual(w.balance, SATOSHIS, @"[BRWallet registerTransaction]");

    tx = [BRTransaction new];
    [tx addInputHash:UINT256_ZERO index:2 script:script signature:NULL sequence:UINT32_MAX - 1];
    [tx addOutputAddress:w.receiveAddress amount:SATOSHIS];
    tx.lockTime = 1000;
    tx.blockHeight = TX_UNCONFIRMED;
    [tx signWithPrivateKeys:@[k.privateKey]];
    [w registerTransaction:tx]; // test pending tx with future lockTime

    XCTAssertEqual(w.balance, SATOSHIS, @"[BRWallet registerTransaction]");

    [w setBlockHeight:1000 andTimestamp:1 forTxHashes:@[uint256_obj(tx.txHash)]];
    XCTAssertEqual(w.balance, SATOSHIS*2, @"[BRWallet registerTransaction]");

    tx = [w transactionFor:SATOSHIS/2 to:k.address withFee:NO];

    XCTAssertNotNil(tx, @"[BRWallet transactionFor:to:withFee:]");

    [w signTransaction:tx withPrompt:@""];

    XCTAssertTrue(tx.isSigned, @"[BRWallet signTransaction]");

    [w registerTransaction:tx];

    XCTAssertEqual(w.balance, SATOSHIS*3/2, @"[BRWallet balance]");

#if ! BITCOIN_TESTNET
    w = [[BRWallet alloc] initWithContext:nil sequence:[BRBIP32Sequence new] masterPublicKey:nil
         seed:^NSData *(NSString *authprompt, uint64_t amount) { return [NSData data]; }];
    
    NSMutableSet *allAddresses = (id)w.addresses;

    [allAddresses addObject:@"1DjJGdMuW6UKunUS3jAuaEcqZ2mkH1QNHc"];
    [allAddresses addObject:@"1P5hsxGtGYEftqcP7gY63pKX7JXCfLCNiR"];
    [allAddresses addObject:@"1htJNo75xgfHUYA7ag8hRMjwg5mREfkD7"];
    [allAddresses addObject:@"19UZQkmaH4PqE99t5bPgA83HeXJAkoogKE"];
    [allAddresses addObject:@"18fPNnWxGhytebu2or4c2tFcnkXVeB2aL6"];
    [allAddresses addObject:@"16XP5vHKm2qnQHAGpmUBCwzGVxamDbGQ5N"];
    [allAddresses addObject:@"1DieDrnPmjv4TfxXukZTKsm32PgFfwKcFA"];

    [w registerTransaction:[BRTransaction transactionWithMessage:@"0100000001932bcd947e72ed69b813a7afc6a75a97bc60a26e45"
     "e2635ca6b5b619cf650d84010000006a4730440220697f9338ecc869361094bc6ab5243cbf683a84e3f424599e3b2961dd33e018f602202a6"
     "190a65b7ac42c9a907823e11e28991c01dd1bda7081bc99191c8304481c5501210235c032e32c490055212aecba58526a68f2ce3d0e53388c"
     "e01efe1764214f52dbffffffff02a0860100000000001976a914b1cedc0e005cb1e929e18b14a2cbb481d4b7e65d88aca0ad3900000000001"
     "976a9148ba16545a88d500197281540541299394194a17a88ac00000000".hexToData]];
    [w registerTransaction:[BRTransaction transactionWithMessage:@"0100000001669313d613ee6b9e31252b7d4160ab821ab21cf059"
     "b7d7b8a5b4c29ebba45d30000000006b483045022100e1e314053d86aff56b4bda7aab3b650732e7d8da6e79f7ab23c1fc4523c44f0d02202"
     "a55fce6cad078ac801626fcd42c40ff43692ade3fe14cfb97f685c070dfe9ea012102ce4f2739e0acf7e6c2eb5babf6cc62d44e5de70ba1a5"
     "9274af86bd5c1c9fa404ffffffff01301b0f00000000001976a914f2368e03acc87480f355dd917baca95e5d19e74d88ac00000000"
     "".hexToData]];
    [w registerTransaction:[BRTransaction transactionWithMessage:@"01000000011000b4ec5446e9d45c04fec06774468d003db4f662"
     "0df256a22ffd6d79883688000000008a473044022022afda9e3a3589c9b286f0c6a989374f59b8c217e0de127bec612265a2b0749b022050f"
     "dc59045592eae7aad218d0f2ac14a7f410a9195018ceecb50e6fc92060526014104a3be6b242cfbef34e63002f304eceb058fdc36797241c3"
     "78b06fa44573e5307031cf1a4c3a1caeac128abfedd169f02db1e795788d27ff44a81a32c50645ab7cffffffff01d06c0400000000001976a"
     "91407bb76119e91184e49882b168e5c785ecefb5b2488ac00000000".hexToData]];
    [w registerTransaction:[BRTransaction transactionWithMessage:@"010000000104c58782c504726fa26c26b23d6cae4715311fb6db"
     "d9ff494f5868cc0686948b010000008a47304402207643b8852c93e425d5a41b8e6e9126cce85115fe99310b680b86c69852dd386e0220691"
     "da90f76fb4ee9519edf2afe4aa0f04d44529bf8602b00c4f31aad7d631d37014104126989db35c5088c021ef16a0d67b1cda7dac2dee20144"
     "ff95b543b449788e5a66c6f314981dd0baffaa5057d5b972e4fb274e2799d6bae796ed2c29be97c574ffffffff0280969800000000001976a"
     "9145cf74a97cf524c5b99a6ec29f3ab3ed4b436592988ac49981700000000001976a9148e022fdce38b1d22fb5bfe89d3e8256c650f246988"
     "ac00000000".hexToData]];
    [w registerTransaction:[BRTransaction transactionWithMessage:@"01000000011000b4ec5446e9d45c04fec06774468d003db4f662"
     "0df256a22ffd6d79883688010000008b483045022100d77a298b3126b347d1576e301ba7a6ca0610124f2cb0cc47b58254cb66cbd00302205"
     "3708a6c858dfb35a65b57381fec99e5797c33cc7d66d220469564303a62dc8a014104a331cd33c13ba323e549fdefa11af1f03f86a44a4f2e"
     "e0883fab39d96bf9c147940afe36e2ddf6ebbef5e8a57a931d5f854abcc27b33d1ba7f424647202a7ee2ffffffff0240420f0000000000197"
     "6a914540b5d80a4d05a2cf7035bbca524f68ef93cf79688ac60926200000000001976a914bf49bd44526f6ab157275aa938df9479bfecf003"
     "88ac00000000".hexToData]];
    [w registerTransaction:[BRTransaction transactionWithMessage:@"0100000002f6d5012856206e93341a40b19afb86caabe9964753"
     "99b77d3695f484ec6fb1d4000000006b483045022100d0f7d86aea22a4fe23bb3b5de29e56983faa9fdf60052a0d8321212ca972336502201"
     "09b11f128e24a2d3dc615ddf2124bb2d1e7506a80a944bafa5ebdf965043982012102fe5d33b9a5fe9c8799d6f8ad0cf92bd477620dd299c5"
     "62c812295dcb6d66f6b4ffffffffe9c01e3b016c95729b13fa5db25412c89a555223f6d4378c3b65898e5b3ca8dd000000006b48304502210"
     "092e5b28aea395ca4a916067ac18f30a9616d6cf827158e80126a657152226165022043cb34077eaf4ec01727eeb038b0b297da0c5580beb1"
     "11b999949c36ba53d12301210382efead48069b88d35ea13e0e80f19eda6c08191f1ce668a77c8d210c5791ffeffffffff0240420f0000000"
     "0001976a914faaaeb7f7e534ee2e18c3f15a3191dd51c36a93688ac5f700c00000000001976a9143c978b11b19d0718b4a847304340b3804d"
     "5194a388ac00000000".hexToData]];
    [w registerTransaction:[BRTransaction transactionWithMessage:@"01000000027560f62fa95ecdb9eb0bf200764b8eff99c717918c"
     "743314fe1e7d4dc9899cc8010000008a47304402203e2c3beb755fe868728896482aaa197f10c4bad9749e9f4d9e607acd23726b9602202bb"
     "0eca3031ee8c750a6688f02b422275b0b02f4353c3e9526905e297c7e2ca801410429c3b9fa9ec9aea0918ccc00c08a814f13bdd2e72273b6"
     "2b046605f8daa8b559b2aec4706caa15b914897ea3be4ba3b200aeca22f16ed882836cad0bdf9c282affffffff8b10474e40d60efc2612614"
     "97ed6d46d38e5219fce122c1ba2b0bc645342fef3000000008a47304402202990aa1fcbb519bf6edd798f6290930bd8c0e8e6185153af0b90"
     "ed64249302c20220419a07a674753778ab2198f37f43b2c7f7c3ef2aac8b685090e30484a366cf960141049b3707c1b05412511a75eaa39b2"
     "56bc7e958539e66fd02b291199df0408c62bbe70a093560cc408e52fac7ee74ed650c5f8c70b85ccc9a2ab853164d1d2a4bd3ffffffff0240"
     "548900000000001976a9148b81a28bc33e75484783475aed1f1e78ac4c084788acbe040300000000001976a9146a5af3e825f69bec5089b42"
     "f54c389c19673ba8488ac00000000".hexToData]];

    // larger than 1k transaction
    tx = [w transactionFor:25000000 to:@"16c7nyuu2D99LqJ8TQ8GSsWSyrCYDS5qBA" withFee:YES];
    NSLog(@"fee: %llu, should be %llu", [w feeForTransaction:tx], [w feeForTxSize:tx.size + 1965]);

    int64_t amount = [w amountReceivedFromTransaction:tx] - [w amountSentByTransaction:tx],
            fee = [w feeForTxSize:tx.size + 1965] + ((w.balance - 25000000) % 100);

    XCTAssertEqual([w feeForTransaction:tx], fee, @"[BRWallet transactionFor:to:withFee:]");
    XCTAssertEqual(amount, -25000000 - fee);
#endif

    XCTAssertEqual([w feeForTxSize:tx.size], tx.standardFee, @"[BRWallet feeForTxSize:]");
}

#pragma mark - testWalletManager

- (void)testWalletManager
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSString *s;
    
    XCTAssertEqual([manager amountForString:nil], 0, @"[BRWalletManager amountForString:]");
    
    XCTAssertEqual([manager amountForString:@""], 0, @"[BRWalletManager amountForString:]");

    s = [manager stringForAmount:0];
    XCTAssertEqual([manager amountForString:s], 0, @"[BRWalletManager amountForString:]");
    
    s = [manager stringForAmount:100000000];
    XCTAssertEqual([manager amountForString:s], 100000000, @"[BRWalletManager amountForString:]");

    s = [manager stringForAmount:1];
    XCTAssertEqual([manager amountForString:s], 1, @"[BRWalletManager amountForString:]");
    
    s = [manager stringForAmount:2100000000000000];
    XCTAssertEqual([manager amountForString:s], 2100000000000000, @"[BRWalletManager amountForString:]");
    
    s = [manager stringForAmount:2099999999999999];
    XCTAssertEqual([manager amountForString:s], 2099999999999999, @"[BRWalletManager amountForString:]");
    
    s = [manager stringForAmount:2099999999999995];
    XCTAssertEqual([manager amountForString:s], 2099999999999995, @"[BRWalletManager amountForString:]");
    
    s = [manager stringForAmount:2099999999999990];
    XCTAssertEqual([manager amountForString:s], 2099999999999990, @"[BRWalletManager amountForString:]");
}

#pragma mark - testBloomFilter

- (void)testBloomFilter
{
    BRBloomFilter *f = [[BRBloomFilter alloc] initWithFalsePositiveRate:.01 forElementCount:3 tweak:0
                        flags:BLOOM_UPDATE_ALL];

    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData];

    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                 @"[BRBloomFilter containsData:]");

    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                  @"[BRBloomFilter containsData:]");

    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData];

    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData],
                 @"[BRBloomFilter containsData:]");

    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData];

    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData],
                 @"[BRBloomFilter containsData:]");

    // check against satoshi client output
    XCTAssertEqualObjects(@"03614e9b050000000000000001".hexToData, f.data, @"[BRBloomFilter data:]");
}

- (void)testBloomFilterWithTweak
{
    BRBloomFilter *f = [[BRBloomFilter alloc] initWithFalsePositiveRate:.01 forElementCount:3 tweak:2147483649
                        flags:BLOOM_UPDATE_P2PUBKEY_ONLY];

    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData];
    
    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                 @"[BRBloomFilter containsData:]");
    
    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                  @"[BRBloomFilter containsData:]");
    
    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData];
    
    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData],
                 @"[BRBloomFilter containsData:]");
    
    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData];
    
    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData],
                 @"[BRBloomFilter containsData:]");

    // check against satoshi client output
    XCTAssertEqualObjects(@"03ce4299050000000100008002".hexToData, f.data, @"[BRBloomFilter data:]");
}

#pragma mark - testMerkleBlock

- (void)testMerkleBlock
{
    // block 10001 filtered to include only transactions 0, 1, 2, and 6
    NSData *block = @"0100000006e533fd1ada86391f3f6c343204b0d278d4aaec1c0b20aa27ba0300000000006abbb3eb3d733a9fe18967fd7"
                     "d4c117e4ccbbac5bec4d910d900b3ae0793e77f54241b4d4c86041b4089cc9b0c000000084c30b63cfcdc2d35e3329421"
                     "b9805ef0c6565d35381ca857762ea0b3a5a128bbca5065ff9617cbcba45eb23726df6498a9b9cafed4f54cbab9d227b00"
                     "35ddefbbb15ac1d57d0182aaee61c74743a9c4f785895e563909bafec45c9a2b0ff3181d77706be8b1dcc91112eada86d"
                     "424e2d0a8907c3488b6e44fda5a74a25cbc7d6bb4fa04245f4ac8a1a571d5537eac24adca1454d65eda446055479af6c6"
                     "d4dd3c9ab658448c10b6921b7a4ce3021eb22ed6bb6a7fde1e5bcc4b1db6615c6abc5ca042127bfaf9f44ebce29cb29c6"
                     "df9d05b47f35b2edff4f0064b578ab741fa78276222651209fe1a2c4c0fa1c58510aec8b090dd1eb1f82f9d261b8273b5"
                     "25b02ff1a".hexToData;
    BRMerkleBlock *b = [BRMerkleBlock blockWithMessage:block];
    UInt256 hash;
    
    hash = *(UInt256 *)@"00000000000080b66c911bd5ba14a74260057311eaeb1982802f7010f1a9f090".hexToData.reverse.bytes;
    XCTAssertTrue(uint256_eq(b.blockHash, hash), @"[BRMerkleBlock blockHash]");

    XCTAssertEqualObjects(block, b.data, @"[BRMerkleBlock toData]");

    XCTAssertTrue(b.valid, @"[BRMerkleBlock isValid]");

    hash = *(UInt256 *)@"4c30b63cfcdc2d35e3329421b9805ef0c6565d35381ca857762ea0b3a5a128bb".hexToData.bytes;
    XCTAssertTrue([b containsTxHash:hash], @"[BRMerkleBlock containsTxHash:]");

    XCTAssertTrue(b.txHashes.count == 4, @"[BRMerkleBlock txHashes]");

    hash = *(UInt256 *)@"4c30b63cfcdc2d35e3329421b9805ef0c6565d35381ca857762ea0b3a5a128bb".hexToData.bytes;
    XCTAssertEqualObjects(b.txHashes[0], uint256_obj(hash), @"[BRMerkleBlock txHashes]");

    hash = *(UInt256 *)@"ca5065ff9617cbcba45eb23726df6498a9b9cafed4f54cbab9d227b0035ddefb".hexToData.bytes;
    XCTAssertEqualObjects(b.txHashes[1], uint256_obj(hash), @"[BRMerkleBlock txHashes]");

    hash = *(UInt256 *)@"bb15ac1d57d0182aaee61c74743a9c4f785895e563909bafec45c9a2b0ff3181".hexToData.bytes;
    XCTAssertEqualObjects(b.txHashes[2], uint256_obj(hash), @"[BRMerkleBlock txHashes]");

    hash = *(UInt256 *)@"c9ab658448c10b6921b7a4ce3021eb22ed6bb6a7fde1e5bcc4b1db6615c6abc5".hexToData.bytes;
    XCTAssertEqualObjects(b.txHashes[3], uint256_obj(hash), @"[BRMerkleBlock txHashes]");
    
    //TODO: test a block with an odd number of tree rows both at the tx level and merkle node level
    
    //TODO:XXXX test verifyDifficultyFromPreviousBlock
}

#pragma mark - testPaymentProtocol

- (void)testPaymentProtocol
{
    NSData *d =
        @"0801120b783530392b7368613235361ab81d0ac90b308205c5308204ada00302010202072b858c53eeed2f300d06092a864886f70d010"
        "10505003081ca310b30090603550406130255533110300e060355040813074172697a6f6e61311330110603550407130a53636f7474736"
        "4616c65311a3018060355040a1311476f44616464792e636f6d2c20496e632e31333031060355040b132a687474703a2f2f63657274696"
        "66963617465732e676f64616464792e636f6d2f7265706f7369746f72793130302e06035504031327476f2044616464792053656375726"
        "52043657274696669636174696f6e20417574686f726974793111300f060355040513083037393639323837301e170d313330343235313"
        "9313130305a170d3135303432353139313130305a3081be31133011060b2b0601040182373c0201031302555331193017060b2b0601040"
        "182373c020102130844656c6177617265311d301b060355040f131450726976617465204f7267616e697a6174696f6e3110300e0603550"
        "405130735313633393636310b30090603550406130255533110300e0603550408130747656f726769613110300e0603550407130741746"
        "c616e746131153013060355040a130c4269745061792c20496e632e311330110603550403130a6269747061792e636f6d30820122300d0"
        "6092a864886f70d01010105000382010f003082010a0282010100c46eefc28b157d03717f0c00a1d67ba7612c1f2b562182ce99602c476"
        "8ff8fbd106685d939263266bb9e107d057db844502d8ec61e887ea55b55c2c17121896454a319f65b3db34c8629a75b3e123fe2076d85c"
        "f4f644ae3f6fb8429c5a7830df465859c4d6c0bcdbc12865fab2218bd65f2b2530012ce499698ccae0259ac0b3470a8566b705e1a661ad"
        "8286429acf0b3136e4cdf4d9119084a5b6ecf197694c2b55782701211ca28dafa6d96acecc2232ac5e9a86181d4f7417fd8d938507f6d0"
        "c6252940216300946f7627013d74998e0922d4b9c97a7779b1d56f30c07d0269b1589bd604d384a5237213c75d0c6bf811bce8cdbbb06c"
        "1a2c6e479d271fd0203010001a38201b8308201b4300f0603551d130101ff04053003010100301d0603551d250416301406082b0601050"
        "507030106082b06010505070302300e0603551d0f0101ff0404030205a030330603551d1f042c302a3028a026a0248622687474703a2f2"
        "f63726c2e676f64616464792e636f6d2f676473332d37322e63726c30530603551d20044c304a3048060b6086480186fd6d01071703303"
        "9303706082b06010505070201162b687474703a2f2f6365727469666963617465732e676f64616464792e636f6d2f7265706f7369746f7"
        "2792f30818006082b0601050507010104743072302406082b060105050730018618687474703a2f2f6f6373702e676f64616464792e636"
        "f6d2f304a06082b06010505073002863e687474703a2f2f6365727469666963617465732e676f64616464792e636f6d2f7265706f73697"
        "46f72792f67645f696e7465726d6564696174652e637274301f0603551d23041830168014fdac6132936c45d6e2ee855f9abae7769968c"
        "ce730250603551d11041e301c820a6269747061792e636f6d820e7777772e6269747061792e636f6d301d0603551d0e04160414b941175"
        "67ae7c3ef507282acc4d551c6bf7fa44a300d06092a864886f70d01010505000382010100b8d5aca963a6f9a0b5c5af034acc832a13f1b"
        "beb932d397a7d4bd3a45e6a3d6db3109a2354a80814ee3e6c7ceff5d7f4a983dbde55f096ba992d0fff4fe1a92eaab79bd147b3521ee36"
        "12cee2cf7595bc635a1feefc6db5c583a5923c71c864ddacbcff463e9967f4c02bdd77271635575967ec23e8b6cdbdab632ce79072f477"
        "04a6ef1f160310837de456e4a01a22bbf89d8e0f5267dfb71998ade3ea260dc9bc6cff3899a88caf6a5e0ea7497ffbc42ed4fa69551e5e"
        "0b2156e9e2d225ba7a5e56de5ff130a4c6e5f1a9968687b82620f861702d56c4429799fff9db2562bc2dce97fe7e34a1fabb039e5e78bd"
        "4dae60f5868a5e8a3f8c330e37f38fbfe1f0ae209308204de308203c6a00302010202020301300d06092a864886f70d010105050030633"
        "10b30090603550406130255533121301f060355040a131854686520476f2044616464792047726f75702c20496e632e3131302f0603550"
        "40b1328476f20446164647920436c61737320322043657274696669636174696f6e20417574686f72697479301e170d303631313136303"
        "1353433375a170d3236313131363031353433375a3081ca310b30090603550406130255533110300e060355040813074172697a6f6e613"
        "11330110603550407130a53636f74747364616c65311a3018060355040a1311476f44616464792e636f6d2c20496e632e3133303106035"
        "5040b132a687474703a2f2f6365727469666963617465732e676f64616464792e636f6d2f7265706f7369746f72793130302e060355040"
        "31327476f204461646479205365637572652043657274696669636174696f6e20417574686f726974793111300f0603550405130830373"
        "9363932383730820122300d06092a864886f70d01010105000382010f003082010a0282010100c42dd5158c9c264cec3235eb5fb859015"
        "aa66181593b7063abe3dc3dc72ab8c933d379e43aed3c3023848eb33014b6b287c33d9554049edf99dd0b251e21de65297e35a8a954ebf"
        "6f73239d4265595adeffbfe5886d79ef4008d8c2a0cbd4204cea73f04f6ee80f2aaef52a16966dabe1aad5dda2c66ea1a6bbbe51a514a0"
        "02f48c79875d8b929c8eef8666d0a9cb3f3fc787ca2f8a3f2b5c3f3b97a91c1a7e6252e9ca8ed12656e6af6124453703095c39c2b582b3"
        "d08744af2be51b0bf87d04c27586bb535c59daf1731f80b8feead813605890898cf3aaf2587c049eaa7fd67f7458e97cc1439e23685b57"
        "e1a37fd16f671119a743016fe1394a33f840d4f0203010001a38201323082012e301d0603551d0e04160414fdac6132936c45d6e2ee855"
        "f9abae7769968cce7301f0603551d23041830168014d2c4b0d291d44c1171b361cb3da1fedda86ad4e330120603551d130101ff0408300"
        "60101ff020100303306082b0601050507010104273025302306082b060105050730018617687474703a2f2f6f6373702e676f646164647"
        "92e636f6d30460603551d1f043f303d303ba039a0378635687474703a2f2f6365727469666963617465732e676f64616464792e636f6d2"
        "f7265706f7369746f72792f6764726f6f742e63726c304b0603551d200444304230400604551d20003038303606082b060105050702011"
        "62a687474703a2f2f6365727469666963617465732e676f64616464792e636f6d2f7265706f7369746f7279300e0603551d0f0101ff040"
        "403020106300d06092a864886f70d01010505000382010100d286c0ecbdf9a1b667ee660ba2063a04508e1572ac4a749553cb37cb4449e"
        "f07906b33d996f09456a51330053c8532217bc9c70aa824a490de46d32523140367c210d66f0f5d7b7acc9fc5582ac1c49e21a85af3aca"
        "446f39ee463cb2f90a4292901d9722c29df370127bc4fee68d3218fc0b3e4f509edd210aa53b4bef0cc590bd63b961c952449dfceecfda"
        "7489114450e3a366fda45b345a241c9d4d7444e3eb97476d5a213552cc687a3b599ac0684877f7506fcbf144c0ecc6ec4df3db71271f4e"
        "8f15140222849e01d4b87a834cc06a2dd125ad186366403356f6f776eebf28550985eab0353ad9123631f169ccdb9b205633ae1f4681b1"
        "705359553ee0a840830820400308202e8a003020102020100300d06092a864886f70d01010505003063310b30090603550406130255533"
        "121301f060355040a131854686520476f2044616464792047726f75702c20496e632e3131302f060355040b1328476f204461646479204"
        "36c61737320322043657274696669636174696f6e20417574686f72697479301e170d3034303632393137303632305a170d33343036323"
        "93137303632305a3063310b30090603550406130255533121301f060355040a131854686520476f2044616464792047726f75702c20496"
        "e632e3131302f060355040b1328476f20446164647920436c61737320322043657274696669636174696f6e20417574686f72697479308"
        "20120300d06092a864886f70d01010105000382010d00308201080282010100de9dd7ea571849a15bebd75f4886eabeddffe4ef671cf46"
        "568b35771a05e77bbed9b49e970803d561863086fdaf2ccd03f7f0254225410d8b281d4c0753d4b7fc777c33e78ab1a03b5206b2f6a2bb"
        "1c5887ec4bb1eb0c1d845276faa3758f78726d7d82df6a917b71f72364ea6173f659892db2a6e5da2fe88e00bde7fe58d15e1ebcb3ad5e"
        "212a2132dd88eaf5f123da0080508b65ca565380445991ea3606074c541a572621b62c51f6f5f1a42be025165a8ae23186afc7803a94d7"
        "f80c3faab5afca140a4ca1916feb2c8ef5e730dee77bd9af67998bcb10767a2150ddda058c6447b0a3e62285fba41075358cf117e3874c"
        "5f8ffb569908f8474ea971baf020103a381c03081bd301d0603551d0e04160414d2c4b0d291d44c1171b361cb3da1fedda86ad4e330818"
        "d0603551d230481853081828014d2c4b0d291d44c1171b361cb3da1fedda86ad4e3a167a4653063310b300906035504061302555331213"
        "01f060355040a131854686520476f2044616464792047726f75702c20496e632e3131302f060355040b1328476f20446164647920436c6"
        "1737320322043657274696669636174696f6e20417574686f72697479820100300c0603551d13040530030101ff300d06092a864886f70"
        "d01010505000382010100324bf3b2ca3e91fc12c6a1078c8e77a03306145c901e18f708a63d0a19f98780116e69e4961730ff349163723"
        "8eecc1c01a31d9428a431f67ac454d7f6e5315803a2ccce62db944573b5bf45c924b5d58202ad2379698db8b64dcecf4cca3323e81c88a"
        "a9d8b416e16c920e5899ecd3bda70f77e992620145425ab6e7385e69b219d0a6c820ea8f8c20cfa101e6c96ef870dc40f618badee832b9"
        "5f88e92847239eb20ea83ed83cd976e08bceb4e26b6732be4d3f64cfe2671e26111744aff571a870f75482ecf516917a002126195d5d14"
        "0b2104ceec4ac1043a6a59e0ad595629a0dcf8882c5320ce42b9f45e60d9f289cb1b92a5a57ad370faf1d7fdbbd9f229b010a046d61696"
        "e121f08e0b60d121976a914a533d4fa076634afef47451f6aec8cdc1e49daf088ac18eee1809b0520f2e8809b052a395061796d656e742"
        "07265717565737420666f722042697450617920696e766f696365203863583552624e38616f666335336157416d35584644322b6874747"
        "0733a2f2f6269747061792e636f6d2f692f3863583552624e38616f666335336157416d355846442a80025ef88bec4e09be979b0706647"
        "64afae4fa3b1eca954744a76699b18530183e6f467ec5923913668c5abe382cb7ef6a8858fae6180c478e81179d3935cd5323f0c5cc2ee"
        "a0f1e29b5a6b2654b4cbda389eaee32215c8777afbbe07d60a4f9fa07ab6e9a6d3ad2a9efb525221631c8044ec759d9c1fccc39bb3ee4f"
        "44ebc7c1cc8248341442722ac880da0c7d59d696706c7bcf09101b4925a0784220a93c5b309dad8e32661f2ccab4ec868b2de000f242db"
        "73fffb26937cf83ed6d2efaa771d2d2c697844b83948c98252b5f352edd4fe96b29cbe0c9ca3d107a3eb790dab5ddd73de6c748f2047db"
        "425c80c39135473cacad3619baaf28e391da4a6c7b82b74".hexToData;

    BRPaymentProtocolRequest *req = [BRPaymentProtocolRequest requestWithData:d];

    XCTAssertEqualObjects(req.data, d, @"[BRPaymentProtocolRequest toData]");

    // test that the x509 certs are valid, but the payment request is expired
    XCTAssertFalse([req isValid], @"[BRPaymentProtocolRequest isValid]");
    XCTAssertEqualObjects(req.errorMessage,
                          @"untrusted certificate - One or more certificates have expired or are not valid yet.",
                          @"[BRPaymentProtocolRequest isValid]");

    NSLog(@"commonName:%@", req.commonName);
    XCTAssertEqualObjects(req.commonName, @"bitpay.com",  @"[BRPaymentProtocolRequest commonName]");

    d = @"0a00125f5472616e73616374696f6e207265636569766564206279204269745061792e20496e766f6963652077696c6c206265206d617"
         "26b6564206173207061696420696620746865207472616e73616374696f6e20697320636f6e6669726d65642e".hexToData;

    BRPaymentProtocolACK *ack = [BRPaymentProtocolACK ackWithData:d];

    XCTAssertEqualObjects(ack.data, d, @"[BRPaymentProtocolACK toData]");

    NSLog(@"ack.memo = '%@'", ack.memo);
    XCTAssertNotNil(ack.memo, @"[BRPaymentProtocolACK memo]");
    
    d = @"120b783530392b7368613235361abe150afe0b308205fa308204e2a0030201020210090b35ca5c5bf1b98b3d8f9f4a7755d6300d06092"
        "a864886f70d01010b05003075310b300906035504061302555331153013060355040a130c446967694365727420496e633119301706035"
        "5040b13107777772e64696769636572742e636f6d313430320603550403132b4469676943657274205348413220457874656e646564205"
        "6616c69646174696f6e20536572766572204341301e170d3134303530393030303030305a170d3136303531333132303030305a3082010"
        "5311d301b060355040f0c1450726976617465204f7267616e697a6174696f6e31133011060b2b0601040182373c0201031302555331193"
        "017060b2b0601040182373c020102130844656c61776172653110300e0603550405130735313534333137310f300d06035504090c06233"
        "233303038311730150603550409130e353438204d61726b65742053742e310e300c060355041113053934313034310b300906035504061"
        "3025553311330110603550408130a43616c69666f726e6961311630140603550407130d53616e204672616e636973636f3117301506035"
        "5040a130e436f696e626173652c20496e632e311530130603550403130c636f696e626173652e636f6d30820122300d06092a864886f70"
        "d01010105000382010f003082010a0282010100b45e3ff380667aa14d5a12fc2fc983fc6618b55499933c3bde15c01d838846b4caf9848"
        "e7c40e5fa7c67ef9b5b1efe26ee5571c5fa2eff759052454701ad8931557d697b139e5d19abb3e439675f31db7f2ef1a5d97db07c1f696"
        "6266380eb4fcfa8e1471a6ecc2fbebf3e67b3eaa84d0fbe063e60380dcdb7a20203d29a94059ef7f20d472cc25783ab2a1db6a394ecc07"
        "b4024974100bcfd470f59ef3b572365213209609fad229994b4923c1df3a18c41e3e7bc1f192ba6e7e5c32ae155107e21903eff7bce9fc"
        "594b49d9f6ae7901fa191fcbae8a2cf09c3bfc24377d717b6010080c5681a7dbc6e1d52987b7ebbe95e7af4202da436e67a88472aacedc"
        "90203010001a38201f2308201ee301f0603551d230418301680143dd350a5d6a0adeef34a600a65d321d4f8f8d60f301d0603551d0e041"
        "604146d33b9743a61b7499423d1a89d085d0148680bba30290603551d1104223020820c636f696e626173652e636f6d82107777772e636"
        "f696e626173652e636f6d300e0603551d0f0101ff0404030205a0301d0603551d250416301406082b0601050507030106082b060105050"
        "7030230750603551d1f046e306c3034a032a030862e687474703a2f2f63726c332e64696769636572742e636f6d2f736861322d65762d7"
        "365727665722d67312e63726c3034a032a030862e687474703a2f2f63726c342e64696769636572742e636f6d2f736861322d65762d736"
        "5727665722d67312e63726c30420603551d20043b3039303706096086480186fd6c0201302a302806082b06010505070201161c6874747"
        "0733a2f2f7777772e64696769636572742e636f6d2f43505330818806082b06010505070101047c307a302406082b06010505073001861"
        "8687474703a2f2f6f6373702e64696769636572742e636f6d305206082b060105050730028646687474703a2f2f636163657274732e646"
        "96769636572742e636f6d2f446967694365727453484132457874656e64656456616c69646174696f6e53657276657243412e637274300"
        "c0603551d130101ff04023000300d06092a864886f70d01010b05000382010100aadfcf94050ed938e3114a640af3d9b04276da00f5215"
        "d7148f9f16d4cac0c77bd5349ec2f47299d03c900f70146752da72829290ac50a77992f01537ab2689392ce0bfeb7efa49f4c4fe4e1e43"
        "ca1fcfb1626ce554da4f6e7fa34a597e401f215c43afd0ba777ad587eb0afacd71f7a6af7752814f7ab4c202ed76d33defd1289d541803"
        "fed01ac80a3cacfdaae29279e5de14d460475f4baf27eab693379d39120e7477bf3ec719664c7b6cb5e557556e5bbddd9c9d1ebc9f835e"
        "9da5b3dbb72fe8d94ac05eab3c479987520ade3a1d275e1e2fe725698d2f7cb1390a9d40ea6cbf21a73bddccd1ad61aa249ce8e2885a37"
        "30b7d53bd075f55099d2960f3cc0aba09308204b63082039ea00302010202100c79a944b08c11952092615fe26b1d83300d06092a86488"
        "6f70d01010b0500306c310b300906035504061302555331153013060355040a130c446967694365727420496e6331193017060355040b1"
        "3107777772e64696769636572742e636f6d312b30290603550403132244696769436572742048696768204173737572616e63652045562"
        "0526f6f74204341301e170d3133313032323132303030305a170d3238313032323132303030305a3075310b30090603550406130255533"
        "1153013060355040a130c446967694365727420496e6331193017060355040b13107777772e64696769636572742e636f6d31343032060"
        "3550403132b4469676943657274205348413220457874656e6465642056616c69646174696f6e2053657276657220434130820122300d0"
        "6092a864886f70d01010105000382010f003082010a0282010100d753a40451f899a616484b6727aa9349d039ed0cb0b00087f16728868"
        "58c8e63dabcb14038e2d3f5eca50518b83d3ec5991732ec188cfaf10ca6642185cb071034b052882b1f689bd2b18f12b0b3d2e7881f1fe"
        "f387754535f80793f2e1aaaa81e4b2b0dabb763b935b77d14bc594bdf514ad2a1e20ce29082876aaeead764d69855e8fdaf1a506c54bc1"
        "1f2fd4af29dbb7f0ef4d5be8e16891255d8c07134eef6dc2decc48725868dd821e4b04d0c89dc392617ddf6d79485d80421709d6f6fff5"
        "cba19e145cb5657287e1c0d4157aab7b827bbb1e4fa2aef2123751aad2d9b86358c9c77b573add8942de4f30c9deec14e627e17c0719e2"
        "cdef1f9102819330203010001a38201493082014530120603551d130101ff040830060101ff020100300e0603551d0f0101ff040403020"
        "186301d0603551d250416301406082b0601050507030106082b06010505070302303406082b0601050507010104283026302406082b060"
        "105050730018618687474703a2f2f6f6373702e64696769636572742e636f6d304b0603551d1f044430423040a03ea03c863a687474703"
        "a2f2f63726c342e64696769636572742e636f6d2f4469676943657274486967684173737572616e63654556526f6f7443412e63726c303"
        "d0603551d200436303430320604551d2000302a302806082b06010505070201161c68747470733a2f2f7777772e64696769636572742e6"
        "36f6d2f435053301d0603551d0e041604143dd350a5d6a0adeef34a600a65d321d4f8f8d60f301f0603551d23041830168014b13ec3690"
        "3f8bf4701d498261a0802ef63642bc3300d06092a864886f70d01010b050003820101009db6d09086e18602edc5a0f0341c74c18d76cc8"
        "60aa8f04a8a42d63fc8a94dad7c08ade6b650b8a21a4d8807b12921dce7dac63c21e0e3114970ac7a1d01a4ca113a57ab7d572a4074fdd"
        "31d851850df574775a17d55202e473750728c7f821bd2628f2d035adac3c8a1ce2c52a20063eb73ba71c84927239764859e380ead63683"
        "cba52815879a32c0cdfde6deb31f2baa07c6cf12cd4e1bd77843703ce32b5c89a811a4a924e3b469a85fe83a2f99e8ca3cc0d5eb33dcf0"
        "4788f14147b329cc700a65cc4b5a1558d5a5668a42270aa3c8171d99da8453bf4e5f6a251ddc77b62e86f0c74ebb8daf8bf870d7950919"
        "09b183b915927f1352813ab267ed5f77a22b401121f0898b768121976a9147d5325a854f0c9a1cbb6cbfb89b2a96d837ed7bf88ac18acb"
        "9e09e0520d2bce09e052a315061796d656e74207265717565737420666f7220436f696e62617365206f7264657220636f64653a2051434"
        "f4947445041323068747470733a2f2f636f696e626173652e636f6d2f72702f35336438316266613564366231646461376230303030303"
        "43a2033363264323931393231373632313339323538373663653263623430303431622a80024d81ca72213813b2585d98005b238e268a0"
        "09ec02d04dd7a8a984832b990d740a96909d62a5df9f8f85b67329379bba0a9ba03bca3d61400d4e477984b7edcf3042261718423736c4"
        "41d140ee89d64609667de50eadb4cabbef478d3a9cbd4dfdab9a0c2818390d20c243ad02cc27abf0bbb2bab3227baa8e5d673f84991412"
        "253be1e69dfa780dc06b6f48edfa15de6d0ccec22d9faaf67b535e8b2778cdf6184da2f2d1792d34c6440988327329e9c5ae18c34dda16"
        "dcdfbf419f7fd27bf575b6f9c95b1f090021640af5c02ad027b5d76053a5840bc4d6104dd87efc31bcc3a8aefc3100235be61c03a50556"
        "6777185dd6f932baeb5d5e2d4398d01140d48".hexToData;
    req = [BRPaymentProtocolRequest requestWithData:d];
    
    XCTAssertEqualObjects(req.data, d, @"[BRPaymentProtocolRequest toData]");
    
    // test that the x509 certs are valid, but the payment request is expired (BUG: XXXX the cert is now expired!)
    XCTAssertFalse([req isValid], @"[BRPaymentProtocolRequest isValid]");
    XCTAssertEqualObjects(req.errorMessage,
                          @"untrusted certificate - One or more certificates have expired or are not valid yet.",
                          @"[BRPaymentProtocolRequest isValid]");
    
    NSLog(@"commonName:%@", req.commonName);
    XCTAssertEqualObjects(req.commonName, @"coinbase.com",  @"[BRPaymentProtocolRequest commonName]");
    
    
    d = @"08011209783530392b736861311aee210ae10a3082055d30820445a0030201020210131b73f7cc0dd0ef4fd9baa161dfd202300d06092"
    "a864886f70d01010b0500308190310b3009060355040613024742311b30190603550408131247726561746572204d616e636865737465"
    "723110300e0603550407130753616c666f7264311a3018060355040a1311434f4d4f444f204341204c696d69746564313630340603550"
    "403132d434f4d4f444f2052534120446f6d61696e2056616c69646174696f6e2053656375726520536572766572204341301e170d3134"
    "313030383030303030305a170d3136313030373233353935395a30573121301f060355040b1318446f6d61696e20436f6e74726f6c205"
    "6616c69646174656431143012060355040b130b506f73697469766553534c311c301a060355040313137061796d656e74732e6269746f"
    "6e69632e657530820122300d06092a864886f70d01010105000382010f003082010a0282010100c1dff3454587b55e6bf004b664f477c"
    "2b0c1b739f782babf2c591d674a9bf8311b26f9dd6b14bac7b18800cc76f406459210d883d13fff3fe58418ca684363db7e5bbd2aa534"
    "81cfce7ae83b87f306689c93c46371da3e9e7270a56e6d72d2b966b2ca18f219f2fb19bfda4258884ab6fda662bd130b1fce2f994f46c"
    "a85e230d9e122ead147f61649684b9077a25122846dc89ffe03d4bf36a2712b91e6b8c0b0b1182e3c46d89b4e34ab9e86e4f7e5b98435"
    "74d5b38ca7c8f6a72bbb3f7a93b33ed0191c4bc8d269de13eaeea9a3ff33bc454dd4e48e664346f3643e6c6dfc3328c8c10a1e712cd69"
    "5131e66641bb9a4a198ffc34c9477725c6b94173be3dd0203010001a38201e9308201e5301f0603551d2304183016801490af6a3a945a"
    "0bd890ea125673df43b43a28dae7301d0603551d0e04160414e23d0ca9028de4cf10359afe36c90bc63b78f4d9300e0603551d0f0101f"
    "f0404030205a0300c0603551d130101ff04023000301d0603551d250416301406082b0601050507030106082b06010505070302304f06"
    "03551d2004483046303a060b2b06010401b23101020207302b302906082b06010505070201161d68747470733a2f2f7365637572652e6"
    "36f6d6f646f2e636f6d2f4350533008060667810c01020130540603551d1f044d304b3049a047a0458643687474703a2f2f63726c2e63"
    "6f6d6f646f63612e636f6d2f434f4d4f444f525341446f6d61696e56616c69646174696f6e53656375726553657276657243412e63726"
    "c30818506082b0601050507010104793077304f06082b060105050730028643687474703a2f2f6372742e636f6d6f646f63612e636f6d"
    "2f434f4d4f444f525341446f6d61696e56616c69646174696f6e53656375726553657276657243412e637274302406082b06010505073"
    "0018618687474703a2f2f6f6373702e636f6d6f646f63612e636f6d30370603551d110430302e82137061796d656e74732e6269746f6e"
    "69632e657582177777772e7061796d656e74732e6269746f6e69632e6575300d06092a864886f70d01010b0500038201010077bbdd872"
    "7eb42b69bac73a7afa4e7254a8f2aa4899d0d3e411f25ac5ff6c36fe754c890ee1835a0c67af5019537220e8d6694808d83278fc77d80"
    "48e842117a1793d6dd467611330943d951a512b17975c60d9b4b32ca0f8f5423893f14b823bbb9acffad782512c1d45ab22cf6cb66168"
    "c6d201a435ddc74b5c47701449c23a3ad019c870258c275071ba8e46cb2b84e5259d7e81cd58eb42ffc249ac7d95d937fceb6e6ebc1ba"
    "d1778a4cb41e23c23d16fcef4331563df6f903753d834a1ddb17b1e6642edad1a8e884cc5e832cf1d791c62f68cd5bd135ea9012fa125"
    "95b660fc061fe078d896a08e8046d2b828f97b7b3aac875ebe524ebff0c55a45b250a8c0c30820608308203f0a00302010202102b2e6e"
    "ead975366c148a6edba37c8c07300d06092a864886f70d01010c0500308185310b3009060355040613024742311b30190603550408131"
    "247726561746572204d616e636865737465723110300e0603550407130753616c666f7264311a3018060355040a1311434f4d4f444f20"
    "4341204c696d69746564312b302906035504031322434f4d4f444f205253412043657274696669636174696f6e20417574686f7269747"
    "9301e170d3134303231323030303030305a170d3239303231313233353935395a308190310b3009060355040613024742311b30190603"
    "550408131247726561746572204d616e636865737465723110300e0603550407130753616c666f7264311a3018060355040a1311434f4"
    "d4f444f204341204c696d69746564313630340603550403132d434f4d4f444f2052534120446f6d61696e2056616c69646174696f6e20"
    "5365637572652053657276657220434130820122300d06092a864886f70d01010105000382010f003082010a02820101008ec20219e1a"
    "059a4eb38358d2cfd01d0d349c064c70b620545163aa8a0c00c027f1dccdbc4a16d7703a30f86f9e3069c3e0b818a9b491bad03befa4b"
    "db8c20edd5ce5e658e3e0daf4cc2b0b7455e522f34de482464b441ae0097f7be67de9ed07aa753803b7cadf596556f97470a7c858b229"
    "78db384e09657d0701860968fee2d07939da1bacad1cd7be9c42a9a2821914d6f924f25a5f27a35dd26dc46a5d0ac59358cff4e914350"
    "3f59931e6c5121ee5814abfe7550783e4cb01c8613fa6b98bce03b941e8552dc039324186ecb275145e670de2543a40de14aa5edb67ec"
    "8cd6dee2e1d27735ddc453080aae3b2410bafbd4487dab9e51b9d7faee58582a50203010001a382016530820161301f0603551d230418"
    "30168014bbaf7e023dfaa6f13c848eadee3898ecd93232d4301d0603551d0e0416041490af6a3a945a0bd890ea125673df43b43a28dae"
    "7300e0603551d0f0101ff04040302018630120603551d130101ff040830060101ff020100301d0603551d250416301406082b06010505"
    "07030106082b06010505070302301b0603551d200414301230060604551d20003008060667810c010201304c0603551d1f04453043304"
    "1a03fa03d863b687474703a2f2f63726c2e636f6d6f646f63612e636f6d2f434f4d4f444f52534143657274696669636174696f6e4175"
    "74686f726974792e63726c307106082b0601050507010104653063303b06082b06010505073002862f687474703a2f2f6372742e636f6"
    "d6f646f63612e636f6d2f434f4d4f444f525341416464547275737443412e637274302406082b060105050730018618687474703a2f2f"
    "6f6373702e636f6d6f646f63612e636f6d300d06092a864886f70d01010c050003820201004e2b764f921c623689ba77c12705f41cd64"
    "49da99a3eaad56666013eea49e6a235bcfaf6dd958e9935980e361875b1dddd50727caedc7788ce0ff79020caa3672e1f567f7be144ea"
    "4295c45d0d01504615f28189596c8add8cf112a18d3a428a98f84b347b273b08b46f243b729d6374583c1a6c3f4fc7119ac8a8f5b537e"
    "f1045c66cd9e05e9526b3ebada3b9ee7f0c9a66357332604ee5dd8a612c6e5211776896d318755115001b7488dde1c738044328e916fd"
    "d905d45d472760d6fb383b6c72a294f8421adfed6f068c45c20600aae4e8dcd9b5e17378ecf623dcd1dd6c8e1a8fa5ea547c96b7c3fe5"
    "58e8d495efc64bbcf3ebd96eb69cdbfe048f1628210e50c4657f233dad0c863edc61f9405964a1a91d1f7ebcf8f52ae0d08d93ea8a051"
    "e9c18774d5c9f774ab2e53fbbb7afb97e2f81f268fb3d2a0e0375b283b31e50e572d5ab8ad79ac5e20661aa5b9a6b539c1f59843ffeef"
    "9a7a7fdeeca243d8016c4178f8ac160a10cae5b4347914bd59a175ff9d487c1c28cb7e7e20f30193786ace0dc4203e694a89daefd0f24"
    "5194ce9208d1fc50f003407b8859ed0eddacd2778234dc069502d890f92dea37d51a60d06720d7d8420b45af8268dedd6624379029941"
    "9461925b880d7cbd486286a4470262362a99f866fbfba9070d256778578efea25a917ce50728c003aaae3db63349ff8067101e28220d4"
    "fe6fbdb10af80a308205743082045ca00302010202102766ee56eb49f38eabd770a2fc84de22300d06092a864886f70d01010c0500306"
    "f310b300906035504061302534531143012060355040a130b416464547275737420414231263024060355040b131d4164645472757374"
    "2045787465726e616c20545450204e6574776f726b312230200603550403131941646454727573742045787465726e616c20434120526"
    "f6f74301e170d3030303533303130343833385a170d3230303533303130343833385a308185310b3009060355040613024742311b3019"
    "0603550408131247726561746572204d616e636865737465723110300e0603550407130753616c666f7264311a3018060355040a13114"
    "34f4d4f444f204341204c696d69746564312b302906035504031322434f4d4f444f205253412043657274696669636174696f6e204175"
    "74686f7269747930820222300d06092a864886f70d01010105000382020f003082020a028202010091e85492d20a56b1ac0d24ddc5cf4"
    "46774992b37a37d23700071bc53dfc4fa2a128f4b7f1056bd9f7072b7617fc94b0f17a73de3b00461eeff1197c7f4863e0afa3e5cf993"
    "e6347ad9146be79cb385a0827a76af7190d7ecfd0dfa9c6cfadfb082f4147ef9bec4a62f4f7f997fb5fc674372bd0c00d689eb6b2cd3e"
    "d8f981c14ab7ee5e36efcd8a8e49224da436b62b855fdeac1bc6cb68bf30e8d9ae49b6c6999f878483045d5ade10d3c4560fc32965127"
    "bc67c3ca2eb66bea46c7c720a0b11f65de4808baa44ea9f283463784ebe8cc814843674e722a9b5cbd4c1b288a5c227bb4ab98d9eee05"
    "183c309464e6d3e99fa9517da7c3357413c8d51ed0bb65caf2c631adf57c83fbce95dc49baf4599e2a35a24b4baa9563dcf6faaff4958"
    "bef0a8fff4b8ade937fbbab8f40b3af9e843421e89d884cb13f1d9bbe18960b88c2856ac141d9c0ae771ebcf0edd3da996a148bd3cf7a"
    "fb50d224cc01181ec563bf6d3a2e25bb7b204225295809369e88e4c65f191032d707402ea8b671529695202bbd7df506a5546bfa0a328"
    "617f70d0c3a2aa2c21aa47ce289c064576bf821827b4d5aeb4cb50e66bf44c867130e9a6df1686e0d8ff40ddfbd042887fa3333a2e5c1"
    "e41118163ce18716b2beca68ab7315c3a6a47e0c37959d6201aaff26a98aa72bc574ad24b9dbb10fcb04c41e5ed1d3d5e289d9cccbfb3"
    "51daa747e584530203010001a381f43081f1301f0603551d23041830168014adbd987a34b426f7fac42654ef03bde024cb541a301d060"
    "3551d0e04160414bbaf7e023dfaa6f13c848eadee3898ecd93232d4300e0603551d0f0101ff040403020186300f0603551d130101ff04"
    "0530030101ff30110603551d20040a300830060604551d200030440603551d1f043d303b3039a037a0358633687474703a2f2f63726c2"
    "e7573657274727573742e636f6d2f416464547275737445787465726e616c4341526f6f742e63726c303506082b060105050701010429"
    "3027302506082b060105050730018619687474703a2f2f6f6373702e7573657274727573742e636f6d300d06092a864886f70d01010c0"
    "500038201010064bf83f15f9a85d0cdb8a129570de85af7d1e93ef276046ef15270bb1e3cff4d0d746acc818225d3c3a02a5d4cf5ba8b"
    "a16dc4540975c7e3270e5d847937401377f5b4ac1cd03bab1712d6ef34187e2be979d3ab57450caf28fad0dbe5509588bbdf8557697d9"
    "2d852ca7381bf1cf3e6b86e661105b31e942d7f91959259f14ccea391714c7c470c3b0b19f6a1b16c863e5caac42e82cbf90796ba484d"
    "90f294c8a973a2eb067b239ddea2f34d559f7a6145981868c75e406b23f5797aef8cb56b8bb76f46f47bf13d4b04d89380595ae041241"
    "db28f15605847dbef6e46fd15f5d95f9ab3dbd8b8e440b3cd9739ae85bb1d8ebcdc879bd1a6eff13b6f10386f22720a046d61696e121f"
    "08a8ef0f121976a914136a8e0aaff92594668980ad47287a7103503f5788ac209c85a0b9052a1b446f6e617469652061616e204269747"
    "3206f662046726565646f6d322668747470733a2f2f627061792e746f2f6d2f30396636366463623263303339386635386165362a8002"
    "b58932c12f8e7015c0797be9c644317dc15f03ce9a4c9c6430147c55cf5c9806895fc7582fd63466abee43eb17b3b0309697f2b79ef28"
    "911986a93cf4fef52d90446a4321efc17c50380b06b9088f427b384523c912070a87cf7f3a2f82dab57c9bd983b799b8a49dce5f797d5"
    "0418c3addca947098c7745f9a8da2bff50185a03b8852c5c37e94c73b56f456ac38999e1600f8ccba72d12994a0ca40edb9e6ef5c2c72"
    "77107aee87b589e1c6d4ba92f6cc9ad7489a3b6a2dccbc62178a7440f563b266aa185c50e72ca97d0abab243c72ce30b8a2ab82a2dd03"
    "e45460f549f41765ee6ebd4aadfaaa5d3ce1cea9bc0253b2187193797e27753259eda7a0367c".hexToData;
    
    req = [BRPaymentProtocolRequest requestWithData:d];
    
    XCTAssertEqualObjects(req.data, d, @"[BRPaymentProtocolRequest toData]");
    
    // test that the x509 certs are valid, but the payment request is expired
    XCTAssertFalse([req isValid], @"[BRPaymentProtocolRequest isValid]");
//    XCTAssertEqualObjects(req.errorMessage, @"request expired", @"[BRPaymentProtocolRequest isValid]");
    
    NSLog(@"commonName:%@", req.commonName);
    XCTAssertEqualObjects(req.commonName, @"payments.bitonic.eu",  @"[BRPaymentProtocolRequest commonName]");
}

#pragma mark - UIImage+Utils

- (void)testUIImageUtils
{
    
}

#pragma mark - performance

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
