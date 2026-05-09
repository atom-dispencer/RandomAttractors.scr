#version 460 core

layout(isolines, equal_spacing, cw) in;

in  float tcs_path_fraction[];
out float tes_path_fraction;

float cubicBezierFloat(float F0, float F1, float F2, float F3, float t)
{
    float u = 1.0 - t;

    return
        F0 * 1.0 * u*u*u +
        F1 * 3.0 * u*u*t +
        F2 * 3.0 * u*t*t +
        F3 * 1.0 * t*t*t ;
}

vec4 cubicBezierVec4(vec4 V0, vec4 V1, vec4 V2, vec4 V3, float t)
{
    float u = 1.0 - t;

    return
        V0 * 1.0 * u*u*u +
        V1 * 3.0 * u*u*t +
        V2 * 3.0 * u*t*t +
        V3 * 1.0 * t*t*t ;
}

uniform float TIME_SECS = 0;

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

void main()
{
    // Pass-through tessellation: draw straight polyline segments between the
    // patch control points instead of evaluating a Bezier curve.

    float t = gl_TessCoord.x;
    float segment = min(t * 3.0, 2.999999);
    int idx = int(segment);
    float localT = fract(segment);

    vec4 curve_pos;
    if (idx == 0)
    {
        curve_pos = mix(gl_in[0].gl_Position, gl_in[1].gl_Position, localT);
    }
    else if (idx == 1)
    {
        curve_pos = mix(gl_in[1].gl_Position, gl_in[2].gl_Position, localT);
    }
    else
    {
        curve_pos = mix(gl_in[2].gl_Position, gl_in[3].gl_Position, localT);
    }

    float pi = 3.1415926;
    float tau = 2.0 * pi;
    float PITCH_RADS = tau * 0.125;
    float ROTATION_RADS_PER_SEC = tau * -0.05;
    float y_rads = TIME_SECS * ROTATION_RADS_PER_SEC;

    gl_Position =
        x_rotation(PITCH_RADS)
        * y_rotation(y_rads)
        * curve_pos;

    tes_path_fraction = mix(
        tcs_path_fraction[idx],
        tcs_path_fraction[idx + 1],
        localT);
}