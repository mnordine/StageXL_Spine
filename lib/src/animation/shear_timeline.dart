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

class ShearTimeline extends TranslateTimeline {
  static const _entries = 3;
  static const _prevTime = -3;
  static const _prevX = -2;
  static const _prevY = -1;
  static const _time = 0;
  static const _x = 1;
  static const _y = 2;

  ShearTimeline(super.frameCount);

  @override
  int getPropertyId() => (TimelineType.shear.ordinal << 24) + boneIndex;

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final bone = skeleton.bones[boneIndex];
    double x = 0;
    double y = 0;

    if (time < frames[0]) {
      // Time is before first frame.
      if (pose == MixPose.setup) {
        bone.shearX = bone.data.shearX;
        bone.shearY = bone.data.shearY;
      } else if (pose == MixPose.current) {
        bone.shearX += (bone.data.shearX - bone.shearX) * alpha;
        bone.shearY += (bone.data.shearY - bone.shearY) * alpha;
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
      final frameIndex = frame ~/ _entries - 1;
      x = getCurveValue(frameIndex, 0, time, t0, x0, t1, x1);
      y = getCurveValue(frameIndex, 1, time, t0, y0, t1, y1);
    }

    if (pose == MixPose.setup) {
      bone.shearX = bone.data.shearX + x * alpha;
      bone.shearY = bone.data.shearY + y * alpha;
    } else {
      bone.shearX = bone.shearX + (bone.data.shearX - bone.shearX + x) * alpha;
      bone.shearY = bone.shearY + (bone.data.shearY - bone.shearY + y) * alpha;
    }
  }
}

class ShearXTimeline extends TranslateXTimeline {
  ShearXTimeline(super.frameCount);

  @override
  int getPropertyId() => (TimelineType.shear.ordinal << 24) + boneIndex;

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final bone = skeleton.bones[boneIndex];
    double x = 0;

    if (time < frames[0]) {
      if (pose == MixPose.setup) {
        bone.shearX = bone.data.shearX;
      } else if (pose == MixPose.current) {
        bone.shearX += (bone.data.shearX - bone.shearX) * alpha;
      }
      return;
    }

    if (time >= frames[frames.length - 2]) {
      x = frames[frames.length - 1];
    } else {
      final frame = Animation.binarySearch(frames, time, 2);
      x = getCurveValue(frame ~/ 2 - 1, 0, time, frames[frame - 2], frames[frame - 1],
          frames[frame], frames[frame + 1]);
    }

    if (pose == MixPose.setup) {
      bone.shearX = bone.data.shearX + x * alpha;
    } else {
      bone.shearX = bone.shearX + (bone.data.shearX - bone.shearX + x) * alpha;
    }
  }
}

class ShearYTimeline extends TranslateYTimeline {
  ShearYTimeline(super.frameCount);

  @override
  int getPropertyId() => (TimelineType.shear.ordinal << 24) + boneIndex;

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final bone = skeleton.bones[boneIndex];
    double y = 0;

    if (time < frames[0]) {
      if (pose == MixPose.setup) {
        bone.shearY = bone.data.shearY;
      } else if (pose == MixPose.current) {
        bone.shearY += (bone.data.shearY - bone.shearY) * alpha;
      }
      return;
    }

    if (time >= frames[frames.length - 2]) {
      y = frames[frames.length - 1];
    } else {
      final frame = Animation.binarySearch(frames, time, 2);
      y = getCurveValue(frame ~/ 2 - 1, 0, time, frames[frame - 2], frames[frame - 1],
          frames[frame], frames[frame + 1]);
    }

    if (pose == MixPose.setup) {
      bone.shearY = bone.data.shearY + y * alpha;
    } else {
      bone.shearY = bone.shearY + (bone.data.shearY - bone.shearY + y) * alpha;
    }
  }
}
