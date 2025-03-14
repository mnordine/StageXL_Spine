/// ****************************************************************************
/// Spine Runtimes Software License v2.5
///
/// Copyright (c) 2013-2016, Esoteric Software
/// All rights reserved.
///
/// You are granted a perpetual, non-exclusive, non-sublicensable, and
/// non-transferable license to use, install, execute, and perform the Spine
/// Runtimes software and derivative works solely for personal or internal
/// use. Without the written permission of Esoteric Software (see Section 2 of
/// the Spine Software License Agreement), you may not (a) modify, translate,
/// adapt, or develop new applications using the Spine Runtimes or otherwise
/// create derivative works or improvements of the Spine Runtimes or (b) remove,
/// delete, alter, or obscure any trademarks or any copyright, trademark, patent,
/// or other intellectual property or proprietary rights notices on or in the
/// Software, including any copy thereof. Redistributions in binary or source
/// form must include this license and terms.
///
/// THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
/// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
/// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
/// EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
/// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
/// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
/// USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
/// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
/// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
/// POSSIBILITY OF SUCH DAMAGE.
///***************************************************************************

part of '../../stagexl_spine.dart';

class ColorTimeline extends CurveTimeline {
  static const _entries = 5;
  static const _prevTime = -5;
  static const _prevR = -4;
  static const _prevG = -3;
  static const _prevB = -2;
  static const _prevA = -1;
  static const _time = 0;
  static const _r = 1;
  static const _g = 2;
  static const _b = 3;
  static const _a = 4;

  final Float32List frames; // time, r, g, b, a, ...
  int slotIndex = 0;

  ColorTimeline(super.frameCount)
      : frames = Float32List(frameCount * 5);

  @override
  int getPropertyId() => (TimelineType.color.ordinal << 24) + slotIndex;

  /// Sets the time and value of the specified keyframe.
  ///
  void setFrame(int frameIndex, double time, double r, double g, double b, double a) {
    frameIndex *= _entries;
    frames[frameIndex + _time] = time;
    frames[frameIndex + _r] = r;
    frames[frameIndex + _g] = g;
    frames[frameIndex + _b] = b;
    frames[frameIndex + _a] = a;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final slot = skeleton.slots[slotIndex];
    double r = 0;
    double g = 0;
    double b = 0;
    double a = 0;

    if (time < frames[0]) {
      if (pose == MixPose.setup) {
        slot.color.setFromColor(slot.data.color);
      } else if (pose == MixPose.current) {
        final color = slot.color;
        final setup = slot.data.color;
        color.add((setup.r - color.r) * alpha, (setup.g - color.g) * alpha,
            (setup.b - color.b) * alpha, (setup.a - color.a) * alpha);
      }
      return;
    }

    if (time >= frames[frames.length + _prevTime]) {
      // Time is after last frame.
      r = frames[frames.length + _prevR];
      g = frames[frames.length + _prevG];
      b = frames[frames.length + _prevB];
      a = frames[frames.length + _prevA];
    } else {
      // Interpolate between the previous frame and the current frame.
      final frame = Animation.binarySearch(frames, time, _entries);
      final t0 = frames[frame + _prevTime];
      final r0 = frames[frame + _prevR];
      final g0 = frames[frame + _prevG];
      final b0 = frames[frame + _prevB];
      final a0 = frames[frame + _prevA];
      final t1 = frames[frame + _time];
      final r1 = frames[frame + _r];
      final g1 = frames[frame + _g];
      final b1 = frames[frame + _b];
      final a1 = frames[frame + _a];
      final between = 1.0 - (time - t1) / (t0 - t1);
      final percent = getCurvePercent(frame ~/ _entries - 1, between);
      r = r0 + (r1 - r0) * percent;
      g = g0 + (g1 - g0) * percent;
      b = b0 + (b1 - b0) * percent;
      a = a0 + (a1 - a0) * percent;
    }

    if (alpha == 1.0) {
      slot.color.setFrom(r, g, b, a);
    } else {
      if (pose == MixPose.setup) {
        slot.color.setFromColor(slot.data.color);
      }
      slot.color.r += (r - slot.color.r) * alpha;
      slot.color.g += (g - slot.color.g) * alpha;
      slot.color.b += (b - slot.color.b) * alpha;
      slot.color.a += (a - slot.color.a) * alpha;
    }
  }
}
