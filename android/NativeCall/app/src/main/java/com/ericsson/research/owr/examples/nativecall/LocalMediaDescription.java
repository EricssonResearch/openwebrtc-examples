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

import android.util.Base64;
import android.util.Log;

import com.ericsson.research.owr.AudioPayload;
import com.ericsson.research.owr.Candidate;
import com.ericsson.research.owr.CandidateType;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.Payload;
import com.ericsson.research.owr.TransportType;
import com.ericsson.research.owr.VideoPayload;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import java.util.regex.Pattern;

class LocalMediaDescription {
    public static final String TAG = "MediaDescription";

    private final MediaType mMediaType;
    private final boolean mIsOffer;
    private final String mFingerprintHashFunction;
    private final List<Candidate> mCandidates = new ArrayList<>();
    private final List<Long> mSsrcs = new ArrayList<>();

    private List<Payload> mPayloads;
    private boolean mRtcpMux;
    private String mDtlsSetup;
    private String mFingerprint;
    private String mCname;
    private String mPassword;
    private String mUfrag;
    private int mLineIndex;

    /* answer */
    private LocalMediaDescription(RemoteMediaDescription remoteDescription) {
        mIsOffer = false;
        mMediaType = remoteDescription.getMediaType();
        mRtcpMux = remoteDescription.isRtcpMux();
        mPayloads = Arrays.asList(remoteDescription.getSelectedPayload());
        mFingerprintHashFunction = remoteDescription.getFingerprintHashFunction();
        mDtlsSetup = "active";
    }

    /* offer */
    private LocalMediaDescription(MediaType mediaType) {
        mIsOffer = true;
        mMediaType = mediaType;
        mRtcpMux = true;
        mPayloads = Arrays.asList(Config.getDefaultPayloadsForMediaType(mediaType));
        mFingerprintHashFunction = Config.DEFAULT_DTLS_FINGERPRINT_HASH_FUNCTION;
        mDtlsSetup = "actpass";
    }

    public synchronized boolean isComplete() {
        if (getFingerprint() == null) {
            return false;
        } else if (getSsrcs().isEmpty()) {
            return false;
        } else if (getCname() == null) {
            return false;
        } else if (getCandidates().isEmpty()) {
            return false;
        }
        return true;
    }

    public static LocalMediaDescription createOffeer(MediaType mediaType) {
        return new LocalMediaDescription(mediaType);
    }

    public static LocalMediaDescription createAnswer(RemoteMediaDescription remoteDescription) {
        return new LocalMediaDescription(remoteDescription);
    }

    public synchronized void setDtlsCertificate(String pem) {
        mFingerprint = fingerprintFromPem(pem, Config.DEFAULT_DTLS_FINGERPRINT_HASH_FUNCTION);
    }

    public synchronized void addSsrc(int ssrc) {
        long unsignedSsrc = ssrc & 0xFFFFFFFFl;
        if (unsignedSsrc > 0) {
            mSsrcs.add(unsignedSsrc);
        }
    }

    public synchronized void setCname(String cname) {
        mCname = cname;
    }

    public synchronized void addCandidate(Candidate candidate) {
        if (mCandidates.isEmpty()) {
            mUfrag = candidate.getUfrag();
            mPassword = candidate.getPassword();
        }
        mCandidates.add(candidate);
    }

    public synchronized void addAnswer(RemoteMediaDescription remoteDescription) {
        if (!mIsOffer) {
            throw new IllegalStateException("tried to add remote description to an answer");
        }

        if (getMediaType() != remoteDescription.getMediaType()) {
            throw new IllegalStateException("media type  mismatch");
        }

        mRtcpMux = remoteDescription.isRtcpMux();
        if (remoteDescription.getDtlsSetup().equals("passive")) {
            mDtlsSetup = "active";
        } else {
            mDtlsSetup = "passive";
        }

        mPayloads = Arrays.asList(remoteDescription.getSelectedPayload());
    }

    public int getLineIndex() {
        return mLineIndex;
    }

    public void setLineIndex(final int lineIndex) {
        mLineIndex = lineIndex;
    }

    public MediaType getMediaType() {
        return mMediaType;
    }

    public boolean isRtcpMux() {
        return mRtcpMux;
    }

    public List<Payload> getPayloads() {
        return mPayloads;
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

    public boolean isDtlsClient() {
        return "active".equals(getDtlsSetup());
    }

    private static Random sRandom = new Random();

    private static String randomString() {
        byte[] randomBytes = new byte[27];
        sRandom.nextBytes(randomBytes);
        return new String(Base64.encode(randomBytes, Base64.NO_WRAP | Base64.NO_PADDING | Base64.CRLF));
    }

    public JSONObject toJson() throws JSONException {
        JSONObject mediaDescription = new JSONObject();

        if (getMediaType() == MediaType.VIDEO) {
            mediaDescription.put("type", "video");
        } else if (getMediaType() == MediaType.AUDIO) {
            mediaDescription.put("type", "audio");
        } else {
            throw new IllegalStateException("unknown media type: " + mMediaType);
        }

        mediaDescription.put("port", getCandidates().get(0).getPort());
        mediaDescription.put("protocol", "RTP/SAVPF");
        mediaDescription.put("netType", "IN");
        mediaDescription.put("addressType", "IP4");
        mediaDescription.put("address", "0.0.0.0");
        mediaDescription.put("mode", "sendrecv");
        mediaDescription.put("cname", getCname());
        mediaDescription.put("mediaStreamId", randomString());
        mediaDescription.put("mediaStreamTrackId", randomString());

        JSONArray payloads = new JSONArray();
        for (Payload payload : getPayloads()) {
            JSONObject payloadJson = new JSONObject();
            payloadJson.put("type", payload.getPayloadType());
            payloadJson.put("encodingName", payload.getCodecType().name());
            payloadJson.put("clockRate", payload.getClockRate());
            if (getMediaType() == MediaType.VIDEO) {
                payloadJson.put("nack", true);
                payloadJson.put("nackpli", ((VideoPayload) payload).getNackPli());
                payloadJson.put("ccmfir", ((VideoPayload) payload).getCcmFir());
            } else if (getMediaType() == MediaType.AUDIO) {
                payloadJson.put("channels", ((AudioPayload) payload).getChannels());
            }
            payloads.put(payloadJson);
        }
        mediaDescription.put("payloads", payloads);

        JSONObject rtcp = new JSONObject();
        rtcp.put("mux", isRtcpMux());
        mediaDescription.put("rtcp", rtcp);

        JSONArray ssrcs = new JSONArray(getSsrcs());
        mediaDescription.put("ssrcs", ssrcs);

        JSONObject ice = new JSONObject();
        ice.put("ufrag", getUfrag());
        ice.put("password", getPassword());
        JSONArray candidates = new JSONArray();
        for (Candidate candidate : getCandidates()) {
            candidates.put(candidateToJson(candidate));
        }
        ice.put("candidates", candidates);
        mediaDescription.put("ice", ice);

        JSONObject dtls = new JSONObject();
        dtls.put("fingerprintHashFunction", getFingerprintHashFunction());
        dtls.put("fingerprint", getFingerprint());
        dtls.put("setup", getDtlsSetup());
        mediaDescription.put("dtls", dtls);

        return mediaDescription;
    }

    public JSONObject serializeCandidate(final Candidate candidate) throws JSONException {
        JSONObject json = new JSONObject();

        json.put("candidateDescription", candidateToJson(candidate));

        if (getMediaType() == MediaType.VIDEO) {
            json.put("sdpMid", "video");
        } else if (getMediaType() == MediaType.AUDIO) {
            json.put("sdpMid", "audio");
        }

        json.put("sdpMLineIndex", getLineIndex());

        return json;
    }

    private static JSONObject candidateToJson(final Candidate candidate) throws JSONException {
        JSONObject candidateJson = new JSONObject();

        CandidateType candidateType = candidate.getType();
        if (candidateType == CandidateType.HOST) {
            candidateJson.put("type", "host");
        } else if (candidateType == CandidateType.SERVER_REFLEXIVE) {
            candidateJson.put("type", "srflx");
        } else if (candidateType == CandidateType.PEER_REFLEXIVE) {
            candidateJson.put("type", "prflx");
        } else if (candidateType == CandidateType.RELAY) {
            candidateJson.put("type", "relay");
        }

        TransportType transportType = candidate.getTransportType();
        if (transportType == TransportType.UDP) {
            candidateJson.put("transport", "UDP");
        } else if (transportType == TransportType.TCP_ACTIVE) {
            candidateJson.put("transport", "TCP");
            candidateJson.put("tcpType", "active");
        } else if (transportType == TransportType.TCP_PASSIVE) {
            candidateJson.put("transport", "TCP");
            candidateJson.put("tcpType", "passive");
        } else if (transportType == TransportType.TCP_SO) {
            candidateJson.put("transport", "TCP");
            candidateJson.put("tcpType", "so");
        }

        candidateJson.put("foundation", candidate.getFoundation());
        candidateJson.put("componentId", candidate.getComponentType().getValue());
        candidateJson.put("priority", candidate.getPriority());
        candidateJson.put("address", candidate.getAddress());

        int port = candidate.getPort();
        candidateJson.put("port", port != 0 ? port : 9);

        if (candidate.getType() != CandidateType.HOST) {
            candidateJson.put("relatedAddress", candidate.getBaseAddress());
            int basePort = candidate.getBasePort();
            candidateJson.put("relatedPort", basePort != 0 ? basePort : 9);
        }

        return candidateJson;
    }

    private static final Pattern sPemPattern = Pattern.compile(
            ".*-----BEGIN CERTIFICATE-----(.*)-----END CERTIFICATE-----.*",
            Pattern.DOTALL
    );

    private static String fingerprintFromPem(String pem, String hashFunction) {
        String base64der = sPemPattern.matcher(pem).replaceFirst("$1").replaceAll("\r?\n", "");
        try {
            byte[] der = Base64.decode(base64der.getBytes("UTF8"), Base64.NO_WRAP | Base64.NO_PADDING | Base64.CRLF);
            if (der != null) {
                MessageDigest digest = MessageDigest.getInstance(hashFunction.toUpperCase());
                byte[] derHash = digest.digest(der);

                StringBuilder fingerprintBuilder = new StringBuilder(derHash.length * 3 - 1);
                for (int i = 0; i < derHash.length; i++) {
                    if (i > 0) {
                        fingerprintBuilder.append(':');
                    }
                    fingerprintBuilder.append(Character.forDigit((derHash[i] >> 4) & 0xF, 16));
                    fingerprintBuilder.append(Character.forDigit(derHash[i] & 0xF, 16));
                }

                return fingerprintBuilder.toString().toUpperCase();
            }
            return null;
        } catch (NoSuchAlgorithmException | UnsupportedEncodingException exception) {
            Log.e(TAG, "failed to parse pem certificate: " + exception);
            throw new RuntimeException(exception);
        }
    }
}
