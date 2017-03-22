//
//  APMSpan.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMSpan.h"
#import "APMTracer.h"
#import "APMSpanContext.h"
#import "APMRecorder.h"
#import "APMTraceFragment.h"
#import <opentracing/OTReference.h>

@interface APMSpan ()

@property (strong, nonatomic, nonnull) APMTracer *tracer;
@property (strong, nonatomic, nonnull) NSArray *references;
@property (strong, nonatomic, nonnull) NSDate *startTime;
@property (strong, nonatomic, nullable) NSDate *endTime;
@property (strong, nonatomic, nullable) NSString *operationName;
@property (strong, nonatomic, nullable) NSString *format;
@property (strong, nonatomic, nullable) APMSpanContext *context;
@property (strong, nonatomic, nonnull) NSMutableDictionary* tags;
@property (strong, nonatomic, nonnull) NSMutableArray* logs;

@end

@implementation APMSpan

+ (NSString*)generateID {
    NSString *uuidString = [[NSUUID UUID].UUIDString lowercaseString];
    return uuidString;
}

- (instancetype)initWithTracer:(APMTracer *)tracer references:(NSArray<OTReference*> *)references startTime:(NSDate *)startTime {
    NSParameterAssert(tracer);
    NSParameterAssert(startTime);
    self = [super init];
    if (self) {
        self.tracer = tracer;
        self.references = references;
        APMSpanContext *parentContext = nil;
        for (OTReference *reference in references) {
            if (reference != nil && ([reference.type isEqualToString:OTReferenceChildOf] || [reference.type isEqualToString:OTReferenceFollowsFrom])) {
                NSAssert([((id)reference.referencedContext) class] == [APMSpanContext class], @"Parent should be an APMSpanContext");
                if ([((id)reference.referencedContext) class] == [APMSpanContext class]) {
                    parentContext = (APMSpanContext*)reference.referencedContext;
                }
            }
        }
        self.context = [[APMSpanContext alloc] initWithParentContext:parentContext];
        self.context.parentContext = parentContext;
        self.tags = [NSMutableDictionary new];
        self.logs = [NSMutableArray new];
        self.startTime = startTime;
        [self loadDefaultTags];
    }
    return self;
}

- (void)loadDefaultTags {
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    self.tags[@"service"] = bundleInfo[@"CFBundleName"];
    self.tags[@"buildStamp"] = bundleInfo[@"CFBundleShortVersionString"];
    self.tags[@"span.kind"] = @"client";
    if ([UIDevice class]) {
        self.tags[@"device.systemName"] = [UIDevice currentDevice].systemName;
        self.tags[@"device.systemVersion"] = [UIDevice currentDevice].systemVersion;
        self.tags[@"device.model"] = [UIDevice currentDevice].model;
        self.tags[@"device.identifierForVendor"] = [[UIDevice currentDevice].identifierForVendor UUIDString].lowercaseString;
    }
}

- (void)finish {
    [self finishWithTime:[NSDate new]];
}

- (void)finishWithTime:(NSDate *)finishTime {
    self.endTime = finishTime;
    
    @try {
        [self.tracer.recorder addNodeForSpan:self];
    } @catch (NSException *exception) {
        NSLog(@"Exception finishing span: %@", exception);
    }
}

- (void)log:(NSDictionary<NSString *,NSObject *> *)fields {
    [self log:fields timestamp:nil];
}

- (void)logEvent:(NSString *)eventName {
    [self logEvent:eventName payload:nil];
}

- (void)logEvent:(NSString *)eventName payload:(NSObject *)payload {
    [self log:eventName timestamp:[NSDate new] payload:payload];
}

- (void)log:(NSDictionary<NSString *,NSObject *> *)fields timestamp:(NSDate *)timestamp {
    for (NSString *key in fields.allKeys) {
        [self log:key timestamp: timestamp payload:fields[key]];
    }
}

- (void)log:(NSString *)eventName timestamp:(NSDate *)timestamp payload:(NSObject *)payload {
    NSDictionary *log = @{
                          @"eventName": eventName,
                          @"timestamp": @([timestamp timeIntervalSince1970] * 1000000),
                          @"payload": payload ?: [NSNull new]
                          };
    [self.logs addObject:log];
}

- (void)setTag:(NSString *)key value:(NSString *)value {
    if ([key isEqualToString:@"transaction"]) {
        self.context.transaction = value;
    } else {
        self.tags[key] = value;
    }
}

- (void)setTag:(NSString *)key boolValue:(BOOL)value {
    self.tags[key] = @(value);
}

- (void)setTag:(NSString *)key numberValue:(NSNumber *)value {
    self.tags[key] = value;
}

- (id<OTSpan>)setBaggageItem:(NSString *)key value:(NSString *)value {
    NSLog(@"Not yet implemented");
    return nil;
}

- (NSString *)getBaggageItem:(NSString *)key {
    NSLog(@"Not yet implemented");
    return nil;
}

@end
