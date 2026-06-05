part of '../../stagexl_spine.dart';

class TextureAtlasAttachmentLoader implements AttachmentLoader, SequenceAttachmentLoader {
  final TextureAtlas textureAtlas;
  final String namePrefix;

  TextureAtlasAttachmentLoader(this.textureAtlas, [this.namePrefix = '']);

  @override
  RegionAttachment newRegionAttachment(Skin skin, String name, String path) {
    final frame = textureAtlas.frames[namePrefix + path];
    final bitmapData = frame?.bitmapData ?? textureAtlas.getBitmapData(namePrefix + path);
    final attachment = RegionAttachment(name, path, bitmapData);
    attachment.textureAtlasFrame = frame;
    return attachment;
  }

  @override
  MeshAttachment newMeshAttachment(Skin skin, String name, String path) {
    final frame = textureAtlas.frames[namePrefix + path];
    final bitmapData = frame?.bitmapData ?? textureAtlas.getBitmapData(namePrefix + path);
    final attachment = MeshAttachment(name, path, bitmapData);
    attachment.textureAtlasFrame = frame;
    return attachment;
  }

  @override
  BoundingBoxAttachment newBoundingBoxAttachment(Skin skin, String name) => BoundingBoxAttachment(name);

  @override
  PathAttachment newPathAttachment(Skin skin, String name) => PathAttachment(name);

  @override
  PointAttachment newPointAttachment(Skin skin, String name) => PointAttachment(name);

  @override
  ClippingAttachment newClippingAttachment(Skin skin, String name) => ClippingAttachment(name);

  @override
  List<BitmapData> getSequenceBitmapData(String path, SpineSequence sequence) => [
        for (var i = 0; i < sequence.count; i++)
          textureAtlas.getBitmapData(namePrefix + sequence.pathFor(path, i)),
      ];
}
