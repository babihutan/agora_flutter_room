import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as local;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as remote;
import 'agora_data.dart';

class AgoraTile extends StatelessWidget {
  final AgoraUser user;
  AgoraTile(this.user);
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontFamily: 'Condensed-Medium', color: Colors.white, fontSize: 16);
    return StreamBuilder<bool>(
      stream: ms.isMyMicOn,
      builder: (context, isMyMicOnSnap) {
        return StreamBuilder<bool>(
          stream: ms.isMyCameraOn,
          builder: (context, isMyCameraOnSnap) {
            return LayoutBuilder(
              builder: (context, BoxConstraints box) {
                Widget view = _getView(context, box, isMyCameraOnSnap);

                final isMe = user.person.id == centralDataService.myPersonId;
                double myVideoWidgetSize = 0.0;
                if (isMe && ms.meetingMedia == MeetingMedia.video) {
                  myVideoWidgetSize = 60.0;
                }
                double levelW = 0.0;
                final double micW = 60.0;
                final double availSize =
                    box.maxWidth - micW - myVideoWidgetSize;
                final includeLevel = availSize > 60;
                final includeName = availSize > 120;
                if (includeLevel) {
                  if (includeName) {
                    levelW = availSize * 0.40;
                  } else {
                    levelW = availSize * 0.85;
                  }
                }
                final nameText = includeName
                    ? Text(user.person.firstName,
                        overflow: TextOverflow.ellipsis, style: style)
                    : null;

                bool isMicOnForLevel = false;
                if (user.audioStatus != null) {
                  final state = user.audioStatus.state;
                  isMicOnForLevel = (state == AudioRemoteState.Decoding ||
                      state == AudioRemoteState.Starting);
                }
                if (isMe && isMyMicOnSnap.hasData) {
                  isMicOnForLevel = isMyMicOnSnap.data;
                }

                final levelBar = (!includeLevel ||
                        user.avi == null ||
                        isMicOnForLevel == false ||
                        user.avi.avi.volume == null)
                    ? null
                    : AgoraLevelBar(user.aviHistory, w: levelW);
                return GridTile(
                    footer: GridTileBar(
                      backgroundColor: Colors.black54,
                      leading: Row(
                        children: [
                          _micButton(context, isMyMicOnSnap),
                          _cameraButton(context, isMyCameraOnSnap),
                        ],
                      ),
                      title: nameText,
                      trailing: levelBar,
                    ),
                    child: GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed('/persons/${user.person.id}');
                        },
                        child: view));
              },
            );
          },
        );
      },
    );
  }

  Widget _cameraButton(
      BuildContext context, AsyncSnapshot<bool> isMyCameraOnSnap) {
    final isMe = user.person.id == centralDataService.myPersonId;
    if (ms.meetingMedia != MeetingMedia.video || !isMe) {
      return SizedBox(width: 0);
    }
    bool isCameraOn = false;
    if (isMyCameraOnSnap.hasData) {
      isCameraOn = isMyCameraOnSnap.data;
    }
    final iconButton = IconButton(
      onPressed: () {
        if (isMe) {
          ms.toggleCamera();
        } else {
          _showSnackBar(
              context, 'Cannot change remote user camera in this version');
        }
      },
      icon: Icon(isCameraOn ? Icons.videocam : Icons.videocam_off),
    );
    return iconButton;
  }

  Widget _micButton(BuildContext context, AsyncSnapshot<bool> isMyMicOnSnap) {
    final isMe = user.person.id == centralDataService.myPersonId;
    bool isWeirdState = true;
    bool isMicOn = false;
    if (user.audioStatus != null) {
      final state = user.audioStatus.state;
      isMicOn = (state == AudioRemoteState.Decoding ||
          state == AudioRemoteState.Starting);
      isWeirdState = (state == AudioRemoteState.Failed ||
          state == AudioRemoteState.Frozen);
    }
    if (isMe && isMyMicOnSnap.hasData) {
      isMicOn = isMyMicOnSnap.data;
      isWeirdState = false;
    }
    final iconButton = IconButton(
      onPressed: () async {
        if (isMe) {
          ms.toggleMic();
        } else {
          final role = await ms.myMeetingRole.first;
          final isEnabled = await ms.isRemoteMuteEnabled.first;
          if (role == MeetingRole.leader && isEnabled) {
            if (isMicOn) {
              _confirmMuteRemoteUser(context);
            } else {
              _showSnackBar(context, 'Cannot enable remote user mic');
            }
          } else {
            if( !isEnabled ) {
              _showSnackBar(context, 'Leaders cannot change remote user mic in this group');
            } else {
              _showSnackBar(context, 'Non-leaders cannot change remote user mic');
            }
          }
        }
      },
      icon: isWeirdState
          ? SizedBox(width: 30)
          : Icon(isMicOn ? Icons.mic : Icons.mic_off),
    );
    return iconButton;
  }

  Widget _getView(BuildContext context, BoxConstraints box,
      AsyncSnapshot<bool> isMyCameraOnSnap) {
    final isMe = user.person.id == centralDataService.myPersonId;
    final failoverImg =
        CbCircleIcon(iconData: Icons.person, size: box.maxWidth * 0.70);
    if (ms.meetingMedia == MeetingMedia.video) {
      if (isMe) {
        if (isMyCameraOnSnap.hasData && isMyCameraOnSnap.data == true) {
          return local.SurfaceView();
        } else {
          if (!user.person.hasProfileImg) {
            return failoverImg;
          } else {
            return FirebaseImg(
                url: user.person.imgUrl, h: box.maxHeight, w: box.maxWidth);
          }
        }
      }
      if (user.videoStatus == null ||
          user.videoStatus.state == VideoRemoteState.Stopped ||
          user.videoStatus.state == VideoRemoteState.Failed ||
          user.videoStatus.state == VideoRemoteState.Frozen) {
        if (user.person.hasProfileImg) {
          return FirebaseImg(
              url: user.person.imgUrl, h: box.maxHeight, w: box.maxWidth);
        } else {
          return failoverImg;
        }
      } else {
        final channelName = 'Meeting-${ms.meetingId}';
        return remote.SurfaceView(
            uid: user.member.agoraUid, channelId: channelName);
      }
    } else {
      if (user.person.hasProfileImg) {
        return FirebaseImg(
            url: user.person.imgUrl, h: box.maxHeight, w: box.maxWidth);
      } else {
        return failoverImg;
      }
    }
  }

  void _showSnackBar(BuildContext context, String msg) {
    final snackBar = SnackBar(
      content: Text(msg),
      action: SnackBarAction(
        label: 'Got it',
        onPressed: () {
          //print('snack bar pressed');
        },
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  _confirmMuteRemoteUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Mute remote user?"),
          content: Text("Mute the mic for ${user.person.fullName}?",
              style: const TextStyle(fontFamily: 'Narrow-Book')),
          actions: <Widget>[
            TextButton(
              child: Text("Mute user".toUpperCase(),
                  style: Theme.of(context).textTheme.headline1),
              onPressed: () async {
                // MeetingMemberRemoteControlCommand.add(
                //     MeetingRemoteControlCommand.muteMic,
                //     meetingId: ms.meetingId,
                //     personId: user.person.id);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Cancel".toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .headline1
                      .copyWith(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
