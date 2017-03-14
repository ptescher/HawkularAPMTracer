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

+ (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    NSParameterAssert(task.originalRequest);
    id<OTSpanContext> parentContext = [[OTGlobal sharedTracer] extractWithFormat:OTFormatHTTPHeaders carrier:task.originalRequest.allHTTPHeaderFields];

    if (parentContext == nil) {
        return;
    }

    for (NSURLSessionTaskTransactionMetrics *metric in metrics.transactionMetrics) {
        [self trackMetrics:metric parentContext:parentContext];
    }
}

+ (void)trackMetrics:(NSURLSessionTaskTransactionMetrics*)metrics parentContext:(id<OTSpanContext>)parentContext {
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:@"Metrics" childOf:parentContext tags:nil startTime:metrics.fetchStartDate];

    [span setTag:@"http.url" value:metrics.request.URL.absoluteString];
    [span setTag:@"http.method" value:metrics.request.HTTPMethod];

    [span setTag:@"network.protocol.name" value:metrics.networkProtocolName];
    [span setTag:@"connection.refused" boolValue:metrics.reusedConnection];
    [span setTag:@"connection.proxy" boolValue:metrics.proxyConnection];
    [span setTag:@"node.componentType" value:@"URL Session Task Transaction"];

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

    [span log:@"Fetch Start" timestamp:metrics.fetchStartDate payload:nil];

    [span log:@"Domain Lookup Start" timestamp:metrics.domainLookupStartDate payload:nil];
    [span log:@"Domain Lookup End" timestamp:metrics.domainLookupEndDate payload:nil];

    [span log:@"Connect Start" timestamp:metrics.connectStartDate payload:nil];
    [span log:@"Secure Connection Start" timestamp:metrics.secureConnectionStartDate payload:nil];
    [span log:@"Secure Connection End" timestamp:metrics.secureConnectionEndDate payload:nil];
    [span log:@"Connect End" timestamp:metrics.connectEndDate payload:nil];

    [span log:@"Request Start" timestamp:metrics.requestStartDate payload:nil];
    [span log:@"Request End" timestamp:metrics.requestEndDate payload:nil];

    [span log:@"Response Start" timestamp:metrics.responseStartDate payload:nil];
    [span log:@"Response End" timestamp:metrics.responseEndDate payload:nil];

    [span finishWithTime:metrics.responseEndDate ?: metrics.fetchStartDate];
}

@end
