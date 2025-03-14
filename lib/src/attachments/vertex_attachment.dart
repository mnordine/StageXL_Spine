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

class VertexAttachment extends Attachment {
  static int _nextID = 0;
  final int id = (_nextID++ & 65535) << 11;

  Int16List? bones;
  late Float32List vertices;
  int worldVerticesLength = 0;

  VertexAttachment(super.name);

  void computeWorldVertices(Slot slot, Float32List worldVertices) {
    computeWorldVertices2(slot, 0, worldVerticesLength, worldVertices, 0, 2);
  }

  /// Transforms local vertices to world coordinates.
  ///
  /// [start] The index of the first local vertex value to transform.
  /// Each vertex has 2 values, x and y.
  ///
  /// [count] The number of world vertex values to output.
  /// Must be <= getWorldVerticesLength() - start.
  ///
  /// [worldVertices] The output world vertices.
  /// Must have a length >= offset + count.
  ///
  /// [offset] The worldVertices index to begin writing values.

  void computeWorldVertices2(
      Slot slot, int start, int count, Float32List worldVertices, int offset, int stride) {
    final skeleton = slot.skeleton;
    final skeletonBones = skeleton.bones;
    final deform = slot.attachmentVertices;
    var vertices = this.vertices;
    final bones = this.bones;

    if (bones == null) {
      vertices = deform.isEmpty? vertices : deform;

      final bone = slot.bone;
      final x = bone.worldX;
      final y = bone.worldY;
      final a = bone.a;
      final b = bone.b;
      final c = bone.c;
      final d = bone.d;

      var vi = start;
      var wi = offset;

      for (var i = 0; i < count; i += 2, vi += 2, wi += stride) {
        final vx = vertices[vi + 0];
        final vy = vertices[vi + 1];
        worldVertices[wi + 0] = vx * a + vy * b + x;
        worldVertices[wi + 1] = vx * c + vy * d + y;
      }
    } else if (deform.isEmpty) {
      var vi = 0; // vertices index
      var bi = 0; // bones index
      var wi = offset; // world vertices index

      for (var i = 0; i < start; i += 2) {
        final boneCount = bones[bi];
        bi += boneCount + 1;
        vi += boneCount * 3;
      }

      for (var i = 0; i < count; i += 2, wi += stride) {
        double x = 0;
        double y = 0;
        final boneCount = bones[bi++];
        final boneFinal = bi + boneCount;
        for (; bi < boneFinal; bi += 1, vi += 3) {
          final bone = skeletonBones[bones[bi]];
          final vx = vertices[vi + 0];
          final vy = vertices[vi + 1];
          final vw = vertices[vi + 2];
          x += (vx * bone.a + vy * bone.b + bone.worldX) * vw;
          y += (vx * bone.c + vy * bone.d + bone.worldY) * vw;
        }
        worldVertices[wi + 0] = x;
        worldVertices[wi + 1] = y;
      }
    } else {
      var vi = 0; // vertices index
      var di = 0; // deform index
      var bi = 0; // bones index
      var wi = offset; // world vertices index

      for (var i = 0; i < start; i += 2) {
        final boneCount = bones[bi];
        bi += boneCount + 1;
        vi += boneCount * 3;
        di += boneCount * 2;
      }

      for (var i = 0; i < count; i += 2, wi += stride) {
        double x = 0;
        double y = 0;
        final boneCount = bones[bi++];
        final boneFinal = bi + boneCount;
        for (; bi < boneFinal; bi += 1, vi += 3, di += 2) {
          final bone = skeletonBones[bones[bi]];
          final vx = vertices[vi + 0] + deform[di + 0];
          final vy = vertices[vi + 1] + deform[di + 1];
          final vw = vertices[vi + 2];
          x += (vx * bone.a + vy * bone.b + bone.worldX) * vw;
          y += (vx * bone.c + vy * bone.d + bone.worldY) * vw;
        }
        worldVertices[wi + 0] = x;
        worldVertices[wi + 1] = y;
      }
    }
  }

  /// Returns true if a deform originally applied to the specified attachment
  /// should be applied to this attachment.

  bool applyDeform(VertexAttachment sourceAttachment) => this == sourceAttachment;
}
