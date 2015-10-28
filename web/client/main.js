var isMozilla = window.mozRTCPeerConnection && !window.webkitRTCPeerConnection;
if (isMozilla) {
    window.webkitURL = window.URL;
    navigator.webkitGetUserMedia = navigator.mozGetUserMedia;
    window.webkitRTCPeerConnection = window.mozRTCPeerConnection;
    window.RTCSessionDescription = window.mozRTCSessionDescription;
    window.RTCIceCandidate = window.mozRTCIceCandidate;
}

var selfView;
var remoteView;
var callButton;
var audioCheckBox;
var videoCheckBox;
var audioOnlyView;
var signalingChannel;
var pc;
var peer;
var localStream;
var chatDiv;
var chatText;
var chatButton;
var chatCheckBox;
var channel;

if (!window.SDP) {
    console.error("+-------------------------WARNING-------------------------+");
    console.error("| sdp.js not found, will not transform signaling messages |");
    console.error("+---------------------------------------------------------+");
    window.SDP = { "parse": function () {}, "generate": function () {} };
}

if (!window.hasOwnProperty("orientation"))
    window.orientation = -90;

// must use 'url' here since Firefox doesn't understand 'urls'
var configuration = {
  "iceServers": [
  {
    "url": "stun:mmt-stun.verkstad.net"
  },
  {
    "url": "turn:mmt-turn.verkstad.net",
    "username": "webrtc",
    "credential": "secret"
  }
  ]
};
window.onload = function () {
    selfView = document.getElementById("self_view");
    remoteView = document.getElementById("remote_view");
    callButton = document.getElementById("call_but");
    var joinButton = document.getElementById("join_but");
    audioCheckBox = document.getElementById("audio_cb");
    videoCheckBox = document.getElementById("video_cb");
    audioOnlyView = document.getElementById("audio-only-container");
    var shareView = document.getElementById("share-container");
    chatText = document.getElementById("chat_txt");
    chatButton = document.getElementById("chat_but");
    chatDiv = document.getElementById("chat_div");
    chatCheckBox = document.getElementById("chat_cb");

    // if browser doesn't support DataChannels the chat will be disabled.
    if (webkitRTCPeerConnection.prototype.createDataChannel === undefined) {
        chatCheckBox.checked = false;
        chatCheckBox.disabled = true;
    }

    // Store media preferences
    audioCheckBox.onclick = videoCheckBox.onclick = chatCheckBox.onclick = function(evt) {
        localStorage.setItem(this.id, this.checked);
    };

    audioCheckBox.checked = localStorage.getItem("audio_cb") == "true";
    videoCheckBox.checked = localStorage.getItem("video_cb") == "true";

    if (webkitRTCPeerConnection.prototype.createDataChannel !== undefined)
        chatCheckBox.checked = localStorage.getItem("chat_cb") == "true";

    // Check video box if no preferences exist
    if (!localStorage.getItem("video_cb"))
        videoCheckBox.checked = true;

    joinButton.disabled = !navigator.webkitGetUserMedia;
    joinButton.onclick = function (evt) {
        if (!(audioCheckBox.checked || videoCheckBox.checked || chatCheckBox.checked)) {
            alert("Choose at least audio, video or chat.");
            return;
        }

        audioCheckBox.disabled = videoCheckBox.disabled = chatCheckBox.disabled = joinButton.disabled = true;

        // only chat
        if (!(videoCheckBox.checked || audioCheckBox.checked)) peerJoin();

        function peerJoin() {
            var sessionId = document.getElementById("session_txt").value;
            signalingChannel = new SignalingChannel(sessionId);

            // show and update share link
            var link = document.getElementById("share_link");
            var maybeAddHash = window.location.href.indexOf('#') !== -1 ? "" : ("#" + sessionId);
            link.href = link.textContent = window.location.href + maybeAddHash;
            shareView.style.visibility = "visible";

            callButton.onclick = function () {
                start(true);
            };

            // another peer has joined our session
            signalingChannel.onpeer = function (evt) {

                callButton.disabled = false;
                shareView.style.visibility = "hidden";

                peer = evt.peer;
                peer.onmessage = handleMessage;

                peer.ondisconnect = function () {
                    callButton.disabled = true;
                    remoteView.style.visibility = "hidden";
                    if (pc)
                        pc.close();
                    pc = null;
                };
            };
        }

        // video/audio with our without chat
        if (videoCheckBox.checked || audioCheckBox.checked) {
            // get a local stream
            navigator.webkitGetUserMedia({ "audio": audioCheckBox.checked,
                "video": videoCheckBox.checked}, function (stream) {
                // .. show it in a self-view
                selfView.src = URL.createObjectURL(stream);
                // .. and keep it to be sent later
                localStream = stream;

                joinButton.disabled = true;
                chatButton.disabled = true;

                if (videoCheckBox.checked)
                    selfView.style.visibility = "visible";
                else if (audioCheckBox.checked && !(chatCheckBox.checked))
                    audioOnlyView.style.visibility = "visible";

                peerJoin();
            }, logError);
        }
    };

    document.getElementById("owr-logo").onclick = function() {
        window.location.assign("http://www.openwebrtc.org");
    };

    var hash = location.hash.substr(1);
    if (hash) {
        document.getElementById("session_txt").value = hash;
        log("Auto-joining session: " + hash);
        joinButton.click();
    } else {
        // set a random session id
        document.getElementById("session_txt").value = Math.random().toString(16).substr(4);
    }
};

// handle signaling messages received from the other peer
function handleMessage(evt) {
    var message = JSON.parse(evt.data);

    if (!pc && (message.sessionDescription || message.sdp || message.candidate))
        start(false);

    if (message.sessionDescription || message.sdp) {
        var desc = new RTCSessionDescription({
            "sdp": SDP.generate(message.sessionDescription) || message.sdp,
            "type": message.type
        });
        pc.setRemoteDescription(desc, function () {
            // if we received an offer, we need to create an answer
            if (pc.remoteDescription.type == "offer")
                pc.createAnswer(localDescCreated, logError);
        }, logError);
    } else if (!isNaN(message.orientation) && remoteView) {
        var transform = "rotate(" + message.orientation + "deg)";
        remoteView.style.transform = remoteView.style.webkitTransform = transform;
    } else {
        var d = message.candidate.candidateDescription;
        if (d && !message.candidate.candidate) {
            message.candidate.candidate = "candidate:" + [
                d.foundation,
                d.componentId,
                d.transport,
                d.priority,
                d.address,
                d.port,
                "typ",
                d.type,
                d.relatedAddress && ("raddr " + d.relatedAddress),
                d.relatedPort && ("rport " + d.relatedPort),
                d.tcpType && ("tcptype " + d.tcpType)
            ].filter(function (x) { return x; }).join(" ");
        }
        pc.addIceCandidate(new RTCIceCandidate(message.candidate), function () {}, logError);
    }
}

// call start() to initiate
function start(isInitiator) {
    callButton.disabled = true;
    pc = new webkitRTCPeerConnection(configuration);

    // send any ice candidates to the other peer
    pc.onicecandidate = function (evt) {
        if (evt.candidate) {
            var candidate = "";
            var s = SDP.parse("m=application 0 NONE\r\na=" + evt.candidate.candidate + "\r\n");
            var candidateDescription = s && s.mediaDescriptions[0].ice.candidates[0];
            if (!candidateDescription)
                candidate = evt.candidate.candidate;
            peer.send(JSON.stringify({
                "candidate": {
                    "candidate": candidate,
                    "candidateDescription": candidateDescription,
                    "sdpMLineIndex": evt.candidate.sdpMLineIndex
                }
            }));
            console.log("candidate emitted: " + evt.candidate.candidate);
        }
    };

    // start the chat
    if (chatCheckBox.checked) {
        if (isInitiator) {
            channel = pc.createDataChannel("chat");
            setupChat();
        } else {
            pc.ondatachannel = function (evt) {
                channel = evt.channel;
                setupChat();
            };
        }
    }

    // once the remote stream arrives, show it in the remote video element
    pc.onaddstream = function (evt) {
        remoteView.src = URL.createObjectURL(evt.stream);
        if (videoCheckBox.checked)
            remoteView.style.visibility = "visible";
        else if (audioCheckBox.checked && !(chatCheckBox.checked))
            audioOnlyView.style.visibility = "visible";
        sendOrientationUpdate();
    };

    if (audioCheckBox.checked || videoCheckBox.checked) {
        pc.addStream(localStream);
    }

    if (isInitiator)
        pc.createOffer(localDescCreated, logError);

}

function localDescCreated(desc) {
    pc.setLocalDescription(desc, function () {
        var sdp = "";
        var sessionDescription = SDP.parse(pc.localDescription.sdp);
        if (!sessionDescription)
            sdp = pc.localDescription.sdp;
        peer.send(JSON.stringify({
            "sdp": sdp,
            "sessionDescription": sessionDescription,
            "type": pc.localDescription.type
        }));
        var logMessage = "localDescription set and sent to peer, type: " + pc.localDescription.type;
        if (sdp)
            logMessage += ", sdp:\n" + sdp;
        if (sessionDescription)
            logMessage += ", sessionDescription:\n" + JSON.stringify(sessionDescription, null, 2);
        console.log(logMessage);
    }, logError);
}

function sendOrientationUpdate() {
    peer.send(JSON.stringify({ "orientation": window.orientation + 90 }));
}

window.onorientationchange = function () {
    if (peer)
        sendOrientationUpdate();

    if (selfView) {
        var transform = "rotate(" + (window.orientation + 90) + "deg)";
        selfView.style.transform = selfView.style.webkitTransform = transform;
    }
};

function logError(error) {
    if (error) {
        if (error.name && error.message)
            log(error.name + ": " + error.message);
        else
            log(error);
    } else
        log("Error (no error message)");
}

function log(msg) {
    log.div = log.div || document.getElementById("log_div");
    log.div.appendChild(document.createTextNode(msg));
    log.div.appendChild(document.createElement("br"));
}

// setup chat
function setupChat() {
    channel.onopen = function () {
        chatDiv.style.visibility = "visible";
        chatText.style.visibility = "visible";
        chatButton.style.visibility = "visible";
        chatButton.disabled = false;

        //On enter press - send text message.
        chatText.onkeyup = function(event) {
            if (event.keyCode == 13) {
                chatButton.click();
            }
        };

        chatButton.onclick = function () {
            if(chatText.value) {
                postChatMessage(chatText.value, true);
                channel.send(chatText.value);
                chatText.value = "";
                chatText.placeholder = "";
            }
        };
    };

    // recieve data from remote user
    channel.onmessage = function (evt) {
        postChatMessage(evt.data);
    };

    function postChatMessage(msg, author) {
        var messageNode = document.createElement('div');
        var messageContent = document.createElement('div');
        messageNode.classList.add('chatMessage');
        messageContent.textContent = msg;
        messageNode.appendChild(messageContent);

        if (author) {
            messageNode.classList.add('selfMessage');
        } else {
            messageNode.classList.add('remoteMessage');
        }

        chatDiv.appendChild(messageNode);
        chatDiv.scrollTop = chatDiv.scrollHeight;
    }
}
