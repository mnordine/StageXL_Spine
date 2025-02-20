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
  final stage = Stage(canvas, width: 1600, height: 800);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "raptor" skeleton resources

  final resourceManager = ResourceManager();
  const format = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('stretchyman', 'spine/stretchyman.json');
  resourceManager.addTextureAtlas('stretchyman', 'spine/stretchyman.atlas', format);
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('stretchyman');
  final textureAtlas = resourceManager.getTextureAtlas('stretchyman');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 200;
  skeletonAnimation.y = 700;
  //skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.5;
  skeletonAnimation.state.setAnimationByName(0, 'sneak', true);

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
