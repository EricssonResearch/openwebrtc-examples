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

package com.ericsson.research.owr.examples.natiev;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.util.Log;
import android.view.Surface;
import android.view.TextureView;
import android.view.Window;

import com.ericsson.research.owr.CaptureSourcesCallback;
import com.ericsson.research.owr.MediaSource;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.Owr;
import com.ericsson.research.owr.VideoRenderer;
import com.ericsson.research.owr.WindowRegistry;

import java.util.EnumSet;
import java.util.List;

public class NativeExampleActivity extends Activity {
    private static final String TAG = "NativeExampleActivity";

    private static final String SELF_VIEW_TAG = "self-view";

    /**
     * Initialize OpenWebRTC at startup
     */
    static {
        Owr.init();
        Owr.runInBackground();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setContentView(R.layout.activity_openwebrtc);

        Owr.getCaptureSources(EnumSet.of(MediaType.VIDEO), new CaptureSourcesCallback() {
            @Override
            public void onCaptureSourcesCallback(final List<MediaSource> mediaSources) {
                /* Use default video source */
                MediaSource mediaSource = mediaSources.get(0);

                VideoRenderer videoRenderer = new VideoRenderer(SELF_VIEW_TAG);
                videoRenderer.setWidth(720);
                videoRenderer.setHeight(720);
                videoRenderer.setSource(mediaSource);
            }
        });

        final TextureView textureView = (TextureView) findViewById(R.id.texture_view);

        textureView.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
            @Override
            public void onSurfaceTextureAvailable(final SurfaceTexture surfaceTexture, final int width, final int height) {
                Log.v(TAG, "onSurfaceTextureAvailable: " + width + "x" + height);
                Surface surface = new Surface(surfaceTexture);
                WindowRegistry.get().register(SELF_VIEW_TAG, surface);
            }

            @Override
            public void onSurfaceTextureSizeChanged(final SurfaceTexture surface, final int width, final int height) {
                Log.v(TAG, "onSurfaceTextureSizeChanged: " + width + "x" + height);
            }

            @Override
            public boolean onSurfaceTextureDestroyed(final SurfaceTexture surface) {
                Log.v(TAG, "onSurfaceTextureDestroyed");
                WindowRegistry.get().unregister(SELF_VIEW_TAG);
                return true;
            }

            @Override
            public void onSurfaceTextureUpdated(final SurfaceTexture surface) {
            }
        });
    }

    /**
     * Shutdown the process as a workaround until cleanup has been fully implemented.
     */
    @Override
    protected void onStop() {
        finish();
        System.exit(0);
    }
}
