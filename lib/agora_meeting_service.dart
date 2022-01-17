import 'dart:async';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'agora_data.dart';
import 'config.dart';
import 'enums.dart';

class AgoraMeetingService {
  final String meetingId;
  final MeetingMedia media;
  late final RtcEngine _engine;

  final df = DateFormat('yyyy-MM-dd HH:mm:ss.SSSS');
  final shortDf = DateFormat('HH:mm:ss.SSSS');

  AgoraMeetingService(this.meetingId, this.media) {
    _log('ctor, media=$media');
    _initAgoraRtcEngine(media);
  }

  final _isMyMicrophoneOpenSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isMyMicrophoneOpen => _isMyMicrophoneOpenSubject.stream;

  final _isMySpeakerphoneEnabledSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isMySpeakerphoneEnabled =>
      _isMySpeakerphoneEnabledSubject.stream;

  final _isMyCameraOpenSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isMyCameraOpen => _isMyCameraOpenSubject.stream;

  _log(String msg) {
    print('${shortDf.format(DateTime.now())} [ams] $msg');
  }

  String get channelName {
    return meetingId;
  }

  Future<void> _initAgoraRtcEngine(MeetingMedia media) async {
    final config = RtcEngineContext(
      AGORA_APP_ID,
      logConfig: LogConfig(level: LogLevel.Warn),
    );
    _engine = await RtcEngine.createWithContext(config);
    _addEngineListeners();
    if (media == MeetingMedia.video) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else if (media == MeetingMedia.audio) {
      await _engine.enableAudio();
    }

    await _engine.setChannelProfile(ChannelProfile.LiveBroadcasting);
    await _engine.setClientRole(ClientRole.Broadcaster);
    return;
  }

  Future<void> joinChannel(String myToken, int myUid) async {
    await _handlePermissions(media);
    await _engine
        .joinChannel(myToken, channelName, null, myUid)
        .catchError((onError) {
      _log('error ${onError.toString()}');
    });
  }

  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
    return;
  }

  Future<void> _handlePermissions(MeetingMedia media) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (media == MeetingMedia.video) {
        await [Permission.microphone, Permission.camera].request();
      } else if (media == MeetingMedia.audio) {
        await Permission.microphone.request();
      }
    }
    return;
  }

  toggleMic() {
    bool isMicOpen = _isMyMicrophoneOpenSubject.value!;
    _engine.enableLocalAudio(!isMicOpen).then((value) {
      _isMyMicrophoneOpenSubject.sink.add(!isMicOpen);
    }).catchError((err) {
      _log('enableLocalAudio error => $err');
    });
  }

  toggleSpeakerphone() {
    bool isSpeakerphoneEnabled = _isMySpeakerphoneEnabledSubject.value!;
    _engine.enableLocalAudio(!isSpeakerphoneEnabled).then((value) {
      _isMySpeakerphoneEnabledSubject.sink.add(!isSpeakerphoneEnabled);
    }).catchError((err) {
      _log('set speakerphone enabled error => $err');
    });
  }

  toggleCamera() {
    _engine.switchCamera().then((value) {
      _isMyCameraOpenSubject.sink.add(value);
    }).catchError((err) {
      _log('toggle camera error => $err');
    });
  }

  Future<ConnectionStateType> checkConnection() async {
    final conn = await _engine.getConnectionState();
    _log('Connection state type now => $conn');
    return conn;
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

  void _addEngineListeners() {
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
      },
      firstLocalAudioFrame: (int elapsedTimeMs) {
        final info = 'firstLocalAudioFrame: elapsedTimeMs=$elapsedTimeMs';
        _log(info);
      },
      firstLocalAudioFramePublished: (int elapsedTimeMs) {
        final info =
            '[ams] firstLocalAudioFramePublished: elapsedTimeMs=$elapsedTimeMs';
        _log(info);
      },
      firstRemoteVideoFrame: (int uid, int w, int h, int elapsedTimeMs) {
        final info =
            'firstRemoteVideo: uid=$uid, w=$w, h=$h, elapsedTimeMs=$elapsedTimeMs';
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
        const info = 'audioMixingFinished: ';
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
        const info = 'connectionLost:';
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

  dispose() async {
    _log('dispose, entry');
    try {
      _engine.destroy();
    } catch (e) {
      _log('error trying to destroy rtc engine');
    }

     _isMyCameraOpenSubject.close();
     _isMyMicrophoneOpenSubject.close();
     _isMySpeakerphoneEnabledSubject.close();

    _log('dispose, exit');
  }
}
