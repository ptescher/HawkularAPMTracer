//
//  APMTracer.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMTracer.h"
#import "APMSpan.h"
#import "APMRecorder.h"
#import "APMSpanContext.h"
#import "APMTraceFragment.h"
#import "APMNode.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTReference.h>

@interface APMTracer ()

@property (strong, nonatomic, nonnull) APMRecorder *recorder;

@end

@implementation APMTracer

+ (void)setup:(NSURL *)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    APMTracer *tracer = [[APMTracer alloc] initWithAPMURL:apmURL credential:credential flushInterval: flushInterval];
    [OTGlobal initSharedTracer:tracer];
}

- (void)flush:(void (^)(NSError * _Nullable))completionHandler {
    [self.recorder send:completionHandler];
}

- (void)flush {
    [self flush:nil];
}

- (instancetype)initWithAPMURL:(NSURL*)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    self = [super init];
    if (self) {
        self.recorder = [[APMRecorder alloc] initWithURL:apmURL credential:credential flushInterval:flushInterval timeoutInterval:10];
    }
    return self;
}

- (id<OTSpan>)startSpan:(NSString *)operationName {
    return [self startSpan:operationName childOf:nil tags:nil startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName tags:(NSDictionary *)tags {
    return [self startSpan:operationName childOf:nil tags:tags startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent {
    return [self startSpan:operationName childOf:parent tags:nil startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent tags:(NSDictionary *)tags {
    return [self startSpan:operationName childOf:parent tags:tags startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName
                childOf:(id<OTSpanContext>)parent
                   tags:(NSDictionary *)tags
              startTime:(NSDate *)startTime {
    if (parent == nil) {
        return [self startSpan:operationName references:nil tags:tags startTime:startTime];
    }
    return [self startSpan:operationName references:@[[OTReference childOf:parent]] tags:tags startTime:startTime];
}

- (id<OTSpan>)startSpan:(NSString *)operationName
             references:(NSArray *)references
                   tags:(NSDictionary *)tags
              startTime:(NSDate *)startTime {


    APMSpan *span = [[APMSpan alloc] initWithTracer:self references:references startTime:startTime];

    @try {
        span.operationName = operationName;
        for (NSString *key in tags.allKeys) {
            [span setTag:key value:tags[key]];
        }
        if (self.recorder.unfinishedSpanContexts.count < APMRecorderMaxUnfinishedSpans) {
            [self.recorder.unfinishedSpanContexts addObject:span.context];
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception adding span: %@", exception);
    }

    return span;
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier {
    return [self inject:spanContext format:format carrier:carrier error: nil];
}

- (NSUInteger)siblingIndexOfSpanContext:(APMSpanContext*)spanContext {
    NSPredicate *siblingNodePredicate = [NSPredicate predicateWithFormat:@"spanContext.parentContext == %@", spanContext.parentContext];
    NSOrderedSet *siblingNodes = [self.recorder.orphanedNodes filteredOrderedSetUsingPredicate:siblingNodePredicate];

    if ([siblingNodes containsObject:spanContext]) {
        return [siblingNodes indexOfObject:spanContext];
    }

    NSPredicate *siblingSpanPredicate = [NSPredicate predicateWithFormat:@"parentContext == %@", spanContext.parentContext];
    NSOrderedSet *sublingUnfinishedSpanContexts = [self.recorder.unfinishedSpanContexts filteredOrderedSetUsingPredicate:siblingSpanPredicate];

    if ([sublingUnfinishedSpanContexts containsObject:spanContext]) {
        return [sublingUnfinishedSpanContexts indexOfObject:spanContext] + siblingNodes.count;
    }

    return 0;
}

- (NSString*)nodeIDForSpanContext:(APMSpanContext*)spanContext {
    if (![self.recorder.unfinishedSpanContexts containsObject:spanContext]) {
        // We haven't seen this span context so we can't generate a node ID
        return spanContext.spanID;
    }

    if (spanContext.parentContext != nil && [self.recorder.unfinishedSpanContexts containsObject:spanContext.parentContext]) {
        NSString *parentRelativeSpanID = [self nodeIDForSpanContext:spanContext.parentContext];
        NSUInteger siblingIndex = [self siblingIndexOfSpanContext:spanContext];
        return [NSString stringWithFormat: @"%@:%@", parentRelativeSpanID, @(siblingIndex)];
    }

    // Assume we are the root span for a fragment
    return [NSString stringWithFormat: @"%@:0", spanContext.spanID];
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    NSParameterAssert(spanContext);

    if (![(id)spanContext isKindOfClass:[APMSpanContext class]]) {
        return NO;
    }

    APMSpanContext *apmSpanContext = (APMSpanContext*)spanContext;
    apmSpanContext.hasBeenInjected = true;

    if ([format isEqualToString:OTFormatHTTPHeaders] && [carrier isKindOfClass:[NSMutableDictionary class]]) {
        NSMutableDictionary *headers = (NSMutableDictionary*)carrier;
        if (apmSpanContext.interactionID == nil) {
            apmSpanContext.interactionID = [APMSpan generateID];
        }
        headers[@"HWKAPMID"] = apmSpanContext.interactionID;
        headers[@"HWKAPMTRACEID"] = apmSpanContext.traceID;
        headers[@"HWKAPMLEVEL"] = apmSpanContext.level;
        headers[@"HWKAPMTXN"] = apmSpanContext.transaction;
        return YES;
    }
    return NO;
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier {
    return [self extractWithFormat:format carrier:carrier error:nil];
}

- (APMSpanContext*)extractWithFormat:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    if (([format isEqualToString:OTFormatHTTPHeaders] || [format isEqualToString:OTFormatTextMap]) && [carrier isKindOfClass:[NSDictionary class]]) {
        NSDictionary *headers = (NSDictionary*)carrier;

        NSString *interactionID = headers[@"HWKAPMID"];
        NSString *traceID = headers[@"HWKAPMTRACEID"];
        NSString *level = headers[@"HWKAPMLEVEL"];
        NSString *transaction = headers[@"HWKAPMTXN"];

        if (traceID != nil) {
            APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID interactionID:interactionID];
            context.transaction = transaction;
            context.level = level;
            context.hasBeenExtracted = true;
            return context;
        } else {
            return nil;
        }
    }

    return nil;
}

@end
