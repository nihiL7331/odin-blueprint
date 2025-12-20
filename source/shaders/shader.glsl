// for shaders we use the same naming convention, with the difference being 
// "a" vertex in (attributes)
// "v" vertex out/fragment in (varyings)
// "o" fragment out (outputs)
// "u" for cpu called (uniforms)
@header package shaders
@header import sg "../libs/sokol/gfx"
@header import "../types/gmath"

@ctype vec4 gmath.Vec4
@ctype mat4 gmath.Mat4

// NOTE: VERTEX SHADER
@vs vs

in vec2 aPosition;
in vec4 aColor;
in vec2 aUv;
in vec2 aLocalUv;
in vec2 aSize;
in vec4 aBytes;
in vec4 aColorOverride;
in vec4 aParams;

out vec2 vPosition;
out vec4 vColor;
out vec2 vUv;
out vec2 vLocalUv;
out vec2 vSize;
out vec4 vBytes;
out vec4 vColorOverride;
out vec4 vParams;

void main() {
  gl_Position = vec4(aPosition, 0, 1);

  vPosition = gl_Position.xy;
  vColor = aColor;
  vUv = aUv;
  vLocalUv = aLocalUv;
  vBytes = aBytes;
  vColorOverride = aColorOverride;
  vSize = aSize;
  vParams = aParams;
}
@end

// NOTE: FRAGMENT SHADER
@fs fs

@include shader_utils.glsl

layout(binding=0) uniform texture2D uTex;
layout(binding=1) uniform texture2D uFontTex;
layout(binding=0) uniform sampler uDefaultSampler;
layout(binding=0) uniform ShaderData {
  mat4 ndcToWorldXForm;
  vec4 bgRepeatTexAtlasUv;
};

in vec2 vPosition;
in vec4 vColor;
in vec2 vUv;
in vec2 vLocalUv;
in vec2 vSize;
in vec4 vBytes;
in vec4 vColorOverride;
in vec4 vParams;

out vec4 oColor;

// shared with QuadFlags definition
#define FLAG_backgroundPixels (1<<0)
#define FLAG_2 (1<<1)
#define FLAG_3 (1<<2)
bool hasFlag(int flags, int flag) { return (flags & flag) != 0; }

void main() {
  int texIndex = int(vBytes.x * 255.0);
  int flags = int(vBytes.z * 255.0);
  vec2 worldPixel = (ndcToWorldXForm * vec4(vPosition.xy, 0, 1)).xy;
  vec4 texColor = vec4(1.0);

  if (texIndex == 0) {
    texColor = texture(sampler2D(uTex, uDefaultSampler), vUv);
  } else if (texIndex == 1) {
    texColor.a = texture(sampler2D(uFontTex, uDefaultSampler), vUv).r;
  }

  oColor = texColor;

  if (hasFlag(flags, FLAG_backgroundPixels)) {
    float wrapLength = 128.0; // repeat every 128px
    vec2 ratio = worldPixel / wrapLength;
    vec2 finalUv = localUvToAtlasUv(ratio, bgRepeatTexAtlasUv);

    vec4 img = texture(sampler2D(uTex, uDefaultSampler), finalUv);
    oColor.rgb = img.rgb;
  }

  oColor *= vColor;

  oColor.rgb = mix(oColor.rgb, vColorOverride.rgb, vColorOverride.a);
}

@end 

@program quad vs fs
