#version 330 core
layout(location = 0) in vec3 aPos;
uniform float y_rads;

out vec3 vColor;

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
  vColor = normalize(aPos * 0.5 + 0.5);

  float FOV_RADS = 3.14159 * 0.5;     // quarter circle
  float ASPECT_RATIO = 1.7777;        // 16:9
  float PITCH_RADS = 3.14159 * 0.25; // eighth circle

  float ortho_scale = 1.0;
  float o_left = -ortho_scale * ASPECT_RATIO;
  float o_right = ortho_scale * ASPECT_RATIO;
  float o_top = -ortho_scale;
  float o_bottom = ortho_scale;

  gl_Position = //
    orthographic(o_left, o_right, o_top, o_bottom, -10, 10)
    * translate(vec3(0.0, 0.0, -5))                   // 4th - Translate away from the camera
    * x_rotation(PITCH_RADS)                          // 3rd - Pitch the mesh like we're looking from above
    * y_rotation(y_rads)                              // 2nd - Yaw the mesh so it spins nicely
    // 
    * vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
