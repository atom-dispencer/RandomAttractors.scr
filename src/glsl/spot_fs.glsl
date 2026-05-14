#version 460 core

uniform sampler2D spot_texture;

in vec2 TexCoord;

out vec4 FragColor;

void main()
{
  vec4 texture_colour = texture(spot_texture, TexCoord);

  float brightness = 0.6;
  FragColor = vec4(
    texture_colour.x * brightness,
    texture_colour.y * brightness,
    texture_colour.z * brightness,
    texture_colour.w
  );
}
