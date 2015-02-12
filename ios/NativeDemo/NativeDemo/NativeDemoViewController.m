//
//  NativeDemoViewController.m
//  NativeDemo
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

#import "NativeDemoViewController.h"
#import "OpenWebRTCVideoView.h"
#import "PeerServerHandler.h"

#include <owr/owr.h>
#include <owr/owr_local.h>
#include <owr/owr_video_renderer.h>
#include <owr/owr_window_registry.h>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "owr.h"
#include "owr_audio_payload.h"
#include "owr_audio_renderer.h"
#include "owr_local.h"
#include "owr_media_session.h"
#include "owr_transport_agent.h"
#include "owr_video_payload.h"
#include "owr_video_renderer.h"

#include <gio/gio.h>
#include <json-glib/json-glib.h>
#include <libsoup/soup.h>
#include <string.h>

#define SERVER_URL "http://demo.openwebrtc.io:38080"
#define SELF_VIEW_TAG "self-view"
#define REMOTE_VIEW_TAG "remote-view"


static GList *local_sources, *renderers;
static OwrTransportAgent *transport_agent;
static gchar *session_id, *peer_id;
static guint client_id;
static gchar *candidate_types[] = { "host", "srflx", "relay", NULL };
static gchar *tcp_types[] = { "", "active", "passive", "so", NULL };

static void read_eventstream_line(GDataInputStream *input_stream, gpointer user_data);
static void got_local_sources(GList *sources, gchar *url);

OwrVideoRenderer *renderer;

@interface NativeDemoViewController () <PeerServerHandlerDelegate>
{
    IBOutlet UIBarButtonItem *callButton;
    IBOutlet UIBarButtonItem *hangupButton;
}

@property (weak) IBOutlet OpenWebRTCVideoView *selfView;
@property (weak) IBOutlet OpenWebRTCVideoView *remoteView;

@property (nonatomic, strong) NSString *roomID;
@property (nonatomic, strong) PeerServerHandler *peerServer;

@end

@implementation NativeDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.navigationController setToolbarHidden:NO animated:NO];

    // Setup the video windows.
    owr_window_registry_register(owr_window_registry_get(), SELF_VIEW_TAG, (__bridge gpointer)(self.selfView));
    owr_window_registry_register(owr_window_registry_get(), REMOTE_VIEW_TAG, (__bridge gpointer)(self.remoteView));

    callButton.enabled = hangupButton.enabled = NO;

    self.peerServer = [[PeerServerHandler alloc] initWithBaseURL:@"http://192.36.158.50:8080"];
    self.peerServer.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self presentRoomInputView];
}

- (void)presentRoomInputView
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Enter Room ID"
                                                                   message:@"Use the same ID to connect 2 clients"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Done"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   UITextField *roomTextField = alert.textFields[0];
                                                   NSString *room = [roomTextField text];
                                                   if (![@"" isEqualToString:room])
                                                       [self joinButtonTapped:room];
                                                   else
                                                       [self presentRoomInputView];
                                               }];
    [alert addAction:ok];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)joinButtonTapped:(NSString *)roomID
{
    NSLog(@"Joining room with ID: %@", roomID);
    self.roomID = roomID;

    client_id = g_random_int();
    gchar *url = g_strdup_printf(SERVER_URL"/stoc/%s/%u", [roomID UTF8String], client_id);
    /*
    GMainLoop *main_loop = g_main_loop_new(NULL, FALSE);
    GMainContext *main_context = g_main_context_default();
    owr_init_with_main_context(main_context);
*/
    owr_init();

    owr_get_capture_sources(OWR_MEDIA_TYPE_AUDIO | OWR_MEDIA_TYPE_VIDEO,
                            (OwrCaptureSourcesCallback)got_local_sources, url);
    //g_main_loop_run(main_loop);

    [self.peerServer joinRoomWithID:roomID];
}

- (IBAction)callButtonTapped:(id)sender
{
    callButton.enabled = NO;
    hangupButton.enabled = YES;
}

- (IBAction)hangupButtonTapped:(id)sender
{
    exit(0); // Nice :)
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"WARNING! didReceiveMemoryWarning");
    [super didReceiveMemoryWarning];
}

- (void)presentErrorWithMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {

                                               }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - OpenWebRTC

static void got_local_sources(GList *sources, gchar *url)
{
    NSLog(@"got_local_sources");

    local_sources = g_list_copy(sources);
    transport_agent = owr_transport_agent_new(FALSE);
    owr_transport_agent_add_helper_server(transport_agent, OWR_HELPER_SERVER_TYPE_STUN,
                                          "stun.services.mozilla.com", 3478, NULL, NULL);

    gboolean have_video = FALSE;
    g_assert(sources);

    while (sources) {
        gchar *name;
        OwrMediaSource *source = NULL;
        OwrMediaType media_type;
        OwrMediaType source_type;

        source = sources->data;
        g_assert(OWR_IS_MEDIA_SOURCE(source));

        g_object_get(source, "name", &name, "type", &source_type, "media-type", &media_type, NULL);

        /* We ref the sources because we want them to stay around. On iOS they will never be
         * unplugged, I expect, but it's safer this way. */
        g_object_ref(source);

        g_print("[%s/%s] %s\n", media_type == OWR_MEDIA_TYPE_AUDIO ? "audio" : "video",
                source_type == OWR_SOURCE_TYPE_CAPTURE ? "capture" : source_type == OWR_SOURCE_TYPE_TEST ? "test" : "unknown",
                name);

        if (!have_video && media_type == OWR_MEDIA_TYPE_VIDEO && source_type == OWR_SOURCE_TYPE_CAPTURE) {
            renderer = owr_video_renderer_new(SELF_VIEW_TAG);
            g_assert(renderer);

            g_object_set(renderer, "width", 640, "height", 480, "max-framerate", 30.0, NULL);

            owr_media_renderer_set_source(OWR_MEDIA_RENDERER(renderer), source);
            have_video = TRUE;
        }
        
        sources = sources->next;
    }

    if (url) {
        //send_eventsource_request(url);
        g_free(url);
    }
}


#pragma mark - PeerServerHandlerDelegate

- (void)peerServer:(PeerServerHandler *)peerServer failedToJoinRoom:(NSString *)roomID withError:(NSError *)error
{
    [self presentErrorWithMessage:error.localizedDescription];
}

- (void)peerServer:(PeerServerHandler *)peerServer successfullyJoinedRoom:(NSString *)roomID
{
    NSLog(@"successfullyJoinedRoom: %@", roomID);
}

- (void)peerServer:(PeerServerHandler *)peerServer roomIsFull:(NSString *)roomID
{
    NSLog(@"roomIsFull: %@", roomID);
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID joinedRoom:(NSString *)roomID
{
    callButton.enabled = YES;

    NSLog(@"peer <%@> joinedRoom: %@", peerID, roomID);
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID leftRoom:(NSString *)roomID
{
    NSLog(@"peer <%@> leftRoom: %@", peerID, roomID);
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentOffer:(NSDictionary *)offer
{
    NSLog(@"peer <%@> sentOffer: %@", peerID, offer);
}

@end
