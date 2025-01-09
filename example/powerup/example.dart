import 'dart:async';
import 'package:web/web.dart';
import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';

Future<void> main() async {
  // configure StageXL default options

  StageXL.stageOptions.renderEngine = RenderEngine.WebGL;
  StageXL.stageOptions.backgroundColor = Color.DarkSlateGray;

  // init Stage and RenderLoop

  var canvas = document.querySelector('#stage')! as HTMLCanvasElement;
  var stage = Stage(canvas, width: 600, height: 400);
  var renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "powerup" skeleton resources

  var resourceManager = ResourceManager();
  var libgdx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('powerup', 'spine/powerup-pro.json');
  resourceManager.addTextureAtlas('powerup', 'spine/powerup-pro.atlas', libgdx);
  await resourceManager.load();

  // load Spine skeleton

  var spineJson = resourceManager.getTextFile('powerup');
  var textureAtlas = resourceManager.getTextureAtlas('powerup');
  var attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  var skeletonLoader = SkeletonLoader(attachmentLoader);
  var skeletonData = skeletonLoader.readSkeletonData(spineJson);
  var animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  var skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 300;
  skeletonAnimation.y = 320;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.7;
  skeletonAnimation.state.setAnimationByName(0, 'bounce', true);
  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
