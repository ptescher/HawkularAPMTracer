//
//  APMURLSessionTaskTracker.m
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import "APMURLSessionTaskTracker.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTTracer.h>
#import <opentracing/OTSpan.h>

@implementation APMURLSessionTaskTracker

+ (NSDictionary*)tagsFromTask:(NSURLSessionTask *)task {
    NSMutableDictionary *tags = [NSMutableDictionary new];
    tags[@"node.uri"] = task.originalRequest.URL;
    tags[@"http.method"] = task.originalRequest.HTTPMethod;
    if ([task.response isMemberOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = ((NSHTTPURLResponse*)task.response).statusCode;
        tags[@"http.status_code"] = @(statusCode);
    }
    tags[@"service"] = [NSBundle mainBundle].infoDictionary[@"CFBundleName"] ?: @"unknown-app";
    tags[@"buildStamp"] = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    return [tags copy];
}

+ (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    NSParameterAssert(task.originalRequest);
    id<OTSpanContext> parentContext = [[OTGlobal sharedTracer] extractWithFormat:OTFormatHTTPHeaders carrier:task.originalRequest.allHTTPHeaderFields];

    if (parentContext == nil) {
        return;
    }

    id<OTSpan> metricsSpan = [[OTGlobal sharedTracer] startSpan:@"Task Metrics" childOf:parentContext tags:[self tagsFromTask:task] startTime:metrics.taskInterval.startDate];

    for (NSURLSessionTaskTransactionMetrics *metric in metrics.transactionMetrics) {
        [self trackMetrics:metric tags:[self tagsFromTask:task] parentContext:metricsSpan.context];
    }

    [metricsSpan finishWithTime:metrics.taskInterval.endDate];

    NSMutableDictionary *carrier = [NSMutableDictionary new];
    carrier[@"tags"] = [self tagsFromTask:task];
    carrier[@"operationName"] = task.originalRequest.HTTPMethod;
    carrier[@"startTime"] = metrics.taskInterval.startDate;
    carrier[@"finishTime"] = metrics.taskInterval.endDate;
    carrier[@"node.type"] = @"Producer";
    carrier[@"node.endpointType"] = task.originalRequest.URL.scheme.uppercaseString;

    [[OTGlobal sharedTracer] inject:parentContext format:OTFormatHTTPHeaders carrier:carrier];
}

+ (void)trackMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Transaction Metrics" childOf:parentContext tags:tags startTime:metrics.fetchStartDate];

    [span setTag:@"network.protocol.name" value:metrics.networkProtocolName];
    [span setTag:@"connection.refused" boolValue:metrics.reusedConnection];
    [span setTag:@"connection.proxy" boolValue:metrics.proxyConnection];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"Metrics"];

    switch (metrics.resourceFetchType) {
            case NSURLSessionTaskMetricsResourceFetchTypeUnknown:
            [span setTag:@"resource.fetch.type" value:@"Unknown"];
            break;
            case NSURLSessionTaskMetricsResourceFetchTypeLocalCache:
            [span setTag:@"resource.fetch.type" value:@"Local Cache"];
            break;
            case NSURLSessionTaskMetricsResourceFetchTypeServerPush:
            [span setTag:@"resource.fetch.type" value:@"Server Push"];
            break;
            case NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad:
            [span setTag:@"resource.fetch.type" value:@"Network Load"];
            break;
    }

    if (metrics.domainLookupStartDate != nil) {
        [self trackDomainLookupMetrics:metrics tags:tags parentContext:span.context];
    }
    if (metrics.connectStartDate != nil) {
        [self trackConnectionMetrics:metrics tags:tags parentContext:span.context];
    }
    if (metrics.requestStartDate != nil) {
        [self trackHTTPMetrics:metrics tags:tags parentContext:span.context];
    }

    [span log:@"Fetch Start" timestamp:metrics.fetchStartDate payload:nil];

    [span finishWithTime:metrics.responseEndDate ?: metrics.fetchStartDate];
}

+ (void)trackDomainLookupMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Domain Lookup" childOf:parentContext tags:tags startTime:metrics.domainLookupStartDate];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"DNS"];
    [span finishWithTime:metrics.domainLookupEndDate];
}

+ (void)trackConnectionMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Connect" childOf:parentContext tags:tags startTime:metrics.connectStartDate];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"TCP"];
    if (metrics.secureConnectionStartDate) {
        [self trackSecureConnectionMetrics:metrics tags:tags parentContext:span.context];
    }
    [span finishWithTime:metrics.connectEndDate];
}

+ (void)trackSecureConnectionMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Secure Connection" childOf:parentContext tags:tags startTime:metrics.secureConnectionStartDate];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"TLS"];
    [span finishWithTime:metrics.secureConnectionEndDate];
}

+ (void)trackHTTPMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Protocol" childOf:parentContext tags:tags startTime:metrics.requestStartDate];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"HTTP"];
    if (metrics.requestStartDate != nil) {
        [self trackRequestMetrics:metrics tags:tags parentContext:span.context];
    }
    if (metrics.responseStartDate != nil) {
        [self trackResponseMetrics:metrics tags:tags parentContext:span.context];
    }
    [span finishWithTime:metrics.responseEndDate];
}


+ (void)trackRequestMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Request" childOf:parentContext tags:tags startTime:metrics.requestStartDate];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"Request"];
    [span finishWithTime:metrics.requestEndDate];
}

+ (void)trackResponseMetrics:(NSURLSessionTaskTransactionMetrics*)metrics tags:(NSDictionary*)tags parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Response" childOf:parentContext tags:tags startTime:metrics.responseStartDate];
    [span setTag:@"node.type" value:@"Component"];
    [span setTag:@"node.componentType" value:@"Response"];
    [span finishWithTime:metrics.responseEndDate];
}

@end
