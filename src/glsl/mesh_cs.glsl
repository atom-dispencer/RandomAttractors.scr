#version 460 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

/**
 * The control points of the random attractor cubic bezier curve.
 *
 * If the points of the random attractor curve are:
 *   P1    P2    P3    P4
 *   P5    P6    P7    P8
 *   P9    P10   P11   P12
 *
 * Then the bezier control points are:
 *   P1    P2    P3    P4       : ( 4 unique + 0 overlap + 0 mirror) =  4 total
 *   P4    P4*   P5    P6       : ( 6 unique + 1 overlap + 1 mirror) =  8 total
 *   P6    P6*   P7    P8       : ( 8 unique + 2 overlap + 2 mirror) = 12 total
 *   P8    P8*   P9    P10      : (10 unique + 3 overlap + 3 mirror) = 16 total
 *   P10   P10*  P11   P12      : (12 unique + 4 overlap + 4 mirror) = 20 total
 *
 * ... where Px* is the mirrored control point of the previous two points:
 *   P(x)* = P(x) + (P(x) - P(x-1))
 *
 * Multiple paths (P, Q, R, ...) are concatenated in this buffer:
 *   P1 P2 P3 Q1 Q2 Q3 R1 R2 R3
 *
 * The size of this buffer is therefore:
 *   CONTROLS_PER_BEZIER * BEZIER_PER_PATH * PATH_COUNT
 *
 * Each path starts at:
 *   PATH_INDEX * (CONTROLS_PER_BEZIER * BEZIER_PER_PATH)
 *
 * Each curve therefore starts at:
 *   PATH_START + (CONTROLS_PER_BEZIER * BEZIER_INDEX)
 */
struct ControlPoint
{
    vec4 position;
    float path_fraction;
};
layout(std430, binding = 0) buffer ControlPoints
{
    ControlPoint control[];
};

/** The number of paths stored in the control buffer. */
uniform int PATH_COUNT;

/** The number of beziers stored in the control buffer. */
uniform int BEZIER_PER_PATH;

/** The number of control points which comprise each beziers in the control buffer. */
int CONTROLS_PER_BEZIER = 4;

int CONTROLS_PER_PATH = CONTROLS_PER_BEZIER * BEZIER_PER_PATH;

/**
 * @returns The index (in the control buffer) where the given path starts.
 */
int path_start(int path_index)
{
    // Clamp interval: [0, PATH_COUNT)
    if (path_index >= PATH_COUNT) path_index = PATH_COUNT - 1;
    if (path_index < 0) path_index = 0;

    int path_length = CONTROLS_PER_BEZIER * BEZIER_PER_PATH;
    return path_index * path_length;
}

/**
 * @returns The index (in the control buffer) where the given bezier starts.
 */
int bezier_start(int path_index, int bezier_index)
{
    // Clamp interval: [0, BEZIER_PER_PATH]
    if (bezier_index >= BEZIER_PER_PATH) bezier_index = BEZIER_PER_PATH - 1;
    if (bezier_index < 0) bezier_index = 0;

    int index_within_path = bezier_index * CONTROLS_PER_BEZIER;
    return path_start(path_index) + index_within_path;
}

/**
 * @returns The index (in the control buffer) where the given control point starts.
 */
int control_start(int path_index, int bezier_index, int ctrlpt_index)
{
    // Clamp interval: [0, BEZIER_PER_PATH]
    if (ctrlpt_index >= CONTROLS_PER_BEZIER) ctrlpt_index = CONTROLS_PER_BEZIER - 1;
    if (ctrlpt_index < 0) ctrlpt_index = 0;

    return bezier_start(path_index, bezier_index) + ctrlpt_index;
}

/**
 * @returns The control point (from the control buffer) at the given location.
 */
ControlPoint get_control(int path_index, int bezier_index, int ctrlpt_index)
{
    return control[control_start(path_index, bezier_index, ctrlpt_index)];
}

int _temp_point_index = 0;
vec4 generate_next_attractor_point()
{
    vec4 _defined_vertices[9] = 
    {
        vec4(-1.000, +0.000, 1.0, 1.0),
        vec4(+0.000, +0.875, 1.0, 1.0),
        vec4(+0.750, +0.000, 1.0, 1.0),
        vec4(-0.000, -0.625, 1.0, 1.0),
        vec4(-0.500, +0.000, 1.0, 1.0),
        vec4(+0.000, +0.375, 1.0, 1.0),
        vec4(+0.250, +0.000, 1.0, 1.0),
        vec4(-0.000, -0.125, 1.0, 1.0),
        vec4(-0.000, +0.000, 1.0, 1.0)
    };

    return _defined_vertices[_temp_point_index++];
}

vec4 mirrored_control_position(vec4 p1, vec4 p2)
{
    return p2 + (p2 - p1);
}

void main()
{
    /**
     * For our setup of cubic Beziers, where:
     * - The first control point of the Bezier curve B(x) shares the final
     *   point of B(x-1) to ensure position continuity
     * - The second control point of the curve B(x) is the mirror of the
     *   second-to-last control of B(x-1) across the final point of B(x-1),
     *   which ensures tangential continuity
     * 
     * The exception to these rules is the first curve, which has 4 unique
     * control as it has no predecessor with which to be continuous.
     */
    int UNIQUE_ATTRACTOR_POINTS = (2 * BEZIER_PER_PATH + 2);

    for (int i = 0; i < UNIQUE_ATTRACTOR_POINTS; i++)
    {
        vec4 p = generate_next_attractor_point();

        // If we're NOT in the first Bezier AND this would be the first control
        // point of this bezier, we need to set up continuity from the previous
        // Bezier
        if ((i >= CONTROLS_PER_BEZIER) && (i % CONTROLS_PER_BEZIER == 0))
        {
            // Position continuity
            control[i].position = control[i-1].position;
            control[i].path_fraction = float(i) / float(CONTROLS_PER_PATH);

            // Tangency continuity
            control[i+1].position = mirrored_control_position(control[i-2].position, control[i-1].position);
            control[i+1].path_fraction = float(i+1) / float(CONTROLS_PER_PATH);

            // Increment i past the continuity section
            // i will now be the 3rd (index=2) point in this Bezier
            i += 2;
        }

        control[i].position = p;
        control[i].path_fraction = float(i) / float(CONTROLS_PER_PATH);
    }
}