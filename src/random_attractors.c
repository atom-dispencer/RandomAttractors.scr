// GLAD must be included before GLFW or everything breaks!
// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>
// clang-format on

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "random_attractors.h"

#define ROTATION_RADS_PER_SEC (0.1 * M_PI)

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

    // TODO Need to compile all the shaders!
    ra_compile_shader();

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
        current_epoch_nanos = (long long)(ts.tv_sec * 1e9 + ts.tv_nsec);
        uptime_nanos        = current_epoch_nanos - start_epoch_nanos;
        if (current_epoch_nanos - last_step_epoch_nanos > 1e9)
        {
            ra_compute_next_step(&ra);
            last_step_epoch_nanos = current_epoch_nanos;
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

long long ra_get_uptime_millis()
{
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

        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    }
    else
    {
        GLFWmonitor       *monitor = glfwGetPrimaryMonitor();
        const GLFWvidmode *mode    = glfwGetVideoMode(monitor);

        width  = mode->width;
        height = mode->height;

        window = glfwCreateWindow(width, height, "RandomAttractors.scr", monitor, NULL);
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
    glfwSwapInterval(2); // 0 for vsync off

    ra->window = window;
    ra->error  = RA_OK;
}

void _callback_ra_framebuffer_size(GLFWwindow *window, int width, int height)
{
    glViewport(0, 0, width, height);
}

void ra_prepare_buffers(struct RandomAttractors *ra)
{
    // TODO set up vertex buffers etc etc etc
}

void ra_compile_shader()
{
}

void ra_compute_next_step(struct RandomAttractors *ra)
{
    // TODO Run compute shader
}

void ra_render(struct RandomAttractors *ra, long long uptime_nanos)
{
    double uptime_secs    = uptime_nanos / 1e9;
    float  rotation_angle = sin(uptime_secs * ROTATION_RADS_PER_SEC);

    // TODO Call shaders to re-render the screen
}
