part of '../../stagexl_spine.dart';

enum SkeletonBoundsCalculation { none, boundingBoxes, hull }

class SkeletonDisplayObject extends DisplayObjectContainer {
  final Skeleton skeleton;
  final Matrix _skeletonMatrix = Matrix(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
  final Matrix _identityMatrix = Matrix.fromIdentity();
  final Matrix _transformMatrix = Matrix.fromIdentity();
  final Map<Slot, _SlotDisplayObject> _slotDisplayObjects = {};
  final Set<Warp> _slotContainers = {};

  static final Float32List _vertices = Float32List(2048);
  static final SkeletonClipping _clipping = SkeletonClipping();

  SkeletonBoundsCalculation boundsCalculation = SkeletonBoundsCalculation.none;

  SkeletonDisplayObject(SkeletonData skeletonData) : skeleton = Skeleton(skeletonData) {
    skeleton.updateWorldTransform();
  }

  //---------------------------------------------------------------------------

  /// Adds [displayObject] at [slotName] in the skeleton draw order.
  ///
  /// The display object keeps its local transform while an internal container
  /// follows the slot's bone. By default, the display object replaces the
  /// slot's Spine attachment visually. The Spine attachment remains assigned,
  /// so removing the display object restores the attachment's current state.
  void addSlotObject(
    String slotName,
    DisplayObject displayObject, {
    bool replaceAttachment = true,
    bool followAttachmentTimeline = false,
  }) {
    final slotIndex = skeleton.findSlotIndex(slotName);
    if (slotIndex < 0) throw ArgumentError.value(slotName, 'slotName', 'Slot not found.');
    addSlotObjectForSlot(
      skeleton.slots[slotIndex],
      displayObject,
      replaceAttachment: replaceAttachment,
      followAttachmentTimeline: followAttachmentTimeline,
    );
  }

  /// Adds [displayObject] at [slot] in the skeleton draw order.
  void addSlotObjectForSlot(
    Slot slot,
    DisplayObject displayObject, {
    bool replaceAttachment = true,
    bool followAttachmentTimeline = false,
  }) {
    if (!identical(slot.skeleton, skeleton)) {
      throw ArgumentError.value(slot, 'slot', 'The slot belongs to a different skeleton.');
    }
    if (identical(displayObject, this) ||
        displayObject is DisplayObjectContainer && displayObject.contains(this)) {
      throw ArgumentError.value(displayObject, 'displayObject', 'A skeleton cannot contain itself.');
    }

    Slot? previousSlot;
    for (final entry in _slotDisplayObjects.entries) {
      if (identical(entry.value.displayObject, displayObject)) {
        previousSlot = entry.key;
        break;
      }
    }
    if (previousSlot != null) _removeSlotObjectForSlot(previousSlot);
    _removeSlotObjectForSlot(slot);

    final container = Warp()..name = '${slot.data.name}:slot-object';
    final slotDisplayObject = _SlotDisplayObject(
      slot,
      displayObject,
      container,
      replaceAttachment,
      followAttachmentTimeline,
    );
    _slotDisplayObjects[slot] = slotDisplayObject;
    _slotContainers.add(container);
    addChild(container);
    container.addChild(displayObject);
    _updateSlotObject(slotDisplayObject);
  }

  /// Returns the display object attached to [slotName], if any.
  DisplayObject? getSlotObject(String slotName) {
    final slotIndex = skeleton.findSlotIndex(slotName);
    if (slotIndex < 0) throw ArgumentError.value(slotName, 'slotName', 'Slot not found.');
    return _slotDisplayObjects[skeleton.slots[slotIndex]]?.displayObject;
  }

  /// Removes and returns the display object attached to [slotName], if any.
  DisplayObject? removeSlotObject(String slotName) {
    final slotIndex = skeleton.findSlotIndex(slotName);
    if (slotIndex < 0) throw ArgumentError.value(slotName, 'slotName', 'Slot not found.');
    return _removeSlotObjectForSlot(skeleton.slots[slotIndex]);
  }

  /// Removes every display object attached to a skeleton slot.
  void removeSlotObjects() {
    for (final slot in _slotDisplayObjects.keys.toList()) {
      _removeSlotObjectForSlot(slot);
    }
  }

  DisplayObject? _removeSlotObjectForSlot(Slot slot) {
    final slotDisplayObject = _slotDisplayObjects.remove(slot);
    if (slotDisplayObject == null) return null;

    final container = slotDisplayObject.container;
    final displayObject = slotDisplayObject.displayObject;
    _slotContainers.remove(container);
    if (identical(displayObject.parent, container)) container.removeChild(displayObject);
    if (identical(container.parent, this)) removeChild(container);
    return displayObject;
  }

  void _updateSlotObjects() {
    for (final slotDisplayObject in _slotDisplayObjects.values) {
      _updateSlotObject(slotDisplayObject);
    }
  }

  void _updateSlotObject(_SlotDisplayObject slotDisplayObject) {
    final slot = slotDisplayObject.slot;
    final bone = slot.bone;
    final matrix = slotDisplayObject.container.matrix;
    final a = bone.a;
    final b = 0.0 - bone.c;
    final c = 0.0 - bone.b;
    final d = bone.d;
    final tx = bone.worldX;
    final ty = 0.0 - bone.worldY;

    if (matrix.a != a || matrix.b != b || matrix.c != c || matrix.d != d || matrix.tx != tx || matrix.ty != ty) {
      matrix.setTo(a, b, c, d, tx, ty);
    }

    final alpha = skeleton.color.a * slot.color.a;
    if (slotDisplayObject.container.alpha != alpha) slotDisplayObject.container.alpha = alpha;
    if (slotDisplayObject.container.blendMode != slot.data.blendMode) {
      slotDisplayObject.container.blendMode = slot.data.blendMode;
    }

    final visible = !slotDisplayObject.followAttachmentTimeline || slot.attachment != null;
    if (slotDisplayObject.container.visible != visible) slotDisplayObject.container.visible = visible;
  }

  //---------------------------------------------------------------------------

  @override
  Rectangle<num> get bounds {
    _updateSlotObjects();
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

    final skeletonBounds = Rectangle<num>(minX, 0.0 - maxY, maxX - minX, maxY - minY);
    if (numChildren == 0) return skeletonBounds;
    final childBounds = super.bounds;
    return offset == 0 ? childBounds : skeletonBounds.boundingBox(childBounds);
  }

  @override
  DisplayObject? hitTestInput(num localX, num localY) {
    _updateSlotObjects();
    final childHit = super.hitTestInput(localX, localY);
    if (childHit != null) return mouseChildren ? childHit : this;

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
    Slot? clippingSlot;
    renderContext.activateRenderProgram(renderProgram);

    for (var s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final attachment = slot.attachment;
      final slotDisplayObject = _slotDisplayObjects[slot];
      final renderAttachment = slotDisplayObject == null || !slotDisplayObject.replaceAttachment;

      if (renderAttachment && attachment is RenderAttachment) {
        final alpha = attachment.color.a * skeletonA * slot.color.a;
        if (alpha > 0 && attachment.ixList.isNotEmpty) {
          final bitmapData = attachment.updateRenderGeometry(slot);

          renderState.push(_skeletonMatrix, 1.0, renderState.globalBlendMode);
          renderContext.activateRenderProgram(renderProgram);
          renderContext.activateBlendMode(slot.data.blendMode);
          renderProgram.renderTextureMesh(
              renderState,
              renderContext,
              bitmapData.renderTexture,
              attachment.ixList,
              attachment.vxList,
              attachment.color.r * skeletonR * slot.color.r,
              attachment.color.g * skeletonG * slot.color.g,
              attachment.color.b * skeletonB * slot.color.b,
              attachment.color.a * skeletonA * slot.color.a,
              blendMode: slot.data.blendMode);
          renderState.pop();
        }
      } else if (renderAttachment && attachment is ClippingAttachment) {
        final length = attachment.worldVerticesLength;
        attachment.computeWorldVertices2(slot, 0, length, vertices, 0, 2);
        clipping.vertices = vertices.buffer.asFloat32List(0, length);
        renderState.push(_skeletonMatrix, 1.0, renderState.globalBlendMode);
        renderContext.beginRenderMask(renderState, clipping);
        renderState.pop();
        renderContext.activateRenderProgram(renderProgram);
        clippingAttachment = attachment;
        clippingSlot = slot;
      }

      if (slotDisplayObject != null) {
        _updateSlotObject(slotDisplayObject);
        final container = slotDisplayObject.container;
        if (container.visible && !container.off) renderState.renderObject(container);
      }

      if (clippingAttachment != null) {
        if (s == slots.length - 1 || (clippingAttachment.endSlot == slot.data && slot != clippingSlot)) {
          renderContext.endRenderMask(renderState, clipping);
          renderContext.activateRenderProgram(renderProgram);
          clippingAttachment = null;
          clippingSlot = null;
        }
      }
    }

    _renderDirectChildren(renderState);
  }

  void _renderCanvas(RenderState renderState) {
    final renderContext = renderState.renderContext as RenderContextCanvas;
    final vertices = _vertices;
    final clipping = _clipping;
    final transform = _transformMatrix;
    final slots = skeleton.drawOrder;

    ClippingAttachment? clippingAttachment;
    Slot? clippingSlot;

    for (var s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final attachment = slot.attachment;
      final slotDisplayObject = _slotDisplayObjects[slot];
      final renderAttachment = slotDisplayObject == null || !slotDisplayObject.replaceAttachment;

      if (renderAttachment && attachment is RegionAttachment) {
        final b = slot.bone;
        final bitmapData = attachment.currentBitmapData(slot);
        transform.setTo(b.a, b.c, b.b, b.d, b.worldX, b.worldY);
        transform.prepend(attachment.transformationMatrix);
        renderState.push(_skeletonMatrix, skeleton.color.a, renderState.globalBlendMode);
        renderState.push(transform, attachment.color.a * slot.color.a, slot.data.blendMode);
        renderState.renderTextureQuad(bitmapData.renderTextureQuad);
        renderState.pop();
        renderState.pop();
      } else if (renderAttachment && attachment is RenderAttachment) {
        final bitmapData = attachment.updateRenderGeometry(slot);
        final ixList = attachment.ixList;
        final vxList = attachment.vxList;
        final alpha = attachment.color.a * slot.color.a;
        final renderTexture = bitmapData.renderTexture;
        renderState.push(_skeletonMatrix, skeleton.color.a, renderState.globalBlendMode);
        renderState.push(_identityMatrix, alpha, slot.data.blendMode);
        renderState.renderTextureMesh(renderTexture, ixList, vxList);
        renderState.pop();
        renderState.pop();
      } else if (renderAttachment && attachment is ClippingAttachment) {
        final length = attachment.worldVerticesLength;
        attachment.computeWorldVertices2(slot, 0, length, vertices, 0, 2);
        clipping.vertices = vertices.buffer.asFloat32List(0, length);
        renderState.push(_skeletonMatrix, skeleton.color.a, renderState.globalBlendMode);
        renderContext.beginRenderMask(renderState, clipping);
        renderState.pop();
        clippingAttachment = attachment;
        clippingSlot = slot;
      }

      if (slotDisplayObject != null) {
        _updateSlotObject(slotDisplayObject);
        final container = slotDisplayObject.container;
        if (container.visible && !container.off) renderState.renderObject(container);
      }

      if (clippingAttachment != null) {
        if (s == slots.length - 1 || (clippingAttachment.endSlot == slot.data && slot != clippingSlot)) {
          renderContext.endRenderMask(renderState, clipping);
          clippingAttachment = null;
          clippingSlot = null;
        }
      }
    }

    _renderDirectChildren(renderState);
  }

  void _renderDirectChildren(RenderState renderState) {
    for (final child in children) {
      if (!_slotContainers.contains(child) && child.visible && !child.off) {
        renderState.renderObject(child);
      }
    }
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

class _SlotDisplayObject {
  final Slot slot;
  final DisplayObject displayObject;
  final Warp container;
  final bool replaceAttachment;
  final bool followAttachmentTimeline;

  _SlotDisplayObject(
    this.slot,
    this.displayObject,
    this.container,
    this.replaceAttachment,
    this.followAttachmentTimeline,
  );
}
