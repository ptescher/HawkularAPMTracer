//
//  APMURLSessionTaskTracker.h
//  HawkularAPMTracer
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 pat2man. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APMURLSessionTaskTracker : NSObject

+ (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics;

@end
