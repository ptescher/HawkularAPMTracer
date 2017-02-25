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

- (instancetype)initWithSpanContext:(APMSpanContext *)spanContext type:(NSString *)type {
    self = [super init];
    if (self) {
        self.spanContext = spanContext;
        self.type = type;
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
    nodeDictionary[@"endpointType"] = self.endpointType;
    nodeDictionary[@"componentType"] = self.componentType;
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

@end
