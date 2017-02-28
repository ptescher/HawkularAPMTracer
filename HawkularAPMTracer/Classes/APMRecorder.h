//
//  APMRecorder.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpanContext.h>

@class APMTrace;
@interface APMRecorder : NSObject

- (instancetype)initWithURL:(NSURL *)baseURL credential:(NSURLCredential*)credential flushInterval:(NSTimeInterval)flushInterval timeoutInterval:(NSTimeInterval)timeoutInterval;
- (BOOL)addTrace:(APMTrace* _Nonnull)trace error:(NSError * _Nullable __autoreleasing *)outError;

@end
