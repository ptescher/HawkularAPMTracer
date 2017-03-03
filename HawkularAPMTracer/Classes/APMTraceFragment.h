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

- (nonnull instancetype)initWithTraceID:(nonnull NSString *)traceID spanID:(nonnull NSString *)spanID rootNode:(nonnull APMNode *)node;

@end
