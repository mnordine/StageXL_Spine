part of '../../stagexl_spine.dart';

class SequenceTimeline implements Timeline {
  static const _entries = 3;
  static const _prevTime = -3;
  static const _time = 0;
  static const _modeAndIndex = 1;
  static const _delay = 2;

  final Float32List frames;
  final RenderAttachment attachment;
  int slotIndex = 0;

  SequenceTimeline(int frameCount, this.attachment)
      : frames = Float32List(frameCount * _entries);

  int get frameCount => frames.length ~/ _entries;

  @override
  int getPropertyId() => (TimelineType.sequence.ordinal << 24) + slotIndex;

  void setFrame(int frameIndex, double time, SequenceMode mode, int index, double delay) {
    frameIndex *= _entries;
    frames[frameIndex + _time] = time;
    frames[frameIndex + _modeAndIndex] = (mode.index | (index << 4)).toDouble();
    frames[frameIndex + _delay] = delay;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final slot = skeleton.slots[slotIndex];
    if (time < frames[0]) {
      if (pose == MixPose.setup) slot.sequenceIndex = -1;
      return;
    }

    final frame = time >= frames[frames.length + _prevTime]
        ? frames.length - _entries
        : Animation.binarySearch(frames, time, _entries) - _entries;

    final before = frames[frame + _time];
    final modeAndIndex = frames[frame + _modeAndIndex].toInt();
    final delay = frames[frame + _delay];
    final sequence = attachment.sequence;
    if (sequence == null || slot.attachment != attachment) return;

    var index = modeAndIndex >> 4;
    final mode = SequenceMode.values[modeAndIndex & 0x0f];
    final count = sequence.count;

    if (mode != SequenceMode.hold && delay > 0) {
      index += ((time - before) / delay + 0.00001).floor();
      switch (mode) {
        case SequenceMode.hold:
          break;
        case SequenceMode.once:
          index = math.min(count - 1, index);
        case SequenceMode.loop:
          index %= count;
        case SequenceMode.pingpong:
          final n = (count << 1) - 2;
          index = n == 0 ? 0 : index % n;
          if (index >= count) index = n - index;
        case SequenceMode.onceReverse:
          index = math.max(count - 1 - index, 0);
        case SequenceMode.loopReverse:
          index = count - 1 - (index % count);
        case SequenceMode.pingpongReverse:
          final n = (count << 1) - 2;
          index = n == 0 ? 0 : (index + count - 1) % n;
          if (index >= count) index = n - index;
      }
    }

    slot.sequenceIndex = index;
  }
}
