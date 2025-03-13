part of '../../stagexl_spine.dart';

class TextureAtlasAttachmentLoader implements AttachmentLoader {
  final TextureAtlas textureAtlas;
  final String namePrefix;

  TextureAtlasAttachmentLoader(this.textureAtlas, [this.namePrefix = '']);

  @override
  RegionAttachment newRegionAttachment(Skin skin, String name, String path) {
    final bitmapData = textureAtlas.getBitmapData(namePrefix + path);
    return RegionAttachment(name, path, bitmapData);
  }

  @override
  MeshAttachment newMeshAttachment(Skin skin, String name, String path) {
    final bitmapData = textureAtlas.getBitmapData(namePrefix + path);
    return MeshAttachment(name, path, bitmapData);
  }

  @override
  BoundingBoxAttachment newBoundingBoxAttachment(Skin skin, String name) => BoundingBoxAttachment(name);

  @override
  PathAttachment newPathAttachment(Skin skin, String name) => PathAttachment(name);

  @override
  PointAttachment newPointAttachment(Skin skin, String name) => PointAttachment(name);

  @override
  ClippingAttachment newClippingAttachment(Skin skin, String name) => ClippingAttachment(name);
}
