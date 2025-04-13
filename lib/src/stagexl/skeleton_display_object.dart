part of '../../stagexl_spine.dart';

enum SkeletonBoundsCalculation { none, boundingBoxes, hull }

class SkeletonDisplayObject extends InteractiveObject {
  final Skeleton skeleton;
  final Matrix _skeletonMatrix = Matrix(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
  final Matrix _identityMatrix = Matrix.fromIdentity();
  final Matrix _transformMatrix = Matrix.fromIdentity();

  static final Float32List _vertices = Float32List(2048);
  static final SkeletonClipping _clipping = SkeletonClipping();

  SkeletonBoundsCalculation boundsCalculation = SkeletonBoundsCalculation.none;

  SkeletonDisplayObject(SkeletonData skeletonData) : skeleton = Skeleton(skeletonData) {
    skeleton.updateWorldTransform();
  }

  //---------------------------------------------------------------------------

  @override
  Rectangle<num> get bounds {
    final vertices = _vertices;
    var offset = 0;

    if (boundsCalculation == SkeletonBoundsCalculation.boundingBoxes) {
      for (final slot in skeleton.drawOrder) {
        final attachment = slot.attachment;
        if (attachment is BoundingBoxAttachment) {
          final length = attachment.worldVerticesLength;
          attachment.computeWorldVertices2(slot, 0, length, vertices, offset, 2);
          offset += length;
        }
      }
    } else if (boundsCalculation == SkeletonBoundsCalculation.hull) {
      for (final slot in skeleton.drawOrder) {
        final attachment = slot.attachment;
        if (attachment is RenderAttachment) {
          final length = attachment.hullLength;
          attachment.computeWorldVertices2(slot, 0, length, vertices, offset, 2);
          offset += length;
        }
      }
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (var i = 0; i < offset - 1; i += 2) {
      final x = vertices[i + 0];
      final y = vertices[i + 1];
      if (minX > x) minX = x;
      if (minY > y) minY = y;
      if (maxX < x) maxX = x;
      if (maxY < y) maxY = y;
    }

    minX = minX.isFinite ? minX : 0.0;
    minY = minY.isFinite ? minY : 0.0;
    maxX = maxX.isFinite ? maxX : 0.0;
    maxY = maxY.isFinite ? maxY : 0.0;

    return Rectangle<num>(minX, 0.0 - maxY, maxX - minX, maxY - minY);
  }

  @override
  DisplayObject? hitTestInput(num localX, num localY) {
    final vertices = _vertices;
    final sx = 0.0 + localX;
    final sy = 0.0 - localY;

    if (boundsCalculation == SkeletonBoundsCalculation.boundingBoxes) {
      for (final slot in skeleton.drawOrder) {
        final attachment = slot.attachment;
        if (attachment is BoundingBoxAttachment) {
          final length = attachment.worldVerticesLength;
          attachment.computeWorldVertices2(slot, 0, length, vertices, 0, 2);
          if (_windingCount(vertices, length, sx, sy) != 0) return this;
        }
      }
    } else if (boundsCalculation == SkeletonBoundsCalculation.hull) {
      for (final slot in skeleton.drawOrder) {
        final attachment = slot.attachment;
        if (attachment is RenderAttachment) {
          final length = attachment.hullLength;
          attachment.computeWorldVertices2(slot, 0, length, vertices, 0, 2);
          if (_windingCount(vertices, length, sx, sy) != 0) return this;
        }
      }
    }

    return null;
  }

  @override
  void render(RenderState renderState) {
    final renderContext = renderState.renderContext;
    if (renderContext is RenderContextWebGL) {
      _renderWebGL(renderState);
    } else {
      _renderCanvas(renderState);
    }
  }

  //---------------------------------------------------------------------------

  void _renderWebGL(RenderState renderState) {
    final renderContext = renderState.renderContext as RenderContextWebGL;
    final renderProgram = renderContext.renderProgramBatch;
    final skeletonR = skeleton.color.r;
    final skeletonG = skeleton.color.g;
    final skeletonB = skeleton.color.b;
    final skeletonA = skeleton.color.a;
    final slots = skeleton.drawOrder;
    final vertices = _vertices;
    final clipping = _clipping;

    ClippingAttachment? clippingAttachment;
    renderContext.activateRenderProgram(renderProgram);
    renderState.push(_skeletonMatrix, 1.0, renderState.globalBlendMode);

    for (var s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final attachment = slot.attachment;

      if (attachment is RenderAttachment) {
        attachment.updateRenderGeometry(slot);
        renderContext.activateRenderTexture(attachment.bitmapData.renderTexture);
        renderContext.activateBlendMode(slot.data.blendMode);
        renderProgram.renderTextureMesh(
            renderState,
            renderContext,
            attachment.bitmapData.renderTexture,
            attachment.ixList,
            attachment.vxList,
            attachment.color.r * skeletonR * slot.color.r,
            attachment.color.g * skeletonG * slot.color.g,
            attachment.color.b * skeletonB * slot.color.b,
            attachment.color.a * skeletonA * slot.color.a);
      } else if (attachment is ClippingAttachment) {
        final length = attachment.worldVerticesLength;
        attachment.computeWorldVertices2(slot, 0, length, vertices, 0, 2);
        clipping.vertices = vertices.buffer.asFloat32List(0, length);
        renderContext.beginRenderMask(renderState, clipping);
        renderContext.activateRenderProgram(renderProgram);
        clippingAttachment = attachment;
      }

      if (clippingAttachment != null) {
        if (s == slots.length - 1 || clippingAttachment.endSlot == slot.data) {
          renderContext.endRenderMask(renderState, clipping);
          renderContext.activateRenderProgram(renderProgram);
          clippingAttachment = null;
        }
      }
    }

    renderState.pop();
  }

  void _renderCanvas(RenderState renderState) {
    final renderContext = renderState.renderContext as RenderContextCanvas;
    final vertices = _vertices;
    final clipping = _clipping;
    final transform = _transformMatrix;
    final slots = skeleton.drawOrder;

    ClippingAttachment? clippingAttachment;
    renderState.push(_skeletonMatrix, skeleton.color.a, renderState.globalBlendMode);

    for (var s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final attachment = slot.attachment;

      if (attachment is RegionAttachment) {
        final b = slot.bone;
        transform.setTo(b.a, b.c, b.b, b.d, b.worldX, b.worldY);
        transform.prepend(attachment.transformationMatrix);
        renderState.push(transform, attachment.color.a * slot.color.a, slot.data.blendMode);
        renderState.renderTextureQuad(attachment.bitmapData.renderTextureQuad);
        renderState.pop();
      } else if (attachment is RenderAttachment) {
        attachment.updateRenderGeometry(slot);
        final ixList = attachment.ixList;
        final vxList = attachment.vxList;
        final alpha = attachment.color.a * slot.color.a;
        final renderTexture = attachment.bitmapData.renderTexture;
        renderState.push(_identityMatrix, alpha, slot.data.blendMode);
        renderState.renderTextureMesh(renderTexture, ixList, vxList);
        renderState.pop();
      } else if (attachment is ClippingAttachment) {
        final length = attachment.worldVerticesLength;
        attachment.computeWorldVertices2(slot, 0, length, vertices, 0, 2);
        clipping.vertices = vertices.buffer.asFloat32List(0, length);
        renderContext.beginRenderMask(renderState, clipping);
        clippingAttachment = attachment;
      }

      if (clippingAttachment != null) {
        if (s == slots.length - 1 || clippingAttachment.endSlot == slot.data) {
          renderContext.endRenderMask(renderState, clipping);
          clippingAttachment = null;
        }
      }
    }

    renderState.pop();
  }

  //---------------------------------------------------------------------------

  int _windingCount(Float32List vertices, int length, double x, double y) {
    var ax = vertices[length - 2];
    var ay = vertices[length - 1];
    var wn = 0;

    for (var i = 0; i < length - 1; i += 2) {
      final bx = vertices[i + 0];
      final by = vertices[i + 1];
      if (ay <= y) {
        if (by > y && (bx - ax) * (y - ay) - (x - ax) * (by - ay) > 0) wn++;
      } else {
        if (by <= y && (bx - ax) * (y - ay) - (x - ax) * (by - ay) < 0) wn--;
      }
      ax = bx;
      ay = by;
    }

    return wn;
  }
}
