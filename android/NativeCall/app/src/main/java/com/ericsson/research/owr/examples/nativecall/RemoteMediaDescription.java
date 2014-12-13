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

import com.ericsson.research.owr.AudioPayload;
import com.ericsson.research.owr.Candidate;
import com.ericsson.research.owr.CandidateType;
import com.ericsson.research.owr.CodecType;
import com.ericsson.research.owr.ComponentType;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.Payload;
import com.ericsson.research.owr.TransportType;
import com.ericsson.research.owr.VideoPayload;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

class RemoteMediaDescription {
    public static final String TAG = "RemoteMediaDescription";

    private final int mMediaType;
    private final boolean mRtcpMux;
    private final List<Payload> mPayloads = new ArrayList<>();
    private final String mPassword;
    private final String mUfrag;
    private final List<Candidate> mCandidates = new ArrayList<>();
    private final String mFingerprintHashFunction;
    private final String mFingerprint;
    private final String mDtlsSetup;
    private final List<Long> mSsrcs = new ArrayList<>();
    private final String mCname;
    private final String mMode;

    private RemoteMediaDescription(JSONObject json) throws JSONException {
        String type = json.getString("type");
        if ("video".equals(type)) {
            mMediaType = MediaType.VIDEO;
        } else if ("audio".equals(type)) {
            mMediaType = MediaType.AUDIO;
        } else {
            throw new FormatException("unknown media type: " + type);
        }

        mMode = json.optString("mode");
        mCname = json.optString("cname");
        mRtcpMux = json.getJSONObject("rtcp").getBoolean("mux");

        JSONArray ssrcs = json.optJSONArray("ssrcs");
        if (ssrcs != null) {
            for (int i = 0; i < ssrcs.length(); i++) {
                mSsrcs.add(ssrcs.getLong(i));
            }
        }

        JSONArray payloads = json.getJSONArray("payloads");
        for (int i = 0; i < payloads.length(); i++) {
            JSONObject payload = payloads.getJSONObject(i);
            String encodingName = payload.getString("encodingName");
            try {
                CodecType codecType = CodecType.valueOf(encodingName.toUpperCase());
                int payloadType = payload.getInt("type");
                int clockRate = payload.getInt("clockRate");

                if (mMediaType == MediaType.VIDEO) {
                    boolean nackpli = payload.getBoolean("nackpli");
                    boolean ccmfir = payload.getBoolean("ccmfir");
                    mPayloads.add(new VideoPayload(codecType, payloadType, clockRate, nackpli, ccmfir));
                } else if (mMediaType == MediaType.AUDIO) {
                    int channels = payload.getInt("channels");
                    mPayloads.add(new AudioPayload(codecType, payloadType, clockRate, channels));
                }
            } catch (IllegalArgumentException ignored) {
            }
        }

        if (getSelectedPayload() == null) {
            throw new FormatException("no suitable payload type found");
        }

        JSONObject ice = json.getJSONObject("ice");
        mUfrag = ice.getString("ufrag");
        mPassword = ice.getString("password");

        JSONArray candidates = ice.optJSONArray("candidates");
        if (candidates != null) {
            for (int i = 0; i < candidates.length(); i++) {
                try {
                    Candidate candidate = deserializeCandidate(candidates.getJSONObject(i));
                    if (!isRtcpMux() || candidate.getComponentType() != ComponentType.RTCP) {
                        mCandidates.add(candidate);
                    }
                } catch (JSONException exception) {
                    Log.w(TAG, "failed to read candidate: " + exception);
                }
            }
        }

        JSONObject dtls = json.getJSONObject("dtls");
        mFingerprintHashFunction = dtls.getString("fingerprintHashFunction");
        mFingerprint = dtls.getString("fingerprint");
        mDtlsSetup = dtls.getString("setup");
    }

    public Candidate addCandidate(JSONObject candidateJson) throws JSONException {
        Log.e(TAG, "adding remote candidate: " + candidateJson.toString());
        JSONObject candidateDescription = candidateJson.getJSONObject("candidateDescription");
        Candidate candidate = deserializeCandidate(candidateDescription);

        if (!isRtcpMux() || candidate.getComponentType() != ComponentType.RTCP) {
            mCandidates.add(candidate);
            return candidate;
        }
        return null;
    }

    public static RemoteMediaDescription fromJson(JSONObject json) throws JSONException {
        return new RemoteMediaDescription(json);
    }

    public int getMediaType() {
        return mMediaType;
    }

    public String getMode() {
        return mMode;
    }

    public boolean isRtcpMux() {
        return mRtcpMux;
    }

    public List<Payload> getPayloads() {
        return mPayloads;
    }

    public Payload getSelectedPayload() {
        Payload[] defaultPayloads = Config.getDefaultPayloadsForMediaType(mMediaType);

        for (Payload defaultPayload : defaultPayloads) {
            for (Payload payload : mPayloads) {
                if (defaultPayload.getCodecType() == payload.getCodecType()) {
                    return payload;
                }
            }
        }
        return null;
    }

    public String getPassword() {
        return mPassword;
    }

    public String getUfrag() {
        return mUfrag;
    }

    public List<Candidate> getCandidates() {
        return mCandidates;
    }

    public String getCname() {
        return mCname;
    }

    public String getFingerprintHashFunction() {
        return mFingerprintHashFunction;
    }

    public String getFingerprint() {
        return mFingerprint;
    }

    public String getDtlsSetup() {
        return mDtlsSetup;
    }

    public List<Long> getSsrcs() {
        return mSsrcs;
    }

    private Candidate deserializeCandidate(final JSONObject candidateJson) throws JSONException {
        Candidate candidate = new Candidate(
                candidateTypeFromJson(candidateJson),
                componentTypeFromJson(candidateJson)
        );
        candidate.setTransportType(transportTypeFromJson(candidateJson));
        candidate.setAddress(candidateJson.getString("address"));
        candidate.setPort(candidateJson.getInt("port"));
        candidate.setBaseAddress(candidateJson.optString("relatedAddress", ""));
        candidate.setBasePort(candidateJson.optInt("relatedPort", 0));
        candidate.setPriority(candidateJson.getInt("priority"));
        candidate.setUfrag(getUfrag());
        candidate.setPassword(getPassword());
        return candidate;
    }

    private static CandidateType candidateTypeFromJson(JSONObject json) throws JSONException {
        String type = json.getString("type");
        switch (type) {
            case "host":
                return CandidateType.HOST;
            case "srflx":
                return CandidateType.SERVER_REFLEXIVE;
            case "prflx":
                return CandidateType.PEER_REFLEXIVE;
            case "relay":
                return CandidateType.RELAY;
            default:
                throw new JSONException("unknown candidate type: " + type);
        }
    }

    private static ComponentType componentTypeFromJson(JSONObject json) throws JSONException {
        int componentId = json.getInt("componentId");
        switch (componentId) {
            case 1:
                return ComponentType.RTP;
            case 2:
                return ComponentType.RTCP;
            default:
                throw new JSONException("unknown component id: " + componentId);
        }
    }

    private static TransportType transportTypeFromJson(JSONObject json) throws JSONException {
        String transportType = json.getString("transport");
        if (transportType.equals("TCP")) {
            String tcpType = json.getString("tcpType");
            switch (tcpType) {
                case "active":
                    return TransportType.TCP_ACTIVE;
                case "passive":
                    return TransportType.TCP_PASSIVE;
                case "so":
                    return TransportType.TCP_SO;
                default:
                    throw new JSONException("unknown tcp type: " + tcpType);
            }
        } else if (transportType.equals("UDP")) {
            return TransportType.UDP;
        } else {
            throw new JSONException("unknown transport type: " + transportType);
        }
    }

    private static class FormatException extends JSONException {
        public FormatException(String message) {
            super(message);
        }
    }
}
