import 'package:flutter/material.dart';
import 'agora_grid.dart';

class AgoraGridPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meeting Members'),
      ),
      body: AgoraMeetingGrid(),
    );
  }
}
