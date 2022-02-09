//
//  AdsTokenTool.m
//  DSxSdk
//
//  Created by winston on 2021/7/7.
//  Copyright © 2021 Platform. All rights reserved.
//

#import "DS_AdsTokenTool.h"
#import <iAd/iAd.h>
#import <AdServices/AdServices.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

#define DS_AAA_TOKEN_KEY	@"DS_AAA_TOKEN_KEY"		//iOS14.3以上，token key
#define DS_IAD_GROUP_ID		@"DS_IAD_GROUP_ID"		//iOS14.3以下，asa_group_id key
#define DS_IAD_PARAMS_KEY	@"DS_IAD_PARAMS_KEY"	//iOS14.3以下，asa_group_info key
#define DS_ADS_FLAG_KEY		@"DS_ADS_FLAG_KEY"		//ads上传标记 key

@implementation DS_AdsTokenTool


+ (void)requestAdsInfo:(void(^ _Nullable )(DS_AdsToeknRequsetResult code))block{

	if (@available(iOS 14.3, *)) {
		//14.3以上采用新的ADS框架
		[self requestADSToken:block];
	}else{
		//14.3以下采用旧的IAD框架
		[self requestIADInfo:block];
	}
}

+ (NSString *)getIADGroupId{
	NSString * groupId = [[NSUserDefaults standardUserDefaults] valueForKey:DS_IAD_GROUP_ID];
	if (groupId == nil) {
		groupId = @"";
	}
	return groupId;
}

#pragma mark - 请求ads数据，存入本地

+ (void)requestADSToken:(void(^ _Nullable )(DS_AdsToeknRequsetResult code))block{
	NSString * aaaToken = [[NSUserDefaults standardUserDefaults] valueForKey:DS_AAA_TOKEN_KEY];
	if (aaaToken != nil) {
		block(DS_AdsToeknRequsetSuccess);
		return;
	}
	//用于 ASA 归因的，不受 ATT 约束，就是无论用户 是否允许跟踪，都可以归因
	NSError *error;
	NSString * token = [AAAttribution attributionTokenWithError:&error];
	if (token != nil) {
		[[NSUserDefaults standardUserDefaults] setValue:token forKey:DS_AAA_TOKEN_KEY];
		[[NSUserDefaults standardUserDefaults] synchronize];
		block(DS_AdsToeknRequsetSuccess);
	}else{
		//错误不为空时
		[self handleError:error];
		block(DS_AdsToeknRequsetError);
	}
}

/*
 {
 "Version3.1" =     {
 "iad-adgroup-id" = 1234567890;
 "iad-adgroup-name" = AdGroupName;
 "iad-attribution" = true;
 "iad-campaign-id" = 1234567890;
 "iad-campaign-name" = CampaignName;
 "iad-click-date" = "2021-07-07T02:43:13Z";
 "iad-conversion-date" = "2021-07-07T02:43:13Z";
 "iad-conversion-type" = Download;
 "iad-country-or-region" = US;
 "iad-creativeset-id" = 1234567890;
 "iad-creativeset-name" = CreativeSetName;
 "iad-keyword" = Keyword;
 "iad-keyword-id" = 12323222;
 "iad-keyword-matchtype" = Broad;
 "iad-lineitem-id" = 1234567890;
 "iad-lineitem-name" = LineName;
 "iad-org-id" = 1234567890;
 "iad-org-name" = OrgName;
 "iad-purchase-date" = "2021-07-07T02:43:13Z";
 };
 }
 */
+ (void)requestIADInfo:(void(^ _Nullable )(DS_AdsToeknRequsetResult code))block{
	NSDictionary * iadInfo = [[NSUserDefaults standardUserDefaults] valueForKey:DS_IAD_PARAMS_KEY];
	if (iadInfo != nil) {
		block(DS_AdsToeknRequsetSuccess);
		return;
	}
	Boolean attribution_enable = TRUE;
	//受 ATT 以及 LAT 约束，如果用户允许 跟踪，就可以归因。
	if (@available(iOS 14.0, *)) {
		ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
		//用户未做选择或未弹窗  或用户允许
		attribution_enable = status == ATTrackingManagerAuthorizationStatusNotDetermined | status == ATTrackingManagerAuthorizationStatusAuthorized;
		
		if (@available(iOS 14.5, *)) {
			attribution_enable = status == ATTrackingManagerAuthorizationStatusAuthorized;
		}
	}
	if (attribution_enable) {
		if ([[ADClient sharedClient] respondsToSelector:@selector(requestAttributionDetailsWithBlock:) ]) {
			[[ADClient sharedClient] requestAttributionDetailsWithBlock:^(NSDictionary<NSString *,NSObject *> * _Nullable attributionDetails, NSError * _Nullable error) {
				if(!error){
					// 归因成功;数据不不再变化，可记录状态，该设备不不再调⽤用此API。
					// 建议将attributionDetails数据原样发送到您的服务器器存储，
					[[NSUserDefaults standardUserDefaults] setValue:attributionDetails forKey:DS_IAD_PARAMS_KEY];
					[[NSUserDefaults standardUserDefaults] synchronize];
					[self saveGroupId:attributionDetails];
					block(DS_AdsToeknRequsetSuccess);
				}else{
					block(DS_AdsToeknRequsetError);
				}
				
				if (error.code == ADClientErrorTrackingRestrictedOrDenied) {
					// 归因错误;数据不再变化，可记录状态，该设备不不再调⽤用此API。
					// 设备启⽤了【限制⼴广告跟踪】。不能获取到归因详情。
					return;
				}
				
				/*
				 ADClientErrorMissingData = 2,
				 ADClientErrorCorruptResponse = 3,
				 ADClientErrorRequestClientError = 4,
				 ADClientErrorRequestServerError = 5,
				 ADClientErrorRequestNetworkError = 6,
				 ADClientErrorUnsupportedPlatform = 7
				 */
				//任何其他归因错误，您需要在合适时机再次调⽤用本接⼝口。
				//可以是在本次会话，或者APP下次被启动时。
			}];
		}
	}else{
		//ATTrackingManagerAuthorizationStatusRestricted和ATTrackingManagerAuthorizationStatusDenied
		//14.0以上会走这里，14.0以下不会走这里，默认走IAD
		block(DS_AdsToeknRequsetError);
		NSLog(@"用户拒绝追踪，需要请求授权");
	}
}

+ (void)saveGroupId:(NSDictionary *)attributionDetails{
	if (attributionDetails.allKeys.count > 0) {
		NSString * groupid = nil;
		if ([attributionDetails.allKeys containsObject:@"iad-adgroup-id"]) {
			groupid = [attributionDetails valueForKey:@"iad-adgroup-id"];
		}else{
			for (NSString * key in attributionDetails.allKeys) {
				id value = attributionDetails[key];
				if ([value isKindOfClass:[NSDictionary class]]) {
					NSDictionary * info = (NSDictionary *)value;
					if ([info.allKeys containsObject:@"iad-adgroup-id"]) {
						groupid = [info valueForKey:@"iad-adgroup-id"];
						break;
					}
				}
			}
		}
		if (groupid != nil) {
			[[NSUserDefaults standardUserDefaults] setValue:groupid forKey:DS_IAD_GROUP_ID];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
}

+(void)handleError:(NSError *)error{
	switch (error.code) {
		case AAAttributionErrorCodeNetworkError:
		{
			NSLog(@"网络错误");
		}
			break;
		case AAAttributionErrorCodeInternalError:
		{
			NSLog(@"内部错误");
		}
			break;
		case AAAttributionErrorCodePlatformNotSupported:
		{
			NSLog(@"平台不支持");
		}
			break;
			
		default:
			break;
	}
}

+ (void)requestAdsInfoByToken:(NSString *)token{
	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
	//后续将该接口抽为单独的action方法，进行请求。 忽略此问题
	NSURL *url = [NSURL URLWithString:@"https://api-adservices.apple.com/api/v1/"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
														   cachePolicy:NSURLRequestUseProtocolCachePolicy
													   timeoutInterval:60.0];
	[request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPMethod:@"POST"];
	NSData* postData = [token dataUsingEncoding:NSUTF8StringEncoding];
	[request setHTTPBody:postData];
	NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSError *resError;
		NSMutableDictionary *resDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&resError];
		
		NSLog(@"苹果返回数据 %@",resDic);
		/*
		 https://developer.apple.com/documentation/apple_search_ads/apple_search_ads_campaign_management_api_4
		 
		 苹果返回数据
		 {
			//广告组的标识符。使用“获取广告组”将您的归因响应与其在 Apple Search Ads 活动管理 API 中的相应活动相关联。adGroupId
		 	adGroupId = 1234567890;
		 	
		 	//如果用户在您的应用下载前最多 30 天点击 Apple Search Ads 展示，则返回值。如果 API 找不到匹配的归因记录，则归因值为false。
			attribution = 1;
		 	
		 	
		 	//活动的唯一标识符。用于请求 https://api.searchads.apple.com/api/v4/campaigns/{campaignId}
			campaignId = 1234567890;
		 	
			//用户点击相应广告系列中的广告的日期和时间。此字段仅出现在详细的归因响应负载中。
			clickDate = "2021-07-06T05:37Z";
		 	
		 	//转换类型为newdownloads或redownloads.
			//转化类型显示在 Apple Search Ads Campaign Management API 的广告活动报告中。有关更多信息，请参阅对象。ExtendedSpendRow
		 	conversionType = Download;
		 	
		 	//活动的国家或地区。
		 	countryOrRegion = US;
		 	
		 	//属于广告组的 Creative Set 的唯一标识符。
			//使用 Apple Search Ads Campaign Management API 中的 Get a Creative Sets Ad Variation端点将您的归因响应关联起来。creativeSetId
		 	creativeSetId = 1234567890;
		 	
		 	//关键字的唯一标识符。使用Apple Search Ads 活动管理 API中的获取广告组中的定位关键字、获取广告系列否定关键字或获取广告组否定关键字端点，通过关联您的归因响应。当您启用搜索匹配时，API不会在归因响应中返回。有关详细信息，请参阅广告组。 keywordIdkeywordId
		 	keywordId = 12323222;
		 	
		 	//拥有活动的组织的标识符。您与 Apple Search Ads UI 中的帐户相同。用来获取API有权访问的角色和组织https://api.searchads.apple.com/api/v4/acls
		 	orgId = 1234567890;
		 	
		 }
		 
		 */
	}];
	[postDataTask resume];
}



@end
