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

//
// 3D Quadratic Polynomial Map
// x[n+1] ​​​= A ​+ B​x + C​y + D​z + E​xx + F​yy + Gzz + H​xy + I​xz + J​yz
// ... and cyclic permutations for Y and Z
//

vec4 COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[10];
void seed_3d_quadratic_polynomial_map()
{
    for (int i = 0; i < 10; i++)
    {
        COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[i] = vec4(
            next_gaussian(0.0, 0.5),
            next_gaussian(0.0, 0.5),
            next_gaussian(0.0, 0.5),
            0.0
        );
    }

    for (int i = 0; i < PREVIOUS.length(); i++)
    {
        PREVIOUS[i] = vec4(
            mix(-0.5, 0.5, next_float()),
            mix(-0.5, 0.5, next_float()),
            mix(-0.5, 0.5, next_float()),
            1.0
        );
    }
}

vec4 factory_3d_quadratic_polynomial_map()
{
    const float ax0 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].x;
    const float ay0 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].y;
    const float az0 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[0].z;

    const float ax1 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].x;
    const float ay1 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].y;
    const float az1 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[1].z;

    const float ax2 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].x;
    const float ay2 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].y;
    const float az2 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[2].z;

    const float ax3 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].x;
    const float ay3 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].y;
    const float az3 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[3].z;

    const float ax4 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].x;
    const float ay4 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].y;
    const float az4 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[4].z;

    const float ax5 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].x;
    const float ay5 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].y;
    const float az5 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[5].z;

    const float ax6 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].x;
    const float ay6 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].y;
    const float az6 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[6].z;

    const float ax7 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[7].x;
    const float ay7 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[7].y;
    const float az7 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[7].z;

    const float ax8 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[8].x;
    const float ay8 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[8].y;
    const float az8 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[8].z;

    const float ax9 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[9].x;
    const float ay9 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[9].y;
    const float az9 = COEFF_3D_QUADRATIC_POLYNOMIAL_MAP[9].z;

    float x = PREVIOUS[0].x;
    float y = PREVIOUS[0].y;
    float z = PREVIOUS[0].z;
    float nx = (ax0) + (ax1*x + ax2*y + ax3*z) + (ax4*x*x + ax5*y*y + ax6*z*z) + (ax7*x*y + ax8*x*z + ax9*y*z);
    float ny = (ay0) + (ay1*x + ay2*y + ay3*z) + (ay4*x*x + ay5*y*y + ay6*z*z) + (ay7*x*y + ay8*x*z + ay9*y*z);
    float nz = (az0) + (az1*x + az2*y + az3*z) + (az4*x*x + az5*y*y + az6*z*z) + (az7*x*y + az8*x*z + az9*y*z);

    return vec4(nx, ny, nz, 1.0);
}

//
// 2D Quadratic Polynomial Map
// x[n+1] ​= A + B​x + C​xx + D​xy + E​y + F​y2
// ... and cyclic permutations for Y and Z
//

vec4 COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[6];
void seed_2d_quadratic_polynomial_map()
{
    for (int i = 0; i < 6; i++)
    {
        COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[i] = vec4(
            next_gaussian(0.0, 0.5),
            next_gaussian(0.0, 0.5),
            next_gaussian(0.0, 0.5),
            0.0
        );
    }

    for (int i = 0; i < PREVIOUS.length(); i++)
    {
        PREVIOUS[i] = vec4(
            mix(-0.5, 0.5, next_float()),
            mix(-0.5, 0.5, next_float()),
            mix(-0.5, 0.5, next_float()),
            1.0
        );
    }
}

vec4 factory_2d_quadratic_polynomial_map()
{
    const float ax0 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[0].x;
    const float ay0 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[0].y;
    const float az0 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[0].z;

    const float ax1 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[1].x;
    const float ay1 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[1].y;
    const float az1 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[1].z;

    const float ax2 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[2].x;
    const float ay2 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[2].y;
    const float az2 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[2].z;

    const float ax3 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[3].x;
    const float ay3 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[3].y;
    const float az3 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[3].z;

    const float ax4 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[4].x;
    const float ay4 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[4].y;
    const float az4 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[4].z;

    const float ax5 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[5].x;
    const float ay5 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[5].y;
    const float az5 = COEFF_2D_QUADRATIC_POLYNOMIAL_MAP[5].z;

    float x = PREVIOUS[0].x;
    float y = PREVIOUS[0].y;

    float nx = (ax0) + (ax1*x) + (ax2*x*x) + (ax3*x*y) + (ax4*y) + (ax5*y*y);
    float ny = (ay0) + (ay1*x) + (ay2*x*x) + (ay3*x*y) + (ay4*y) + (ay5*y*y);
    float nz = (az0) + (az1*x) + (az2*x*x) + (az3*x*y) + (az4*y) + (az5*y*y);

    return vec4(nx, ny, nz, 1.0);
}

//
// Trigonometric Coupled Map
// x[n+1] ​= z​*sin(Ay) + y*​cos(Bz)
// ... and cyclic permutations for Y and Z
//

vec4 COEFF_TRIG_COUPLED_MAP[2];
void seed_trig_coupled_map()
{
    for (int i = 0; i < 2; i++)
    {
        COEFF_TRIG_COUPLED_MAP[i] = vec4(
            next_gaussian(0.0, 2.0),
            next_gaussian(0.0, 2.0),
            next_gaussian(0.0, 2.0),
            0.0
        );
    }

    for (int i = 0; i < PREVIOUS.length(); i++)
    {
        PREVIOUS[i] = vec4(
            mix(-0.5, 0.5, next_float()),
            mix(-0.5, 0.5, next_float()),
            mix(-0.5, 0.5, next_float()),
            1.0
        );
    }
}

vec4 factory_trig_coupled_map()
{
    const float ax = COEFF_TRIG_COUPLED_MAP[0].x;
    const float ay = COEFF_TRIG_COUPLED_MAP[0].y;
    const float az = COEFF_TRIG_COUPLED_MAP[0].z;

    const float bx = COEFF_TRIG_COUPLED_MAP[1].x;
    const float by = COEFF_TRIG_COUPLED_MAP[1].y;
    const float bz = COEFF_TRIG_COUPLED_MAP[1].z;

    float x = PREVIOUS[0].x;
    float y = PREVIOUS[0].y;
    float z = PREVIOUS[0].z;

    float nx = z * sin(ax * y) + y * cos(bx * z);
    float ny = x * sin(ay * z) + z * cos(by * x);
    float nz = y * sin(az * x) + x * cos(bz * y);

    return vec4(nx, ny, nz, 1.0);
}

//
// Lorenz-Style Random Attractor
//
// dx/dt = A(y - x)
// dy/dt = x(B - z) - y
// dz/dt = xy - Cz
//

vec4 COEFF_LORENZ_ATTRACTOR[3];
void seed_lorenz()
{
    float sigma = mix(8.0, 12.0, next_float());
    float rho   = mix(24.0, 32.0, next_float());
    float beta  = mix(2.0, 3.5, next_float());

    COEFF_LORENZ_ATTRACTOR[0] = vec4(sigma, 0.0, 0.0, 0.0);
    COEFF_LORENZ_ATTRACTOR[1] = vec4(rho,   0.0, 0.0, 0.0);
    COEFF_LORENZ_ATTRACTOR[2] = vec4(beta,  0.0, 0.0, 0.0);

    for (int i = 0; i < PREVIOUS.length(); i++)
    {
        PREVIOUS[i] = vec4(
            mix(-1.0, 1.0, next_float()),
            mix(-1.0, 1.0, next_float()),
            mix( 0.5, 1.5, next_float()),
            1.0
        );
    }
}

// Single Lorenz derivative evaluation
vec3 lorenz_eval_derivative(vec3 p)
{
    const float a = COEFF_LORENZ_ATTRACTOR[0].x;
    const float b = COEFF_LORENZ_ATTRACTOR[1].x;
    const float c = COEFF_LORENZ_ATTRACTOR[2].x;

    return vec3(
        a * (p.y - p.x),
        p.x * (b - p.z) - p.y,
        p.x * p.y - c * p.z
    );
}

vec4 factory_lorenz()
{
    vec3 p = PREVIOUS[0].xyz;

    // Sample coursely with accurate integration
    const float dt_eff = 0.05;
    const int iterations = 5;

    const float dt = dt_eff / iterations;
    for (int i = 0; i < iterations; i++)
    {
        vec3 k1 = lorenz_eval_derivative(p);
        vec3 k2 = lorenz_eval_derivative(p + 0.5 * dt * k1);
        vec3 k3 = lorenz_eval_derivative(p + 0.5 * dt * k2);
        vec3 k4 = lorenz_eval_derivative(p + dt * k3);

        p += (dt / 6.0) * (k1 + 2.0*k2 + 2.0*k3 + k4);
    }

    return vec4(p, 1.0);
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
 *  2: 2D Quadratic Polynomial Map
 *  3: Trigonometric Coupled Map
 *  4: Lorenz
 *  5: Sprott
 */
int ATTRACTOR_FACTORY = 0;

void bind_attractor_factory()
{
    float f = next_float();

    // x%
    if (f <= 1.0) ATTRACTOR_FACTORY = 1;
    // y%
    else if (f < 1.0) ATTRACTOR_FACTORY = 1;
    // y%
    else if (f < 1.0) ATTRACTOR_FACTORY = 1;
    // y%
    else if (f < 1.0) ATTRACTOR_FACTORY = 1;
    // y%
    else if (f < 1.0) ATTRACTOR_FACTORY = 1;
    // 
    else ATTRACTOR_FACTORY = 1;
}

void seed_attractor_factory()
{
    float f = next_float();

    // Reset the PREVIOUS buffer in case it's corrupted
    // Should be reset by the seed function anyway
    for (int i = 0; i < PREVIOUS.length(); i++)
    {
        PREVIOUS[i] = vec4(0);
    }

    switch(ATTRACTOR_FACTORY)
    {
        default:
        case 1:
            seed_3d_quadratic_polynomial_map();
            break;
        case 2:
            seed_2d_quadratic_polynomial_map();
            break;
        case 3:
            seed_trig_coupled_map();
            break;
        case 4:
            seed_lorenz();
            break;
    }
}

vec4 attractor_factory_next(bool store)
{
    vec4 p;

    switch(ATTRACTOR_FACTORY)
    {
        default:
        case 1:
            factory_3d_quadratic_polynomial_map();
            break;
        case 2:
            factory_2d_quadratic_polynomial_map();
            break;
        case 3:
            factory_trig_coupled_map();
            break;
        case 4:
            factory_lorenz();
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

    /** Lyapunov exponent to quanify chaos */
    float lyapunov = 0;
    /** Covariance tracker for estimating Eigenvalues */
    mat3 cov = mat3(0);
    vec3 mean = vec3(0);
    int n_cov = 0;

    // We check the next 10000 points to:
    // - Check the series doesn't explode to infinity
    // - Check the series doesn't tend to a point
    // - Check the series' Lyapunov exponent is positive
    const int ITERATIONS = 10000;
    for (int i = 0; i < ITERATIONS; i++)
    {
        //
        // Calculate the parallel path
        // (1) Perturb the previous points in-place
        // (2) Calculate the next point the parallel path, without shuffing the PREVIOUS buffer
        // (3) Un-perturb the previous points 
        // (4) Calculate the next point of the original path, which *will* shuffle the PREVIOUS buffer
        //
        for (int i = 0; i < PREVIOUS.length(); i++) PREVIOUS[i] += D0;
        vec4 xe = attractor_factory_next(false);
        for (int i = 0; i < PREVIOUS.length(); i++) PREVIOUS[i] -= D0;
        vec4 x = attractor_factory_next(true);

        //
        // Check for irrationalities
        //
        if (any(isnan(x)) || any(isinf(x))) return false;
        if (any(isnan(xe)) || any(isinf(xe))) return false;

        //
        // Accumulate data for eigenvlaue estimation
        //
        vec3 dMean = PREVIOUS[0].xyz - mean;
        mean += dMean / float(n_cov + 1);
        //
        cov[0][0] += dMean.x * (PREVIOUS[0].x - mean.x);
        cov[0][1] += dMean.x * (PREVIOUS[0].y - mean.y);
        cov[0][2] += dMean.x * (PREVIOUS[0].z - mean.z);
        //
        cov[1][0] += dMean.y * (PREVIOUS[0].x - mean.x);
        cov[1][1] += dMean.y * (PREVIOUS[0].y - mean.y);
        cov[1][2] += dMean.y * (PREVIOUS[0].z - mean.z);
        //
        cov[2][0] += dMean.z * (PREVIOUS[0].x - mean.x);
        cov[2][1] += dMean.z * (PREVIOUS[0].y - mean.y);
        cov[2][2] += dMean.z * (PREVIOUS[0].z - mean.z);
        //
        n_cov++;

        //
        // Calculate the Lyapunov exponent contribution from this step
        //
        float dd = distance(xe, PREVIOUS[0]);
        float d0 = length(D0);
        lyapunov += log( abs(dd/d0) ) / float(ITERATIONS);

        //
        // If the bounds explode, also unsuitable
        //
        if (PREVIOUS[0].x < -1e3 || +1e3 < PREVIOUS[0].x) return false;
        if (PREVIOUS[0].y < -1e3 || +1e3 < PREVIOUS[0].y) return false;
        if (PREVIOUS[0].z < -1e3 || +1e3 < PREVIOUS[0].z) return false;
        if (PREVIOUS[0].w < -1e3 || +1e3 < PREVIOUS[0].w) return false;

        //
        // If this tends to a point, also unsuitable
        //
        float dx = PREVIOUS[0].x - PREVIOUS[1].x;
        float dy = PREVIOUS[0].y - PREVIOUS[1].y;
        float dz = PREVIOUS[0].z - PREVIOUS[1].z;
        float dw = PREVIOUS[0].w - PREVIOUS[1].w;
        if (abs(dx) < 1e-6 && abs(dy) < 1e-6 && abs(dz) < 1e-6 && abs(dw) < 1e-6) return false;
    }

    //
    // (1) Normalise the covarariance
    // (2) Use power iteration to prepare dominant Eigenvectors
    // (3) Find 1st dominant Eigenvalue (lambda1)
    // (4) Find the trace of the covariance, which is the sum of all Eigenvalues (lambda1 + lambda2 + lambda3)
    // (5) Estimate the anisotropy of the attractor
    // (6) Reject isotropic attractors which form boring lines
    //
    cov /= float(n_cov);
    //
    vec3 v = normalize(vec3(1.0, 0.7, 0.3));
    for (int i = 0; i < 8; i++) v = normalize(cov * v);
    // 
    float lambda1 = dot(v, cov * v);
    //
    float trace_cov = cov[0][0] + cov[1][1] + cov[2][2];
    //
    float anisotropy = lambda1 / (trace_cov + 1e-6);
    //
    if (anisotropy > 0.75) return false;

    //
    // If Lyapunov exponent is small or negative, also unsuitable
    //
    if (lyapunov < 0.001) return false;

    //
    // YAY!!
    //
    return true;
}

vec4 generate_next_attractor_point()
{
    if (0 == ATTRACTOR_FACTORY)
    {
        // I don't think we need to limit this as we should always find an
        // attractor within the timeframe.
        do {
            bind_attractor_factory();
            seed_attractor_factory();
        } while(!seeded_attractor_is_suitable());
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
    mesh_bounding_box.minimum = vec4(1e10);
    mesh_bounding_box.maximum = vec4(-1e10);

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