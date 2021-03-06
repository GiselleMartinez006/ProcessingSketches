//TODO
// soft shadows https://www.shadertoy.com/view/Xds3zN
// cheap fbm https://www.shadertoy.com/view/XslGRr
// acos(-1) = pi

precision highp float;

uniform vec2 resolution;
uniform vec3 translate;
uniform vec3 lightDirection;
uniform float diffuseMag;
uniform float specularMag;
uniform float distFOV;
uniform float rotate;
uniform float time;
uniform float shininess;

const int maxSteps = 100;
const float maxDist = 100.;
const float surfaceDist = 0.0000001;
const float normalOffset = 0.001;

#define pi 3.14159265359

struct ray{
    vec3 hit;
    bool lit;
    float hue;
    float sat;
    float distClosest;
    float distSum;
};

struct dist{
    float d;
    int maxRefractions;
    bool lit;
    float hue;
    float sat;
};

float cubicPulse(float c, float w, float x){
    x = abs(x - c);
    if (x>w) return 0.0;
    x /= w;
    return 1.0 - x*x*(3.0-2.0*x);
}

vec3 rgb(in vec3 hsb){
    vec3 rgb = clamp(abs(mod(hsb.x*6.0+
    vec3(0.0, 4.0, 2.0), 6.0)-3.0)-1.0, 0.0, 1.0);
    rgb = rgb*rgb*(3.0-2.0*rgb);
    return hsb.z * mix(vec3(1.0), rgb, hsb.y);
}

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
    return mix(d2, d1, h) - k*h*(1.0-h); }

float opSmoothSubtraction(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5*(d2+d1)/k, 0.0, 1.0);
    return mix(d2, -d1, h) + k*h*(1.0-h); }

float opSmoothIntersection(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5*(d2-d1)/k, 0.0, 1.0);
    return mix(d2, d1, h) + k*h*(1.0-h); }

float opUnion(float d1, float d2) { return min(d1, d2); }

float opSubtraction(float d1, float d2) { return max(-d1, d2); }

float opIntersection(float d1, float d2) { return max(d1, d2); }

mat2 rotate2d(float angle){
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

float value4D(vec4 P){
    //  https://github.com/BrianSharpe/Wombat/blob/master/Value4D.glsl

    // establish our grid cell and unit position
    vec4 Pi = floor(P);
    vec4 Pf = P - Pi;

    // clamp the domain
    Pi = Pi - floor(Pi * (1.0 / 69.0)) * 69.0;
    vec4 Pi_inc1 = step(Pi, vec4(69.0 - 1.5)) * (Pi + 1.0);

    // calculate the hash
    const vec4 OFFSET = vec4(16.841230, 18.774548, 16.873274, 13.664607);
    const vec4 SCALE = vec4(0.102007, 0.114473, 0.139651, 0.084550);
    Pi = (Pi * SCALE) + OFFSET;
    Pi_inc1 = (Pi_inc1 * SCALE) + OFFSET;
    Pi *= Pi;
    Pi_inc1 *= Pi_inc1;
    vec4 x0y0_x1y0_x0y1_x1y1 = vec4(Pi.x, Pi_inc1.x, Pi.x, Pi_inc1.x) * vec4(Pi.yy, Pi_inc1.yy);
    vec4 z0w0_z1w0_z0w1_z1w1 = vec4(Pi.z, Pi_inc1.z, Pi.z, Pi_inc1.z) * vec4(Pi.ww, Pi_inc1.ww) * vec4(1.0 / 56974.746094);
    vec4 z0w0_hash = fract(x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.xxxx);
    vec4 z1w0_hash = fract(x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.yyyy);
    vec4 z0w1_hash = fract(x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.zzzz);
    vec4 z1w1_hash = fract(x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.wwww);

    //	blend the results and return
    vec4 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    vec4 res0 = z0w0_hash + (z0w1_hash - z0w0_hash) * blend.wwww;
    vec4 res1 = z1w0_hash + (z1w1_hash - z1w0_hash) * blend.wwww;
    res0 = res0 + (res1 - res0) * blend.zzzz;
    blend.zw = vec2(1.0 - blend.xy);
    return dot(res0, blend.zxzx * blend.wwyy);
}

float simplex3D(vec3 p){
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl

    //  simplex math constants
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;// sqrt( 0.5 )

    //  establish our grid cell.
    p *= SIMPLEX_TETRAHADRON_HEIGHT;// scale space so we can have an approx feature size of 1.0
    vec3 Pi = floor(p + dot(p, vec3(SKEWFACTOR)));

    //  Find the vectors to the corners of our simplex tetrahedron
    vec3 x0 = p - Pi + dot(Pi, vec3(UNSKEWFACTOR));
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min(g.xyz, l.zxy);
    vec3 Pi_2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    //  pack them into a parallel-friendly arrangement
    vec4 v1234_x = vec4(x0.x, x1.x, x2.x, x3.x);
    vec4 v1234_y = vec4(x0.y, x1.y, x2.y, x3.y);
    vec4 v1234_z = vec4(x0.z, x1.z, x2.z, x3.z);

    // clamp the domain of our grid cell
    Pi.xyz = Pi.xyz - floor(Pi.xyz * (1.0 / 69.0)) * 69.0;
    vec3 Pi_inc1 = step(Pi, vec3(69.0 - 1.5)) * (Pi + 1.0);

    //	generate the random vectors
    vec4 Pt = vec4(Pi.xy, Pi_inc1.xy) + vec2(50.0, 161.0).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix(Pt.xyxy, Pt.zwzw, vec4(Pi_1.xy, Pi_2.xy));
    Pt = vec4(Pt.x, V1xy_V2xy.xz, Pt.z) * vec4(Pt.y, V1xy_V2xy.yw, Pt.w);
    const vec3 SOMELARGEFLOATS = vec3(635.298681, 682.357502, 668.926525);
    const vec3 ZINC = vec3(48.500388, 65.294118, 63.934599);
    vec3 lowz_mods = vec3(1.0 / (SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz));
    vec3 highz_mods = vec3(1.0 / (SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz));
    Pi_1 = (Pi_1.z < 0.5) ? lowz_mods : highz_mods;
    Pi_2 = (Pi_2.z < 0.5) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract(Pt * vec4(lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x)) - 0.49999;
    vec4 hash_1 = fract(Pt * vec4(lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y)) - 0.49999;
    vec4 hash_2 = fract(Pt * vec4(lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z)) - 0.49999;

    //	evaluate gradients
    vec4 grad_results = inversesqrt(hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2) * (hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z);

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    //	sum with the kernel and return
    return dot(kernel_weights, grad_results) * FINAL_NORMALIZATION;
}

float noise2D(vec2 P){
    //  https://github.com/BrianSharpe/Wombat/blob/master/Perlin2D.glsl

    // establish our grid cell and unit position
    vec2 Pi = floor(P);
    vec4 Pf_Pfmin1 = P.xyxy - vec4(Pi, Pi + 1.0);

    // calculate the hash
    vec4 Pt = vec4(Pi.xy, Pi.xy + 1.0);
    Pt = Pt - floor(Pt * (1.0 / 71.0)) * 71.0;
    Pt += vec2(26.0, 161.0).xyxy;
    Pt *= Pt;
    Pt = Pt.xzxz * Pt.yyww;
    vec4 hash_x = fract(Pt * (1.0 / 951.135664));
    vec4 hash_y = fract(Pt * (1.0 / 642.949883));

    // calculate the gradient results
    vec4 grad_x = hash_x - 0.49999;
    vec4 grad_y = hash_y - 0.49999;
    vec4 grad_results = inversesqrt(grad_x * grad_x + grad_y * grad_y) * (grad_x * Pf_Pfmin1.xzxz + grad_y * Pf_Pfmin1.yyww);

    // Classic Perlin Interpolation
    grad_results *= 1.4142135623730950488016887242097;// scale things to a strict -1.0->1.0 range  *= 1.0/sqrt(0.5)
    vec2 blend = Pf_Pfmin1.xy * Pf_Pfmin1.xy * Pf_Pfmin1.xy * (Pf_Pfmin1.xy * (Pf_Pfmin1.xy * 6.0 - 15.0) + 10.0);
    vec4 blend2 = vec4(blend, vec2(1.0 - blend));
    return dot(grad_results, blend2.zxzx * blend2.wwyy);
}

float fbm (vec4 p, int octaves, float amp, float ampMult, float freq,  float freqMult) {
    p += vec4(13);
    float value = .0;
    float amplitude = amp;
    float frequency = freq;
    for (int i = 0; i < octaves; i++) {
        float n = value4D(p*frequency);
        value += abs(amplitude * n);
        frequency *= freqMult;
        amplitude *= ampMult;
    }
    return value;
}

float fbm (vec3 p, int octaves, float amp, float ampMult, float freq,  float freqMult) {
    p += vec3(13);
    float value = .0;
    float amplitude = amp;
    float frequency = freq;
    for (int i = 0; i < octaves; i++) {
        float n = simplex3D(p*frequency);
        value += abs(amplitude * n);
        frequency *= freqMult;
        amplitude *= ampMult;
    }
    return value;
}

float fbm (vec2 p) {
    float value = .0;
    float amplitude = 1.5;
    float frequency = 0.05;
    for (int i = 0; i < 1; i++) {
        float n = noise2D(p*frequency);
        value += amplitude * n;
        frequency *= 2.5;
        amplitude *= 0.5;
    }
    return value;
}

float sdOctahedron(vec3 p, float s){
    p = abs(p);
    return (p.x+p.y+p.z-s)*0.57735027;
}

float sdSphere(vec3 p, float r){
    return length(p) - r;
}

float sdCube(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTubularCube(vec3 p, vec2 s){
    p = abs(p);
    return max(p.x - s.x, p.y - s.y);
}

float sdCappedCylinder(vec3 p, float h, float r){
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(h, r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdDoubleHelix(vec3 p){
    float r = 2.;
    float frq = 0.15;
    float w = 0.5;
    float helixA = sdTubularCube(vec3(p.x+r*sin(p.z*frq), p.y+r*cos(p.z*frq), p.z), vec2(w));
    float helixB = sdTubularCube(vec3(p.x+r*sin(pi+p.z*frq), p.y+r*cos(pi+p.z*frq), p.z), vec2(w));
    return min(helixA, helixB);
}

float sdCylinder(vec3 p, float w){
    return length(p.xy) - w;
}

vec3 repeat(vec3 p, vec3 c){
    return mod(p+0.5*c, c)-0.5*c;
}

dist getDistance(vec3 p){
    bool lit = true;
    // (vec3 p, int octaves, float amp, float ampMult, float freq,  float freqMult)
    float s = 0.05*cos((cos(p.y*p.z) + cos(p.x*p.y) + cos(p.y*p.z))*1.5+time*8);
    float d = sdSphere(p, 8)-s;
    float hue = .7+.9*s;
    float sat = .85;
    return dist(d, 0, lit, hue, sat);
}

vec3 getNormal(vec3 p){
    dist d0 = getDistance(p);
    float d = d0.d;
    vec2 offset = vec2(normalOffset, 0.);
    dist d1 = getDistance(p-offset.xyy);
    dist d2 = getDistance(p-offset.yxy);
    dist d3 = getDistance(p-offset.yyx);
    vec3 normal = d - vec3(d1.d, d2.d, d3.d);
    return normalize(normal);
}

ray raymarch(vec3 rayOrigin, vec3 dir, bool doRefract){
    float distanceTraveled = 0.;
    dist d;
    vec3 p;
    float distClosest = maxDist;
    int refractions = 0;
    for (int i = 0; i < maxSteps; i++){
        p = rayOrigin+dir*distanceTraveled;
        d = getDistance(p);
        distClosest = min(distClosest, d.d);
        if (d.d < surfaceDist && d.maxRefractions == 0){
            break;
        }
        if (d.d < surfaceDist && refractions < d.maxRefractions){
            vec3 n = getNormal(p);
            dir = refract(normalize(dir), normalize(n), 0.5);
            rayOrigin = p+dir;
            refractions++;
        }
        if (distanceTraveled > maxDist){
            break;
        }
        distanceTraveled += d.d;
    }
    return ray(p, d.lit, d.hue, d.sat, distClosest, distanceTraveled);
}

float getDiffuseLight(vec3 p, vec3 lightDir, vec3 normal, bool shadow){
    float diffuseLight = max(dot(normal, -lightDir), 0.0);
    return diffuseLight;
}

float getSpecularLight(vec3 p, vec3 lightDir, vec3 rayDirection, vec3 normal) {
    vec3 reflectionDirection = reflect(-lightDir, normal);
    float specularAngle = max(dot(reflectionDirection, rayDirection), 0.);
    return pow(specularAngle, shininess);
}

ray getShadow(vec3 p, vec3 normal, vec3 lightDir){
    vec3 shadowOrigin = vec3(p.xyz)+normal;
    vec3 shadowDirection = lightDir * -1;
    return raymarch(shadowOrigin, shadowDirection, false);
}

vec3 render(vec2 cv){
    vec3 rayOrigin = vec3(translate.xyz);
    rayOrigin.xz *= rotate2d(rotate);
    vec3 rayDirection = normalize(vec3(cv.xy, distFOV));
    rayDirection.xz *= rotate2d(rotate);
    ray r = raymarch(rayOrigin, rayDirection, true);
    vec3 normal = getNormal(r.hit);
    vec3 lightDir = normalize(lightDirection);
    lightDir.xz *= rotate2d(rotate);
    vec3 col;
    float diffuse;
    float specular;
    if(!r.lit){
        lightDir.y = lightDir.y*-1;
    }
    diffuse = getDiffuseLight(r.hit, lightDir, normal, true);
    specular  = getSpecularLight(r.hit, lightDir, rayDirection, normal);
    vec3 hsb = vec3(r.hue, r.sat, diffuse*diffuseMag + specular*specularMag);
    vec3 light =
    col = rgb(hsb);
    col = step(r.distSum, maxDist*0.99)*col;
    return col;
}

vec3 srgb(vec3 col){
    return col = pow(col,vec3(0.45));
}

vec3 aarender(vec2 cv){
    float off = (1./resolution.x)/4.;
    vec3 colA = render(cv+vec2(off, off));
    vec3 colB = render(cv+vec2(-off, off));
    vec3 colC = render(cv+vec2(off, -off));
    vec3 colD = render(cv+vec2(-off, -off));
    vec3 mixed = (colA+colB+colC+colD)/4.;
    return mixed;
}

void main(){
    vec2 cv = (gl_FragCoord.xy-.5*resolution) / resolution.y;
    gl_FragColor = vec4(srgb(render(cv)), 1.);
}