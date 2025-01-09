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

class PathConstraintPositionTimeline extends CurveTimeline {
  static const int _entries = 2;
  static const int _prevTime = -2;
  static const int _prevValue = -1;
  static const int _time = 0;
  static const int _value = 1;

  int pathConstraintIndex = 0;

  final Float32List frames; // time, position, ...

  PathConstraintPositionTimeline(super.frameCount)
      : frames = Float32List(frameCount * _entries);

  @override
  int getPropertyId() => (TimelineType.pathConstraintPosition.ordinal << 24) + pathConstraintIndex;

  /// Sets the time and value of the specified keyframe.

  void setFrame(int frameIndex, double time, double value) {
    frameIndex *= _entries;
    frames[frameIndex + _time] = time;
    frames[frameIndex + _value] = value;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    var constraint = skeleton.pathConstraints[pathConstraintIndex];
    var data = constraint.data;
    double p = 0;

    if (time < frames[0]) {
      // Time is before first frame.
      if (pose == MixPose.setup) {
        constraint.position = data.position;
      } else if (pose == MixPose.current) {
        constraint.position += (constraint.data.position - constraint.position) * alpha;
      }
      return;
    }

    if (time >= frames[frames.length + _prevTime]) {
      // Time is after last frame.
      p = frames[frames.length + _prevValue];
    } else {
      // Interpolate between the previous frame and the current frame.
      var frame = Animation.binarySearch(frames, time, _entries);
      var t0 = frames[frame + _prevTime];
      var p0 = frames[frame + _prevValue];
      var t1 = frames[frame + _time];
      var p1 = frames[frame + _value];
      var between = 1.0 - (time - t1) / (t0 - t1);
      var percent = getCurvePercent(frame ~/ _entries - 1, between);
      p = p0 + (p1 - p0) * percent;
    }

    if (pose == MixPose.setup) {
      constraint.position = data.position + (p - data.position) * alpha;
    } else {
      constraint.position = constraint.position + (p - constraint.position) * alpha;
    }
  }
}
