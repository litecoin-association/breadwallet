//
//  BRBuyLTCViewController.m
//  LoafWallet
//
//  Created by Litecoin Foundation on 05/05/2017.
//  Copyright © 2017 Litecoin Foundation. All rights reserved.
//

#import "BRBuyLTCViewController.h"
#import "BRWalletManager.h"
#import "BRPaymentRequest.h"

@interface BRBuyLTCViewController ()
@property (strong, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation BRBuyLTCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *APIKEY = @"58a81dde-3bb2-56b7-998c-b28e7d500e25";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://buy.coinbase.com?code=%@&address=%@&crypto_currency=LTC", APIKEY, self.paymentAddress]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:urlRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSString *)paymentAddress
{
    return [BRWalletManager sharedInstance].wallet.receiveAddress;
}

- (IBAction)backButton:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
