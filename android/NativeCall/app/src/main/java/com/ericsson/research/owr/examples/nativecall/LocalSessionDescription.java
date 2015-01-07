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

import android.util.SparseArray;

import com.ericsson.research.owr.MediaType;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Random;

public class LocalSessionDescription {
    public static final String TAG = "LocalSessionDescription";

    private static final Random sRandom = new Random();

    private final List<LocalMediaDescription> mMediaDescriptions;
    private final boolean mIsOffer;
    private long mSessionId = (long) Math.floor(sRandom.nextDouble() + new Date().getTime() * 1e6);

    private LocalSessionDescription(List<LocalMediaDescription> mediaDescriptions, boolean isOffer) {
        for (int i = 0; i < mediaDescriptions.size(); i++) {
            mediaDescriptions.get(i).setLineIndex(i);
        }
        mIsOffer = isOffer;
        mMediaDescriptions = mediaDescriptions;
    }

    public static LocalSessionDescription createOffer(boolean wantAudio, boolean wantVideo) {
        List<LocalMediaDescription> mediaDescriptions = new ArrayList<>();
        if (wantAudio) {
            mediaDescriptions.add(LocalMediaDescription.createOffeer(MediaType.AUDIO));
        }
        if (wantVideo) {
            mediaDescriptions.add(LocalMediaDescription.createOffeer(MediaType.VIDEO));
        }
        return new LocalSessionDescription(mediaDescriptions, true);
    }

    public static LocalSessionDescription createAnswer(RemoteSessionDescription remoteDescription,
                                                       boolean wantAudio, boolean wantVideo) {
        List<LocalMediaDescription> mediaDescriptions = new ArrayList<>();
        SparseArray<RemoteMediaDescription> remoteMediaDescriptions = remoteDescription.getMediaDescriptions();
        for(int i = 0; i < remoteMediaDescriptions.size(); i++) {
            int key = remoteMediaDescriptions.keyAt(i);
            RemoteMediaDescription remoteMediaDescription = remoteMediaDescriptions.get(key);
            if ((remoteMediaDescription.getMediaType() == MediaType.AUDIO && wantAudio) ||
                    (remoteMediaDescription.getMediaType() == MediaType.VIDEO && wantVideo)) {
                mediaDescriptions.add(LocalMediaDescription.createAnswer(remoteMediaDescription));
            }
        }
        return new LocalSessionDescription(mediaDescriptions, false);
    }

    public synchronized void addAnswer(RemoteSessionDescription remoteDescription) {
        if (!mIsOffer) {
            throw new IllegalStateException("tried to add remote description to an answer");
        }

        List<LocalMediaDescription> removed = new ArrayList<>();
        SparseArray<RemoteMediaDescription> remoteMediaDescriptions = remoteDescription.getMediaDescriptions();

        for (LocalMediaDescription localMediaDescription : mMediaDescriptions) {
            RemoteMediaDescription matchingDescription = null;

            for (int i = 0; i < remoteMediaDescriptions.size(); i++) {
                RemoteMediaDescription remoteMediaDescription = remoteMediaDescriptions.valueAt(i);
                if (remoteMediaDescription.getMediaType() == localMediaDescription.getMediaType()) {
                    matchingDescription = remoteMediaDescription;
                }
            }

            if (matchingDescription != null) {
                localMediaDescription.addAnswer(matchingDescription);
            } else {
                removed.add(localMediaDescription);
            }
        }

        mMediaDescriptions.removeAll(removed);
    }

    public boolean isComplete() {
        for (LocalMediaDescription localMediaDescription : mMediaDescriptions) {
            if (!localMediaDescription.isComplete()) {
                return false;
            }
        }
        return true;
    }

    public long getSessionId() {
        return mSessionId;
    }

    public LocalMediaDescription getMediaDescription(MediaType mediaType) {
        for (LocalMediaDescription mediaDescription : mMediaDescriptions) {
            if (mediaDescription.getMediaType() == mediaType) {
                return mediaDescription;
            }
        }
        return null;
    }

    public JSONObject toJson() throws JSONException {
        JSONObject json = new JSONObject();

        JSONObject originator = new JSONObject();
        originator.put("username", "-");
        originator.put("sessionId", getSessionId());
        originator.put("sessionVersion", 1);
        originator.put("netType", "IN");
        originator.put("addressType", "IP4");
        originator.put("address", "127.0.0.1");

        json.put("version", 0);
        json.put("originator", originator);
        json.put("sessionName", "-");
        json.put("startTime", 0);
        json.put("stopTime", 0);

        JSONArray mediaDescriptions = new JSONArray();
        for (LocalMediaDescription mediaDescription : mMediaDescriptions) {
            mediaDescriptions.put(mediaDescription.toJson());
        }
        json.put("mediaDescriptions", mediaDescriptions);

        return json;
    }
}
