//
//  APMRecorder.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMRecorder.h"
#import "APMTraceFragment.h"
#import "APMSpanContext.h"
#import "APMNode.h"
#import "APMSpan.h"

@interface APMRecorder () <NSURLSessionDelegate>

@property (strong, nonatomic, nonnull) NSMutableOrderedSet *orphanedNodes;
@property (strong, nonatomic, nonnull) NSMutableOrderedSet *unfinishedSpanContexts;

@property (strong, nonatomic, nonnull) NSMutableArray<NSDictionary*> *traceDictionariesToSend;
@property (strong, nonatomic, nonnull) NSURLSession *urlSession;
@property (strong, nonatomic, nonnull) NSURL *baseURL;
@property (strong, nonatomic, nonnull) NSURLCredential *credential;
@property (weak, nonatomic, nullable) NSTimer *sendTimer;
@property (nonatomic) NSTimeInterval timeoutInterval;

@end

@implementation APMRecorder

- (instancetype)initWithURL:(NSURL *)baseURL credential:(NSURLCredential*)credential flushInterval:(NSTimeInterval)flushInterval timeoutInterval:(NSTimeInterval)timeoutInterval {
    self = [super init];
    if (self) {
        self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:flushInterval repeats:YES block:^(NSTimer * _Nonnull timer) {
            [self send];
        }];
        self.traceDictionariesToSend = [NSMutableArray<NSDictionary*> new];
        self.orphanedNodes = [NSMutableOrderedSet new];
        self.unfinishedSpanContexts = [NSMutableOrderedSet new];

        self.baseURL = baseURL;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.urlSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        self.timeoutInterval = timeoutInterval;
        self.credential = credential;
    }
    return self;
}

- (void)dealloc {
    [self.sendTimer invalidate];
}

- (void)send {
    [self send:nil];
}

- (void)send:(void (^)(NSError * _Nullable error))completionHandler {
    NSArray *traces = [self.traceDictionariesToSend copy];

    if (traces.count > 0) {
        [self.traceDictionariesToSend removeAllObjects];
        NSURLRequest *request = [self requestForTraces:traces];
        NSURLSessionTask *task = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"APM recorder got an error when sending traces: %@", error);
            } else if (![response isKindOfClass:[NSHTTPURLResponse class]] || ((NSHTTPURLResponse*)response).statusCode != 204 ) {
                NSLog(@"Got invalid response: %@", response);
            }
            if (completionHandler) {
                completionHandler(error);
            }
        }];
        [task resume];
    } else {
        if (completionHandler) {
            completionHandler(nil);
        }
    }
}

- (NSURLRequest*)requestForTraces:(NSArray*)traces {
    NSString *nameAndPassword = [NSString stringWithFormat:@"%@:%@", self.credential.user, self.credential.password];
    NSData *nameAndPasswordData = [nameAndPassword dataUsingEncoding:NSASCIIStringEncoding];
    NSString *base64EncodedNameAndPassword = [nameAndPasswordData base64EncodedStringWithOptions: 0];
    NSString *basicAuth = [NSString stringWithFormat:@"Basic %@", base64EncodedNameAndPassword];
    NSURL *requestURL = [NSURL URLWithString:@"/hawkular/apm/traces/fragments" relativeToURL:self.baseURL];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:basicAuth forHTTPHeaderField:@"Authorization"];
    request.timeoutInterval = self.timeoutInterval;

    NSError *error = nil;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:traces options:0 error:&error];
    NSAssert(error == nil, @"Should not get an error endoding %@", traces);

    return request;
}

- (BOOL)addFragment:(APMTraceFragment * _Nonnull)fragment {
    NSParameterAssert(fragment);
    NSDictionary *traceDictionary = fragment.traceDictionary;
    if (![self.traceDictionariesToSend containsObject:traceDictionary]) {
        [self.traceDictionariesToSend addObject:traceDictionary];
        return YES;
    }
    return NO;
}

// MARK: - Nodes

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

- (BOOL)addNodeForSpan:(APMSpan *)span {
    APMSpanContext *spanContext = (APMSpanContext*)span.context;

    [self.unfinishedSpanContexts removeObject:span.context];

    APMNode *node = [[APMNode alloc] initWithSpanContext:span.context];
    node.timestamp = span.startTime;
    node.duration = [span.endTime timeIntervalSinceDate:span.startTime] ?: 0;
    NSAssert(node.duration >= 0, @"Duration must be positive");

    if (spanContext.interactionID != nil) {
        APMCorrelationIdentifier *interactionIdentifier = [[APMCorrelationIdentifier alloc] initWithScope:@"Interaction" value:spanContext.interactionID];
        [node addCorrelationIdentifier:interactionIdentifier];
    }

    if (spanContext.parentContext.nodeID != nil) {
        APMCorrelationIdentifier *causedByIdentifier = [[APMCorrelationIdentifier alloc] initWithScope:@"CausedBy" value:spanContext.parentContext.nodeID];
        [node addCorrelationIdentifier:causedByIdentifier];
    }

    [node parseTags:span.tags];

    node.operation = span.operationName;

    NSSet *children = [self.orphanedNodes filteredOrderedSetUsingPredicate:[NSPredicate predicateWithFormat:@"spanContext.parentContext == %@", span.context]];
    for (APMNode *child in children) {
        [node addChildNode:child];
        [self.orphanedNodes removeObject:child];
    }

    if (spanContext.parentContext == nil || ![self.unfinishedSpanContexts containsObject:spanContext.parentContext]) {
        if (![spanContext.level isEqualToString:@"All"]) {
            return NO;
        }
        APMTraceFragment *fragment = [[APMTraceFragment alloc] initWithTraceID:spanContext.traceID fragmendID:spanContext.spanID rootNode: node];
        return [self addFragment:fragment];
    }

    [self.orphanedNodes addObject:node];
    return YES;
}


@end
