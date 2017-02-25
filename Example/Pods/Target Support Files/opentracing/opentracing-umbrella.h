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

#import "OpenTracing-Bridging-Header.h"
#import "OTGlobal.h"
#import "OTNoop.h"
#import "OTReference.h"
#import "OTSpan.h"
#import "OTSpanContext.h"
#import "OTTracer.h"
#import "OTVersion.h"

FOUNDATION_EXPORT double opentracingVersionNumber;
FOUNDATION_EXPORT const unsigned char opentracingVersionString[];

