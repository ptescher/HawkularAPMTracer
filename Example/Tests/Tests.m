//
//  HawkularAPMTracerTests.m
//  HawkularAPMTracerTests
//
//  Created by pat2man on 02/23/2017.
//  Copyright (c) 2017 pat2man. All rights reserved.
//

@import XCTest;
#import <HawkularAPMTracer/APMURLSessionDelegate.h>
#import <HawkularAPMTracer/APMTracer.h>
#import <HawkularAPMTracer/NSMutableURLRequest+APMTracing.h>
#import <opentracing/OTGlobal.h>
#import <opentracing/OTSpan.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/NSURLRequest+HTTPBodyTesting.h>


@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];

    NSURL *baseURL = [NSURL URLWithString:@"http://localhost:54676/hawkular/apm/"];
    NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:@"admin" password:@"password" persistence:NSURLCredentialPersistenceNone];
    [APMTracer setup:baseURL credential:credential flushInterval:2.0];
}

- (void)tearDown {
    [super tearDown];
    [OHHTTPStubs removeAllStubs];
}

- (void)stubFragmentEndpointAndExpectResponse {
    XCTestExpectation *finishedExpectation = [self expectationWithDescription:@"Test span was sent"];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
        return [request.URL.path  isEqual: @"/hawkular/apm/traces/fragments"];
    } withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
        [finishedExpectation fulfill];
        NSData *body = request.OHHTTPStubs_HTTPBody;
        NSArray *traces = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingAllowFragments error:nil];
        XCTAssert(traces.count > 0);
        NSError *error = [NSError errorWithDomain:@"com.outtherelabs.hawkularapmtracer" code:500 userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:error];
    }];
}

- (void)testSpanSending {
    NSDictionary *tags = @{@"foo": @"bar", @"service": @"test-service", @"test.type": @"xctest", @"node.endpointType": @"HTTP"};
    id<OTSpan> testSpan = [[OTGlobal sharedTracer] startSpan:@"root" childOf:nil tags:tags startTime:[NSDate date]];

    [self stubFragmentEndpointAndExpectResponse];

    [testSpan finishWithTime:[NSDate dateWithTimeIntervalSinceNow:0.201]];

    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testNSURLMetricsTracking {
    NSURL *testURL = [NSURL URLWithString:@"http://www.apple.com/macbook/"];

    APMURLSessionDelegate *delegate = [APMURLSessionDelegate new];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate: delegate delegateQueue:nil];

    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:testURL];
    id<OTSpan> testSpan = [urlRequest startSpanWithParentContext:nil];

    [self stubFragmentEndpointAndExpectResponse];

    NSURLSessionTask *task = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [testSpan finish];
    }];

    [task resume];

    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

@end

