//
//  BRCopyLabel.m
//  BreadWallet
//
//  Created by Aaron Voisine on 6/21/14.
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

#import "BRCopyLabel.h"

@interface BRCopyLabel ()

@property (nonatomic, strong) UIView *highlight;
@property (nonatomic, readonly) CGRect copyableFrame;
@property (nonatomic, strong) id menuHideObserver;

@end

@implementation BRCopyLabel

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)resignFirstResponder
{
    if ([super resignFirstResponder]) {
        [UIView animateWithDuration:0.2 animations:^{
            self.highlight.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (finished) [self.highlight removeFromSuperview];
        }];

        if (self.menuHideObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.menuHideObserver];
        self.menuHideObserver = nil;
        return YES;
    }
    else return NO;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return (action == @selector(copy:));
}

- (NSString *)copyableText
{
    return (_copyableText) ? _copyableText : self.text;
}

- (CGRect)copyableFrame
{
    NSRange r = [self.text rangeOfString:self.copyableText];

    if (r.location == NSNotFound) return self.bounds;

    CGRect start = [[self.text substringToIndex:r.location] boundingRectWithSize:self.bounds.size options:0
                    attributes:@{NSFontAttributeName:self.font} context:nil],
           end = [[self.text substringFromIndex:r.location + r.length] boundingRectWithSize:self.bounds.size options:0
                  attributes:@{NSFontAttributeName:self.font} context:nil];

    if (start.size.width + end.size.width > self.bounds.size.width) return self.bounds;
    return CGRectMake(start.size.width, 0, self.bounds.size.width - (start.size.width + end.size.width),
                      self.bounds.size.height);
}

- (void)setSelectedColor:(UIColor *)selectedColor
{
    _selectedColor = selectedColor;
    self.highlight.backgroundColor = selectedColor;
}

- (void)toggleCopyMenu
{
    if (self.copyableText.length == 0) return;
    
    if ([self isFirstResponder]) {
        [self resignFirstResponder];
        return;
    }

    if (! self.highlight) {
        self.highlight =
            [[UIView alloc] initWithFrame:CGRectOffset(self.copyableFrame, self.frame.origin.x, self.frame.origin.y)];
        self.highlight.backgroundColor =
            (self.selectedColor) ? self.selectedColor : [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.15];
        self.highlight.alpha = 0.0;
    }

    [self.superview insertSubview:self.highlight belowSubview:self];
    [UIView animateWithDuration:0.2 animations:^{ self.highlight.alpha = 1.0; }];
    [self becomeFirstResponder];
    [[UIMenuController sharedMenuController] setTargetRect:self.copyableFrame inView:self];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];

    if (! self.menuHideObserver) {
        self.menuHideObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:UIMenuControllerWillHideMenuNotification object:nil
             queue:nil usingBlock:^(NSNotification *note) { [self resignFirstResponder]; }];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self toggleCopyMenu];
    [super touchesEnded:touches withEvent:event];
}

- (void)dealloc
{
    if (self.menuHideObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.menuHideObserver];
}

// MARK: - UIResponderStandardEditActions

- (void)copy:(id)sender
{
    [UIPasteboard generalPasteboard].string = self.copyableText;
    NSLog(@"%@", [UIPasteboard generalPasteboard].string);
    [self resignFirstResponder];
}

@end
