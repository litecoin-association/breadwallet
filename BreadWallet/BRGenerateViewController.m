//
//  BRGenerateViewController.m
//  BreadWallet
//
//  Created by Loshan T on 30/05/2016.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
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

#import "BRGenerateViewController.h"

@interface BRGenerateViewController ()

@property (strong, nonatomic) IBOutlet UIButton *genButton;

@end

@implementation BRGenerateViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Adding border to Generate Button
    
    self.genButton.layer.cornerRadius = 2;
    self.genButton.layer.borderWidth = 2;
    self.genButton.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor colorWithRed:40.0 green:40.0 blue:40.0 alpha:0.90]);
    self.genButton.clipsToBounds = YES;
    
    [self.genButton setTitle:NSLocalizedString(@"continue", nil) forState:UIControlStateNormal];
    
    }

@end