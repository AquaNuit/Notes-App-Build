// Shaders.metal
// Metal shaders for ink rendering pipeline

#include <metal_stdlib>
#include "InkShaderTypes.h"

using namespace metal;

// MARK: - Vertex Output Types

/// Output struct for ink vertex shader.
/// Must include [[position]] attribute for Metal's rasterizer.
struct InkVertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
    float alpha;
    float width;
};

/// Output struct for full-screen quad vertex shader.
struct CompositeVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Vertex Shaders

/// Vertex shader for ink strokes.
/// Transforms canvas-space vertices to clip space and passes
/// texture coordinates and alpha to the fragment shader.
vertex InkVertexOut inkVertexShader(
    const device InkVertex *vertices [[buffer(0)]],
    constant FrameUniforms &frame [[buffer(1)]],
    unsigned int vertexID [[vertex_id]]
) {
    InkVertex vertex = vertices[vertexID];

    // Transform position from canvas space to clip space
    float4 clipPosition = float4(vertex.position, 0.0, 1.0);
    clipPosition = frame.viewProjectionMatrix * clipPosition;

    InkVertexOut out;
    out.position = clipPosition;
    out.textureCoordinate = vertex.textureCoordinate;
    out.alpha = vertex.alpha;
    out.width = vertex.width;

    return out;
}

// MARK: - Fragment Shaders

/// Fragment shader for basic solid ink (fountain pen, calligraphy).
/// Applies color with alpha blending.
fragment float4 inkFragmentShader(
    InkVertexOut in [[stage_in]],
    constant StrokeUniforms &stroke [[buffer(2)]]
) {
    // For non-textured brushes, just output the stroke color with alpha
    float alpha = stroke.strokeColor.a * in.alpha;
    return float4(stroke.strokeColor.rgb, alpha);
}

/// Fragment shader for textured brushes (pencil, marker).
/// Samples the brush texture at the given UV coordinates.
fragment float4 texturedInkFragmentShader(
    InkVertexOut in [[stage_in]],
    constant StrokeUniforms &stroke [[buffer(2)]],
    texture2d<float> brushTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    float4 textureColor = brushTexture.sample(textureSampler, in.textureCoordinate);
    float alpha = textureColor.r * stroke.strokeColor.a * in.alpha;

    return float4(stroke.strokeColor.rgb, alpha);
}

/// Fragment shader for marker ink with opacity buildup.
/// Accumulates alpha for overlapping strokes.
fragment float4 markerFragmentShader(
    InkVertexOut in [[stage_in]],
    constant StrokeUniforms &stroke [[buffer(2)]]
) {
    // Marker alpha is lower to show buildup on overlapping strokes
    float markerAlpha = 0.3;
    float alpha = stroke.strokeColor.a * in.alpha * markerAlpha;
    return float4(stroke.strokeColor.rgb, alpha);
}

/// Fragment shader for the highlighter tool.
/// Uses a subtractive blend style with luminance preservation.
fragment float4 highlighterFragmentShader(
    InkVertexOut in [[stage_in]],
    constant StrokeUniforms &stroke [[buffer(2)]]
) {
    float highlighterAlpha = 0.25 * in.alpha;
    return float4(stroke.strokeColor.rgb, highlighterAlpha);
}

/// Fragment shader for the pixel eraser.
/// Sets alpha to 0 to erase content beneath.
fragment float4 eraserFragmentShader(
    InkVertexOut in [[stage_in]],
    constant StrokeUniforms &stroke [[buffer(2)]]
) {
    return float4(0.0, 0.0, 0.0, 0.0);
}

// MARK: - Background Grid Shader

/// Vertex shader for background grid rendering.
vertex float4 gridVertexShader(
    const device float2 *vertices [[buffer(0)]],
    constant FrameUniforms &frame [[buffer(1)]],
    unsigned int vertexID [[vertex_id]]
) {
    float2 position = vertices[vertexID];
    float4 clipPosition = float4(position, 0.0, 1.0);
    clipPosition = frame.viewProjectionMatrix * clipPosition;
    return clipPosition;
}

/// Fragment shader for grid lines.
fragment float4 gridFragmentShader(
    constant float4 &gridColor [[buffer(0)]]
) {
    return gridColor;
}

// MARK: - Full-Screen Quad Shader

/// Vertex shader for full-screen quad rendering (used for render target composition).
/// Derives texture coordinates from NDC vertex position.
vertex CompositeVertexOut fullScreenQuadVertex(
    const device float2 *vertices [[buffer(0)]],
    unsigned int vertexID [[vertex_id]]
) {
    CompositeVertexOut out;
    out.position = float4(vertices[vertexID], 0.0, 1.0);
    // Convert from NDC [-1, 1] to UV [0, 1]
    out.texCoord = (out.position.xy + float2(1.0)) * float2(0.5);
    return out;
}

/// Fragment shader for compositing render targets.
fragment float4 compositeFragmentShader(
    CompositeVertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]]
) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    return sourceTexture.sample(s, in.texCoord);
}
