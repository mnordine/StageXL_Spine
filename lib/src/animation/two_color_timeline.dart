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

class TwoColorTimeline extends CurveTimeline {
  static const _entries = 8;
  static const _prevTime = -8;
  static const _prevR1 = -7;
  static const _prevG1 = -6;
  static const _prevB1 = -5;
  static const _prevA1 = -4;
  static const _prevR2 = -3;
  static const _prevG2 = -2;
  static const _prevB2 = -1;
  static const _time = 0;
  static const _r1 = 1;
  static const _g1 = 2;
  static const _b1 = 3;
  static const _a1 = 4;
  static const _r2 = 5;
  static const _g2 = 6;
  static const _b2 = 7;

  int slotIndex = 0;
  final Float32List frames; // time, r, g, b, a, ...

  TwoColorTimeline(super.frameCount)
      : frames = Float32List(frameCount * _entries);

  @override
  int getPropertyId() => (TimelineType.twoColor.ordinal << 24) + slotIndex;

  /// Sets the time and value of the specified keyframe.
  void setFrame(int frameIndex, double time, double r, double g, double b, double a, double r2,
      double g2, double b2) {
    frameIndex *= TwoColorTimeline._entries;
    frames[frameIndex] = time;
    frames[frameIndex + TwoColorTimeline._r1] = r;
    frames[frameIndex + TwoColorTimeline._g1] = g;
    frames[frameIndex + TwoColorTimeline._b1] = b;
    frames[frameIndex + TwoColorTimeline._a1] = a;
    frames[frameIndex + TwoColorTimeline._r2] = r2;
    frames[frameIndex + TwoColorTimeline._g2] = g2;
    frames[frameIndex + TwoColorTimeline._b2] = b2;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final slot = skeleton.slots[slotIndex];
    double r1 = 0;
    double g1 = 0;
    double b1 = 0;
    double a1 = 0;
    double r2 = 0;
    double g2 = 0;
    double b2 = 0;

    if (time < frames[0]) {
      if (pose == MixPose.setup) {
        slot.color.setFromColor(slot.data.color);
        if (slot.data.darkColor != null) {
          slot.darkColor?.setFromColor(slot.data.darkColor!);
        }
      } else if (pose == MixPose.current && slot.darkColor != null && slot.data.darkColor != null) {
        final l1 = slot.color;
        final d1 = slot.darkColor!;
        final l2 = slot.data.color;
        final s2 = slot.data.darkColor!;
        l1.add((l2.r - l1.r) * alpha, (l2.g - l1.g) * alpha, (l2.b - l1.b) * alpha,
            (l2.a - l1.a) * alpha);
        d1.add((s2.r - d1.r) * alpha, (s2.g - d1.g) * alpha, (s2.b - d1.b) * alpha, 0);
      }
      return;
    }

    if (time >= frames[frames.length - _entries]) {
      // Time is after last frame.
      r1 = frames[frames.length + _prevR1];
      g1 = frames[frames.length + _prevG1];
      b1 = frames[frames.length + _prevB1];
      a1 = frames[frames.length + _prevA1];
      r2 = frames[frames.length + _prevR2];
      g2 = frames[frames.length + _prevG2];
      b2 = frames[frames.length + _prevB2];
    } else {
      // Interpolate between the previous frame and the current frame.
      final frame = Animation.binarySearch(frames, time, _entries);

      final t0 = frames[frame + _prevTime];
      final r01 = frames[frame + _prevR1];
      final g01 = frames[frame + _prevG1];
      final b01 = frames[frame + _prevB1];
      final a01 = frames[frame + _prevA1];
      final r02 = frames[frame + _prevR2];
      final g02 = frames[frame + _prevG2];
      final b02 = frames[frame + _prevB2];

      final t1 = frames[frame + _time];
      final r11 = frames[frame + _r1];
      final g11 = frames[frame + _g1];
      final b11 = frames[frame + _b1];
      final a11 = frames[frame + _a1];
      final r12 = frames[frame + _r2];
      final g12 = frames[frame + _g2];
      final b12 = frames[frame + _b2];

      final between = 1.0 - (time - t1) / (t0 - t1);
      final percent = getCurvePercent(frame ~/ _entries - 1, between);

      r1 = r01 + (r11 - r01) * percent;
      g1 = g01 + (g11 - g01) * percent;
      b1 = b01 + (b11 - b01) * percent;
      a1 = a01 + (a11 - a01) * percent;
      r2 = r02 + (r12 - r02) * percent;
      g2 = g02 + (g12 - g02) * percent;
      b2 = b02 + (b12 - b02) * percent;
    }

    if (alpha == 1.0) {
      slot.color.setFrom(r1, g1, b1, a1);
      slot.darkColor?.setFrom(r2, g2, b2, 1);
    } else {
      final light = slot.color;
      final dark = slot.darkColor;
      if (pose == MixPose.setup) {
        light.setFromColor(slot.data.color);
        if (slot.data.darkColor != null) {
          dark?.setFromColor(slot.data.darkColor!);
        }
      }
      light.add((r1 - light.r) * alpha, (g1 - light.g) * alpha, (b1 - light.b) * alpha,
          (a1 - light.a) * alpha);
      dark?.add((r2 - dark.r) * alpha, (g2 - dark.g) * alpha, (b2 - dark.b) * alpha, 0);
    }
  }
}
