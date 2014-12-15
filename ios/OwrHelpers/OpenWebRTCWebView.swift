//
//  OpenWebRTCWebView.swift
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
