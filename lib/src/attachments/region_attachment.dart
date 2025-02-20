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

part of stagexl_spine;

class RegionAttachment extends RenderAttachment {
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  double scaleX = 1;
  double scaleY = 1;
  double rotation = 0;

  final Matrix transformationMatrix = Matrix.fromIdentity();

  RegionAttachment(super.name, super.path, super.bitmapData) {
    initRenderGeometry();
  }

  //---------------------------------------------------------------------------

  /// The update method will update the [transformationMatrix] based on the
  /// x, y, width, height, scaleX, scaleY and rotation fields. Therefore you
  /// have to call this method after you have changed one of those fields.

  void update() {
    final num sw = scaleX * width;
    final num sh = scaleY * height;
    final bw = bitmapData.width;
    final bh = bitmapData.height;
    final num cosR = _cosDeg(rotation);
    final num sinR = _sinDeg(rotation);

    final num ma = cosR * sw / bw;
    final num mb = sinR * sh / bh;
    final num mc = sinR * sw / bw;
    final num md = 0.0 - cosR * sh / bh;
    final num mx = x - 0.5 * (sw * cosR + sh * sinR);
    final num my = y - 0.5 * (sw * sinR - sh * cosR);
    transformationMatrix.setTo(ma, mc, mb, md, mx, my);

    final vxList = bitmapData.renderTextureQuad.vxList;

    for (var o = 0; o <= vertices.length - 2; o += 2) {
      final x = vxList[o * 2 + 0];
      final y = vxList[o * 2 + 1];
      vertices[o + 0] = x * ma + y * mb + mx;
      vertices[o + 1] = x * mc + y * md + my;
    }
  }

  //---------------------------------------------------------------------------

  @override
  void computeWorldVertices2(
      Slot slot, int start, int count, Float32List worldVertices, int offset, int stride) {
    final ma = slot.bone.a;
    final mb = slot.bone.b;
    final mc = slot.bone.c;
    final md = slot.bone.d;
    final mx = slot.bone.worldX;
    final my = slot.bone.worldY;
    final length = count >> 1;

    for (var i = 0; i < length; i++, start += 2, offset += stride) {
      final x = vertices[start + 0];
      final y = vertices[start + 1];
      worldVertices[offset + 0] = x * ma + y * mb + mx;
      worldVertices[offset + 1] = x * mc + y * md + my;
    }
  }

  @override
  void initRenderGeometry() {
    final renderTextureQuad = bitmapData.renderTextureQuad;
    ixList = Int16List.fromList(renderTextureQuad.ixList);
    vxList = Float32List.fromList(renderTextureQuad.vxList);
    worldVerticesLength = hullLength = vxList.length >> 1;
    vertices = Float32List(worldVerticesLength);
    update();
  }
}
