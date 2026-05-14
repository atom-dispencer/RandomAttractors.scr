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
    SHADERTYPE_VS  = 1000,
    SHADERTYPE_FS  = 2000,
    SHADERTYPE_CS  = 3000,
    SHADERTYPE_TCS = 4000,
    SHADERTYPE_TES = 5000
};

struct RandomAttractors
{
    enum RA_Error error;
    struct timespec start_ts;
    bool          is_preview;
    GLFWwindow   *window;


    // Bezier control points 
    GLuint controls_program_handle;
    GLuint controls_ssbo_handle;
    GLuint bounding_ssbo_handle;
    GLuint srand_ssbo_handle;

    // Mesh
    GLuint mesh_program_handle;
    GLuint mesh_vao_handle;

    // Spotlight
    GLuint spot_program_handle;
    GLuint spot_vbo_handle;
    GLuint spot_vao_handle;
    GLuint spot_tex_handle;
};

struct ControlPoint
{
    GLfloat pos[4];
    GLfloat data[4];
};

void          ra_parse_args(struct RandomAttractors *mdbrt, int argc, char *argv[]);
void          ra_print_help();
void          ra_log(struct RandomAttractors *ra, const char *format, ...);
void          ra_create_glfw_window(struct RandomAttractors *ra);
void          _callback_ra_framebuffer_size(GLFWwindow *window, int width, int height);
void          ra_prepare_buffers(struct RandomAttractors *ra);
void          ra_prepare_textures(struct RandomAttractors *ra);
enum RA_Error ra_compile_shader(struct RandomAttractors *ra, const GLchar *source, enum RA_ShaderType type, GLuint *handle);
enum RA_Error ra_link_shader_program(
    struct RandomAttractors *ra, GLuint shader1, GLuint shader2, GLuint shader3, GLuint shader4, GLuint *program_handle);
void ra_compute_next_step(struct RandomAttractors *ra);
void ra_render(struct RandomAttractors *ra, long long uptime_nanos);
