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

part of stagexl_spine;

class TranslateTimeline extends CurveTimeline {
  static const _entries = 3;
  static const _prevTime = -3;
  static const _prevX = -2;
  static const _prevY = -1;
  static const _time = 0;
  static const _x = 1;
  static const _y = 2;

  final Float32List frames; // time, value, value, ...
  int boneIndex = 0;

  TranslateTimeline(super.frameCount)
      : frames = Float32List(frameCount * 3);

  @override
  int getPropertyId() => (TimelineType.translate.ordinal << 24) + boneIndex;

  /// Sets the time and value of the specified keyframe.

  void setFrame(int frameIndex, double time, double x, double y) {
    frameIndex *= 3;
    frames[frameIndex + 0] = time;
    frames[frameIndex + 1] = x;
    frames[frameIndex + 2] = y;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final bone = skeleton.bones[boneIndex];
    double x = 0;
    double y = 0;

    if (time < frames[0]) {
      // Time is before first frame.
      if (pose == MixPose.setup) {
        bone.x = bone.data.x;
        bone.y = bone.data.y;
      } else if (pose == MixPose.current) {
        bone.x += (bone.data.x - bone.x) * alpha;
        bone.y += (bone.data.y - bone.y) * alpha;
      }
      return;
    }

    if (time >= frames[frames.length + _prevTime]) {
      // Time is after last frame.
      x = frames[frames.length + _prevX];
      y = frames[frames.length + _prevY];
    } else {
      // Interpolate between the previous frame and the current frame.
      final frame = Animation.binarySearch(frames, time, _entries);
      final t0 = frames[frame + _prevTime];
      final x0 = frames[frame + _prevX];
      final y0 = frames[frame + _prevY];
      final t1 = frames[frame + _time];
      final x1 = frames[frame + _x];
      final y1 = frames[frame + _y];
      final between = 1.0 - (time - t1) / (t0 - t1);
      final percent = getCurvePercent(frame ~/ _entries - 1, between);
      x = x0 + (x1 - x0) * percent;
      y = y0 + (y1 - y0) * percent;
    }

    if (pose == MixPose.setup) {
      bone.x = bone.data.x + x * alpha;
      bone.y = bone.data.y + y * alpha;
    } else {
      bone.x = bone.x + (bone.data.x - bone.x + x) * alpha;
      bone.y = bone.y + (bone.data.y - bone.y + y) * alpha;
    }
  }
}
