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

class TrackEntry extends EventDispatcher {
  final int trackIndex;
  final Animation animation;
  List<int> timelineData = [];
  List<TrackEntry?> timelineDipMix = [];
  final List<num> timelinesRotation = [];

  TrackEntry? next;
  TrackEntry? mixingFrom;
  bool loop = false;

  double eventThreshold = 0;
  double attachmentThreshold = 0;
  double drawOrderThreshold = 0;

  double animationStart = 0;
  double animationEnd = 0;
  double animationLast = -1;
  double nextAnimationLast = -1;

  double delay = 0;
  double trackTime = 0;
  double trackLast = -1;
  double nextTrackLast = -1;
  double trackEnd = double.maxFinite;
  double timeScale = 1;

  double alpha = 1;
  double interruptAlpha = 1;
  double mixTime = 0;
  double mixDuration = 0;
  double totalAlpha = 0;

  TrackEntry(this.trackIndex, this.animation) {
    animationEnd = animation.duration;
  }

  //---------------------------------------------------------------------------

  EventStream<TrackEntryStartEvent> get onTrackStart => const EventStreamProvider<TrackEntryStartEvent>('start').forTarget(this);

  EventStream<TrackEntryInterruptEvent> get onTrackInterrupt => const EventStreamProvider<TrackEntryInterruptEvent>('interrupt').forTarget(this);

  EventStream<TrackEntryEndEvent> get onTrackEnd => const EventStreamProvider<TrackEntryEndEvent>('end').forTarget(this);

  EventStream<TrackEntryDisposeEvent> get onTrackDispose => const EventStreamProvider<TrackEntryDisposeEvent>('dispose').forTarget(this);

  EventStream<TrackEntryCompleteEvent> get onTrackComplete => const EventStreamProvider<TrackEntryCompleteEvent>('complete').forTarget(this);

  EventStream<TrackEntryEventEvent> get onTrackEvent => const EventStreamProvider<TrackEntryEventEvent>('event').forTarget(this);

  //---------------------------------------------------------------------------

  double getAnimationTime() {
    if (loop) {
      var duration = animationEnd - animationStart;
      if (duration == 0.0) return animationStart;
      return trackTime.remainder(duration) + animationStart;
    } else {
      return math.min(trackTime + animationStart, animationEnd);
    }
  }

  TrackEntry setTimelineData(TrackEntry? to, List<TrackEntry> mixingToArray, Set<int> propertyIDs) {
    if (to != null) mixingToArray.add(to);
    var lastEntry = mixingFrom?.setTimelineData(this, mixingToArray, propertyIDs) ?? this;
    if (to != null) mixingToArray.removeLast();

    var timelinesCount = animation.timelines.length;

    timelineData = List.filled(timelinesCount, 0);
    timelineDipMix = List.filled(timelinesCount, null);

    outer:
    for (var i = 0; i < timelinesCount; i++) {
      var id = animation.timelines[i].getPropertyId();
      if (propertyIDs.add(id) == false) {
        timelineData[i] = AnimationState.subsequent;
      } else if (to == null || to._hasTimeline(id) == false) {
        timelineData[i] = AnimationState.first;
      } else {
        for (var ii = mixingToArray.length - 1; ii >= 0; ii--) {
          var entry = mixingToArray[ii];
          if (entry._hasTimeline(id) == false) {
            if (entry.mixDuration > 0) {
              timelineData[i] = AnimationState.dipMix;
              timelineDipMix[i] = entry;
              continue outer;
            }
            break;
          }
        }
        timelineData[i] = AnimationState.dip;
      }
    }
    return lastEntry;
  }

  bool _hasTimeline(int id) {
    var timelines = animation.timelines;
    for (var i = 0; i < timelines.length; i++) {
      if (timelines[i].getPropertyId() == id) return true;
    }
    return false;
  }

  void resetRotationDirection() {
    timelinesRotation.clear();
  }

  @override
  String toString() => animation.name;
}
