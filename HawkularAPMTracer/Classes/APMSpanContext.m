//
//  APMSpanContext.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMSpanContext.h"
#import "APMTraceFragment.h"
#import "APMSpan.h"

@interface APMSpanContext ()

@property (strong, nonatomic, nonnull) NSString *traceID;
@property (strong, nonatomic, nonnull) NSString *spanID;

@end

@implementation APMSpanContext

- (instancetype)initWithTraceID:(NSString *)traceID interactionID:(NSString *)interactionID {
    self = [super init];
    if (self) {
        self.traceID = traceID;
        self.interactionID = interactionID;
        self.spanID = [APMSpan generateID];
        self.hasBeenInjected = false;
        self.hasBeenExtracted = false;
    }
    return self;
}

- (instancetype)initWithParentContext:(APMSpanContext *)parentContext {
    self = [super init];
    if (self) {
        self.spanID = [APMSpan generateID];
        self.parentContext = parentContext;

        if (parentContext != nil) {
            self.traceID = parentContext.traceID;
        } else {
            self.traceID = self.spanID;
        }

        NSString *defaultLevel = @"All";

        self.level = parentContext.level ?: defaultLevel;
        self.transaction = parentContext.transaction;
        self.hasBeenInjected = false;
        self.hasBeenExtracted = false;
    }
    return self;
}

- (void)forEachBaggageItem:(BOOL (^)(NSString * _Nonnull, NSString * _Nonnull))callback {
    NSLog(@"Not implemented");
}

@end
