import 'package:hasura_connect/hasura_connect.dart';
import 'dart:async';
import 'package:flutter_webrtc/webrtc.dart';



enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel dc);

class Signaling {

  Signaling(this._selfId, this._sessionId);

 
  String _selfId;
  final _sessionId;
  bool offerPassed=false;
  List<int> ids = [];
  
  var _peerConnections = new Map<String, RTCPeerConnection>();
  var _dataChannels = new Map<String, RTCDataChannel>();
  var _remoteCandidates = [];
  var _turnCredential;

  MediaStream _localStream;
  List<MediaStream> _remoteStreams;
  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;
  DataChannelMessageCallback onDataChannelMessage;
  DataChannelCallback onDataChannel;

  static String url = 'http://35.224.121.33:5021/v1/graphql';
  HasuraConnect hasuraConnect = HasuraConnect(url);

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
       */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };
  //omar
  final Map<String, dynamic> _audio_constraint = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };



  close() {
    if (_localStream != null) {
      _localStream.dispose();
      _localStream = null;
    }

    _peerConnections.forEach((key, pc) {
      pc.close();
    });
    
    //  if (_socket != null) _socket.close();
  }

  void switchCamera() {
    if (_localStream != null) {
      _localStream.getVideoTracks()[0].switchCamera();
    }
  }

  //////
  void microphoneMute(bool mute) {
    if (_localStream != null) {
      _localStream.getAudioTracks()[0].setMicrophoneMute(mute);
    }
  }
    void speakerMute(double v) {
    if (_localStream != null) {
      _localStream.getAudioTracks()[0].enabled = (v!=0);
    }
  }

  void speakerPhone(bool enable) {
    if (_localStream != null)
      _localStream.getAudioTracks()[0].enableSpeakerphone(enable);
  }

///////
  void invite(String peer_id, String media) {
    // this._sessionId = _channelId;

    if (this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateRinging);
    }

    _createPeerConnection(peer_id, media).then((pc) {
      _peerConnections[peer_id] = pc;
      _createOffer(peer_id, pc, media);
    });
  }

  void bye(id) {
    _send('bye', {
      'session_id': this._sessionId,
      'from': this._selfId,
      'to': id,
    });
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];

    switch (mapData['type']) {
    
      case 'offer':
        {
          var id = data['from'];
         var description = data['description'];
          var media = data['media'];
           

          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }
                _createPeerConnection(id, media).then((pc) {
            _peerConnections[id] = pc;
            pc.setRemoteDescription(
                new RTCSessionDescription(description['sdp'], description['type']));
            _createAnswer(id, pc, media);
            if (this._remoteCandidates.length > 0) {
              _remoteCandidates.forEach((candidate) async {
                await pc.addCandidate(candidate);
              });
              _remoteCandidates.clear();
            }
          });
        }
        break;
      case 'answer':
        {
          var id = data['from'];
          var description = data['description'];

          var pc = _peerConnections[id];
          if (pc != null) {
            await pc.setRemoteDescription(new RTCSessionDescription(
                description['sdp'], description['type']));
          }
        }
        break;
      case 'candidate':
        {
          var id = data['from'];
          var candidateMap = data['candidate'];
          var pc = _peerConnections[id];
          RTCIceCandidate candidate = new RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex']);
          if (pc != null) {
            await pc.addCandidate(candidate);
          } else {
            _remoteCandidates.add(candidate);
          }
        }
        break;
      case 'leave':
        {
          var id = data;
          var pc = _peerConnections.remove(id);
          _dataChannels.remove(id);

          if (_localStream != null) {
            _localStream.dispose();
            _localStream = null;
          }

          if (pc != null) {
            pc.close();
          }
          // this._sessionId = null;
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;
      case 'bye':
        {
          var to = data['to'];
          var sessionId = data['session_id'];
          print('bye: ' + sessionId);

          if (_localStream != null) {
            _localStream.dispose();
            _localStream = null;
          }

          var pc = _peerConnections[to];
          if (pc != null) {
            pc.close();
            _peerConnections.remove(to);
          }

          var dc = _dataChannels[to];
          if (dc != null) {
            dc.close();
            _dataChannels.remove(to);
          }

          
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

  void connect() async {
   
    if (_turnCredential == null) {
      try {
      
        _iceServers = {
          'iceServers': [
            {
              'url': 'turn:numb.viagenie.ca',
              'credential': 'muazkh',
              'username': 'webrtc@live.com'
            },
          ]
        };

      } catch (e) {}
    }

   
String docQuery = r"""
subscription MySubscription($selfId:String!,$channelId:String!) {
  call_signaling_beta(where: {channel_id: {_eq: $channelId}, created_by: {_neq: $selfId}}) {
    data
  }
}

""";

Snapshot snapshot = hasuraConnect.subscription(docQuery,variables:{
  "selfId": _selfId,
  "channelId":_sessionId
});
  snapshot.listen((data) {
    print("recived data:");
snapshot.cleanCache();

    List<dynamic> dataa = data["data"]["call_signaling_beta"];
    dataa.forEach((element) {
       print(element["data"]);
      if(element["data"]["type"]=="offer" &&!offerPassed){
            this.onMessage(element["data"]);
            offerPassed=true;
      }
        else{
          if(element["data"]["type"]!="offer")  
             this.onMessage(element["data"]);
          if(element["data"]["type"]=="bye")
             offerPassed=false;
        } 

    });
  }).onError((err) {
    print(err);
  });
    
  }

  Future<MediaStream> createStream(media) async {
    final Map<String, dynamic> mediaConstraintsAudio = {
      'audio': true,
      'video': false
    };
    MediaStream stream = await navigator.getUserMedia(mediaConstraintsAudio);
    if (this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    return stream;
  }

  _createPeerConnection(id, media) async {
    _localStream = await createStream(media);
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
    if (media != 'data') pc.addStream(_localStream);
    pc.onIceCandidate = (candidate) {
      _send('candidate', {
        'to': id,
        'from': _selfId,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMlineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'session_id': this._sessionId,
      });
    };

    pc.onIceConnectionState = (state) {};

    pc.onAddStream = (stream) {
      if (this.onAddRemoteStream != null) this.onAddRemoteStream(stream);
      // _remoteStreams.add(stream);
    };

    pc.onRemoveStream = (stream) {
      if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream(stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    return pc;
  }

  _createOffer(String id, RTCPeerConnection pc, String media) async {
    try {
      RTCSessionDescription s = await pc.createOffer(_audio_constraint);
      pc.setLocalDescription(s);
      _send('offer', {
        'to': id,
        'from': _selfId,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
        'media': media,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _createAnswer(String id, RTCPeerConnection pc, media) async {
    try {
      RTCSessionDescription s = await pc.createAnswer(_audio_constraint);
      pc.setLocalDescription(s);
      _send('answer', {
        'to': id,
        'from': _selfId,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
        'media': media,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event, data) async {
    Map<String, dynamic> request = new Map();
    request["type"] = event;
    request["data"] = data;
    var selfId = data["from"];

String newQuerey=r"""
mutation MyMutation($selfId: String!, $channelId: String!,$data:jsonb) {
  insert_call_signaling_beta(objects: {created_by: $selfId, channel_id: $channelId, data: $data}) {
    affected_rows
  }
}
""";
     var r=   await  hasuraConnect.mutation(newQuerey,variables:{
       "selfId":selfId,
       "data":request,
       "channelId":data["session_id"]

     } );
     print("send data:");
    print(r);
  }
}
