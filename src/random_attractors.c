// GLAD must be included before GLFW or everything breaks!
// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "random_attractors.h"

#include "mesh_fragment_shader.h"
#include "mesh_vertex_shader.h"
#include "spot_fragment_shader.h"
#include "spot_vertex_shader.h"

// clang-format on

#define ROTATION_RADS_PER_SEC (0.1 * M_PI)

float vertices[] = {
    // Edge 0: Apex → Base vertex 0
    0.0f, 0.5f, 0.0f, -0.5f, -0.25f, 0.2887f,

    // Edge 1: Apex → Base vertex 1
    0.0f, 0.5f, 0.0f, 0.5f, -0.25f, 0.2887f,

    // Edge 2: Apex → Base vertex 2
    0.0f, 0.5f, 0.0f, 0.0f, -0.25f, -0.5774f,

    // Edge 3: Base edge 0–1
    -0.5f, -0.25f, 0.2887f, 0.5f, -0.25f, 0.2887f,

    // Edge 4: Base edge 1–2
    0.5f, -0.25f, 0.2887f, 0.0f, -0.25f, -0.5774f,

    // Edge 5: Base edge 2–0
    0.0f, -0.25f, -0.5774f, -0.5f, -0.25f, 0.2887f
};

float spotlight_vertices[] = {
    // 0
    -1.0f,
    0.0f,
    -1.0f,
    // 0 -> 1
    -1.0f,
    0.0f,
    1.0f,
    // 1 -> 2
    1.0f,
    0.0f,
    1.0f,
    // 0
    -1.0f,
    0.0f,
    -1.0f,
    // 0 -> 2
    1.0f,
    0.0f,
    1.0f,
    // 2 -> 3
    1.0f,
    0.0f,
    -1.0f,
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
        printf("Couldn't parse arguments: %d\n", ra.error);
        ra_print_help();
        return ra.error;
    }

    //
    // OpenGL and GLFW configuration
    //

    ra_create_glfw_window(&ra);
    if (ra.error != RA_OK)
    {
        printf("Couldn't create GLFW window: %d\n", ra.error);
        return ra.error;
    }

    ra_prepare_buffers(&ra);
    if (ra.error != RA_OK)
    {
        printf("Couldn't set up OpenGL buffers: %d\n", ra.error);
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
    long long last_step_epoch_nanos = start_epoch_nanos;
    long long current_epoch_nanos   = start_epoch_nanos;

    while (!glfwWindowShouldClose(ra.window))
    {
        timespec_get(&ts, TIME_UTC);
        current_epoch_nanos = (long long)(ts.tv_sec * 1e9 + ts.tv_nsec);
        uptime_nanos        = current_epoch_nanos - start_epoch_nanos;
        if (current_epoch_nanos - last_step_epoch_nanos > 1e9)
        {
            ra_compute_next_step(&ra);
            last_step_epoch_nanos = current_epoch_nanos;
        }

        if (GLFW_PRESS == glfwGetKey(ra.window, GLFW_KEY_SPACE)
            || GLFW_PRESS == glfwGetKey(ra.window, GLFW_KEY_ENTER)
            || GLFW_PRESS == glfwGetMouseButton(ra.window, GLFW_MOUSE_BUTTON_LEFT))
        {
            if (ra.is_preview)
            {
                printf("Input detected! Triggering close...\n");
            }
            glfwSetWindowShouldClose(ra.window, GLFW_TRUE);
        }

        ra_render(&ra, uptime_nanos);

        glfwSwapBuffers(ra.window);
        glfwPollEvents();
    }

    //
    // Shutdown
    //

    glfwTerminate();
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

void ra_create_glfw_window(struct RandomAttractors *ra)
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    //
    // Create and configure the GLFW window
    //

    GLFWwindow *window = NULL;
    int         width  = 0;
    int         height = 0;

    glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

    if (ra->is_preview)
    {
        printf("Creating preview window\n");
        width  = 800;
        height = 600;
        window = glfwCreateWindow(width, height, "RandomAttractors.scr", NULL, NULL);
    }
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
        printf("Failed to create GLFW window.\n");
        glfwTerminate();
        ra->error = RA_ERROR_INIT_GLFWWINDOW;
        return;
    }
    glfwMakeContextCurrent(window);

    //
    // Load GLAD bindings for 'gl' functions
    //

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        printf("Failed to initialize GLAD\n");
        ra->error = RA_ERROR_INIT_GLAD;
        return;
    }

    //
    // Congrats! You can now call OpenGL 'gl' functions
    //

    glViewport(0, 0, width, height);
    glfwSetFramebufferSizeCallback(window, _callback_ra_framebuffer_size);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Control VSync (0=off, 1=framerate, 2=half-framerate)
    glfwSwapInterval(1); // 0 for vsync off

    ra->window = window;
    ra->error  = RA_OK;
}

void _callback_ra_framebuffer_size(GLFWwindow *window, int width, int height)
{
    glViewport(0, 0, width, height);
}

void ra_prepare_buffers(struct RandomAttractors *ra)
{
    glGenBuffers(1, &ra->vbo_handle);
    glGenVertexArrays(1, &ra->vao_handle);

    GLuint mesh_vertex_handle   = 0;
    GLuint mesh_fragment_handle = 0;
    GLuint spot_fragment_handle = 0;
    ra_compile_shader(mesh_vertex_glsl, SHADERTYPE_VERTEX, &mesh_vertex_handle);
    ra_compile_shader(mesh_fragment_glsl, SHADERTYPE_FRAGMENT, &mesh_fragment_handle);
    ra_compile_shader(spot_fragment_glsl, SHADERTYPE_FRAGMENT, &spot_fragment_handle);
    ra_link_shader_program(mesh_vertex_handle, mesh_fragment_handle, &ra->mesh_program_handle);
    ra_link_shader_program(mesh_vertex_handle, spot_fragment_handle, &ra->spot_program_handle);

    glDeleteShader(mesh_vertex_handle);
    glDeleteShader(mesh_fragment_handle);
    glDeleteShader(spot_fragment_handle);

    // Load vertex data
    glBindBuffer(GL_ARRAY_BUFFER, ra->vbo_handle);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindVertexArray(ra->vao_handle);
    glBindBuffer(GL_ARRAY_BUFFER, ra->vbo_handle);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(0);
}

enum RA_Error ra_compile_shader(const GLchar *source, enum RA_ShaderType type, GLuint *handle)
{
    int gl_shader_type = 0;

    switch (type)
    {
        case SHADERTYPE_VERTEX:
            gl_shader_type = GL_VERTEX_SHADER;
            break;
        case SHADERTYPE_FRAGMENT:
            gl_shader_type = GL_FRAGMENT_SHADER;
            break;
        case SHADERTYPE_COMPUTE:
            gl_shader_type = GL_COMPUTE_SHADER;
            break;
        default:
            printf("Failed to compile illegal ShaderType: %d\n", type);
            return RA_ERROR_INIT_SHADERTYPE;
    }

    printf("Compiling shader: \n\n%s\n\n", source);

    *handle = glCreateShader(gl_shader_type);
    glShaderSource(*handle, 1, &source, NULL);
    glCompileShader(*handle);

    int    success      = 0;
    GLchar infoLog[512] = { 0 };
    glGetShaderiv(*handle, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(*handle, 512, NULL, infoLog);
        printf("Shader compilation failed. Type=%d. Error: %s\n", gl_shader_type, infoLog);
        return RA_ERROR_INIT_SHADERCOMP;
    }

    printf("Successfully compiled shader (%d)! Type=%d\n", *handle, gl_shader_type);
    return RA_OK;
}

enum RA_Error ra_link_shader_program(
    GLuint vertex_handle, GLuint frag_handle, GLuint *program_handle)
{
    *program_handle = glCreateProgram();
    glAttachShader(*program_handle, vertex_handle);
    glAttachShader(*program_handle, frag_handle);
    glLinkProgram(*program_handle);

    int    success      = 0;
    GLchar infoLog[512] = { 0 };
    glGetProgramiv(*program_handle, GL_LINK_STATUS, &success);
    if (!success)
    {
        glGetProgramInfoLog(*program_handle, 512, NULL, infoLog);
        printf("Shader linking failed. Error: %s\n", infoLog);
        return RA_ERROR_INIT_SHADERLINK;
    }

    printf("Successfully linked shader program (%d)\n", *program_handle);
    return RA_OK;
}

void ra_compute_next_step(struct RandomAttractors *ra)
{
    // TODO Run compute shader
}

void ra_render(struct RandomAttractors *ra, long long uptime_nanos)
{
    double uptime_secs    = uptime_nanos / 1.0e9d;
    float  rotation_angle = uptime_secs * ROTATION_RADS_PER_SEC;

    // TODO Call shaders to re-render the screen
    // Shaders will need to:
    // - Translate and rotate the camera to achieve an isometric viewpoint
    // - Rotate the geometry to the current rotation angle
    // - Find hotspots of color (bloom?) and color the regions by intensity

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(ra->mesh_program_handle);

    GLuint y_rads_location = glGetUniformLocation(ra->mesh_program_handle, "y_rads");
    glUniform1f(y_rads_location, rotation_angle);

    if (ra->is_preview)
    {
        printf("y_rads = %f @ %d\n", rotation_angle, y_rads_location);
    }

    glBindVertexArray(ra->vao_handle);
    glLineWidth(5.0f);
    glDrawArrays(GL_LINES, 0, sizeof(vertices) / (sizeof(float) * 3));
}
