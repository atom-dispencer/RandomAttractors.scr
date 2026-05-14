#version 460 core

layout(vertices = 4) out;

/**
 * Array containing the path fraction for each vertex in the patch as generated
 * in the vertex shader. 
 */
in  float vs_path_fraction[];
/** Direct copy of vs_path_fraction */
out float tcs_path_fraction[];

vec4 cubic_bezier_vec4(vec4 V0, vec4 V1, vec4 V2, vec4 V3, float t)
{
    float u = 1.0 - t;

    return
        V0 * 1.0 * u*u*u +
        V1 * 3.0 * u*u*t +
        V2 * 3.0 * u*t*t +
        V3 * 1.0 * t*t*t ;
}

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
        // Calculate TessLevelOuter[1]
        //

        /**
         * 0.5 looks like a sea urchin, 0.1 looks a little crunchy, 0.05 you
         * can see the corners if you squint but it's not noticeable as:
         *
         * (a) the mesh is moving
         * (b) the pixels are a little blocky anyway
         */
        const float max_distance_aspect_ratio = 0.05;

        bool untessellated = true;
        int tess_level = 0;

        do
        {
            untessellated = false;
            tess_level++;

            for (int node = 0; node < tess_level; node++)
            {
                float t_chord_start = float(node) / float(tess_level);
                vec4 chord_start  = cubic_bezier_vec4(
                    gl_in[0].gl_Position,
                    gl_in[1].gl_Position,
                    gl_in[2].gl_Position,
                    gl_in[3].gl_Position,
                    t_chord_start
                );

                float t_chord_end = float(node+1) / float(tess_level);
                vec4 chord_end = cubic_bezier_vec4(
                    gl_in[0].gl_Position,
                    gl_in[1].gl_Position,
                    gl_in[2].gl_Position,
                    gl_in[3].gl_Position,
                    t_chord_end
                );

                vec4 chord_middle = mix(chord_start, chord_end, 0.5);
                vec4 chord = chord_end - chord_start;

                float t_curve_middle = mix(t_chord_start, t_chord_end, 0.5);
                vec4 curve_middle = cubic_bezier_vec4(
                    gl_in[0].gl_Position,
                    gl_in[1].gl_Position,
                    gl_in[2].gl_Position,
                    gl_in[3].gl_Position,
                    t_curve_middle
                );

                vec4 diff = chord_middle - curve_middle;
                float aspect_ratio = length(diff) / length(chord);
                if (aspect_ratio > max_distance_aspect_ratio)
                {
                    untessellated = true;
                }
            }

        // 128 is way high enough, but we want as low as possible
        } while (untessellated && tess_level < 128);

        //
        // The TPG uses OUTER[1] to determine how to subdivide each
        // isoline.
        //
        // In this case, that means subdividing each curve into segments which
        // will be arranged to closely approximate the Bezier curve represented
        // by this patch.
        // 
        gl_TessLevelOuter[1] = tess_level;

        // NOTE!!!
        // BEFORE YOU START PLAYING WITH DYNAMIC TESSELLATION LEVELS, GO AND
        // IMPLEMENT THE BEZIER EVALUATION IN THE TES AND MAKE SURE IT WORKS
        // FIRST!!!

        // Isolines ignore the INNER tessellation levels.
    }
}