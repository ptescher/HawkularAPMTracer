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

- (instancetype)initWithTraceID:(NSString* _Nonnull)traceID;

- (void)addNodeWithSpanContext:(APMSpanContext*)spanContext carrier:(NSDictionary*)carrier type:(NSString*)type;

@end
