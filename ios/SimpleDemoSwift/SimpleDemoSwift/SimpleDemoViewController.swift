//
//  ViewController.swift
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
import WebKit

class SimpleDemoViewController: OpenWebRTCViewController {

    @IBOutlet var roomSlider:UISlider?
    @IBOutlet var roomLabel:UILabel?
    @IBOutlet var joinButton:UIBarButtonItem?
    @IBOutlet var callButton:UIBarButtonItem?
    @IBOutlet var hangupButton:UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setToolbarHidden(false, animated: false)
        
        joinButton?.enabled = false
        callButton?.enabled = false
        hangupButton?.enabled = false
        
        loadRequestWithUrl("http://demo.openwebrtc.org")
        browserView?.hidden = false
        
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        joinButton?.enabled = true
    }
    
    @IBAction func joinButtonTapped(sender:AnyObject?) {
        let room = roomSlider?.value
        let js = "document.getElementById('join_but').click();"
        browserView?.evaluateJavaScript(js, completionHandler: nil)
        
        joinButton?.enabled = false
        callButton?.enabled = true
    }
    
    @IBAction func callButtonTapped(sender:UIButton?) {
        callButton?.enabled = false
        hangupButton?.enabled = true
    }
    
    @IBAction func hangupButtonTapped(sender:UIButton?) {
        abort()
    }
    
    @IBAction func sliderValueChanged(sender:UISlider?) {
        let sliderValue = sender?.value
        roomLabel?.text = "\(sliderValue!)"
    }

    override func didReceiveMemoryWarning() {
        println("WARNING! didReceiveMemoryWarning")
        super.didReceiveMemoryWarning()
    }


}

