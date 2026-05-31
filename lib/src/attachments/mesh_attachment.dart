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

    final matrix = bitmapData.renderTextureQuad.samplerMatrix;
    final ma = matrix.a * bitmapData.width;
    final mb = matrix.b * bitmapData.width;
    final mc = matrix.c * bitmapData.height;
    final md = matrix.d * bitmapData.height;
    final mx = matrix.tx;
    final my = matrix.ty;

    for (var i = 0, o = 0; i < regionUVs.length - 1; i += 2, o += 4) {
      final u = regionUVs[i + 0];
      final v = regionUVs[i + 1];
      vxList[o + 2] = u * ma + v * mc + mx;
      vxList[o + 3] = u * mb + v * md + my;
    }
  }
}
