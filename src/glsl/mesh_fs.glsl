#version 460 core

uniform float TIME_SECS = 0;
in float tes_path_fraction;
out vec4 FragColor;

vec3 colorFromFraction(float t)
{
    t = fract(t);

    float r = abs(t * 6.0 - 3.0) - 1.0;
    float g = abs(t * 6.0 - 2.0) - 1.0;
    float b = abs(t * 6.0 - 4.0) - 1.0;

    return clamp(vec3(r, g, b), 0.0, 1.0);
}

void main()
{
    FragColor = vec4(colorFromFraction(tes_path_fraction), 1.0);
}
