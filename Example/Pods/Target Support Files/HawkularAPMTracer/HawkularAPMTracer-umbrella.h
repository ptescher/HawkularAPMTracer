#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "APMNode.h"
#import "APMRecorder.h"
#import "APMSpan.h"
#import "APMSpanContext.h"
#import "APMTrace.h"
#import "APMTracer.h"
#import "APMURLSessionDelegate.h"
#import "APMURLSessionTaskTracker.h"

FOUNDATION_EXPORT double HawkularAPMTracerVersionNumber;
FOUNDATION_EXPORT const unsigned char HawkularAPMTracerVersionString[];

