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
  final stage = Stage(canvas, width: 400, height: 500);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  // load "hero" skeleton resources

  final resourceManager = ResourceManager();
  const libgdx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('hero', 'spine/hero.json');
  resourceManager.addTextureAtlas('hero', 'spine/hero.atlas', libgdx);
  await resourceManager.load();

  // Add TextField to show user information

  final textField = TextField();
  textField.defaultTextFormat = TextFormat('Arial', 24, Color.White);
  textField.defaultTextFormat.align = TextFormatAlign.CENTER;
  textField.width = 400;
  textField.x = 0;
  textField.y = 450;
  textField.text = 'tap to change animation';
  textField.addTo(stage);

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('hero');
  final textureAtlas = resourceManager.getTextureAtlas('hero');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);

  // configure Spine animation mix

  final animationStateData = AnimationStateData(skeletonData);
  animationStateData.setMixByName('idle', 'walk', 0.2);
  animationStateData.setMixByName('walk', 'run', 0.2);
  animationStateData.setMixByName('run', 'attack', 0.2);
  animationStateData.setMixByName('attack', 'crouch', 0.2);
  animationStateData.setMixByName('crouch', 'idle', 0.2);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 180;
  skeletonAnimation.y = 400;
  skeletonAnimation.state.setAnimationByName(0, 'idle', true);
  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);

  // change the animation on every mouse click

  final animations = ['idle', 'walk', 'run', 'attack', 'crouch'];
  var animationIndex = 0;

  stage.onMouseClick.listen((me) {
    animationIndex = (animationIndex + 1) % animations.length;
    skeletonAnimation.state.setAnimationByName(0, animations[animationIndex], true);
  });

  // register track events

  skeletonAnimation.state.onTrackStart.listen((e) {
    print('${e.trackEntry.trackIndex} start: ${e.trackEntry}');
  });

  skeletonAnimation.state.onTrackEnd.listen((e) {
    print('${e.trackEntry.trackIndex} end: ${e.trackEntry}');
  });

  skeletonAnimation.state.onTrackComplete.listen((e) {
    print('${e.trackEntry.trackIndex} complete: ${e.trackEntry}');
  });

  skeletonAnimation.state.onTrackEvent.listen((e) {
    final ev = e.event;
    final text = '${ev.data.name}: ${ev.intValue}, ${ev.floatValue}, ${ev.stringValue}';
    print('${e.trackEntry.trackIndex} event: ${e.trackEntry}, $text');
  });
}
