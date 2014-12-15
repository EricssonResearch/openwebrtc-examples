//
//  OpenWebRTCViewController.swift
//  SimpleDemoSwift
//
//  Created by Joseph Ross on 12/12/14.
//  Copyright (c) 2014 Savant Systems LLC. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or other
//  materials provided with the distribution.

//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
//  OF SUCH DAMAGE.
//

import UIKit
import GLKit
import WebKit
import AVFoundation

let kBridgeLocalURL = "http://localhost:10717/owr.js"

@objc
class OpenWebRTCViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, OpenWebRTCWebViewDelegate {
    
    private var pageNavigationTimer:NSTimer?
    private var _URL:String?
    @IBOutlet var selfView:GLKView?
    @IBOutlet var remoteView:GLKView?
    @IBOutlet var browserView:OpenWebRTCWebView?
    var javascriptCode:String? = nil
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
    }
    
    class func initOpenWebRTC() {
        owr_bridge_start_in_thread()
        
        var theError:NSError? = nil
        var result:Bool = true
        
        UIApplication.sharedApplication().idleTimerDisabled = true
        UIApplication.sharedApplication().statusBarStyle = UIStatusBarStyle.LightContent
        
        let myAudioSession = AVAudioSession.sharedInstance()
        
        result = myAudioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, error: &theError)
        if !result {
            println("setCategory failed")
        }
        
        result = myAudioSession.setActive(true, error: &theError)
        if !result {
            println("setActive failed")
        }
    }
    
    func loadRequestWithUrl(url:String) {
        _URL = url
        var request:NSURLRequest? = NSURLRequest(URL: NSURL(string: url)!, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 10)
        browserView?.loadRequest(request!)
        
    }
    
    func userContentController(userContentController:WKUserContentController, didReceiveScriptMessage message:WKScriptMessage) {
        println("Placeholder: Received message from JavaScript: \(message)")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        javascriptCode = "(function () {\n" +
        "    var xhr = new XMLHttpRequest();\n" +
        "    xhr.open(\"GET\", \"\(kBridgeLocalURL)\", false);\n" +
        "    xhr.send();\n" +
        "    eval(xhr.responseText);\n" +
        "})()"
        
        browserView = OpenWebRTCWebView(frame: view.frame)
        view.addSubview(browserView!)
        
        browserView!.owrDelegate = self
        browserView!.navigationDelegate = self
        var userScript:WKUserScript? = WKUserScript(source: javascriptCode!, injectionTime: WKUserScriptInjectionTime.AtDocumentStart, forMainFrameOnly: true)
        browserView?.configuration.userContentController.addUserScript(userScript!)
        browserView?.configuration.userContentController.addScriptMessageHandler(self, name: "owr")
        
    }
    
    
    func webviewProgress(progress:Float) {
        
    }
    
    func newOwrMessage(message:String?) {
        
    }
    
    func newVideoRect(rect:CGRect, forSelfView rectIsSelfView:Bool) {
        
    }
}

