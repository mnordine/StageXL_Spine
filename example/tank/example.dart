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
  var stage = Stage(canvas, width: 2000, height: 800);
  var renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "raptor" skeleton resources

  var resourceManager = ResourceManager();
  var format = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile("tank", "spine/tank.json");
  resourceManager.addTextureAtlas("tank", "spine/tank.atlas", format);
  await resourceManager.load();

  // load Spine skeleton

  var spineJson = resourceManager.getTextFile("tank");
  var textureAtlas = resourceManager.getTextureAtlas("tank");
  var attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  var skeletonLoader = SkeletonLoader(attachmentLoader);
  var skeletonData = skeletonLoader.readSkeletonData(spineJson);
  var animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  var skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 2300;
  skeletonAnimation.y = 700;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.5;
  skeletonAnimation.state.setAnimationByName(0, "drive", true);

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}
