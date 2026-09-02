import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';
import 'package:test/test.dart';

void main() {
  group('slot display objects', () {
    test('replace a Spine attachment without changing its animation state', () {
      final display = SkeletonDisplayObject(_skeletonData(['weapon']));
      final slot = display.skeleton.slots.single;
      final attachment = Attachment('sword');
      final sword = Sprite();
      slot.attachment = attachment;

      display.addSlotObject('weapon', sword);

      expect(display.getSlotObject('weapon'), same(sword));
      expect(slot.attachment, same(attachment));
      expect(sword.parent, isA<Warp>());
      expect(sword.parent!.parent, same(display));
      expect(display.numChildren, 1);

      expect(display.removeSlotObject('weapon'), same(sword));
      expect(display.getSlotObject('weapon'), isNull);
      expect(slot.attachment, same(attachment));
      expect(sword.parent, isNull);
      expect(display.numChildren, 0);
    });

    test('moves a display object between slots and replaces the previous object', () {
      final display = SkeletonDisplayObject(_skeletonData(['left', 'right']));
      final first = Sprite();
      final second = Sprite();

      display.addSlotObject('left', first);
      display.addSlotObject('right', first);

      expect(display.getSlotObject('left'), isNull);
      expect(display.getSlotObject('right'), same(first));
      expect(display.numChildren, 1);

      display.addSlotObject('right', second);

      expect(first.parent, isNull);
      expect(display.getSlotObject('right'), same(second));
      expect(display.numChildren, 1);
    });

    test('follows the bone transform without inverting StageXL content', () {
      final data = _skeletonData(['weapon']);
      data.bones.single
        ..x = 10
        ..y = 20;
      final display = SkeletonDisplayObject(data);
      final slot = display.skeleton.slots.single;
      final sprite = Sprite();
      sprite.graphics
        ..circle(0, 0, 5)
        ..fillColor(0xFFFFFFFF);
      display.skeleton.color.a = 0.5;
      slot.color.a = 0.5;
      slot.data.blendMode = BlendMode.ADD;

      display.addSlotObject('weapon', sprite);

      final slotContainer = sprite.parent! as Warp;
      expect(slotContainer.matrix.a, closeTo(1, 0.000001));
      expect(slotContainer.matrix.b, closeTo(0, 0.000001));
      expect(slotContainer.matrix.c, closeTo(0, 0.000001));
      expect(slotContainer.matrix.d, closeTo(1, 0.000001));
      expect(slotContainer.matrix.tx, closeTo(10, 0.000001));
      expect(slotContainer.matrix.ty, closeTo(-20, 0.000001));
      expect(slotContainer.alpha, 0.25);
      expect(slotContainer.blendMode, BlendMode.ADD);
      expect(display.hitTestInput(10, -20), same(sprite));
    });

    test('converts a rotated Spine bone to StageXL coordinates', () {
      final data = _skeletonData(['weapon']);
      data.bones.single.rotation = 90;
      final display = SkeletonDisplayObject(data);
      final sprite = Sprite();

      display.addSlotObject('weapon', sprite);

      final slotContainer = sprite.parent! as Warp;
      expect(slotContainer.matrix.a, closeTo(0, 0.000001));
      expect(slotContainer.matrix.b, closeTo(-1, 0.000001));
      expect(slotContainer.matrix.c, closeTo(1, 0.000001));
      expect(slotContainer.matrix.d, closeTo(0, 0.000001));
    });

    test('can follow whether the Spine attachment timeline has an attachment', () {
      final display = SkeletonDisplayObject(_skeletonData(['weapon']));
      final slot = display.skeleton.slots.single;
      final sprite = Sprite();

      display.addSlotObject('weapon', sprite, followAttachmentTimeline: true);
      final slotContainer = sprite.parent! as Warp;
      expect(slotContainer.visible, isFalse);

      slot.attachment = Attachment('sword');
      display.bounds;
      expect(slotContainer.visible, isTrue);

      slot.attachment = null;
      display.bounds;
      expect(slotContainer.visible, isFalse);
    });

    test('rejects missing and foreign slots', () {
      final display = SkeletonDisplayObject(_skeletonData(['weapon']));
      final other = SkeletonDisplayObject(_skeletonData(['weapon']));

      expect(() => display.addSlotObject('missing', Sprite()), throwsArgumentError);
      expect(
        () => display.addSlotObjectForSlot(other.skeleton.slots.single, Sprite()),
        throwsArgumentError,
      );
    });
  });
}

SkeletonData _skeletonData(List<String> slotNames) {
  final root = BoneData(0, 'root', null);
  return SkeletonData()
    ..bones = [root]
    ..slots = [
      for (final (index, name) in slotNames.indexed) SlotData(index, name, root),
    ];
}
