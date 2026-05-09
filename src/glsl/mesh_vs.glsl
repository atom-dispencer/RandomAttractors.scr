#version 460 core

layout(location = 0) in vec4 in_position;
layout(location = 1) in float in_path_fraction;
layout(location = 2) in float _unused1;
layout(location = 3) in float _unused2;
layout(location = 4) in float _unused3;

uniform float TIME_SECS = 0;

out float vs_path_fraction;
out float tes_path_fraction; /// ONLY FOR GL_POINTS

mat4 translate(vec3 v)
{
    return mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        v.x, v.y, v.z, 1.0
    );
}

mat4 perspective(float fov_rads, float aspect, float znear, float zfar)
{
    float f = 1.0 / tan(fov_rads / 2.0);
    return mat4(
        f / aspect, 0.0, 0.0, 0.0,
        0.0,        f,   0.0, 0.0,
        0.0,        0.0, (zfar + znear)/(znear - zfar), -1.0,
        0.0,        0.0, (2.0 * zfar * znear)/(znear - zfar), 0.0
    );
}

mat4 x_rotation(float rads)
{
    float c = cos(rads);
    float s = sin(rads);

    return mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, c,   s,   0.0,
        0.0, -s,  c,   0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

mat4 y_rotation(float rads)
{
    float c = cos(rads);
    float s = sin(rads);

    return mat4(
        c,   0.0, -s,  0.0,
        0.0, 1.0, 0.0, 0.0,
        s,   0.0, c,   0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

//
// Let's do some shading!
//
void main()
{
    vs_path_fraction = in_path_fraction;
    tes_path_fraction = in_path_fraction; /// ONLY FOR GL_POINTS

    float pi = 3.1415926;
    float tau = 2.0 * pi;
    float PITCH_RADS = tau * 0.125;
    float ASPECT_RATIO = 1.7777;
    float ROTATION_RADS_PER_SEC = tau * -0.05;
    float FOV_RADS = tau * 0.25;
    float y_rads = TIME_SECS * ROTATION_RADS_PER_SEC;

    gl_Position = perspective(FOV_RADS, ASPECT_RATIO, 0.1, 100.0)
      * translate(vec3(0.0, 0.0, -2))
      * x_rotation(PITCH_RADS)
      * y_rotation(y_rads)
      * in_position;
}
