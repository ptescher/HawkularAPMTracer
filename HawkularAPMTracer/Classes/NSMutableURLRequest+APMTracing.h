//
//  NSMutableURLRequest+APMTracing.h
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 3/14/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpan.h>
#import <opentracing/OTSpanContext.h>

@interface NSMutableURLRequest (APMTracing)

- (nonnull id<OTSpan>)startSpanWithParentContext:(nullable id<OTSpanContext>)parent;

@end
