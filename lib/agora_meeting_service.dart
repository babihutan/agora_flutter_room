import 'dart:async';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';;
import 'agora_data.dart';
import 'config.dart';
import 'enums.dart';

class AgoraMeetingService {
  final String meetingId;
  final MeetingMedia meetingMedia;
  MeetingMemberData _initializingMeetingMember;
  int _myAgoraUid;
  String _myAgoraToken;
  bool _isAgoraInitialized = false;
  RtcEngine _engine;
  //final List<String> _agoraMessages = [];
  Timer _timer;
  bool _isProcessingAvi = false;

  AgoraMeetingService(this.meetingId, this.meetingMedia) {
    print('''[ags] ctor, hashCode=>${this.hashCode}, media=$meetingMedia, 
        hashCode=${this.hashCode}''');
    ls.log(
        'AgoraMeetingService ctor, meetingId=$meetingId, media=$meetingMedia');
    _handlePermissions();
  }

  final _audioPlayerInfoSubject = BehaviorSubject<AudioPlayerInfo>();
  Stream<AudioPlayerInfo> get audioPlayerInfo => _audioPlayerInfoSubject.stream;

  final _audioPlayerStateSubject = BehaviorSubject<AudioMixingStateCode>();
  Stream<AudioMixingStateCode> get audioPlayerState =>
      _audioPlayerStateSubject.stream;

  final _agoraRemoteUserIdsSubject = BehaviorSubject<List<int>>();
  Stream<List<int>> get agoraRemoteUserIds => _agoraRemoteUserIdsSubject.stream;

  final _isSpeakphoneEnabledSubject = BehaviorSubject<bool>();
  Stream<bool> get isSpeakerphoneEnabled => _isSpeakphoneEnabledSubject.stream;

  final _activeSpeakerUidSubject = BehaviorSubject<int>();
  Stream<int> get activeSpeakerUid => _activeSpeakerUidSubject.stream;

  final _audioVolumeInfoMapSubject =
      BehaviorSubject<Map<int, List<CbAudioVolumeInfo>>>();
  Stream<Map<int, List<CbAudioVolumeInfo>>> get audioVolumeInfoMap =>
      _audioVolumeInfoMapSubject.stream;

  final _audioStatusMapSubject = BehaviorSubject<Map<int, AudioStatus>>();
  Stream<Map<int, AudioStatus>> get audioStatusMap =>
      _audioStatusMapSubject.stream;

  final _videoStatusMapSubject = BehaviorSubject<Map<int, VideoStatus>>();
  Stream<Map<int, VideoStatus>> get videoStatusMap =>
      _videoStatusMapSubject.stream;

  //List<String> get agoraMessages => _agoraMessages;

  Future<void> _initAgoraRtcEngine() async {
    final config = RtcEngineContext(
      AGORA_APP_ID,
      logConfig: LogConfig(level: LogLevel.Warn),
    );
    _engine = await RtcEngine.createWithContext(config);
    if (meetingMedia == MeetingMedia.video) {
      await _engine.enableVideo();
      await _engine.enableAudio();
    } else if (meetingMedia == MeetingMedia.audio) {
      await _engine.enableAudio();
    }
    await _engine.setChannelProfile(ChannelProfile.Communication);
    //removed on 8/18/2021
    //await _engine.setClientRole(ClientRole.Broadcaster);
  }

  void _handlePermissions() async {
    await _handleCameraAndMic(Permission.microphone);
    if (meetingMedia == MeetingMedia.video) {
      await _handleCameraAndMic(Permission.camera);
    }
  }

  Future<void> _handleCameraAndMic(Permission permission) async {
    final status = await permission.request();
    print(status);
  }

  _log(String msg) {
    print('${shortDf.format(DateTime.now())} [ams] $msg');
  }

  //https://docs.agora.io/en/Voice/API%20Reference/flutter/rtc_engine/RtcEngine/enableLocalAudio.html
  // void enableLocalAudio(bool isEnabled) {
  //   _engine.enableLocalAudio(isEnabled);
  // }

  void stopAudioMixing() {
    if (_engine != null) {
      try {
        _engine.stopAudioMixing();
      } catch (e) {
        _log('Error stopping audio mixing');
        print(e);
      }
    }
  }

  Future<ConnectionStateType> checkConnection() async {
    final conn = await _engine.getConnectionState();
    _log('Connection state type now => $conn');
    return conn;
  }

  void restart() async {
    _log('Agora restart');
    if (_initializingMeetingMember == null) {
      _log(
          'Cannot restart agora, no initializing meeting member');
      return;
    }
    if (_engine != null) {
      _log('About to destroy engine');
      try {
        await _engine.destroy();
        _log('Engine destroyed');
      } catch (e) {
        _log('Error on destroy rtc engine => $e');
      }
    }
    await initializeAgora(_initializingMeetingMember, isRestart: true);
    _log('Agora restart complete....');
  }

  void restartSong() {
    _engine.setAudioMixingPosition(0);
  }

  void pauseAudioMixing() {
    _engine.pauseAudioMixing();
  }

  void resumeAudioMixing() {
    _engine.resumeAudioMixing();
  }

  void startAudioMixing(String filePath, {@required bool replaceMicStream}) {
    final loopback = false; //all can hear, true=only local user can hear
    final cycle = 1;
    _engine.startAudioMixing(filePath, loopback, replaceMicStream, cycle);
    if (_timer != null) {
      _timer.cancel();
    }
    final timerIntervalMs = 100;
    _audioPlayerInfoSubject.sink.add(AudioPlayerInfo(
        AudioMixingStateCode.Stopped,
        durationMs: 0,
        currentPlaybackPositionMs: 0));
    _timer = Timer.periodic(Duration(milliseconds: timerIntervalMs),
        (Timer t) async {
      final AudioMixingStateCode playerState = _audioPlayerStateSubject.value;
      final AudioPlayerInfo v = _audioPlayerInfoSubject.value;
      if ((t.tick % 10 == 0 && playerState == v.audioPlayerState) ||
          playerState != v.audioPlayerState) {
        if (_engine == null) {
          _timer.cancel();
          return;
        }
        int posMs = await _engine.getAudioMixingCurrentPosition();
        int durMs = await _engine.getAudioMixingDuration();
        _audioPlayerInfoSubject.sink.add(AudioPlayerInfo(playerState,
            durationMs: durMs, currentPlaybackPositionMs: posMs));
      } else {
        int lastPos = v.currentPlaybackPositionMs;
        int lastDur = v.durationMs;
        if (playerState == AudioMixingStateCode.Playing) {
          _audioPlayerInfoSubject.sink.add(AudioPlayerInfo(playerState,
              durationMs: lastDur,
              currentPlaybackPositionMs: lastPos + timerIntervalMs));
        }
      }
    });
  }

  void enableSpeakerphone(bool isEnabled) {
    _log('User enabled speakerphone=$isEnabled');
    _engine.setEnableSpeakerphone(isEnabled);
  }

  void toggleSpeakerphone() {
    final isOn = _isSpeakphoneEnabledSubject.value;
    _log('User toggled speakerphone, now isOn=$isOn');
    enableSpeakerphone(!isOn);
  }

  Future<bool> muteLocalAudioStream(bool isMuted) async {
    _log(
        "About to ${isMuted ? 'mute' : 'unmute'} my local audio stream");
    try {
      await _engine.muteLocalAudioStream(isMuted);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> muteLocalVideoStream(bool isMuted) async {
    _log(
        "About to ${isMuted ? 'mute' : 'unmute'} my local video stream");
    try {
      await _engine.muteLocalVideoStream(isMuted);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> initializeAgora(MeetingMemberData meetingMember,
      {bool isRestart = false}) async {
    final restartStr = isRestart ? '-restart' : '';
    if (_isAgoraInitialized && !isRestart) {
      return;
    }
    _log('Initialize Agora entry');
    if (this.meetingId == null || this.meetingId.isEmpty) {
      _log(
          'Meeting id is null or empty, not initializing agora');
      return;
    }
    if (this.meetingMedia == null) {
      _log('Meeting media is null, not initializing agora');
    }
    if (this.meetingMedia == MeetingMedia.none) {
      _log(
          'Meeting media is none, not initializing agora; there is nothing to do');
    }
    if (AGORA_APP_ID.isEmpty || AGORA_APP_ID == null) {
      _log(
          'Agora APP_ID null or empty, not initializing agora');
      return;
    }
    if (meetingMember == null) {
      _log('Meeting member null, not initializing agora');
      return;
    }
    if (meetingMember.agoraToken == null || meetingMember.agoraToken.isEmpty) {
      _log(
          'Agora token null or empty, not initializing agora');
      return;
    }
    if (meetingMember.agoraUid == null || meetingMember.agoraUid == 0) {
      _log('Agora uid null or zero, not initializing agora');
      return;
    }

    _isAgoraInitialized = true;
    _myAgoraUid = meetingMember.agoraUid;
    _myAgoraToken = meetingMember.agoraToken;
    _initializingMeetingMember = meetingMember;

    agoraRemoteUserIds.listen((List<int> remoteUserIds) {
      _log('Agora remote users=$remoteUserIds');
    });

    _agoraRemoteUserIdsSubject.sink.add(List<int>.empty(growable: true));
    _audioVolumeInfoMapSubject.sink.add(Map<int, List<CbAudioVolumeInfo>>());
    _audioStatusMapSubject.sink.add(Map<int, AudioStatus>());
    _videoStatusMapSubject.sink.add(Map<int, VideoStatus>());
    final channelName = 'Meeting-$meetingId';
    _log('About to initalize agora, channel=$channelName');

    await _initAgoraRtcEngine();
    _log('Agora rtc engine initalized');

    _addAgoraEventHandlers();
    _log('Agora event handlers initialized');

    //await _engine.enableWebSdkInteroperability(true);
    //ls.log('[ams$restartStr] added web sdk interop');

    if (meetingMedia == MeetingMedia.video) {
      VideoEncoderConfiguration config = VideoEncoderConfiguration(
        dimensions:VideoDimensions(width:320, height:180),
        frameRate: VideoFrameRate.Fps7,
      );
      await _engine.setVideoEncoderConfiguration(config);
      _log('''Set agora video encoder config, 
          h=${config.dimensions.width}, 
          w=${config.dimensions.width}''');
    }

    //set audio profile must be set before joining channel
    if (meetingMember.meetingRole == MeetingRole.participant) {
      await _engine.setAudioProfile(
          AudioProfile.SpeechStandard, AudioScenario.Education);
    } else {
      await _engine.setAudioProfile(
          AudioProfile.MusicStandard, AudioScenario.Education);
    }

    _log('''channel=$channelName, 
                  \nuid=$_myAgoraUid, 
                  \ntoken=$_myAgoraToken''');

    await _engine.joinChannel(_myAgoraToken, channelName, null, _myAgoraUid);
    _log('''Joined channel=$channelName, 
        token=$_myAgoraToken, uid=$_myAgoraUid''');

    if (IS_AGORA_AUDIO_LEVEL_TRACKING_ENABLED) {
      final int intervalMs = 500; // > 200 ms is recommended
      final int smoothingValue = 3; //3 is recommended
      final bool reportVoiceActivityDetectionOfLocalUser = true;
      _engine.enableAudioVolumeIndication(
          intervalMs, smoothingValue, reportVoiceActivityDetectionOfLocalUser);
    }

    final isAudioMuted = !INIT_MEETING_MIC_ENABLED;
    await _engine.muteLocalAudioStream(isAudioMuted);

    if (meetingMedia == MeetingMedia.video) {
      final isVideoMuted = !INIT_MEETING_CAMERA_ENABLED;
      await _engine.muteLocalVideoStream(isVideoMuted);
    }

    final cs = await _engine.getConnectionState();
    _log('Agora connection state=$cs');
  }

  final df = DateFormat('yyyy-MM-dd HH:mm:ss.SSSS');
  final shortDf = DateFormat('HH:mm:ss.SSSS');
  
  void _agoraPrint(String s) {
    print('[ams-] $s');
  }

  List<CbAudioVolumeInfo> _getUpdatedHistory(
      Map<int, List<CbAudioVolumeInfo>> priorMap,
      int uid,
      AudioVolumeInfo newAvi) {
    List<CbAudioVolumeInfo> history = priorMap[uid];
    if (history == null) {
      _log('Avi history was null for uid=$uid');
      history = List<CbAudioVolumeInfo>.empty(growable: true);
    }
    //likely me, so use my uid
    history.insert(0, CbAudioVolumeInfo(DateTime.now(), newAvi));
    if (history.length > 5) {
      history.removeLast();
    }
    for (int i = 0; i < history.length; i++) {
      _log(
          'Avi history, uid=$uid, i=$i, newAviVol=${newAvi.volume}, vol=${history[i].avi.volume}');
    }
    return history;
  }

  void _addAgoraEventHandlers() {
    _engine.setEventHandler(RtcEngineEventHandler(
      error: (code) {
        final info = 'onError: $code';
        _log(info);
      },
      rejoinChannelSuccess: (String s, int x, int y) {
        final info = 'rejoinChannelSuccess: $s, $x, $y';
        _log(info);
      },
      joinChannelSuccess:
          (String channel, int uid, int timeElapsedFromUserCallingMs) {
        final info = '''onJoinChannel: channel=$channel, uid=$uid, 
            elapsedTimeMs=$timeElapsedFromUserCallingMs''';
        _log(info);
      },
      networkTypeChanged: (NetworkType nt) {
        final info = 'networkTypeChanged: networkType=$nt';
        _log(info);
      },
      leaveChannel: (stats) {
        final info = 'onLeaveChannel: number of users=$stats';
        _log(info);
      },
      remoteAudioTransportStats:
          (int uid, int delayMs, int lossRatePct, int rxBitRate) {
        final info =
            'remoteAudioTransportStats: uid=$uid, delayMs=$delayMs, lossRatePct=$lossRatePct, rxBitRate=$rxBitRate ';
        _log(info);
      },
      userJoined: (int uid, int elapsedTimeMs) {
        final info = 'userJoined: uid=$uid, elapsedTimeMs=$elapsedTimeMs';
        _log(info);
        final v = _agoraRemoteUserIdsSubject.value;
        v.add(uid);
        _agoraRemoteUserIdsSubject.sink.add(v);
      },
      userOffline: (int uid, UserOfflineReason reason) {
        final info = 'userOffline: uid=$uid, reasonOffLIne=$reason';
        _log(info);
        final v = _agoraRemoteUserIdsSubject.value;
        v.remove(uid);
        _agoraRemoteUserIdsSubject.sink.add(v);
      },
      microphoneEnabled: (bool micEnabled) {
        final info = 'micEnabled=$micEnabled';
        _log(info);
        _agoraPrint(info);
        //_agoraMessages.add(info);
      },
      localAudioStateChanged: (AudioLocalState alState, AudioLocalError alErr) {
        final info =
            'localAudioStateChanged: audioLocalState=$alState audioLocalError=$alErr';
        _log(info);
      },
      tokenPrivilegeWillExpire: (String token) {
        final info = 'tokenPrivilegeWillExpire: $token';
        _log(info);
      },
      activeSpeaker: (int uid) {
        final info = 'activeSpeaker: uid=$uid';
        _log(info);
        _activeSpeakerUidSubject.sink.add(uid);
      },
      firstRemoteAudioDecoded: (int uid, int elapsedTimeMs) {
        final info =
            'firstRemoteAudioDecoded: uid=$uid, elapsedTimeMs=$elapsedTimeMs';
        _log(info);
        //_agoraMessages.add(info);
      },
      firstLocalAudioFrame: (int elapsedTimeMs) {
        final info = '[ams] firstLocalAudioFrame: elapsedTimeMs=$elapsedTimeMs';
        _log(info);
      },
      firstLocalAudioFramePublished: (int elapsedTimeMs) {
        final info =
            '[ams] firstLocalAudioFramePublished: elapsedTimeMs=$elapsedTimeMs';
        _log(info);
      },
      firstRemoteVideoFrame: (int uid, int w, int h, int elapsedTimeMs) {
        final info =
            '[ams] firstRemoteVideo: uid=$uid, w=$w, h=$h, elapsedTimeMs=$elapsedTimeMs';
        _log(info);
      },
      localAudioStats: (LocalAudioStats stats) {
        final info =
            'localAudioStats: numChannels=${stats.numChannels}, sentBitRate=${stats.sentBitrate}, sentSampleRate=${stats.sentSampleRate}, txPacketLossRt=${stats.txPacketLossRate}';
        _log(info);
      },
      remoteAudioStats: (RemoteAudioStats stats) {
        final info =
            'remoteAudioStats: uid=${stats.uid}, numChannels=${stats.numChannels}, publishDuration=${stats.publishDuration}, recBitRate=${stats.receivedBitrate}, recSampleRate=${stats.receivedSampleRate}, totalActiveTime=${stats.totalActiveTime}, totalFrozenTime=${stats.totalFrozenTime}';
        _log(info);
      },
      audioVolumeIndication: (List<AudioVolumeInfo> list, int x) {
        if (_isProcessingAvi) {
          return;
        }
        _isProcessingAvi = true;
        final priorMap = _audioVolumeInfoMapSubject.value;
        for (AudioVolumeInfo avi in list) {
          final info =
              'audioVolumeIndication: uid=${avi.uid}, isLocalSpeaking=${avi.vad == 1}, vol=${avi.volume}, totVol=$x';
          _log(info);
          if (avi.uid == 0) {
            List<CbAudioVolumeInfo> updatedHistory =
                _getUpdatedHistory(priorMap, _myAgoraUid, avi);
            priorMap[_myAgoraUid] = updatedHistory;
          } else {
            List<CbAudioVolumeInfo> updatedHistory =
                _getUpdatedHistory(priorMap, avi.uid, avi);
            priorMap[avi.uid] = updatedHistory;
          }
        }
        _audioVolumeInfoMapSubject.sink.add(priorMap);
        //final exitTime = DateTime.now();
        //final diffDur = exitTime.difference(entryTime);
        //print(
        //    '[ams-${tsdf.format(exitTime)}] - audioVolumeInfo exit, duration=${diffDur.inMilliseconds} ms');
        _isProcessingAvi = false;
      },
      rtcStats: (RtcStats stats) {
        final info =
            'rtcStats: txAudioBitRate=${stats.txAudioKBitRate}, txBytes=${stats.txBytes}, txBitRate=${stats.txKBitRate}, txPacketLossRate=${stats.txPacketLossRate}, txVidBytes=${stats.txVideoBytes}, txVidBitRate=${stats.txVideoKBitRate}, users=$stats';
        _log(info);
      },
      //Here's where the speakerphone comes into play
      audioRouteChanged: (AudioOutputRouting aop) {
        final info = '[ams] audioRouteChanged: audioOutputRouting=$aop';
        _log(info);
        if (aop == AudioOutputRouting.Speakerphone) {
          _isSpeakphoneEnabledSubject.sink.add(true);
        } else {
          _isSpeakphoneEnabledSubject.sink.add(false);
        }
      },
      audioMixingStateChanged:
          (AudioMixingStateCode mixState, AudioMixingReason mixReason) {
        final info =
            'audioMixingStateChanged: mixState=$mixState, mixReason=$mixReason';
        _log(info);
        _audioPlayerStateSubject.sink.add(mixState);
      },
      audioMixingFinished: () {
        final info = '[ams] audioMixingFinished: ';
        _log(info);
      },
      remoteVideoStateChanged: (int uid, VideoRemoteState state,
          VideoRemoteStateReason reason, int callbackMs) {
        final info =
            'remoteVideoStateChanged: uid=$uid, state=$state, reason=$reason, ms=$callbackMs';
        _log(info);
        final v = _videoStatusMapSubject.value;
        v[uid] = VideoStatus(uid, state, reason);
        _videoStatusMapSubject.sink.add(v);
      },
      remoteAudioStateChanged: (int uid, AudioRemoteState state,
          AudioRemoteStateReason reason, int callbackMs) {
        final info =
            'remoteAudioStateChanged: uid=$uid, state=$state, reason=$reason, ms=$callbackMs';
        _log(info);
        //_agoraMessages.add(info);
        final v = _audioStatusMapSubject.value;
        v[uid] = AudioStatus(uid, state, reason);
        _audioStatusMapSubject.sink.add(v);
      },
      audioSubscribeStateChanged: (String channel,
          int uid,
          StreamSubscribeState sss1,
          StreamSubscribeState sss2,
          int elapsedTimeMs) {
        final info =
            'audioSubscribedStateChanged: channel=$channel, uid=$uid, oldState=$sss1, newState=$sss2, elapsedTimeMs=$elapsedTimeMs';
        _log(info);
      },
      connectionLost: () {
        final info = '[ams] connectionLost:';
        _log(info);
      },
      connectionStateChanged:
          (ConnectionStateType cst, ConnectionChangedReason ccr) {
        final info =
            'connectionStateChanged: connection state type=$cst, connection changed reason=$ccr';
        _log(info);
      },
    ));
  }

  leaveChannel() async {
    if (_engine != null) {
      _log('RTC Engine not null, about to leave channel');
      await _engine.leaveChannel();
      _log('Left channel');
    } else {
      _log('RTC Engine null, nothing to do');
    }
  }

  destroyRtcEngineAndDispose() async {
    if (_engine != null) {
      _log('RTC Engine not null, about to destory it');
      await _engine.destroy();
      _engine = null;
      _log('RTC Engine destroyed and set to null');
    } else {
      _log('RTC Engine null, nothing to do');
    }
    dispose();
  }

  dispose() async {
    _log('dispose, entry');
    // destroy sdk
    if (_engine != null) {
      _log('RTC Engine not null, about to destroy engine');
      try {
        _engine.destroy();
      } catch (e) {
        _log('error trying to destroy rtc engine');
        _log(e);
      }
      _log('dispose, rtc engine destroyed');
      _engine = null;
    } else {
      _log('dispose, RTC Engine null, nothing to do');
    }

    await _agoraRemoteUserIdsSubject.drain();
    await _audioVolumeInfoMapSubject.drain();
    await _audioStatusMapSubject.drain();
    await _isSpeakphoneEnabledSubject.drain();
    await _activeSpeakerUidSubject.drain();
    await _videoStatusMapSubject.drain();
    await _audioPlayerStateSubject.drain();
    await _audioPlayerInfoSubject.drain();

    await _agoraRemoteUserIdsSubject.close();
    await _audioVolumeInfoMapSubject.close();
    await _audioStatusMapSubject.close();
    await _isSpeakphoneEnabledSubject.close();
    await _activeSpeakerUidSubject.close();
    await _videoStatusMapSubject.close();
    await _audioPlayerStateSubject.close();
    await _audioPlayerInfoSubject.close();

    if (_timer != null) {
      _timer.cancel();
    }

    _log('dispose, exit');
  }
}
