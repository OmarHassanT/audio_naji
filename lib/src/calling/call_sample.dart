import 'package:flutter/material.dart';
import 'package:videoAppFluuter/src/calling/webrtc_client.dart';
import 'dart:core';
import 'signaling.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'random_string.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';

  final String ip;

  CallSample({Key key, @required this.ip}) : super(key: key);

  @override
  _CallSampleState createState() => _CallSampleState();
}

class _CallSampleState extends State<CallSample> {
  String _selfId = "2";
  String _peerId = "1";
   String channelId="123";
  
  String media;
  bool _inCalling = false;
  bool isSpeaker = true;
  bool mute = false;
  WebRtcClient _webRtcClient;

  _CallSampleState({Key key});

  @override
  initState() {
    super.initState();
       _webRtcClient = WebRtcClient(channelId, peerId: _peerId, selfId: _selfId);
  }

  @override
  deactivate() {
    super.deactivate(); 
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Id:$channelId  ss $_selfId'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: null,
              tooltip: 'setup',
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _inCalling
            ? SizedBox(
                width: 200.0,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      FloatingActionButton(
                        onPressed:(){
                           _webRtcClient.leave();
                        },
                        tooltip: 'Hangup',
                        child: Icon(Icons.call_end),
                        backgroundColor: Colors.pink,
                      ),
                      FloatingActionButton(
                        child: Icon(mute ? Icons.mic_off : Icons.mic),
                        onPressed: () {
                           _webRtcClient.toggleMic(mute);
                          setState(() {
                            mute = !mute;
                          });
                         
                        },
                      ),
                      FloatingActionButton(
                        child: Icon(
                            isSpeaker ? Icons.volume_up : Icons.volume_down),
                        tooltip: 'Speaker',
                        onPressed: () {
                       _webRtcClient.toggleSpeaker(isSpeaker);
                          setState(() {
                            isSpeaker = !isSpeaker;
                          });
                        },
                      ),
                       
                    ]))
            : null,
        body: _inCalling
            ? Center(
                child: Text(
                  "Voice call running...",
                  style: TextStyle(color: Colors.green, fontSize: 40),
                  textAlign: TextAlign.center,
                ),
              )
            : Container(
                child: Center(
                  child: Column(
                    children: <Widget>[
                      TextField(
                        decoration: InputDecoration(
                            hintText: 'Enter Id of the reciver'),
                        onChanged: (channelId) {
                          setState(() {
                            this.channelId=channelId;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          // media = 'audio';
                          _webRtcClient.invitPeer();
                        },

                        tooltip: 'invite',
                      ),
                        SizedBox(height: 20,width: 20,),
                        IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                         
                          _webRtcClient.join();

                        },
                        tooltip: 'join ',
                      ),
                   
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      FloatingActionButton(
                        onPressed:(){
                           _webRtcClient.leave();
                        },
                        tooltip: 'Hangup',
                        child: Icon(Icons.call_end),
                        backgroundColor: Colors.pink,
                      ),
                      FloatingActionButton(
                        child: Icon(mute ? Icons.mic_off : Icons.mic),
                        onPressed: () {
                           _webRtcClient.toggleMic(mute);
                          setState(() {
                            mute = !mute;
                          });
                         
                        },
                      ),
                      FloatingActionButton(
                        child: Icon(
                            isSpeaker ? Icons.volume_up : Icons.volume_down),
                        tooltip: 'Speaker',
                        onPressed: () {
                       _webRtcClient.toggleSpeaker(isSpeaker);
                          setState(() {
                            isSpeaker = !isSpeaker;
                          });
                        },
                      ),
                       
                    ]) ],
                  ),
                ),
              ));
  }
}
