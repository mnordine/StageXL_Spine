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
  final stage = Stage(canvas, width: 2000, height: 800);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "raptor" skeleton resources

  final resourceManager = ResourceManager();
  const format = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('tank', 'spine/tank.json');
  resourceManager.addTextureAtlas('tank', 'spine/tank.atlas', format);
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('tank');
  final textureAtlas = resourceManager.getTextureAtlas('tank');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 2300;
  skeletonAnimation.y = 700;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.5;
  skeletonAnimation.state.setAnimationByName(0, 'drive', true);

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
