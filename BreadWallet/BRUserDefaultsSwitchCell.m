//
//  BRUserDefaultsSwitchCell.m
//  BreadWallet
//
//  Created by Samuel Sutch on 12/29/15.
//  Copyright (c) 2016 breadwallet LLC
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

#import "BRUserDefaultsSwitchCell.h"

@interface BRUserDefaultsSwitchCell ()

@property (nonatomic, copy) NSString *_userDefaultsKey;
- (void)updateUi;

@end

@implementation BRUserDefaultsSwitchCell

- (void)setUserDefaultsKey:(NSString *)key
{
    self._userDefaultsKey = key;
    [self updateUi];
}

- (void)didUpdateSwitch:(id)sender
{
    if (self._userDefaultsKey)
        [[NSUserDefaults standardUserDefaults] setBool:self.theSwitch.on forKey:self._userDefaultsKey];
}

- (void)updateUi
{
    if (self._userDefaultsKey)
        self.theSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:self._userDefaultsKey];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    if (self._userDefaultsKey)
        self.theSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:self._userDefaultsKey];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

@end
