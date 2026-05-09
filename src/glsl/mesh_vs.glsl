#version 460 core

layout(location = 0) in vec4 in_position;
layout(location = 1) in float in_path_fraction;
layout(location = 2) in float _unused1;
layout(location = 3) in float _unused2;
layout(location = 4) in float _unused3;

out float vs_path_fraction;

//
// Let's do some shading!
//
void main()
{
    vs_path_fraction = in_path_fraction;
    gl_Position = in_position;
}
