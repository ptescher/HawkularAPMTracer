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
@property (strong, nonatomic, nullable) APMSpanContext *parentContext;
@property (strong, nonatomic, nullable) NSString *transaction;

- (nonnull instancetype)initWithTraceID:(NSString* _Nonnull)traceID spanID:(NSString* _Nonnull)spanID;
- (nonnull instancetype)initWithParentContext:(APMSpanContext* _Nullable)parentContext;

@end
