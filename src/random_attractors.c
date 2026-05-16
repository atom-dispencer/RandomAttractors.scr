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

#define RA_BYTES_PER_CONTROL    (sizeof(struct ControlPoint))
#define RA_CONTROLS_PER_BEZIER  (4)
#define RA_BEZIER_PER_PATH      (20)
#define RA_PATH_COUNT           (20)
//
#define RA_CONTROLS_PER_PATH    (RA_CONTROLS_PER_BEZIER * RA_BEZIER_PER_PATH)
#define RA_CONTROLS_COUNT       (RA_CONTROLS_PER_PATH * RA_PATH_COUNT)
#define RA_CONTROL_BUFFER_SIZE  (RA_CONTROLS_COUNT * RA_BYTES_PER_CONTROL)
//
#define RA_CYCLE_TIME_SECS      (30)
#define RA_CYCLE_FADE_FRACTION  (0.05)

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

    double start_time_secs = glfwGetTime();
    double skip_secs = 0.0;

    while (!glfwWindowShouldClose(ra.window))
    {
        double uptime_secs = (glfwGetTime() - start_time_secs) + skip_secs;

        //
        // Left Mouse & Enter keys close the window
        //
        if (GLFW_PRESS == glfwGetKey(ra.window, GLFW_KEY_ENTER)
            || GLFW_PRESS == glfwGetMouseButton(ra.window, GLFW_MOUSE_BUTTON_LEFT))
        {
            ra_log(&ra, "Input detected! Triggering close...\n");
            glfwSetWindowShouldClose(ra.window, GLFW_TRUE);
        }
        //
        // Spacebar skips to the next cycle
        //
        static bool space_debounce = false;
        if (GLFW_PRESS == glfwGetKey(ra.window, GLFW_KEY_SPACE))
        {
            if (!space_debounce)
            {
                ra_log(&ra, "Skipping cycle...\n");
                space_debounce = true;

                double cycle_secs = fmod(uptime_secs, (double)RA_CYCLE_TIME_SECS);
                double residual = (double)RA_CYCLE_TIME_SECS - cycle_secs;
                skip_secs += residual;
            }
        }
        else
        {
            space_debounce = false;
        }

        ra_render(&ra, uptime_secs);

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

    double seconds = glfwGetTime();
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
    glfwWindowHint(GLFW_FOCUSED, GLFW_TRUE);
    glfwWindowHint(GLFW_AUTO_ICONIFY, GLFW_FALSE);

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
    glfwFocusWindow(window);

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

    // Mesh
    glGenBuffers(1, &ra->controls_ssbo_handle);
    glGenBuffers(1, &ra->bounding_ssbo_handle);
    glGenBuffers(1, &ra->srand_ssbo_handle);
    glGenVertexArrays(1, &ra->mesh_vao_handle);
    // Spot
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
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    //
    // Allocate attractor point vertex data
    //
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ra->controls_ssbo_handle);
    glBufferData(GL_SHADER_STORAGE_BUFFER, RA_CONTROL_BUFFER_SIZE, NULL, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    //
    // Allocate bounding box storage buffer
    // Size 2*vec4
    //
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ra->bounding_ssbo_handle);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 8 * sizeof(GLfloat), NULL, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
    
    //
    // Allocate and initialise srand storage buffer
    // Size vec2
    //
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ra->srand_ssbo_handle);
    time_t t = time(NULL);
    srand(t);
    ra_log(ra, "Random seed is %ld\n", t);
    GLuint initial_srand = (GLuint)rand();
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(GLuint), &initial_srand, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    //
    // The mesh VAO gives the VS access to the CS SSBO (control points) like a
    // normal vertex buffer so RenderDoc is actually useful again.
    //
    glBindVertexArray(ra->mesh_vao_handle);
    glBindBuffer(GL_ARRAY_BUFFER, ra->controls_ssbo_handle);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, sizeof(struct ControlPoint), (void *)0);                    // Z,Y,Z,W
    glVertexAttribPointer(1, 1, GL_FLOAT, GL_FALSE, sizeof(struct ControlPoint), (void *)(sizeof(float) * 4));  // path_fraction
    glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, sizeof(struct ControlPoint), (void *)(sizeof(float) * 5));  // unused1
    glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, sizeof(struct ControlPoint), (void *)(sizeof(float) * 6));  // unused2
    glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, sizeof(struct ControlPoint), (void *)(sizeof(float) * 7));  // unused3
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);
    glEnableVertexAttribArray(3);
    glEnableVertexAttribArray(4);
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

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
    glUseProgram(ra->mesh_program_handle);
    // Uniform: FRAGMENT_HUE_RANDOM
    // THIS IS USED BY THE MESH, NOT BY THE COMPUTE PROGRAM, BUT IT MUST BE SYNCED WITH THE COMPUTE SHADER
    GLuint fragment_hue_random_location = glGetUniformLocation(ra->mesh_program_handle, "FRAGMENT_HUE_RANDOM");
    if (fragment_hue_random_location != -1)
    {
        float fhr = (float) rand() / (float) RAND_MAX;
        ra_log(ra, "Fragment randomness is %f\n", fhr);
        glUniform1f(fragment_hue_random_location, (GLfloat) fhr);
    }

    //
    // Compute Shader
    //

    glUseProgram(ra->controls_program_handle);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ra->controls_ssbo_handle);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, ra->bounding_ssbo_handle);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, ra->srand_ssbo_handle);

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
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT);
}

void ra_render(struct RandomAttractors *ra, double uptime_secs)
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    //
    // Compute new geometry
    //
    static double next_update_secs = 0.0;
    if (uptime_secs >= next_update_secs)
    {
        //
        // All other rendering logic is aligned strictly to uptime_secs, so
        // this should be too! Using a delta here would be a BAD idea because
        // you would be guaranteed to drift 1 frame every cycle, which gets
        // problematic after a few hours of screensaving!!
        //
        // We therefore set the uptime to be at the start of the next cycle
        //
        // It's also a little tricky because we need to make sure we don't
        // dispatch the compute shader twice (not breaking, just inefficient),
        // so using ceil(...)*CYCLE_SECS is out of the question.
        //
        next_update_secs = (floor(uptime_secs / RA_CYCLE_TIME_SECS) + 1.0) * RA_CYCLE_TIME_SECS;
        ra_log(ra, "Computing new mesh...\n");
        ra_compute_new_mesh(ra, uptime_secs);
        ra_log(ra, "Mesh computed!\n");
    }

    //
    // Spotlight
    //

    glUseProgram(ra->spot_program_handle);
    glBindTexture(GL_TEXTURE_2D, ra->spot_tex_handle);
    glBindVertexArray(ra->spot_vao_handle);
    glDrawArrays(GL_TRIANGLES, 0, sizeof(spotlight_vertices) / (sizeof(float) * 6));
    glBindVertexArray(0);

    //
    // Mesh
    //

    glDepthMask(GL_FALSE);
    glUseProgram(ra->mesh_program_handle);

    // Uniform: TIME_SECS
    GLuint time_secs_location = glGetUniformLocation(ra->mesh_program_handle, "TIME_SECS");
    if (time_secs_location != -1)
    {
        glUniform1f(time_secs_location, uptime_secs);
    }

    // Uniform: CYCLE_TIME_SECS
    GLuint cycle_time_secs_location = glGetUniformLocation(ra->mesh_program_handle, "CYCLE_TIME_SECS");
    if (cycle_time_secs_location != -1)
    {
        glUniform1f(cycle_time_secs_location, (GLfloat) RA_CYCLE_TIME_SECS);
    }

    // Uniform: CYCLE_FADE_FRACTION
    GLuint cycle_fade_fraction_location = glGetUniformLocation(ra->mesh_program_handle, "CYCLE_FADE_FRACTION");
    if (cycle_fade_fraction_location != -1)
    {
        glUniform1f(cycle_fade_fraction_location, (GLfloat) RA_CYCLE_FADE_FRACTION);
    }

    glBindVertexArray(ra->mesh_vao_handle);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ra->controls_ssbo_handle);
    glPatchParameteri(GL_PATCH_VERTICES, 4);
    glLineWidth(2.0f);
    glDrawArrays(GL_PATCHES, 0, RA_CONTROLS_COUNT);
    glBindVertexArray(0);
    glDepthMask(GL_TRUE);
}
