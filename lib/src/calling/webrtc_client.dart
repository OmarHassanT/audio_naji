// import 'package:flutter/cupertino.dart';
// import 'package:flutter_webrtc/rtc_video_view.dart';//import 'package:flutter_webrtc/web/rtc_video_view.dart'; this for web
// import 'package:videoAppFluuter/src/calling/signaling.dart';
import 'package:flutter/material.dart';
import 'dart:core';
import 'signaling.dart';
import 'package:flutter_webrtc/webrtc.dart';

class WebRtcClient {

  WebRtcClient(this.channelId, {@required this.selfId ,@required  this.peerId}) {
    _initRenderers();
  }

  Signaling _signaling;
  String channelId;
  String selfId;
  String peerId;

  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  String media = "audio";

  join() {
   
    _connect();
  }
   _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

  }

  void _connect() async {
    if (_signaling == null) {
     _signaling= Signaling(selfId, channelId)..connect();

      _signaling.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
      });

      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
      });

      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }


  invitPeer() {
    _invitePeer(peerId, media);
  }

  leave() {
    _hangUp();
  }

  toggleMic(bool mute) {
    _muteMic(!mute);
  }

  toggleSpeaker(bool mute) {
    _muteSpeaker(!mute);
  }

  
 
  _invitePeer(peerId, media) async {
    if (_signaling != null && peerId != selfId && peerId != null) {
      _signaling.invite(peerId, media);
    }
  }

   _hangUp() {
    if (_signaling != null) {
      _signaling.close();

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      
    }

    _signaling.bye(peerId);
  }

  _muteMic(mute) {
    _signaling.microphoneMute(mute);
  }

  _muteSpeaker(bool mute) {
    mute ? _signaling.speakerMute(0) : _signaling.speakerMute(1);
  }
 

}
