//
//  DSViewController.m
//  DSAds
//
//  Created by 董硕 on 02/09/2022.
//  Copyright (c) 2022 董硕. All rights reserved.
//

#import "DSViewController.h"
#import "DS_AdsTokenTool.h"

@interface DSViewController ()

@end

@implementation DSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[DS_AdsTokenTool requestAdsInfo:^(DS_AdsToeknRequsetResult code) {
		NSLog(@"code = %ld",code);
	}];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
