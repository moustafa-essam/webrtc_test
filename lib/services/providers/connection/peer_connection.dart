import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/blocs/models/attendee.dart';
import 'package:webrtc_test/blocs/models/connection.dart';
import 'package:webrtc_test/blocs/models/rtc_candidate.dart';
import 'package:webrtc_test/helpers/utils/list_diff_notifier.dart';
import 'package:webrtc_test/helpers/utils/map_diff_notifier.dart';

class EstablishedPeerConnection {
  final RTCPeerConnection connection;
  final ListDiffNotifier<RtcIceCandidateModel> localCandidates;
  MediaStream? _localStream;
  final MapDiffNotifier<String, MediaStream> remoteStreams =
      MapDiffNotifier((streams) {
    for (final stream in streams.values) {
      stream.getTracks().forEach((track) {
        track.stop();
      });
      stream.dispose();
    }
  });

  EstablishedPeerConnection._(this.connection, this.localCandidates) {
    _registerCallbacks();
  }

  static Future<EstablishedPeerConnection> establish(
      Map<String, dynamic> configuration,
      [MediaStream? localStream]) async {
    final connection = await createPeerConnection(configuration);
    final established =
        EstablishedPeerConnection._(connection, ListDiffNotifier());
    established.localStream = localStream;
    return established;
  }

  set localStream(MediaStream? localStream) {
    if (localStream?.id != _localStream?.id) {
      if (localStream != null) {
        _registerStreamCallbacks(localStream);
      }
      if (_localStream != null) {
        _unregisterStreamCallbacks(_localStream!);
      }
    }
    _localStream = localStream;
  }

  void dispose() {
    localCandidates.dispose();
    if (_localStream != null) {
      _unregisterStreamCallbacks(_localStream!);
    }
    remoteStreams.dispose();
    connection.close();
  }

  void _registerCallbacks() {
    connection.onIceCandidate = (candidate) {
      log('Got candidate: ${candidate.toMap()}');
      localCandidates.addItem(RtcIceCandidateModel.fromCandidate(candidate));
    };
  }

  void _registerStreamCallbacks(MediaStream localStream) {
    localStream.getTracks().forEach((track) {
      connection.addTrack(track, localStream);
    });
    connection.onAddTrack = (stream, track) {
      log("Add remote stream track");
      remoteStreams[stream.id] ??= stream;
      remoteStreams[stream.id]?.addTrack(track);
    };
    connection.onRemoveTrack = (stream, track) {
      log("Remove remote stream track");
      remoteStreams[stream.id] ??= stream;
      remoteStreams[stream.id]?.removeTrack(track);
    };
    connection.onAddStream = (stream) {
      log("Add remote stream");
      remoteStreams[stream.id] = stream;
    };
    connection.onRemoveStream = (stream) {
      log("Remove remote stream");
      remoteStreams.removeItem(stream.id);
    };
  }

  void _unregisterStreamCallbacks(MediaStream localStream) {
    connection.removeStream(localStream);
  }

  Future<RTCSessionDescription> createOffer() {
    return connection.createOffer();
  }

  Future<RTCSessionDescription> createAnswer() {
    return connection.createAnswer();
  }

  Future<void> setLocalDescription(RTCSessionDescription offer) {
    return connection.setLocalDescription(offer);
  }
}

class PeerConnection extends ChangeNotifier {
  final EstablishedPeerConnection _connection;
  final String id;
  final Attendee remote;
  final ListDiffNotifier<RtcIceCandidateModel> _remoteCandidates;

  ListDiffNotifier<RtcIceCandidateModel> get localCandidates =>
      _connection.localCandidates;
  MapDiffNotifier<String, MediaStream> get remoteStreams =>
      _connection.remoteStreams;
  Connection _conData;
  Connection get conData => _conData;
  void setConData(Connection conData) {
    _conData = conData;
  }

  bool _localSat = false;
  bool get localSat => _localSat;
  bool _remoteSat = false;
  bool get remoteSat => _remoteSat;
  RTCPeerConnection get connection => _connection.connection;

  PeerConnection._(
    this.id,
    this._connection,
    this.remote,
    this._remoteCandidates,
    this._conData,
  ) {
    _registerCallbacks();
  }

  set localStream(MediaStream? localStream) {
    _connection.localStream = localStream;
  }

  static Future<PeerConnection> createConnection(
    String id,
    Attendee remote,
    ListDiffNotifier<RtcIceCandidateModel> remoteCandidates,
    EstablishedPeerConnection connection,
    Connection conData,
  ) async {
    final _connection = PeerConnection._(
      id,
      connection,
      remote,
      remoteCandidates,
      conData,
    );
    return _connection;
  }

  Future<RTCSessionDescription> setOffer(
      {RTCSessionDescription? offer, bool remote = false}) async {
    offer ??= await connection.createOffer();
    if (remote) {
      _remoteSat = true;
      connection.setRemoteDescription(offer);
    } else {
      _localSat = true;
      connection.setLocalDescription(offer);
    }
    return offer;
  }

  Future<RTCSessionDescription> setAnswer(
      {RTCSessionDescription? answer, bool remote = false}) async {
    answer ??= await connection.createAnswer();
    if (remote) {
      _remoteSat = true;
      connection.setRemoteDescription(answer);
    } else {
      _localSat = true;
      connection.setLocalDescription(answer);
    }
    return answer;
  }

  @override
  void dispose() {
    super.dispose();
    _remoteCandidates.dispose();
  }

  void _registerCallbacks() {
    _remoteCandidates.addDiffListener(onAdded: (candidate) {
      connection.addCandidate(candidate.iceCandidate);
    });
    // connection.onTrack = (event) {
    //   remoteStreams.clear(event.streams.isEmpty);
    //   for (var stream in event.streams) {
    //     remoteStreams[stream.id] = stream;
    //   }
    // };
  }
}
