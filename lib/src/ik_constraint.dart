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

class IkConstraint implements Constraint {
  final List<Bone> bones = [];
  final IkConstraintData data;
  final Bone target;

  double mix = 1;
  int bendDirection = 0;

  IkConstraint(this.data, Skeleton skeleton) : target = skeleton.findBone(data.target.name)! {
    mix = data.mix;
    bendDirection = data.bendDirection;

    for (final boneData in data.bones) {
      final bone = skeleton.findBone(boneData.name);
      if (bone != null) bones.add(bone);
    }
  }

  void apply() {
    update();
  }

  @override
  void update() {
    if (bones.length == 1) {
      apply1(bones[0], target.worldX, target.worldY, mix);
    } else if (bones.length == 2) {
      apply2(bones[0], bones[1], target.worldX, target.worldY, bendDirection, mix);
    }
  }

  @override
  int getOrder() => data.order;

  @override
  String toString() => data.name;

  /// Adjusts the bone rotation so the tip is as close to the target position
  /// as possible. The target is specified in the world coordinate system.
  static void apply1(Bone bone, double targetX, double targetY, double alpha) {
    if (!bone.appliedValid) bone._updateAppliedTransform();
    final p = bone.parent!;
    const rad2deg = 180.0 / math.pi;
    final id = 1.0 / (p.a * p.d - p.b * p.c);
    final x = targetX - p.worldX;
    final y = targetY - p.worldY;
    final tx = (x * p.d - y * p.b) * id - bone.ax;
    final ty = (y * p.a - x * p.c) * id - bone.ay;
    var rotationIK = math.atan2(ty, tx) * rad2deg - bone.ashearX - bone.arotation;
    if (bone.ascaleX < 0.0) rotationIK += 180.0;
    if (rotationIK > 180.0) rotationIK -= 360.0;
    if (rotationIK < -180.0) rotationIK += 360.0;
    bone.updateWorldTransformWith(bone.ax, bone.ay, bone.arotation + rotationIK * alpha,
        bone.ascaleX, bone.ascaleY, bone.ashearX, bone.ashearY);
  }

  /// Adjusts the parent and child bone rotations so the tip of the
  /// child is as close to the target position as possible. The target
  /// is specified in the world coordinate system.
  ///
  /// [child] Any descendant bone of the parent.

  static void apply2(
      Bone parent, Bone child, double targetX, double targetY, int bendDir, double alpha) {
    if (alpha == 0) {
      child.updateWorldTransform();
      return;
    }
    if (!parent.appliedValid) parent._updateAppliedTransform();
    if (!child.appliedValid) child._updateAppliedTransform();

    final px = parent.ax;
    final py = parent.ay;
    var psx = parent.ascaleX;
    var psy = parent.ascaleY;
    var csx = child.ascaleX;
    var os1 = 0, os2 = 0, s2 = 0;

    if (psx < 0) {
      psx = -psx;
      os1 = 180;
      s2 = -1;
    } else {
      os1 = 0;
      s2 = 1;
    }

    if (psy < 0) {
      psy = -psy;
      s2 = -s2;
    }

    if (csx < 0) {
      csx = -csx;
      os2 = 180;
    } else {
      os2 = 0;
    }

    final cx = child.ax;
    double cy = 0;
    double cwx = 0;
    double cwy = 0;
    var a = parent.a;
    var b = parent.b;
    var c = parent.c;
    var d = parent.d;

    final u = (psx - psy).abs() <= 0.0001;
    if (!u) {
      cy = 0.0;
      cwx = a * cx + parent.worldX;
      cwy = c * cx + parent.worldY;
    } else {
      cy = child.ay;
      cwx = a * cx + b * cy + parent.worldX;
      cwy = c * cx + d * cy + parent.worldY;
    }

    final pp = parent.parent!;
    a = pp.a;
    b = pp.b;
    c = pp.c;
    d = pp.d;
    final id = 1.0 / (a * d - b * c);
    var x = targetX - pp.worldX;
    var y = targetY - pp.worldY;
    final tx = (x * d - y * b) * id - px;
    final ty = (y * a - x * c) * id - py;
    x = cwx - pp.worldX;
    y = cwy - pp.worldY;
    final dx = (x * d - y * b) * id - px;
    final dy = (y * a - x * c) * id - py;
    final l1 = math.sqrt(dx * dx + dy * dy);
    var l2 = child.data.length * csx;
    double a1 = 0;
    double a2 = 0;

    outer:
    if (u) {
      l2 *= psx;
      var cos = (tx * tx + ty * ty - l1 * l1 - l2 * l2) / (2 * l1 * l2);
      if (cos < -1.0) {
        cos = -1.0; 
      } else if (cos > 1.0) { 
        cos = 1.0; 
      }
      a2 = math.acos(cos) * bendDir;
      a = l1 + l2 * cos;
      b = l2 * math.sin(a2);
      a1 = math.atan2(ty * a - tx * b, tx * a + ty * b);
    } else {
      a = psx * l2;
      b = psy * l2;
      final aa = a * a;
      final bb = b * b;
      final dd = tx * tx + ty * ty;
      final ta = math.atan2(ty, tx);
      c = bb * l1 * l1 + aa * dd - aa * bb;
      final c1 = -2 * bb * l1;
      final c2 = bb - aa;
      d = c1 * c1 - 4 * c2 * c;
      if (d >= 0) {
        var q = math.sqrt(d);
        if (c1 < 0) q = -q;
        q = -(c1 + q) / 2;
        final r0 = q / c2;
        final r1 = c / q;
        final r = r0.abs() < r1.abs() ? r0 : r1;
        if (r * r <= dd) {
          y = math.sqrt(dd - r * r) * bendDir;
          a1 = ta - math.atan2(y, r);
          a2 = math.atan2(y / psy, (r - l1) / psx);
          break outer;
        }
      }

      var minAngle = math.pi;
      var minX = l1 - a;
      var minDist = minX * minX;
      double minY = 0;
      double maxAngle = 0;
      var maxX = l1 + a;
      var maxDist = maxX * maxX;
      double maxY = 0;

      c = -a * l1 / (aa - bb);
      if (c >= -1.0 && c <= 1.0) {
        c = math.acos(c);
        x = a * math.cos(c) + l1;
        y = b * math.sin(c);
        d = x * x + y * y;
        if (d < minDist) {
          minAngle = c;
          minDist = d;
          minX = x;
          minY = y;
        }
        if (d > maxDist) {
          maxAngle = c;
          maxDist = d;
          maxX = x;
          maxY = y;
        }
      }

      if (dd <= (minDist + maxDist) / 2) {
        a1 = ta - math.atan2(minY * bendDir, minX);
        a2 = minAngle * bendDir;
      } else {
        a1 = ta - math.atan2(maxY * bendDir, maxX);
        a2 = maxAngle * bendDir;
      }
    }

    final os = math.atan2(cy, cx) * s2;
    var rotation = parent.arotation;
    a1 = _wrapRotation(_toDeg(a1 - os) + os1 - rotation);
    parent.updateWorldTransformWith(
        px, py, rotation + a1 * alpha, parent.ascaleX, parent.ascaleY, 0, 0);
    rotation = child.arotation;
    a2 = _wrapRotation((_toDeg(a2 + os) - child.ashearX) * s2 + os2 - rotation);
    child.updateWorldTransformWith(
        cx, cy, rotation + a2 * alpha, child.ascaleX, child.ascaleY, child.ashearX, child.ashearY);
  }
}
