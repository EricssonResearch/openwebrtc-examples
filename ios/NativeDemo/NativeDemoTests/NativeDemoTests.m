//
//  NativeDemoTests.m
//  NativeDemoTests
//
//  Copyright (c) 2015, Ericsson AB.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or other
//  materials provided with the distribution.

//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
//  OF SUCH DAMAGE.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "NativeDemoViewController.h"
#import "PeerServerHandler.h"
#import <OpenWebRTC-SDK/OpenWebRTC.h>

@interface NativeDemoTests : XCTestCase <PeerServerHandlerDelegate>

@end

@implementation NativeDemoTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testConnectToRoom
{
    XCTAssert(YES, @"Pass");
}

#pragma mark - PeerServerHandlerDelegate

- (void)peerServer:(PeerServerHandler *)peerServer failedToJoinRoom:(NSString *)roomID withError:(NSError *)error
{

}

- (void)peerServer:(PeerServerHandler *)peerServer roomIsFull:(NSString *)roomID
{

}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID joinedRoom:(NSString *)roomID
{

}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID leftRoom:(NSString *)roomID
{

}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentOffer:(NSString *)offer
{

}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentAnswer:(NSString *)answer
{

}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentCandidate:(NSDictionary *)candidate
{

}

- (void)peerServer:(PeerServerHandler *)peerServer failedToSendDataWithError:(NSError *)error
{
    
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentOrientation:(NSInteger)orientation
{
    
}

- (void)testFindResourcesToParse
{
    for (NSString *file in @[@"example_dc", @"example_ff_remote"]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"sdp"];
        XCTAssert(path);
    }
    XCTAssert(YES, @"Pass");
}

- (void)testParseBadSDP
{
    NSDictionary *sdp = [OpenWebRTCUtils parseSDPFromString:@"hej"];
    XCTAssert(sdp[@"mediaDescriptions"]);
    XCTAssert([sdp[@"mediaDescriptions"] count] == 0);
}

- (void)testParseDataChannelSDP
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"example_dc" ofType:@"sdp"];
    NSError *error = nil;
    NSString *js = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:path]
                                            encoding:NSUTF8StringEncoding
                                               error:&error];

    XCTAssert(js);
    XCTAssert(!error);

    NSDictionary *sdp = [OpenWebRTCUtils parseSDPFromString:js];
    XCTAssert(sdp);
    XCTAssert([sdp[@"mediaDescriptions"] count] == 1);

    NSDictionary *desc = sdp[@"mediaDescriptions"][0];
    XCTAssert(desc);
    XCTAssert([desc[@"address"] isEqualToString:@"192.168.1.86"]);
    XCTAssert([desc[@"addressType"] isEqualToString:@"IP4"]);

    NSDictionary *dtls = desc[@"dtls"];
    XCTAssert(dtls);
    XCTAssert([dtls[@"fingerprint"] isEqualToString:@"1A:3C:A9:43:47:14:D1:12:E3:6E:C0:D5:19:14:EE:57:F6:FC:F9:1F:18:64:65:79:8B:AA:88:EB:3E:1A:B6:69"]);
    XCTAssert([dtls[@"fingerprintHashFunction"] isEqualToString:@"sha-256"]);
    XCTAssert([dtls[@"setup"] isEqualToString:@"actpass"]);

    NSDictionary *ice = desc[@"ice"];
    XCTAssert(ice);

    NSArray *candidates = ice[@"candidates"];
    XCTAssert([candidates count] == 1);
    XCTAssert([candidates[0][@"priority"] intValue] == 2122260223);
    XCTAssert([candidates[0][@"address"] isEqualToString:@"192.168.1.86"]);

    XCTAssert([ice[@"password"] isEqualToString:@"2gMDyNA8fu2WOCnIyyU1gkur"]);
    XCTAssert([ice[@"ufrag"] isEqualToString:@"9I+z5/4mb+Y00teq"]);


    /*
     {
     mediaDescriptions =     (
     {
     address = "192.168.1.86";
     addressType = IP4;
     dtls =             {
     fingerprint = "1A:3C:A9:43:47:14:D1:12:E3:6E:C0:D5:19:14:EE:57:F6:FC:F9:1F:18:64:65:79:8B:AA:88:EB:3E:1A:B6:69";
     fingerprintHashFunction = "sha-256";
     setup = actpass;
     };
     ice =             {
     candidates =                 (
     {
     address = "192.168.1.86";
     componentId = 1;
     foundation = 3681649477;
     port = 57049;
     priority = 2122260223;
     transport = UDP;
     type = host;
     }
     );
     password = 2gMDyNA8fu2WOCnIyyU1gkur;
     ufrag = "9I+z5/4mb+Y00teq";
     };
     netType = IN;
     port = 57049;
     protocol = "DTLS/SCTP";
     sctp =             {
     app = "webrtc-datachannel";
     maxMessageSize = 1024;
     port = 5000;
     };
     type = application;
     }
     );
     originator =     {
     address = "127.0.0.1";
     addressType = IP4;
     netType = IN;
     sessionId = "1.282549890398803e+17";
     sessionVersion = 2;
     username = "-";
     };
     sessionName = "-";
     startTime = 0;
     stopTime = 0;
     version = 0;
     }
     */
}

- (void)testParsePerformance
{
    [self measureBlock:^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"example_ff_remote" ofType:@"sdp"];
        NSString *content = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        [OpenWebRTCUtils parseSDPFromString:content];
    }];
}

@end
