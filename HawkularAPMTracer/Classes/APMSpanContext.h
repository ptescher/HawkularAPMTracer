//
//  APMSpanContext.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpanContext.h>

@class APMTrace;
@interface APMSpanContext : NSObject<OTSpanContext>

@property (readonly, nonnull) NSString *traceID;
@property (readonly, nonnull) NSString *spanID;
@property (strong, nonatomic, nonnull) NSDate *startTime;
@property (strong, nonatomic, nullable) NSDate *finishTime;
@property (strong, nonatomic, nullable) APMSpanContext *parentContext;
@property (strong, nonatomic, nullable) APMTrace *trace;

- (instancetype)initWithStartTime:(NSDate *)startTime parentContext:(APMSpanContext*)parentContext;

- (void)addCarrierToTrace:(NSDictionary* _Nonnull)carrier type:(NSString*)type;

@end
