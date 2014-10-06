if (window.mozRTCPeerConnection) {
    window.webkitURL = window.URL;
    navigator.webkitGetUserMedia = navigator.mozGetUserMedia;
    window.webkitRTCPeerConnection = window.mozRTCPeerConnection;
    window.RTCSessionDescription = window.mozRTCSessionDescription;
    window.RTCIceCandidate = window.mozRTCIceCandidate;
}

var remoteView;
var callButton;

var signalingChannel;
var pc;
var peer;
var localStream;

// must use 'url' here since Firefox doesn't understand 'urls'
var configuration = { "iceServers": [{ "url": "stun:132.177.123.6" }] };

window.onload = function () {
    remoteView = document.getElementById("remote_view");
    callButton = document.getElementById("call_but");
    var selfView = document.getElementById("self_view");
    var joinButton = document.getElementById("join_but");
    var audioCheckBox = document.getElementById("audio_cb");
    var videoCheckBox = document.getElementById("video_cb");

    joinButton.disabled = !navigator.webkitGetUserMedia;
    joinButton.onclick = function (evt) {
        audioCheckBox.disabled = videoCheckBox.disabled = true;
        // get a local stream
        navigator.webkitGetUserMedia({ "audio": audioCheckBox.checked,
            "video": videoCheckBox.checked }, function (stream) {
            // .. show it in a self-view
            selfView.src = URL.createObjectURL(stream);
            // .. and keep it to be sent later
            localStream = stream;

            joinButton.disabled = true;
            selfView.style.visibility = "visible";

            var sessionId = document.getElementById("session_txt").value;
            signalingChannel = new SignalingChannel(sessionId);

            callButton.onclick = function () {
                start(true);
            };

            // another peer has joined our session
            signalingChannel.onpeer = function (evt) {
                callButton.disabled = false;

                peer = evt.peer;
                peer.onmessage = handleMessage;

                peer.ondisconnect = function () {
                    callButton.disabled = true;
                    remoteView.style.visibility = "visible";
                    if (pc)
                        pc.close();
                    pc = null;
                };
            };
        }, logError);
    };
}

// handle signaling messages received from the other peer
function handleMessage(evt) {
    if (!pc)
        start(false);

    var message = JSON.parse(evt.data);
    if (message.sdp) {
        var desc = new RTCSessionDescription(message.sdp);
        pc.setRemoteDescription(desc, function () {
            // if we received an offer, we need to create an answer
            if (pc.remoteDescription.type == "offer")
                pc.createAnswer(localDescCreated, logError);
        }, logError);
    } else
        pc.addIceCandidate(new RTCIceCandidate(message.candidate), function () {}, logError);
}

// call start() to initiate
function start(isInitiator) {
    callButton.disabled = true;
    pc = new webkitRTCPeerConnection(configuration);

    // send any ice candidates to the other peer
    pc.onicecandidate = function (evt) {
        if (evt.candidate)
            peer.send(JSON.stringify({ "candidate": evt.candidate }));
    };

    // let the "negotiationneeded" event trigger offer generation
    pc.onnegotiationneeded = function () {
        // check signaling state here because Chrome dispatches negotiationeeded during negotiation
        if (pc.signalingState == "stable")
            pc.createOffer(localDescCreated, logError);
    };

    // once the remote stream arrives, show it in the remote video element
    pc.onaddstream = function (evt) {
        remoteView.src = URL.createObjectURL(evt.stream);
        remoteView.style.visibility = "visible";
    };

    pc.addStream(localStream);

    // the negotiationneeded event is not supported in Firefox
    if (window.mozRTCPeerConnection && isInitiator)
        pc.onnegotiationneeded();
}

function localDescCreated(desc) {
    pc.setLocalDescription(desc, function () {
        peer.send(JSON.stringify({ "sdp": pc.localDescription }));
    }, logError);
}

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
