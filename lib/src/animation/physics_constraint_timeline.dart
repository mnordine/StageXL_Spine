part of '../../stagexl_spine.dart';

enum PhysicsConstraintProperty {
  inertia,
  strength,
  damping,
  mass,
  wind,
  gravity,
  mix,
}

class PhysicsConstraintTimeline extends CurveTimeline {
  static const _entries = 2;
  static const _prevTime = -2;
  static const _prevValue = -1;
  static const _time = 0;
  static const _value = 1;

  final Float32List frames;
  final PhysicsConstraintProperty property;
  int physicsConstraintIndex;

  PhysicsConstraintTimeline(super.frameCount, this.property, this.physicsConstraintIndex)
      : frames = Float32List(frameCount * _entries);

  @override
  int getPropertyId() =>
      (TimelineType.physicsConstraint.ordinal << 24) + (property.index << 16) + physicsConstraintIndex;

  void setFrame(int frameIndex, double time, double value) {
    frameIndex *= _entries;
    frames[frameIndex + _time] = time;
    frames[frameIndex + _value] = value;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    if (physicsConstraintIndex < 0) {
      for (final constraint in skeleton.physicsConstraints) {
        if (_usesGlobalValue(constraint.data) == false) continue;
        final value = _getValue(time, _setupValue(constraint.data.setupPose));
        _applyPoseValue(constraint.pose, value, alpha, pose);
      }
      return;
    }

    final constraint = skeleton.physicsConstraints[physicsConstraintIndex];
    final value = _getValue(time, _setupValue(constraint.data.setupPose));
    _applyPoseValue(constraint.pose, value, alpha, pose);
  }

  double _getValue(double time, double setup) {
    if (time < frames[0]) return setup;
    if (time >= frames[frames.length + _prevTime]) return frames[frames.length + _prevValue];

    final frame = Animation.binarySearch(frames, time, _entries);
    final t0 = frames[frame + _prevTime];
    final v0 = frames[frame + _prevValue];
    final t1 = frames[frame + _time];
    final v1 = frames[frame + _value];
    return getCurveValue(frame ~/ _entries - 1, 0, time, t0, v0, t1, v1);
  }

  double _setupValue(PhysicsConstraintPose setup) {
    switch (property) {
      case PhysicsConstraintProperty.inertia:
        return setup.inertia;
      case PhysicsConstraintProperty.strength:
        return setup.strength;
      case PhysicsConstraintProperty.damping:
        return setup.damping;
      case PhysicsConstraintProperty.mass:
        return 1 / setup.massInverse;
      case PhysicsConstraintProperty.wind:
        return setup.wind;
      case PhysicsConstraintProperty.gravity:
        return setup.gravity;
      case PhysicsConstraintProperty.mix:
        return setup.mix;
    }
  }

  void _applyPoseValue(PhysicsConstraintPose target, double value, double alpha, MixPose pose) {
    switch (property) {
      case PhysicsConstraintProperty.inertia:
        target.inertia = _mixValue(target.inertia, value, alpha, pose);
      case PhysicsConstraintProperty.strength:
        target.strength = _mixValue(target.strength, value, alpha, pose);
      case PhysicsConstraintProperty.damping:
        target.damping = _mixValue(target.damping, value, alpha, pose);
      case PhysicsConstraintProperty.mass:
        final mass = _mixValue(1 / target.massInverse, value, alpha, pose);
        target.massInverse = mass == 0 ? 0 : 1 / mass;
      case PhysicsConstraintProperty.wind:
        target.wind = _mixValue(target.wind, value, alpha, pose);
      case PhysicsConstraintProperty.gravity:
        target.gravity = _mixValue(target.gravity, value, alpha, pose);
      case PhysicsConstraintProperty.mix:
        target.mix = _mixValue(target.mix, value, alpha, pose);
    }
  }

  bool _usesGlobalValue(PhysicsConstraintData data) {
    switch (property) {
      case PhysicsConstraintProperty.inertia:
        return data.inertiaGlobal;
      case PhysicsConstraintProperty.strength:
        return data.strengthGlobal;
      case PhysicsConstraintProperty.damping:
        return data.dampingGlobal;
      case PhysicsConstraintProperty.mass:
        return data.massGlobal;
      case PhysicsConstraintProperty.wind:
        return data.windGlobal;
      case PhysicsConstraintProperty.gravity:
        return data.gravityGlobal;
      case PhysicsConstraintProperty.mix:
        return data.mixGlobal;
    }
  }

  double _mixValue(double current, double value, double alpha, MixPose pose) =>
      pose == MixPose.setup ? value * alpha : current + (value - current) * alpha;
}

class PhysicsConstraintResetTimeline implements Timeline {
  final Float32List frames;
  int physicsConstraintIndex;

  PhysicsConstraintResetTimeline(int frameCount, this.physicsConstraintIndex)
      : frames = Float32List(frameCount);

  int get frameCount => frames.length;

  void setFrame(int frameIndex, double time) {
    frames[frameIndex] = time;
  }

  @override
  int getPropertyId() => (TimelineType.physicsConstraint.ordinal << 24) + (7 << 16) + physicsConstraintIndex;

  @override
  void apply(Skeleton skeleton, double lastTime, double time, List<SpineEvent>? firedEvents,
      double alpha, MixPose pose, MixDirection direction) {
    if (frames.isEmpty || lastTime > time) {
      apply(skeleton, lastTime, double.infinity, firedEvents, alpha, pose, direction);
      lastTime = -1;
    }

    if (lastTime >= frames[frames.length - 1]) return;
    final frame = time < frames[0] ? -1 : Animation.binarySearch1(frames, time) - 1;
    if (frame == -1 || frames[frame] <= lastTime) return;

    if (physicsConstraintIndex < 0) {
      for (final constraint in skeleton.physicsConstraints) {
        constraint.reset(skeleton);
      }
    } else {
      skeleton.physicsConstraints[physicsConstraintIndex].reset(skeleton);
    }
  }
}
