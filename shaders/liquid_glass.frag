// Liquid glass — edge refraction for the navigation layer.
//
// A BackdropFilter blur makes a surface *frosted*; it does not make it read as
// a solid piece of glass. What sells the solid is that light bends as it passes
// through the edge, so what you see near the rim is displaced and compressed
// relative to what you see through the middle. That is the whole effect here.
//
// The surface is described as a rounded-rect signed distance field. The SDF
// gradient gives a surface normal, the normal drives a lookup offset into the
// blurred backdrop, and the offset is weighted so it is zero in the flat centre
// and strongest just inside the rim — the same falloff a bevelled pane has.
//
// Deliberately NOT a full-surface distortion. Apple's `clear` variant warps
// everything and is prescribed only for media backdrops; over a ledger it would
// fight the text. Refraction stays in the rim band.

#include <flutter/runtime_effect.glsl>

// Must be first, and the engine sets it to the bound texture's size.
uniform vec2 uSize;

// Corner radius in physical pixels.
uniform float uRadius;

// Width of the refracting band inward from the edge, in physical pixels.
uniform float uEdge;

// How far, in physical pixels, the rim displaces its lookup at full strength.
uniform float uStrength;

// Specular rim intensity (0 disables the lit edge).
uniform float uSpecular;

// 1.0 for a light-on-dark rim (dark theme), 0.0 for the inverted dark rim.
uniform float uDark;

// The blurred backdrop, supplied by the engine.
uniform sampler2D uTexture;

out vec4 fragColor;

// Signed distance to a rounded rectangle centred at the origin.
// Negative inside, positive outside.
float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
  vec2 fragPx = FlutterFragCoord().xy;
  vec2 uv = fragPx / uSize;

  // Impeller's GLES backend hands the texture over with the y-axis reversed.
  // Sampling without this renders the backdrop upside-down.
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec2 halfSize = uSize * 0.5;
  vec2 centred = fragPx - halfSize;

  // Clamp the radius to what the box can actually hold, so a capsule (radius
  // == half the short side) stays a capsule instead of inverting.
  float radius = min(uRadius, min(halfSize.x, halfSize.y));
  float dist = roundedBoxSDF(centred, halfSize, radius);

  // Gradient of the SDF ≈ the outward normal of the glass surface.
  vec2 eps = vec2(1.0, 0.0);
  vec2 normal = normalize(vec2(
    roundedBoxSDF(centred + eps.xy, halfSize, radius) -
    roundedBoxSDF(centred - eps.xy, halfSize, radius),
    roundedBoxSDF(centred + eps.yx, halfSize, radius) -
    roundedBoxSDF(centred - eps.yx, halfSize, radius)
  ) + vec2(1e-6));

  // Refraction weight: 0 in the flat interior, rising to 1 at the rim.
  // smoothstep gives the eased shoulder a real bevel has; squaring it keeps
  // the centre genuinely undistorted so text under the middle stays readable.
  float band = clamp(uEdge, 1.0, max(halfSize.x, halfSize.y));
  float t = clamp(1.0 + dist / band, 0.0, 1.0);
  float weight = t * t * smoothstep(0.0, 1.0, t);

  // Pull the lookup *inward* along the normal: the rim samples what sits
  // further into the surface, which is what compresses the image at the edge
  // and reads as thickness.
  vec2 offsetPx = -normal * (uStrength * weight);
  vec2 refracted = uv + offsetPx / uSize;
  refracted = clamp(refracted, vec2(0.001), vec2(0.999));

  vec4 color = texture(uTexture, refracted);

  // Specular: a bright line hugging the inside of the rim, strongest where the
  // normal faces the light. Light sits above, so the top edge catches most.
  // In light mode the rim inverts to a shadow — a white line on a near-white
  // fill is invisible, but the shadow the same lighting casts is not.
  float rim = smoothstep(0.0, 1.0, weight);
  float facing = clamp(-normal.y, 0.0, 1.0);        // 1 at the top edge
  float lit = rim * mix(0.35, 1.0, facing) * uSpecular;

  vec3 rimColor = mix(vec3(0.0), vec3(1.0), uDark);
  color.rgb = mix(color.rgb, rimColor, lit * color.a);

  // Outside the shape contributes nothing; the Dart side clips to the same
  // geometry, this just avoids a hairline of unrefracted backdrop at the seam.
  float inside = 1.0 - smoothstep(-1.0, 1.0, dist);
  fragColor = color * inside;
}
