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
#import <opentracing/OTReference.h>

@interface APMSpan ()

@property (strong, nonatomic, nonnull) APMTracer *tracer;
@property (strong, nonatomic, nonnull) NSArray *references;
@property (strong, nonatomic, nonnull) NSDate *startTime;
@property (strong, nonatomic, nullable) NSString *operationName;
@property (strong, nonatomic, nullable) NSString *format;
@property (strong, nonatomic, nullable) APMSpanContext *context;
@property (strong, nonatomic, nonnull) NSMutableDictionary* tags;
@property (strong, nonatomic, nonnull) NSMutableArray* logs;

@end

@implementation APMSpan

+ (NSString*)generateID {
    NSString *uuidString = [[[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    return [uuidString substringToIndex:16];
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
                parentContext = (id<OTSpanContext>)reference.referencedContext;
            }
        }
        self.context = [[APMSpanContext alloc] initWithParentContext:parentContext];
        self.context.parentContext = parentContext;
        self.tags = [NSMutableDictionary new];
        self.logs = [NSMutableArray new];
        self.startTime = startTime;
    }
    return self;
}

- (void)finish {
    [self finishWithTime:[NSDate new]];
}

- (void)finishWithTime:(NSDate *)finishTime {
    NSMutableDictionary *carrier = [NSMutableDictionary new];
    carrier[@"tags"] = self.tags;
    carrier[@"logs"] = self.logs;
    carrier[@"operationName"] = self.operationName;
    carrier[@"startTime"] = self.startTime;
    carrier[@"finishTime"] = finishTime;

    [self.tracer inject:self.context format:self.format carrier:carrier error:nil];
}

- (void)logEvent:(NSString *)eventName {
    [self logEvent:eventName payload:nil];
}

- (void)logEvent:(NSString *)eventName payload:(NSObject *)payload {
    [self log:eventName timestamp:[NSDate new] payload:payload];
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
    self.tags[key] = value;
}

- (void)setTag:(NSString *)key boolValue:(BOOL)value {
    self.tags[key] = @(value);
}

- (void)setTag:(NSString *)key numberValue:(NSNumber *)value {
    self.tags[key] = value;
}

@end
