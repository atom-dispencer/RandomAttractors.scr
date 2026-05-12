#version 460 core

uniform float TIME_SECS = 0;
in float tes_path_fraction;
out vec4 FragColor;

vec3 hsv2rgb(float h, float s, float v)
{
    h = fract(h);

    float hh = h * 6.0;
    float c  = v * s;
    float x  = c * (1.0 - abs(mod(hh, 2.0) - 1.0));
    float m  = v - c;

    vec3 rgb;

    if (hh < 1.0)      rgb = vec3(c, x, 0.0);
    else if (hh < 2.0) rgb = vec3(x, c, 0.0);
    else if (hh < 3.0) rgb = vec3(0.0, c, x);
    else if (hh < 4.0) rgb = vec3(0.0, x, c);
    else if (hh < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);

    return rgb + vec3(m);
}

/**
 * Value-Function
 * A function which describes the brightness at a point `dx` distance ahead of
 * the wavefront. Positive values are ahead of the wavefront, negative values
 * lag behind it.
 */
float V(float dx)
{
    if (dx >= -0.001) return 0;

    float k = 1.5;
    float A = 2.3;
    float w = -16*dx;

    float G = pow(w,k) * exp(-w);

    return G;
}

/**
 * Hue-Function
 * Like Value-Function, but for Hue.
 */
float H(float dx)
{
    return mod(tes_path_fraction + TIME_SECS/5, 1.0);
}

/**
 * Saturation-Function
 * Like Value-Function, but for Saturation.
 */
float S(float dx)
{
    return 0.0;
}

/**
 * Alpha-Function
 * Like Value-Function, but for transparency.
 */
float A(float dx)
{
    return 1.0;
}

/**
 * Normalised wavefront position in Value-Function space.
 * The wavefront progresses linearly from (t=0,X=0) to (t=T,X=1)
 */
float X(float t, float T, float overrun)
{
    return mod(t,T+overrun) / T;
}

void main()
{
    float f = mod(tes_path_fraction, 1);
    float F = f - X(TIME_SECS, 5, 5);

    float h = H(F);
    float s = S(F);
    float v = V(F);
    float a = A(F);

    vec3 rgb = hsv2rgb(h, s, v);
    FragColor = vec4(rgb, a);
}
