//
//  AdsTokenTool.h
//  DSxSdk
//
//  Created by winston on 2021/7/7.
//  Copyright © 2021 Platform. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DS_AdsToeknRequsetResult) {
	DS_AdsToeknRequsetSuccess,	//获取成功
	DS_AdsToeknRequsetError,	//获取失败
};


NS_ASSUME_NONNULL_BEGIN


@interface DS_AdsTokenTool : NSObject
+ (void)requestAdsInfo:(void(^ _Nullable )(DS_AdsToeknRequsetResult code))block;

+ (NSString *)getIADGroupId;


@end

NS_ASSUME_NONNULL_END
