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

void main()
{
    // Build an example line strip from the point buffer using GL_LINES.
    line_data[0].pos = points[0];
    line_data[1].pos = points[1];
    line_data[2].pos = points[1];
    line_data[3].pos = points[2];
    line_data[4].pos = points[2];
    line_data[5].pos = points[3];
    line_data[6].pos = points[3];
    line_data[7].pos = points[4];
    line_data[8].pos = points[4];
    line_data[9].pos = points[5];
    line_data[10].pos = points[5];
    line_data[11].pos = points[6];

    for (int i = 0; i < 12; ++i)
    {
        line_data[i].data = vec4(0.0);
    }
}
