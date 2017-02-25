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
#import <opentracing/OTGlobal.h>
#import <opentracing/OTSpan.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/NSURLRequest+HTTPBodyTesting.h>


@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];

    NSURL *baseURL = [NSURL URLWithString:@"http://hawkular-apm-riff-production.apps.outtherelabs.com/hawkular/apm/"];
    [APMTracer setup:baseURL flushInterval:1.0];
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
        NSLog(@"Got traces: %@", traces);
        NSError *error = [NSError errorWithDomain:@"com.outtherelabs.hawkularapmtracer" code:500 userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:error];
    }];
}

- (void)testSpanSending {
    id<OTSpan> testSpan = [[OTGlobal sharedTracer] startSpan:@"Test Span" childOf:nil tags:@{@"test-tag": @"test-value"} startTime:[NSDate dateWithTimeIntervalSinceNow:-10.0]];
    [testSpan setTag:@"node.componentType" value:@"Test"];
    [testSpan logEvent:@"Test Event"];

    [self stubFragmentEndpointAndExpectResponse];

    [testSpan finish];

    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testNSURLMetricsTracking {
    NSURL *testURL = [NSURL URLWithString:@"http://www.apple.com/macbook/"];
    APMURLSessionDelegate *delegate = [APMURLSessionDelegate new];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate: delegate delegateQueue:nil];

    [self stubFragmentEndpointAndExpectResponse];

    [[session dataTaskWithURL: testURL] resume];

    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

@end

