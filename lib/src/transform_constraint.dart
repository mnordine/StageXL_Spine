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

part of '../stagexl_spine.dart';

class TransformConstraint implements Constraint {
  final TransformConstraintData data;
  final List<Bone> bones = [];

  Bone target;
  double translateMix = 0;
  double rotateMix = 0;
  double scaleMix = 0;
  double shearMix = 0;

  final Float32List _temp = Float32List(2);

  TransformConstraint(this.data, Skeleton skeleton) : target = skeleton.findBone(data.target.name)! {
    translateMix = data.translateMix;
    rotateMix = data.rotateMix;
    scaleMix = data.scaleMix;
    shearMix = data.shearMix;

    for (final boneData in data.bones) {
      bones.add(skeleton.findBone(boneData.name)!);
    }
  }

  void apply() {
    update();
  }

  @override
  void update() {
    if (data.local) {
      if (data.relative) {
        _applyRelativeLocal();
      } else {
        _applyAbsoluteLocal();
      }
    } else {
      if (data.relative) {
        _applyRelativeWorld();
      } else {
        _applyAbsoluteWorld();
      }
    }
  }

  void _applyAbsoluteWorld() {
    final rotateMix = this.rotateMix;
    final translateMix = this.translateMix;
    final scaleMix = this.scaleMix;
    final shearMix = this.shearMix;

    final target = this.target;

    final ta = target.a;
    final tb = target.b;
    final tc = target.c;
    final td = target.d;

    final degRadReflect = ta * td - tb * tc > 0 ? _deg2rad : -_deg2rad;
    final offsetRotation = data.offsetRotation * degRadReflect;
    final offsetShearY = data.offsetShearY * degRadReflect;
    final bones = this.bones;

    for (var i = 0; i < bones.length; i++) {
      final bone = bones[i];
      var modified = false;

      if (rotateMix != 0) {
        final a = bone.a;
        final b = bone.b;
        final c = bone.c;
        final d = bone.d;
        var r = math.atan2(tc, ta) - math.atan2(c, a) + offsetRotation;

        if (r > math.pi) {
          r -= math.pi * 2;
        } else if (r < -math.pi) {
           r += math.pi * 2;
        }

        r *= rotateMix;
        final cos = math.cos(r);
        final sin = math.sin(r);
        bone._a = cos * a - sin * c;
        bone._b = cos * b - sin * d;
        bone._c = sin * a + cos * c;
        bone._d = sin * b + cos * d;
        modified = true;
      }

      if (translateMix != 0) {
        _temp[0] = data.offsetX;
        _temp[1] = data.offsetY;
        target.localToWorld(_temp);
        bone._worldX += (_temp[0] - bone.worldX) * translateMix;
        bone._worldY += (_temp[1] - bone.worldY) * translateMix;
        modified = true;
      }

      if (scaleMix > 0) {
        var s = math.sqrt(bone.a * bone.a + bone.c * bone.c);
        var ts = math.sqrt(ta * ta + tc * tc);
        if (s > 0.00001) s = (s + (ts - s + data.offsetScaleX) * scaleMix) / s;
        bone._a *= s;
        bone._c *= s;
        s = math.sqrt(bone.b * bone.b + bone.d * bone.d);
        ts = math.sqrt(tb * tb + td * td);
        if (s > 0.00001) s = (s + (ts - s + data.offsetScaleY) * scaleMix) / s;
        bone._b *= s;
        bone._d *= s;
        modified = true;
      }

      if (shearMix > 0) {
        final b = bone.b;
        final d = bone.d;
        final by = math.atan2(d, b);
        var r = math.atan2(td, tb) - math.atan2(tc, ta) - (by - math.atan2(bone.c, bone.a));
        
        if (r > math.pi) {
          r -= math.pi * 2;
        } else if (r < -math.pi) {
          r += math.pi * 2;
        }

        r = by + (r + offsetShearY) * shearMix;
        final s = math.sqrt(b * b + d * d);
        bone._b = math.cos(r) * s;
        bone._d = math.sin(r) * s;
        modified = true;
      }

      if (modified) bone.appliedValid = false;
    }
  }

  void _applyRelativeWorld() {
    final rotateMix = this.rotateMix;
    final translateMix = this.translateMix;
    final scaleMix = this.scaleMix;
    final shearMix = this.shearMix;
    final target = this.target;
    final ta = target.a;
    final tb = target.b;
    final tc = target.c;
    final td = target.d;
    const degRad = math.pi / 180.0;
    final degRadReflect = ta * td - tb * tc > 0 ? degRad : -degRad;
    final offsetRotation = data.offsetRotation * degRadReflect;
    final offsetShearY = data.offsetShearY * degRadReflect;
    final bones = this.bones;

    for (var i = 0; i < bones.length; i++) {
      final bone = bones[i];
      var modified = false;

      if (rotateMix != 0) {
        final a = bone.a;
        final b = bone.b;
        final c = bone.c;
        final d = bone.d;
        var r = math.atan2(tc, ta) + offsetRotation;

        if (r > math.pi) {
          r -= 2.0 * math.pi;
        } else if (r < -math.pi) {
          r += 2.0 * math.pi;
        }

        r *= rotateMix;
        final cos = math.cos(r);
        final sin = math.sin(r);
        bone._a = cos * a - sin * c;
        bone._b = cos * b - sin * d;
        bone._c = sin * a + cos * c;
        bone._d = sin * b + cos * d;
        modified = true;
      }

      if (translateMix != 0) {
        final temp = _temp;
        temp[0] = data.offsetX;
        temp[1] = data.offsetY;
        target.localToWorld(temp);
        bone._worldX += temp[0] * translateMix;
        bone._worldY += temp[1] * translateMix;
        modified = true;
      }

      if (scaleMix > 0) {
        final st = math.sqrt(ta * ta + tc * tc) - 1.0;
        final sx = (st + data.offsetScaleX) * scaleMix + 1.0;
        final sy = (st + data.offsetScaleY) * scaleMix + 1.0;
        bone._a *= sx;
        bone._c *= sx;
        bone._b *= sy;
        bone._d *= sy;
        modified = true;
      }

      if (shearMix > 0) {
        var r = math.atan2(td, tb) - math.atan2(tc, ta);
        if (r > math.pi) {
          r -= 2.0 * math.pi;
        } else if (r < -math.pi) {
          r += 2.0 * math.pi;
        }

        final b = bone.b;
        final d = bone.d;
        final s = math.sqrt(b * b + d * d);
        r = math.atan2(d, b) + (r - math.pi / 2.0 + offsetShearY) * shearMix;
        bone._b = math.cos(r) * s;
        bone._d = math.sin(r) * s;
        modified = true;
      }

      if (modified) bone.appliedValid = false;
    }
  }

  void _applyAbsoluteLocal() {
    final rotateMix = this.rotateMix;
    final translateMix = this.translateMix;
    final scaleMix = this.scaleMix;
    final shearMix = this.shearMix;
    final target = this.target;
    if (!target.appliedValid) target._updateAppliedTransform();
    final bones = this.bones;

    for (var i = 0; i < bones.length; i++) {
      final bone = bones[i];
      if (!bone.appliedValid) bone._updateAppliedTransform();

      var rotation = bone.arotation;
      if (rotateMix != 0.0) {
        final r = target.arotation - rotation + data.offsetRotation;
        rotation += _wrapRotation(r) * rotateMix;
      }

      var x = bone.ax;
      var y = bone.ay;
      if (translateMix != 0) {
        x += (target.ax - x + data.offsetX) * translateMix;
        y += (target.ay - y + data.offsetY) * translateMix;
      }

      var scaleX = bone.ascaleX;
      var scaleY = bone.ascaleY;
      if (scaleMix > 0.0) {
        if (scaleX > 0.00001) {
          scaleX = (scaleX + (target.ascaleX - scaleX + data.offsetScaleX) * scaleMix) / scaleX;
        }
        if (scaleY > 0.00001) {
          scaleY = (scaleY + (target.ascaleY - scaleY + data.offsetScaleY) * scaleMix) / scaleY;
        }
      }

      final shearY = bone.ashearY;
      if (shearMix > 0.0) {
        final r = target.ashearY - shearY + data.offsetShearY;
        bone.shearY += _wrapRotation(r) * shearMix;
      }

      bone.updateWorldTransformWith(x, y, rotation, scaleX, scaleY, bone.ashearX, shearY);
    }
  }

  void _applyRelativeLocal() {
    final rotateMix = this.rotateMix;
    final translateMix = this.translateMix;
    final scaleMix = this.scaleMix;
    final shearMix = this.shearMix;
    final target = this.target;
    if (!target.appliedValid) target._updateAppliedTransform();
    final bones = this.bones;

    for (var i = 0; i < bones.length; i++) {
      final bone = bones[i];
      if (!bone.appliedValid) bone._updateAppliedTransform();

      var rotation = bone.arotation;
      if (rotateMix != 0.0) {
        rotation += (target.arotation + data.offsetRotation) * rotateMix;
      }

      var x = bone.ax;
      var y = bone.ay;
      if (translateMix != 0.0) {
        x += (target.ax + data.offsetX) * translateMix;
        y += (target.ay + data.offsetY) * translateMix;
      }

      var scaleX = bone.ascaleX;
      var scaleY = bone.ascaleY;
      if (scaleMix > 0.0) {
        if (scaleX > 0.00001) {
          scaleX *= ((target.ascaleX - 1 + data.offsetScaleX) * scaleMix) + 1;
        }
        if (scaleY > 0.00001) {
          scaleY *= ((target.ascaleY - 1 + data.offsetScaleY) * scaleMix) + 1;
        }
      }

      var shearY = bone.ashearY;
      if (shearMix > 0.0) {
        shearY += (target.ashearY + data.offsetShearY) * shearMix;
      }

      bone.updateWorldTransformWith(x, y, rotation, scaleX, scaleY, bone.ashearX, shearY);
    }
  }

  @override
  int getOrder() => data.order;

  @override
  String toString() => data.name;
}
