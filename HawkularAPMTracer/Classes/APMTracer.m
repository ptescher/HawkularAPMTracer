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

@property (strong, nonatomic, nonnull) NSMutableSet *orphanedNodes;
@property (strong, nonatomic, nonnull) NSMutableSet *unfinishedSpanContexts;
@property (strong, nonatomic, nonnull) APMRecorder *recorder;

- (void)addNodeWithSpanContext:(APMSpanContext*)spanContext carrier:(NSDictionary*)carrier type:(NSString*)type startTime:(NSDate* _Nonnull)startTime finishTime:(NSDate* _Nullable)finishTime;

@end

@implementation APMTracer

+ (void)setup:(NSURL *)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    APMTracer *tracer = [[APMTracer alloc] initWithAPMURL:apmURL credential:credential flushInterval: flushInterval];
    [OTGlobal initSharedTracer:tracer];
}

- (instancetype)initWithAPMURL:(NSURL*)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    self = [super init];
    if (self) {
        self.recorder = [[APMRecorder alloc] initWithURL:apmURL credential:credential flushInterval:flushInterval timeoutInterval:10];
        self.orphanedNodes = [NSMutableSet new];
        self.unfinishedSpanContexts = [NSMutableSet new];
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
    span.operationName = operationName;
    for (NSString *key in tags.allKeys) {
        [span setTag:key value:tags[key]];
    }
    [self.unfinishedSpanContexts addObject:span.context];
    return span;
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier {
    return [self inject:spanContext format:format carrier:carrier error: nil];
}

- (nullable APMNode*)findNodeWithContext:(APMSpanContext*)spanContext inNodes:(NSArray<APMNode*>*)nodes {
    for (APMNode *node in nodes) {
        if (node.spanContext == spanContext) {
            return node;
        }
        APMNode *childNode = [self findNodeWithContext:spanContext inNodes:node.childNodes];
        if (childNode != nil) {
            return childNode;
        }
    }
    return nil;
}

- (BOOL)addNodeWithSpanContext:(APMSpanContext *)spanContext carrier:(NSDictionary *)carrier type:(NSString *)type startTime:(NSDate *)startTime finishTime:(NSDate *)finishTime error:(NSError * _Nullable __autoreleasing *)outError {
    APMNode *node = [[APMNode alloc] initWithSpanContext:spanContext type:type];
    node.timestamp = startTime;
    node.duration = [finishTime timeIntervalSinceDate:startTime] ?: 0;
    NSAssert(node.duration >= 0, @"Duration must be positive");
    [node parseCarrier:carrier type:type];

    NSSet *children = [self.orphanedNodes filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"spanContext.parentContext == %@", spanContext]];
    for (APMNode *child in children) {
        [node addChildNode:child];
        [self.orphanedNodes removeObject:child];
    }

    if (spanContext.parentContext == nil || ![self.unfinishedSpanContexts containsObject:spanContext.parentContext]) {
        APMTraceFragment *fragment = [[APMTraceFragment alloc] initWithTraceID:spanContext.traceID spanID:spanContext.spanID rootNode: node];
        [self.recorder addFragment:fragment error:outError];
    } else {
        [self.orphanedNodes addObject:node];
    }
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    NSParameterAssert(spanContext);

    if ([(APMSpanContext*)spanContext isKindOfClass:[APMSpanContext class]]) {
        APMSpanContext *apmSpanContext = (APMSpanContext*)spanContext;
        [self.unfinishedSpanContexts removeObject:apmSpanContext];
        NSDictionary *tags = carrier[@"tags"];
        NSString *type = tags[@"node.type"] ?: @"Component";
        NSDate *startTime = carrier[@"startTime"];
        NSDate *finishTime = carrier[@"finishTime"];
        return [self addNodeWithSpanContext:apmSpanContext carrier:carrier type:type startTime:startTime finishTime:finishTime error:outError];
    } else {
        return @NO;
    }
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier {
    return [self extractWithFormat:format carrier:carrier error:nil];
}

- (APMSpanContext*)extractWithFormat:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    if ([format isEqualToString:OTFormatHTTPHeaders] && [carrier isKindOfClass:[NSDictionary class]]) {
        NSDictionary *headers = (NSDictionary*)carrier;
        NSString *traceID = headers[@"X-B3-TraceId"];
        NSString *spanID = headers[@"X-B3-SpanId"];
        NSString *parentSpanID = headers[@"X-B3-ParentSpanId"];
        NSString *sampled = headers[@"X-B3-Sampled"];
        NSString *transaction = headers[@"X-B3-Transaction"];
        if (traceID != nil && spanID != nil) {
            APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID spanID:spanID];
            context.transaction = transaction;
            if (parentSpanID != nil && traceID != nil) {
                NSMutableDictionary *parentHeaders = @{
                                          @"X-B3-TraceId": traceID,
                                          @"X-B3-SpanId": parentSpanID,
                                          }.mutableCopy;
                parentHeaders[@"X-B3-Sampled"] = sampled;
                parentHeaders[@"X-B3-Transaction"] = transaction;
                context.parentContext = [self extractWithFormat:OTFormatHTTPHeaders carrier:parentHeaders error:outError];
            }
            return context;
        } else {
            return nil;
        }
    }
    if ([format isEqualToString:OTFormatTextMap] && [carrier isKindOfClass:[NSDictionary class]]) {
        NSDictionary *headers = (NSDictionary*)carrier;
        NSString *traceID = headers[@"HWKAPMTRACEID"];
        APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID spanID:[APMSpan generateID]];
        return context;
    }
    return nil;
}

@end
