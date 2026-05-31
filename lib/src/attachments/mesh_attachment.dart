/// ****************************************************************************
/// Spine Runtimes Software License v2.5
///
/// Copyright (c) 2013-2016, Esoteric Software
/// All rights reserved.
///
/// You are granted a perpetual, non-exclusive, non-sublicensable, and
/// non-transferable license to use, install, execute, and perform the Spine
/// Runtimes software and derivative works solely for personal or internal
/// use. Without the written permission of Esoteric Software (see Section 2 of
/// the Spine Software License Agreement), you may not (a) modify, translate,
/// adapt, or develop new applications using the Spine Runtimes or otherwise
/// create derivative works or improvements of the Spine Runtimes or (b) remove,
/// delete, alter, or obscure any trademarks or any copyright, trademark, patent,
/// or other intellectual property or proprietary rights notices on or in the
/// Software, including any copy thereof. Redistributions in binary or source
/// form must include this license and terms.
///
/// THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
/// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
/// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
/// EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
/// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
/// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
/// USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
/// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
/// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
/// POSSIBILITY OF SUCH DAMAGE.
///***************************************************************************

part of '../../stagexl_spine.dart';

class MeshAttachment extends RenderAttachment {
  late Float32List regionUVs;
  late Int16List triangles;
  late Int16List edges;

  bool inheritDeform = false;
  double width = 0;
  double height = 0;
  MeshAttachment? _parentMesh;

  MeshAttachment(super.name, super.path, super.bitmapData);

  //---------------------------------------------------------------------------

  MeshAttachment? get parentMesh => _parentMesh;

  set parentMesh(MeshAttachment? parentMesh) {
    _parentMesh = parentMesh;
    if (parentMesh != null) {
      bones = parentMesh.bones;
      vertices = parentMesh.vertices;
      worldVerticesLength = parentMesh.worldVerticesLength;
      regionUVs = parentMesh.regionUVs;
      triangles = parentMesh.triangles;
      hullLength = parentMesh.hullLength;
      edges = parentMesh.edges;
      width = parentMesh.width;
      height = parentMesh.height;
    }
  }

  @override
  bool applyDeform(VertexAttachment sourceAttachment) {
    if (sourceAttachment == this) return true;
    if (sourceAttachment == _parentMesh && inheritDeform) return true;
    return false;
  }

  //---------------------------------------------------------------------------

  @override
  void initRenderGeometry() {
    ixList = Int16List.fromList(triangles);
    vxList = Float32List(regionUVs.length * 2);

    final textureUvs = _computeTextureUvs();
    for (var i = 0, o = 0; i < textureUvs.length - 1; i += 2, o += 4) {
      vxList[o + 2] = textureUvs[i + 0];
      vxList[o + 3] = textureUvs[i + 1];
    }
  }

  Float32List _computeTextureUvs() {
    final atlasFrame = textureAtlasFrame;
    final renderTextureQuad = bitmapData.renderTextureQuad;
    final sourceRectangle = renderTextureQuad.sourceRectangle;
    final offsetRectangle = renderTextureQuad.offsetRectangle;
    final textureWidth = renderTextureQuad.renderTexture.width.toDouble();
    final textureHeight = renderTextureQuad.renderTexture.height.toDouble();
    final rotation = atlasFrame?.rotation ?? renderTextureQuad.rotation;
    final offsetX = (atlasFrame?.offsetX ?? -offsetRectangle.left).toDouble();
    final offsetY = (atlasFrame?.offsetY ?? -offsetRectangle.top).toDouble();
    final originalWidth = (atlasFrame?.originalWidth ?? offsetRectangle.width).toDouble();
    final originalHeight = (atlasFrame?.originalHeight ?? offsetRectangle.height).toDouble();
    final packedWidth = atlasFrame == null
      ? (rotation.isOdd ? sourceRectangle.height : sourceRectangle.width).toDouble()
      : (rotation.isOdd ? atlasFrame.frameHeight : atlasFrame.frameWidth).toDouble();
    final packedHeight = atlasFrame == null
      ? (rotation.isOdd ? sourceRectangle.width : sourceRectangle.height).toDouble()
      : (rotation.isOdd ? atlasFrame.frameWidth : atlasFrame.frameHeight).toDouble();
    final textureUvs = Float32List(regionUVs.length);

    var baseU = (atlasFrame?.frameX ?? sourceRectangle.left) / textureWidth;
    var baseV = (atlasFrame?.frameY ?? sourceRectangle.top) / textureHeight;
    late double width;
    late double height;

    if (rotation == 3) {
      baseU -= (originalHeight - offsetY - packedHeight) / textureWidth;
      baseV -= (originalWidth - offsetX - packedWidth) / textureHeight;
      width = originalHeight / textureWidth;
      height = originalWidth / textureHeight;

      for (var i = 0; i < textureUvs.length - 1; i += 2) {
        textureUvs[i + 0] = baseU + regionUVs[i + 1] * width;
        textureUvs[i + 1] = baseV + (1.0 - regionUVs[i + 0]) * height;
      }
    } else if (rotation == 2) {
      baseU -= (originalWidth - offsetX - packedWidth) / textureWidth;
      baseV -= offsetY / textureHeight;
      width = originalWidth / textureWidth;
      height = originalHeight / textureHeight;

      for (var i = 0; i < textureUvs.length - 1; i += 2) {
        textureUvs[i + 0] = baseU + (1.0 - regionUVs[i + 0]) * width;
        textureUvs[i + 1] = baseV + (1.0 - regionUVs[i + 1]) * height;
      }
    } else if (rotation == 1) {
      baseU -= offsetY / textureWidth;
      baseV -= offsetX / textureHeight;
      width = originalHeight / textureWidth;
      height = originalWidth / textureHeight;

      for (var i = 0; i < textureUvs.length - 1; i += 2) {
        textureUvs[i + 0] = baseU + (1.0 - regionUVs[i + 1]) * width;
        textureUvs[i + 1] = baseV + regionUVs[i + 0] * height;
      }
    } else {
      baseU -= offsetX / textureWidth;
      baseV -= (originalHeight - offsetY - packedHeight) / textureHeight;
      width = originalWidth / textureWidth;
      height = originalHeight / textureHeight;

      for (var i = 0; i < textureUvs.length - 1; i += 2) {
        textureUvs[i + 0] = baseU + regionUVs[i + 0] * width;
        textureUvs[i + 1] = baseV + regionUVs[i + 1] * height;
      }
    }

    return textureUvs;
  }
}
