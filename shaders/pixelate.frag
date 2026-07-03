#include <flutter/flutter.glsl>

uniform sampler2D image;
uniform vec2 resolution;
uniform float blockSize;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / resolution;
    
    // Calculate pixelation
    float dx = blockSize / resolution.x;
    float dy = blockSize / resolution.y;
    
    vec2 coord = vec2(
        dx * floor(uv.x / dx),
        dy * floor(uv.y / dy)
    );
    
    fragColor = texture(image, coord);
}
