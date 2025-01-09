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
  final stage = Stage(canvas, width: 600, height: 1000);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "raptor" skeleton resources

  final resourceManager = ResourceManager();
  const libgdx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('vine', 'spine/vine.json');
  resourceManager.addTextureAtlas('vine', 'spine/vine.atlas', libgdx);
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('vine');
  final textureAtlas = resourceManager.getTextureAtlas('vine');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 300;
  skeletonAnimation.y = 950;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.8;
  skeletonAnimation.state.setAnimationByName(0, 'grow', true);

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
