//
//  APMTrace.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class APMSpan, APMSpanContext;
@interface APMTrace : NSObject

@property (readonly, nonnull) NSDictionary* traceDictionary;
@property (readonly) bool isFinished;

@property (strong, nonatomic, nullable) NSString *transaction;

- (instancetype)initWithTraceID:(NSString* _Nonnull)traceID spanID:(NSString* _Nonnull)spanID;

- (void)addNodeWithSpanContext:(APMSpanContext*)spanContext carrier:(NSDictionary*)carrier type:(NSString*)type startTime:(NSDate* _Nonnull)startTime finishTime:(NSDate* _Nullable)finishTime;

@end
