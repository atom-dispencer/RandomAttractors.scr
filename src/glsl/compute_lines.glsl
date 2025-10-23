#version 460 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

struct LineDataPoint
{
  vec4 pos;
  vec4 data;
};

layout(std430, binding = 0) buffer LineData
{
  LineDataPoint line_data[];
};

void main()
{
    // Edge 0: Apex → Base vertex 0
    line_data[0].pos = vec4(0.0f, 0.75f, 0.0f, 1.0);
    line_data[1].pos = vec4(-0.75f, -0.25f, 0.2887f, 1.0);

    // Edge 1: Apex → Base vertex 1
    line_data[2].pos = vec4(0.0f, 0.75f, 0.0f, 1.0);
    line_data[3].pos = vec4(0.5f, -0.25f, 0.2887f, 1.0);

    // Edge 2: Apex → Base vertex 2
    line_data[4].pos = vec4(0.0f, 0.75f, 0.0f, 1.0);
    line_data[5].pos = vec4(0.0f, -0.25f, -0.5774f, 1.0);

    // Edge 3: Base edge 0–1
    line_data[6].pos = vec4(-0.75f, -0.25f, 0.2887f, 1.0);
    line_data[7].pos = vec4(0.5f, -0.25f, 0.2887f, 1.0);

    // Edge 4: Base edge 1–2
    line_data[8].pos = vec4(0.5f, -0.25f, 0.2887f, 1.0);
    line_data[9].pos = vec4(0.0f, -0.25f, -0.5774f, 1.0);

    // Edge 5: Base edge 2–0
    line_data[10].pos = vec4(0.0f, -0.25f, -0.5774f, 1.0);
    line_data[11].pos = vec4(-0.75f, -0.25f, 0.2887f, 1.0);
}
