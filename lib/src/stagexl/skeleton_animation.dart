part of '../../stagexl_spine.dart';

class SkeletonAnimation extends SkeletonDisplayObject implements Animatable {
  final AnimationState state;
  double timeScale = 1;

  SkeletonAnimation(super.skeletonData, [AnimationStateData? stateData])
      : state = AnimationState(stateData ?? AnimationStateData(skeletonData));

  @override
  bool advanceTime(num time) {
    final timeScaled = time * timeScale;
    skeleton.update(timeScaled);
    state.update(timeScaled);
    state.apply(skeleton);
    skeleton.updateWorldTransform();
    return true;
  }
}
