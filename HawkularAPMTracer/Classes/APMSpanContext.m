//
//  APMSpanContext.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMSpanContext.h"
#import "APMTrace.h"
#import "APMSpan.h"

@interface APMSpanContext ()

@property (strong, nonatomic, nonnull) NSString *traceID;
@property (strong, nonatomic, nonnull) NSString *spanID;

@end

@implementation APMSpanContext

- (instancetype)initWithStartTime:(NSDate *)startTime parentContext:(APMSpanContext *)parentContext {
    self = [super init];
    if (self) {
        self.startTime = startTime;
        self.traceID = parentContext.traceID ?: [APMSpan generateID];
        self.spanID = [APMSpan generateID];
        self.parentContext = parentContext;
    }
    return self;
}

- (APMTrace *)addCarrierToTrace:(NSDictionary *)carrier type:(NSString*)type {
    [self.trace addNodeWithSpanContext:self carrier:carrier type:type];
}

- (APMTrace *)trace {
    return self.parentContext.trace ?: _trace ?: [self generateTrace];
}

- (APMTrace *)generateTrace {
    APMTrace *trace = [[APMTrace alloc] initWithTraceID:self.traceID];
    _trace = trace;
    return trace;
}

@end
