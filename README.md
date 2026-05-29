StageXL_Spine
=============

The Spine runtime for the StageXL library.

*NOTE:* as of version 0.10.0-dev, `StageXL_Spine` requires a Dart 2 SDK. 

[![Build Status](https://travis-ci.org/bp74/StageXL_Spine.svg?branch=master)](https://travis-ci.org/bp74/StageXL_Spine)

## Examples

Raptor (<http://www.stagexl.org/show/spine/raptor/example.html>)  
Tank (<http://www.stagexl.org/show/spine/tank/example.html>)  
Stretchyman (<http://www.stagexl.org/show/spine/stretchyman/example.html>)  
SpineBoy (<http://www.stagexl.org/show/spine/spineboy/example.html>)  
Goblins (<http://www.stagexl.org/show/spine/goblins/example.html>)  
PowerUp (<http://www.stagexl.org/show/spine/powerup/example.html>)  
Hero (<http://www.stagexl.org/show/spine/hero/example.html>)  
Coin (<http://www.stagexl.org/show/spine/coin/example.html>)  
Combined (<http://www.stagexl.org/show/spine/texture_atlas/example.html>)  

## Spine Runtime

Based on the spine-as3 runtime (2017-07-01)
This runtime supports the export format and features of Spine v3.6.

<https://github.com/EsotericSoftware/spine-runtimes/tree/3.6/spine-as3>

## Restricted Spine 4.3 JSON Support

This package also supports a restricted subset of Spine 4.3 JSON exports. The 4.3 path is intended
for projects that author in Spine 4.3 and need smooth animation curves in StageXL without exporting
down to Spine 3.6, because down-exporting can flatten or lose curve information.

Supported in the 4.3 subset:

- Bones and slots.
- Region attachments.
- Existing mesh support where it is compatible with this runtime.
- Skin arrays exported as `skins: [{ name, attachments }]`.
- Bone timelines for rotate, translate, scale, shear, and their X/Y variants.
- Slot attachment timelines and basic color timelines (`rgba`, `rgb`, `alpha`, `rgba2`, `rgb2`).
- Draw order and events.
- Linear, stepped, and Bezier curves, including separate curves per value for multi-value bone
  timelines.

Unsupported 4.3 features fail fast with `UnsupportedError` instead of silently rendering incorrectly.
This includes physics constraints, slider constraints/timelines, sequence attachments/timelines,
4.3 constraint arrays, draw-order folders, inverse clipping, and attachment or timeline types that
are not listed above.

Artist export rules:

- Export JSON, not binary `.skel` or `.spine`.
- Keep animation curves in the Spine 4.3 export.
- Avoid physics, sliders, sequences, draw-order folders, inverse clipping, and advanced 4.3
  constraint features.
- Prefer simple region attachments for assets that must be guaranteed to work in this runtime.

## Spine License
  
Spine Runtimes Software License v2.5    
  
Copyright (c) 2013-2016, Esoteric Software  
All rights reserved.    
  
You are granted a perpetual, non-exclusive, non-sublicensable, and  
non-transferable license to use, install, execute, and perform the Spine  
Runtimes software and derivative works solely for personal or internal  
use. Without the written permission of Esoteric Software (see Section 2 of  
the Spine Software License Agreement), you may not (a) modify, translate,  
adapt, or develop new applications using the Spine Runtimes or otherwise  
create derivative works or improvements of the Spine Runtimes or (b) remove,  
delete, alter, or obscure any trademarks or any copyright, trademark, patent,  
or other intellectual property or proprietary rights notices on or in the  
Software, including any copy thereof. Redistributions in binary or source  
form must include this license and terms.    
     
THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR  
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF  
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO  
EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,  
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF  
USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER  
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)  
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE  
POSSIBILITY OF SUCH DAMAGE.  
