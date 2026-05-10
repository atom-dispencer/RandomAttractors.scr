#version 460 core

layout(vertices = 4) out;

/**
 * Array containing the path fraction for each vertex in the patch as generated
 * in the vertex shader. 
 */
in  float vs_path_fraction[];
/** Direct copy of vs_path_fraction */
out float tcs_path_fraction[];

void main()
{

    //
    // Pass control points straight through
    // The TCS can optionally transform the control points, but we don't want
    // to do that
    //
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
    tcs_path_fraction[gl_InvocationID] = vs_path_fraction[gl_InvocationID];

    //
    // The TCS is run on each of the vertices in the patch.
    //
    // The InvocationID tells us which vertex we're running on currently.
    //
    // The tessellation levels are defined for the whole patch in the same
    // array, which is specific to the PATCH rather than any single invocation.
    //
    // In this case, Invocation #0 controls tessellation levels for the whole
    // patch.
    //
    if (gl_InvocationID == 0)
    {
        // 
        // The TPG uses OUTER[0] to determine how many side-by-side
        // (NOT end-to-end) abstract isolines to generate for this patch.
        //
        // Each patch represents the control points of exactly 1 full Bezier.
        // Given that we want one continuous curve per Bezier, we therefore
        // generate one abstract-isoline per patch.
        // 
        gl_TessLevelOuter[0] = 1.0;

        //
        // The TPG uses OUTER[1] to determine how to subdivide each
        // isoline.
        //
        // In this case, that means subdividing each curve into segments which
        // will be arranged to closely approximate the Bezier curve represented
        // by this patch.
        // 
        gl_TessLevelOuter[1] = 16.0;

        // NOTE!!!
        // BEFORE YOU START PLAYING WITH DYNAMIC TESSELLATION LEVELS, GO AND
        // IMPLEMENT THE BEZIER EVALUATION IN THE TES AND MAKE SURE IT WORKS
        // FIRST!!!

        // Isolines ignore the INNER tessellation levels.
    }
}