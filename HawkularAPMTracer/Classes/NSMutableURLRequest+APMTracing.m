//
//  NSMutableURLRequest+APMTracing.m
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 3/14/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import "NSMutableURLRequest+APMTracing.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTTracer.h>

@implementation NSMutableURLRequest (APMTracing)

- (id<OTSpan>)startSpanWithParentContext:(id<OTSpanContext>)parent {
    NSMutableDictionary *tags = [NSMutableDictionary new];
    tags[@"http.url"] = self.URL.absoluteString;
    tags[@"http.method"] = self.HTTPMethod;

    NSString *spanName = self.HTTPMethod ?: @"Other";
    id<OTSpan> span = [[OTGlobal sharedTracer] startSpan:spanName childOf:parent tags:[tags copy]];

    NSMutableDictionary *headers = [NSMutableDictionary new];
    [[OTGlobal sharedTracer] inject:[span context] format:OTFormatHTTPHeaders carrier:headers];

    for (NSString *key in headers.allKeys) {
        [self setValue:headers[key] forHTTPHeaderField:key];
    }

    return span;
}

@end
