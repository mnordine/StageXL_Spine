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

class SkeletonLoader {
  final AttachmentLoader attachmentLoader;
  final List<_LinkedMesh> _linkedMeshes = [];

  SkeletonLoader(this.attachmentLoader);

  /// Parameter 'object' must be a String or Map.
  ///
  SkeletonData readSkeletonData(Object? object, [String? name]) {
    Json root;

    if (object == null) {
      throw ArgumentError("object cannot be null.");
    } else if (object is String) {
      root = jsonDecode(object) as Json;
    } else if (object is Json) {
      root = object;
    } else {
      throw ArgumentError("object must be a String or Map.");
    }

    SkeletonData skeletonData = SkeletonData();
    skeletonData.name = name;

    // Skeleton

    final skeletonMap = root["skeleton"] as Json?;

    if (skeletonMap != null) {
      skeletonData.version = _getString(skeletonMap, "spine", "")!;
      skeletonData.hash = _getString(skeletonMap, "hash", "")!;
      skeletonData.width = _getDouble(skeletonMap, "width", 0);
      skeletonData.height = _getDouble(skeletonMap, "height", 0);
      skeletonData.fps = _getDouble(skeletonMap, "fps", 0);
      skeletonData.imagesPath = _getString(skeletonMap, "images", "")!;
    }

    // Bones

    for (final boneMap in (root["bones"] as List? ?? []).cast<Json>()) {
      BoneData? parent;

      String? parentName = _getString(boneMap, "parent", null);
      if (parentName != null) {
        parent = skeletonData.findBone(parentName);
        if (parent == null) throw StateError("Parent bone not found: $parentName");
      }

      var boneIndex = skeletonData.bones.length;
      var boneName = _getString(boneMap, "name", null);
      if (boneName == null)
        continue;

      var boneData = BoneData(boneIndex, boneName, parent);
      var transformMode = "TransformMode.${_getString(boneMap, "transform", "normal")!}";

      boneData.length = _getDouble(boneMap, "length", 0);
      boneData.x = _getDouble(boneMap, "x", 0);
      boneData.y = _getDouble(boneMap, "y", 0);
      boneData.rotation = _getDouble(boneMap, "rotation", 0);
      boneData.scaleX = _getDouble(boneMap, "scaleX", 1);
      boneData.scaleY = _getDouble(boneMap, "scaleY", 1);
      boneData.shearX = _getDouble(boneMap, "shearX", 0);
      boneData.shearY = _getDouble(boneMap, "shearY", 0);
      boneData.transformMode =
          TransformMode.values.firstWhere((e) => e.toString() == transformMode);
      skeletonData.bones.add(boneData);
    }

    // Slots

    for (final slotMap in (root["slots"] as List? ?? []).cast<Json>()) {
      var slotName = _getString(slotMap, "name", null);
      var boneName = _getString(slotMap, "bone", null);
      if (slotName == null || boneName == null)
        continue;

      var boneData = skeletonData.findBone(boneName);
      if (boneData == null) throw StateError("Slot bone not found: $boneName");

      var slotIndex = skeletonData.slots.length;
      SlotData slotData = SlotData(slotIndex, slotName, boneData);
      slotData.color.setFromString(_getString(slotMap, "color", "FFFFFFFF")!);
      slotData.attachmentName = _getString(slotMap, "attachment", null);

      if (slotMap.containsKey("dark")) {
        slotData.darkColor =
          SpineColor(1, 1, 1, 0)..setFromString(_getString(slotMap, "dark", "FFFFFF")!);
      }

      switch (_getString(slotMap, "blend", "normal")) {
        case "normal":
          slotData.blendMode = BlendMode.NORMAL;
        case "additive":
          slotData.blendMode = BlendMode.ADD;
        case "multiply":
          slotData.blendMode = BlendMode.MULTIPLY;
        case "screen":
          slotData.blendMode = BlendMode.SCREEN;
      }

      skeletonData.slots.add(slotData);
    }

    // IK constraints.

    for (final constraintMap in (root["ik"] as List? ?? []).cast<Json>()) {
      var constraintName = _getString(constraintMap, "name", null);
      if (constraintName == null)
        continue;

      var constraintData = IkConstraintData(constraintName);

      for (var boneName in (constraintMap["bones"] as List<String>)) {
        var bone = skeletonData.findBone(boneName);
        if (bone == null) throw StateError("IK constraint bone not found: $boneName");
        constraintData.bones.add(bone);
      }

      var targetName = _getString(constraintMap, "target", null);
      if (targetName == null)
        continue;

      var target = skeletonData.findBone(targetName);
      if (target == null) throw StateError("Target bone not found: $targetName");

      constraintData.target = target;
      constraintData.order = _getInt(constraintMap, "order", 0);
      constraintData.bendDirection = _getBool(constraintMap, "bendPositive", true) ? 1 : -1;
      constraintData.mix = _getDouble(constraintMap, "mix", 1);

      skeletonData.ikConstraints.add(constraintData);
    }

    // Transform constraints.

    for (final constraintMap in (root["transform"] as List? ?? []).cast<Json>()) {
      var constraintName = _getString(constraintMap, "name", null);
      if (constraintName == null)
        continue;

      var constraintData = TransformConstraintData(constraintName);

      for (String boneName in constraintMap["bones"] as List<String>) {
        var bone = skeletonData.findBone(boneName);
        if (bone == null) throw StateError("Transform constraint bone not found: $boneName");
        constraintData.bones.add(bone);
      }

      var targetName = _getString(constraintMap, "target", null);
      if (targetName == null)
        continue;

      var target = skeletonData.findBone(targetName);
      if (target == null) throw StateError("Target bone not found: $targetName");

      constraintData.target = target;
      constraintData.local = _getBool(constraintMap, "local", false);
      constraintData.relative = _getBool(constraintMap, "relative", false);
      constraintData.order = _getInt(constraintMap, "order", 0);
      constraintData.offsetRotation = _getDouble(constraintMap, "rotation", 0);
      constraintData.offsetX = _getDouble(constraintMap, "x", 0);
      constraintData.offsetY = _getDouble(constraintMap, "y", 0);
      constraintData.offsetScaleX = _getDouble(constraintMap, "scaleX", 0);
      constraintData.offsetScaleY = _getDouble(constraintMap, "scaleY", 0);
      constraintData.offsetShearY = _getDouble(constraintMap, "shearY", 0);
      constraintData.rotateMix = _getDouble(constraintMap, "rotateMix", 1);
      constraintData.translateMix = _getDouble(constraintMap, "translateMix", 1);
      constraintData.scaleMix = _getDouble(constraintMap, "scaleMix", 1);
      constraintData.shearMix = _getDouble(constraintMap, "shearMix", 1);

      skeletonData.transformConstraints.add(constraintData);
    }

    // Path constraints.

    for (final constraintMap in (root["path"] as List? ?? []).cast<Json>()) {
      var constraintName = _getString(constraintMap, "name", null);
      if (constraintName == null)
        continue;

      var pathConstraintData = PathConstraintData(constraintName);

      for (String boneName in constraintMap["bones"] as List<String>) {
        var bone = skeletonData.findBone(boneName);
        if (bone == null) throw StateError("Path constraint bone not found: $boneName");
        pathConstraintData.bones.add(bone);
      }

      var targetName = _getString(constraintMap, "target", null);
      if (targetName == null)
        continue;

      var target = skeletonData.findSlot(targetName);
      if (target == null) throw StateError("Path target slot not found: $targetName");

      var positionMode = "PositionMode.${_getString(constraintMap, "positionMode", "percent")!}";
      var spacingMode = "SpacingMode.${_getString(constraintMap, "spacingMode", "length")!}";
      var rotateMode = "RotateMode.${_getString(constraintMap, "rotateMode", "tangent")!}";

      pathConstraintData.target = target;
      pathConstraintData.order = _getInt(constraintMap, "order", 0);
      pathConstraintData.positionMode =
          PositionMode.values.firstWhere((e) => e.toString() == positionMode);
      pathConstraintData.spacingMode =
          SpacingMode.values.firstWhere((e) => e == spacingMode);
      pathConstraintData.rotateMode =
          RotateMode.values.firstWhere((e) => e.toString() == rotateMode);
      pathConstraintData.offsetRotation = _getDouble(constraintMap, "rotation", 0);
      pathConstraintData.position = _getDouble(constraintMap, "position", 0);
      pathConstraintData.spacing = _getDouble(constraintMap, "spacing", 0);
      pathConstraintData.rotateMix = _getDouble(constraintMap, "rotateMix", 1);
      pathConstraintData.translateMix = _getDouble(constraintMap, "translateMix", 1);

      skeletonData.pathConstraints.add(pathConstraintData);
    }

    // Skins

    final skins = root["skins"] as Json? ?? <String, Object?>{};

    for (String skinName in skins.keys) {
      var skinMap = skins[skinName] as Json;
      var skin = Skin(skinName);
      for (String slotName in skinMap.keys) {
        var slotIndex = skeletonData.findSlotIndex(slotName);
        var slotEntry = skinMap[slotName] as Json;
        for (String attachmentName in slotEntry.keys) {
          final map = slotEntry[attachmentName] as Json;
          var attachment = readAttachment(map, skin, slotIndex, attachmentName, skeletonData);
          if (attachment != null) skin.addAttachment(slotIndex, attachmentName, attachment);
        }
      }
      skeletonData.skins.add(skin);
      if (skin.name == "default") skeletonData.defaultSkin = skin;
    }

    // Linked meshes.

    for (var linkedMesh in _linkedMeshes) {
      var parentSkin = linkedMesh.skin == null
          ? skeletonData.defaultSkin
          : skeletonData.findSkin(linkedMesh.skin!);
      if (parentSkin == null) throw StateError("Skin not found: ${linkedMesh.skin}");
      var parentMesh = parentSkin.getAttachment(linkedMesh.slotIndex, linkedMesh.parent);
      if (parentMesh == null) throw StateError("Parent mesh not found: ${linkedMesh.parent}");
      linkedMesh.mesh.parentMesh = parentMesh as MeshAttachment;
      linkedMesh.mesh.initRenderGeometry();
    }

    _linkedMeshes.clear();

    // Events

    final events = root["events"] as Json? ?? <String, Object?>{};

    for (String eventName in events.keys) {
      final eventMap = events[eventName] as Json;
      var eventData = EventData(eventName);
      eventData.intValue = _getInt(eventMap, "int", 0);
      eventData.floatValue = _getDouble(eventMap, "float", 0);
      eventData.stringValue = _getString(eventMap, "string", null);
      skeletonData.events.add(eventData);
    }

    // Animations

    final animations = root["animations"] as Json? ?? <String, Object?>{};

    for (var animationName in animations.keys) {
      final map = animations[animationName] as Json;
      _readAnimation(map, animationName, skeletonData);
    }

    return skeletonData;
  }

  //---------------------------------------------------------------------------

  Attachment? readAttachment(
      Json map, Skin skin, int slotIndex, String name, SkeletonData skeletonData) {
    name = _getString(map, "name", name)!;

    var typeName = "AttachmentType.${_getString(map, "type", "region")!}";
    var type = AttachmentType.values.firstWhere((e) => e.toString() == typeName);
    var path = _getString(map, "path", name)!;

    switch (type) {
      case AttachmentType.region:
        var region = attachmentLoader.newRegionAttachment(skin, name, path);
        if (region == null) return null;

        region.x = _getDouble(map, "x", 0);
        region.y = _getDouble(map, "y", 0);
        region.scaleX = _getDouble(map, "scaleX", 1);
        region.scaleY = _getDouble(map, "scaleY", 1);
        region.rotation = _getDouble(map, "rotation", 0);
        region.width = _getDouble(map, "width", 0);
        region.height = _getDouble(map, "height", 0);
        region.color.setFromString(_getString(map, "color", "FFFFFFFF")!);
        region.update();

        return region;

      case AttachmentType.regionsequence:
        // Currently not supported
        return null;

      case AttachmentType.mesh:
      case AttachmentType.linkedmesh:
        var mesh = attachmentLoader.newMeshAttachment(skin, name, path);
        if (mesh == null) return null;

        mesh.color.setFromString(_getString(map, "color", "FFFFFFFF")!);
        mesh.width = _getDouble(map, "width", 0);
        mesh.height = _getDouble(map, "height", 0);

        var parentName = _getString(map, "parent", null);

        if (parentName != null) {
          var skinName = _getString(map, "skin", null);
          var lm = _LinkedMesh(mesh, skinName, slotIndex, parentName);
          _linkedMeshes.add(lm);
          mesh.inheritDeform = _getBool(map, "deform", true);
          return mesh;
        }

        Float32List uvs = _getFloat32List(map, "uvs");
        _readVertices(map, mesh, uvs.length);

        mesh.triangles = _getInt16List(map, "triangles");
        mesh.regionUVs = uvs;
        mesh.initRenderGeometry();

        mesh.hullLength = _getInt(map, "hull", 0) * 2;
        if (map.containsKey("edges")) mesh.edges = _getInt16List(map, "edges");

        return mesh;

      case AttachmentType.boundingbox:
        var box = attachmentLoader.newBoundingBoxAttachment(skin, name);
        if (box == null) return null;
        int vertexCount = _getInt(map, "vertexCount", 0);
        _readVertices(map, box, vertexCount << 1);
        return box;

      case AttachmentType.path:
        var path = attachmentLoader.newPathAttachment(skin, name);
        if (path == null) return null;

        path.closed = _getBool(map, "closed", false);
        path.constantSpeed = _getBool(map, "constantSpeed", true);
        path.lengths = _getFloat32List(map, "lengths");

        int vertexCount = _getInt(map, "vertexCount", 0);
        _readVertices(map, path, vertexCount << 1);

        return path;

      case AttachmentType.point:
        var point = attachmentLoader.newPointAttachment(skin, name);
        if (point == null) return null;

        point.x = _getDouble(map, "x", 0);
        point.y = _getDouble(map, "y", 0);
        point.rotation = _getDouble(map, "rotation", 0);
        point.color.setFromString(_getString(map, "color", "FFFFFFFF")!);
        return point;

      case AttachmentType.clipping:
        var clip = attachmentLoader.newClippingAttachment(skin, name);
        if (clip == null) return null;

        var end = _getString(map, "end", null);
        var vertexCount = _getInt(map, "vertexCount", 0);

        if (end != null) {
          var slot = skeletonData.findSlot(end);
          if (slot == null) throw StateError("Clipping end slot not found: $end");
          clip.endSlot = slot;
        }

        clip.color.setFromString(_getString(map, "color", "FFFFFFFF")!);
        _readVertices(map, clip, vertexCount << 1);
        return clip;
    }
  }

  //---------------------------------------------------------------------------

  void _readVertices(Json map, VertexAttachment attachment, int verticesLength) {
    attachment.worldVerticesLength = verticesLength;

    var vertices = _getFloat32List(map, "vertices");
    var weights = <double>[];
    var bones = <int>[];

    if (verticesLength == vertices.length) {
      attachment.vertices = vertices;
      return;
    }

    for (int i = 0; i < vertices.length;) {
      int boneCount = vertices[i++].toInt();
      bones.add(boneCount);
      for (var nn = i + boneCount * 4; i < nn; i += 4) {
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
    List<Timeline> timelines = [];
    double duration = 0;

    //-------------------------------------

    final slots = map["slots"] as Json? ?? <String, Object?>{};

    for (String slotName in slots.keys) {
      final slotMap = slots[slotName] as Json;
      int slotIndex = skeletonData.findSlotIndex(slotName);

      for (String timelineName in slotMap.keys) {
        final values = (slotMap[timelineName] as List).cast<Json>();

        if (timelineName == "attachment") {
          AttachmentTimeline attachmentTimeline = AttachmentTimeline(values.length);
          attachmentTimeline.slotIndex = slotIndex;

          int frameIndex = 0;
          for (final valueMap in values) {
            var time = _getDouble(valueMap, "time", 0);
            var name = _getString(valueMap, "name", null);
            attachmentTimeline.setFrame(frameIndex, time, name);
            frameIndex++;
          }

          timelines.add(attachmentTimeline);
          duration =
              math.max(duration, attachmentTimeline.frames[attachmentTimeline.frameCount - 1]);
        } else if (timelineName == "color") {
          ColorTimeline colorTimeline = ColorTimeline(values.length);
          colorTimeline.slotIndex = slotIndex;

          int frameIndex = 0;
          for (final valueMap in values) {
            double time = _getDouble(valueMap, "time", 0);
            SpineColor color = SpineColor(1, 1, 1, 1);
            color.setFromString(_getString(valueMap, "color", "FFFFFFFF")!);
            colorTimeline.setFrame(frameIndex, time, color.r, color.g, color.b, color.a);
            _readCurve(valueMap, colorTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(colorTimeline);
          duration = math.max(duration,
              colorTimeline.frames[(colorTimeline.frameCount - 1) * ColorTimeline._entries]);
        } else if (timelineName == "twoColor") {
          var twoColorTimeline = TwoColorTimeline(values.length);
          twoColorTimeline.slotIndex = slotIndex;

          int frameIndex = 0;
          for (final valueMap in values) {
            var time = _getDouble(valueMap, "time", 0);
            var cl = SpineColor(1, 1, 1, 1);
            var cd = SpineColor(1, 1, 1, 1);
            cl.setFromString(_getString(valueMap, "light", "FFFFFFFF")!);
            cd.setFromString(_getString(valueMap, "dark", "FFFFFFFF")!);
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
          throw StateError("Invalid timeline type for a slot: $timelineName ($slotName)");
        }
      }
    }

    //-------------------------------------

    final bones = map["bones"] as Json? ?? <String, Object?>{};

    for (String boneName in bones.keys) {
      int boneIndex = skeletonData.findBoneIndex(boneName);
      if (boneIndex == -1) throw StateError("Bone not found: $boneName");

      final boneMap = bones[boneName] as Json;

      for (String timelineName in boneMap.keys) {
        final values = (boneMap[timelineName] as List).cast<Json>();

        if (timelineName == "rotate") {
          RotateTimeline rotateTimeline = RotateTimeline(values.length);
          rotateTimeline.boneIndex = boneIndex;

          int frameIndex = 0;
          for (final valueMap in values) {
            double time = _getDouble(valueMap, "time", 0);
            double degrees = _getDouble(valueMap, "angle", 0);
            rotateTimeline.setFrame(frameIndex, time, degrees);
            _readCurve(valueMap, rotateTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(rotateTimeline);
          duration = math.max(duration,
              rotateTimeline.frames[(rotateTimeline.frameCount - 1) * RotateTimeline._entries]);
        } else if (timelineName == "translate" ||
            timelineName == "scale" ||
            timelineName == "shear") {
          TranslateTimeline translateTimeline;

          if (timelineName == "scale") {
            translateTimeline = ScaleTimeline(values.length);
          } else if (timelineName == "shear") {
            translateTimeline = ShearTimeline(values.length);
          } else {
            translateTimeline = TranslateTimeline(values.length);
          }

          translateTimeline.boneIndex = boneIndex;

          int frameIndex = 0;
          for (final valueMap in values) {
            double x = _getDouble(valueMap, "x", 0);
            double y = _getDouble(valueMap, "y", 0);
            double time = _getDouble(valueMap, "time", 0);
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
          throw StateError("Invalid timeline type for a bone: $timelineName ($boneName)");
        }
      }
    }

    //-------------------------------------

    final ikMap = map["ik"] as Json? ?? <String, Object?>{};

    for (String ikConstraintName in ikMap.keys) {
      IkConstraintData ikConstraint = skeletonData.findIkConstraint(ikConstraintName)!;
      final valueMaps = (ikMap[ikConstraintName] as List).cast<Json>();
      IkConstraintTimeline ikTimeline = IkConstraintTimeline(valueMaps.length);
      ikTimeline.ikConstraintIndex = skeletonData.ikConstraints.indexOf(ikConstraint);
      int frameIndex = 0;
      for (final valueMap in valueMaps) {
        double time = _getDouble(valueMap, "time", 0);
        double mix = _getDouble(valueMap, "mix", 1);
        int bendDirection = _getBool(valueMap, "bendPositive", true) ? 1 : -1;
        ikTimeline.setFrame(frameIndex, time, mix, bendDirection);
        _readCurve(valueMap, ikTimeline, frameIndex);
        frameIndex++;
      }
      timelines.add(ikTimeline);
      duration = math.max(
          duration, ikTimeline.frames[(ikTimeline.frameCount - 1) * IkConstraintTimeline._entries]);
    }

    //-------------------------------------

    final transformMap = map["transform"] as Json? ?? <String, Object?>{};

    for (String transformName in transformMap.keys) {
      TransformConstraintData transformConstraint =
          skeletonData.findTransformConstraint(transformName)!;
      final valueMaps = (transformMap[transformName] as List).cast<Json>();
      TransformConstraintTimeline transformTimeline = TransformConstraintTimeline(valueMaps.length);
      transformTimeline.transformConstraintIndex =
          skeletonData.transformConstraints.indexOf(transformConstraint);
      int frameIndex = 0;
      for (final valueMap in valueMaps) {
        double rotateMix = _getDouble(valueMap, "rotateMix", 1);
        double translateMix = _getDouble(valueMap, "translateMix", 1);
        double scaleMix = _getDouble(valueMap, "scaleMix", 1);
        double shearMix = _getDouble(valueMap, "shearMix", 1);
        double time = _getDouble(valueMap, "time", 0);
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

    final pathsMaps = map["paths"] as Json? ?? <String, Object?>{};

    for (String pathName in pathsMaps.keys) {
      int index = skeletonData.findPathConstraintIndex(pathName);
      if (index == -1) throw StateError("Path constraint not found: $pathName");

      final pathMap = pathsMaps[pathName] as Json;
      for (String timelineName in pathMap.keys) {
        final valueMaps = (pathMap[timelineName] as List).cast<Json>();

        if (timelineName == "position" || timelineName == "spacing") {
          PathConstraintPositionTimeline pathTimeline;

          if (timelineName == "spacing") {
            pathTimeline = PathConstraintSpacingTimeline(valueMaps.length);
          } else {
            pathTimeline = PathConstraintPositionTimeline(valueMaps.length);
          }

          pathTimeline.pathConstraintIndex = index;
          int frameIndex = 0;

          for (final valueMap in valueMaps) {
            double value = _getDouble(valueMap, timelineName, 0);
            double time = _getDouble(valueMap, "time", 0);
            pathTimeline.setFrame(frameIndex, time, value);
            _readCurve(valueMap, pathTimeline, frameIndex);
            frameIndex++;
          }

          timelines.add(pathTimeline);
          duration = math.max(
              duration,
              pathTimeline
                  .frames[(pathTimeline.frameCount - 1) * PathConstraintPositionTimeline._entries]);
        } else if (timelineName == "mix") {
          PathConstraintMixTimeline pathMixTimeline = PathConstraintMixTimeline(valueMaps.length);
          pathMixTimeline.pathConstraintIndex = index;
          int frameIndex = 0;

          for (final valueMap in valueMaps) {
            double rotateMix = _getDouble(valueMap, "rotateMix", 1);
            double translateMix = _getDouble(valueMap, "translateMix", 1);
            double time = _getDouble(valueMap, "time", 0);
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

    final deformMap = map["deform"] as Json? ?? <String, Object?>{};

    for (String skinName in deformMap.keys) {
      Skin skin = skeletonData.findSkin(skinName)!;
      final slotMap = deformMap[skinName] as Json;

      for (String slotName in slotMap.keys) {
        int slotIndex = skeletonData.findSlotIndex(slotName);
        final timelineMap = slotMap[slotName] as Json;

        for (String timelineName in timelineMap.keys) {
          final valueMaps = (timelineMap[timelineName] as List).cast<Json>();
          var attachment = skin.getAttachment(slotIndex, timelineName) as VertexAttachment?;
          if (attachment == null) throw StateError("Deform attachment not found: $timelineName");

          bool weighted = attachment.bones != null;
          Float32List vertices = attachment.vertices;
          int deformLength = weighted ? vertices.length ~/ 3 * 2 : vertices.length;
          int frameIndex = 0;

          DeformTimeline deformTimeline = DeformTimeline(valueMaps.length, attachment);
          deformTimeline.slotIndex = slotIndex;

          for (final valueMap in valueMaps) {
            Float32List deform;
            var verticesValue = valueMap["vertices"];
            if (verticesValue == null) {
              deform = weighted ? Float32List(deformLength) : vertices;
            } else {
              deform = Float32List(deformLength);
              int start = _getInt(valueMap, "offset", 0);
              Float32List temp = _getFloat32List(valueMap, "vertices");
              for (int i = 0; i < temp.length; i++) {
                deform[start + i] = temp[i];
              }
              if (!weighted) {
                for (int i = 0; i < deformLength; i++) {
                  deform[i] += vertices[i];
                }
              }
            }
            var time = _getDouble(valueMap, "time", 0);
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

    final drawOrderValues = ((map["drawOrder"] ?? map["draworder"]) as List?)?.cast<Json>();

    if (drawOrderValues != null) {
      DrawOrderTimeline drawOrderTimeline = DrawOrderTimeline(drawOrderValues.length);
      int slotCount = skeletonData.slots.length;
      int frameIndex = 0;

      for (final drawOrderMap in drawOrderValues) {
        double time = _getDouble(drawOrderMap, "time", 0);
        Int16List? drawOrder;

        if (drawOrderMap.containsKey("offsets")) {
          drawOrder = Int16List(slotCount);
          for (int i = 0; i < drawOrder.length; i++) {
            drawOrder[i] = -1;
          }

          final offsetMaps = (drawOrderMap["offsets"] as List).cast<Json>();
          Int16List unchanged = Int16List(slotCount - offsetMaps.length);
          int originalIndex = 0;
          int unchangedIndex = 0;

          for (final offsetMap in offsetMaps) {
            var slotName = _getString(offsetMap, "slot", null);
            if (slotName == null)
              continue;

            int slotIndex = skeletonData.findSlotIndex(slotName);
            if (slotIndex == -1) throw StateError("Slot not found: $slotName");
            // Collect unchanged items.
            while (originalIndex != slotIndex) {
              unchanged[unchangedIndex++] = originalIndex++;
            }
            // Set changed items.
            drawOrder[originalIndex + (offsetMap["offset"] as int)] = originalIndex++;
          }

          // Collect remaining unchanged items.
          while (originalIndex < slotCount) {
            unchanged[unchangedIndex++] = originalIndex++;
          }

          // Fill in unchanged items.
          for (int i = slotCount - 1; i >= 0; i--) {
            if (drawOrder[i] == -1) drawOrder[i] = unchanged[--unchangedIndex];
          }
        }

        drawOrderTimeline.setFrame(frameIndex++, time, drawOrder);
      }

      timelines.add(drawOrderTimeline);
      duration = math.max(duration, drawOrderTimeline.frames[drawOrderTimeline.frameCount - 1]);
    }

    //-------------------------------------

    if (map.containsKey("events")) {
      final eventsMap = (map["events"] as List).cast<Json>();
      EventTimeline eventTimeline = EventTimeline(eventsMap.length);
      int frameIndex = 0;

      for (final eventMap in eventsMap) {
        var eventData = skeletonData.findEvent(eventMap["name"] as String);
        if (eventData == null) throw StateError("Event not found: ${eventMap["name"]}");
        var eventTime = _getDouble(eventMap, "time", 0);
        var event = SpineEvent(
            eventTime,
            eventData,
            _getInt(eventMap, "int", eventData.intValue),
            _getDouble(eventMap, "float", eventData.floatValue),
            _getString(eventMap, "string", eventData.stringValue),
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
    final values = (map[name] as List).cast<double>();
    return Float32List.fromList(values);
  }

  Int16List _getInt16List(Json map, String name) {
    final values = (map[name] as List).cast<int>();
    return Int16List.fromList(values);
  }

  String? _getString(Json map, String name, String? defaultValue) {
    var value = map[name];
    return value is String ? value : defaultValue;
  }

  double _getDouble(Json map, String name, double defaultValue) {
    var value = map[name];
    if (value is num) {
      return value.toDouble();
    } else {
      return defaultValue;
    } 
  }

  int _getInt(Json map, String name, int defaultValue) {
    var value = map[name];
    if (value is int) {
      return value;
    } else {
      return defaultValue;
    } 
  }

  bool _getBool(Json map, String name, bool defaultValue) {
    var value = map[name];
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
