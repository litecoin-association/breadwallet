//
//  BRTransactionEntity.m
//  BreadWallet
//
//  Created by Aaron Voisine on 8/22/13.
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

#import "BRTransactionEntity.h"
#import "BRTxInputEntity.h"
#import "BRTxOutputEntity.h"
#import "BRAddressEntity.h"
#import "BRTransaction.h"
#import "BRMerkleBlock.h"
#import "NSManagedObject+Sugar.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"

@implementation BRTransactionEntity

@dynamic txHash;
@dynamic blockHeight;
@dynamic timestamp;
@dynamic inputs;
@dynamic outputs;
@dynamic lockTime;

+ (void)setContext:(NSManagedObjectContext *)context
{
    [super setContext:context];
    [BRTxInputEntity setContext:context];
    [BRTxOutputEntity setContext:context];
}

- (instancetype)setAttributesFromTx:(BRTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        NSMutableOrderedSet *inputs = [self mutableOrderedSetValueForKey:@"inputs"];
        NSMutableOrderedSet *outputs = [self mutableOrderedSetValueForKey:@"outputs"];
        UInt256 txHash = tx.txHash;
        NSUInteger idx = 0;
        
        self.txHash = [NSData dataWithBytes:&txHash length:sizeof(txHash)];
        self.blockHeight = tx.blockHeight;
        self.timestamp = tx.timestamp;
    
        while (inputs.count < tx.inputHashes.count) {
            [inputs addObject:[BRTxInputEntity managedObject]];
        }
    
        while (inputs.count > tx.inputHashes.count) {
            [inputs removeObjectAtIndex:inputs.count - 1];
        }
    
        for (BRTxInputEntity *e in inputs) {
            [e setAttributesFromTx:tx inputIndex:idx++];
        }

        while (outputs.count < tx.outputAddresses.count) {
            [outputs addObject:[BRTxOutputEntity managedObject]];
        }
    
        while (outputs.count > tx.outputAddresses.count) {
            [self removeObjectFromOutputsAtIndex:outputs.count - 1];
        }

        idx = 0;
        
        for (BRTxOutputEntity *e in outputs) {
            [e setAttributesFromTx:tx outputIndex:idx++];
        }
        
        self.lockTime = tx.lockTime;
    }];
    
    return self;
}

- (BRTransaction *)transaction
{
    BRTransaction *tx = [BRTransaction new];
    
    [self.managedObjectContext performBlockAndWait:^{
        NSData *txHash = self.txHash;
        
        if (txHash.length == sizeof(UInt256)) tx.txHash = *(const UInt256 *)txHash.bytes;
        tx.lockTime = self.lockTime;
        tx.blockHeight = self.blockHeight;
        tx.timestamp = self.timestamp;
    
        for (BRTxInputEntity *e in self.inputs) {
            txHash = e.txHash;
            if (txHash.length != sizeof(UInt256)) continue;
            [tx addInputHash:*(const UInt256 *)txHash.bytes index:e.n script:nil signature:e.signature
             sequence:e.sequence];
        }
        
        for (BRTxOutputEntity *e in self.outputs) {
            [tx addOutputScript:e.script amount:e.value];
        }
    }];
    
    return tx;
}

- (void)deleteObject
{
    for (BRTxInputEntity *e in self.inputs) { // mark inputs as unspent
        [[BRTxOutputEntity objectsMatching:@"txHash == %@ && n == %d", e.txHash, e.n].lastObject setSpent:NO];
    }

    [super deleteObject];
}

@end
