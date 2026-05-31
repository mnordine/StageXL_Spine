part of '../stagexl_spine.dart';

enum Physics {
  none,
  reset,
  update,
  pose,
}

enum ScaleYMode {
  none,
  uniform,
  volume,
}

ScaleYMode _readScaleYMode(String? value) {
  switch (value) {
    case 'uniform':
      return ScaleYMode.uniform;
    case 'volume':
      return ScaleYMode.volume;
    default:
      return ScaleYMode.none;
  }
}
