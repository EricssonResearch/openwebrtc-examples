//
//  OpenWebRTCWebView.swift
//  SimpleDemoSwift
//
//  Created by Joseph Ross on 12/12/14.
//  Copyright (c) 2014 Savant Systems LLC. All rights reserved.
//

import UIKit
import WebKit

protocol OpenWebRTCWebViewDelegate : NSObjectProtocol {
    func webviewProgress(progress:Float)
    func newOwrMessage(message:String?)
    func newVideoRect(rect:CGRect, forSelfView rectIsSelfView:Bool)
}

class OpenWebRTCWebView : WKWebView {
    var resourceCount:Int = 0
    var resourceCompletedCount:Int = 0
    
    weak var owrDelegate:OpenWebRTCWebViewDelegate?
    var webGLEnabled:Bool = false
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame:frame, configuration:configuration)
    }
}
