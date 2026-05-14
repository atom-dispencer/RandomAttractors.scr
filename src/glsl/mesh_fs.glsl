#version 460 core

uniform float TIME_SECS = 0;
uniform float CYCLE_TIME_SECS = 0;
uniform float CYCLE_FADE_FRACTION = 0.1;
in float tes_path_fraction;
out vec4 FragColor;

bool DEBUG_ALWAYS_VISIBLE = false;

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
    if (DEBUG_ALWAYS_VISIBLE)
    {
        return 1.0;
    }
    else
    {
        return 1.0;
    }
}

/**
 * Hue-Function
 * Like Value-Function, but for Hue.
 */
float H(float dx)
{
    if (DEBUG_ALWAYS_VISIBLE)
    {
        return 1.0;
    }
    else
    {
        return 1.0;
    }
}

/**
 * Saturation-Function
 * Like Value-Function, but for Saturation.
 */
float S(float dx)
{
    if (DEBUG_ALWAYS_VISIBLE)
    {
        return 1.0;
    }
    else
    {
        if (dx >= -0.001) return 0;

        float k = 1.5;
        float A = 2.3;
        float w = -32*dx;

        float G = pow(w,k) * exp(-w);

        return 1.0 - A*G;
    }
}

/**
 * Alpha-Function
 * Like Value-Function, but for transparency.
 */
float A(float dx)
{
    if (DEBUG_ALWAYS_VISIBLE)
    {
        return 1.0;
    }
    else
    {
        if (dx >= -0.001) return 0;

        float k = 1.5;
        float A = 2.3;
        float w = -16*dx;

        float G = pow(w,k) * exp(-w);

        //
        // Fade In/Out Ramp
        //

        float t = mod(TIME_SECS, CYCLE_TIME_SECS);
        float fadeDur = max(CYCLE_TIME_SECS * CYCLE_FADE_FRACTION, 1e-6);

        float fadeInDelay = 0.25 * fadeDur;
        float fadeIn = smoothstep(fadeInDelay, fadeDur, t);

        float fadeOutStart = CYCLE_TIME_SECS - fadeDur;
        float fadeOutEnd   = CYCLE_TIME_SECS - 0.25 * fadeDur;
        float fadeOut = 1.0 - smoothstep(fadeOutStart, fadeOutEnd, t);

        float fade = fadeIn * fadeOut;

        //

        return fade * A*G;
    }
}

/**
 * Normalised wavefront position in Value-Function space.
 * The wavefront progresses linearly from (t=0,X=0) to (t=T,X=1)
 *
 * Specifying an `overrun` changes the mapping:
 * From [t=0,X=0] ... To [t=T+overrun, X=1+overrun/T]
 */
float X(float t, float T, float overrun)
{
    return mod(t,T+overrun) / T;
}

void main()
{
    float x0 = mod(tes_path_fraction, 1);
    float fadeout = CYCLE_TIME_SECS*CYCLE_FADE_FRACTION;
    float dx = x0 - X(TIME_SECS, CYCLE_TIME_SECS - fadeout, fadeout);

    float h = H(dx);
    float s = S(dx);
    float v = V(dx);
    float a = A(dx);

    vec3 rgb = hsv2rgb(h, s, v);
    FragColor = vec4(rgb, a);
}
