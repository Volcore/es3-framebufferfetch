#version 300 es
#extension GL_EXT_shader_framebuffer_fetch : require
uniform mediump vec4 uni_color;
inout mediump vec4 out_color;

void main() {
  // Compute the alpha blend
  out_color.xyz = mix(out_color.xyz, uni_color.xyz, uni_color.a);
}
