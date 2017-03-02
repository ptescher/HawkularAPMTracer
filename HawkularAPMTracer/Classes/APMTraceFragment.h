//
//  APMTrace.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class APMSpan, APMSpanContext, APMNode;
@interface APMTraceFragment : NSObject

@property (readonly, nonnull) NSDictionary* traceDictionary;
@property (readonly) bool isFinished;

- (instancetype)initWithTraceID:(NSString* _Nonnull)traceID spanID:(NSString* _Nonnull)spanID rootNode:(APMNode*)node;

@end
