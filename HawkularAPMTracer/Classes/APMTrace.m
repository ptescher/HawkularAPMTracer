//
//  APMTrace.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMTrace.h"
#import "APMNode.h"
#import "APMSpanContext.h"
#import "APMSpan.h"

@interface APMTrace ()

@property (strong, nonatomic, nonnull) NSMutableArray<APMNode*> *rootNodes;
@property (strong, nonatomic, nonnull) NSMutableArray<APMNode*> *orphanedNodes;
@property (strong, nonatomic, nonnull) NSString *fragmendID;
@property (strong, nonatomic, nullable) NSString *hostAddress;
@property (readonly, nullable) NSDate *timestamp;
@property (strong, nonatomic, nullable) NSString *traceID;
@property (nonatomic) bool isFinished;

@end

@implementation APMTrace

- (instancetype)initWithTraceID:(NSString* _Nonnull)traceID spanID:(NSString*)spanID {
    self = [super init];
    if (self) {
        self.rootNodes = [NSMutableArray<APMNode*> new];
        self.orphanedNodes = [NSMutableArray<APMNode*> new];
        self.traceID = traceID;
        self.isFinished = false;
        self.fragmendID = spanID;
    }
    return self;
}

- (NSDate *)timestamp {
    return [self.rootNodes valueForKeyPath:@"@min.timestamp"];
}

- (NSDictionary *)traceDictionary {
    NSMutableDictionary *traceDictionary = [[NSMutableDictionary alloc] initWithCapacity:7];
    traceDictionary[@"fragmentId"] = self.fragmendID;
    traceDictionary[@"hostAddress"] = self.hostAddress;
    traceDictionary[@"nodes"] = [self.rootNodes valueForKeyPath:@"@unionOfObjects.nodeDictionary"];
    traceDictionary[@"timestamp"] = self.timestamp == nil ? nil : [NSNumber numberWithLong: [self.timestamp timeIntervalSince1970] * 1000000];
    traceDictionary[@"traceId"] = self.traceID;
    traceDictionary[@"transaction"] = self.transaction;
    return [traceDictionary copy];
}

- (void)addNodeWithSpanContext:(APMSpanContext*)spanContext carrier:(NSDictionary*)carrier type:(NSString*)type startTime:(NSDate* _Nonnull)startTime finishTime:(NSDate* _Nullable)finishTime {
    APMNode *node = [[APMNode alloc] initWithSpanContext:spanContext type:type];
    node.timestamp = startTime;
    node.duration = [finishTime timeIntervalSinceDate:startTime] ?: 0;
    NSAssert(node.duration >= 0, @"Duration must be positive");
    node.operation = carrier[@"operationName"];

    NSString *interactionID = carrier[@"interactionID"];
    if (interactionID != nil) {
        APMCorrelationIdentifier *interactionIdentifier = [[APMCorrelationIdentifier alloc] initWithScope:@"Interaction" value:interactionID];
        [node addCorrelationIdentifier:interactionIdentifier];
    }

    NSDictionary *tags = carrier[@"tags"];
    for (NSString *key in tags.allKeys) {
        if ([key isEqualToString:@"node.uri"]) {
            NSURL *uri = tags[key];
            node.uri = uri;
            APMProperty *uriProperty = [APMProperty new];
            uriProperty.name = @"http.uri";
            uriProperty.value = uri.path;
            uriProperty.type = @"Text";
            [node addProperty:uriProperty];
            APMProperty *urlProperty = [APMProperty new];
            urlProperty.name = @"http.url";
            urlProperty.value = uri.absoluteString;
            urlProperty.type = @"Text";
            [node addProperty:urlProperty];
            APMProperty *pathProperty = [APMProperty new];
            pathProperty.name = @"http.path";
            pathProperty.value = uri.path;
            pathProperty.type = @"Text";
            [node addProperty:pathProperty];
        } else if ([key isEqualToString:@"node.operation"]) {
            node.operation = tags[key];
        } else if ([key isEqualToString:@"node.endpointType"]) {
            node.endpointType = tags[key];
        } else if ([key isEqualToString:@"node.componentType"]) {
            node.componentType = tags[key];
        } else if ([key isEqualToString:@"node.type"]) {
            // node.type = tags[key];
        } else {
            APMProperty *property = [APMProperty new];
            property.name = key;
            if ([tags[key] isKindOfClass:[NSString class]]) {
                property.type = @"Text";
                property.value = tags[key];
            } else {
                NSValue *value = tags[key];
                NSString *type = [NSString stringWithCString:value.objCType encoding:NSUTF8StringEncoding];
                if ([type isEqualToString:@"c"]) {
                    property.type = @"Boolean";
                    property.value = ((NSNumber*)tags[key]).boolValue ? @"true": @"false";
                    property.number = tags[key];
                } else if ([type isEqualToString:@"q"] || [type isEqualToString:@"d"]) {
                    property.type = @"Number";
                    property.number = tags[key];
                } else {
                    NSLog(@"Don't know how to encode %@", type);
                }
            }
            [node addProperty:property];
        }
    }

    NSArray *children = [self.orphanedNodes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"spanContext.parentContext == %@", spanContext]];
    for (APMNode *child in children) {
        [node addChildNode:child];
        [self.orphanedNodes removeObject:child];
    }

    if (spanContext.parentContext == nil) {
        [self.rootNodes addObject:node];
        self.isFinished = true;
    } else {
        APMNode *parentNode = [self findNodeWithContext:spanContext.parentContext inNodes:self.rootNodes];
        if (parentNode == nil) {
            [self.orphanedNodes addObject:node];
        } else {
            [parentNode addChildNode:node];
        }
    }
}

- (nullable APMNode*)findNodeWithContext:(APMSpanContext*)spanContext inNodes:(NSArray<APMNode*>*)nodes {
    for (APMNode *node in nodes) {
        if (node.spanContext == spanContext) {
            return node;
        }
        APMNode *childNode = [self findNodeWithContext:spanContext inNodes:node.childNodes];
        if (childNode != nil) {
            return childNode;
        }
    }
    return nil;
}

@end
