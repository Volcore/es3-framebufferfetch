es3-framebufferfetch
====================

Demo to compare the performance of using glBlend vs GL_EXT_shader_framebuffer_fetch.

## Findings
On my iPad Mini Retina, using framebuffer fetch instead of alpha blending is about 20% slower.

The fillrate for simple untextured quads is about 2.5 gp/s using frame buffer fetch, and 3 gp/s using glBlend.
