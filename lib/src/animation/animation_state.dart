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

class AnimationState extends EventDispatcher {
  static const subsequent = 0;
  static const first = 1;
  static const dip = 2;
  static const dipMix = 3;
  static final Animation _emptyAnimation = Animation('<empty>', [], 0);

  final AnimationStateData data;
  final List<TrackEntry?> _tracks = [];
  final List<SpineEvent> _events = [];
  final List<TrackEntryEvent> _trackEntryEvents = [];
  final Set<int> _propertyIDs = <int>{};
  final List<TrackEntry> _mixingTo = [];

  bool _eventDispatchDisabled = false;
  bool _animationsChanged = false;
  double timeScale = 1;

  //----------------------------------------------------------------------------

  AnimationState(this.data);

  EventStream<TrackEntryStartEvent> get onTrackStart => const EventStreamProvider<TrackEntryStartEvent>('start').forTarget(this);

  EventStream<TrackEntryInterruptEvent> get onTrackInterrupt => const EventStreamProvider<TrackEntryInterruptEvent>('interrupt').forTarget(this);

  EventStream<TrackEntryEndEvent> get onTrackEnd => const EventStreamProvider<TrackEntryEndEvent>('end').forTarget(this);

  EventStream<TrackEntryDisposeEvent> get onTrackDispose => const EventStreamProvider<TrackEntryDisposeEvent>('dispose').forTarget(this);

  EventStream<TrackEntryCompleteEvent> get onTrackComplete => const EventStreamProvider<TrackEntryCompleteEvent>('complete').forTarget(this);

  EventStream<TrackEntryEventEvent> get onTrackEvent => const EventStreamProvider<TrackEntryEventEvent>('event').forTarget(this);

  //-----------------------------------------------------------------------------------------------

  void update(double delta) {
    delta *= timeScale;

    for (var i = 0; i < _tracks.length; i++) {
      final current = _tracks[i];
      if (current == null) continue;

      current.animationLast = current.nextAnimationLast;
      current.trackLast = current.nextTrackLast;

      var currentDelta = delta * current.timeScale;

      if (current.delay > 0.0) {
        current.delay -= currentDelta;
        if (current.delay > 0.0) continue;
        currentDelta = -current.delay;
        current.delay = 0.0;
      }

      var next = current.next;
      if (next != null) {
        // When the next entry's delay is passed, change to the next entry, preserving leftover time.
        final nextTime = current.trackLast - next.delay;
        if (nextTime >= 0.0) {
          next.delay = 0.0;
          next.trackTime = nextTime + delta * next.timeScale;
          current.trackTime += currentDelta;
          _setCurrent(i, next, true);
          while (next?.mixingFrom != null) {
            next!.mixTime += currentDelta;
            next = next.mixingFrom;
          }
          continue;
        }
      } else {
        // Clear the track when there is no next entry, the track end time is reached, and there is no mixingFrom.
        if (current.trackLast >= current.trackEnd && current.mixingFrom == null) {
          _tracks[i] = null;
          _enqueueTrackEntryEvent(TrackEntryEndEvent(current));
          _disposeNext(current);
          continue;
        }
      }

      if (current.mixingFrom != null && _updateMixingFrom(current, delta)) {
        // End mixing from entries once all have completed.
        var from = current.mixingFrom;
        current.mixingFrom = null;
        while (from != null) {
          _enqueueTrackEntryEvent(TrackEntryEndEvent(from));
          from = from.mixingFrom;
        }
      }

      current.trackTime += currentDelta;
    }

    _dispatchTrackEntryEvents();
  }

  bool _updateMixingFrom(TrackEntry to, double delta) {
    final from = to.mixingFrom;
    if (from == null) return true;

    final finished = _updateMixingFrom(from, delta);

    // Require mixTime > 0 to ensure the mixing from entry was applied at least once.
    if (to.mixTime > 0 && (to.mixTime >= to.mixDuration || to.timeScale == 0)) {
      // Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame).
      if (from.totalAlpha == 0 || to.mixDuration == 0) {
        to.mixingFrom = from.mixingFrom;
        to.interruptAlpha = from.interruptAlpha;
        _enqueueTrackEntryEvent(TrackEntryEndEvent(from));
      }
      return finished;
    }

    from.animationLast = from.nextAnimationLast;
    from.trackLast = from.nextTrackLast;
    from.trackTime += delta * from.timeScale;
    to.mixTime += delta * to.timeScale;
    return false;
  }

  bool apply(Skeleton skeleton) {
    if (_animationsChanged) _animationsHasChanged();

    final events = _events;
    var applied = false;

    for (var i = 0; i < _tracks.length; i++) {
      final current = _tracks[i];
      if (current == null || current.delay > 0.0) continue;
      applied = true;
      final currentPose = i == 0 ? MixPose.current : MixPose.currentLayered;

      // Apply mixing from entries first.
      var mix = current.alpha;
      if (current.mixingFrom != null) {
        mix *= _applyMixingFrom(current, skeleton, currentPose);
      } else if (current.trackTime >= current.trackEnd && current.next == null) {
        mix = 0.0;
      }

      // Apply current entry.
      final animationLast = current.animationLast;
      final animationTime = current.getAnimationTime();
      final timelines = current.animation.timelines;
      var timelinesRotation = current.timelinesRotation;

      if (mix == 1.0) {
        for (var tl = 0; tl < timelines.length; tl++) {
          timelines[tl].apply(
              skeleton, animationLast, animationTime, events, 1, MixPose.setup, MixDirection.In);
        }
      } else {
        final timelineData = current.timelineData;
        final firstFrame = timelinesRotation.isEmpty;
        if (firstFrame) {
          timelinesRotation = List.filled(timelines.length << 1, 0.0);
        }

        for (var tl = 0; tl < timelines.length; tl++) {
          final timeline = timelines[tl];
          final pose = timelineData[tl] >= AnimationState.first ? MixPose.setup : currentPose;
          if (timeline is RotateTimeline) {
            _applyRotateTimeline(timeline, skeleton, animationTime, mix, pose, timelinesRotation,
                tl << 1, firstFrame);
          } else {
            timeline.apply(
                skeleton, animationLast, animationTime, events, mix, pose, MixDirection.In);
          }
        }
      }

      _queueEvents(current, animationTime);
      _events.clear();

      current.nextAnimationLast = animationTime;
      current.nextTrackLast = current.trackTime;
    }

    _dispatchTrackEntryEvents();
    return applied;
  }

  double _applyMixingFrom(TrackEntry to, Skeleton skeleton, MixPose currentPose) {
    final from = to.mixingFrom!;
    if (from.mixingFrom != null) _applyMixingFrom(from, skeleton, currentPose);

    double mix = 0;
    if (to.mixDuration == 0.0) {
      // Single frame mix to undo mixingFrom changes.
      mix = 1.0;
      currentPose = MixPose.setup;
    } else {
      mix = to.mixTime / to.mixDuration;
      if (mix > 1.0) mix = 1.0;
    }

    final events = mix < from.eventThreshold ? _events : <SpineEvent>[];
    final attachments = mix < from.attachmentThreshold;
    final drawOrder = mix < from.drawOrderThreshold;

    final animationLast = from.animationLast;
    final animationTime = from.getAnimationTime();
    final timelines = from.animation.timelines;
    var timelinesRotation = from.timelinesRotation;
    final timelineData = from.timelineData;
    final timelineDipMix = from.timelineDipMix;

    final firstFrame = timelinesRotation.isEmpty;
    if (firstFrame) {
      timelinesRotation = List.filled(timelines.length << 1, 0.0);
    }

    MixPose pose;
    final alphaDip = from.alpha * to.interruptAlpha;
    final alphaMix = alphaDip * (1.0 - mix);
    double alpha = 0;
    from.totalAlpha = 0.0;

    for (var i = 0; i < timelines.length; i++) {
      final timeline = timelines[i];
      switch (timelineData[i]) {
        case subsequent:
          if (!attachments && timeline is AttachmentTimeline) continue;
          if (!drawOrder && timeline is DrawOrderTimeline) continue;
          pose = currentPose;
          alpha = alphaMix;
        case first:
          pose = MixPose.setup;
          alpha = alphaMix;
        case dip:
          pose = MixPose.setup;
          alpha = alphaDip;
        default:
          pose = MixPose.setup;
          alpha = alphaDip;
          final dipMix = timelineDipMix[i]!;
          alpha *= math.max(0.0, 1.0 - dipMix.mixTime / dipMix.mixDuration);
      }
      from.totalAlpha += alpha;
      if (timeline is RotateTimeline) {
        _applyRotateTimeline(
            timeline, skeleton, animationTime, alpha, pose, timelinesRotation, i << 1, firstFrame);
      } else {
        timeline.apply(
            skeleton, animationLast, animationTime, events, alpha, pose, MixDirection.Out);
      }
    }

    if (to.mixDuration > 0) {
      _queueEvents(from, animationTime);
    }
    _events.clear();

    from.nextAnimationLast = animationTime;
    from.nextTrackLast = from.trackTime;
    return mix;
  }

  void _applyRotateTimeline(RotateTimeline timeline, Skeleton skeleton, double time, double alpha,
      MixPose pose, List<num> timelinesRotation, int i, bool firstFrame) {
    if (firstFrame) {
      timelinesRotation[i] = 0.0;
    }

    if (alpha == 1.0) {
      timeline.apply(skeleton, 0, time, null, 1, pose, MixDirection.In);
      return;
    }

    final frames = timeline.frames;
    final bone = skeleton.bones[timeline.boneIndex];
    double r2 = 0;

    if (time < frames[0]) {
      if (pose == MixPose.setup) bone.rotation = bone.data.rotation;
      return;
    }

    if (time >= frames[frames.length - RotateTimeline._entries]) {
      // Time is after last frame.
      r2 = bone.data.rotation + frames[frames.length + RotateTimeline._prevRotation];
    } else {
      // Interpolate between the previous frame and the current frame.
      final frame = Animation.binarySearch(frames, time, RotateTimeline._entries);
      final prevTime = frames[frame + RotateTimeline._prevTime];
      final prevRotation = frames[frame + RotateTimeline._prevRotation];
      final frameTime = frames[frame + RotateTimeline._time];
      final frameRotation = frames[frame + RotateTimeline._rotation];
      final between = 1.0 - (time - frameTime) / (prevTime - frameTime);
      final percent = timeline.getCurvePercent((frame >> 1) - 1, between);
      r2 = _wrapRotation(frameRotation - prevRotation);
      r2 = _wrapRotation(prevRotation + r2 * percent + bone.data.rotation);
    }

    // Mix between rotations using the direction of the shortest route on the first frame while detecting crosses.
    final r1 = pose == MixPose.setup ? bone.data.rotation : bone.rotation;
    num total = 0.0;
    var diff = r2 - r1;

    if (diff == 0.0) {
      total = timelinesRotation[i];
    } else {
      diff = _wrapRotation(diff);
      var lastTotal =
          firstFrame ? 0.0 : timelinesRotation[i]; // Angle and direction of mix, including loops.
      final lastDiff = firstFrame ? diff : timelinesRotation[i + 1]; // Difference between bones.
      final current = diff > 0.0;
      var dir = lastTotal >= 0.0;
      // Detect cross at 0 (not 180).
      if ((lastDiff.sign != diff.sign) && (lastDiff.abs() <= 90.0)) {
        // A cross after a 360 rotation is a loop.
        if (lastTotal.abs() > 180.0) lastTotal += 360.0 * lastTotal.sign;
        dir = current;
      }
      // Store loops as part of '../stagexl_spine.dart';
      total = diff + 360.0 * (lastTotal / 360.0).truncateToDouble();
      if (dir != current) total += 360.0 * lastTotal.sign;
      timelinesRotation[i] = total;
    }

    timelinesRotation[i + 1] = diff;
    bone.rotation = _wrapRotation(r1 + total * alpha);
  }

  void _queueEvents(TrackEntry entry, double animationTime) {
    final animationStart = entry.animationStart;
    final animationEnd = entry.animationEnd;
    final duration = animationEnd - animationStart;
    final trackLastWrapped = entry.trackLast.remainder(duration);
    var i = 0;

    // Queue events before complete.
    for (; i < _events.length; i++) {
      final event = _events[i];
      if (event.time < trackLastWrapped) break;
      if (event.time > animationEnd) continue;
      _enqueueTrackEntryEvent(TrackEntryEventEvent(entry, event));
    }

    // Queue complete if completed a loop iteration or the animation.
    if (entry.loop
        ? (trackLastWrapped > entry.trackTime.remainder(duration))
        : (animationTime >= animationEnd && entry.animationLast < animationEnd)) {
      _enqueueTrackEntryEvent(TrackEntryCompleteEvent(entry));
    }

    // Queue events after complete.
    for (; i < _events.length; i++) {
      final event = _events[i];
      if (event.time < animationStart) continue;
      _enqueueTrackEntryEvent(TrackEntryEventEvent(entry, _events[i]));
    }
  }

  void clearTracks() {
    final oldEventDispatchDisabled = _eventDispatchDisabled;
    _eventDispatchDisabled = true;
    for (var i = 0; i < _tracks.length; i++) {
      clearTrack(i);
    }
    _tracks.clear();
    _eventDispatchDisabled = oldEventDispatchDisabled;
    _dispatchTrackEntryEvents();
  }

  void clearTrack(int trackIndex) {
    if (trackIndex >= _tracks.length) return;
    final current = _tracks[trackIndex];
    if (current == null) return;
    _enqueueTrackEntryEvent(TrackEntryEndEvent(current));
    _disposeNext(current);
    var entry = current;

    for (;;) {
      final from = entry.mixingFrom;
      if (from == null) break;
      _enqueueTrackEntryEvent(TrackEntryEndEvent(from));
      entry.mixingFrom = null;
      entry = from;
    }

    _tracks[current.trackIndex] = null;
    _dispatchTrackEntryEvents();
  }

  void _setCurrent(int index, TrackEntry current, bool interrupt) {
    final from = _expandToIndex(index);
    _tracks[index] = current;

    if (from != null) {
      if (interrupt) {
        _enqueueTrackEntryEvent(TrackEntryInterruptEvent(from));
      }
      current.mixingFrom = from;
      current.mixTime = 0.0;

      // Store the interrupted mix percentage.
      if (from.mixingFrom != null && from.mixDuration > 0) {
        current.interruptAlpha *= math.min(1.0, from.mixTime / from.mixDuration);
      }

      from.timelinesRotation.clear(); // Reset rotation for mixing out, in case entry was mixed in.
    }

    _enqueueTrackEntryEvent(TrackEntryStartEvent(current));
  }

  TrackEntry setAnimationByName(int trackIndex, String animationName, bool loop) {
    final animation = data.skeletonData.findAnimation(animationName)!;
    return setAnimation(trackIndex, animation, loop);
  }

  TrackEntry setAnimation(int trackIndex, Animation animation, bool loop) {
    var interrupt = true;
    var current = _expandToIndex(trackIndex);
    if (current != null) {
      if (current.nextTrackLast == -1) {
        // Don't mix from an entry that was never applied.
        _tracks[trackIndex] = current.mixingFrom;
        _enqueueTrackEntryEvent(TrackEntryInterruptEvent(current));
        _enqueueTrackEntryEvent(TrackEntryEndEvent(current));
        _disposeNext(current);
        current = current.mixingFrom;
        interrupt = false;
      } else {
        _disposeNext(current);
      }
    }
    final entry = _trackEntry(trackIndex, animation, loop, current);
    _setCurrent(trackIndex, entry, interrupt);
    _dispatchTrackEntryEvents();
    return entry;
  }

  TrackEntry addAnimationByName(int trackIndex, String animationName, bool loop, double delay) {
    final animation = data.skeletonData.findAnimation(animationName)!;
    return addAnimation(trackIndex, animation, loop, delay);
  }

  TrackEntry addAnimation(int trackIndex, Animation animation, bool loop, double delay) {
    var last = _expandToIndex(trackIndex);
    if (last != null) {
      while (last!.next != null) {
        last = last.next;
      }
    }

    final entry = _trackEntry(trackIndex, animation, loop, last);

    if (last == null) {
      _setCurrent(trackIndex, entry, true);
      _dispatchTrackEntryEvents();
    } else {
      last.next = entry;
      if (delay <= 0.0) {
        final duration = last.animationEnd - last.animationStart;
        if (duration != 0.0) {
          delay += duration * (1.0 + last.trackTime ~/ duration) -
              data.getMix(last.animation, animation);
        } else {
          delay = 0.0;
        }
      }
    }

    entry.delay = delay;
    return entry;
  }

  TrackEntry setEmptyAnimation(int trackIndex, double mixDuration) {
    final entry = setAnimation(trackIndex, _emptyAnimation, false);
    entry.mixDuration = mixDuration;
    entry.trackEnd = mixDuration;
    return entry;
  }

  TrackEntry addEmptyAnimation(int trackIndex, double mixDuration, double delay) {
    if (delay <= 0.0) delay -= mixDuration;
    final entry = addAnimation(trackIndex, _emptyAnimation, false, delay);
    entry.mixDuration = mixDuration;
    entry.trackEnd = mixDuration;
    return entry;
  }

  void setEmptyAnimations(double mixDuration) {
    final oldEventDispatchDisabled = _eventDispatchDisabled;
    _eventDispatchDisabled = true;
    for (var i = 0; i < _tracks.length; i++) {
      final current = _tracks[i];
      if (current != null) setEmptyAnimation(current.trackIndex, mixDuration);
    }
    _eventDispatchDisabled = oldEventDispatchDisabled;
    _dispatchTrackEntryEvents();
  }

  TrackEntry? _expandToIndex(int index) {
    if (index < _tracks.length) return _tracks[index];
    while (_tracks.length <= index) _tracks.add(null);
    return null;
  }

  TrackEntry _trackEntry(int trackIndex, Animation animation, bool loop, TrackEntry? last) {
    final entry = TrackEntry(trackIndex, animation);
    entry.loop = loop;
    entry.mixDuration = last == null ? 0.0 : data.getMix(last.animation, animation);
    return entry;
  }

  void _disposeNext(TrackEntry entry) {
    for (var next = entry.next; next != null; next = next.next) {
      _enqueueTrackEntryEvent(TrackEntryDisposeEvent(next));
    }
    entry.next = null;
  }

  void _animationsHasChanged() {
    _animationsChanged = false;
    _propertyIDs.clear();
    for (var i = 0; i < _tracks.length; i++) {
      _tracks[i]?.setTimelineData(null, _mixingTo, _propertyIDs);
    }
  }

  void _enqueueTrackEntryEvent(TrackEntryEvent trackEntryEvent) {
    _trackEntryEvents.add(trackEntryEvent);
    if (trackEntryEvent is TrackEntryStartEvent || trackEntryEvent is TrackEntryEndEvent) {
      _animationsChanged = true;
    }
  }

  void _dispatchTrackEntryEvents() {
    if (_eventDispatchDisabled == false) {
      _eventDispatchDisabled = true;
      _trackEntryEvents.toList().forEach((trackEntryEvent) {
        trackEntryEvent.trackEntry.dispatchEvent(trackEntryEvent);
        dispatchEvent(trackEntryEvent);
      });
      _trackEntryEvents.clear();
      _eventDispatchDisabled = false;
    }
  }

  TrackEntry? getCurrent(int trackIndex) {
    if (trackIndex >= _tracks.length) return null;
    return _tracks[trackIndex];
  }

  void clearListeners() {
    removeEventListeners('start');
    removeEventListeners('interrupt');
    removeEventListeners('end');
    removeEventListeners('dispose');
    removeEventListeners('complete');
    removeEventListeners('event');
  }

  void clearListenerNotifications() {
    _trackEntryEvents.clear();
  }
}
