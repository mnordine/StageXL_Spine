import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';
import 'package:web/web.dart';

Future<void> main() async {
  StageXL.stageOptions
    ..renderEngine = RenderEngine.WebGL
    ..backgroundColor = 0xFF15202B;
  final canvas = document.querySelector('#stage')! as HTMLCanvasElement;
  final status = document.querySelector('#status')! as HTMLParagraphElement;
  final stage = Stage(canvas, width: 600, height: 600);
  RenderLoop().addStage(stage);

  final resourceManager = ResourceManager();
  resourceManager.addTextFile('coin', '../coin/spine/coin.json');
  resourceManager.addTextureAtlas('coin', '../coin/spine/coin.atlas', TextureAtlasFormat.libGdx);
  await resourceManager.load();

  final textureAtlas = resourceManager.getTextureAtlas('coin');
  final attachmentLoader = TextureAtlasAttachmentLoader(textureAtlas);
  final skeletonLoader = SkeletonLoader(attachmentLoader);
  final skeletonData = skeletonLoader.readSkeletonData(resourceManager.getTextFile('coin'));
  final skeletonAnimation = SkeletonAnimation(skeletonData)
    ..x = 300
    ..y = 600;
  skeletonAnimation.state.setAnimationByName(0, 'rotate', true);
  stage
    ..addChild(skeletonAnimation)
    ..juggler.add(skeletonAnimation);

  final replacementBitmap = Bitmap(
    BitmapData(220, 220, 0xFF5B4BDB)
      ..fillRect(Rectangle<num>(14, 14, 192, 192), 0xFF14B8A6)
      ..fillRect(Rectangle<num>(42, 42, 52, 52), 0xFFFFC857)
      ..fillRect(Rectangle<num>(126, 42, 52, 52), 0xFFFFC857)
      ..fillRect(Rectangle<num>(42, 130, 136, 34), 0xFFFFFFFF),
  )
    ..x = -110
    ..y = -110;
  final replacement = Sprite()..addChild(replacementBitmap);

  var injected = true;
  skeletonAnimation.addSlotObject('images/coin', replacement);
  status.textContent = 'StageXL display object replaces the coin attachment. Click to restore.';

  stage.onMouseClick.listen((_) {
    injected = !injected;
    if (injected) {
      skeletonAnimation.addSlotObject('images/coin', replacement);
      status.textContent = 'StageXL display object replaces the coin attachment. Click to restore.';
    } else {
      skeletonAnimation.removeSlotObject('images/coin');
      status.textContent = 'Spine attachment restored. Click to inject the display object.';
    }
  });
}
