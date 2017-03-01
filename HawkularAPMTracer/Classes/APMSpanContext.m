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

- (instancetype)initWithTraceID:(NSString *)traceID spanID:(NSString *)spanID {
    self = [super init];
    if (self) {
        self.traceID = spanID;
        self.spanID = spanID;
    }
    return self;
}

- (instancetype)initWithParentContext:(APMSpanContext *)parentContext {
    self = [super init];
    if (self) {
        if (parentContext == nil) {
            NSString *spanID = [APMSpan generateID];
            self.traceID = spanID;
            self.spanID = spanID;
        } else {
            self.parentContext = parentContext;
            self.traceID = parentContext.traceID;
            self.spanID = [APMSpan generateID];
        }
    }
    return self;
}

- (APMTrace *)trace {
    return self.parentContext.trace ?: _trace ?: [self generateTrace];
}

- (APMTrace *)generateTrace {
    APMTrace *trace = [[APMTrace alloc] initWithTraceID:self.traceID spanID:self.spanID];
    trace.transaction = self.transaction;
    _trace = trace;
    return trace;
}

@end
