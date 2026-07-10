// InkShaderTypes.h
// Shared type definitions between Swift and Metal shader code

#ifndef InkShaderTypes_h
#define InkShaderTypes_h

#include <simd/simd.h>

// MARK: - Vertex Data

/// A single vertex for ink rendering.
/// Each point on the stroke generates two vertices (one on each side of the path).
typedef struct {
    /// Position in clip space (Metal NDC)
    vector_float2 position;

    /// UV coordinates for texture sampling
    vector_float2 textureCoordinate;

    /// Opacity (from pressure and tool settings)
    float alpha;

    /// Width of the stroke at this vertex (in screen points)
    float width;
} InkVertex;

// MARK: - Uniform Buffers

/// Uniform data that changes per frame (viewport, zoom, pan)
typedef struct {
    /// The view-projection matrix (canvas → clip space)
    matrix_float4x4 viewProjectionMatrix;

    /// Canvas zoom scale
    float zoomScale;

    /// Canvas dimensions in points
    vector_float2 canvasSize;

    /// Viewport dimensions in pixels
    vector_float2 viewportSize;

    /// Time since app launch (for animated effects)
    float time;
} FrameUniforms;

/// Uniform data that changes per stroke (color, tool settings)
typedef struct {
    /// Stroke color as packed RGBA
    vector_float4 strokeColor;

    /// Base stroke width
    float strokeWidth;

    /// Brush type (0=fountainPen, 1=pencil, 2=marker, etc.)
    unsigned int brushType;

    /// Brush-specific parameter (e.g., texture index)
    float brushParameter;

    /// Whether to use pressure-based width
    bool usePressureWidth;

    /// Padding for 16-byte alignment
    float padding[2];
} StrokeUniforms;

// MARK: - Constants

/// Maximum number of vertices per stroke
#define MAX_VERTICES_PER_STROKE 65536

/// Maximum number of strokes per draw call
#define MAX_STROKES_PER_DRAW 1024

/// Ink texture atlas size
#define TEXTURE_ATLAS_SIZE 1024

#endif /* InkShaderTypes_h */
