//
//  APMNode.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class APMSpanContext, APMProperty;

@interface APMCorrelationIdentifier: NSObject
@property (readonly, nonnull) NSDictionary* correlationIDDictionary;
- (nonnull instancetype)initWithScope:(NSString* _Nonnull)scope value:(NSString* _Nonnull)value;
@end

@interface APMIssue: NSObject
@end

@interface APMProperty: NSObject
@property (readonly, nonnull) NSDictionary* propertyDictionary;
@property (strong, nonatomic, nullable) NSString *name;
@property (strong, nonatomic, nullable) NSNumber *number;
@property (strong, nonatomic, nullable) NSString *type;
@property (strong, nonatomic, nullable) NSString *value;
@end

@interface APMNode : NSObject

@property (readonly, nonnull) APMSpanContext *spanContext;
@property (readonly, nonnull) NSArray<APMNode*> *childNodes;
@property (readonly, nonnull) NSString *type;
@property (readonly, nonnull) NSArray<APMCorrelationIdentifier*> *correlationIDs;
@property (readonly, nonnull) NSDictionary* nodeDictionary;
@property (strong, nonatomic, nullable) NSDate *timestamp;
@property (nonatomic) NSTimeInterval duration;
@property (strong, nonatomic, nullable) NSString *operation;
@property (strong, nonatomic, nullable) NSURL *uri;
@property (strong, nonatomic, nullable) NSString *endpointType;
@property (strong, nonatomic, nullable) NSString *componentType;

- (nonnull instancetype)initWithSpanContext:(APMSpanContext* _Nonnull)spanContext type:(NSString* _Nonnull)type;
- (void)parseCarrier:(nonnull NSDictionary*)carrier type:(nonnull NSString*)type;

- (void)addProperty:(APMProperty* _Nonnull)property;
- (void)addCorrelationIdentifier:(APMCorrelationIdentifier* _Nonnull)correlationIdentifier;
- (void)addChildNode:(APMNode* _Nonnull)node;

@end
