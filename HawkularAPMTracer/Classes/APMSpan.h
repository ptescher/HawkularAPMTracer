//
//  APMSpan.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpan.h>

@class APMTracer, OTReference;
@interface APMSpan : NSObject<OTSpan>

@property (readonly, nonnull) NSDate *startTime;
@property (readonly, nullable) NSDate *endTime;
@property (readonly, nonnull) NSMutableDictionary* tags;
@property (readonly, nullable) NSString *operationName;

- (nonnull instancetype)initWithTracer:(APMTracer* _Nonnull)tracer references:(NSArray<OTReference*> * _Nullable)references startTime:(NSDate * _Nonnull)startTime;
+ (nonnull NSString*)generateID;

@end
