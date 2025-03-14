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

/// Base class for frames that use an interpolation bezier curve.
///
class CurveTimeline implements Timeline {
  static const double _linear = 0;
  static const double _stepped = 1;
  static const double _bezier = 2;
  static const _bezierSize = 10 * 2 - 1;

  final Float32List _curves; // type, x, y, ...

  CurveTimeline(int frameCount) : _curves = Float32List((frameCount - 1) * _bezierSize);

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {}

  @override
  int getPropertyId() => 0;

  int get frameCount => _curves.length ~/ _bezierSize + 1;

  void setLinear(int frameIndex) {
    _curves[frameIndex * _bezierSize] = _linear;
  }

  void setStepped(int frameIndex) {
    _curves[frameIndex * _bezierSize] = _stepped;
  }

  /// Sets the control handle positions for an interpolation bezier curve
  /// used to transition from this keyframe to the next.
  ///
  /// cx1 and cx2 are from 0 to 1, representing the percent of time between
  /// the two keyframes. cy1 and cy2 are the percent of the difference between
  /// the keyframe's values.

  void setCurve(int frameIndex, double cx1, double cy1, double cx2, double cy2) {
    final tmpx = (-cx1 * 2 + cx2) * 0.03;
    final tmpy = (-cy1 * 2 + cy2) * 0.03;
    final dddfx = ((cx1 - cx2) * 3 + 1) * 0.006;
    final dddfy = ((cy1 - cy2) * 3 + 1) * 0.006;
    var ddfx = tmpx * 2 + dddfx;
    var ddfy = tmpy * 2 + dddfy;
    var dfx = cx1 * 0.3 + tmpx + dddfx * 0.16666667;
    var dfy = cy1 * 0.3 + tmpy + dddfy * 0.16666667;

    var i = frameIndex * _bezierSize;
    _curves[i++] = _bezier;

    var x = dfx;
    var y = dfy;

    for (final n = i + _bezierSize - 1; i < n; i += 2) {
      _curves[i + 0] = x;
      _curves[i + 1] = y;
      dfx += ddfx;
      dfy += ddfy;
      ddfx += dddfx;
      ddfy += dddfy;
      x += dfx;
      y += dfy;
    }
  }

  double getCurvePercent(int frameIndex, double percent) {
    if (percent < 0.0) percent = 0.0;
    if (percent > 1.0) percent = 1.0;

    var i = frameIndex * _bezierSize;
    final type = _curves[i];
    if (type == _linear) return percent;
    if (type == _stepped) return 0;
    i++;

    double x = 0;
    for (final start = i, n = i + _bezierSize - 1; i < n; i += 2) {
      x = _curves[i];
      if (x >= percent) {
        final prevX = (i == start) ? 0.0 : _curves[i - 2];
        final prevY = (i == start) ? 0.0 : _curves[i - 1];
        return prevY + (_curves[i + 1] - prevY) * (percent - prevX) / (x - prevX);
      }
    }

    final y = _curves[i - 1];
    return y + (1 - y) * (percent - x) / (1 - x); // Last point is 1,1.
  }
}
