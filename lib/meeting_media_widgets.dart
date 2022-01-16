// import 'package:flutter/material.dart';
// import 'agora_grid_page.dart';

// class MeetingMicButton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<bool>(
//       stream: ms.isMyMicOn,
//       builder: (context, onSnap) {
//         final isOn = onSnap.hasData ? onSnap.data : false;
//         return IconButton(
//             onPressed: () {
//               //ms.toggleMic();
//             },
//             icon: Icon(isOn ? Icons.mic : Icons.mic_off,
//                 color: isOn ? Colors.red : null));
//       },
//     );
//   }
// }

// class MeetingVideoCameraButton extends StatelessWidget {
//   final MeetingService ms;
//   MeetingVideoCameraButton(this.ms);
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<bool>(
//       stream: ms.isMyCameraOn,
//       builder: (context, onSnap) {
//         final isOn = onSnap.hasData ? onSnap.data : false;
//         return IconButton(
//             onPressed: () {
//               ms.toggleCamera();
//             },
//             icon: Icon(isOn ? Icons.videocam : Icons.videocam_off,
//                 color: isOn ? Colors.red : null));
//       },
//     );
//   }
// }

// class MeetingSeeRoomButton extends StatelessWidget {
//   final MeetingService meetingService;
//   MeetingSeeRoomButton(this.meetingService);
//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       onPressed: () async {
//         final rt = MaterialPageRoute(
//           builder: (BuildContext context) {
//             return AgoraGridPage(meetingService);
//           },
//           fullscreenDialog: true,
//         );
//         Navigator.of(context).push(rt);
//       },
//       icon: Icon(Icons.people, color: Theme.of(context).colorScheme.primary),
//     );
//   }
// }

// class MeetingSpeakerphoneButton extends StatelessWidget {
//   final MeetingService ms;
//   MeetingSpeakerphoneButton(this.ms);
//   @override
//   Widget build(BuildContext context) {
//     if (ms.meetingMedia == MeetingMedia.none || ms.ams == null) {
//       return SizedBox(width: 0);
//     }
//     return StreamBuilder<bool>(
//       stream: ms.ams.isSpeakerphoneEnabled,
//       builder: (context, onSnap) {
//         final isOn = onSnap.hasData ? onSnap.data : false;
//         return IconButton(
//             onPressed: () {
//               ms.ams.toggleSpeakerphone();
//             },
//             icon: CbIcon(
//                 icon: isOn ? 'speakersound_on' : 'speakersound_off',
//                 color: isOn ? Colors.red : null));
//       },
//     );
//   }
// }
