part of '../../stagexl_spine.dart';

enum SequenceMode {
  hold,
  once,
  loop,
  pingpong,
  onceReverse,
  loopReverse,
  pingpongReverse,
}

class SpineSequence {
  final int count;
  final int start;
  final int digits;
  final int setupIndex;
  final List<BitmapData> bitmapData;

  SpineSequence({
    required this.count,
    required this.start,
    required this.digits,
    required this.setupIndex,
    required this.bitmapData,
  });

  String pathFor(String path, int index) {
    final frame = start + index;
    final suffix = digits == 0 ? '$frame' : '$frame'.padLeft(digits, '0');
    return '$path$suffix';
  }

  BitmapData bitmapDataForIndex(int index) {
    final clampedIndex = index.clamp(0, bitmapData.length - 1);
    return bitmapData[clampedIndex];
  }
}
