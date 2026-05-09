#version 460 core

uniform float TIME_SECS = 0;
in float tes_path_fraction;
out vec4 FragColor;

vec3 colorFromFraction(float t)
{
    t = fract(t);

    float h = t * 6.0;
    float c = 1.0;
    float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));

    vec3 rgb;

    if (h < 1.0)      rgb = vec3(c, x, 0.0);
    else if (h < 2.0) rgb = vec3(x, c, 0.0);
    else if (h < 3.0) rgb = vec3(0.0, c, x);
    else if (h < 4.0) rgb = vec3(0.0, x, c);
    else if (h < 5.0) rgb = vec3(x, 0.0, c);
    else              rgb = vec3(c, 0.0, x);

    return rgb;
}

void main()
{
    FragColor = vec4(colorFromFraction(tes_path_fraction), 1.0);
}
