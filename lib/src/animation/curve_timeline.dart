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

/// Base class for frames that use linear, stepped, or Bezier interpolation.
///
class CurveTimeline implements Timeline {
  static const _linear = 0;
  static const _stepped = 1;
  static const _bezier = 2;
  static const _bezierSize = 10 * 2 - 1;

  final List<Map<int, _CurveData>?> _curves;

  CurveTimeline(int frameCount) : _curves = List<Map<int, _CurveData>?>.filled(frameCount - 1, null);

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {}

  @override
  int getPropertyId() => 0;

  int get frameCount => _curves.length + 1;

  void setLinear(int frameIndex) {
    if (frameIndex >= _curves.length) return;
    _setCurveData(frameIndex, 0, _CurveData.linear());
  }

  void setStepped(int frameIndex) {
    if (frameIndex >= _curves.length) return;
    _setCurveData(frameIndex, 0, _CurveData.stepped());
  }

  /// Sets the control handle positions for an interpolation bezier curve
  /// used to transition from this keyframe to the next.
  ///
  /// cx1 and cx2 are from 0 to 1, representing the percent of time between
  /// the two keyframes. cy1 and cy2 are the percent of the difference between
  /// the keyframe's values.

  void setCurve(int frameIndex, double cx1, double cy1, double cx2, double cy2) {
    if (frameIndex >= _curves.length) return;

    final tmpx = (-cx1 * 2 + cx2) * 0.03;
    final tmpy = (-cy1 * 2 + cy2) * 0.03;
    final dddfx = ((cx1 - cx2) * 3 + 1) * 0.006;
    final dddfy = ((cy1 - cy2) * 3 + 1) * 0.006;
    var ddfx = tmpx * 2 + dddfx;
    var ddfy = tmpy * 2 + dddfy;
    var dfx = cx1 * 0.3 + tmpx + dddfx * 0.16666667;
    var dfy = cy1 * 0.3 + tmpy + dddfy * 0.16666667;

    var i = 0;
    final curves = Float32List(_bezierSize - 1);

    var x = dfx;
    var y = dfy;

    for (final n = curves.length; i < n; i += 2) {
      curves[i + 0] = x;
      curves[i + 1] = y;
      dfx += ddfx;
      dfy += ddfy;
      ddfx += dddfx;
      ddfy += dddfy;
      x += dfx;
      y += dfy;
    }

    _setCurveData(frameIndex, 0, _CurveData.percent(curves));
  }

  /// Stores an absolute-time/value Bezier curve, matching Spine 4.x JSON.
  ///
  /// Multi-value timelines use a separate value index for each animated value.
  void setBezier(int frameIndex, int valueIndex, double time1, double value1, double cx1,
      double cy1, double cx2, double cy2, double time2, double value2) {
    if (frameIndex >= _curves.length) return;

    final tmpx = (time1 - cx1 * 2 + cx2) * 0.03;
    final tmpy = (value1 - cy1 * 2 + cy2) * 0.03;
    final dddx = ((cx1 - cx2) * 3 - time1 + time2) * 0.006;
    final dddy = ((cy1 - cy2) * 3 - value1 + value2) * 0.006;
    var ddx = tmpx * 2 + dddx;
    var ddy = tmpy * 2 + dddy;
    var dx = (cx1 - time1) * 0.3 + tmpx + dddx * 0.16666667;
    var dy = (cy1 - value1) * 0.3 + tmpy + dddy * 0.16666667;
    var x = time1 + dx;
    var y = value1 + dy;

    final curves = Float32List(_bezierSize - 1);
    for (var i = 0; i < curves.length; i += 2) {
      curves[i + 0] = x;
      curves[i + 1] = y;
      dx += ddx;
      dy += ddy;
      ddx += dddx;
      ddy += dddy;
      x += dx;
      y += dy;
    }

    _setCurveData(frameIndex, valueIndex, _CurveData.absolute(curves));
  }

  double getCurvePercent(int frameIndex, double percent) {
    if (percent < 0.0) percent = 0.0;
    if (percent > 1.0) percent = 1.0;

    final curve = _getCurveData(frameIndex, 0);
    if (curve.type == _linear) return percent;
    if (curve.type == _stepped) return 0;

    double x = 0;
    final curves = curve.values;
    for (var i = 0; i < curves.length; i += 2) {
      x = curves[i];
      if (x >= percent) {
        final prevX = (i == 0) ? 0.0 : curves[i - 2];
        final prevY = (i == 0) ? 0.0 : curves[i - 1];
        return prevY + (curves[i + 1] - prevY) * (percent - prevX) / (x - prevX);
      }
    }

    final y = curves[curves.length - 1];
    return y + (1 - y) * (percent - x) / (1 - x); // Last point is 1,1.
  }

  double getCurveValue(int frameIndex, int valueIndex, double time, double time1,
      double value1, double time2, double value2) {
    final curve = _getCurveDataForValue(frameIndex, valueIndex);
    if (curve.type == _linear) {
      return value1 + (value2 - value1) * (time - time1) / (time2 - time1);
    }
    if (curve.type == _stepped) return value1;

    if (!curve.absolute) {
      final percent = getCurvePercent(frameIndex, (time - time1) / (time2 - time1));
      return value1 + (value2 - value1) * percent;
    }

    final curves = curve.values;
    if (curves[0] > time) {
      return value1 + (time - time1) / (curves[0] - time1) * (curves[1] - value1);
    }

    for (var i = 2; i < curves.length; i += 2) {
      if (curves[i] >= time) {
        final x = curves[i - 2];
        final y = curves[i - 1];
        return y + (time - x) / (curves[i] - x) * (curves[i + 1] - y);
      }
    }

    final x = curves[curves.length - 2];
    final y = curves[curves.length - 1];
    return y + (time - x) / (time2 - x) * (value2 - y);
  }

  void setSteppedValue(int frameIndex, int valueIndex) {
    if (frameIndex >= _curves.length) return;
    _setCurveData(frameIndex, valueIndex, _CurveData.steppedValue());
  }

  _CurveData _getCurveData(int frameIndex, int valueIndex) {
    final frameCurves = _curves[frameIndex];
    if (frameCurves == null) return _CurveData.linear();
    return frameCurves[valueIndex] ?? _CurveData.linear();
  }

  _CurveData _getCurveDataForValue(int frameIndex, int valueIndex) {
    final frameCurves = _curves[frameIndex];
    if (frameCurves == null) return _CurveData.linear();

    final curve = frameCurves[valueIndex];
    if (curve != null) return curve;

    final legacyCurve = frameCurves[0];
    if (legacyCurve != null && !legacyCurve.absolute) return legacyCurve;

    return _CurveData.linear();
  }

  void _setCurveData(int frameIndex, int valueIndex, _CurveData curve) {
    final frameCurves = _curves[frameIndex] ??= <int, _CurveData>{};
    frameCurves[valueIndex] = curve;
  }
}

class _CurveData {
  final int type;
  final Float32List values;
  final bool absolute;

  _CurveData._(this.type, this.values, this.absolute);

  factory _CurveData.linear() => _CurveData._(CurveTimeline._linear, Float32List(0), false);

  factory _CurveData.stepped() => _CurveData._(CurveTimeline._stepped, Float32List(0), false);

  factory _CurveData.steppedValue() => _CurveData._(CurveTimeline._stepped, Float32List(0), true);

  factory _CurveData.percent(Float32List values) => _CurveData._(CurveTimeline._bezier, values, false);

  factory _CurveData.absolute(Float32List values) => _CurveData._(CurveTimeline._bezier, values, true);
}
