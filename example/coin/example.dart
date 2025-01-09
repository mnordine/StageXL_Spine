import 'dart:async';
import 'package:web/web.dart';
import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';

Future<void> main() async {
  // configure StageXL default options

  StageXL.stageOptions.renderEngine = RenderEngine.WebGL;
  StageXL.stageOptions.backgroundColor = Color.DarkSlateGray;

  // init Stage and RenderLoop

  final canvas = document.querySelector('#stage')! as HTMLCanvasElement;
  final stage = Stage(canvas, width: 600, height: 600);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "raptor" skeleton resources

  final resourceManager = ResourceManager();
  const format = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('coin', 'spine/coin.json');
  resourceManager.addTextureAtlas('coin', 'spine/coin.atlas', format);
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('coin');
  final textureAtlas = resourceManager.getTextureAtlas('coin');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 300;
  skeletonAnimation.y = 600;
  skeletonAnimation.state.setAnimationByName(0, 'rotate', true);

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
