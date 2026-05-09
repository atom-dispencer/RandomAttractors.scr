#version 460 core

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

out float vs_path_fraction;

uniform float TIME_SECS = 0;

//
// A transformation matrix which translates (moves/slides) a vector in each
// direction by the magnitude of each of the components in vector 'v'.
//
mat4 translate(vec3 v)
{
    return mat4(
        1.0,  0.0,  0.0,  0.0,  // column 0
        0.0,  1.0,  0.0,  0.0,  // column 1
        0.0,  0.0,  1.0,  0.0,  // column 2
        v.x,  v.y,  v.z,  1.0   // column 3
    );
}

//
// A view matrix which is more 'human' - it projects the geometry into a
// diverging frustrum which makes closer objects appear larger - i.e. the
// viewing lines diverge with distance.
//
mat4 perspective(float fov_rads, float aspect, float znear, float zfar)
{
    float f = 1.0 / tan(fov_rads / 2.0);
    return mat4(
        f / aspect, 0.0, 0.0,                                 0.0,
        0.0,        f,   0.0,                                 0.0,
        0.0,        0.0, (zfar + znear)/(znear - zfar),       -1.0,
        0.0,        0.0, (2.0 * zfar * znear)/(znear - zfar), 0.0
    );
}

//
// A view matrix to apply an orthographic projection, i.e. vertex spacing does
// not decay with distance and all viewing lines are parallel.
//
mat4 orthographic(float left, float right, float bottom, float top, float znear, float zfar)
{
    return mat4(
        2.0/(right-left), 0.0,             0.0,             0.0,
        0.0,              2.0/(top-bottom),0.0,             0.0,
        0.0,              0.0,            -2.0/(zfar-znear),0.0,
       -(right+left)/(right-left), -(top+bottom)/(top-bottom), -(zfar+znear)/(zfar-znear), 1.0
    );
}

//
// A matrix to rotate a vector by 'rads' radians anticlockwise around the X axis.
//
mat4 x_rotation(float rads)
{
    float c = cos(rads);
    float s = sin(rads);

    // For some reason glsl matrices are column-major
    return mat4(
        1.0,  0.0,  0.0,  0.0, //
        0.0,  c,    s,    0.0, //
        0.0,  -s,    c,   0.0, //
        0.0,  0.0,  0.0,  1.0 //
    );
}

//
// A matrix to rotate a vector by 'rads' radians anticlockwise around the Y axis.
//
mat4 y_rotation(float rads)
{
    float c = cos(rads);
    float s = sin(rads);

    // For some reason glsl matrices are column-major
    return mat4(
        c,    0.0,  -s,   0.0,  // column 0
        0.0,  1.0,  0.0,  0.0,  // column 1
        s,    0.0,  c,    0.0,  // column 2
        0.0,  0.0,  0.0,  1.0   // column 3
    );
}

//
// A matrix to non-uniformly scale the components of a vector by the components
// of the scaling vector 's'.
//
mat4 scale(vec3 s)
{
    return mat4(
        s.x, 0.0, 0.0, 0.0, // c0
        0.0, s.y, 0.0, 0.0, // c1
        0.0, 0.0, s.z, 0.0, // c2
        0.0, 0.0, 0.0, 1.0  // c3
    );
}

//
// Let's do some shading!
//
void main()
{
  ControlPoint cp = control[gl_VertexID];
  vs_path_fraction = cp.path_fraction;

  float pi = 3.1415926f;
  float tau = 2*pi;

  float PITCH_RADS = tau * 0.125;               // eighth circle
  float ASPECT_RATIO = 1.7777;                  // 16:9

  float FOV_RADS = tau * 0.25;                  // quarter circle
  float Z_NEAR = 0.1;
  float Z_FAR = 100.0;

  float ortho_scale = 1.0;
  float o_left = -ortho_scale * ASPECT_RATIO;
  float o_right = ortho_scale * ASPECT_RATIO;
  float o_top = -ortho_scale;
  float o_bottom = ortho_scale;

  gl_Position = //
    // orthographic(o_left, o_right, o_top, o_bottom, -10, 10) // 4th - Apply the projection matrix
    perspective(FOV_RADS, ASPECT_RATIO, Z_NEAR, Z_FAR)          // 4th - Apply the projection matrix
    * translate(vec3(0.0, 0.0, -2))                         // 3rd - Translate away from the camera
    * x_rotation(PITCH_RADS)                                // 2nd - Pitch the mesh like we're looking from above
    // * y_rotation(y_rads)                                    // 1st - Yaw the mesh so it spins nicely
    // 
    * cp.position;
}
