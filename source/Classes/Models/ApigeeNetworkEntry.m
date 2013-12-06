//
//  ApigeeNetworkEntry.m
//  ApigeeAppMonitor
//
//  Copyright (c) 2012 Apigee. All rights reserved.
//

#import <mach/mach_time.h>

#import "NSDate+Apigee.h"
#import "ApigeeModelUtils.h"
#import "ApigeeNetworkEntry.h"

static const NSUInteger kMaxUrlLength = 200;

static NSString *kHeaderReceiptTime    = @"x-apigee-receipttime";
static NSString *kHeaderResponseTime   = @"x-apigee-responsetime";
static NSString *kHeaderProcessingTime = @"x-apigee-serverprocessingtime";
static NSString *kHeaderServerId       = @"x-apigee-serverid";

static mach_timebase_info_data_t mach_time_info;
static uint64_t startupTimeMach;
static NSDate* startupTime;


@implementation ApigeeNetworkEntry

@synthesize url;
@synthesize timeStamp;
@synthesize startTime;
@synthesize endTime;
@synthesize latency;
@synthesize numSamples;
@synthesize numErrors;
@synthesize transactionDetails;
@synthesize httpStatusCode;
@synthesize responseDataSize;
@synthesize serverProcessingTime;
@synthesize serverReceiptTime;
@synthesize serverResponseTime;
@synthesize serverId;
@synthesize domain;
//@synthesize allowsCellularAccess;

+ (void)load
{
    mach_timebase_info(&mach_time_info);
    startupTimeMach = mach_absolute_time();
    startupTime = [NSDate date];
}

+ (uint64_t)machTime
{
    return mach_absolute_time();
}

+ (CGFloat)millisFromMachStartTime:(uint64_t)startTime endTime:(uint64_t)endTime
{
    const uint64_t elapsedTime = endTime - startTime;
    const uint64_t nanos = elapsedTime * mach_time_info.numer / mach_time_info.denom;
    return ((CGFloat) nanos) / NSEC_PER_MSEC;
}

+ (CGFloat)secondsFromMachStartTime:(uint64_t)startTime endTime:(uint64_t)endTime
{
    const uint64_t elapsedTime = endTime - startTime;
    const uint64_t nanos = elapsedTime * mach_time_info.numer / mach_time_info.denom;
    return ((CGFloat) nanos) / NSEC_PER_SEC;
}

+ (NSDate*)machTimeToDate:(uint64_t)machTime
{
    NSTimeInterval timeSinceStartup =
        [ApigeeNetworkEntry secondsFromMachStartTime:startupTimeMach
                                             endTime:machTime];
    return [startupTime dateByAddingTimeInterval:timeSinceStartup];
}


- (id)init
{
    self = [super init];
    if (self) {
        self.numSamples = @"1";
        self.numErrors = @"0";
    }
    
    return self;
}

- (NSDictionary*) asDictionary
{
    return [ApigeeModelUtils asDictionary:self];
}

- (void)populateWithURLString:(NSString*)urlString
{
    if ([urlString length] > kMaxUrlLength) {
        self.url = [urlString substringToIndex:kMaxUrlLength];
    } else {
        self.url = [urlString copy];
    }
}

- (void)populateWithURL:(NSURL*)theUrl
{
    [self populateWithURLString:[theUrl absoluteString]];
}

- (void)populateWithRequest:(NSURLRequest*)request
{
    [self populateWithURL:request.URL];
    //self.allowsCellularAccess = [NSNumber numberWithBool:request.allowsCellularAccess];
}

- (void)populateWithResponse:(NSURLResponse*)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        
        self.httpStatusCode = [NSString stringWithFormat:@"%ld", (long)[httpResponse statusCode]];
        
        NSDictionary *headerFields = [httpResponse allHeaderFields];
        NSString *receiptTime = [headerFields valueForKey:kHeaderReceiptTime];
        NSString *responseTime = [headerFields valueForKey:kHeaderResponseTime];
        NSString *processingTime = [headerFields valueForKey:kHeaderProcessingTime];
        NSString *theServerId = [headerFields valueForKey:kHeaderServerId];
        
        if ([theServerId length] > 0) {
            self.serverId = theServerId;
        }
        
        if ([processingTime length] > 0) {
            self.serverProcessingTime = processingTime;
        }
        
        if ([receiptTime length] > 0) {
            self.serverReceiptTime = receiptTime;
        }
        
        if ([responseTime length] > 0) {
            self.serverResponseTime = responseTime;
        }
    }
}

- (void)populateWithResponseData:(NSData*)responseData
{
    [self populateWithResponseDataSize:[responseData length]];
}

- (void)populateWithResponseDataSize:(NSUInteger)dataSize
{
    self.responseDataSize = [NSString stringWithFormat:@"%lu", (unsigned long)dataSize];
}

- (void)populateWithError:(NSError*)error
{
    if (error) {
        @try {
            self.transactionDetails = [error localizedDescription];
            self.numErrors = @"1";
        }
        @catch (NSException *exception)
        {
            ApigeeLogWarn(@"MONITOR_CLIENT",
                          @"unable to capture networking error: %@",
                          [exception reason]);
        }
    }
}

- (void)populateStartTime:(uint64_t)started ended:(uint64_t)ended
{
    NSDate* start = [ApigeeNetworkEntry machTimeToDate:started];
    NSDate* end = [ApigeeNetworkEntry machTimeToDate:ended];
    
    NSString* startedTimestampMillis = [NSDate stringFromMilliseconds:[start dateAsMilliseconds]];
    self.timeStamp = startedTimestampMillis;
    self.startTime = startedTimestampMillis;
    self.endTime = [NSDate stringFromMilliseconds:[end dateAsMilliseconds]];
    
    const long latencyMillis =
        [ApigeeNetworkEntry millisFromMachStartTime:started
                                            endTime:ended];
    
    self.latency = [NSString stringWithFormat:@"%ld", latencyMillis ];
}

- (void)debugPrint
{
    NSLog(@"========= Start ApigeeNetworkEntry ========");
    NSLog(@"url='%@'", self.url);
    NSLog(@"timeStamp='%@'", self.timeStamp);
    NSLog(@"startTime='%@'", self.startTime);
    NSLog(@"endTime='%@'", self.endTime);
    NSLog(@"latency='%@'", self.latency);
    NSLog(@"numSamples='%@'", self.numSamples);
    NSLog(@"numErrors='%@'", self.numErrors);
    NSLog(@"transactionDetails='%@'", self.transactionDetails);
    NSLog(@"httpStatusCode='%@'", self.httpStatusCode);
    NSLog(@"responseDataSize='%@'", self.responseDataSize);
    NSLog(@"serverProcessingTime='%@'", self.serverProcessingTime);
    NSLog(@"serverReceiptTime='%@'", self.serverReceiptTime);
    NSLog(@"serverResponseTime='%@'", self.serverResponseTime);
    NSLog(@"serverId='%@'", self.serverId);
    NSLog(@"domain='%@'", self.domain);
    NSLog(@"========= End ApigeeNetworkEntry ========");
}

@end
