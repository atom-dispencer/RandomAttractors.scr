#version 460 core

layout(vertices = 4) out;

in  float vs_path_fraction[];
out float tcs_path_fraction[];

void main()
{
    tcs_path_fraction[gl_InvocationID] = vs_path_fraction[gl_InvocationID];

    //
    // Pass control points straight through
    //
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;

    //
    // One invocation sets tessellation levels
    //
    if (gl_InvocationID == 0)
    {
        // Number of generated line segments
        gl_TessLevelOuter[0] = 16.0;

        // Number of isolines
        gl_TessLevelOuter[1] = 1.0;
    }
}