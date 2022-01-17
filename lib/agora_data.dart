import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:flutter/material.dart';
import 'enums.dart';

class CbAudioVolumeInfo {
  DateTime date;
  AudioVolumeInfo avi;
  CbAudioVolumeInfo(this.date, this.avi);
  bool get isRecent {
    final dur = DateTime.now().difference(date);
    return dur.inMilliseconds < 2000;
  }
}

class AgoraUser {
  final String personName;
  final MeetingRole role;
  final CbAudioVolumeInfo avi;
  final List<CbAudioVolumeInfo> aviHistory;
  final AudioStatus audioStatus;
  final VideoStatus videoStatus;
  AgoraUser(this.personName,
      this.role, this.avi, this.aviHistory, this.audioStatus, this.videoStatus);
}

class AudioStatus {
  final int uid;
  final AudioRemoteState state;
  final AudioRemoteStateReason reason;
  AudioStatus(this.uid, this.state, this.reason);
}

class VideoStatus {
  final int uid;
  final VideoRemoteState state;
  final VideoRemoteStateReason reason;
  VideoStatus(this.uid, this.state, this.reason);
}

class AudioPlayerInfo {
  final AudioMixingStateCode audioPlayerState;
  final int? durationMs;
  final int? currentPlaybackPositionMs;
  AudioPlayerInfo(this.audioPlayerState,
      {@required this.durationMs, @required this.currentPlaybackPositionMs});
  int get timeRemainingMs {
    return durationMs! - currentPlaybackPositionMs!;
  }

  int get timeRemainingSec {
    return durationSec - playbackPositonSec;
  }

  int get durationSec {
    return (durationMs! / 1000).truncate();
  }

  int get playbackPositonSec {
    return (currentPlaybackPositionMs! / 1000).truncate();
  }
}
