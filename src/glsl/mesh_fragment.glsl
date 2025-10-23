#version 330 core

in vec4 vertex_colour;
out vec4 FragColor;

void main()
{
  FragColor = vertex_colour;
}
