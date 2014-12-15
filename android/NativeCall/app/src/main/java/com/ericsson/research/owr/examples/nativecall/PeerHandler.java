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

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.ericsson.research.owr.AudioPayload;
import com.ericsson.research.owr.Candidate;
import com.ericsson.research.owr.MediaSession;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.Payload;
import com.ericsson.research.owr.Session;
import com.ericsson.research.owr.TransportAgent;
import com.ericsson.research.owr.VideoPayload;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class PeerHandler implements SignalingChannel.MessageListener {
    public static final String TAG = "PeerHandler";

    private enum State {
        INIT, WAITING_TO_OFFER, OFFERED, WAITING_TO_ANSWER, ACTIVE, INVALID;

//          WAITING_TO_ANSWER <--- INIT ---> WAITING_TO_OFFER
//                  |                                |        
//                  +-------> ACTIVE <--- OFFERED <--+    

        public boolean canInitiateCall() {
            return this == INIT;
        }

        public boolean hasRemoteDescription() {
            return this == WAITING_TO_ANSWER || this == ACTIVE;
        }

        public boolean canSendLocalDescription() {
            return this == WAITING_TO_OFFER || this == WAITING_TO_ANSWER;
        }

        public boolean canReceiveRemoteDescription() {
            return this == INIT || this == OFFERED;
        }
    }

    private State mState = State.INIT;

    private List<JSONObject> mRemoteCandidateBuffer = new ArrayList<>();

    private final SignalingChannel.PeerChannel mPeerChannel;
    private final MediaController mMediaController;
    private final boolean mWantAudio;
    private final boolean mWantVideo;
    private final CallStateListener mCallStateListener;

    private TransportAgent mTransportAgent;
    private MediaSession mAudioSession;
    private MediaSession mVideoSession;
    private RemoteSessionDescription mRemoteDescription;
    private LocalSessionDescription mLocalDescription;

    public PeerHandler(SignalingChannel.PeerChannel peerChannel, MediaController mediaController,
                       boolean wantAudio, boolean wantVideo, CallStateListener callStateListener) {
        mPeerChannel = peerChannel;
        mMediaController = mediaController;
        mWantAudio = wantAudio;
        mWantVideo = wantVideo;
        mCallStateListener = callStateListener;
        peerChannel.setMessageListener(this);
        peerChannel.setDisconnectListener(new SignalingChannel.DisconnectListener() {
            @Override
            public void onDisconnect() {
                mState = State.INVALID;
                mMediaController.clearRemoteSources();
                mCallStateListener.onPeerDisconnect(mPeerChannel.getPeerId());
            }
        });
    }

    @Override
    public synchronized void onMessage(final JSONObject json) {
        try {
            if (json.has("candidate")) {
                handleRemoteCandidate(json.getJSONObject("candidate"));
            }
            if (json.has("sessionDescription")) {
                handleSessionDescription(json.getJSONObject("sessionDescription"));
            }
            if (json.has("orientation")) {
                handleOrientation(json.getInt("orientation"));
            }
        } catch (JSONException exception) {
            Log.e(TAG, "failed to read message: " + exception);
        }
    }

    public void setDeviceOrientation(final int orientation) {
        int angle = ((orientation + 3) % 4) * 90;
        JSONObject json = new JSONObject();
        try {
            json.put("orientation", angle);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        mPeerChannel.send(json);
    }

    public synchronized void call() {
        if (!mState.canInitiateCall()) {
            return;
        }

        mLocalDescription = LocalSessionDescription.createOffer(mWantAudio, mWantVideo);
        initialSetup(true);

        if (mWantAudio) {
        }
        if (mWantVideo) {
            for (Payload payload : mLocalDescription.getMediaDescription(MediaType.VIDEO).getPayloads()) {
                mVideoSession.addReceivePayload(clonePayload(payload));
            }
        }
        mState = State.WAITING_TO_OFFER;
    }

    private void handleRemoteCandidate(JSONObject json) throws JSONException {
        if (mState.hasRemoteDescription()) {
            addRemoteCandidate(json);
        } else {
            mRemoteCandidateBuffer.add(json);
        }
    }

    private void addRemoteCandidate(JSONObject json) throws JSONException {
        int mlineIndex = json.getInt("sdpMLineIndex");
        String mediaTypeString = json.getString("sdpMid");

        RemoteMediaDescription mediaDescription = mRemoteDescription.getMediaDescriptions().get(mlineIndex);
        Candidate candidate = mediaDescription.addCandidate(json);
        if (candidate == null) {
            return;
        }

        MediaSession mediaSession = null;

        int mediaType = mediaDescription.getMediaType();
        if (mediaType == MediaType.AUDIO) {
            mediaSession = mAudioSession;
        } else if (mediaType == MediaType.VIDEO) {
            mediaSession = mVideoSession;
        }

        if (mediaSession != null) {
            mediaSession.addRemoteCandidate(candidate);
            Log.e(TAG, "added remote candidate: " + candidate);
        }
    }

    private void handleOrientation(int angle) {
        Log.d(TAG, "got orientation: " + angle);
    }

    private void initialSetup(boolean isInitiator) {
        mTransportAgent = new TransportAgent(isInitiator);
        for (Config.HelperServer h : Config.HELPER_SERVERS) {
            mTransportAgent.addHelperServer(h.type, h.address, h.port, h.username, h.password);
        }
        mTransportAgent.setIceControllingMode(isInitiator);

        if (mWantAudio) {
            LocalMediaDescription mediaDescription = mLocalDescription.getMediaDescription(MediaType.AUDIO);
            mAudioSession = createMediaSession(isInitiator, mediaDescription);
            mMediaController.setAudioSession(mAudioSession);
        }
        if (mWantVideo) {
            LocalMediaDescription mediaDescription = mLocalDescription.getMediaDescription(MediaType.VIDEO);
            mVideoSession = createMediaSession(isInitiator, mediaDescription);
            mMediaController.setVideoSession(mVideoSession);
        }
    }

    private MediaSession createMediaSession(boolean isInitiator, LocalMediaDescription mediaDescription) {
        MediaSession mediaSession = new MediaSession(!isInitiator);
        mediaSession.setRtcpMux(true);
        for (Payload payload : mediaDescription.getPayloads()) {
            mediaSession.addReceivePayload(clonePayload(payload));
        }
        MediaSessionEventListener mediaSessionEventListener = new MediaSessionEventListener(mediaDescription);
        mediaSession.addNewCandidateListener(mediaSessionEventListener);
        mediaSession.addDtlsCertificateChangeListener(mediaSessionEventListener);
        mediaSession.addSendSsrcChangeListener(mediaSessionEventListener);
        mediaSession.addCnameChangeListener(mediaSessionEventListener);
        mTransportAgent.addSession(mediaSession);
        return mediaSession;
    }

    private void continueIfLocalDescriptionIsComplete() {
        if (mLocalDescription.isComplete()) {
            onLocalDescriptionCompleted();
        }
    }

    private synchronized void onLocalDescriptionCompleted() {
        if (!mState.canSendLocalDescription()) {
            Log.w(TAG, "invalid state when completing local description: " + mState);
            return;
        }

        try {
            JSONObject message = new JSONObject();
            message.put("sessionDescription", mLocalDescription.toJson());
            if (mState == State.WAITING_TO_ANSWER) {
                message.put("type", "answer");
                mState = State.ACTIVE;
            } else if (mState == State.WAITING_TO_OFFER) {
                message.put("type", "offer");
                mState = State.OFFERED;
            }
            mPeerChannel.send(message);
        } catch (JSONException exception) {
            Log.e(TAG, "failed to serialize session: " + exception);
            mState = State.INVALID;
        }
    }

    private void handleSessionDescription(final JSONObject json) throws JSONException {
        if (!mState.canReceiveRemoteDescription()) {
            Log.w(TAG, "invalid state when receiving session description: " + mState);
            return;
        }

        mRemoteDescription = RemoteSessionDescription.fromJson(json);
        for (JSONObject jsonObject : mRemoteCandidateBuffer) {
            addRemoteCandidate(jsonObject);
        }
        mRemoteCandidateBuffer.clear();

        if (mState == State.INIT) {
            mLocalDescription = LocalSessionDescription.createAnswer(mRemoteDescription, mWantAudio, mWantVideo);
            initialSetup(false);
        } else {
            mLocalDescription.addAnswer(mRemoteDescription);
        }

        RemoteMediaDescription audioDescription = mRemoteDescription.getMediaDescription(MediaType.AUDIO);
        if (audioDescription != null) {
            mAudioSession.setSendPayload(clonePayload(audioDescription.getSelectedPayload()));
            mAudioSession.setRtcpMux(audioDescription.isRtcpMux());
            for (Candidate candidate : audioDescription.getCandidates()) {
                mAudioSession.addRemoteCandidate(candidate);
            }
        }

        RemoteMediaDescription videoDescription = mRemoteDescription.getMediaDescription(MediaType.VIDEO);
        if (videoDescription != null) {
            mVideoSession.setSendPayload(clonePayload(videoDescription.getSelectedPayload()));
            mVideoSession.setRtcpMux(videoDescription.isRtcpMux());
            for (Candidate candidate : videoDescription.getCandidates()) {
                mVideoSession.addRemoteCandidate(candidate);
            }
        }

        if (mState == State.INIT) {
            if (mWantAudio) {
                Payload payload = mLocalDescription.getMediaDescription(MediaType.AUDIO).getPayloads().get(0);
                mAudioSession.addReceivePayload(clonePayload(payload));
            }
            if (mWantVideo) {
                Payload payload = mLocalDescription.getMediaDescription(MediaType.VIDEO).getPayloads().get(0);
                mVideoSession.addReceivePayload(clonePayload(payload));
            }
            mState = State.WAITING_TO_ANSWER;
        } else {
            mState = State.ACTIVE;
        }
    }

    private static Payload clonePayload(Payload payload) {
        if (payload instanceof VideoPayload) {
            VideoPayload videoPayload = (VideoPayload) payload;
            return new VideoPayload(
                    videoPayload.getCodecType(),
                    videoPayload.getPayloadType(),
                    videoPayload.getClockRate(),
                    videoPayload.getNackPli(),
                    videoPayload.getCcmFir()
            );
        } else if (payload instanceof AudioPayload) {
            AudioPayload audioPayload = (AudioPayload) payload;
            return new AudioPayload(
                    audioPayload.getCodecType(),
                    audioPayload.getPayloadType(),
                    audioPayload.getClockRate(),
                    audioPayload.getChannels()
            );
        } else {
            throw new IllegalArgumentException("unknown payload: " + payload);
        }
    }

    private class MediaSessionEventListener implements
            Session.NewCandidateListener,
            Session.DtlsCertificateChangeListener,
            MediaSession.SendSsrcChangeListener,
            MediaSession.CnameChangeListener {
        private final LocalMediaDescription mMediaDescription;

        public MediaSessionEventListener(LocalMediaDescription mediaDescription) {
            mMediaDescription = mediaDescription;
        }

        @Override
        public void onNewCandidate(final Candidate candidate) {
            if (mState == State.ACTIVE || mState == State.OFFERED) {
                try {
                    JSONObject json = mMediaDescription.serializeCandidate(candidate);
                    JSONObject message = new JSONObject();
                    message.put("candidate", json);
                    mPeerChannel.send(message);
                } catch (JSONException exception) {
                    Log.w(TAG, "failed to serialize candidate: " + exception);
                }
            } else {
                Log.d(TAG, "onNewCandidate: " + candidate);
                mMediaDescription.addCandidate(candidate);
                continueIfLocalDescriptionIsComplete();
            }
        }

        @Override
        public void onCnameChanged(final String cname) {
            Log.d(TAG, "onCnameChanged: " + cname);
            mMediaDescription.setCname(cname);
            continueIfLocalDescriptionIsComplete();
        }

        @Override
        public void onDtlsCertificateChanged(final String pem) {
            Log.d(TAG, "onDtlsCertificateChanged: " + pem);
            mMediaDescription.setDtlsCertificate(pem);
            continueIfLocalDescriptionIsComplete();
        }

        @Override
        public void onSendSsrcChanged(final int ssrc) {
            Log.d(TAG, "onSendSsrcChanged: " + ssrc);
            mMediaDescription.addSsrc(ssrc);
            continueIfLocalDescriptionIsComplete();
        }
    }

    public static interface CallStateListener {
        public void onIncomingCall();

        public void onPeerDisconnect(final String peerId);
    }
}
