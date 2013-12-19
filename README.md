es3-framebufferfetch
====================

Demo to compare the performance of using glBlend vs GL_EXT_shader_framebuffer_fetch.

## Observations
On my iPad Mini Retina, using framebuffer fetch instead of alpha blending is about 20% slower when using highp, and about the same speed when using mediump.

The fillrate for simple untextured quads is about 2.5 gp/s using framebuffer fetch using highp, and 3 gp/s using glBlend or framebuffer fetch with mediump.

## Conclusion
On current gen hardware, when possible, framebuffer fetch should be used with mediump, as highp brings a 20% penalty. With that in mind, there seems to be no performance penalty in using framebuffer fetch.
