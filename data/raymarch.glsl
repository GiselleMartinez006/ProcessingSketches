//TODO
// soft shadows https://www.shadertoy.com/view/Xds3zN
// cheap fbm https://www.shadertoy.com/view/XslGRr
// acos(-1) = pi

precision lowp float;

uniform vec2 resolution;
uniform vec3 translate;
uniform vec3 lightDirection;
uniform float diffuseMag;
uniform float specularMag;
uniform float distFOV;
uniform float rotate;
uniform float time;
uniform float shininess;

uniform int maxSteps = 1000;
uniform float maxDist = 1000.;
uniform float surfaceDist = .0001;

#define pi 3.14159265359

struct ray{
    vec3 hit;
    float hue;
    float sat;
    float distClosest;
    float distSum;
};

struct dist{
    float d;
    int maxRefractions;
};

float getDiffuseLight(vec3 p, vec3 lightDir, vec3 normal){
    float diffuseLight = max(dot(normal, -lightDir), 0.0);
    return diffuseLight;
}

float getSpecularLight(vec3 p, vec3 lightDir, vec3 rayDirection, vec3 normal) {
    vec3 reflectionDirection = reflect(-lightDir, normal);
    float specularAngle = max(dot(reflectionDirection, rayDirection), 0.);
    return pow(specularAngle, shininess);
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

mediump vec4 permute(in mediump vec4 x){return mod(x*x*34.+x,289.);}
mediump float snoise(in mediump vec3 v){
    const mediump vec2 C = vec2(0.16666666666,0.33333333333);
    const mediump vec4 D = vec4(0,.5,1,2);
    mediump vec3 i  = floor(C.y*(v.x+v.y+v.z) + v);
    mediump vec3 x0 = C.x*(i.x+i.y+i.z) + (v - i);
    mediump vec3 g = step(x0.yzx, x0);
    mediump vec3 l = (1. - g).zxy;
    mediump vec3 i1 = min( g, l );
    mediump vec3 i2 = max( g, l );
    mediump vec3 x1 = x0 - i1 + C.x;
    mediump vec3 x2 = x0 - i2 + C.y;
    mediump vec3 x3 = x0 - D.yyy;
    i = mod(i,289.);
    mediump vec4 p = permute( permute( permute(
    i.z + vec4(0., i1.z, i2.z, 1.))
    + i.y + vec4(0., i1.y, i2.y, 1.))
    + i.x + vec4(0., i1.x, i2.x, 1.));
    mediump vec3 ns = .142857142857 * D.wyz - D.xzx;
    mediump vec4 j = -49. * floor(p * ns.z * ns.z) + p;
    mediump vec4 x_ = floor(j * ns.z);
    mediump vec4 x = x_ * ns.x + ns.yyyy;
    mediump vec4 y = floor(j - 7. * x_ ) * ns.x + ns.yyyy;
    mediump vec4 h = 1. - abs(x) - abs(y);
    mediump vec4 b0 = vec4( x.xy, y.xy );
    mediump vec4 b1 = vec4( x.zw, y.zw );
    mediump vec4 sh = -step(h, vec4(0));
    mediump vec4 a0 = b0.xzyw + (floor(b0)*2.+ 1.).xzyw*sh.xxyy;
    mediump vec4 a1 = b1.xzyw + (floor(b1)*2.+ 1.).xzyw*sh.zzww;
    mediump vec3 p0 = vec3(a0.xy,h.x);
    mediump vec3 p1 = vec3(a0.zw,h.y);
    mediump vec3 p2 = vec3(a1.xy,h.z);
    mediump vec3 p3 = vec3(a1.zw,h.w);
    mediump vec4 norm = inversesqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    mediump vec4 m = max(.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.);
    return .5 + 12. * dot( m * m * m, vec4( dot(p0,x0), dot(p1,x1),dot(p2,x2), dot(p3,x3) ) );
}

float fbm (vec3 p) {
    float value = 0.;
    float amplitude = 1;
    float frequency = 0.1;
    for (int i = 0; i < 3; i++) {
        float n = snoise(p*frequency);
        value += amplitude * n;
        frequency *= 2.5;
        amplitude *= 0.5;
    }
    return value;
}

float octahedron(vec3 p, float s){
    p = abs(p);
    return (p.x+p.y+p.z-s)*0.57735027;
}

float sphere(vec3 p, float r){
    return length(p) - r;
}

float doubleHelix(vec3 p){
    float r = 1.;
    float frq = 0.25;
    float w = 0.6;
    float helixA = length(vec2(p.x+r*sin(p.z*frq), p.y+r*cos(p.z*frq)))-w;
    float helixB = length(vec2(p.x+r*sin(pi+p.z*frq), p.y+r*cos(pi+p.z*frq)))-w;
    return min(helixA, helixB);
}

vec3 repeat(vec3 p, vec3 c){
    return mod(p+0.5*c, c)-0.5*c;
}

dist getDistance(vec3 p){
    int refract = 0;
    float d = doubleHelix(p);
    return dist(d, refract);
}

vec3 getNormal(vec3 p){
    dist d0 = getDistance(p);
    float d = d0.d;
    vec2 offset = vec2(0.001, 0.);
    dist d1 = getDistance(p-offset.xyy);
    dist d2 = getDistance(p-offset.yxy);
    dist d3 = getDistance(p-offset.yyx);
    vec3 normal = d - vec3(d1.d, d2.d, d3.d);
    return normalize(normal);
}

ray raymarch(vec3 rayOrigin, vec3 dir){
    float distanceTraveled = 0.;
    dist d = dist(0., 0);
    vec3 p;
    float distClosest = maxDist;
    int refractions = 0;
    for (int i = 0; i < maxSteps; i++){
        p = rayOrigin+dir*distanceTraveled;
        d = getDistance(p);
        distClosest = min(distClosest, d.d);
        if(d.d < surfaceDist && refractions < d.maxRefractions){
            vec3 n = getNormal(p);
            dir = refract(normalize(dir), normalize(n), 0.8);
            rayOrigin = p+dir;
            refractions++;
        }
        if (distanceTraveled > maxDist){
            break;
        }
        distanceTraveled += d.d;
    }
    return ray(p, 0, 0, distClosest, distanceTraveled);
}

vec3 render(vec2 cv){
    vec3 rayOrigin = vec3(translate.xyz);
    rayOrigin.xz *= rotate2d(rotate);
    vec3 rayDirection = normalize(vec3(cv.xy, distFOV));
    rayDirection.xz *= rotate2d(rotate);
    ray r = raymarch(rayOrigin, rayDirection);
    vec3 normal = getNormal(r.hit);
    vec3 lightDir = normalize(lightDirection);
    lightDir.xz *= rotate2d(rotate);
    float diffuse = getDiffuseLight(r.hit, lightDir, normal);
    float specular = getSpecularLight(r.hit,lightDir,  rayDirection, normal);
    vec3 hsb = vec3(r.hue, r.sat, diffuse*diffuseMag + specular*specularMag);
    vec3 col = rgb(hsb);
    col = step(r.distSum, maxDist)*col;
    return col;
}

vec3 antiAliasRender(vec2 cv){
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
    gl_FragColor = vec4(render(cv), 1);
}