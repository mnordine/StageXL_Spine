import 'dart:async';
import 'dart:math' as math;
import 'package:web/web.dart';
import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';

Future<void> main() async {
  // configure StageXL default options

  StageXL.stageOptions.renderEngine = RenderEngine.WebGL;
  StageXL.stageOptions.backgroundColor = Color.DarkSlateGray;

  // init Stage and RenderLoop

  final canvas = document.querySelector('#stage')! as HTMLCanvasElement;
  final stage = Stage(canvas, width: 1300, height: 1100);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);
  stage.console?.visible = true;
  stage.console?.alpha = 0.75;

  // load "raptor" skeleton resources

  final resourceManager = ResourceManager();
  //var libgdx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('raptor', 'spine/raptor.json');
  //resourceManager.addTextureAtlas("raptor", "atlas1/raptor.atlas", libgdx);
  //resourceManager.addTextureAtlas("raptor", "atlas2/raptor.json");
  resourceManager.addTextureAtlas('raptor', 'atlas3/raptor.json');
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('raptor');
  final textureAtlas = resourceManager.getTextureAtlas('raptor');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 600;
  skeletonAnimation.y = 1000;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.8;
  skeletonAnimation.state.setAnimationByName(0, 'walk', true);

  stage.onMouseClick.listen((me) {
    final state = skeletonAnimation.state;
    final roarAnimation = state.setAnimationByName(0, 'roar', false);
    roarAnimation.mixDuration = 0.25;
    roarAnimation.onTrackComplete.first.then((_) {
      final walkAnimation = state.setAnimationByName(0, 'walk', true);
      walkAnimation.mixDuration = 1.0;
    });
  });

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
  stage.juggler.onElapsedTimeChange.listen((time) {
    skeletonAnimation.timeScale = 0.7 + 0.5 * math.sin(time / 2);
  });
}
