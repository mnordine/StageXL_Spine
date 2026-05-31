part of '../stagexl_spine.dart';

class PhysicsConstraint extends Constraint {
  final PhysicsConstraintData data;
  final PhysicsConstraintPose pose = PhysicsConstraintPose();
  final Bone bone;

  bool _reset = true;
  double ux = 0;
  double uy = 0;
  double cx = 0;
  double cy = 0;
  double tx = 0;
  double ty = 0;
  double xOffset = 0;
  double xLag = 0;
  double xVelocity = 0;
  double yOffset = 0;
  double yLag = 0;
  double yVelocity = 0;
  double rotateOffset = 0;
  double rotateLag = 0;
  double rotateVelocity = 0;
  double scaleOffset = 0;
  double scaleLag = 0;
  double scaleVelocity = 0;
  double remaining = 0;
  double lastTime = 0;

  PhysicsConstraint(this.data, Skeleton skeleton)
      : bone = skeleton.bones[data.bone.index] {
    pose.set(data.setupPose);
  }

  @override
  int getOrder() => data.order;

  @override
  void update() {
    updatePhysics(Physics.update);
  }

  void reset(Skeleton skeleton) {
    remaining = 0;
    lastTime = skeleton.time;
    _reset = true;
    xOffset = 0;
    xLag = 0;
    xVelocity = 0;
    yOffset = 0;
    yLag = 0;
    yVelocity = 0;
    rotateOffset = 0;
    rotateLag = 0;
    rotateVelocity = 0;
    scaleOffset = 0;
    scaleLag = 0;
    scaleVelocity = 0;
  }

  void translate(double x, double y) {
    ux -= x;
    uy -= y;
    cx -= x;
    cy -= y;
  }

  void rotate(double x, double y, double degrees) {
    final r = degrees * math.pi / 180;
    final cos = math.cos(r);
    final sin = math.sin(r);
    final dx = cx - x;
    final dy = cy - y;
    translate(dx * cos - dy * sin - dx, dx * sin + dy * cos - dy);
  }

  void updatePhysics(Physics physics) {
    final mix = pose.mix;
    if (mix == 0) return;

    final applyX = data.x > 0;
    final applyY = data.y > 0;
    final rotateOrShearX = data.rotate > 0 || data.shearX > 0;
    final applyScaleX = data.scaleX > 0;
    final length = bone.data.length;
    final step = data.step;
    var z = 0.0;

    switch (physics) {
      case Physics.none:
        return;
      case Physics.reset:
        reset(bone.skeleton);
        z = _update(physics, applyX, applyY, rotateOrShearX, applyScaleX, length, step, mix, z);
      case Physics.update:
        z = _update(physics, applyX, applyY, rotateOrShearX, applyScaleX, length, step, mix, z);
      case Physics.pose:
        z = math.max(0, 1 - remaining / step);
        if (applyX) bone._worldX += (xOffset - xLag * z) * mix * data.x;
        if (applyY) bone._worldY += (yOffset - yLag * z) * mix * data.y;
    }

    _applyRotationAndScale(physics, rotateOrShearX, applyScaleX, length, mix, z);
    bone._updateAppliedTransform();
  }

  double _update(Physics physics, bool applyX, bool applyY, bool rotateOrShearX, bool applyScaleX,
      double length, double step, double mix, double z) {
    final skeleton = bone.skeleton;
    final delta = math.max(skeleton.time - lastTime, 0);
    final previousRemaining = remaining;
    remaining += delta;
    lastTime = skeleton.time;

    final bx = bone.worldX;
    final by = bone.worldY;
    if (_reset) {
      _reset = false;
      ux = bx;
      uy = by;
    } else {
      var a = remaining;
      final inertia = pose.inertia;
      final referenceScale = skeleton.data.referenceScale;
      var damping = -1.0;
      var mass = 0.0;
      var strength = 0.0;
      final qx = data.limit * delta * skeleton.scaleX.abs();
      final qy = data.limit * delta * skeleton.scaleY.abs();

      if (applyX || applyY) {
        if (applyX) {
          final u = (ux - bx) * inertia;
          xOffset += u > qx ? qx : u < -qx ? -qx : u;
          ux = bx;
        }
        if (applyY) {
          final u = (uy - by) * inertia;
          yOffset += u > qy ? qy : u < -qy ? -qy : u;
          uy = by;
        }
        if (a >= step) {
          final xs = xOffset;
          final ys = yOffset;
          damping = math.pow(pose.damping, 60 * step).toDouble();
          mass = step * pose.massInverse;
          strength = pose.strength;
          final wind = referenceScale * pose.wind;
          final gravity = referenceScale * pose.gravity;
          final ax = (wind * skeleton.windX + gravity * skeleton.gravityX) * skeleton.scaleX;
          final ay = (wind * skeleton.windY + gravity * skeleton.gravityY) * skeleton.scaleY;
          do {
            if (applyX) {
              xVelocity += (ax - xOffset * strength) * mass;
              xOffset += xVelocity * step;
              xVelocity *= damping;
            }
            if (applyY) {
              yVelocity -= (ay + yOffset * strength) * mass;
              yOffset += yVelocity * step;
              yVelocity *= damping;
            }
            a -= step;
          } while (a >= step);
          xLag = xOffset - xs;
          yLag = yOffset - ys;
        }
        z = math.max(0, 1 - a / step);
        if (applyX) bone._worldX += (xOffset - xLag * z) * mix * data.x;
        if (applyY) bone._worldY += (yOffset - yLag * z) * mix * data.y;
      }

      if (rotateOrShearX || applyScaleX) {
        final ca = math.atan2(bone.c, bone.a);
        var c = 0.0;
        var s = 0.0;
        var mixedRotate = 0.0;
        var dx = cx - bone.worldX;
        var dy = cy - bone.worldY;
        if (dx > qx) dx = qx;
        if (dx < -qx) dx = -qx;
        if (dy > qy) dy = qy;
        if (dy < -qy) dy = -qy;
        a = remaining;
        if (rotateOrShearX) {
          mixedRotate = (data.rotate + data.shearX) * mix;
          z = rotateLag * math.max(0, 1 - previousRemaining / step);
          var r = math.atan2(dy + ty, dx + tx) - ca - (rotateOffset - z) * mixedRotate;
          rotateOffset += (r - (r * 0.5 / math.pi - 0.5).ceil() * math.pi * 2) * inertia;
          r = (rotateOffset - z) * mixedRotate + ca;
          c = math.cos(r);
          s = math.sin(r);
          if (applyScaleX) {
            r = length * bone.worldScaleX;
            if (r > 0) scaleOffset += (dx * c + dy * s) * inertia / r;
          }
        } else {
          c = math.cos(ca);
          s = math.sin(ca);
          final r = length * bone.worldScaleX - scaleLag * math.max(0, 1 - previousRemaining / step);
          if (r > 0) scaleOffset += (dx * c + dy * s) * inertia / r;
        }
        if (a >= step) {
          if (damping == -1) {
            damping = math.pow(pose.damping, 60 * step).toDouble();
            mass = step * pose.massInverse;
            strength = pose.strength;
          }
          final ax = pose.wind * skeleton.windX + pose.gravity * skeleton.gravityX;
          final ay = pose.wind * skeleton.windY + pose.gravity * skeleton.gravityY;
          final rotateStart = rotateOffset;
          final scaleStart = scaleOffset;
          final h = length / referenceScale;
          for (;;) {
            a -= step;
            if (applyScaleX) {
              scaleVelocity += (ax * c - ay * s - scaleOffset * strength) * mass;
              scaleOffset += scaleVelocity * step;
              scaleVelocity *= damping;
            }
            if (rotateOrShearX) {
              rotateVelocity -= ((ax * s + ay * c) * h + rotateOffset * strength) * mass;
              rotateOffset += rotateVelocity * step;
              rotateVelocity *= damping;
              if (a < step) break;
              final r = rotateOffset * mixedRotate + ca;
              c = math.cos(r);
              s = math.sin(r);
            } else if (a < step) {
              break;
            }
          }
          rotateLag = rotateOffset - rotateStart;
          scaleLag = scaleOffset - scaleStart;
        }
        z = math.max(0, 1 - a / step);
      }
      remaining = a;
    }
    cx = bone.worldX;
    cy = bone.worldY;
    return z;
  }

  void _applyRotationAndScale(Physics physics, bool rotateOrShearX, bool applyScaleX, double length,
      double mix, double z) {
    if (rotateOrShearX) {
      var offset = (rotateOffset - rotateLag * z) * mix;
      if (data.shearX > 0) {
        var r = 0.0;
        if (data.rotate > 0) {
          r = offset * data.rotate;
          final s = math.sin(r);
          final c = math.cos(r);
          final a = bone.b;
          bone._b = c * a - s * bone.d;
          bone._d = s * a + c * bone.d;
        }
        r += offset * data.shearX;
        final s = math.sin(r);
        final c = math.cos(r);
        final a = bone.a;
        bone._a = c * a - s * bone.c;
        bone._c = s * a + c * bone.c;
      } else {
        offset *= data.rotate;
        final s = math.sin(offset);
        final c = math.cos(offset);
        var a = bone.a;
        bone._a = c * a - s * bone.c;
        bone._c = s * a + c * bone.c;
        a = bone.b;
        bone._b = c * a - s * bone.d;
        bone._d = s * a + c * bone.d;
      }
    }
    if (applyScaleX) {
      var scale = 1 + (scaleOffset - scaleLag * z) * mix * data.scaleX;
      bone._a *= scale;
      bone._c *= scale;
      switch (data.scaleYMode) {
        case ScaleYMode.none:
          break;
        case ScaleYMode.uniform:
          bone._b *= scale;
          bone._d *= scale;
        case ScaleYMode.volume:
          scale = scale.abs();
          scale = scale >= 0.7 ? 1 / scale : 4 - 3.67347 * scale;
          bone._b *= scale;
          bone._d *= scale;
      }
    }
    if (physics != Physics.pose) {
      tx = length * bone.a;
      ty = length * bone.c;
    }
  }
}
