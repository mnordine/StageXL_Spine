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

class TransformConstraintTimeline extends CurveTimeline {
  static const _entries = 5;
  static const _prevTime = -5;
  static const _prevRotate = -4;
  static const _prevTranslate = -3;
  static const _prevScale = -2;
  static const _prevShear = -1;
  static const _time = 0;
  static const _rotate = 1;
  static const _translate = 2;
  static const _scale = 3;
  static const _shear = 4;

  int transformConstraintIndex = 0;

  final Float32List frames; // time, rotate mix, translate mix, scale mix, shear mix, ...

  TransformConstraintTimeline(super.frameCount)
      : frames = Float32List(frameCount * _entries);

  @override
  int getPropertyId() => (TimelineType.transformConstraint.ordinal << 24) + transformConstraintIndex;

  /// Sets the time and mixes of the specified keyframe.

  void setFrame(int frameIndex, double time, double rotateMix, double translateMix, double scaleMix,
      double shearMix) {
    frameIndex *= _entries;
    frames[frameIndex + _time] = time;
    frames[frameIndex + _rotate] = rotateMix;
    frames[frameIndex + _translate] = translateMix;
    frames[frameIndex + _scale] = scaleMix;
    frames[frameIndex + _shear] = shearMix;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    final tcs = skeleton.transformConstraints;
    final tc = tcs[transformConstraintIndex];
    final data = tc.data;
    double rot = 0; // rotate
    double tra = 0; // translate
    double sca = 0; // scale
    double she = 0; // shear

    if (time < frames[0]) {
      // Time is before first frame.
      if (pose == MixPose.setup) {
        tc.rotateMix = data.rotateMix;
        tc.translateMix = data.translateMix;
        tc.scaleMix = data.scaleMix;
        tc.shearMix = data.shearMix;
      } else if (pose == MixPose.current) {
        tc.rotateMix += (data.rotateMix - tc.rotateMix) * alpha;
        tc.translateMix += (data.translateMix - tc.translateMix) * alpha;
        tc.scaleMix += (data.scaleMix - tc.scaleMix) * alpha;
        tc.shearMix += (data.shearMix - tc.shearMix) * alpha;
      }
      return;
    }

    if (time >= frames[frames.length + _prevTime]) {
      // Time is after last frame.
      rot = frames[frames.length + _prevRotate];
      tra = frames[frames.length + _prevTranslate];
      sca = frames[frames.length + _prevScale];
      she = frames[frames.length + _prevShear];
    } else {
      // Interpolate between the previous frame and the current frame.
      final frame = Animation.binarySearch(frames, time, _entries);
      final tim0 = frames[frame + _prevTime];
      final rot0 = frames[frame + _prevRotate];
      final tra0 = frames[frame + _prevTranslate];
      final sca0 = frames[frame + _prevScale];
      final she0 = frames[frame + _prevShear];
      final tim1 = frames[frame + _time];
      final rot1 = frames[frame + _rotate];
      final tra1 = frames[frame + _translate];
      final sca1 = frames[frame + _scale];
      final she1 = frames[frame + _shear];
      final between = 1.0 - (time - tim1) / (tim0 - tim1);
      final percent = getCurvePercent(frame ~/ _entries - 1, between);
      rot = rot0 + (rot1 - rot0) * percent;
      tra = tra0 + (tra1 - tra0) * percent;
      sca = sca0 + (sca1 - sca0) * percent;
      she = she0 + (she1 - she0) * percent;
    }

    if (pose == MixPose.setup) {
      tc.rotateMix = data.rotateMix + (rot - data.rotateMix) * alpha;
      tc.translateMix = data.translateMix + (tra - data.translateMix) * alpha;
      tc.scaleMix = data.scaleMix + (sca - data.scaleMix) * alpha;
      tc.shearMix = data.shearMix + (she - data.shearMix) * alpha;
    } else {
      tc.rotateMix = tc.rotateMix + (rot - tc.rotateMix) * alpha;
      tc.translateMix = tc.translateMix + (tra - tc.translateMix) * alpha;
      tc.scaleMix = tc.scaleMix + (sca - tc.scaleMix) * alpha;
      tc.shearMix = tc.shearMix + (she - tc.shearMix) * alpha;
    }
  }
}
