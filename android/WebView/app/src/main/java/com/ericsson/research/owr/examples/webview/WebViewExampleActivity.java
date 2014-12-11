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

package com.ericsson.research.owr.examples.webview;

import android.app.Activity;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.view.Window;
import android.webkit.ValueCallback;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.ericsson.research.owr.OwrBridge;

public class WebViewExampleActivity extends Activity {
    private static final String TAG = "WebViewExampleActivity";

    static {
        // Start the OpenWebRTC bridge at startup
        OwrBridge.start();

        // Enable remote debugging of WebViews
        WebView.setWebContentsDebuggingEnabled(true);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setContentView(R.layout.activity_openwebrtc);

        WebView webView = (WebView) findViewById(R.id.web_view);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);

        webView.setWebViewClient(new InternalWebViewClient());

        webView.loadUrl("file:///android_asset/selfview.html");
    }

    private class InternalWebViewClient extends WebViewClient {
        private OwrClientInjector mOwrClientInjector;
        /**
         * The initial script injection fails when navigating between pages because onPageStarted
         * is called while the current page is still loaded. A workaround for this is to
         * keep trying to inject the script until it is executed in the new page.
         */
        @Override
        public void onPageStarted(final WebView view, final String url, final Bitmap favicon) {
            Log.d(TAG, "onPageStarted: " + url);

            if (mOwrClientInjector != null) {
                // Stop the old injector, in case we load a new page before the injection is complete
                mOwrClientInjector.stop();
            }
            mOwrClientInjector = new OwrClientInjector(view);
            mOwrClientInjector.start();

            super.onPageStarted(view, url, favicon);
        }

        @Override
        public void onPageFinished(final WebView view, final String url) {
            Log.d(TAG, "onPageFinished: " + url);

            if (mOwrClientInjector != null) {
                // Once the page has finished the injection should be completed
                mOwrClientInjector.stop();
            }
            super.onPageFinished(view, url);
        }
    }

    private class OwrClientInjector implements ValueCallback<String> {
        /**
         * A script which attempts to load owr.js using a synchronous AJAX request and eval
         */
        private static final String INJECT_JS = "" +
                "(function () {" +
                "    if (window.webkitRTCPeerConnection)" +
                "        return '';" +
                "    var xhr = new XMLHttpRequest();" +
                "    xhr.open('GET', 'http://localhost:10717/owr.js', false);" +
                "    xhr.send();" +
                "    eval(xhr.responseText);" +
                "    return 'ok';" +
                "}())";

        private final WebView mWebView;

        private boolean mRunning = true;

        public OwrClientInjector(final WebView webView) {
            mWebView = webView;
        }

        private void stop() {
            mRunning = false;
            Log.d(TAG, "injector stopped");
        }

        private void start() {
            mWebView.evaluateJavascript(INJECT_JS, this);
        }

        @Override
        public void onReceiveValue(final String value) {
            if (mRunning) {
                // The injected script returns "ok" if the injection was successful.
                boolean injectionWasSuccessful = "\"ok\"".equals(value);

                // When webView.getUrl() returns the expected url the script should have been injected.
                if (injectionWasSuccessful) {
                    Log.d(TAG, "injection successful");
                } else {
                    mWebView.evaluateJavascript(INJECT_JS, this);
                }
            }
        }
    }

    /**
     * Shutdown the process as a workaround until cleanup has been fully implemented
     */
    @Override
    protected void onStop() {
        finish();
        System.exit(0);
    }
}
