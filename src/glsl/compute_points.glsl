#version 460 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer PointData
{
    vec4 points[];
};

uniform float y_offset;

void main()
{
    vec4 up = vec4(0.0, y_offset, 0.0, 0.0);

    points[0] = vec4(-1.000, +0.000, 1.0f, 1.0f) + up;
    points[1] = vec4(+0.000, +0.875, 1.0f, 1.0f) + up;
    points[2] = vec4(+0.750, +0.000, 1.0f, 1.0f) + up;
    points[3] = vec4(-0.000, -0.625, 1.0f, 1.0f) + up;
    points[4] = vec4(-0.500, +0.000, 1.0f, 1.0f) + up;
    points[5] = vec4(+0.000, +0.375, 1.0f, 1.0f) + up;
    points[6] = vec4(+0.250, +0.000, 1.0f, 1.0f) + up;
    points[7] = vec4(-0.000, -0.125, 1.0f, 1.0f) + up;
    points[8] = vec4(-0.000, +0.000, 1.0f, 1.0f) + up;
}
