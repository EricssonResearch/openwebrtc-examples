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

import android.util.Log;
import android.util.SparseArray;

import com.ericsson.research.owr.MediaType;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class RemoteSessionDescription {
    public static final String TAG = "SessionDescription";

    private final SparseArray<RemoteMediaDescription> mMediaDescriptions = new SparseArray<>();
    private final long mSessionId;

    private RemoteSessionDescription(JSONObject json) throws JSONException {
        mSessionId = json.getJSONObject("originator").getLong("sessionId");

        JSONArray mediaDescriptions = json.optJSONArray("mediaDescriptions");
        for (int i = 0; i < mediaDescriptions.length(); i++) {
            JSONObject mediaDescriptionObject = mediaDescriptions.getJSONObject(i);
            try {
                mMediaDescriptions.append(i, RemoteMediaDescription.fromJson(mediaDescriptionObject));
            } catch (JSONException exception) {
                Log.w(TAG, "failed to read media description: " + exception);
            }
        }
    }

    public static RemoteSessionDescription fromJson(JSONObject json) throws JSONException {
        return new RemoteSessionDescription(json);
    }

    public long getSessionId() {
        return mSessionId;
    }

    public SparseArray<RemoteMediaDescription> getMediaDescriptions() {
        return mMediaDescriptions;
    }

    public RemoteMediaDescription getMediaDescription(MediaType mediaType) {
        for (int i = 0; i < mMediaDescriptions.size(); i++) {
            RemoteMediaDescription mediaDescription = mMediaDescriptions.valueAt(i);
            if (mediaDescription.getMediaType() == mediaType) {
                return mediaDescription;
            }
        }
        return null;
    }
}
