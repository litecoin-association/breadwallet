//
//  BRTxMetadataEntity.m
//  BreadWallet
//
//  Created by Aaron Voisine on 10/22/15.
//  Copyright (c) 2015 Aaron Voisine <voisine@gmail.com>
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

#import "BRTxMetadataEntity.h"
#import "BRTransaction.h"
#import "NSManagedObject+Sugar.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"

@implementation BRTxMetadataEntity

@dynamic blob;
@dynamic txHash;
@dynamic type;

- (instancetype)setAttributesFromTx:(BRTransaction *)tx
{
    NSMutableData *data = [NSMutableData dataWithData:tx.data];

    [data appendUInt32:tx.blockHeight];
    [data appendUInt32:tx.timestamp];

    [self.managedObjectContext performBlockAndWait:^{
        self.blob = data;
        self.type = TX_MDTYPE_MSG;
        self.txHash = [NSData dataWithBytes:tx.txHash.u8 length:sizeof(UInt256)];
    }];
    
    return self;
}

- (BRTransaction *)transaction
{
    __block BRTransaction *tx = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        NSData *data = self.blob;
    
        if (data.length > sizeof(uint32_t)*2) {
            tx = [BRTransaction transactionWithMessage:data];
            tx.blockHeight = [data UInt32AtOffset:data.length - sizeof(uint32_t)*2];
            tx.timestamp = [data UInt32AtOffset:data.length - sizeof(uint32_t)];
        }
    }];
    
    return tx;
}

@end
