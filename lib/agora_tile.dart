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
    return Text('person => ${user.personName}');
  }
}
