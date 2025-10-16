#pragma once

enum Mandelbrot_Error {
  Mandelbrot_OK = 0,
  Mandelbrot_ERROR_INIT = 100,
  Mandelbrot_ERROR_INIT_ARGCOUNT = 101,
  Mandelbrot_ERROR_INIT_GLFWWINDOW = 102,
  Mandelbrot_ERROR_INIT_UNKNOWNARG = 103,
  Mandelbrot_ERROR_INIT_GLAD = 104,
  Mandelbrot_ERROR_INIT_COMPILEVERTEX = 105,
  Mandelbrot_ERROR_INIT_COMPILEFRAGMENT = 106,
  Mandelbrot_ERROR_INIT_SHADERLINK = 107,
  Mandelbrot_ERROR_PREPBUFFER_FRAME_RENDER = 200,
  Mandelbrot_ERROR_PREPBUFFER_FRAME_EFFECT = 201,
};

struct Mandelbrot {
  enum Mandelbrot_Error error;
  uint8_t is_preview;
  GLFWwindow *window;

  uint64_t time;
  float zoom;
  float x;
  float y;

  // Basic circle geometry
  unsigned int dimensionUBO, circleVAO, circleVBO, circleEBO, dataVBO;
  unsigned int geometryFBO, geometryTexture, geometryShader;
  unsigned int pointsVAO, pointsShader;
  unsigned int blurredFBO1, blurredTexture1, blurredShader;
  unsigned int blurredFBO2, blurredTexture2;
  unsigned int bloomFBO, bloomTexture, bloomShader;
  unsigned int screenShader, screenVAO;
};

#define TO_GLCOLOR(b) (b / 255.0f)

enum Mandelbrot_Error Mandelbrot_Init(struct Mandelbrot *fwgl, int maxParticles, int maxRockets);
enum Mandelbrot_Error Mandelbrot_DeInit(struct Mandelbrot *fwgl);
void Mandelbrot_printHelp();
void Mandelbrot_parseArgs(struct Mandelbrot *fwgl, int argc, char *argv[]);
void Mandelbrot_createGLFWWindow(struct Mandelbrot *fwgl);
void Mandelbrot_framebufferSizeCallback(GLFWwindow *window, int width, int height);
void Mandelbrot_process(struct Mandelbrot *fwgl, float dSecs);
void Mandelbrot_compileShader(struct Mandelbrot *fwgl, unsigned int *program,
                        const char *vertexSource, const char *fragSource);
void Mandelbrot_prepareBuffers(struct Mandelbrot *fwgl);
void Mandelbrot_render(struct Mandelbrot *fwgl);
