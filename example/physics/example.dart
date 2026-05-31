import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';

import 'package:web/web.dart' as web;
import 'package:stagexl/stagexl.dart' as st show MouseEvent;
import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';

Future<void> main() async {
  StageXL.stageOptions.renderEngine = RenderEngine.WebGL;
  StageXL.stageOptions.backgroundColor = Color.Black;

  final canvas = web.document.querySelector('#stage')! as web.HTMLCanvasElement;
  final stage = Stage(canvas, width: _stageWidth, height: _stageHeight);
  final renderLoop = RenderLoop();
  renderLoop.addStage(stage);

  final resourceManager = ResourceManager();
  resourceManager.addTextFile('skeletons', 'skeletons.json');
  resourceManager.addTextFile('atlasText', 'atlas2.atlas');
  resourceManager.addBitmapData('atlasImage', 'atlas2.png');
  resourceManager.addBitmapData('background', 'bg-example.png');
  await resourceManager.load();

  final backgroundData = resourceManager.getBitmapData('background');
  final background = Bitmap(backgroundData);
  final backgroundScale = math.max(_stageWidth / backgroundData.width, _stageHeight / backgroundData.height);
  background
    ..scaleX = backgroundScale
    ..scaleY = backgroundScale
    ..x = (_stageWidth - backgroundData.width * backgroundScale) / 2
    ..y = (_stageHeight - backgroundData.height * backgroundScale) / 2;
  stage.addChild(background);

  final skeletons = jsonDecode(resourceManager.getTextFile('skeletons')) as Map<String, Object?>;
  final physicsJson = skeletons['celeste']! as Map<String, Object?>;
  final setupBounds = physicsJson['skeleton']! as Map<String, Object?>;
  final textureAtlas = _readAtlas(resourceManager.getTextFile('atlasText'), resourceManager.getBitmapData('atlasImage'));
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonData = SkeletonLoader(attachmentLoader).readSkeletonData(physicsJson, 'celeste');
  final stateData = AnimationStateData(skeletonData);
  final skeletonAnimation = SkeletonAnimation(skeletonData, stateData)
    ..boundsCalculation = SkeletonBoundsCalculation.hull;

  skeletonAnimation.state.setAnimationByName(0, 'swing', true);
  skeletonAnimation.advanceTime(0);
  for (final constraint in skeletonAnimation.skeleton.physicsConstraints) {
    if (constraint.data.name == 'girl/wings/wing-back' ||
        constraint.data.name == 'girl/wings/wing-back-tip') {
      constraint.pose.mix = 0;
    }
  }
  _fitSkeletonToStage(skeletonAnimation, setupBounds);
  _enableCloudDrag(stage, skeletonAnimation);

  stage.addChild(skeletonAnimation);
  stage.juggler.add(skeletonAnimation);
}

const _stageWidth = 1200;
const _stageHeight = 700;

TextureAtlas _readAtlas(String source, BitmapData bitmapData) {
  final atlas = TextureAtlas(1);
  final lines = source.split(RegExp(r'\r\n|\r|\n'));
  var lineIndex = 0;

  while (lineIndex < lines.length && lines[lineIndex].trim().isEmpty) {
    lineIndex++;
  }
  if (lineIndex < lines.length) lineIndex++;
  while (lineIndex < lines.length && lines[lineIndex].contains(':')) {
    lineIndex++;
  }

  while (lineIndex < lines.length) {
    while (lineIndex < lines.length && lines[lineIndex].trim().isEmpty) {
      lineIndex++;
    }
    if (lineIndex >= lines.length) break;

    final name = lines[lineIndex++].trim();
    var frameX = 0;
    var frameY = 0;
    var packedWidth = 0;
    var packedHeight = 0;
    var originalWidth = 0;
    var originalHeight = 0;
    var offsetX = 0;
    var offsetY = 0;
    var rotation = 0;

    while (lineIndex < lines.length) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty || !line.contains(':')) break;
      lineIndex++;

      final separator = line.indexOf(':');
      final key = line.substring(0, separator);
      final values = line
          .substring(separator + 1)
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      switch (key) {
        case 'bounds':
          frameX = int.parse(values[0]);
          frameY = int.parse(values[1]);
          packedWidth = int.parse(values[2]);
          packedHeight = int.parse(values[3]);
        case 'offset':
          offsetX = int.parse(values[0]);
          offsetY = int.parse(values[1]);
        case 'offsets':
          offsetX = int.parse(values[0]);
          offsetY = int.parse(values[1]);
          originalWidth = int.parse(values[2]);
          originalHeight = int.parse(values[3]);
        case 'orig':
          originalWidth = int.parse(values[0]);
          originalHeight = int.parse(values[1]);
        case 'rotate':
          rotation = switch (values[0]) {
            '90' || 'true' => 3,
            '180' => 2,
            '270' => 1,
            _ => 0,
          };
      }
    }

    originalWidth = originalWidth == 0 ? packedWidth : originalWidth;
    originalHeight = originalHeight == 0 ? packedHeight : originalHeight;

    final frameWidth = rotation.isOdd ? packedHeight : packedWidth;
    final frameHeight = rotation.isOdd ? packedWidth : packedHeight;

    atlas.frames[name] = TextureAtlasFrame(
        atlas,
        bitmapData.renderTextureQuad,
        name,
        rotation,
        offsetX,
        offsetY,
        originalWidth,
        originalHeight,
        frameX,
        frameY,
        frameWidth,
        frameHeight,
        null,
        null);
  }

  return atlas;
}

void _fitSkeletonToStage(SkeletonAnimation skeletonAnimation, Map<String, Object?> setupBounds) {
  final boundsX = (setupBounds['x']! as num).toDouble();
  final boundsY = (setupBounds['y']! as num).toDouble();
  final boundsWidth = (setupBounds['width']! as num).toDouble();
  final boundsHeight = (setupBounds['height']! as num).toDouble();
  final boundsTop = -(boundsY + boundsHeight);
  final scale = math.min(_stageWidth / boundsWidth, _stageHeight / boundsHeight) * 0.95;

  skeletonAnimation
    ..scaleX = scale
    ..scaleY = scale
    ..x = (_stageWidth - boundsWidth * scale) / 2 - boundsX * scale
    ..y = (_stageHeight - boundsHeight * scale) / 2 - boundsTop * scale;
}

void _enableCloudDrag(Stage stage, SkeletonAnimation skeletonAnimation) {
  final cloudBone = skeletonAnimation.skeleton.findBone('cloud');
  if (cloudBone == null) return;

  skeletonAnimation.useHandCursor = true;

  var isDragging = false;
  var dragOffsetX = 0.0;
  var dragOffsetY = 0.0;
  StreamSubscription<st.MouseEvent>? moveSubscription;
  StreamSubscription<st.MouseEvent>? upSubscription;

  void updateCloud(st.MouseEvent event) {
    final localPoint = skeletonAnimation.globalToLocal(Point<num>(event.stageX, event.stageY));
    cloudBone.x = localPoint.x.toDouble() / skeletonAnimation.scaleX - dragOffsetX;
    cloudBone.y = -localPoint.y.toDouble() / skeletonAnimation.scaleY - dragOffsetY;
    skeletonAnimation.skeleton.updateWorldTransform();
  }

  void stopDrag() {
    isDragging = false;
    unawaited(moveSubscription?.cancel());
    unawaited(upSubscription?.cancel());
    moveSubscription = null;
    upSubscription = null;
  }

  skeletonAnimation.onMouseDown.listen((event) {
    final localPoint = skeletonAnimation.globalToLocal(Point<num>(event.stageX, event.stageY));
    final pointerX = localPoint.x.toDouble() / skeletonAnimation.scaleX;
    final pointerY = -localPoint.y.toDouble() / skeletonAnimation.scaleY;

    dragOffsetX = pointerX - cloudBone.x;
    dragOffsetY = pointerY - cloudBone.y;
    isDragging = true;
    updateCloud(event);

    unawaited(moveSubscription?.cancel());
    unawaited(upSubscription?.cancel());
    moveSubscription = stage.onMouseMove.listen((moveEvent) {
      if (isDragging) updateCloud(moveEvent);
    });
    upSubscription = stage.onMouseUp.listen((_) => stopDrag());
  });
}
