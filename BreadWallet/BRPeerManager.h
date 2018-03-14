//
//  BRPeerManager.h
//  BreadWallet
//
//  Created by Aaron Voisine on 10/6/13.
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "BRPeer.h"

FOUNDATION_EXPORT NSString* _Nonnull const BRPeerManagerSyncStartedNotification;
FOUNDATION_EXPORT NSString* _Nonnull const BRPeerManagerSyncFinishedNotification;
FOUNDATION_EXPORT NSString* _Nonnull const BRPeerManagerSyncFailedNotification;
FOUNDATION_EXPORT NSString* _Nonnull const BRPeerManagerTxStatusNotification;

#define PEER_MAX_CONNECTIONS 3

@class BRTransaction;

@interface BRPeerManager : NSObject <BRPeerDelegate, UIAlertViewDelegate>

@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) uint32_t lastBlockHeight;
@property (nonatomic, readonly) uint32_t estimatedBlockHeight; // last block height reported by current download peer
@property (nonatomic, readonly) double syncProgress;
@property (nonatomic, readonly) NSUInteger peerCount; // number of connected peers
@property (nonatomic, readonly) NSString * _Nullable downloadPeerName;

+ (instancetype _Nullable)sharedInstance;

- (void)connect;
- (void)rescan;
- (void)publishTransaction:(BRTransaction * _Nonnull)transaction
                completion:(void (^ _Nonnull)(NSError * _Nullable error))completion;
- (NSUInteger)relayCountForTransaction:(UInt256)txHash; // number of connected peers that have relayed the transaction
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since reference date, 00:00:00 01/01/01 GMT

@end
