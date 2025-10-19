#version 330 core
layout(location = 0) in vec3 aPos;
uniform float y_rads;

out vec3 vColor;

mat4 translate(vec3 v)
{
    return mat4(
        1.0,  0.0,  0.0,  0.0,  // column 0
        0.0,  1.0,  0.0,  0.0,  // column 1
        0.0,  0.0,  1.0,  0.0,  // column 2
        v.x,  v.y,  v.z,  1.0   // column 3
    );
}

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

void main()
{
  vColor = normalize(aPos * 0.5 + 0.5);

  float PITCH_RADS = 3.14159 * -0.25;

  gl_Position = //
    translate(vec3(0.0, 0.0, 0.2))  // 3rd - Translate away from the camera
    * x_rotation(PITCH_RADS)        // 2nd - Pitch the mesh like we're looking from above
    * y_rotation(y_rads)            // 1st - Yaw the mesh so it spins nicely
    // 
    * vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
