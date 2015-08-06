## Starting the server
The server uses [node.js](http://nodejs.org) and is started using:
```
node channel_server.js
```
The default port is 8080. The port to use can be changed by setting the environment variable PORT or giving the port as an argument to the node command. If both the environment variable and the argument are given then the argument is used.

Example of how to set port using environment variable and command line argument.
```
PORT=9080 node channel_server.js
node channel_server.js 10080
```

## Local testing
The simple WebRTC app is now running at [http://localhost:8080/](http://localhost:8080/)

![Demo app](https://github.com/EricssonResearch/openwebrtc-browser-extensions/blob/master/imgs/demoapp.png)

## Live testing
We are keeping an up-to-date version of this app available at [http://demo.openwebrtc.org](http://demo.openwebrtc.org)
