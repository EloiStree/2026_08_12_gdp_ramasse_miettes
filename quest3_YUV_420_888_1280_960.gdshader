shader_type canvas_item;

// Input: Raw YUV_420_888 texture (NV21 layout) from Quest 3 camera.
// Resolution hint: 2560x960 (stereo 1280x960 side-by-side).
// Uniform for the YUV texture (assign your OpenXR camera texture here).
uniform sampler2D yuv_tex : source_color, filter_nearest;

// YUV to RGB conversion matrix (BT.601 for SD/Quest camera feeds).
// Y' = 0.299R + 0.587G + 0.114B
// Cb = -0.169R - 0.331G + 0.500B - 0.5
// Cr = 0.500R - 0.419G - 0.081B - 0.5
const mat3 yuv2rgb = mat3(
    1.16438,  0.0,      1.59603,
    1.16438, -0.39176, -0.81297,
    1.16438,  2.01723,  0.0
);

// UV offset for chroma (half-res sampling).
void fragment() {
    // Get UV coords (0.0 to 1.0 across full texture).
    vec2 uv = UV;
    
    // Sample Y (luma) at full resolution.
    float y = texture(yuv_tex, uv).r;  // Y in R channel (0-1).
    
    // Sample UV chroma at half resolution (average over 2x2 block).
    // For NV21: UV interleaved in G/B (VU order: G=V, B=U? Wait, standard NV21: G=U, B=V? No—Android YUV_420_888 NV21 is Y in plane0, VU interleaved in plane1 (G=V? Standard is plane1: U then V? Actually, for texture: assume R unused, G=V, B=U for interleaved VU.
    // Correction for standard NV21 texture sampling: plane1 row: V U V U... (so even pixels V in G, U in B? No.
    // To simplify: sample full chroma pixel, then extract.
    vec3 yuv_sample = texture(yuv_tex, uv * vec2(1.0, 0.5)).gba;  // Bottom half for chroma rows.
    // For accurate NV21: YUV sample is .r = Y (but chroma rows are 0), for chroma rows: .g = V, .b = U (interleaved VU per pixel? No.
    // NV21 layout: Y plane full, then VU plane half height, each VU pixel is byte V then byte U (so in RGBA texture, for chroma: r=0, g=V, b=U, a=0 or junk.
    // So for chroma sampling:
    vec2 chroma_uv = uv * vec2(1.0, 0.5) + vec2(0.0, 0.5);  // Offset to chroma block.
    vec2 chroma_sample = texture(yuv_tex, chroma_uv).gb;  // G = V (0-1), B = U (0-1).
    float u = chroma_sample.y;  // U = Cr
    float v = chroma_sample.x;  // V = Cb? Wait, NV21 is V U per byte pair, so in texture .g = V, .b = U.
    // Yes: u = chroma_sample.b; v = chroma_sample.g; but standard BT.601 uses Cb=U, Cr=V.
    // Let's set:
    float cb = chroma_sample.b - 0.5;  // Cb = U - 0.5
    float cr = chroma_sample.g - 0.5;  // Cr = V - 0.5? No—for NV21, the interleaved is V (first byte) U (second), but in 32-bit texture, it's packed as g=V/255, b=U/255 for each 'pixel' in chroma plane.
    // To match standard: assume .g = V, .b = U, and for BT.601, Cb = U, Cr = V.
    float cb = chroma_sample.b - 0.5;  // Cb (U)
    float cr = chroma_sample.g - 0.5;  // Cr (V)
    
    // Full YUV: Y (0-1), Cb/Cr (-0.5 to 0.5)
    vec3 yuv = vec3(y - 0.0625, cb, cr);  // Y offset for full range (16/255 ≈0.0625 for studio).
    
    // Convert to RGB.
    vec3 rgb = yuv2rgb * yuv;
    
    // Clamp to valid range.
    rgb = clamp(rgb, 0.0, 1.0);
    
    // Output (preserve alpha if needed; camera usually opaque).
    COLOR = vec4(rgb, 1.0);
}