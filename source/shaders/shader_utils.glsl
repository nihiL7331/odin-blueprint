// This file contains helper functions for shader.glsl.
// Can be expanded further if needed.

//shout out sam hocevar
vec3 rgbToHsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10; // 0.0000000001
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsvToRgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 hexToRgb(int hex) {
  return vec3(
      float((hex >> 16) & 0xFF),
      float((hex >> 8 ) & 0xFF),
      float((hex      ) & 0xFF)
      ) / 255.0;
}

bool almostEquals(vec3 a, vec3 b, float epsilon) {
  return all(lessThan(abs(a - b), vec3(epsilon)));
}

float square(float x) {
  return x * x;
}

vec2 localUvToAtlasUv(vec2 localUv, vec4 atlasRect) {
  vec2 size = atlasRect.zw - atlasRect.xy;

  vec2 wrapped = fract(localUv);

  const float epsilon = 0.0001;
  wrapped = clamp(wrapped, vec2(epsilon), vec2(1.0 - epsilon));

  return atlasRect.xy + (size * wrapped);
}
