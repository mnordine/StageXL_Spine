import 'dart:async';
import 'package:web/web.dart';
import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';

Future<void> main() async {
  // configure StageXL default options

  StageXL.stageOptions.renderEngine = RenderEngine.WebGL;
  StageXL.stageOptions.backgroundColor = Color.Azure;

  // init Stage and RenderLoop

  final canvas = document.querySelector('#stage')! as HTMLCanvasElement;
  final stage = Stage(canvas, width: 800, height: 400);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);
  stage.console?.visible = true;
  stage.console?.alpha = 0.75;

  // load "raptor" skeleton resources

  final resourceManager = ResourceManager();
  resourceManager.addTextureAtlas('combined', 'atlas/combined.json');
  resourceManager.addTextFile('goblins-spine', 'spine/goblins.json');
  resourceManager.addTextFile('goblins-atlas', 'spine/goblins.atlas');
  resourceManager.addTextFile('hero-spine', 'spine/hero.json');
  resourceManager.addTextFile('hero-atlas', 'spine/hero.atlas');
  resourceManager.addTextFile('raptor-spine', 'spine/raptor.json');
  resourceManager.addTextFile('raptor-atlas', 'spine/raptor.atlas');
  resourceManager.addTextFile('speedy-spine', 'spine/speedy.json');
  resourceManager.addTextFile('speedy-atlas', 'spine/speedy.atlas');
  resourceManager.addTextFile('spineboy-spine', 'spine/spineboy.json');
  resourceManager.addTextFile('spineboy-atlas', 'spine/spineboy.atlas');
  await resourceManager.load();

  //---------------------------------------------------------------------------
  // load Spine skeletons from combined texture and the individual definitions

  final names = ['goblins', 'hero', 'raptor', 'speedy', 'spineboy'];
  final skeletonAnimations = <SkeletonAnimation>[];

  for (final name in names) {
    // get spine texture atlases from combined texture atlas

    final bitmapData = resourceManager.getTextureAtlas('combined').getBitmapData(name);
    final spine = resourceManager.getTextFile('$name-spine');
    final atlas = resourceManager.getTextFile('$name-atlas');
    const format = TextureAtlasFormat.libGdx;
    final textureAtlas = await TextureAtlas.fromBitmapData(bitmapData, atlas, format);

    // create spine skeleton data

    final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
    final skeletonLoader = SkeletonLoader(attachmentLoader);
    final skeletonData = skeletonLoader.readSkeletonData(spine);

    // create spine skeleton animation

    final animationStateData = AnimationStateData(skeletonData);
    final skeletonAnimation = SkeletonAnimation(skeletonData, animationStateData);
    skeletonAnimations.add(skeletonAnimation);
  }

  //---------------------------------------------------------------------------
  // setup the skeleton animations

  skeletonAnimations[0] // goblins-mesh
    ..state.setAnimationByName(0, 'walk', true)
    ..skeleton.skinName = 'goblin'
    ..scaleX = 1.0
    ..scaleY = 1.0
    ..x = 150
    ..y = 320;

  skeletonAnimations[1] // hero-mesh
    ..state.setAnimationByName(0, 'walk', true)
    ..scaleX = 0.7
    ..scaleY = 0.7
    ..x = 260
    ..y = 390;

  skeletonAnimations[2] // raptor
    ..state.setAnimationByName(0, 'walk', true)
    ..scaleX = 0.28
    ..scaleY = 0.28
    ..x = 380
    ..y = 320;

  skeletonAnimations[3] // speedy
    ..state.setAnimationByName(0, 'run', true)
    ..scaleX = 0.65
    ..scaleY = 0.65
    ..x = 550
    ..y = 390;

  skeletonAnimations[4] // spineboy
    ..state.setAnimationByName(0, 'hoverboard', true)
    ..scaleX = 0.32
    ..scaleY = 0.32
    ..x = 660
    ..y = 320;

  // add the skeleton animations to the Stage and the Juggler

  stage.addChild(skeletonAnimations[0]);
  stage.addChild(skeletonAnimations[2]);
  stage.addChild(skeletonAnimations[4]);
  stage.addChild(skeletonAnimations[1]);
  stage.addChild(skeletonAnimations[3]);

  stage.juggler.add(skeletonAnimations[0]);
  stage.juggler.add(skeletonAnimations[1]);
  stage.juggler.add(skeletonAnimations[2]);
  stage.juggler.add(skeletonAnimations[3]);
  stage.juggler.add(skeletonAnimations[4]);
/*
  var shape = new Shape();
  shape.addTo(stage);
  shape.onExitFrame.listen((e) {
    var animation = skeletonAnimations[4];
    animation.boundsCalculation = SkeletonBoundsCalculation.Hull;
    var r = animation.bounds;
    shape.x = animation.x;
    shape.y = animation.y;
    shape.scaleX = animation.scaleX;
    shape.scaleY = animation.scaleY;
    shape.graphics.clear();
    shape.graphics.rect(r.left, r.top, r.width, r.height);
    shape.graphics.strokeColor(Color.Red, 2.0);
  });*/
}
