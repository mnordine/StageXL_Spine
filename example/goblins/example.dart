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
  final stage = Stage(canvas, width: 480, height: 600);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "goblins-ffd" skeleton resources

  final resourceManager = ResourceManager();
  const libgdx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('goblins', 'spine/goblins.json');
  resourceManager.addTextureAtlas('goblins', 'spine/goblins.atlas', libgdx);
  await resourceManager.load();

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('goblins');
  final textureAtlas = resourceManager.getTextureAtlas('goblins');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);
  final animationStateData = AnimationStateData(skeletonData);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 240;
  skeletonAnimation.y = 560;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 1.5;
  skeletonAnimation.state.setAnimationByName(0, 'walk', true);
  skeletonAnimation.skeleton.skinName = 'goblin';
  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);

  // feature: change the skin used for the skeleton

  //skeletonAnimation.skeleton.skinName = "goblin";
  //skeletonAnimation.skeleton.skinName = "goblingirl";

  // feature: change the attachments assigned to slots

  //skeletonAnimation.skeleton.setAttachment("left hand item", "dagger");
  //skeletonAnimation.skeleton.setAttachment("right hand item", null);
  //skeletonAnimation.skeleton.setAttachment("right hand item 2", null);
}
