import 'dart:math';
import 'package:flutter/material.dart';
import 'agora_data.dart';
import 'agora_tile.dart';

class AgoraMeetingGrid extends StatelessWidget {
  final Widget headWidget;
  AgoraMeetingGrid({@required this.headWidget});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgoraUser>>(
      stream: meetingService.agoraUsers,
      builder: (context, agListSnap) {
        if (!agListSnap.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final List<int> userIds = [];
        for (AgoraUser au in agListSnap.data) {
          userIds.add(au.member.agoraUid);
        }
        final cnt = agListSnap.data.length;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            double x = _getTargetX(w, h, 4.0, cnt);
            return CustomScrollView(
              slivers: [
                if (headWidget != null) SliverToBoxAdapter(child: headWidget),
                _header('fun'),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: x,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 4.0,
                    childAspectRatio: 0.83333,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int inx) {
                      final agoraUser = agListSnap.data[inx];
                      return AgoraTile(agoraUser, meetingService);
                    },
                    childCount: cnt,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _getTargetX(double maxW, double maxH, double spacing, int panelCnt) {
    double largestTargetX = 0;
    for (int col = 1; col < 5; col++) {
      if (col == 2 && panelCnt == 1) {
        continue;
      }
      if (col > 2) {
        int minToPlay = (col - 1) * (col - 1);
        if (panelCnt < minToPlay) {
          continue;
        }
      }

      int panelsPerColumn = (panelCnt / col).ceil();
      int panelsPerRow = col;
      double maxSizeY =
          (maxH - ((panelsPerColumn - 1) * spacing)) / panelsPerColumn;
      double maxSizeX = (maxW - ((panelsPerRow - 1) * spacing)) / panelsPerRow;
      double targetX = min(maxSizeY * 0.833333, maxSizeX);
      if (targetX > largestTargetX) {
        largestTargetX = targetX;
      }
      //print('col=$col, targetX=$targetX');
    }
    return largestTargetX;
  }

  SliverPersistentHeader _header(String headerText) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 100.0,
        maxHeight: 100.0,
        child: Container(
            color: Colors.lightBlue, child: Center(child: Text(headerText))),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    @required this.minHeight,
    @required this.maxHeight,
    @required this.child,
  });
  final double minHeight;
  final double maxHeight;
  final Widget child;
  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Column(
      children: [
        Container(
          height: 50,
          child: Row(
            children: [
              //MeetingSpeakerphoneButton(meetingService),
              const Text('My Speakerphone'),
            ],
          ),
        ),
        Container(
          height: 50,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  //meetingService.restartAgora();
                },
                icon: const Icon(Icons.network_cell),
              ),
              const Text('Restart Connection'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
