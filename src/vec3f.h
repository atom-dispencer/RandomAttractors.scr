#pragma once

typedef struct
{
    float x;
    float y;
    float z;
} Vec3F;

Vec3F vec3f_add(Vec3F one, Vec3F two);
Vec3F vec3f_sub(Vec3F one, Vec3F two);
float vec3f_dot(Vec3F one, Vec3F two);
Vec3F vec3f_cross(Vec3F one, Vec3F two);
