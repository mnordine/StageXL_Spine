/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

part of stagexl_spine;

class DeformTimeline extends CurveTimeline {

  final Float32List frames;
  final List<Float32List> frameVertices;

  int slotIndex = 0;
  VertexAttachment attachment = null;

  DeformTimeline (int frameCount)
    : frames = new Float32List(frameCount),
      frameVertices = new List<Float32List>(frameCount),
      super(frameCount);

  @override
  int getPropertyId() {
    return (TimelineType.deform.ordinal << 24) + slotIndex;
  }

  /// Sets the time and value of the specified keyframe.

  void setFrame(int frameIndex, double time, Float32List vertices) {
    frames[frameIndex] = time;
    frameVertices[frameIndex] = vertices;
  }

  @override
  void apply(
      Skeleton skeleton, double lastTime, double time, List<Event> firedEvents,
      double alpha, bool setupPose, bool mixingOut) {

    Slot slot = skeleton.slots[slotIndex];
    if (slot.attachment is! VertexAttachment) return;
    VertexAttachment vertexAttachment = slot.attachment;
    if (vertexAttachment.applyDeform(attachment) == false) return;

    Float32List frames = this.frames;
    if (time < frames[0]) return; // Time is before first frame.

    List<Float32List> frameVertices = this.frameVertices;
    int vertexCount = frameVertices[0].length;

    Float32List vertices = slot.attachmentVertices;
    if (vertices.length != vertexCount) {
      alpha = 1.0; // Don't mix from uninitialized slot vertices.
      vertices = slot.attachmentVertices = new Float32List(vertexCount);
    }

    List<num> setupVertices;
    double setup = 0.0, prev = 0.0;

    if (time >= frames[frames.length - 1]) { // Time is after last frame.
      Float32List lastVertices = frameVertices[frames.length - 1];
      if (alpha == 1) {
        // Vertex positions or deform offsets, no alpha.
        for (int i = 0; i < vertexCount; i++) {
          vertices[i] = lastVertices[i];
        }
      } else if (setupPose) {
        if (vertexAttachment.bones == null) {
          // Unweighted vertex positions, with alpha.
          setupVertices = vertexAttachment.vertices;
          for (int i = 0; i < vertexCount; i++) {
            setup = setupVertices[i];
            vertices[i] = setup + (lastVertices[i] - setup) * alpha;
          }
        } else {
          // Weighted deform offsets, with alpha.
          for (int i = 0; i < vertexCount; i++) {
            vertices[i] = lastVertices[i] * alpha;
          }
        }
      } else {
        // Vertex positions or deform offsets, with alpha.
        for (int i = 0; i < vertexCount; i++) {
          vertices[i] += (lastVertices[i] - vertices[i]) * alpha;
        }
      }
      return;
    }

    // Interpolate between the previous frame and the current frame.
    int frame = Animation.binarySearch1(frames, time);
    Float32List prevVertices = frameVertices[frame - 1];
    Float32List nextVertices = frameVertices[frame];
    double frameTime = frames[frame];
    double percent = getCurvePercent(frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

    if (alpha == 1) {
      // Vertex positions or deform offsets, no alpha.
      for (int i = 0; i < vertexCount; i++) {
        prev = prevVertices[i];
        vertices[i] = prev + (nextVertices[i] - prev) * percent;
      }
    } else if (setupPose) {
      if (vertexAttachment.bones == null) {
        // Unweighted vertex positions, with alpha.
        setupVertices = vertexAttachment.vertices;
        for (int i = 0; i < vertexCount; i++) {
          prev = prevVertices[i];
          setup = setupVertices[i];
          vertices[i] = setup + (prev + (nextVertices[i] - prev) * percent - setup) * alpha;
        }
      } else {
        // Weighted deform offsets, with alpha.
        for (int i = 0; i < vertexCount; i++) {
          prev = prevVertices[i];
          vertices[i] = (prev + (nextVertices[i] - prev) * percent) * alpha;
        }
      }
    } else {
      // Vertex positions or deform offsets, with alpha.
      for (int i = 0; i < vertexCount; i++) {
        prev = prevVertices[i];
        vertices[i] += (prev + (nextVertices[i] - prev) * percent - vertices[i]) * alpha;
      }
    }
  }

}

