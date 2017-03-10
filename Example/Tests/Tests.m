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

    NSURL *baseURL = [NSURL URLWithString:@"http://localhost:54676/hawkular/apm/"];
    NSURLCredential *credential = [[NSURLCredential alloc] initWithUser:@"admin" password:@"password" persistence:NSURLCredentialPersistenceNone];
    [APMTracer setup:baseURL credential:credential flushInterval:1.0];
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
    NSDictionary *carrier = @{@"HWKAPMID": @5};
    id<OTSpanContext> parentContext = [[OTGlobal sharedTracer] extractWithFormat:OTFormatTextMap carrier:carrier];
    NSDictionary *tags = @{@"foo": @"bar", @"service": @"test-service", @"test.type": @"xctest"};
    id<OTSpan> testSpan = [[OTGlobal sharedTracer] startSpan:@"root" childOf:parentContext tags:tags startTime:[NSDate date]];
    [testSpan setTag:@"node.endpointType" value:@"HTTP"];
    [testSpan setTag:@"node.type" value:@"Consumer"];

    [self stubFragmentEndpointAndExpectResponse];

    [testSpan finishWithTime:[NSDate dateWithTimeIntervalSinceNow:0.201]];
    [[OTGlobal sharedTracer] inject:parentContext format:OTFormatTextMap carrier:carrier];

    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testNSURLMetricsTracking {
    NSString *traceID = [NSUUID UUID].UUIDString;
    NSURL *testURL = [NSURL URLWithString:@"http://www.apple.com/macbook/"];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:testURL];
    [urlRequest setValue:@"All" forHTTPHeaderField:@"HWKAPMLEVEL"];
    [urlRequest setValue:traceID forHTTPHeaderField:@"HWKAPMTRACEID"];
    [urlRequest setValue:traceID forHTTPHeaderField:@"HWKAPMID"];
    [urlRequest setValue:@"Test Transaction" forHTTPHeaderField:@"HWKAPMTXN"];

    APMURLSessionDelegate *delegate = [APMURLSessionDelegate new];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate: delegate delegateQueue:nil];

    [self stubFragmentEndpointAndExpectResponse];

    [[session dataTaskWithRequest: urlRequest] resume];

    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

@end

