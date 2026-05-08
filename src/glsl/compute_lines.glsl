#version 460 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer PointData
{
    vec4 points[];
};

struct LineDataPoint
{
    vec4 pos;
    vec4 data;
};

layout(std430, binding = 1) buffer LineData
{
    LineDataPoint line_data[];
};

uniform int point_count;
uniform int line_count;

void main()
{
    // Build line strip from the point buffer using GL_LINES
    // Each line connects consecutive points
    int line_idx = 0;
    for (int i = 0; i < point_count - 1 && line_idx < line_count - 1; ++i)
    {
        line_data[line_idx].pos = points[i];
        line_idx++;
        line_data[line_idx].pos = points[i + 1];
        line_idx++;
    }

    // Fill remaining line data with zeros
    for (int i = line_idx; i < line_count; ++i)
    {
        line_data[i].data = vec4(0.0);
    }
}
