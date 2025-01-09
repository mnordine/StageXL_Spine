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

class Bone implements Updatable {
  final BoneData data;
  final Skeleton skeleton;
  final Bone? parent;
  final List<Bone> children = [];

  double x = 0;
  double y = 0;
  double rotation = 0;
  double scaleX = 0;
  double scaleY = 0;
  double shearX = 0;
  double shearY = 0;

  double ax = 0;
  double ay = 0;
  double arotation = 0;
  double ascaleX = 0;
  double ascaleY = 0;
  double ashearX = 0;
  double ashearY = 0;
  bool appliedValid = false;

  double _a = 1;
  double _b = 0;
  double _c = 0;
  double _d = 1;
  double _worldX = 0;
  double _worldY = 0;

  bool _sorted = false;

  Bone(this.data, this.skeleton, this.parent) {
    setToSetupPose();
  }

  /// Same as updateWorldTransform().
  /// This method exists for Bone to implement Updatable.

  @override
  void update() {
    updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
  }

  /// Computes the world SRT using the parent bone and this bone's local SRT.

  void updateWorldTransform() {
    updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
  }

  /// Computes the world SRT using the parent bone and the specified local SRT.
  void updateWorldTransformWith(double x, double y, double rotation, double scaleX, double scaleY,
      double shearX, double shearY) {
    ax = x;
    ay = y;
    arotation = rotation;
    ascaleX = scaleX;
    ascaleY = scaleY;
    ashearX = shearX;
    ashearY = shearY;
    appliedValid = true;

    final parent = this.parent;
    if (parent == null) {
      // Root bone.
      _a = scaleX * _cosDeg(rotation + shearX);
      _b = scaleY * _cosDeg(rotation + 90.0 + shearY);
      _c = scaleX * _sinDeg(rotation + shearX);
      _d = scaleY * _sinDeg(rotation + 90.0 + shearY);
      _worldX = x + skeleton.x;
      _worldY = y + skeleton.y;
      return;
    }

    var pa = parent.a;
    var pb = parent.b;
    var pc = parent.c;
    var pd = parent.d;

    _worldX = pa * x + pb * y + parent.worldX;
    _worldY = pc * x + pd * y + parent.worldY;

    switch (data.transformMode) {
      case TransformMode.normal:
        final la = scaleX * _cosDeg(rotation + shearX);
        final lb = scaleY * _cosDeg(rotation + 90 + shearY);
        final lc = scaleX * _sinDeg(rotation + shearX);
        final ld = scaleY * _sinDeg(rotation + 90 + shearY);
        _a = pa * la + pb * lc;
        _b = pa * lb + pb * ld;
        _c = pc * la + pd * lc;
        _d = pc * lb + pd * ld;
        return;

      case TransformMode.onlyTranslation:
        _a = scaleX * _cosDeg(rotation + shearX);
        _b = scaleY * _cosDeg(rotation + 90 + shearY);
        _c = scaleX * _sinDeg(rotation + shearX);
        _d = scaleY * _sinDeg(rotation + 90 + shearY);

      case TransformMode.noRotationOrReflection:
        var s = pa * pa + pc * pc;
        double prx = 0;
        if (s > 0.0001) {
          s = (pa * pd - pb * pc).abs() / s;
          pb = pc * s;
          pd = pa * s;
          prx = _toDeg(math.atan2(pc, pa));
        } else {
          pa = 0.0;
          pc = 0.0;
          prx = 90.0 - _toDeg(math.atan2(pd, pb));
        }
        final rx = rotation + shearX - prx;
        final ry = rotation + shearY - prx + 90.0;
        final la = scaleX * _cosDeg(rx);
        final lb = scaleY * _cosDeg(ry);
        final lc = scaleX * _sinDeg(rx);
        final ld = scaleY * _sinDeg(ry);
        _a = pa * la - pb * lc;
        _b = pa * lb - pb * ld;
        _c = pc * la + pd * lc;
        _d = pc * lb + pd * ld;

      case TransformMode.noScale:
      case TransformMode.noScaleOrReflection:
        final cos = _cosDeg(rotation);
        final sin = _sinDeg(rotation);
        var za = pa * cos + pb * sin;
        var zc = pc * cos + pd * sin;
        var s = math.sqrt(za * za + zc * zc);
        if (s > 0.00001) s = 1.0 / s;
        za *= s;
        zc *= s;
        s = math.sqrt(za * za + zc * zc);
        final r = math.pi / 2.0 + math.atan2(zc, za);
        var zb = math.cos(r) * s;
        var zd = math.sin(r) * s;
        final la = scaleX * _cosDeg(shearX);
        final lb = scaleY * _cosDeg(90.0 + shearY);
        final lc = scaleX * _sinDeg(shearX);
        final ld = scaleY * _sinDeg(90.0 + shearY);
        if (data.transformMode != TransformMode.noScaleOrReflection) {
          if (pa * pd - pb * pc < 0.0) {
            zb = -zb;
            zd = -zd;
          }
        }
        _a = za * la + zb * lc;
        _b = za * lb + zb * ld;
        _c = zc * la + zd * lc;
        _d = zc * lb + zd * ld;
    }
  }

  void setToSetupPose() {
    x = data.x;
    y = data.y;
    rotation = data.rotation;
    scaleX = data.scaleX;
    scaleY = data.scaleY;
    shearX = data.shearX;
    shearY = data.shearY;
  }

  double get a => _a;
  double get b => _b;
  double get c => _c;
  double get d => _d;
  double get worldX => _worldX;
  double get worldY => _worldY;

  double get worldRotationX => _toDeg(math.atan2(_c, _a));
  double get worldRotationY => _toDeg(math.atan2(_d, _b));
  double get worldScaleX => math.sqrt(_a * _a + _c * _c);
  double get worldScaleY => math.sqrt(_b * _b + _d * _d);

  double worldToLocalRotationX() {
    final parent = this.parent;
    if (parent == null) return arotation;
    final pa = parent.a;
    final pb = parent.b;
    final pc = parent.c;
    final pd = parent.d;
    return _toDeg(math.atan2(pa * c - pc * a, pd * a - pb * c));
  }

  double worldToLocalRotationY() {
    final parent = this.parent;
    if (parent == null) return arotation;
    final pa = parent.a;
    final pb = parent.b;
    final pc = parent.c;
    final pd = parent.d;
    return _toDeg(math.atan2(pa * d - pc * b, pd * b - pb * d));
  }

  void rotateWorld(double degrees) {
    final a = this.a;
    final b = this.b;
    final c = this.c;
    final d = this.d;
    final cos = _cosDeg(degrees);
    final sin = _sinDeg(degrees);
    _a = cos * a - sin * c;
    _b = cos * b - sin * d;
    _c = sin * a + cos * c;
    _d = sin * b + cos * d;
    appliedValid = false;
  }

  /// Computes the individual applied transform values from the world transform.
  /// This can be useful to perform processing using the applied transform after
  /// the world transform has been modified directly (eg, by a constraint).
  ///
  /// Some information is ambiguous in the world transform, such as -1,-1 scale
  /// versus 180 rotation.

  void _updateAppliedTransform() {
    appliedValid = true;
    final parent = this.parent;

    if (parent == null) {
      ax = worldX;
      ay = worldY;
      arotation = _toDeg(math.atan2(c, a));
      ascaleX = math.sqrt(a * a + c * c);
      ascaleY = math.sqrt(b * b + d * d);
      ashearX = 0.0;
      ashearY = _toDeg(math.atan2(a * b + c * d, a * d - b * c));
      return;
    }

    final pa = parent.a;
    final pb = parent.b;
    final pc = parent.c;
    final pd = parent.d;
    final pid = 1.0 / (pa * pd - pb * pc);
    final dx = worldX - parent.worldX;
    final dy = worldY - parent.worldY;
    ax = (dx * pd * pid - dy * pb * pid);
    ay = (dy * pa * pid - dx * pc * pid);

    final ia = pid * pd;
    final id = pid * pa;
    final ib = pid * pb;
    final ic = pid * pc;
    final ra = ia * a - ib * c;
    final rb = ia * b - ib * d;
    final rc = id * c - ic * a;
    final rd = id * d - ic * b;

    ashearX = 0.0;
    ascaleX = math.sqrt(ra * ra + rc * rc);

    if (ascaleX > 0.0001) {
      final det = ra * rd - rb * rc;
      ascaleY = det / ascaleX;
      ashearY = _toDeg(math.atan2(ra * rb + rc * rd, det));
      arotation = _toDeg(math.atan2(rc, ra));
    } else {
      ascaleX = 0.0;
      ascaleY = math.sqrt(rb * rb + rd * rd);
      ashearY = 0.0;
      arotation = 90.0 - _toDeg(math.atan2(rd, rb));
    }
  }

  void worldToLocal(Float32List world) {
    final invDet = 1.0 / (a * d - b * c);
    final x = world[0] - worldX;
    final y = world[1] - worldY;
    world[0] = x * d * invDet - y * b * invDet;
    world[1] = y * a * invDet - x * c * invDet;
  }

  void localToWorld(Float32List local) {
    final localX = local[0];
    final localY = local[1];
    local[0] = localX * a + localY * b + worldX;
    local[1] = localX * c + localY * d + worldY;
  }

  @override
  String toString() => data.name;
}
