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
  final stage = Stage(canvas, width: 600, height: 400);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "powerup" skeleton resources

  final resourceManager = ResourceManager();
  const libgdx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('powerup', 'spine/powerup-pro.json');
  resourceManager.addTextureAtlas('powerup', 'spine/powerup-pro.atlas', libgdx);
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('powerup');
  final textureAtlas = resourceManager.getTextureAtlas('powerup');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 300;
  skeletonAnimation.y = 320;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.7;
  skeletonAnimation.state.setAnimationByName(0, 'bounce', true);
  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
