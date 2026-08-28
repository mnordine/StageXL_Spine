@TestOn('browser')
library;

import 'dart:convert';

import 'package:stagexl/stagexl.dart';
import 'package:stagexl_spine/stagexl_spine.dart';
import 'package:test/test.dart';

void main() {
  late SkeletonLoader loader;

  setUp(() {
    loader = SkeletonLoader(_TestAttachmentLoader());
  });

  test('evaluates Spine 4.x RGBA curves independently per channel', () {
    final data = loader.readSkeletonData(jsonEncode({
      'skeleton': {'spine': '4.2.43'},
      'bones': [
        {'name': 'root'},
      ],
      'slots': [
        {'name': 'slot', 'bone': 'root', 'color': '00000000'},
      ],
      'skins': [
        {'name': 'default', 'attachments': <String, Object?>{}},
      ],
      'animations': {
        'color': {
          'slots': {
            'slot': {
              'rgba': [
                {
                  'color': '00000000',
                  'curve': [
                    0.25, 1, 0.75, 1,
                    0.25, 0, 0.75, 0,
                    0.25, 0.25, 0.75, 0.75,
                    0.25, 0.25, 0.75, 0.75,
                  ],
                },
                {'time': 1, 'color': 'FFFFFFFF'},
              ],
            },
          },
        },
      },
    }));
    final skeleton = Skeleton(data);

    data.findAnimation('color')!.apply(
        skeleton, 0, 0.5, false, [], 1, MixPose.setup, MixDirection.In);

    final color = skeleton.slots.single.color;
    expect(color.r, greaterThan(0.8));
    expect(color.g, lessThan(0.2));
    expect(color.b, closeTo(0.5, 0.02));
    expect(color.a, closeTo(0.5, 0.02));
  });

  test('loads and applies independent transform constraint x and y mixes', () {
    final data = loader.readSkeletonData(jsonEncode({
      'skeleton': {'spine': '4.2.43'},
      'bones': [
        {'name': 'root'},
        {'name': 'target', 'parent': 'root', 'x': 10, 'y': 20},
        {'name': 'constrained', 'parent': 'root'},
      ],
      'slots': <Object?>[],
      'transform': [
        {
          'name': 'follow',
          'bones': ['constrained'],
          'target': 'target',
          'mixRotate': 0,
          'mixX': 0.5,
          'mixY': 0.25,
          'mixScaleX': 0,
          'mixShearY': 0,
        },
      ],
      'skins': [
        {'name': 'default', 'attachments': <String, Object?>{}},
      ],
      'animations': {
        'move': {
          'transform': {
            'follow': [
              {
                'mixRotate': 0,
                'mixX': 0.75,
                'mixY': 0.1,
                'mixScaleX': 0,
                'mixShearY': 0,
              },
            ],
          },
        },
      },
    }));
    final skeleton = Skeleton(data);
    final constraint = skeleton.transformConstraints.single;

    expect(constraint.data.translateMixX, closeTo(0.5, 0.001));
    expect(constraint.data.translateMixY, closeTo(0.25, 0.001));

    data.findAnimation('move')!.apply(
        skeleton, 0, 0, false, [], 1, MixPose.setup, MixDirection.In);
    skeleton.updateWorldTransform();

    expect(constraint.translateMixX, closeTo(0.75, 0.001));
    expect(constraint.translateMixY, closeTo(0.1, 0.001));
    expect(skeleton.findBone('constrained')!.worldX, closeTo(7.5, 0.001));
    expect(skeleton.findBone('constrained')!.worldY, closeTo(2, 0.001));
  });

  test('refreshes region UVs when a sequence frame changes', () {
    final sheet = BitmapData(32, 16, Color.Transparent);
    sheet.fillRect(Rectangle<num>(0, 0, 16, 16), Color.Red);
    sheet.fillRect(Rectangle<num>(16, 0, 16, 16), Color.Blue);
    final sequenceFrames = [
      BitmapData.fromBitmapData(sheet, Rectangle<num>(0, 0, 16, 16)),
      BitmapData.fromBitmapData(sheet, Rectangle<num>(16, 0, 16, 16)),
    ];
    final sequenceLoader = SkeletonLoader(_TestAttachmentLoader(sequenceFrames));
    final data = sequenceLoader.readSkeletonData(jsonEncode({
      'skeleton': {'spine': '4.2.43'},
      'bones': [
        {'name': 'root'},
      ],
      'slots': [
        {'name': 'slot', 'bone': 'root', 'attachment': 'slot'},
      ],
      'skins': [
        {
          'name': 'default',
          'attachments': {
            'slot': {
              'slot': {
                'width': 16,
                'height': 16,
                'sequence': {'count': 2, 'start': 0, 'digits': 1},
              },
            },
          },
        },
      ],
      'animations': {
        'sequence': {
          'attachments': {
            'default': {
              'slot': {
                'slot': {
                  'sequence': [
                    {'mode': 'loop', 'delay': 0.1},
                  ],
                },
              },
            },
          },
        },
      },
    }));
    final skeleton = Skeleton(data)..updateWorldTransform();
    final slot = skeleton.slots.single;

    data.findAnimation('sequence')!.apply(
        skeleton, 0, 0.15, false, [], 1, MixPose.setup, MixDirection.In);
    final attachment = slot.attachment! as RegionAttachment;
    final bitmapData = attachment.updateRenderGeometry(slot);
    final setupVertices = sequenceFrames.first.renderTextureQuad.vxList;
    final expectedVertices = sequenceFrames.last.renderTextureQuad.vxList;

    expect(bitmapData, same(sequenceFrames.last));
    expect(expectedVertices[2], isNot(closeTo(setupVertices[2], 0.001)));
    for (final offset in [2, 3, 6, 7, 10, 11, 14, 15]) {
      expect(attachment.vxList[offset], closeTo(expectedVertices[offset], 0.001));
    }
  });

  test('evaluates Spine 4.x deform curves using absolute control times', () {
    final data = loader.readSkeletonData(jsonEncode({
      'skeleton': {'spine': '4.2.43'},
      'bones': [
        {'name': 'root'},
      ],
      'slots': [
        {'name': 'slot', 'bone': 'root', 'attachment': 'mesh'},
      ],
      'skins': [
        {
          'name': 'default',
          'attachments': {
            'slot': {
              'mesh': {
                'type': 'mesh',
                'uvs': [0, 0, 1, 0, 1, 1, 0, 1],
                'triangles': [0, 1, 2, 0, 2, 3],
                'vertices': [0, 0, 16, 0, 16, 16, 0, 16],
                'hull': 4,
              },
            },
          },
        },
      ],
      'animations': {
        'warp': {
          'attachments': {
            'default': {
              'slot': {
                'mesh': {
                  'deform': [
                    {
                      'curve': [0.022, 0, 0.08, 0.35],
                    },
                    {
                      'time': 0.1,
                      'vertices': [100, 0, 0, 0, 0, 0, 0, 0],
                    },
                  ],
                },
              },
            },
          },
        },
      },
    }));
    final skeleton = Skeleton(data);

    data.findAnimation('warp')!.apply(
        skeleton, 0, 0.05, false, [], 1, MixPose.setup, MixDirection.In);

    expect(skeleton.slots.single.attachmentVertices.first, closeTo(25.044, 0.5));
  });
}

class _TestAttachmentLoader implements AttachmentLoader, SequenceAttachmentLoader {
  final List<BitmapData>? sequenceBitmapData;
  late final BitmapData _bitmapData;

  _TestAttachmentLoader([this.sequenceBitmapData]) {
    _bitmapData = sequenceBitmapData?.first ?? BitmapData(16, 16, Color.White);
  }

  @override
  RegionAttachment newRegionAttachment(Skin skin, String name, String path) =>
      RegionAttachment(name, path, _bitmapData);

  @override
  MeshAttachment newMeshAttachment(Skin skin, String name, String path) =>
      MeshAttachment(name, path, _bitmapData);

  @override
  BoundingBoxAttachment newBoundingBoxAttachment(Skin skin, String name) =>
      BoundingBoxAttachment(name);

  @override
  ClippingAttachment newClippingAttachment(Skin skin, String name) => ClippingAttachment(name);

  @override
  PathAttachment newPathAttachment(Skin skin, String name) => PathAttachment(name);

  @override
  PointAttachment newPointAttachment(Skin skin, String name) => PointAttachment(name);

  @override
  List<BitmapData> getSequenceBitmapData(String path, SpineSequence sequence) =>
      sequenceBitmapData ?? [
        for (var i = 0; i < sequence.count; i++) BitmapData(16, 16, Color.White),
      ];
}
