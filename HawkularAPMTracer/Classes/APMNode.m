//
//  APMNode.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMNode.h"
#import "APMSpan.h"
#import "APMSpanContext.h"

@interface APMCorrelationIdentifier ()

@property (strong, nonatomic, nonnull) NSString *scope;
@property (strong, nonatomic, nonnull) NSString *value;

@end

@implementation APMCorrelationIdentifier

- (instancetype)initWithScope:(NSString *)scope value:(NSString *)value {
    self = [super init];
    if (self) {
        self.scope = scope;
        self.value = value;
    }
    return self;
}

- (NSDictionary *)correlationIDDictionary {
    return @{
             @"scope": self.scope,
             @"value": self.value
             };
}

@end

@implementation APMIssue
@end

@implementation APMProperty

- (NSDictionary *)propertyDictionary {
    NSMutableDictionary *propertyDictionary = [NSMutableDictionary new];
    propertyDictionary[@"name"] = self.name;
    propertyDictionary[@"type"] = self.type;
    propertyDictionary[@"value"] = self.number ?: self.value;
    return [propertyDictionary copy];
}

@end

@interface APMNode ()

@property (strong, nonatomic, nonnull) APMSpanContext *spanContext;
@property (strong, nonatomic, nonnull) NSString *type;
@property (strong, nonatomic, nonnull) NSMutableArray<APMCorrelationIdentifier*> *correlationIDs;
@property (strong, nonatomic, nonnull) NSArray<APMIssue*> *issues;
@property (strong, nonatomic, nonnull) NSMutableArray<APMNode*> *childNodes;
@property (strong, nonatomic, nonnull) NSMutableArray<APMProperty*> *properties;

@end

@implementation APMNode

- (instancetype)initWithSpanContext:(APMSpanContext *)spanContext {
    self = [super init];
    if (self) {
        self.spanContext = spanContext;
        self.type = spanContext.hasBeenInjected ? @"Producer" : @"Component";
        self.correlationIDs = [NSMutableArray<APMCorrelationIdentifier*> new];
        self.issues = [NSArray<APMIssue*> new];
        self.childNodes = [NSMutableArray<APMNode*> new];
        self.properties = [NSMutableArray<APMProperty*> new];
    }
    return self;
}

- (NSDictionary *)nodeDictionary {
    NSMutableDictionary *nodeDictionary = [NSMutableDictionary new];
    nodeDictionary[@"correlationIds"] = self.correlationIDs.count > 0 ? [self.correlationIDs valueForKeyPath:@"@unionOfObjects.correlationIDDictionary"] : nil;
    nodeDictionary[@"duration"] = [NSNumber numberWithLong: self.duration * 1000000];
    nodeDictionary[@"issues"] = self.issues.count > 0 ? [self.issues valueForKeyPath:@"@unionOfObjects.issueDictionary"] : nil;
    nodeDictionary[@"nodes"] = self.childNodes.count > 0 ? [self.childNodes valueForKeyPath:@"@unionOfObjects.nodeDictionary"] : nil;
    nodeDictionary[@"operation"] = self.operation;
    nodeDictionary[@"properties"] = self.properties.count > 0 ? [self.properties valueForKeyPath:@"@unionOfObjects.propertyDictionary"] : nil;
    nodeDictionary[@"timestamp"] = self.timestamp == nil ? nil : [NSNumber numberWithLong: [self.timestamp timeIntervalSince1970] * 1000000];
    nodeDictionary[@"type"] = self.type;
    if ([self.type isEqualToString:@"Component"]) {
        nodeDictionary[@"componentType"] = self.componentType;
    } else {
        nodeDictionary[@"endpointType"] = self.endpointType;
    }
    nodeDictionary[@"uri"] = self.uri.path;
    return [nodeDictionary copy];
}

- (void)addProperty:(APMProperty *)property {
    [self.properties addObject:property];
}

- (void)addCorrelationIdentifier:(APMCorrelationIdentifier *)correlationIdentifier {
    [(NSMutableArray*)self.correlationIDs addObject:correlationIdentifier];
}

- (void)addChildNode:(APMNode *)node {
    [(NSMutableArray*)self.childNodes addObject:node];
}

- (void)parseTags:(NSDictionary *)tags {
    for (NSString *key in tags.allKeys) {
        if ([key isEqualToString:@"http.url"]) {
            NSString *uriString = tags[key];
            NSURL *uri = [NSURL URLWithString:uriString];
            self.uri = uri;
            self.endpointType = uri.scheme;
            self.type = @"Producer";

            APMProperty *uriProperty = [APMProperty new];
            uriProperty.name = @"http.uri";
            uriProperty.value = uri.path;
            uriProperty.type = @"Text";
            [self addProperty:uriProperty];
            APMProperty *urlProperty = [APMProperty new];
            urlProperty.name = @"http.url";
            urlProperty.value = uri.absoluteString;
            urlProperty.type = @"Text";
            [self addProperty:urlProperty];
            APMProperty *pathProperty = [APMProperty new];
            pathProperty.name = @"http.path";
            pathProperty.value = uri.path;
            pathProperty.type = @"Text";
            [self addProperty:pathProperty];
        } else if ([key isEqualToString:@"node.operation"]) {
            self.operation = tags[key];
        } else if ([key isEqualToString:@"node.componentType"]) {
            self.componentType = tags[key];
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
            [self addProperty:property];
        }
    }
}

@end
