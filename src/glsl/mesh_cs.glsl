#version 460 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

/**
 * The control points of the random attractor cubic bezier curve.
 *
 * If the points of the random attractor curve are:
 *   P1    P2    P3    P4
 *   P5    P6    P7    P8
 *   P9    P10   P11   P12
 *
 * Then the bezier control points are:
 *   P1    P2    P3    P4       : ( 4 unique + 0 overlap + 0 mirror) =  4 total
 *   P4    P4*   P5    P6       : ( 6 unique + 1 overlap + 1 mirror) =  8 total
 *   P6    P6*   P7    P8       : ( 8 unique + 2 overlap + 2 mirror) = 12 total
 *   P8    P8*   P9    P10      : (10 unique + 3 overlap + 3 mirror) = 16 total
 *   P10   P10*  P11   P12      : (12 unique + 4 overlap + 4 mirror) = 20 total
 *
 * ... where Px* is the mirrored control point of the previous two points:
 *   P(x)* = P(x) + (P(x) - P(x-1))
 *
 * Multiple paths (P, Q, R, ...) are concatenated in this buffer:
 *   P1 P2 P3 Q1 Q2 Q3 R1 R2 R3
 *
 * The size of this buffer is therefore:
 *   CONTROLS_PER_BEZIER * BEZIER_PER_PATH * PATH_COUNT
 *
 * Each path starts at:
 *   PATH_INDEX * (CONTROLS_PER_BEZIER * BEZIER_PER_PATH)
 *
 * Each curve therefore starts at:
 *   PATH_START + (CONTROLS_PER_BEZIER * BEZIER_INDEX)
 */
struct ControlPoint
{
    vec4 position;
    /**
     * std430 enforces 16-byte alignment
     *
     * X: path_fraction
     * Y: Unused
     * Z: Unused
     * W: Unused
     */
    vec4 data;
};
layout(std430, binding = 0) buffer ControlPoints
{
    ControlPoint control[];
};

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

void expand_bounds(vec4 expand)
{
    mesh_bounding_box.minimum.x = min(mesh_bounding_box.minimum.x, expand.x);
    mesh_bounding_box.minimum.y = min(mesh_bounding_box.minimum.y, expand.y);
    mesh_bounding_box.minimum.z = min(mesh_bounding_box.minimum.z, expand.z);
    mesh_bounding_box.minimum.w = min(mesh_bounding_box.minimum.w, expand.w);

    mesh_bounding_box.maximum.x = max(mesh_bounding_box.maximum.x, expand.x);
    mesh_bounding_box.maximum.y = max(mesh_bounding_box.maximum.y, expand.y);
    mesh_bounding_box.maximum.z = max(mesh_bounding_box.maximum.z, expand.z);
    mesh_bounding_box.maximum.w = max(mesh_bounding_box.maximum.w, expand.w);
}

//                                                                                              
//        mmmm     mmmm    mmm   mm    mmmm    mmmmmmmm     mm     mmm   mm  mmmmmmmm    mmmm   
//      ##""""#   ##""##   ###   ##  m#""""#   """##"""    ####    ###   ##  """##"""  m#""""#  
//     ##"       ##    ##  ##"#  ##  ##m          ##       ####    ##"#  ##     ##     ##m      
//     ##        ##    ##  ## ## ##   "####m      ##      ##  ##   ## ## ##     ##      "####m  
//     ##m       ##    ##  ##  #m##       "##     ##      ######   ##  #m##     ##          "## 
//      ##mmmm#   ##mm##   ##   ###  #mmmmm#"     ##     m##  ##m  ##   ###     ##     #mmmmm#" 
//        """"     """"    ""   """   """""       ""     ""    ""  ""   """     ""      """""   
//                                                                                              

/** The number of paths stored in the control buffer. */
uniform int PATH_COUNT;

/** The number of beziers stored in the control buffer. */
uniform int BEZIER_PER_PATH;

/** The number of control points which comprise each beziers in the control buffer. */
int CONTROLS_PER_BEZIER = 4;

/** */
int CONTROLS_PER_PATH = CONTROLS_PER_BEZIER * BEZIER_PER_PATH;

/**
 * Each complete Bezier shares its start and end control points with its
 * neighbouring curves, hence each new curve only adds 3 unique control
 * points:
 *
 * A1 A2 A3 A4                                +4 (-1+1)
 * ^^       B1 B2 B3 B4                       +4 -1
 * Not               C1 C2 C3 C4              +4 -1
 * Shared!  ||       ^^       D1 D2 D3 D4     +4 -1
 *          ||       ||       ^^              
 *          ||       ||       ||       
 *         Shared Control Points
 *
 * The first and final control points of the whole path are also unique.
 */
int UNIQUE_CONTROLS_PER_PATH = CONTROLS_PER_PATH - BEZIER_PER_PATH + 1;

//                                                                
//     mmmmmm    mm    mm  mmmmmmmm  mmmmmmmm  mmmmmmmm  mmmmmm   
//     ##""""##  ##    ##  ##""""""  ##""""""  ##""""""  ##""""## 
//     ##    ##  ##    ##  ##        ##        ##        ##    ## 
//     #######   ##    ##  #######   #######   #######   #######  
//     ##    ##  ##    ##  ##        ##        ##        ##  "##m 
//     ##mmmm##  "##mm##"  ##        ##        ##mmmmmm  ##    ## 
//     """""""     """"    ""        ""        """"""""  ""    """
//                                                                

/**
 * @returns The index (in the control buffer) where the given path starts.
 */
int path_start(int path_index)
{
    // Clamp interval: [0, PATH_COUNT)
    if (path_index >= PATH_COUNT) path_index = PATH_COUNT - 1;
    if (path_index < 0) path_index = 0;

    int path_length = CONTROLS_PER_BEZIER * BEZIER_PER_PATH;
    return path_index * path_length;
}

/**
 * @returns The index (in the control buffer) where the given bezier starts.
 */
int bezier_start(int path_index, int bezier_index)
{
    // Clamp interval: [0, BEZIER_PER_PATH]
    if (bezier_index >= BEZIER_PER_PATH) bezier_index = BEZIER_PER_PATH - 1;
    if (bezier_index < 0) bezier_index = 0;

    int index_within_path = bezier_index * CONTROLS_PER_BEZIER;
    return path_start(path_index) + index_within_path;
}

/**
 * @returns The index (in the control buffer) where the given control point starts.
 */
int control_start(int path_index, int bezier_index, int ctrlpt_index)
{
    // Clamp interval: [0, BEZIER_PER_PATH]
    if (ctrlpt_index >= CONTROLS_PER_BEZIER) ctrlpt_index = CONTROLS_PER_BEZIER - 1;
    if (ctrlpt_index < 0) ctrlpt_index = 0;

    return bezier_start(path_index, bezier_index) + ctrlpt_index;
}

/**
 * @returns The control point (from the control buffer) at the given location.
 */
ControlPoint get_control(int path_index, int bezier_index, int ctrlpt_index)
{
    return control[control_start(path_index, bezier_index, ctrlpt_index)];
}

/**
 * Set the control point (in the control buffer) at the given location.
 */
void set_control(int path_index, int bezier_index, int ctrlpt_index, ControlPoint cp)
{
    control[control_start(path_index, bezier_index, ctrlpt_index)] = cp;
}

vec4 mirrored_control_position(vec4 p1, vec4 p2)
{
    return p2 + (p2 - p1);
}


//                                                                                              
//        mm     mmmmmmmm  mmmmmmmm  mmmmmm       mm        mmmm   mmmmmmmm    mmmm    mmmmmm   
//       ####    """##"""  """##"""  ##""""##    ####     ##""""#  """##"""   ##""##   ##""""## 
//       ####       ##        ##     ##    ##    ####    ##"          ##     ##    ##  ##    ## 
//      ##  ##      ##        ##     #######    ##  ##   ##           ##     ##    ##  #######  
//      ######      ##        ##     ##  "##m   ######   ##m          ##     ##    ##  ##  "##m 
//     m##  ##m     ##        ##     ##    ##  m##  ##m   ##mmmm#     ##      ##mm##   ##    ## 
//     ""    ""     ""        ""     ""    """ ""    ""     """"      ""       """"    ""    """
//                                                                                              

vec4 spiralPoint(int i)
{
    float magnitude = 0.75 * float(i) / float(4);
    vec3 direction = vec3(0.0, 0.0, 0.0);
    
    switch(i % 4)
    {
        case 0:
            direction = vec3(1, 0, 0);
            break;
        case 1:
            direction = vec3(0, 1, 0);
            break;
        case 2:
            direction = vec3(-1, 0, 0);
            break;
        case 3:
            direction = vec3(0, -1, 0);
            break;
    }

    vec3 vector = direction * magnitude;
    return vec4(vector.x, vector.y, vector.z, 1.0);
}

int _temp_point_index = 0;
vec4 generate_next_attractor_point()
{
    return spiralPoint(_temp_point_index++);
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

    for (int path = 0; path < PATH_COUNT; path++)
    {

        int unique_controls_on_path = 0;

        for (int bez = 0; bez < BEZIER_PER_PATH; bez++)
        {
            // 
            // If this is the first bezier, we just generate 4 new points,
            // ignoring continuity since there is no previous bezier
            //
            if (bez <= 0)
            {
                for (int ctrl = 0; ctrl < CONTROLS_PER_BEZIER; ctrl++)
                {
                    ControlPoint cp;

                    cp.position = generate_next_attractor_point();
                    unique_controls_on_path++;

                    cp.data.x = float(unique_controls_on_path-1) / float(UNIQUE_CONTROLS_PER_PATH-1);
                    cp.data.y = 0.0;
                    cp.data.z = 0.0;
                    cp.data.w = 0.0;

                    set_control(path, bez, ctrl, cp);
                    expand_bounds(cp.position);
                }

                continue;
            }
            //
            // For all Beziers after the first, we must handle position and
            // tangential continuity
            //
            else
            {
                for (int ctrl = 0; ctrl < CONTROLS_PER_BEZIER; ctrl++)
                {
                    ControlPoint cp;

                    switch (ctrl)
                    {
                        //
                        // If 0, add control for position continuity
                        //
                        // We DON'T increment the unique_controls_on_path
                        // because this is shared from the previous Bezier
                        //
                        case 0:
                            cp.position = get_control(path, bez-1, 3).position;
                            break;
                        //
                        // If 1, add control for tangency continuity
                        //
                        case 1:
                            ControlPoint mirror_from = get_control(path, bez-1, 2);
                            ControlPoint mirror_to = get_control(path, bez-1, 3);
                            cp.position = mirrored_control_position(mirror_from.position, mirror_to.position);
                            unique_controls_on_path++;
                            break;
                        //
                        // If 2/3, generate a new point
                        //
                        default:
                            cp.position = generate_next_attractor_point();
                            unique_controls_on_path++;
                            break;
                    };

                    cp.data.x = float(unique_controls_on_path-1) / float(UNIQUE_CONTROLS_PER_PATH-1);
                    cp.data.y = 0.0;
                    cp.data.z = 0.0;
                    cp.data.w = 0.0;
                    set_control(path, bez, ctrl, cp);
                    expand_bounds(cp.position);
                }
            }
        }
    }
}