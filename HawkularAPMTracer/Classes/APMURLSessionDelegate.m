//
//  APMURLSessionDelegate.m
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import "APMURLSessionDelegate.h"
#import "APMURLSessionTaskTracker.h"

@implementation APMURLSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    [APMURLSessionTaskTracker URLSession:session task:task didFinishCollectingMetrics:metrics];
}

@end
