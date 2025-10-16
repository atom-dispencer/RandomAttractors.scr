// GLAD must be included before GLFW or everything breaks!
// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>
// clang-format on

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "mandelbrot.h"

int main(int argc, char *argv[]) {
  struct Mandelbrot *mdbrt = malloc(sizeof(struct Mandelbrot));

  Mandelbrot_parseArgs(mdbrt, argc, argv);
  if (mdbrt->error != Mandelbrot_OK) {
    printf("Error parsing arguments: %d\n", mdbrt->error);
    Mandelbrot_printHelp();
    return mdbrt->error;
  }

  Mandelbrot_Init(mdbrt, 500, 1);

  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

  Mandelbrot_createGLFWWindow(mdbrt);
  if (mdbrt->error != Mandelbrot_OK) {
    printf("Error creating GLFW window: %d\n", mdbrt->error);
    glfwTerminate();
    return mdbrt->error;
  }

  Mandelbrot_compileShader(mdbrt, &(mdbrt->geometryShader), geometryVertexShaderSource,
                     geometryFragmentShaderSource);
  Mandelbrot_compileShader(mdbrt, &(mdbrt->pointsShader), pointVertexShaderSource,
                     pointFragmentShaderSource);
  Mandelbrot_compileShader(mdbrt, &(mdbrt->screenShader), screenVertexShaderSource,
                     screenFragmentShaderSource);
  Mandelbrot_compileShader(mdbrt, &(mdbrt->blurredShader), blurVertexShaderSource,
                     blurFragmentShaderSource);
  Mandelbrot_compileShader(mdbrt, &(mdbrt->bloomShader), bloomVertexShaderSource,
                     bloomFragmentShaderSource);

  if (!mdbrt->is_preview) {
    glfwSetInputMode(mdbrt->window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
  }

  // glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
  glfwSwapInterval(2);  // 0 for vsync off
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  Mandelbrot_prepareBuffers(mdbrt);
  if (mdbrt->error != Mandelbrot_OK) {
    printf("Error preparing OpenGL buffers: %d\n", mdbrt->error);
    glfwTerminate();
    return mdbrt->error;
  }

  // Set up timing
  long long startEpochNano = 0;
  long long uptimeEpochNanos = 0;
  struct timespec ts;

  timespec_get(&ts, TIME_UTC);
  startEpochNano = (long long)(ts.tv_sec * 1e9 + ts.tv_nsec);

  while (!glfwWindowShouldClose(mdbrt->window)) {
    timespec_get(&ts, TIME_UTC);
    thisEpochNano = (long long)(ts.tv_sec * 1e9 + ts.tv_nsec);
    uptimeEpochNanos = thisEpochNano - startEpochNano;

    if (mdbrt->is_preview) {
      // printf("\n%.6fs\n%ffps\n", dSecs, 1 / dSecs);
    }

    Mandelbrot_process(mdbrt, dSecs);
    Mandelbrot_render(mdbrt);

    glfwSwapBuffers(mdbrt->window);
    glfwPollEvents();
  }
  if (mdbrt->is_preview) {
    printf("Shutting down gracefully...\n");
  }

  enum Mandelbrot_Error error = Mandelbrot_DeInit(mdbrt);
  if (error != Mandelbrot_OK) {
    printf("Error deinitialising Mandelbrot: %d\n", error);
  }

  glfwTerminate();
  return Mandelbrot_OK;
}

enum Mandelbrot_Error Mandelbrot_Init(struct Mandelbrot *mdbrt, int maxParticles, int maxRockets) {
  if (mdbrt->is_preview) {
    printf("Initialising new Mandelbrot with maxParticles=%d, maxRockets=%d\n",
           maxParticles, maxRockets);
  }
  mdbrt->error = Mandelbrot_ERROR_INIT;

  struct timespec ts;
  timespec_get(&ts, TIME_UTC);
  srand(ts.tv_nsec);
  if (mdbrt->is_preview) {
    printf("Random seed is %ld\n", ts.tv_nsec);
  }

  int renderDataAllocation = sizeof(struct ParticleRenderData) * maxParticles;
  int particlesAllocation = sizeof(struct Particle) * maxParticles;
  if (mdbrt->is_preview) {
    printf("renderData will be allocated %d bytes\n", renderDataAllocation);
    printf("particles will be allocated %d bytes\n", renderDataAllocation);
  }

  mdbrt->window, mdbrt->geometryShader, mdbrt->circleVAO, mdbrt->circleVBO,
      mdbrt->dataVBO, mdbrt->circleEBO = -1;
  mdbrt->renderData = malloc(renderDataAllocation);

  struct MandelbrotSimulation simulation;
  simulation.maxParticles = maxParticles;
  simulation.liveParticles = 0;
  simulation.maxRockets = maxRockets;
  simulation.liveRockets = 0;
  simulation.mdbrtIsPreview = mdbrt->is_preview;
  simulation.particles = malloc(particlesAllocation);
  simulation.timeSinceRocketCount = 0;
  mdbrt->simulation = simulation;

  struct Particle defaultParticle;
  defaultParticle.isAlive = 0;
  defaultParticle.position[0] = 0;
  defaultParticle.position[1] = 0;
  defaultParticle.position[2] = 0;
  defaultParticle.velocity[0] = 0;
  defaultParticle.velocity[1] = 0;
  defaultParticle.velocity[2] = 0;
  defaultParticle.acceleration[0] = 0;
  defaultParticle.acceleration[1] = 0;
  defaultParticle.acceleration[2] = 0;
  defaultParticle.colour[0] = 1;
  defaultParticle.colour[1] = 1;
  defaultParticle.colour[2] = 1;
  defaultParticle.colour[3] = 1;
  defaultParticle.children = 0;
  defaultParticle.radius = 0;
  defaultParticle.remainingLife = 0;
  defaultParticle.timeSinceLastEmission = 0;
  defaultParticle.type = PT_HAZE;

  for (int i = 0; i < simulation.maxParticles; i++) {
    mdbrt->simulation.particles[i] = defaultParticle;
  }

  struct ParticleRenderData defaultRenderData;
  defaultRenderData.translate[0] = 0;
  defaultRenderData.translate[1] = 0;
  defaultRenderData.translate[2] = 0;
  defaultRenderData.colour[0] = 1;
  defaultRenderData.colour[1] = 1;
  defaultRenderData.colour[2] = 1;
  defaultRenderData.colour[3] = 1;
  defaultRenderData.radius = 1;
  defaultRenderData.remainingLife = 0;
  defaultRenderData.particleType = PT_HAZE;

  for (int i = 0; i < simulation.maxParticles; i++) {
    mdbrt->renderData[i] = defaultRenderData;
  }

  mdbrt->error = Mandelbrot_OK;
  return Mandelbrot_OK;
}

enum Mandelbrot_Error Mandelbrot_DeInit(struct Mandelbrot *mdbrt) {
  if (mdbrt->is_preview) {
    printf("Deinitialising Mandelbrot: ");
  }

  if (mdbrt->is_preview) {
    printf("Deleting OpenGL resources...  ");
  }
  glDeleteVertexArrays(1, &(mdbrt->circleVAO));
  glDeleteBuffers(1, &(mdbrt->circleVBO));
  glDeleteBuffers(1, &(mdbrt->circleEBO));
  glDeleteProgram(mdbrt->geometryShader);
  glDeleteFramebuffers(1, &(mdbrt->geometryFBO));
  // TODO delete the rest of the buffers

  if (mdbrt->is_preview) {
    printf("Freeing memory...  ");
  }
  free(mdbrt->renderData);
  free(mdbrt->simulation.particles);
  free(mdbrt);
  return Mandelbrot_OK;
}

void Mandelbrot_parseArgs(struct Mandelbrot *mdbrt, int argc, char *argv[]) {
  if (argc < 2) {
    printf("Not enough arguments!\n");
    mdbrt->error = Mandelbrot_ERROR_INIT_ARGCOUNT;
    return;
  }

  if (strcmp(argv[1], "/s") == 0) {
    mdbrt->is_preview = 0;
  } else if (strcmp(argv[1], "/p") == 0) {
    mdbrt->is_preview = 1;
    printf("Preview mode detected!\n");
  } else {
    printf("Unrecognised argument: %s\n", argv[1]);
    mdbrt->error = Mandelbrot_ERROR_INIT_UNKNOWNARG;
    return;
  }

  mdbrt->error = Mandelbrot_OK;
}

void Mandelbrot_printHelp() {
  printf("\n  ~~ Help ~~ \n");
  printf("  FireworksGL.scr Screensaver, by Adam Spencer \n");
  printf("  https://github.com/atom-dispencer/FireworksGL.scr/ for source code "
         "and full documentation.\n");
  printf("  Options:\n");
  printf("      /s - Run in screensaver mode (fullscreen, logging disabled)\n");
  printf("      /p - Run in preview mode (small window, logging enabled)\n");
  printf("  Correct usage:\n");
  printf("      FireworksGL.scr /s\n");
  printf("      FireworksGL.scr /p\n\n");
}

void Mandelbrot_createGLFWWindow(struct Mandelbrot *mdbrt) {

  GLFWwindow *window = NULL;
  int width = 0;
  int height = 0;

  // It's a screensaver, it shouldn't change size
  glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

  if (mdbrt->is_preview) {
    printf("Creating preview window\n");
    width = 800;
    height = 600;
    window = glfwCreateWindow(width, height, "FireworksGL", NULL, NULL);
  } else {
    GLFWmonitor *monitor = glfwGetPrimaryMonitor();
    const GLFWvidmode *mode = glfwGetVideoMode(monitor);

    width = mode->width;
    height = mode->height;

    window = glfwCreateWindow(width, height, "FireworksGL", monitor, NULL);
  }

  if (window == NULL) {
    printf("Failed to create GLFW window.\n");
    glfwTerminate();
    mdbrt->error = Mandelbrot_ERROR_INIT_GLFWWINDOW;
    return;
  }
  glfwMakeContextCurrent(window);

  if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
    printf("Failed to initialize GLAD\n");
    mdbrt->error = Mandelbrot_ERROR_INIT_GLAD;
    return;
  }

  glViewport(0, 0, width, height);
  glfwSetFramebufferSizeCallback(window, Mandelbrot_framebufferSizeCallback);

  mdbrt->window = window;
  mdbrt->error = Mandelbrot_OK;
}

void Mandelbrot_framebufferSizeCallback(GLFWwindow *window, int width, int height) {
  glViewport(0, 0, width, height);
}

void Mandelbrot_process(struct Mandelbrot *mdbrt, float dSecs) {
  if (GLFW_PRESS == glfwGetKey(mdbrt->window, GLFW_KEY_SPACE) ||
      GLFW_PRESS == glfwGetKey(mdbrt->window, GLFW_KEY_ENTER) ||
      GLFW_PRESS == glfwGetMouseButton(mdbrt->window, GLFW_MOUSE_BUTTON_LEFT)) {
    if (mdbrt->is_preview) {
      printf("Input detected! Triggering close...\n");
    }
    glfwSetWindowShouldClose(mdbrt->window, GLFW_TRUE);
  }

  int width;
  int height;
  glfwGetWindowSize(mdbrt->window, &width, &height);
  MoveParticles(&(mdbrt->simulation), width, height, dSecs);
}

void Mandelbrot_compileShader(struct Mandelbrot *mdbrt, unsigned int *program,
                        const char *vertexSource, const char *fragSource) {

  int success;
  char log[512];

  if (mdbrt->is_preview) {
    printf("Vertex Shader:\n%s\n", vertexSource);
    printf("Fragment Shader:\n%s\n", fragSource);
  }

  unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &vertexSource, NULL);
  glCompileShader(vertexShader);
  glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
  if (!success) {
    glGetShaderInfoLog(vertexShader, 512, NULL, log);
    printf("Failed to compile vertex shader: %s", log);
  }

  unsigned int fragShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragShader, 1, &fragSource, NULL);
  glCompileShader(fragShader);
  glGetShaderiv(fragShader, GL_COMPILE_STATUS, &success);
  if (!success) {
    glGetShaderInfoLog(fragShader, 512, NULL, log);
    printf("Failed to compile fragment shader: %s", log);
  }

  unsigned quadProgram = glCreateProgram();
  *program = quadProgram;
  glAttachShader(quadProgram, vertexShader);
  glAttachShader(quadProgram, fragShader);
  glLinkProgram(quadProgram);
  glGetProgramiv(quadProgram, GL_LINK_STATUS, &success);
  if (!success) {
    glGetProgramInfoLog(quadProgram, 512, NULL, log);
    printf("Failed to link quad shader program: %s", log);
  }

  glDeleteShader(vertexShader);
  glDeleteShader(fragShader);
  if (mdbrt->is_preview) {
    printf("Successfully compiled and linked shader program!\n");
  }
}

void Mandelbrot_makeTexture(unsigned int *texture, int width, int height) {

  unsigned int handle;
  glGenTextures(1, &handle);
  glBindTexture(GL_TEXTURE_2D, handle);
  // glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
  // GL_UNSIGNED_BYTE, NULL);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, width, height, 0, GL_RGBA,
               GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  *texture = handle;
}

void Mandelbrot_makeFramebuffer(unsigned int *framebuffer, unsigned int texture) {
  unsigned int fbo;
  glGenFramebuffers(1, &fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                         texture, 0);
  GLenum fbStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  if (GL_FRAMEBUFFER_COMPLETE != fbStatus) {
    printf("Erronious framebuffer status: %d\n", fbStatus);
  }
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  *framebuffer = fbo;
}

void Mandelbrot_prepareBuffers(struct Mandelbrot *mdbrt) {
  //
  // Handles
  //
  // Basic output of the particle geometry (semi-transparent circles on a black
  // background)
  unsigned int dimensionUBO, circleVAO, circleVBO, circleEBO, dataVBO;
  unsigned int geometryFBO, geometryTexture, geometryShader;
  unsigned int pointsVAO;
  // A blurred version of the geometry
  unsigned int blurredFBO1, blurredTexture1, blurredShader;
  unsigned int blurredFBO2, blurredTexture2;
  // A HDR buffer with the bloom (addition) result of the blur and geometry
  // buffers
  unsigned int bloomFBO, bloomTexture;
  // A tone-remapped FBO to reduce the bloom to the standard 0-1 range.
  unsigned int tonemappedFBO;
  // Tone-mapped buffer gets drawn to the screen
  unsigned int screenShader, screenVAO, screenVBO;

  int width, height;
  glfwGetWindowSize(mdbrt->window, &width, &height);

  //
  // Framebuffers
  //
  // Geometry
  Mandelbrot_makeTexture(&geometryTexture, width, height);
  Mandelbrot_makeFramebuffer(&geometryFBO, geometryTexture);
  // Blur
  Mandelbrot_makeTexture(&blurredTexture1, width, height);
  Mandelbrot_makeTexture(&blurredTexture2, width, height);
  Mandelbrot_makeFramebuffer(&blurredFBO1, blurredTexture1);
  Mandelbrot_makeFramebuffer(&blurredFBO2, blurredTexture2);
  // Bloom
  Mandelbrot_makeTexture(&bloomTexture, width, height);
  Mandelbrot_makeFramebuffer(&bloomFBO, bloomTexture);

  // 2*f Screen Position (x,y)
  // 2*f Texture Coordinates (x,y)
  glGenVertexArrays(1, &screenVAO);
  glGenBuffers(1, &screenVBO);
  glBindVertexArray(screenVAO);
  glBindBuffer(GL_ARRAY_BUFFER, screenVBO);
  glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices,
               GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                        (void *)(2 * sizeof(float)));

  //
  // Standard rendering
  //

  // 3*f Translate (x,y,z)
  // 4*f Colour (r,g,b,a)
  // 1*f Radius (r)
  // 1*f Remaining Life (l)
  // 1*i Particle Type (t)
  glGenBuffers(1, &dataVBO);

  // Vertices
  glGenVertexArrays(1, &circleVAO);
  glGenBuffers(1, &circleVBO);
  glGenBuffers(1, &circleEBO);

  glBindVertexArray(circleVAO);
  glBindBuffer(GL_ARRAY_BUFFER, circleVBO);
  glBufferData(GL_ARRAY_BUFFER, sizeof(circleVertices), circleVertices,
               GL_STATIC_DRAW);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, circleEBO);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(circleIndices), circleIndices,
               GL_STATIC_DRAW);

  // 2*i Dimensions (w,h)
  glGenBuffers(1, &dimensionUBO);
  glBindBuffer(GL_UNIFORM_BUFFER, dimensionUBO);
  glBindBufferBase(GL_UNIFORM_BUFFER, 0, dimensionUBO);
  int defaultDimensions[4] = {100, 100, 0, 0}; // Pad to 16 bytes for std140
  glBufferData(GL_UNIFORM_BUFFER, sizeof(defaultDimensions), defaultDimensions,
               GL_STATIC_DRAW);

  // Vertex attributes
  // Vertex base position (x,y,z)
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void *)0);
  // Translate (x,y,z)
  glBindBuffer(GL_ARRAY_BUFFER, dataVBO);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE,
                        sizeof(struct ParticleRenderData), (void *)0);
  // Colour (r,g,b,a)
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE,
                        sizeof(struct ParticleRenderData),
                        (void *)(3 * sizeof(float)));
  // Radius (r)
  glEnableVertexAttribArray(3);
  glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE,
                        sizeof(struct ParticleRenderData),
                        (void *)(7 * sizeof(float)));
  // Remaining Life (l)
  glEnableVertexAttribArray(4);
  glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE,
                        sizeof(struct ParticleRenderData),
                        (void *)(8 * sizeof(float)));
  // Particle Type (t)
  glEnableVertexAttribArray(5);
  glVertexAttribIPointer(5, 1, GL_INT, sizeof(struct ParticleRenderData),
                         (void *)(9 * sizeof(float)));

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glVertexAttribDivisor(1, 1); // Stride of 1 between swapping attributes
  glVertexAttribDivisor(2, 1); // Stride of 1 between swapping attributes
  glVertexAttribDivisor(3, 1); // Stride of 1 between swapping attributes
  glVertexAttribDivisor(4, 1); // Stride of 1 between swapping attributes
  glVertexAttribDivisor(5, 1); // Stride of 1 between swapping attributes

  glBindVertexArray(0);

  // Points based on translations
  glGenVertexArrays(1, &pointsVAO);
  glBindVertexArray(pointsVAO);
  glBindBuffer(GL_ARRAY_BUFFER, dataVBO);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE,
                        sizeof(struct ParticleRenderData), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribIPointer(1, 1, GL_INT, sizeof(struct ParticleRenderData),
                         (void *)(9 * sizeof(float)));
  glBindVertexArray(0);

  //
  mdbrt->dimensionUBO = dimensionUBO;
  mdbrt->circleVAO = circleVAO;
  mdbrt->circleVBO = circleVBO;
  mdbrt->circleEBO = circleEBO;
  mdbrt->dataVBO = dataVBO;
  //
  mdbrt->geometryFBO = geometryFBO;
  mdbrt->geometryTexture = geometryTexture;
  mdbrt->pointsVAO = pointsVAO;
  //
  mdbrt->blurredFBO1 = blurredFBO1;
  mdbrt->blurredTexture1 = blurredTexture1;
  mdbrt->blurredFBO2 = blurredFBO2;
  mdbrt->blurredTexture2 = blurredTexture2;
  //
  mdbrt->bloomFBO = bloomFBO;
  mdbrt->bloomTexture = bloomTexture;
  //
  mdbrt->screenVAO = screenVAO;

  mdbrt->error = Mandelbrot_OK;
}

void Mandelbrot_render(struct Mandelbrot *mdbrt) {

  //
  // Geometry
  //
  struct MandelbrotSimulation *simulation = &(mdbrt->simulation);
  struct Particle *p;

  int renderParticles = 0;
  for (int pId = 0; pId < simulation->maxParticles; pId++) {
    p = &(simulation->particles[pId]);
    if (!p->isAlive) {
      continue;
    }

    struct ParticleRenderData data;
    // Translate (x,y,z)
    data.translate[0] = p->position[0];
    data.translate[1] = p->position[1];
    data.translate[2] = p->position[2];
    // Colour (r,g,b,a)
    data.colour[0] = p->colour[0];
    data.colour[1] = p->colour[1];
    data.colour[2] = p->colour[2];
    data.colour[3] = p->colour[3];
    // Radius (r)
    data.radius = p->radius;
    // Remaining Life (l)
    data.remainingLife = p->remainingLife;
    // Particle Type (t)
    data.particleType = p->type;

    mdbrt->renderData[renderParticles] = data;
    renderParticles++;
  }

  // Need to pad it to 16 bytes for std140 layout
  int dimensions[4] = {200, 200, 0, 0};
  glfwGetWindowSize(mdbrt->window, &(dimensions[0]), &(dimensions[1]));
  glBindBuffer(GL_UNIFORM_BUFFER, mdbrt->dimensionUBO);
  glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(dimensions), &dimensions);
  glBindBuffer(GL_UNIFORM_BUFFER, 0);

  // Does this need to come before the uniform buffer?
  glBindFramebuffer(GL_FRAMEBUFFER, mdbrt->geometryFBO);
  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT);

  if (renderParticles > 0) {
    int bufferSize = sizeof(struct ParticleRenderData) * renderParticles;
    glBindBuffer(GL_ARRAY_BUFFER, mdbrt->dataVBO);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, mdbrt->renderData, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    int indexCount = (int)(sizeof(circleIndices) / sizeof(int));

    glUseProgram(mdbrt->geometryShader);
    glBindVertexArray(mdbrt->circleVAO);
    glDrawElementsInstanced(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0,
                            renderParticles);
  }
  glBindVertexArray(0);

  // Draw bright cores
  glBindFramebuffer(GL_FRAMEBUFFER, mdbrt->geometryFBO);
  glBindVertexArray(mdbrt->pointsVAO);
  glUseProgram(mdbrt->pointsShader);
  glPointSize(2);
  glDrawArrays(GL_POINTS, 0, renderParticles);

  //
  // Blur
  //
  const int BLUR_PASSES_1 = 2;
  unsigned int blurFBOs[] = {mdbrt->blurredFBO1, mdbrt->blurredFBO2};
  unsigned int blurTextures[] = {mdbrt->blurredTexture1, mdbrt->blurredTexture2};

  glUseProgram(mdbrt->blurredShader);
  for (int pass = 0; pass < 2 * BLUR_PASSES_1; pass++) {
    int pingpong = pass % 2;

    unsigned int blurDestFBO = blurFBOs[pingpong];
    unsigned int blurSourceTexture = blurTextures[1 - pingpong];

    glBindFramebuffer(GL_FRAMEBUFFER, blurDestFBO);

    unsigned int loc = glGetUniformLocation(mdbrt->blurredShader, "horizontal");
    glUniform1i(loc, 0 == pingpong);

    // 0: (Initial condition) Draw from geometry to texture1
    // 1: Draw from texture1 to texture2
    // 2: Draw from texture2 to texture1
    // 3: Draw from texture1 to texture2
    // etc... (alternating)
    if (0 == pass) {
      glBindTexture(GL_TEXTURE_2D, mdbrt->geometryTexture);
    } else {
      glBindTexture(GL_TEXTURE_2D, blurSourceTexture);
    }

    glBindVertexArray(mdbrt->screenVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
  }

  // Bloom
  glBindFramebuffer(GL_FRAMEBUFFER, mdbrt->bloomFBO);
  glUseProgram(mdbrt->bloomShader);

  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, mdbrt->blurredTexture2);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, mdbrt->geometryTexture);

  glUniform1i(glGetUniformLocation(mdbrt->bloomShader, "texture0_screen"), 0);
  glUniform1i(glGetUniformLocation(mdbrt->bloomShader, "texture1_blur"), 1);
  glBindVertexArray(mdbrt->screenVAO);
  glDrawArrays(GL_TRIANGLES, 0, 6);

  // Blur round 2
  const int BLUR_PASSES_2 = 1;
  glUseProgram(mdbrt->blurredShader);
  for (int pass = 0; pass < 2 * BLUR_PASSES_2; pass++) {
    int pingpong = pass % 2;

    unsigned int blurDestFBO = blurFBOs[pingpong];
    unsigned int blurSourceTexture = blurTextures[1 - pingpong];

    glBindFramebuffer(GL_FRAMEBUFFER, blurDestFBO);

    unsigned int loc = glGetUniformLocation(mdbrt->blurredShader, "horizontal");
    glUniform1i(loc, 0 == pingpong);

    // 0: (Initial condition) Draw from geometry to texture1
    // 1: Draw from texture1 to texture2
    // 2: Draw from texture2 to texture1
    // 3: Draw from texture1 to texture2
    // etc... (alternating)
    if (0 == pass) {
      glBindTexture(GL_TEXTURE_2D, mdbrt->bloomTexture);
    } else {
      glBindTexture(GL_TEXTURE_2D, blurSourceTexture);
    }

    glBindVertexArray(mdbrt->screenVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
  }

  //
  // Screen
  //
  // Return to the regular framebuffer and render the processed texture as a
  // quad Don't need to clear colours because quad is opaque.
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glUseProgram(mdbrt->screenShader);
  glBindVertexArray(mdbrt->screenVAO);
  glBindTexture(GL_TEXTURE_2D, mdbrt->bloomTexture);
  glDrawArrays(GL_TRIANGLES, 0, 6);
}
