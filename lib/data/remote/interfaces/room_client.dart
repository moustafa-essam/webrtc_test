import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/blocs/models/attendee.dart';
import 'package:webrtc_test/blocs/models/available_room.dart';
import 'package:webrtc_test/blocs/models/room.dart';
import 'package:webrtc_test/blocs/models/rtc_candidate.dart';
import 'package:webrtc_test/blocs/models/user.dart';
import 'package:webrtc_test/helpers/utils/tuple.dart';

abstract class IRoomClient {
  Future<Tuple2<Room, Attendee>> createRoom(
    String roomName,
    UserAccount user,
  );

  Future<Tuple2<Room, Attendee>> joinRoom(
    AvailableRoom room,
    UserAccount user,
    RTCSessionDescription offer,
  );

  Future<List<AvailableRoom>> getAvailableRooms();

  Future<void> addCandidate(Attendee attendee, RtcIceCandidateModel candidate);

  Future<void> exitRoom(Attendee attendee);

  Future<void> closeRoom(Room room);
}
