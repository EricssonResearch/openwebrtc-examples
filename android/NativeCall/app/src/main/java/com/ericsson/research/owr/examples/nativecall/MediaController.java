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

import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.SurfaceTexture;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;

import com.ericsson.research.owr.AudioRenderer;
import com.ericsson.research.owr.MediaSession;
import com.ericsson.research.owr.MediaSource;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.RemoteMediaSource;
import com.ericsson.research.owr.VideoRenderer;
import com.ericsson.research.owr.WindowRegistry;

import java.util.LinkedList;
import java.util.List;

public class MediaController {
    public static final String TAG = "MediaController";

    public static final String SELF_VIEW_TAG = "self-view";
    public static final String REMOTE_VIEW_TAG = "remote-view";


    private final SurfaceTagger mSelfViewTagger;
    private final SurfaceTagger mRemoteViewTagger;
    private final VideoRenderer mSelfViewRenderer;
    private final VideoRenderer mRemoteViewRenderer;
    private final AudioRenderer mRemoteAudioRenderer;
    private final Handler mHandler;

    private TextureView mSelfView;
    private TextureView mRemoteView;

    private MediaSource mLocalVideo;
    private MediaSource mLocalAudio;

    private MediaSession mVideoSession;

    private List<MediaSource> mVideoSources = new LinkedList<>();

    private MediaController(final List<MediaSource> mediaSources) {
        mSelfViewRenderer = new VideoRenderer(SELF_VIEW_TAG);
        mSelfViewRenderer.setWidth(Config.VIDEO_WIDTH);
        mSelfViewRenderer.setHeight(Config.VIDEO_HEIGHT);
        mSelfViewRenderer.setMaxFramerate(Config.VIDEO_FRAMERATE);

        mRemoteViewRenderer = new VideoRenderer(REMOTE_VIEW_TAG);
        mRemoteAudioRenderer = new AudioRenderer();

        mSelfViewTagger = new SurfaceTagger(SELF_VIEW_TAG);
        mRemoteViewTagger = new SurfaceTagger(REMOTE_VIEW_TAG);

        mHandler = new Handler(Looper.getMainLooper());

        for (MediaSource mediaSource : mediaSources) {
            if (mediaSource.getMediaType().contains(MediaType.VIDEO)) {
                Log.d(TAG, "have video source: " + mediaSource.getName());
                mVideoSources.add(mediaSource);
            } else if (mediaSource.getMediaType().contains(MediaType.AUDIO)) {
                Log.d(TAG, "have audio source: " + mediaSource.getName());
                if (mLocalAudio != null) {
                    Log.e(TAG, "got multiple audio sources, that should be handled by the system");
                }
                mLocalAudio = mediaSource;
            }
        }
    }

    public synchronized static void create(final List<MediaSource> mediaSources) {
        if (instance != null) {
            throw new IllegalStateException("tried to create duplicate MediaController");
        }
        instance = new MediaController(mediaSources);
        MediaController.class.notifyAll();
    }

    private static MediaController instance;

    public synchronized static MediaController getInstance() {
        if (instance == null) {
            try {
                MediaController.class.wait();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
        return instance;
    }

    public void setSelfView(final TextureView selfView) {
        if (mSelfView != null) {
            selfView.setVisibility(mSelfView.getVisibility());
        }
        mSelfView = selfView;
        mSelfView.setOpaque(false);
        mSelfView.setSurfaceTextureListener(mSelfViewTagger);
    }

    public void setRemoteView(final TextureView remoteView) {
        if (mRemoteView != null) {
            remoteView.setVisibility(mRemoteView.getVisibility());
        }
        mRemoteView = remoteView;
        mRemoteView.setOpaque(false);
        mRemoteView.setSurfaceTextureListener(mRemoteViewTagger);
    }

    public synchronized void toggleCamera() {
        if (mLocalVideo == null) {
            return;
        }

        final MediaSource newSource;
        final int index = mVideoSources.indexOf(mLocalVideo);
        if (index < 0) {
            newSource = mVideoSources.get(0);
        } else {
            int nextIndex = (index + 1) % mVideoSources.size();
            newSource = mVideoSources.get(nextIndex);
        }

        if (mLocalVideo == newSource) {
            return;
        }

        mLocalVideo = null;
        mSelfViewRenderer.setSource(null);
        if (mVideoSession != null) {
            mVideoSession.setSendSource(null);
        }

        mHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                synchronized (MediaController.this) {
                    setLocalVideoSource(newSource);
                }
            }
        }, 500);
    }

    public synchronized void showSelfView() {
        if (mVideoSources.isEmpty()) {
            Log.e(TAG, "no local video source available");
        } else {
            setLocalVideoSource(mVideoSources.get(0));
        }
    }

    public synchronized void hideSelfView() {
        setLocalVideoSource(null);
    }

    public synchronized void clearRemoteSources() {
        setRemoteVideoSource(null);
    }

    public synchronized void setVideoSession(final MediaSession mediaSession) {
        mVideoSession = mediaSession;
        mVideoSession.addOnIncomingSourceListener(new MediaSession.OnIncomingSourceListener() {
            @Override
            public void onIncomingSource(final RemoteMediaSource remoteMediaSource) {
                synchronized (MediaController.this) {
                    setRemoteVideoSource(remoteMediaSource);
                }
            }
        });
        if (mLocalVideo != null) {
            mVideoSession.setSendSource(mLocalVideo);
        }
    }

    public synchronized void setAudioSession(final MediaSession mediaSession) {
        mediaSession.addOnIncomingSourceListener(new MediaSession.OnIncomingSourceListener() {
            @Override
            public void onIncomingSource(final RemoteMediaSource remoteMediaSource) {
                synchronized (MediaController.this) {
                    setRemoteAudioSource(remoteMediaSource);
                }
            }
        });
        if (mLocalAudio != null) {
            mediaSession.setSendSource(mLocalAudio);
        }
    }

    private void setLocalVideoSource(final MediaSource localSource) {
        Log.w(TAG, "self view: " + localSource);
        mLocalVideo = localSource;
        mSelfViewRenderer.setSource(localSource);
        if (mVideoSession != null) {
            mVideoSession.setSendSource(localSource);
        }
        setViewVisibility(mSelfView, localSource != null);
    }

    private void setRemoteVideoSource(final MediaSource remoteSource) {
        Log.w(TAG, "remote view: " + remoteSource);
        mRemoteViewRenderer.setSource(remoteSource);
        setViewVisibility(mRemoteView, remoteSource != null);
    }

    private void setRemoteAudioSource(final MediaSource remoteSource) {
        Log.w(TAG, "remote audio: " + remoteSource);
        mRemoteAudioRenderer.setSource(remoteSource);
    }

    private void setViewVisibility(final View view, final boolean visible) {
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                view.setVisibility(visible ? View.VISIBLE : View.INVISIBLE);
            }
        });
    }

    public void setDeviceOrientation(final int orientation) {
        Log.w(TAG, "setDeviceOrientation: " + orientation);
        int angle = ((orientation + 3) % 4) * 90;
        mSelfView.setRotation(angle);
    }

    public class SurfaceTagger implements TextureView.SurfaceTextureListener {
        private final String mTag;

        public SurfaceTagger(String tag) {
            mTag = tag;
        }

        @Override
        public void onSurfaceTextureAvailable(SurfaceTexture surfaceTexture, int width, int height) {
            Log.d(TAG, "onSurfaceTextureAvailable: " + surfaceTexture);
            Surface surface = new Surface(surfaceTexture);
            Log.w(TAG, "Register[" + mTag + "] => " + surface);
            WindowRegistry.get().register(mTag, surface);
        }

        @Override
        public boolean onSurfaceTextureDestroyed(SurfaceTexture surfaceTexture) {
            Log.d(TAG, "onSurfaceTextureDestroyed: " + surfaceTexture);
            WindowRegistry.get().unregister(mTag);
            return true;
        }

        @Override
        public void onSurfaceTextureSizeChanged(SurfaceTexture surfaceTexture, int width, int height) {
            Log.d(TAG, "onSurfaceTextureSizeChanged: " + surfaceTexture);
        }

        @Override
        public void onSurfaceTextureUpdated(SurfaceTexture surfaceTexture) {
        }
    }
}
