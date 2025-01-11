import 'package:flutter/material.dart';
import '../providers/scroll_retention_provider.dart';

class PositionRetainedScrollPhysics extends ScrollPhysics {
  late final _retentionState = ScrollRetentionState();

  PositionRetainedScrollPhysics({super.parent});

  @override
  PositionRetainedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PositionRetainedScrollPhysics(
      parent: buildParent(ancestor),
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final position = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    // Calculate how much content was added to both ends
    final oldMax = oldPosition.maxScrollExtent;
    final newMax = newPosition.maxScrollExtent;
    final oldMin = oldPosition.minScrollExtent;
    final newMin = newPosition.minScrollExtent;

    // Since our list is reversed, content added to the top (newer messages)
    // appears at the bottom of the scroll area
    final contentAddedToTop = newMax - oldMax;
    final contentAddedToBottom = oldMin - newMin;

    if (_retentionState.shouldRetainPosition &&
        (contentAddedToTop > 0 || contentAddedToBottom > 0)) {
      // If content was added to the top (newer messages), we need to adjust the position
      // to account for the new content, keeping our relative position the same
      final adjustedPosition = position + contentAddedToTop;
      return adjustedPosition;
    } else {
      return position;
    }
  }
}
