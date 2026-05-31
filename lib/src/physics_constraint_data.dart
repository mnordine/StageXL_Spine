part of '../stagexl_spine.dart';

class PhysicsConstraintData {
  final String name;

  int order = 0;
  late BoneData bone;

  double x = 0;
  double y = 0;
  double rotate = 0;
  double scaleX = 0;
  double shearX = 0;
  double limit = 5000;
  double step = 1 / 60;
  ScaleYMode scaleYMode = ScaleYMode.none;

  bool inertiaGlobal = false;
  bool strengthGlobal = false;
  bool dampingGlobal = false;
  bool massGlobal = false;
  bool windGlobal = false;
  bool gravityGlobal = false;
  bool mixGlobal = false;

  final PhysicsConstraintPose setupPose = PhysicsConstraintPose();

  PhysicsConstraintData(this.name);
}
