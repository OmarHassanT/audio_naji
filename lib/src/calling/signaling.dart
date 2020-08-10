import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:hasura_connect/hasura_connect.dart';

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

  JsonEncoder _encoder = new JsonEncoder();
  JsonDecoder _decoder = new JsonDecoder();
  String _selfId;

  // SimpleWebSocket _socket;
  var _sessionId="123";
  var _host;
  var _port = 8086;
  var _peerConnections = new Map<String, RTCPeerConnection>();
  var _dataChannels = new Map<String, RTCDataChannel>();
  var _remoteCandidates = [];
  var _turnCredential;
  bool offerPassed=false;
  List<int> ids = [];
  
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
  // final Map<String, dynamic> _video_constraints = {
  //   'mandatory': {
  //     'OfferToReceiveAudio': true,
  //     'OfferToReceiveVideo': true,
  //   },
  //   'optional': [],
  // };

  // final Map<String, dynamic> _dc_constraints = {
  //   'mandatory': {
  //     'OfferToReceiveAudio': false,
  //     'OfferToReceiveVideo': false,
  //   },
  //   'optional': [],
  // };



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
      // if (media == 'data') {
      //   _createDataChannel(peer_id, pc);
      // }
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

  // accept2(id, String media) async {
  //   var pc = await _createPeerConnection(id, media);
  //   _peerConnections[id] = pc;
  //   await pc.setRemoteDescription(
  //       new RTCSessionDescription(description['sdp'], description['type']));

  //   await _createAnswer(id, pc, media);
  //   if (this._remoteCandidates.length > 0) {
  //     _remoteCandidates.forEach((candidate) async {
  //       await pc.addCandidate(candidate);
  //     });
  //     _remoteCandidates.clear();
  //   }
  // }

//   String updataQuerySetValidFalse = r"""
//       mutation MyMutation2($sessionId:String!) {
//   update_call_signaling(_set: {valid: false}, where: {session_id: {_eq:$sessionId}}) {
//     affected_rows
//   }
// }
//       """;
  // accept(String media) {
  //   _createPeerConnection(id, media).then((pc) {
  //     _peerConnections[id] = pc;
  //     pc.setRemoteDescription(
  //         new RTCSessionDescription(description['sdp'], description['type']));
  //     _createAnswer(id, pc, media);
  //     if (this._remoteCandidates.length > 0) {
  //       _remoteCandidates.forEach((candidate) async {
  //         await pc.addCandidate(candidate);
  //       });
  //       _remoteCandidates.clear();
  //     }
  //   });
  //   if (this.onStateChange != null) {
  //     this.onStateChange(SignalingState.CallStateRinging);
  //   }
  // }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];

    switch (mapData['type']) {
      // case 'peers':
      //   {
      //     List<dynamic> peers = data;
      //     if (this.onPeersUpdate != null) {
      //       Map<String, dynamic> event = new Map<String, dynamic>();
      //       event['self'] = _selfId;
      //       event['peers'] = peers;
      //       this.onPeersUpdate(event);
      //     }
      //   }
      //   break;
      case 'offer':
        {
          var id = data['from'];
         var description = data['description'];
          var media = data['media'];
           var sessionId = data['session_id'];
           this._sessionId = sessionId;

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
          this._sessionId = null;
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

          this._sessionId = null;
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
    // var url = 'https://$_host:$_port/ws';
    //  _socket = SimpleWebSocket(url);

    // print('connect to $url');

    if (_turnCredential == null) {
      try {
        // _turnCredential = await getTurnCredential(_host, _port);
        /*{
            "username": "1584195784:mbzrxpgjys",
            "password": "isyl6FF6nqMTB9/ig5MrMRUXqZg",
            "ttl": 86400,
            "uris": ["turn:127.0.0.1:19302?transport=udp"]
          }
        */
        //////////////////////////////////////////////////////////////////////////

        _iceServers = {
          'iceServers': [
            {
              'url': 'turn:numb.viagenie.ca',
              'credential': 'muazkh',
              'username': 'webrtc@live.com'
            },
          ]
        };

        //  _iceServers = {
        //   'iceServers': [
        //     {
        //       'url': _turnCredential['uris'][0],
        //       'username': _turnCredential['username'],
        //       'credential': _turnCredential['password']
        //     },
        //   ]
        // };
      } catch (e) {}
    }

    // // this.onStateChange(SignalingState.ConnectionOpen);
    // _send('new', {
    //   'name': DeviceInfo.label,
    //   'id': _selfId,
    //   'user_agent': DeviceInfo.userAgent
    // });
    // _socket.onOpen = () {
    //   print('onOpen');
    //   this?.onStateChange(SignalingState.ConnectionOpen);
    //   _send('new', {
    //     'name': DeviceInfo.label,
    //     'id': _selfId,
    //     'user_agent': DeviceInfo.userAgent
    //   });
    // };

    // _socket.onMessage = (message) {
    //   print('Recivied data: ' + message);
    //   JsonDecoder decoder = new JsonDecoder();
    //   this.onMessage(decoder.convert(message));
    // };

    // _socket.onClose = (int code, String reason) {
    //   print('Closed by server [$code => $reason]!');
    //   if (this.onStateChange != null) {
    //     this.onStateChange(SignalingState.ConnectionClosed);
    //   }
    // };

    // await _socket.connect();
//     String docQuery = r"""
//     subscription MySubscription($cid: String!, $selfId: String!) {
//       call_signaling_beta(where: {channel_id: {_eq: $cid}, created_by: {_neq: $selfId}}) {
//         data
//       }
//     }
// """;

//     Snapshot snapshot =hasuraConnect.subscription(docQuery, variables: {"selfId": _selfId , "cid":"123"});
//     snapshot.listen((data)  {
//       print("recived data:");
//       List<dynamic> dataa = data["data"]["call_signaling_beta"];
//       dataa.forEach((element){
//         print(element["data"]);
//         this.onMessage(element["data"]);
//          }
//       );
//     }).onError((err) {
//       print(err);
//     });
String docQuery = r"""
subscription MySubscription($_selfId: String!) {
  call(where: {User_id: {_eq: $_selfId}}) {
    data
  }
}

""";s

Snapshot snapshot = hasuraConnect.subscription(docQuery,variables:{"_selfId": _selfId});
  snapshot.listen((data) {
    print("recived data:");

    List<dynamic> dataa = data["data"]["call"];
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
//  final Map<String, dynamic> mediaConstraintsVideo = {
//       'audio': true,
//       'video': {
//         'mandatory': {
//           'minWidth':
//               '640', // Provide your own width, height and frame rate here
//           'minHeight': '480',
//           'minFrameRate': '30',
//         },
//         'facingMode': 'user',
//         'optional': [],
//       }
//     };
// var mediaConstraints= media=='audio'?mediaConstraintsAudio:mediaConstraintsVideo;
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

    // pc.onDataChannel = (channel) {
    //   _addDataChannel(id, channel);
    // };

    return pc;
  }

  // _addDataChannel(id, RTCDataChannel channel) {
  //   channel.onDataChannelState = (e) {};
  //   channel.onMessage = (RTCDataChannelMessage data) {
  //     if (this.onDataChannelMessage != null)
  //       this.onDataChannelMessage(channel, data);
  //   };
  //   _dataChannels[id] = channel;

  //   if (this.onDataChannel != null) this.onDataChannel(channel);
  // }

  // _createDataChannel(id, RTCPeerConnection pc, {label: 'fileTransfer'}) async {
  //   RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
  //   RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
  //   _addDataChannel(id, channel);
  // }

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
    var cby = data["from"];
var reciverID=data["to"];
//     String docQuery = r"""
// mutation MyMutation($cby:String!,$request:jsonb!,$cid:String!) {
//   insert_call_signaling_beta(objects: {created_by: $cby, data:$request,channel_id:$cid }) {
//     affected_rows
//   }
// }
// """;

//     var r = await hasuraConnect.mutation(docQuery, variables: {
//       "cby": cby,
//       "request": request,
//       "cid": data["session_id"]
//     });
//     print("send data:");
//     print(r);
    //  _socket.send(_encoder.convert(request));

     String docQuery = r"""

mutation MyMutation($reciverID:String!,$request:jsonb!) {
  insert_call(objects: {User_id: $reciverID, data:$request }) {
    affected_rows
  }
}

""";
     var r=   await  hasuraConnect.mutation(docQuery,variables:{
       "reciverID":reciverID,
       "request":request
     } );
     print("send data:");
    print(r);
  }
}
