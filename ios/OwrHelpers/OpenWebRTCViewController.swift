//
//  OpenWebRTCViewController.swift
//  SimpleDemoSwift
//
//  Created by Joseph Ross on 12/12/14.
//  Copyright (c) 2014 Savant Systems LLC. All rights reserved.
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

