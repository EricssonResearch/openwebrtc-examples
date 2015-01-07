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

import android.app.Activity;
import android.content.res.Configuration;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.util.Log;
import android.view.KeyEvent;
import android.view.TextureView;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.ericsson.research.owr.CaptureSourcesCallback;
import com.ericsson.research.owr.MediaSource;
import com.ericsson.research.owr.MediaType;
import com.ericsson.research.owr.Owr;

import java.util.EnumSet;
import java.util.List;

public class NativeCallExampleActivity extends Activity implements SignalingChannel.JoinListener, SignalingChannel.DisconnectListener, SignalingChannel.SessionFullListener, PeerHandler.CallStateListener {
    private static final String TAG = "NativeCallExampleActivity";

    private static final String PREFERENCE_KEY_SERVER_URL = "url";
    private static final int SETTINGS_ANIMATION_DURATION = 400;
    private static final int SETTINGS_ANIMATION_ANGLE = 90;

    /**
     * Initialize OpenWebRTC at startup
     */
    static {
        Owr.init();
        Owr.getCaptureSources(EnumSet.of(MediaType.VIDEO, MediaType.AUDIO), new CaptureSourcesCallback() {
            @Override
            public void onCaptureSourcesCallback(final List<MediaSource> sources) {
                MediaController.create(sources);
            }
        });
    }

    private Button mJoinButton;
    private Button mCallButton;
    private EditText mSessionInput;
    private CheckBox mAudioCheckBox;
    private CheckBox mVideoCheckBox;
    private EditText mUrlSetting;
    private View mHeader;
    private View mSettingsHeader;

    private SignalingChannel mSignalingChannel;
    private PeerHandler mPeerHandler;
    private MediaController mMediaController;
    private InputMethodManager mInputMethodManager;
    private WindowManager mWindowManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        initUi();

        mInputMethodManager = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);

        mMediaController = MediaController.getInstance();
        mMediaController.setSelfView((TextureView) findViewById(R.id.self_view));
        mMediaController.setRemoteView((TextureView) findViewById(R.id.remote_view));
        mJoinButton.setEnabled(true);

        mWindowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        mMediaController.setDeviceOrientation(mWindowManager.getDefaultDisplay().getRotation());
    }

    @Override
    public void onConfigurationChanged(final Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        initUi();
        Log.e(TAG, "set self view: " + findViewById(R.id.self_view));
        mMediaController.setSelfView((TextureView) findViewById(R.id.self_view));
        mMediaController.setRemoteView((TextureView) findViewById(R.id.remote_view));
        mMediaController.setDeviceOrientation(mWindowManager.getDefaultDisplay().getRotation());
        if (mPeerHandler != null) {
            mPeerHandler.setDeviceOrientation(mWindowManager.getDefaultDisplay().getRotation());
        }
    }

    public void initUi() {
        setContentView(R.layout.activity_openwebrtc);

        mCallButton = (Button) findViewById(R.id.call);
        mJoinButton = (Button) findViewById(R.id.join);
        mSessionInput = (EditText) findViewById(R.id.session_id);
        mAudioCheckBox = (CheckBox) findViewById(R.id.audio);
        mVideoCheckBox = (CheckBox) findViewById(R.id.video);

        mHeader = findViewById(R.id.header);
        mHeader.setCameraDistance(getResources().getDisplayMetrics().widthPixels * 5);
        mHeader.setPivotX(getResources().getDisplayMetrics().widthPixels / 2);
        mHeader.setPivotY(0);
        mSettingsHeader = findViewById(R.id.settings_header);
        mSettingsHeader.setCameraDistance(getResources().getDisplayMetrics().widthPixels * 5);
        mSettingsHeader.setPivotX(getResources().getDisplayMetrics().widthPixels / 2);
        mSettingsHeader.setPivotY(0);

        mUrlSetting = (EditText) findViewById(R.id.url_setting);
        mUrlSetting.setText(getUrl());
        mUrlSetting.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(final TextView view, final int actionId, final KeyEvent event) {
                if (actionId == EditorInfo.IME_ACTION_DONE) {
                    hideSettings();
                    String url = view.getText().toString();
                    saveUrl(url);
                    return true;
                }
                return false;
            }
        });
    }

    public void onCallClicked(final View view) {
        Log.d(TAG, "onCallClicked");

        if (mPeerHandler != null) {
            mPeerHandler.call();
            mCallButton.setEnabled(false);
        }
    }

    public void onSelfViewClicked(final View view) {
        Log.d(TAG, "onSelfViewClicked");
        mMediaController.toggleCamera();
    }

    public void onJoinClicked(final View view) {
        Log.d(TAG, "onJoinClicked");

        String sessionId = mSessionInput.getText().toString();
        if (sessionId.isEmpty()) {
            mSessionInput.requestFocus();
            mInputMethodManager.showSoftInput(mSessionInput, InputMethodManager.SHOW_IMPLICIT);
            return;
        }

        mInputMethodManager.hideSoftInputFromWindow(mSessionInput.getWindowToken(), 0);
        mSessionInput.setEnabled(false);
        mJoinButton.setEnabled(false);
        mAudioCheckBox.setEnabled(false);
        mVideoCheckBox.setEnabled(false);

        mMediaController.showSelfView();

        mSignalingChannel = new SignalingChannel(getUrl(), sessionId);
        mSignalingChannel.setJoinListener(this);
        mSignalingChannel.setDisconnectListener(this);
        mSignalingChannel.setSessionFullListener(this);
    }

    @Override
    public void onPeerJoin(final SignalingChannel.PeerChannel peerChannel) {
        Log.v(TAG, "onPeerJoin => " + peerChannel.getPeerId());
        mCallButton.setEnabled(true);
        boolean wantAudio = mAudioCheckBox.isChecked();
        boolean wantVideo = mVideoCheckBox.isChecked();
        mPeerHandler = new PeerHandler(peerChannel, mMediaController, wantAudio, wantVideo, this);
        mPeerHandler.setDeviceOrientation(mWindowManager.getDefaultDisplay().getRotation());
    }

    @Override
    public void onIncomingCall() {
        Log.d(TAG, "onIncomingCall");
        mCallButton.setEnabled(false);
    }

    @Override
    public void onPeerDisconnect(final String peerId) {
        Log.d(TAG, "onPeerDisconnect => " + peerId);
        mCallButton.setEnabled(false);
        mMediaController.clearRemoteSources();
        mPeerHandler = null;
    }

    @Override
    public void onDisconnect() {
        Toast.makeText(this, "Disconnected from session", Toast.LENGTH_LONG).show();
        mJoinButton.setEnabled(true);
        mMediaController.hideSelfView();
        mMediaController.clearRemoteSources();
        mAudioCheckBox.setEnabled(true);
        mVideoCheckBox.setEnabled(true);
        mSignalingChannel = null;
    }

    @Override
    public void onSessionFull() {
        Toast.makeText(this, "Session is full", Toast.LENGTH_LONG).show();
        mJoinButton.setEnabled(true);
    }

    public void onSettingsClicked(final View view) {
        showSettings();
    }

    public void onCancelSettingsClicked(final View view) {
        hideSettings();
    }

    private void showSettings() {
        mUrlSetting.requestFocus();
        mInputMethodManager.showSoftInput(mUrlSetting, InputMethodManager.SHOW_IMPLICIT);
        mSettingsHeader.setVisibility(View.VISIBLE);
        mSettingsHeader.setRotationX(SETTINGS_ANIMATION_ANGLE);
        mSettingsHeader.animate().rotationX(0).setDuration(SETTINGS_ANIMATION_DURATION).start();
        mHeader.setVisibility(View.VISIBLE);
        mHeader.animate()
                .rotationX(-SETTINGS_ANIMATION_ANGLE)
                .setDuration(SETTINGS_ANIMATION_DURATION)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        mHeader.setVisibility(View.INVISIBLE);
                    }
                }).start();
    }

    private void hideSettings() {
        mInputMethodManager.hideSoftInputFromWindow(mUrlSetting.getWindowToken(), 0);
        mHeader.setVisibility(View.VISIBLE);
        mHeader.setRotationX(SETTINGS_ANIMATION_ANGLE);
        mHeader.animate().rotationX(0).setDuration(SETTINGS_ANIMATION_DURATION).start();
        mSettingsHeader.setVisibility(View.VISIBLE);
        mSettingsHeader.animate()
                .rotationX(-SETTINGS_ANIMATION_ANGLE)
                .setDuration(SETTINGS_ANIMATION_DURATION)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        mSettingsHeader.setVisibility(View.INVISIBLE);
                    }
                }).start();
    }

    private void saveUrl(final String url) {
        PreferenceManager.getDefaultSharedPreferences(this).edit()
                .putString(PREFERENCE_KEY_SERVER_URL, url).commit();
    }

    private String getUrl() {
        return PreferenceManager.getDefaultSharedPreferences(this)
                .getString(PREFERENCE_KEY_SERVER_URL, Config.DEFAULT_SERVER_ADDRESS);
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
