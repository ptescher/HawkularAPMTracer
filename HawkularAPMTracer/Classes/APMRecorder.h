//
//  APMRecorder.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpanContext.h>

@class APMTraceFragment;
@interface APMRecorder : NSObject

- (nonnull instancetype)initWithURL:(NSURL* _Nonnull)baseURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval timeoutInterval:(NSTimeInterval)timeoutInterval;
- (BOOL)addFragment:(APMTraceFragment* _Nonnull)trace error:(NSError * _Nullable __autoreleasing *)outError;

@end
