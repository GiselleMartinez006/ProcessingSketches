#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define pi 3.1415

uniform sampler2D texture;
uniform vec2 resolution;
uniform float pixelSize;

vec3 rgb(float r, float g, float b){
    vec3 c = vec3(r, g, b);
    vec3 rgb = clamp(abs(mod(c.x*6.0+vec3(0.0, 4.0, 2.0), 6.0)-3.0)-1.0, 0.0, 1.0);
    rgb = rgb*rgb*(3.0-2.0*rgb);  return c.z * mix(vec3(1.0), rgb, c.y);
}

mat2 rotate2d(float angle){
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

float mod289(float x){ return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x){ return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 perm(vec4 x){ return mod289(((x * 34.0) + 1.0) * x); }

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}


float fbm (float x, float y, float z) {
    vec3 st = vec3(x, y, z);
    float value = 0.0;
    float amplitude = 1;
    float frequency = 1;
    // Loop of octaves
    for (int i = 0; i < 4; i++) {
        float n = noise(vec3(st.x*frequency, st.y*frequency, st.z));
        value += amplitude * n;
        st.xy *= rotate2d(amplitude+frequency);
        //        st += pi;
        frequency *= 5.;
        amplitude *= .45;
    }
    return value;
}

float fbm(float x, float y){
    return fbm(x, y, 0.);
}

float fbm(float x){
    return fbm(x, 0., 0.);
}

float cubicPulse(float c, float w, float x){
    x = abs(x - c);
    if (x>w) return 0.0;
    x /= w;
    return 1.0 - x*x*(3.0-2.0*x);
}

float ease(float p, float g) {
    if (p < 0.5)
    return 0.5f * pow(2 * p, g);
    else
    return 1 - 0.5f * pow(2 * (1 - p), g);
}

vec3 cross(vec2 gv){
    float w = 1;
    float e = 0.8;
    return vec3(
    (1.-length(gv*.8)) * max(
        ease(cubicPulse(0., w, gv.x-gv.y), e),
        ease(cubicPulse(0., w, gv.x+gv.y), e)
    ));
}

void main(){
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    uv *= pixelSize;
    vec2 id = floor(uv)/pixelSize;
    vec2 gv = fract(uv)-.5;
    vec2 step = vec2(1).xy/resolution.xy;
    vec4 underlyingColor = vec4(mix(
        mix(texture(texture, vec2(id.x+step.x, id.y)), texture(texture, vec2(id.x-step.x, id.y)), .5),
        mix(texture(texture, vec2(id.x, id.y+step.y)), texture(texture, vec2(id.x, id.y-step.y)), .5), .5));
    vec4 crossColor = vec4(cross(gv), 1.);
    gl_FragColor =  vec4(
        vec3(
        step(1-crossColor.x, .5)*crossColor * underlyingColor) +
        step(crossColor.x, .5)*.7
    , 1);
}