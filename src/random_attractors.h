#pragma once

#include <stdbool.h>

enum RA_Error
{
    RA_OK                    = 0,
    RA_ERROR_INIT_GLFWWINDOW = 100,
    RA_ERROR_INIT_GLAD       = 200,
    RA_ERROR_INIT_UNKNOWNARG = 300,
    RA_ERROR_INIT_ARGCOUNT   = 400,
    RA_ERROR_INIT_SHADERTYPE = 500,
    RA_ERROR_INIT_SHADERCOMP = 600,
    RA_ERROR_INIT_SHADERLINK = 700,
};

enum RA_ShaderType
{
    SHADERTYPE_VERTEX   = 1000,
    SHADERTYPE_FRAGMENT = 2000,
    SHADERTYPE_COMPUTE  = 3000
};

struct RandomAttractors
{
    enum RA_Error error;
    bool          is_preview;
    GLFWwindow   *window;

    GLuint lines_vbo_handle;
    GLuint lines_vao_handle;
    GLuint spot_vbo_handle;
    GLuint spot_vao_handle;
    // Normal shaders
    GLuint mesh_program_handle;
    GLuint spot_program_handle;
    // Compute shaders
    GLuint lines_program_handle;
};

struct LineDataPoint
{
    GLfloat pos[4];
    GLfloat data[4];
};

void          ra_parse_args(struct RandomAttractors *mdbrt, int argc, char *argv[]);
void          ra_print_help();
void          ra_create_glfw_window(struct RandomAttractors *ra);
void          _callback_ra_framebuffer_size(GLFWwindow *window, int width, int height);
void          ra_prepare_buffers(struct RandomAttractors *ra);
enum RA_Error ra_compile_shader(const GLchar *source, enum RA_ShaderType type, GLuint *handle);
enum RA_Error ra_link_shader_program(
    GLuint vertex_handle, GLuint frag_handle, GLuint *program_handle);
void ra_compute_next_step(struct RandomAttractors *ra);
void ra_render(struct RandomAttractors *ra, long long uptime_nanos);
