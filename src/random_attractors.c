// GLAD must be included before GLFW or everything breaks!
// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

#include "random_attractors.h"

#include "stb/stb_image.h"

// Shaders
#include "mesh_cs.h"
#include "mesh_fs.h"
#include "mesh_tcs.h"
#include "mesh_tes.h"
#include "mesh_vs.h"
#include "spot_fs.h"
#include "spot_vs.h"
// Textures
#include "spotlight.h"

// clang-format on

#define RA_BYTES_PER_CONTROL    (sizeof(GLfloat) * 4)
#define RA_CONTROLS_PER_BEZIER  (4)
#define RA_BEZIER_PER_PATH      (20)
#define RA_PATH_COUNT           (1)
//
#define RA_CONTROLS_PER_PATH    (RA_CONTROLS_PER_BEZIER * RA_BEZIER_PER_PATH)
#define RA_CONTROLS_COUNT       (RA_CONTROLS_PER_PATH * RA_PATH_COUNT)
#define RA_CONTROL_BUFFER_SIZE  (RA_CONTROLS_COUNT * RA_BYTES_PER_CONTROL)

/**
 * Spotlight sits just below the XZ plane (y=0.05) to prevent z-fighting
 * All mesh geometry will be transformed to sit above the XZ plane
 */
const static float spotlight_vertices[] = {
    // 0
    /* XYZW */ -1.0f, -0.05f, -1.0f, 1.0f, /* Tex XY */ 0.0f, 0.0f,
    // 0 -> 1
    /* XYZW */ -1.0f, -0.05f, 1.0f,  1.0f, /* Tex XY */ 0.0f, 1.0f,
    // 1 -> 2
    /* XYZW */ 1.0f, -0.05f, 1.0f,   1.0f, /* Tex XY */ 1.0f, 1.0f,
    // 0
    /* XYZW */ -1.0f, -0.05f, -1.0f, 1.0f, /* Tex XY */ 0.0f, 0.0f,
    // 0 -> 2
    /* XYZW */ 1.0f, -0.05f, 1.0f,   1.0f, /* Tex XY */ 1.0f, 1.0f,
    // 2 -> 3
    /* XYZW */ 1.0f, -0.05f, -1.0f,  1.0f, /* Tex XY */ 1.0f, 0.0f
};

int main(int argc, char *argv[])
{
    struct RandomAttractors ra = { 0 };
    timespec_get(&ra.start_ts, TIME_UTC);

    //
    // Parse program (screensaver) arguments
    //

    ra_parse_args(&ra, argc, argv);
    if (ra.error != RA_OK)
    {
        ra_log(&ra, "Couldn't parse arguments: %d\n", ra.error);
        ra_print_help();
        return ra.error;
    }

    //
    // OpenGL and GLFW configuration
    //

    ra_create_glfw_window(&ra);
    if (ra.error != RA_OK)
    {
        ra_log(&ra, "Couldn't create GLFW window: %d\n", ra.error);
        return ra.error;
    }

    ra_prepare_buffers(&ra);
    if (ra.error != RA_OK)
    {
        ra_log(&ra, "Couldn't set up OpenGL buffers: %d\n", ra.error);
        return ra.error;
    }

    ra_prepare_textures(&ra);
    if (ra.error != RA_OK)
    {
        ra_log(&ra, "Couldn't set up OpenGL texture: %d\n", ra.error);
        return ra.error;
    }

    //
    // Simulation
    //

    struct timespec ts;

    timespec_get(&ts, TIME_UTC);
    srand(ts.tv_nsec);
    if (ra.is_preview)
    {
        printf("Random seed is %ld\n", ts.tv_nsec);
    }

    long long start_epoch_nanos = 0;
    timespec_get(&ts, TIME_UTC);
    start_epoch_nanos = (long long)(ts.tv_sec * 1e9 + ts.tv_nsec);

    long long uptime_nanos          = 0;
    long long current_epoch_nanos   = start_epoch_nanos;

    while (!glfwWindowShouldClose(ra.window))
    {
        timespec_get(&ts, TIME_UTC);
        current_epoch_nanos = (long long)(ts.tv_sec * 1e9 + ts.tv_nsec);
        uptime_nanos        = current_epoch_nanos - start_epoch_nanos;

        if (GLFW_PRESS == glfwGetKey(ra.window, GLFW_KEY_SPACE)
            || GLFW_PRESS == glfwGetKey(ra.window, GLFW_KEY_ENTER)
            || GLFW_PRESS == glfwGetMouseButton(ra.window, GLFW_MOUSE_BUTTON_LEFT))
        {
            ra_log(&ra, "Input detected! Triggering close...\n");
            glfwSetWindowShouldClose(ra.window, GLFW_TRUE);
        }

        ra_render(&ra, uptime_nanos);

        glfwSwapBuffers(ra.window);
        glfwPollEvents();
    }

    //
    // Shutdown
    //

    ra_log(&ra, "Terminating GLFW...\n");
    glfwTerminate();

    ra_log(&ra, "Goodbye.\n");
    return RA_OK;
}

void ra_parse_args(struct RandomAttractors *ra, int argc, char *argv[])
{
    if (argc < 2)
    {
        printf("Not enough arguments!\n");
        ra->error = RA_ERROR_INIT_ARGCOUNT;
        return;
    }

    if (strcmp(argv[1], "/s") == 0)
    {
        ra->is_preview = 0;
    }
    else if (strcmp(argv[1], "/p") == 0)
    {
        ra->is_preview = 1;
        printf("Preview mode detected!\n");
    }
    else
    {
        printf("Unrecognised argument: %s\n", argv[1]);
        ra->error = RA_ERROR_INIT_UNKNOWNARG;
        return;
    }

    ra->error = RA_OK;
}

void ra_print_help()
{
    printf("\n  ~~ Help ~~ \n");
    printf("  RandomAttractors.scr Screensaver, by Adam Spencer \n");
    printf("  https://github.com/atom-dispencer/RandomAttractors.scr for source code and full "
           "documentation.\n");
    printf("  Options:\n");
    printf("      /s - Run in screensaver mode (fullscreen, logging disabled)\n");
    printf("      /p - Run in preview mode (small window, logging enabled)\n");
    printf("  Correct usage:\n");
    printf("      RandomAttractors.scr /s\n");
    printf("      RandomAttractors.scr /p\n\n");
}

void ra_log(struct RandomAttractors *ra, const char *format, ...)
{
    if (!ra->is_preview) return;

    struct timespec now;
    timespec_get(&now, TIME_UTC);
    long long diff_nanos = (now.tv_sec - ra->start_ts.tv_sec) * 1000000000LL + (now.tv_nsec - ra->start_ts.tv_nsec);
    double seconds = diff_nanos / 1e9;
    printf("[%7.3f] ", seconds);
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
}

void ra_create_glfw_window(struct RandomAttractors *ra)
{
    ra_log(ra, "Init GLFW...\n");
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    //
    // Create and configure the GLFW window
    //

    ra_log(ra, "Creating GLFW window...\n");

    GLFWwindow *window = NULL;
    int         width  = 0;
    int         height = 0;

    glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

    // In preview mode, make it 16:9 small windowed
    if (ra->is_preview)
    {
        ra_log(ra, "Creating preview window\n");
        width  = 800;
        height = 450;
        window = glfwCreateWindow(width, height, "RandomAttractors.scr", NULL, NULL);
    }
    // In screensaver mode, make it full screen
    else
    {
        GLFWmonitor       *monitor = glfwGetPrimaryMonitor();
        const GLFWvidmode *mode    = glfwGetVideoMode(monitor);

        width  = mode->width;
        height = mode->height;

        window = glfwCreateWindow(width, height, "RandomAttractors.scr", monitor, NULL);
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    }

    if (window == NULL)
    {
        ra_log(ra, "Failed to create GLFW window.\n");
        glfwTerminate();
        ra->error = RA_ERROR_INIT_GLFWWINDOW;
        return;
    }
    glfwMakeContextCurrent(window);

    //
    // Load GLAD bindings for 'gl' functions
    //

    ra_log(ra, "Loading GLAD...\n");
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        ra_log(ra, "Failed to initialize GLAD\n");
        ra->error = RA_ERROR_INIT_GLAD;
        return;
    }

    //
    // Congrats! You can now call OpenGL 'gl' functions
    //

    ra_log(ra, "Configuring OpenGL viewport and callbacks...\n");
    glViewport(0, 0, width, height);
    glfwSetFramebufferSizeCallback(window, _callback_ra_framebuffer_size);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Control VSync (0=off, 1=framerate, 2=half-framerate)
    glfwSwapInterval(1); // 0 for vsync off

    ra->window = window;
    ra->error  = RA_OK;
    ra_log(ra, "GLFW window created.\n");
}

void _callback_ra_framebuffer_size(GLFWwindow *window, int width, int height)
{
    glViewport(0, 0, width, height);
}

void ra_prepare_buffers(struct RandomAttractors *ra)
{
    ra_log(ra, "Preparing buffers and compiling shaders...\n");

    //
    // Generate OpenGL objects
    //

    glGenBuffers(1, &ra->controls_ssbo_handle);
    glGenBuffers(1, &ra->mesh_vao_handle);
    glGenBuffers(1, &ra->spot_vbo_handle);
    glGenVertexArrays(1, &ra->spot_vao_handle);

    //
    // Compile and link all shaders
    //

    // Controls: CS only
    GLuint mesh_cs_handle  = 0;
    ra_compile_shader(ra, mesh_cs_glsl,  SHADERTYPE_CS,  &mesh_cs_handle);
    ra_link_shader_program(ra, -1, -1, -1, mesh_cs_handle, &ra->controls_program_handle);
    glDeleteShader(mesh_cs_handle);

    // Mesh: VS -> TCS -> TES -> FS
    GLuint mesh_fs_handle  = 0;
    GLuint mesh_tcs_handle = 0;
    GLuint mesh_tes_handle = 0;
    GLuint mesh_vs_handle  = 0;
    ra_compile_shader(ra, mesh_fs_glsl,  SHADERTYPE_FS,  &mesh_fs_handle);
    ra_compile_shader(ra, mesh_tcs_glsl, SHADERTYPE_TCS, &mesh_tcs_handle);
    ra_compile_shader(ra, mesh_tes_glsl, SHADERTYPE_TES, &mesh_tes_handle);
    ra_compile_shader(ra, mesh_vs_glsl,  SHADERTYPE_VS,  &mesh_vs_handle);
    ra_link_shader_program(ra, mesh_vs_handle, mesh_tcs_handle, mesh_tes_handle, mesh_fs_handle, &ra->mesh_program_handle);
    glDeleteShader(mesh_fs_handle);
    glDeleteShader(mesh_tcs_handle);
    glDeleteShader(mesh_tes_handle);
    glDeleteShader(mesh_vs_handle);

    // Spotlight: VS -> FS
    GLuint spot_fs_handle  = 0;
    GLuint spot_vs_handle  = 0;
    ra_compile_shader(ra, spot_fs_glsl,  SHADERTYPE_FS,  &spot_fs_handle);
    ra_compile_shader(ra, spot_vs_glsl,  SHADERTYPE_VS,  &spot_vs_handle);
    ra_link_shader_program(ra, -1, -1, spot_vs_handle, spot_fs_handle, &ra->spot_program_handle);
    glDeleteShader(spot_fs_handle);
    glDeleteShader(spot_vs_handle);

    //
    // Load spotlight vertex data
    //
    // Attributes:
    // 0 : Vertex coordinates (X,Y,Z,W)
    // 1 : Texture coordinates (X,Y)
    //

    glBindVertexArray(ra->spot_vao_handle);
    glBindBuffer(GL_ARRAY_BUFFER, ra->spot_vbo_handle);
    glBufferData(GL_ARRAY_BUFFER, sizeof(spotlight_vertices), spotlight_vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void *)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void *)(4 * sizeof(float)));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);

    //
    // Allocate attractor point vertex data
    //

    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ra->controls_ssbo_handle);
    glBufferData(GL_SHADER_STORAGE_BUFFER, RA_CONTROL_BUFFER_SIZE, NULL, GL_DYNAMIC_DRAW);

    //
    // Create a blank VAO for the mesh data because OpenGL requires a VAO to be
    // bound for drawing operations, but the vertex data is actually generated
    // in the compute shader and passed via an SSBO on the GPU.
    //
    glBindVertexArray(ra->mesh_vao_handle);
    glBindVertexArray(0);

    // All done :)
    ra_log(ra, "Buffers prepared.\n");
}

void ra_prepare_textures(struct RandomAttractors *ra)
{
    ra_log(ra, "Preparing spotlight texture...\n");
    int width = -1, height = -1, type = -1;

    unsigned char *spotlight_data = stbi_load_from_memory(spotlight_png_data, spotlight_png_data_size, &width, &height, &type, 0);
    if (spotlight_data)
    {
        glGenTextures(1, &ra->spot_tex_handle);
        glBindTexture(GL_TEXTURE_2D, ra->spot_tex_handle);
        // wrap/filter
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);	
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        // data
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, spotlight_data);
        glGenerateMipmap(GL_TEXTURE_2D);
    }
    else
    {
        ra_log(ra, "Failed to generate spotlight texture!\n");
    }
    stbi_image_free(spotlight_data);

    ra_log(ra, "Spotlight texture prepared.\n");
}

enum RA_Error ra_compile_shader(struct RandomAttractors *ra, const GLchar *source, enum RA_ShaderType type, GLuint *handle)
{
    int gl_shader_type = 0;

    switch (type)
    {
        case SHADERTYPE_VS:
            gl_shader_type = GL_VERTEX_SHADER;
            break;
        case SHADERTYPE_FS:
            gl_shader_type = GL_FRAGMENT_SHADER;
            break;
        case SHADERTYPE_CS:
            gl_shader_type = GL_COMPUTE_SHADER;
            break;
        case SHADERTYPE_TCS:
            gl_shader_type = GL_TESS_CONTROL_SHADER;
            break;
        case SHADERTYPE_TES:
            gl_shader_type = GL_TESS_EVALUATION_SHADER;
            break;
        default:
            ra_log(ra, "Failed to compile illegal ShaderType: %d\n", type);
            return RA_ERROR_INIT_SHADERTYPE;
    }

    if (ra->is_preview)
    {
        printf("\n ================================================== \n");
        printf("   Compiling shader");
        printf("\n ================================================== \n");
        printf("\n\n%s\n\n", source);
    }

    *handle = glCreateShader(gl_shader_type);
    glShaderSource(*handle, 1, &source, NULL);
    glCompileShader(*handle);

    int    success      = 0;
    GLchar infoLog[512] = { 0 };
    glGetShaderiv(*handle, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(*handle, 512, NULL, infoLog);
        ra_log(ra, "Shader compilation failed. Type=%d. Error: %s\n", gl_shader_type, infoLog);
        return RA_ERROR_INIT_SHADERCOMP;
    }

    ra_log(ra, "Successfully compiled shader (%d)! Type=%d\n", *handle, gl_shader_type);
    return RA_OK;
}

enum RA_Error ra_link_shader_program(struct RandomAttractors *ra, GLuint shader1, GLuint shader2, GLuint shader3, GLuint shader4, GLuint *program_handle)
{
    *program_handle = glCreateProgram();

    if (shader1 != -1)
    {
        glAttachShader(*program_handle, shader1);
    }
    if (shader2 != -1)
    {
        glAttachShader(*program_handle, shader2);
    }
    if (shader3 != -1)
    {
        glAttachShader(*program_handle, shader3);
    }
    if (shader4 != -1)
    {
        glAttachShader(*program_handle, shader4);
    }
    glLinkProgram(*program_handle);

    int    success      = 0;
    GLchar infoLog[512] = { 0 };
    glGetProgramiv(*program_handle, GL_LINK_STATUS, &success);
    if (!success)
    {
        glGetProgramInfoLog(*program_handle, 512, NULL, infoLog);
        ra_log(ra, "Shader linking failed. Error: %s\n", infoLog);
        return RA_ERROR_INIT_SHADERLINK;
    }

    ra_log(ra, "Successfully linked shader program (%d)\n", *program_handle);
    return RA_OK;
}

void ra_compute_new_mesh(struct RandomAttractors *ra, double uptime_secs)
{
    glUseProgram(ra->controls_program_handle);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ra->controls_ssbo_handle);

    // Uniform: PATH_COUNT
    GLuint path_count_location = glGetUniformLocation(ra->controls_program_handle, "PATH_COUNT");
    if (path_count_location != -1)
    {
        glUniform1i(path_count_location, (GLint) RA_PATH_COUNT);
    }

    // Uniform: BEZIER_PER_PATH
    GLuint bezier_per_path_location = glGetUniformLocation(ra->controls_program_handle, "BEZIER_PER_PATH");
    if (bezier_per_path_location != -1)
    {
        glUniform1i(bezier_per_path_location, (GLint) RA_BEZIER_PER_PATH);
    }

    glDispatchCompute(1, 1, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
}

void ra_render(struct RandomAttractors *ra, long long uptime_nanos)
{
    double uptime_secs = uptime_nanos / 1.0e9;

    // TODO Call shaders to re-render the screen
    // Shaders will need to:
    // - Translate and rotate the camera to achieve an isometric viewpoint
    // - Rotate the geometry to the current rotation angle
    // - Find hotspots of color (bloom?) and color the regions by intensity

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    //
    // Compute new geometry
    //
    static double next_update_secs = -1000;
    if (uptime_secs > next_update_secs)
    {
        next_update_secs = uptime_secs + 5;
        ra_compute_new_mesh(ra, uptime_secs);
    }

    //
    // Spotlight
    //

    glUseProgram(ra->spot_program_handle);
    glBindTexture(GL_TEXTURE_2D, ra->spot_tex_handle);
    glBindVertexArray(ra->spot_vao_handle);
    glDrawArrays(GL_TRIANGLES, 0, sizeof(spotlight_vertices) / (sizeof(float) * 6));

    //
    // Mesh
    //

    glUseProgram(ra->mesh_program_handle);

    GLuint time_secs_location = glGetUniformLocation(ra->mesh_program_handle, "TIME_SECS");
    glUniform1f(time_secs_location, uptime_secs);
    // ra_log(ra, "time_secs=%f; uniform=%d\n", uptime_secs, time_secs_location);

    glBindVertexArray(ra->mesh_vao_handle);
    glPatchParameteri(GL_PATCH_VERTICES, 4);
    glLineWidth(5.0f);
    glDrawArrays(GL_PATCHES, 0, RA_CONTROLS_COUNT);
}
