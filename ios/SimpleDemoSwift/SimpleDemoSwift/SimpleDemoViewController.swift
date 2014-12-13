//
//  ViewController.swift
//  SimpleDemoSwift
//
//  Created by Joseph Ross on 12/12/14.
//  Copyright (c) 2014 Savant Systems LLC. All rights reserved.
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
        
        loadRequestWithUrl("http://demo.openwebrtc.io")
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

