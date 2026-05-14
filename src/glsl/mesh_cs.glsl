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
const int CONTROLS_PER_BEZIER = 4;

int TOTAL_BEZIERS = PATH_COUNT * BEZIER_PER_PATH;

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
 * @returns The index (in the control buffer) where the given bezier starts.
 */
int bezier_start(int bezier_index)
{
    // Clamp interval: [0, TOTAL_BEZIERS]
    if (bezier_index >= TOTAL_BEZIERS) bezier_index = TOTAL_BEZIERS - 1;
    if (bezier_index < 0) bezier_index = 0;

    return bezier_index * CONTROLS_PER_BEZIER;
}

/**
 * @returns The index (in the control buffer) where the given control point starts.
 */
int control_start(int bezier_index, int ctrlpt_index)
{
    // Clamp interval: [0, CONTROLS_PER_BEZIER]
    if (ctrlpt_index >= CONTROLS_PER_BEZIER) ctrlpt_index = CONTROLS_PER_BEZIER - 1;
    if (ctrlpt_index < 0) ctrlpt_index = 0;

    return bezier_start(bezier_index) + ctrlpt_index;
}

/**
 * @returns The control point (from the control buffer) at the given location.
 */
ControlPoint get_control(int bezier_index, int ctrlpt_index)
{
    return control[control_start(bezier_index, ctrlpt_index)];
}

/**
 * Set the control point (in the control buffer) at the given location.
 */
void set_control(int bezier_index, int ctrlpt_index, ControlPoint cp)
{
    control[control_start(bezier_index, ctrlpt_index)] = cp;
}

vec4 mirrored_control_position(vec4 p1, vec4 p2)
{
    return p2 + (p2 - p1);
}

//                                                                
//     mmmmmm       mm     mmm   mm  mmmmm       mmmm    mmm  mmm 
//     ##""""##    ####    ###   ##  ##"""##    ##""##   ###  ### 
//     ##    ##    ####    ##"#  ##  ##    ##  ##    ##  ######## 
//     #######    ##  ##   ## ## ##  ##    ##  ##    ##  ## ## ## 
//     ##  "##m   ######   ##  #m##  ##    ##  ##    ##  ## "" ## 
//     ##    ##  m##  ##m  ##   ###  ##mmm##    ##mm##   ##    ## 
//     ""    """ ""    ""  ""   """  """""       """"    ""    "" 
//                                                                
//                                                                

layout(std430, binding = 2) buffer SeedRandom
{
    uint srand;
};

float next_float()
{
    srand = srand * 747796405u + 2891336453u;
    srand = ((srand >> ((srand >> 28u) + 4u)) ^ srand) * 277803737u;
    return float((srand >> 22u) ^ srand) / 4294967295.0;
}

// Box-Muller Gaussian
float next_gaussian(float mean, float sigma)
{
    float u1 = max(next_float(), 1e-7);
    float u2 = next_float();

    float r = sqrt(-2.0 * log(u1));
    float theta = 6.28318530718 * u2;

    float z = r * cos(theta);

    return mean + sigma * z;
}

//                                                                                              
//     mmmmmmmm     mm        mmmm   mmmmmmmm    mmmm    mmmmmm     mmmmmm   mmmmmmmm    mmmm   
//     ##""""""    ####     ##""""#  """##"""   ##""##   ##""""##   ""##""   ##""""""  m#""""#  
//     ##          ####    ##"          ##     ##    ##  ##    ##     ##     ##        ##m      
//     #######    ##  ##   ##           ##     ##    ##  #######      ##     #######    "####m  
//     ##         ######   ##m          ##     ##    ##  ##  "##m     ##     ##             "## 
//     ##        m##  ##m   ##mmmm#     ##      ##mm##   ##    ##   mm##mm   ##mmmmmm  #mmmmm#" 
//     ""        ""    ""     """"      ""       """"    ""    """  """"""   """"""""   """""   
//                                                                                              
//                                                                                              

const int PREVIOUS_LENGTH = 10;
/**
 * The 10 most recent points generated by the attractor factory, used to check
 * for suitability of the seed. The most recent point is at index 0, the least
 * recent at index 9.
 */
vec4 PREVIOUS[PREVIOUS_LENGTH];

int spiral_idx = 0;
vec4 factory_spiral()
{
    int i = spiral_idx++;

    float magnitude = 0.25 * float(i) / float(4);
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

vec4 COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[8];
void seed_3d_quadratic_polynomial_map()
{
    float ax[10];
    float ay[10];
    float az[10];
    
    for (int i = 0; i < 10; i++)
    {
        ax[i] = next_gaussian(0.0, 0.5);
        ay[i] = next_gaussian(0.0, 0.5);
        az[i] = next_gaussian(0.0, 0.5);
    }

    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0] = vec4(ax[0], ax[1], ax[2], ax[3]);
    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1] = vec4(ax[4], ax[5], ax[6], ax[7]);
    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2] = vec4(ax[8], ax[9], ay[0], ay[1]);

    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3] = vec4(ay[2], ay[3], ay[4], ay[5]);
    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4] = vec4(ay[6], ay[7], ay[8], ay[9]);

    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5] = vec4(az[0], az[1], az[2], az[3]);
    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6] = vec4(az[4], az[5], az[6], az[7]);
    COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[7] = vec4(az[8], az[9], 0.0, 0.0);

    PREVIOUS[0] = vec4(
        mix(-0.5, 0.5, next_float()),
        mix(-0.5, 0.5, next_float()),
        mix(-0.5, 0.5, next_float()),
        1.0
    );
}

vec4 factory_3d_quadratic_polynomial_map()
{
    float x = PREVIOUS[0].x;
    float y = PREVIOUS[0].y;
    float z = PREVIOUS[0].z;

    float ax[10];
    float ay[10];
    float az[10];

    ax[0] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].x;
    ax[1] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].y;
    ax[2] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].z;
    ax[3] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].w;
    ax[4] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].x;
    ax[5] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].y;
    ax[6] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].z;
    ax[7] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].w;
    ax[8] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].x;
    ax[9] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].y;

    ay[0] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].z;
    ay[1] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].w;
    ay[2] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].x;
    ay[3] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].y;
    ay[4] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].z;
    ay[5] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].w;
    ay[6] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].x;
    ay[7] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].y;
    ay[8] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].z;
    ay[9] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].w;

    az[0] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].x;
    az[1] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].y;
    az[2] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].z;
    az[3] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].w;
    az[4] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].x;
    az[5] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].y;
    az[6] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].z;
    az[7] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].w;
    az[8] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[7].x;
    az[9] = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[7].y;

    float nx =
          ax[0]
        + ax[1] * x
        + ax[2] * y
        + ax[3] * z
        + ax[4] * x * x
        + ax[5] * y * y
        + ax[6] * z * z
        + ax[7] * x * y
        + ax[8] * x * z
        + ax[9] * y * z;

    float ny =
          ay[0]
        + ay[1] * x
        + ay[2] * y
        + ay[3] * z
        + ay[4] * x * x
        + ay[5] * y * y
        + ay[6] * z * z
        + ay[7] * x * y
        + ay[8] * x * z
        + ay[9] * y * z;

    float nz =
          az[0]
        + az[1] * x
        + az[2] * y
        + az[3] * z
        + az[4] * x * x
        + az[5] * y * y
        + az[6] * z * z
        + az[7] * x * y
        + az[8] * x * z
        + az[9] * y * z;

    return vec4(nx, ny, nz, 1.0);

    return vec4(0);
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

/**
 *  0: Unseeded (default)
 *  1: 3D Quadratic Polynomial Map
 */
int ATTRACTOR_FACTORY = 0;

void seed_attractor_factory()
{
    float f = next_float();

    if (f < 1.0)
    {
        seed_3d_quadratic_polynomial_map();
        ATTRACTOR_FACTORY = 1;
    }
    else 
    {
        seed_3d_quadratic_polynomial_map();
        ATTRACTOR_FACTORY = 1;
    }
}

vec4 attractor_factory_next(bool store)
{
    vec4 p;

    switch(ATTRACTOR_FACTORY)
    {
        case 1:
            p = factory_3d_quadratic_polynomial_map();
            break;
        default:
            p = vec4(0);
            break;
    }

    if (store)
    {
        // Shift the previous points back by one, and add the new point to the front
        for (int i = PREVIOUS.length() - 1; i > 0; i--)
        {
            PREVIOUS[i] = PREVIOUS[i-1];
        }
        PREVIOUS[0] = p;
    }

    return p;
}

/**
 * Using the attractor factory seeded in 
 */
bool seeded_attractor_is_suitable()
{
    // Skip the first 1000 points to let behaviour emerge
    // PREVIOUS is now filled with 100 values
    for (int i = 0; i < 1000; i++)
    {
        attractor_factory_next(true);
    }

    // Perturbing factory for Lyapunov calculation
    // Random 4D direction, normalised, and scaled to be a small perturbation
    const vec4 D0 = 0.00005 * normalize(
        vec4(
            mix(-1, +1, next_float()),
            mix(-1, +1, next_float()),
            mix(-1, +1, next_float()),
            mix(-1, +1, next_float())
        )
    );

    float lyapunov = 0;

    // We check the next 10000 points to:
    // - Check the series doesn't explode to infinity
    // - Check the series doesn't tend to a point
    // - Check the series' Lyapunov exponent is positive
    const int ITERATIONS = 10000;
    for (int i = 0; i < ITERATIONS; i++)
    {
        // Perturb previous points 

        // Calculate the parallel path
        // (1) Perturb the previous points in-place
        // (2) Calculate the next point the parallel path, without shuffing the PREVIOUS buffer
        // (3) Un-perturb the previous points 
        // (4) Calculate the next point of the original path, which *will* shuffle the PREVIOUS buffer
        for (int i = 0; i < PREVIOUS.length(); i++) PREVIOUS[i] += D0;
        vec4 xe = attractor_factory_next(false);
        for (int i = 0; i < PREVIOUS.length(); i++) PREVIOUS[i] -= D0;
        vec4 x = attractor_factory_next(true);

        // Calculate the Lyapunov exponent from this step
        float dd = distance(xe, PREVIOUS[0]);
        float d0 = length(D0);
        lyapunov += log( abs(dd/d0) ) / float(ITERATIONS);

        // If the bounds explode, also unsuitable
        if (PREVIOUS[0].x < -1e3 || +1e3 < PREVIOUS[0].x) return false;
        if (PREVIOUS[0].y < -1e3 || +1e3 < PREVIOUS[0].y) return false;
        if (PREVIOUS[0].z < -1e3 || +1e3 < PREVIOUS[0].z) return false;
        if (PREVIOUS[0].w < -1e3 || +1e3 < PREVIOUS[0].w) return false;

        // If this tends to a point, also unsuitable
        float dx = PREVIOUS[0].x - PREVIOUS[1].x;
        float dy = PREVIOUS[0].y - PREVIOUS[1].y;
        float dz = PREVIOUS[0].z - PREVIOUS[1].z;
        float dw = PREVIOUS[0].w - PREVIOUS[1].w;
        if (abs(dx) < 1e-6 && abs(dy) < 1e-6 && abs(dz) < 1e-6 && abs(dw) < 1e-6) return false;
    }

    // If Lyapunov exponent is small or negative, also unsuitable
    if (lyapunov < 0.001) return false;

    // YAY!!
    return true;
}

vec4 generate_next_attractor_point()
{
    if (0 == ATTRACTOR_FACTORY)
    {
        // I don't think we need to limit this as we should always find an
        // attractor within the timeframe.
        do {
            seed_attractor_factory();
        } while(seeded_attractor_is_suitable());
    }

    return attractor_factory_next(true);
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

    //
    //
    //

    int unique_controls = 0;

    for (int bez = 0; bez < TOTAL_BEZIERS; bez++)
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
                unique_controls++;

                cp.data.x = float(unique_controls-1) / float(UNIQUE_CONTROLS_PER_PATH-1);
                cp.data.y = 0.0;
                cp.data.z = 0.0;
                cp.data.w = 0.0;

                set_control(bez, ctrl, cp);
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
                    // We DON'T increment the unique_controls
                    // because this is shared from the previous Bezier
                    //
                    case 0:
                        cp.position = get_control(bez-1, 3).position;
                        break;
                    //
                    // If 1, add control for tangency continuity
                    //
                    case 1:
                        ControlPoint mirror_from = get_control(bez-1, 2);
                        ControlPoint mirror_to = get_control(bez-1, 3);
                        cp.position = mirrored_control_position(mirror_from.position, mirror_to.position);
                        unique_controls++;
                        break;
                    //
                    // If 2/3, generate a new point
                    //
                    default:
                        cp.position = generate_next_attractor_point();
                        unique_controls++;
                        break;
                };

                cp.data.x = float(unique_controls-1) / float(UNIQUE_CONTROLS_PER_PATH-1);
                cp.data.y = 0.0;
                cp.data.z = 0.0;
                cp.data.w = 0.0;
                set_control(bez, ctrl, cp);
                expand_bounds(cp.position);
            }
        }
    }
}