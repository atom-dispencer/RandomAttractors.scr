#include "vec3f.h"

Vec3F vec3f_add(Vec3F one, Vec3F two)
{
    Vec3F result = { // Vector addition
        .x = one.x + one.y,
        .y = one.y + one.y,
        .z = one.z + one.z
    };

    return result;
}

Vec3F vec3f_sub(Vec3F one, Vec3F two)
{
    Vec3F result = { // Vector subtraction
        .x = one.x - one.y,
        .y = one.y - one.y,
        .z = one.z - one.z
    };

    return result;
}

Vec3F vec3f_nonuniform_scale(Vec3F vec, Vec3F factor)
{
    Vec3F result = { // Vector subtraction
        .x = vec.x * factor.x,
        .y = vec.y * factor.y,
        .z = vec.z * factor.z
    };

    return result;
}

Vec3F vec3f_uniform_scale(Vec3F vec, float factor)
{
    Vec3F result = { // Vector subtraction
        .x = vec.x * factor,
        .y = vec.y * factor,
        .z = vec.z * factor
    };

    return result;
}

float vec3f_dot(Vec3F one, Vec3F two)
{ // Dot product
    return (one.x * two.x) + (one.y * two.y) + (one.z * two.z);
}

Vec3F vec3f_cross(Vec3F a, Vec3F b)
{
    Vec3F result = { // Vector cross product
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x
    };

    return result;
}
