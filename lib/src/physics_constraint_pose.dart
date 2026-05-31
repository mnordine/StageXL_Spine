part of '../stagexl_spine.dart';

class PhysicsConstraintPose {
  double inertia = 0.5;
  double strength = 100;
  double damping = 0.85;
  double massInverse = 1;
  double wind = 0;
  double gravity = 0;
  double mix = 1;

  void set(PhysicsConstraintPose pose) {
    inertia = pose.inertia;
    strength = pose.strength;
    damping = pose.damping;
    massInverse = pose.massInverse;
    wind = pose.wind;
    gravity = pose.gravity;
    mix = pose.mix;
  }
}
