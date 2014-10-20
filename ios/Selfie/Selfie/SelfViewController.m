//
//  SelfViewController.m
//  Selfie
//
//  Copyright (c) 2014, Ericsson AB.
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

#import "SelfViewController.h"
#import <GLKit/GLKit.h>

#include <owr/owr.h>
#include <owr/owr_local.h>
#include <owr/owr_video_renderer.h>
#include <owr/owr_window_registry.h>

#define SELF_VIEW_TAG "self-view"

@interface SelfViewController ()

@property (weak) IBOutlet GLKView *selfView;

@end

@implementation SelfViewController

OwrVideoRenderer *renderer;

- (void)viewDidLoad
{
    [super viewDidLoad];

    owr_init();
    NSLog(@"OpenWebRTC initialized");

    NSLog(@"Registering self view %@", self.selfView);
    owr_window_registry_register(owr_window_registry_get(), SELF_VIEW_TAG, (__bridge gpointer)(self.selfView));

    NSLog(@"Getting capture sources...");
    owr_get_capture_sources(OWR_MEDIA_TYPE_VIDEO, got_sources, NULL);
}

static void got_sources(GList *sources, gpointer user_data)
{
    g_assert(sources);

    while (sources) {
        OwrMediaSource *source = NULL;
        OwrMediaType media_type;
        gchar *name = "";

        source = sources->data;
        g_assert(OWR_IS_MEDIA_SOURCE(source));

        g_object_get(source, "name", &name, "media-type", &media_type, NULL);

        if (media_type == OWR_MEDIA_TYPE_VIDEO && strcasestr(name, "capture")) {
            renderer = owr_video_renderer_new(SELF_VIEW_TAG);
            g_assert(renderer);

            g_object_set(renderer, "width", 1280, "height", 720, "max-framerate", 60.0, NULL);

            owr_media_renderer_set_source(OWR_MEDIA_RENDERER(renderer), source);
            break;
        }
        sources = sources->next;
    }
}

@end