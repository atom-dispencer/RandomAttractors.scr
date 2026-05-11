#version 460 core

layout(location = 0) in vec4 in_position;
layout(location = 1) in float in_path_fraction;
layout(location = 2) in float _unused1;
layout(location = 3) in float _unused2;
layout(location = 4) in float _unused3;

out float vs_path_fraction;

//                                                                
//     mmmmmm      mmmm    mm    mm  mmm   mm  mmmmm       mmmm   
//     ##""""##   ##""##   ##    ##  ###   ##  ##"""##   m#""""#  
//     ##    ##  ##    ##  ##    ##  ##"#  ##  ##    ##  ##m      
//     #######   ##    ##  ##    ##  ## ## ##  ##    ##   "####m  
//     ##    ##  ##    ##  ##    ##  ##  #m##  ##    ##       "## 
//     ##mmmm##   ##mm##   "##mm##"  ##   ###  ##mmm##   #mmmmm#" 
//     """""""     """"      """"    ""   """  """""      """""   
//                                                                

struct BoundingBox
{
    vec4 minimum;
    vec4 maximum;
};
layout(std430, binding = 1) buffer MeshBoundingBox
{
    BoundingBox mesh_bounding_box;
};

//                                                                
//     mmm  mmm     mm     mmmmmmmm  mmmmmm     mmmmmm   mmm  mmm 
//     ###  ###    ####    """##"""  ##""""##   ""##""    ##mm##  
//     ########    ####       ##     ##    ##     ##       ####   
//     ## ## ##   ##  ##      ##     #######      ##        ##    
//     ## "" ##   ######      ##     ##  "##m     ##       ####   
//     ##    ##  m##  ##m     ##     ##    ##   mm##mm    ##  ##  
//     ""    ""  ""    ""     ""     ""    """  """"""   """  """ 
//                                                                

mat4 translate(vec3 v)
{
    return mat4(
        vec4(1.0, 0.0, 0.0, 0.0),
        vec4(0.0, 1.0, 0.0, 0.0),
        vec4(0.0, 0.0, 1.0, 0.0),
        vec4(v.x, v.y, v.z, 1.0)
    );
}

mat4 scale(vec3 v)
{
    return mat4(
        vec4(v.x, 0.0,  0.0,  0.0),
        vec4(0.0,  v.y, 0.0,  0.0),
        vec4(0.0,  0.0, v.z,  0.0),
        vec4(0.0,  0.0, 0.0,  1.0)
    );
}

//                                            
//     mmm  mmm     mm      mmmmmm   mmm   mm 
//     ###  ###    ####     ""##""   ###   ## 
//     ########    ####       ##     ##"#  ## 
//     ## ## ##   ##  ##      ##     ## ## ## 
//     ## "" ##   ######      ##     ##  #m## 
//     ##    ##  m##  ##m   mm##mm   ##   ### 
//     ""    ""  ""    ""   """"""   ""   """ 
//                                            

void main()
{
    float dX = mesh_bounding_box.maximum.x - mesh_bounding_box.minimum.x;
    float dY = mesh_bounding_box.maximum.y - mesh_bounding_box.minimum.y;
    float dZ = mesh_bounding_box.maximum.z - mesh_bounding_box.minimum.z;
    float normal_scale = max(dX, max(dY, dZ));

    // The final maximum dimension the transformed vertex should have
    // The final mesh will fit in a cube of dimensions:
    //   `up_scale * up_scale * up_scale`
    float up_scale = 1.5;

    gl_Position = //
        // (4)
        // Make the mesh hover above the spotlight
        // It's now: [-1,+0,-1] -> [+1,+2,+1]
        translate( up_scale*vec3(0,0.5,0) )
        // (3)
        // Scale the bounding box down
        // It's now: [-1,-1,-1] -> [+1,+1,+1]
        * scale( vec3(up_scale/normal_scale) )
        // (2)
        // Centre the bounding box on [0,0,0]
        // It's now: [-dX/2,-dY/2,-dZ/2] -> [+dX/2,+dY/2,+dZ/2]
        * translate( -0.5*vec3(dX,dY,dZ) )
        // (1)
        // Anchor the bounding box on [0,0,0]
        // It's now: [0,0,0] -> [dX,dY,dZ]
        * translate( -mesh_bounding_box.minimum.xyz )
        //
        * in_position;

    vs_path_fraction = in_path_fraction;
}
