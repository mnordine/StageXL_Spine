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

part of '../stagexl_spine.dart';

extension on Object? {
  // ignore: cast_nullable_to_non_nullable
  List<T> getList<T>() => this == null ? [] : List<T>.from(this as List);

  Json get json => this as Json? ?? {};
}

class SkeletonLoader {
  final AttachmentLoader attachmentLoader;
  final List<_LinkedMesh> _linkedMeshes = [];

  SkeletonLoader(this.attachmentLoader);

  /// Parameter 'object' must be a String or Map.
  ///
  SkeletonData readSkeletonData(Object? object, [String? name]) {
    Json root;

    if (object == null) {
      throw ArgumentError('object cannot be null.');
    } else if (object is String) {
      root = jsonDecode(object) as Json;
    } else if (object is Json) {
      root = object;
    } else {
      throw ArgumentError('object must be a String or Map.');
    }

    final skeletonData = SkeletonData();
    skeletonData.name = name;

    // Skeleton

    final skeletonMap = root['skeleton'] as Json?;

    if (skeletonMap != null) {
      skeletonData.version = _getString(skeletonMap, 'spine', '')!;
      skeletonData.hash = _getString(skeletonMap, 'hash', '')!;
      skeletonData.width = _getDouble(skeletonMap, 'width', 0);
      skeletonData.height = _getDouble(skeletonMap, 'height', 0);
      skeletonData.fps = _getDouble(skeletonMap, 'fps', 0);
      skeletonData.imagesPath = _getString(skeletonMap, 'images', '')!;
    }

    // Bones

    for (final boneMap in root['bones'].getList<Json>()) {
      BoneData? parent;

      final parentName = _getString(boneMap, 'parent', null);
      if (parentName != null) {
        parent = skeletonData.findBone(parentName);
        if (parent == null) throw StateError('Parent bone not found: $parentName');
      }

      final boneIndex = skeletonData.bones.length;
      final boneName = _getString(boneMap, 'name', null);
      if (boneName == null)
        continue;

      final boneData = BoneData(boneIndex, boneName, parent);
      final transformMode = "TransformMode.${_getString(boneMap, "transform", "normal")!}";

      boneData.length = _getDouble(boneMap, 'length', 0);
      boneData.x = _getDouble(boneMap, 'x', 0);
      boneData.y = _getDouble(boneMap, 'y', 0);
      boneData.rotation = _getDouble(boneMap, 'rotation', 0);
      boneData.scaleX = _getDouble(boneMap, 'scaleX', 1);
      boneData.scaleY = _getDouble(boneMap, 'scaleY', 1);
      boneData.shearX = _getDouble(boneMap, 'shearX', 0);
      boneData.shearY = _getDouble(boneMap, 'shearY', 0);
      boneData.transformMode =
          TransformMode.values.firstWhere((e) => e.toString() == transformMode);
      skeletonData.bones.add(boneData);
    }

    // Slots

    for (final slotMap in root['slots'].getList<Json>()) {
      final slotName = _getString(slotMap, 'name', null);
      final boneName = _getString(slotMap, 'bone', null);
      if (slotName == null || boneName == null)
        continue;

      final boneData = skeletonData.findBone(boneName);
      if (boneData == null) throw StateError('Slot bone not found: $boneName');

      final slotIndex = skeletonData.slots.length;
      final slotData = SlotData(slotIndex, slotName, boneData);
      slotData.color.setFromString(_getString(slotMap, 'color', 'FFFFFFFF')!);
      slotData.attachmentName = _getString(slotMap, 'attachment', null);

      if (slotMap.containsKey('dark')) {
        slotData.darkColor =
          SpineColor(1, 1, 1, 0)..setFromString(_getString(slotMap, 'dark', 'FFFFFF')!);
      }

      switch (_getString(slotMap, 'blend', 'normal')) {
        case 'normal':
          slotData.blendMode = BlendMode.NORMAL;
        case 'additive':
          slotData.blendMode = BlendMode.ADD;
        case 'multiply':
          slotData.blendMode = BlendMode.MULTIPLY;
        case 'screen':
          slotData.blendMode = BlendMode.SCREEN;
      }

      skeletonData.slots.add(slotData);
    }

    // IK constraints.

    for (final constraintMap in root['ik'].getList<Json>()) {
      final constraintName = _getString(constraintMap, 'name', null);
      if (constraintName == null)
        continue;

      final constraintData = IkConstraintData(constraintName);

      for (final boneName in constraintMap['bones'].getList<String>()) {
        final bone = skeletonData.findBone(boneName);
        if (bone == null) throw StateError('IK constraint bone not found: $boneName');
        constraintData.bones.add(bone);
      }

      final targetName = _getString(constraintMap, 'target', null);
      if (targetName == null)
        continue;

      final target = skeletonData.findBone(targetName);
      if (target == null) throw StateError('Target bone not found: $targetName');

      constraintData.target = target;
      constraintData.order = _getInt(constraintMap, 'order', 0);
      constraintData.bendDirection = _getBool(constraintMap, 'bendPositive', true) ? 1 : -1;
      constraintData.mix = _getDouble(constraintMap, 'mix', 1);

      skeletonData.ikConstraints.add(constraintData);
    }

    // Transform constraints.

    for (final constraintMap in root['transform'].getList<Json>()) {
      final constraintName = _getString(constraintMap, 'name', null);
      if (constraintName == null)
        continue;

      final constraintData = TransformConstraintData(constraintName);

      for (final boneName in constraintMap['bones'].getList<String>()) {
        final bone = skeletonData.findBone(boneName);
        if (bone == null) throw StateError('Transform constraint bone not found: $boneName');
        constraintData.bones.add(bone);
      }

      final targetName = _getString(constraintMap, 'target', null);
      if (targetName == null)
        continue;

      final target = skeletonData.findBone(targetName);
      if (target == null) throw StateError('Target bone not found: $targetName');

      constraintData.target = target;
      constraintData.local = _getBool(constraintMap, 'local', false);
      constraintData.relative = _getBool(constraintMap, 'relative', false);
      constraintData.order = _getInt(constraintMap, 'order', 0);
      constraintData.offsetRotation = _getDouble(constraintMap, 'rotation', 0);
      constraintData.offsetX = _getDouble(constraintMap, 'x', 0);
      constraintData.offsetY = _getDouble(constraintMap, 'y', 0);
      constraintData.offsetScaleX = _getDouble(constraintMap, 'scaleX', 0);
      constraintData.offsetScaleY = _getDouble(constraintMap, 'scaleY', 0);
      constraintData.offsetShearY = _getDouble(constraintMap, 'shearY', 0);
      constraintData.rotateMix = _getDouble(constraintMap, 'rotateMix', 1);
      constraintData.translateMix = _getDouble(constraintMap, 'translateMix', 1);
      constraintData.scaleMix = _getDouble(constraintMap, 'scaleMix', 1);
      constraintData.shearMix = _getDouble(constraintMap, 'shearMix', 1);

      skeletonData.transformConstraints.add(constraintData);
    }

    // Path constraints.

    for (final constraintMap in root['path'].getList<Json>()) {
      final constraintName = _getString(constraintMap, 'name', null);
      if (constraintName == null)
        continue;

      final pathConstraintData = PathConstraintData(constraintName);

      for (final boneName in constraintMap['bones'].getList<String>()) {
        final bone = skeletonData.findBone(boneName);
        if (bone == null) throw StateError('Path constraint bone not found: $boneName');
        pathConstraintData.bones.add(bone);
      }

      final targetName = _getString(constraintMap, 'target', null);
      if (targetName == null)
        continue;

      final target = skeletonData.findSlot(targetName);
      if (target == null) throw StateError('Path target slot not found: $targetName');

      final positionMode = PositionMode.fromString(constraintMap['positionMode'] as String?) ?? PositionMode.percent;
      final spacingMode = SpacingMode.fromString(constraintMap['spacingMode'] as String?) ?? SpacingMode.length;  
      final rotateMode = RotateMode.fromString(constraintMap['rotateMode'] as String?) ?? RotateMode.tangent;

      pathConstraintData.target = target;
      pathConstraintData.order = _getInt(constraintMap, 'order', 0);
      pathConstraintData.positionMode = positionMode;
      pathConstraintData.spacingMode = spacingMode;
      pathConstraintData.rotateMode = rotateMode;
      pathConstraintData.offsetRotation = _getDouble(constraintMap, 'rotation', 0);
      pathConstraintData.position = _getDouble(constraintMap, 'position', 0);
      pathConstraintData.spacing = _getDouble(constraintMap, 'spacing', 0);
      pathConstraintData.rotateMix = _getDouble(constraintMap, 'rotateMix', 1);
      pathConstraintData.translateMix = _getDouble(constraintMap, 'translateMix', 1);

      skeletonData.pathConstraints.add(pathConstraintData);
    }

    // Skins

    final skins = root['skins'].json;

    for (final skinName in skins.keys) {
      final skinMap = skins[skinName]! as Json;
      final skin = Skin(skinName);
      for (final slotName in skinMap.keys) {
        final slotIndex = skeletonData.findSlotIndex(slotName);
        final slotEntry = skinMap[slotName]! as Json;
        for (final attachmentName in slotEntry.keys) {
          final map = slotEntry[attachmentName]! as Json;
          final attachment = readAttachment(map, skin, slotIndex, attachmentName, skeletonData);
          if (attachment != null) skin.addAttachment(slotIndex, attachmentName, attachment);
        }
      }
      skeletonData.skins.add(skin);
      if (skin.name == 'default') skeletonData.defaultSkin = skin;
    }

    // Linked meshes.

    for (final linkedMesh in _linkedMeshes) {
      final parentSkin = linkedMesh.skin == null
          ? skeletonData.defaultSkin
          : skeletonData.findSkin(linkedMesh.skin!);
      if (parentSkin == null) throw StateError('Skin not found: ${linkedMesh.skin}');
      final parentMesh = parentSkin.getAttachment(linkedMesh.slotIndex, linkedMesh.parent);
      if (parentMesh == null) throw StateError('Parent mesh not found: ${linkedMesh.parent}');
      linkedMesh.mesh.parentMesh = parentMesh as MeshAttachment;
      linkedMesh.mesh.initRenderGeometry();
    }

    _linkedMeshes.clear();

    // Events

    final events = root['events'].json;

    for (final eventName in events.keys) {
      final eventMap = events[eventName]! as Json;
      final eventData = EventData(eventName);
      eventData.intValue = _getInt(eventMap, 'int', 0);
      eventData.floatValue = _getDouble(eventMap, 'float', 0);
      eventData.stringValue = _getString(eventMap, 'string', null);
      skeletonData.events.add(eventData);
    }

    // Animations

    final animations = root['animations'].json;

    for (final animationName in animations.keys) {
      final map = animations[animationName]! as Json;
      _readAnimation(map, animationName, skeletonData);
    }

    return skeletonData;
  }

  //---------------------------------------------------------------------------

  Attachment? readAttachment(
      Json map, Skin skin, int slotIndex, String name, SkeletonData skeletonData) {
    name = _getString(map, 'name', name)!;

    final typeName = "AttachmentType.${_getString(map, "type", "region")!}";
    final type = AttachmentType.values.firstWhere((e) => e.toString() == typeName);
    final path = _getString(map, 'path', name)!;

    switch (type) {
      case AttachmentType.region:
        final region = attachmentLoader.newRegionAttachment(skin, name, path);
        if (region == null) return null;

        region.x = _getDouble(map, 'x', 0);
        region.y = _getDouble(map, 'y', 0);
        region.scaleX = _getDouble(map, 'scaleX', 1);
        region.scaleY = _getDouble(map, 'scaleY', 1);
        region.rotation = _getDouble(map, 'rotation', 0);
        region.width = _getDouble(map, 'width', 0);
        region.height = _getDouble(map, 'height', 0);
        region.color.setFromString(_getString(map, 'color', 'FFFFFFFF')!);
        region.update();

        return region;

      case AttachmentType.regionsequence:
        // Currently not supported
        return null;

      case AttachmentType.mesh:
      case AttachmentType.linkedmesh:
        final mesh = attachmentLoader.newMeshAttachment(skin, name, path);
        if (mesh == null) return null;

        mesh.color.setFromString(_getString(map, 'color', 'FFFFFFFF')!);
        mesh.width = _getDouble(map, 'width', 0);
        mesh.height = _getDouble(map, 'height', 0);

        final parentName = _getString(map, 'parent', null);

        if (parentName != null) {
          final skinName = _getString(map, 'skin', null);
          final lm = _LinkedMesh(mesh, skinName, slotIndex, parentName);
          _linkedMeshes.add(lm);
          mesh.inheritDeform = _getBool(map, 'deform', true);
          return mesh;
        }

        final uvs = _getFloat32List(map, 'uvs');
        _readVertices(map, mesh, uvs.length);

        mesh.triangles = _getInt16List(map, 'triangles');
        mesh.regionUVs = uvs;
        mesh.initRenderGeometry();

        mesh.hullLength = _getInt(map, 'hull', 0) * 2;
        if (map.containsKey('edges')) mesh.edges = _getInt16List(map, 'edges');

        return mesh;

      case AttachmentType.boundingbox:
        final box = attachmentLoader.newBoundingBoxAttachment(skin, name);
        if (box == null) return null;
        final vertexCount = _getInt(map, 'vertexCount', 0);
        _readVertices(map, box, vertexCount << 1);
        return box;

      case AttachmentType.path:
        final path = attachmentLoader.newPathAttachment(skin, name);
        if (path == null) return null;

        path.closed = _getBool(map, 'closed', false);
        path.constantSpeed = _getBool(map, 'constantSpeed', true);
        path.lengths = _getFloat32List(map, 'lengths');

        final vertexCount = _getInt(map, 'vertexCount', 0);
        _readVertices(map, path, vertexCount << 1);

        return path;

      case AttachmentType.point:
        final point = attachmentLoader.newPointAttachment(skin, name);
        if (point == null) return null;

        point.x = _getDouble(map, 'x', 0);
        point.y = _getDouble(map, 'y', 0);
        point.rotation = _getDouble(map, 'rotation', 0);
        point.color.setFromString(_getString(map, 'color', 'FFFFFFFF')!);
        return point;

      case AttachmentType.clipping:
        final clip = attachmentLoader.newClippingAttachment(skin, name);
        if (clip == null) return null;

        final end = _getString(map, 'end', null);
        final vertexCount = _getInt(map, 'vertexCount', 0);

        if (end != null) {
          final slot = skeletonData.findSlot(end);
          if (slot == null) throw StateError('Clipping end slot not found: $end');
          clip.endSlot = slot;
        }

        clip.color.setFromString(_getString(map, 'color', 'FFFFFFFF')!);
        _readVertices(map, clip, vertexCount << 1);
        return clip;
    }
  }

  //---------------------------------------------------------------------------

  void _readVertices(Json map, VertexAttachment attachment, int verticesLength) {
    attachment.worldVerticesLength = verticesLength;

    final vertices = _getFloat32List(map, 'vertices');
    final weights = <double>[];
    final bones = <int>[];

    if (verticesLength == vertices.length) {
      attachment.vertices = vertices;
      return;
    }

    for (var i = 0; i < vertices.length;) {
      final boneCount = vertices[i++].toInt();
      bones.add(boneCount);
      for (final nn = i + boneCount * 4; i < nn; i += 4) {
        bones.add(vertices[i + 0].toInt());
        weights.add(vertices[i + 1]);
        weights.add(vertices[i + 2]);
        weights.add(vertices[i + 3]);
      }
    }

    attachment.vertices = Float32List.fromList(weights);
    attachment.bones = Int16List.fromList(bones);
  }

  //---------------------------------------------------------------------------

  void _readAnimation(Json map, String name, SkeletonData skeletonData) {
    final timelines = <Timeline>[];
    double duration = 0;

    //-------------------------------------

    final slots = map['slots'].json;

    for (final slotName in slots.keys) {
      final slotMap = slots[slotName]! as Json;
      final slotIndex = skeletonData.findSlotIndex(slotName);

      for (final timelineName in slotMap.keys) {
        final values = slotMap[timelineName].getList<Json>();

        if (timelineName == 'attachment') {
          final attachmentTimeline = AttachmentTimeline(values.length);
          attachmentTimeline.slotIndex = slotIndex;

          var frameIndex = 0;
          for (final valueMap in values) {
            final time = _getDouble(valueMap, 'time', 0);
            final name = _getString(valueMap, 'name', null);
            attachmentTimeline.setFrame(frameIndex, time, name);
            frameIndex++;
          }

          timelines.add(attachmentTimeline);
          duration =
              math.max(duration, attachmentTimeline.frames[attachmentTimeline.frameCount - 1]);
        } else if (timelineName == 'color') {
          final colorTimeline = ColorTimeline(values.length);
          colorTimeline.slotIndex = slotIndex;

          var frameIndex = 0;
          for (final valueMap in values) {
            final time = _getDouble(valueMap, 'time', 0);
            final color = SpineColor(1, 1, 1, 1);
            color.setFromString(_getString(valueMap, 'color', 'FFFFFFFF')!);
            colorTimeline.setFrame(frameIndex, time, color.r, color.g, color.b, color.a);
            _readCurve(valueMap, colorTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(colorTimeline);
          duration = math.max(duration,
              colorTimeline.frames[(colorTimeline.frameCount - 1) * ColorTimeline._entries]);
        } else if (timelineName == 'twoColor') {
          final twoColorTimeline = TwoColorTimeline(values.length);
          twoColorTimeline.slotIndex = slotIndex;

          var frameIndex = 0;
          for (final valueMap in values) {
            final time = _getDouble(valueMap, 'time', 0);
            final cl = SpineColor(1, 1, 1, 1);
            final cd = SpineColor(1, 1, 1, 1);
            cl.setFromString(_getString(valueMap, 'light', 'FFFFFFFF')!);
            cd.setFromString(_getString(valueMap, 'dark', 'FFFFFFFF')!);
            twoColorTimeline.setFrame(frameIndex, time, cl.r, cl.g, cl.b, cl.a, cd.r, cd.g, cd.b);
            _readCurve(valueMap, twoColorTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(twoColorTimeline);
          duration = math.max(
              duration,
              twoColorTimeline
                  .frames[(twoColorTimeline.frameCount - 1) * TwoColorTimeline._entries]);
        } else {
          throw StateError('Invalid timeline type for a slot: $timelineName ($slotName)');
        }
      }
    }

    //-------------------------------------

    final bones = map['bones'].json;

    for (final boneName in bones.keys) {
      final boneIndex = skeletonData.findBoneIndex(boneName);
      if (boneIndex == -1) throw StateError('Bone not found: $boneName');

      final boneMap = bones[boneName]! as Json;

      for (final timelineName in boneMap.keys) {
        final values = boneMap[timelineName].getList<Json>();

        if (timelineName == 'rotate') {
          final rotateTimeline = RotateTimeline(values.length);
          rotateTimeline.boneIndex = boneIndex;

          var frameIndex = 0;
          for (final valueMap in values) {
            final time = _getDouble(valueMap, 'time', 0);
            final degrees = _getDouble(valueMap, 'angle', 0);
            rotateTimeline.setFrame(frameIndex, time, degrees);
            _readCurve(valueMap, rotateTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(rotateTimeline);
          duration = math.max(duration,
              rotateTimeline.frames[(rotateTimeline.frameCount - 1) * RotateTimeline._entries]);
        } else if (timelineName == 'translate' ||
            timelineName == 'scale' ||
            timelineName == 'shear') {
          TranslateTimeline translateTimeline;

          if (timelineName == 'scale') {
            translateTimeline = ScaleTimeline(values.length);
          } else if (timelineName == 'shear') {
            translateTimeline = ShearTimeline(values.length);
          } else {
            translateTimeline = TranslateTimeline(values.length);
          }

          translateTimeline.boneIndex = boneIndex;

          var frameIndex = 0;
          for (final valueMap in values) {
            final x = _getDouble(valueMap, 'x', 0);
            final y = _getDouble(valueMap, 'y', 0);
            final time = _getDouble(valueMap, 'time', 0);
            translateTimeline.setFrame(frameIndex, time, x, y);
            _readCurve(valueMap, translateTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(translateTimeline);
          duration = math.max(
              duration,
              translateTimeline
                  .frames[(translateTimeline.frameCount - 1) * TranslateTimeline._entries]);
        } else {
          throw StateError('Invalid timeline type for a bone: $timelineName ($boneName)');
        }
      }
    }

    //-------------------------------------

    final ikMap = map['ik'].json;

    for (final ikConstraintName in ikMap.keys) {
      final ikConstraint = skeletonData.findIkConstraint(ikConstraintName)!;
      final valueMaps = ikMap[ikConstraintName].getList<Json>();
      final ikTimeline = IkConstraintTimeline(valueMaps.length);
      ikTimeline.ikConstraintIndex = skeletonData.ikConstraints.indexOf(ikConstraint);
      var frameIndex = 0;
      for (final valueMap in valueMaps) {
        final time = _getDouble(valueMap, 'time', 0);
        final mix = _getDouble(valueMap, 'mix', 1);
        final bendDirection = _getBool(valueMap, 'bendPositive', true) ? 1 : -1;
        ikTimeline.setFrame(frameIndex, time, mix, bendDirection);
        _readCurve(valueMap, ikTimeline, frameIndex);
        frameIndex++;
      }
      timelines.add(ikTimeline);
      duration = math.max(
          duration, ikTimeline.frames[(ikTimeline.frameCount - 1) * IkConstraintTimeline._entries]);
    }

    //-------------------------------------

    final transformMap = map['transform'].json;

    for (final transformName in transformMap.keys) {
      final transformConstraint =
          skeletonData.findTransformConstraint(transformName)!;
      final valueMaps = transformMap[transformName].getList<Json>();
      final transformTimeline = TransformConstraintTimeline(valueMaps.length);
      transformTimeline.transformConstraintIndex =
          skeletonData.transformConstraints.indexOf(transformConstraint);
      var frameIndex = 0;
      for (final valueMap in valueMaps) {
        final rotateMix = _getDouble(valueMap, 'rotateMix', 1);
        final translateMix = _getDouble(valueMap, 'translateMix', 1);
        final scaleMix = _getDouble(valueMap, 'scaleMix', 1);
        final shearMix = _getDouble(valueMap, 'shearMix', 1);
        final time = _getDouble(valueMap, 'time', 0);
        transformTimeline.setFrame(frameIndex, time, rotateMix, translateMix, scaleMix, shearMix);
        _readCurve(valueMap, transformTimeline, frameIndex);
        frameIndex++;
      }
      timelines.add(transformTimeline);
      duration = math.max(
          duration,
          transformTimeline
              .frames[(transformTimeline.frameCount - 1) * TransformConstraintTimeline._entries]);
    }

    //-------------------------------------

    final pathsMaps = map['paths'].json;

    for (final pathName in pathsMaps.keys) {
      final index = skeletonData.findPathConstraintIndex(pathName);
      if (index == -1) throw StateError('Path constraint not found: $pathName');

      final pathMap = pathsMaps[pathName]! as Json;
      for (final timelineName in pathMap.keys) {
        final valueMaps = pathMap[timelineName].getList<Json>();

        if (timelineName == 'position' || timelineName == 'spacing') {
          PathConstraintPositionTimeline pathTimeline;

          if (timelineName == 'spacing') {
            pathTimeline = PathConstraintSpacingTimeline(valueMaps.length);
          } else {
            pathTimeline = PathConstraintPositionTimeline(valueMaps.length);
          }

          pathTimeline.pathConstraintIndex = index;
          var frameIndex = 0;

          for (final valueMap in valueMaps) {
            final value = _getDouble(valueMap, timelineName, 0);
            final time = _getDouble(valueMap, 'time', 0);
            pathTimeline.setFrame(frameIndex, time, value);
            _readCurve(valueMap, pathTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(pathTimeline);
          duration = math.max(
              duration,
              pathTimeline
                  .frames[(pathTimeline.frameCount - 1) * PathConstraintPositionTimeline._entries]);
        } else if (timelineName == 'mix') {
          final pathMixTimeline = PathConstraintMixTimeline(valueMaps.length);
          pathMixTimeline.pathConstraintIndex = index;
          var frameIndex = 0;

          for (final valueMap in valueMaps) {
            final rotateMix = _getDouble(valueMap, 'rotateMix', 1);
            final translateMix = _getDouble(valueMap, 'translateMix', 1);
            final time = _getDouble(valueMap, 'time', 0);
            pathMixTimeline.setFrame(frameIndex, time, rotateMix, translateMix);
            _readCurve(valueMap, pathMixTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(pathMixTimeline);
          duration = math.max(
              duration,
              pathMixTimeline
                  .frames[(pathMixTimeline.frameCount - 1) * PathConstraintMixTimeline._entries]);
        }
      }
    }

    //-------------------------------------

    final deformMap = map['deform'].json;

    for (final skinName in deformMap.keys) {
      final skin = skeletonData.findSkin(skinName)!;
      final slotMap = deformMap[skinName]! as Json;

      for (final slotName in slotMap.keys) {
        final slotIndex = skeletonData.findSlotIndex(slotName);
        final timelineMap = slotMap[slotName]! as Json;

        for (final timelineName in timelineMap.keys) {
          final valueMaps = timelineMap[timelineName].getList<Json>();
          final attachment = skin.getAttachment(slotIndex, timelineName) as VertexAttachment?;
          if (attachment == null) throw StateError('Deform attachment not found: $timelineName');

          final weighted = attachment.bones != null;
          final vertices = attachment.vertices;
          final deformLength = weighted ? vertices.length ~/ 3 * 2 : vertices.length;
          var frameIndex = 0;

          final deformTimeline = DeformTimeline(valueMaps.length, attachment);
          deformTimeline.slotIndex = slotIndex;

          for (final valueMap in valueMaps) {
            Float32List deform;
            final verticesValue = valueMap['vertices'];
            if (verticesValue == null) {
              deform = weighted ? Float32List(deformLength) : vertices;
            } else {
              deform = Float32List(deformLength);
              final start = _getInt(valueMap, 'offset', 0);
              final temp = _getFloat32List(valueMap, 'vertices');
              for (var i = 0; i < temp.length; i++) {
                deform[start + i] = temp[i];
              }
              if (!weighted) {
                for (var i = 0; i < deformLength; i++) {
                  deform[i] += vertices[i];
                }
              }
            }
            final time = _getDouble(valueMap, 'time', 0);
            deformTimeline.setFrame(frameIndex, time, deform);
            _readCurve(valueMap, deformTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(deformTimeline);
          duration = math.max(duration, deformTimeline.frames[deformTimeline.frameCount - 1]);
        }
      }
    }

    //-------------------------------------

    final drawOrderValues = (map['drawOrder'] ?? map['draworder']).getList<Json>();

    if (drawOrderValues.isNotEmpty) {
      final drawOrderTimeline = DrawOrderTimeline(drawOrderValues.length);
      final slotCount = skeletonData.slots.length;
      var frameIndex = 0;

      for (final drawOrderMap in drawOrderValues) {
        final time = _getDouble(drawOrderMap, 'time', 0);
        Int16List? drawOrder;

        if (drawOrderMap.containsKey('offsets')) {
          drawOrder = Int16List(slotCount);
          for (var i = 0; i < drawOrder.length; i++) {
            drawOrder[i] = -1;
          }

          final offsetMaps = drawOrderMap['offsets'].getList<Json>();
          final unchanged = Int16List(slotCount - offsetMaps.length);
          var originalIndex = 0;
          var unchangedIndex = 0;

          for (final offsetMap in offsetMaps) {
            final slotName = _getString(offsetMap, 'slot', null);
            if (slotName == null)
              continue;

            final slotIndex = skeletonData.findSlotIndex(slotName);
            if (slotIndex == -1) throw StateError('Slot not found: $slotName');
            // Collect unchanged items.
            while (originalIndex != slotIndex) {
              unchanged[unchangedIndex++] = originalIndex++;
            }
            // Set changed items.
            drawOrder[originalIndex + (offsetMap['offset']! as int)] = originalIndex++;
          }

          // Collect remaining unchanged items.
          while (originalIndex < slotCount) {
            unchanged[unchangedIndex++] = originalIndex++;
          }

          // Fill in unchanged items.
          for (var i = slotCount - 1; i >= 0; i--) {
            if (drawOrder[i] == -1) drawOrder[i] = unchanged[--unchangedIndex];
          }
        }

        drawOrderTimeline.setFrame(frameIndex++, time, drawOrder);
      }

      timelines.add(drawOrderTimeline);
      duration = math.max(duration, drawOrderTimeline.frames[drawOrderTimeline.frameCount - 1]);
    }

    //-------------------------------------

    if (map.containsKey('events')) {
      final eventsMap = map['events'].getList<Json>();
      final eventTimeline = EventTimeline(eventsMap.length);
      var frameIndex = 0;

      for (final eventMap in eventsMap) {
        final name = eventMap['name'] as String?;
        if (name == null) continue;

        final eventData = skeletonData.findEvent(name);
        if (eventData == null) throw StateError("Event not found: ${eventMap["name"]}");
        final eventTime = _getDouble(eventMap, 'time', 0);
        final event = SpineEvent(
            eventTime,
            eventData,
            _getInt(eventMap, 'int', eventData.intValue),
            _getDouble(eventMap, 'float', eventData.floatValue),
            _getString(eventMap, 'string', eventData.stringValue),
        );
        eventTimeline.setFrame(frameIndex++, event);
      }

      timelines.add(eventTimeline);
      duration = math.max(duration, eventTimeline.frames[eventTimeline.frameCount - 1]);
    }

    skeletonData.animations.add(Animation(name, timelines, duration));
  }

  //---------------------------------------------------------------------------
  //---------------------------------------------------------------------------

  void _readCurve(Json valueMap, CurveTimeline timeline, int frameIndex) {
    switch (valueMap['curve']) {
      case 'stepped':
        timeline.setStepped(frameIndex);

      case final List<double> curve:  
        final [cx1, cy1, cx2, cy2, ...] = curve;
        timeline.setCurve(frameIndex, cx1, cy1, cx2, cy2);
    }
  }

  Float32List _getFloat32List(Json map, String name) {
    final values = map[name].getList<double>();
    return Float32List.fromList(values);
  }

  Int16List _getInt16List(Json map, String name) {
    final values = map[name].getList<int>();
    return Int16List.fromList(values);
  }

  String? _getString(Json map, String name, String? defaultValue) {
    final value = map[name];
    return value is String ? value : defaultValue;
  }

  double _getDouble(Json map, String name, double defaultValue) {
    final value = map[name];
    if (value is num) {
      return value.toDouble();
    } else {
      return defaultValue;
    } 
  }

  int _getInt(Json map, String name, int defaultValue) {
    final value = map[name];
    if (value is int) {
      return value;
    } else {
      return defaultValue;
    } 
  }

  bool _getBool(Json map, String name, bool defaultValue) {
    final value = map[name];
    if (value is bool) {
      return value;
    } else {
      return defaultValue;
    } 
  }
}

class _LinkedMesh {
  final String parent;
  final String? skin;
  final int slotIndex;
  final MeshAttachment mesh;

  _LinkedMesh(this.mesh, this.skin, this.slotIndex, this.parent);
}
