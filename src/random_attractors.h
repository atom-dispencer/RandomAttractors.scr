#pragma once

#include <stdbool.h>

enum RA_Error
{
    RA_OK                    = 0,
    RA_ERROR_INIT_GLFWWINDOW = 100,
    RA_ERROR_INIT_GLAD       = 200,
    RA_ERROR_INIT_UNKNOWNARG = 300,
    RA_ERROR_INIT_ARGCOUNT   = 400
};

struct RandomAttractors
{
    enum RA_Error error;
    bool          is_preview;
    GLFWwindow   *window;
};

void      ra_parse_args(struct RandomAttractors *mdbrt, int argc, char *argv[]);
void      ra_print_help();
void      ra_create_glfw_window(struct RandomAttractors *ra);
void      _callback_ra_framebuffer_size(GLFWwindow *window, int width, int height);
void      ra_prepare_buffers(struct RandomAttractors *ra);
void      ra_compile_shader();
long long ra_get_uptime_millis();
void      ra_compute_next_step(struct RandomAttractors *ra);
void      ra_render(struct RandomAttractors *ra, long long uptime_nanos);
