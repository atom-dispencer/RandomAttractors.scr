#version 460 core

uniform sampler2D spot_texture;

in vec2 TexCoord;

out vec4 FragColor;

void main()
{
  FragColor = texture(spot_texture, TexCoord);
}
