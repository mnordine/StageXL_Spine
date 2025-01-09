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

  // load "spineboy" skeleton resources

  final resourceManager = ResourceManager();
  const libgdxx = TextureAtlasFormat.libGdx;
  resourceManager.addTextFile('spineboy', 'spine/spineboy.json');
  resourceManager.addTextureAtlas('spineboy', 'spine/spineboy.atlas', libgdxx);
  await resourceManager.load();

  // add TextField to show user information

  final textField = TextField();
  textField.defaultTextFormat = TextFormat('Arial', 24, Color.White);
  textField.defaultTextFormat.align = TextFormatAlign.CENTER;
  textField.width = 480;
  textField.x = 0;
  textField.y = 550;
  textField.text = 'tap to change animation';
  textField.addTo(stage);

  // load Spine skeleton

  final spineJson = resourceManager.getTextFile('spineboy');
  final textureAtlas = resourceManager.getTextureAtlas('spineboy');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(spineJson);

  // configure Spine animation mix

  final animationStateData = AnimationStateData(skeletonData);
  animationStateData.setMixByName('portal', 'idle', 0.2);
  animationStateData.setMixByName('idle', 'walk', 0.2);
  animationStateData.setMixByName('walk', 'run', 0.2);
  animationStateData.setMixByName('run', 'walk', 0.2);
  animationStateData.setMixByName('walk', 'idle', 0.2);

  // create the display object showing the skeleton animation

  final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
  skeletonAnimation.x = 240;
  skeletonAnimation.y = 520;
  skeletonAnimation.scaleX = skeletonAnimation.scaleY = 0.7;
  skeletonAnimation.boundsCalculation = SkeletonBoundsCalculation.hull;

  final mouseContainer = Sprite();
  mouseContainer.addChild(skeletonAnimation);
  mouseContainer.mouseCursor = MouseCursor.CROSSHAIR;
  stage.juggler.add(skeletonAnimation);
  stage.addChild(mouseContainer);

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

  // start with the "portal" animation continue with the "idle" animation

  final portalAnimation = skeletonAnimation.state.setAnimationByName(0, 'portal', false);
  skeletonAnimation.state.addAnimationByName(0, 'idle', true, portalAnimation.animation.duration);
  await portalAnimation.onTrackComplete.first;

  // change the animation on every mouse click

  final animationNames = ['idle', 'idle', 'walk', 'run', 'walk'];
  final animationState = skeletonAnimation.state;
  var animationIndex = 0;

  stage.onMouseClick.listen((me) {
    animationIndex = (animationIndex + 1) % animationNames.length;
    if (animationIndex == 1) {
      animationState.setEmptyAnimation(1, 0);
      animationState.addAnimationByName(1, 'shoot', false, 0).mixDuration = 0.2;
      animationState.addEmptyAnimation(1, 0.2, 0.5);
    } else {
      final animationName = animationNames[animationIndex];
      animationState.setAnimationByName(0, animationName, true);
    }
  });
}
