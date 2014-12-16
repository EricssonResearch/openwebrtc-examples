/*
 * Copyright (c) 2014, Ericsson AB. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this
 * list of conditions and the following disclaimer in the documentation and/or other
 * materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 */

package com.ericsson.research.owr.examples.nativecall;

import com.ericsson.research.owr.AudioPayload;
import com.ericsson.research.owr.CodecType;
import com.ericsson.research.owr.HelperServerType;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.Payload;
import com.ericsson.research.owr.VideoPayload;

public class Config {
    public static final String DEFAULT_SERVER_ADDRESS = "http://demo.openwebrtc.io:38080";

    public static final HelperServer[] HELPER_SERVERS = new HelperServer[] {
            new HelperServer(HelperServerType.STUN, "stun.l.google.com", 19302, "", ""),
    };

    public static final int VIDEO_HEIGHT = 480;
    public static final int VIDEO_WIDTH = 640;
    public static final double VIDEO_FRAMERATE = 30.0;

    public static final String DEFAULT_DTLS_FINGERPRINT_HASH_FUNCTION = "sha-256";

    public static final VideoPayload[] DEFAULT_VIDEO_PAYLOADS = new VideoPayload[] {
        new VideoPayload(CodecType.H264, 103, 90000, true, true),
        new VideoPayload(CodecType.VP8, 100, 90000, true, true),
    };

    public static final AudioPayload[] DEFAULT_AUDIO_PAYLOADS = new AudioPayload[] {
        new AudioPayload(CodecType.OPUS, 111, 48000, 2),
        new AudioPayload(CodecType.PCMA, 8, 8000, 1),
        new AudioPayload(CodecType.PCMU, 0, 8000, 1),
    };





    public static Payload[] getDefaultPayloadsForMediaType(int mediaType) {
        if (mediaType == MediaType.VIDEO) {
            return DEFAULT_VIDEO_PAYLOADS;
        } else if (mediaType == MediaType.AUDIO) {
            return DEFAULT_AUDIO_PAYLOADS;
        } else {
            return null;
        }
    }

    public static class HelperServer {
        public final HelperServerType type;
        public final String address;
        public final int port;
        public final String username;
        public final String password;

        public HelperServer(HelperServerType type, String address, int port, String username, String password) {
            this.type = type;
            this.address = address;
            this.port = port;
            this.username = username;
            this.password = password;
        }
    }
}
