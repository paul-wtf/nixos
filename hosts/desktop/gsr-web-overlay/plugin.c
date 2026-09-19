#include <gsr/plugin.h>
#include <GLES3/gl3.h>

#include <dlfcn.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

/* Must match feed.py. */
#define MAGIC 0x31574F47u
#define MAX_W 2048
#define MAX_H 2048
#define HEADER_SIZE 16
#define SHM_SIZE (HEADER_SIZE + (size_t)MAX_W * MAX_H * 4)

/* gpu-screen-recorder dlopens libglvnd itself and never links GL, so the
   entry points are fetched from the libraries it already has loaded. Linking
   our own libGLESv2 could pull a second libGLdispatch that has no current
   context. */
#define GL_FUNCS(X) \
    X(ActiveTexture) X(AttachShader) X(BindBuffer) X(BindTexture) \
    X(BindVertexArray) X(BlendFuncSeparate) X(BufferData) X(BufferSubData) \
    X(CompileShader) X(CreateProgram) X(CreateShader) X(DeleteBuffers) \
    X(DeleteProgram) X(DeleteShader) X(DeleteTextures) X(DeleteVertexArrays) \
    X(Disable) X(DrawArrays) X(Enable) X(EnableVertexAttribArray) \
    X(GenBuffers) X(GenTextures) X(GenVertexArrays) X(GetIntegerv) \
    X(GetUniformLocation) X(IsEnabled) X(LinkProgram) X(PixelStorei) \
    X(ShaderSource) X(TexImage2D) X(TexParameteri) X(TexSubImage2D) \
    X(Uniform1f) X(Uniform1i) X(UseProgram) X(VertexAttribPointer)

typedef struct {
#define X(name) __typeof__(gl##name) *name;
    GL_FUNCS(X)
#undef X
} gl_funcs;

typedef struct {
    gl_funcs gl;
    GLuint program, vao, vbo, texture;
    GLint u_hdr, u_sdr_nits;

    const char *shm_path;
    int hdr;
    float sdr_nits, margin, ref_height;

    const volatile uint8_t *shm;
    double next_open_attempt;
    uint32_t drawn_seq;
    unsigned int tex_w, tex_h;
    unsigned int frame_w, frame_h;
    uint8_t *pixels;
} overlay;

static const char vertex_src[] =
    "#version 300 es\n"
    "layout(location = 0) in vec4 pos_uv;\n"
    "out vec2 uv;\n"
    "void main() {\n"
    "    uv = pos_uv.zw;\n"
    "    gl_Position = vec4(pos_uv.xy, 0.0, 1.0);\n"
    "}\n";

/* HDR captures hold BT.2020 PQ. The widget is sRGB, so it is placed the way
   Hyprland places SDR windows: gamma 2.2 decode, SDR white at sdr_nits. */
static const char fragment_src[] =
    "#version 300 es\n"
    "precision highp float;\n"
    "uniform sampler2D tex;\n"
    "uniform int hdr;\n"
    "uniform float sdr_nits;\n"
    "in vec2 uv;\n"
    "out vec4 color;\n"
    "vec3 pq(vec3 nits) {\n"
    "    vec3 y = pow(clamp(nits / 10000.0, 0.0, 1.0), vec3(0.1593017578125));\n"
    "    return pow((0.8359375 + 18.8515625 * y) / (1.0 + 18.6875 * y), vec3(78.84375));\n"
    "}\n"
    "void main() {\n"
    "    vec4 c = texture(tex, uv);\n"
    "    if(hdr == 1) {\n"
    "        const mat3 bt709_to_bt2020 = mat3(0.6274, 0.0691, 0.0164,\n"
    "                                          0.3293, 0.9195, 0.0880,\n"
    "                                          0.0433, 0.0114, 0.8956);\n"
    "        c.rgb = pq(bt709_to_bt2020 * pow(c.rgb, vec3(2.2)) * sdr_nits);\n"
    "    }\n"
    "    color = c;\n"
    "}\n";

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static float env_float(const char *name, float fallback) {
    const char *v = getenv(name);
    return v && *v ? strtof(v, NULL) : fallback;
}

static bool load_gl(gl_funcs *gl, gsr_plugin_graphics_api api) {
    void *(*get_proc)(const char *) = NULL;
    void *lib;
    if(api == GSR_PLUGIN_GRAPHICS_API_EGL_ES) {
        lib = dlopen("libEGL.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if(lib)
            get_proc = (void *(*)(const char *))dlsym(lib, "eglGetProcAddress");
    } else {
        lib = dlopen("libGL.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if(lib)
            get_proc = (void *(*)(const char *))dlsym(lib, "glXGetProcAddressARB");
    }
    if(!get_proc) {
        fprintf(stderr, "gsr-web-overlay: no GL loader in process\n");
        return false;
    }
#define X(name) \
    gl->name = (__typeof__(gl->name))get_proc("gl" #name); \
    if(!gl->name) { fprintf(stderr, "gsr-web-overlay: missing gl" #name "\n"); return false; }
    GL_FUNCS(X)
#undef X
    return true;
}

static GLuint compile(gl_funcs *gl, GLenum type, const char *src) {
    GLuint shader = gl->CreateShader(type);
    gl->ShaderSource(shader, 1, &src, NULL);
    gl->CompileShader(shader);
    return shader;
}

static void try_open_shm(overlay *o) {
    const double t = now();
    if(t < o->next_open_attempt)
        return;
    o->next_open_attempt = t + 1.0;

    int fd = open(o->shm_path, O_RDONLY | O_CLOEXEC);
    if(fd < 0)
        return;
    struct stat st;
    if(fstat(fd, &st) == 0 && (size_t)st.st_size >= SHM_SIZE) {
        void *map = mmap(NULL, SHM_SIZE, PROT_READ, MAP_SHARED, fd, 0);
        if(map != MAP_FAILED)
            o->shm = map;
    }
    close(fd);
}

static uint32_t header_word(const overlay *o, int index) {
    return __atomic_load_n((const uint32_t *)(o->shm + index * 4), __ATOMIC_ACQUIRE);
}

/* Seqlock read: the feed makes seq odd while it writes and even afterwards. */
static bool fetch_frame(overlay *o) {
    const uint32_t seq = header_word(o, 1);
    if(header_word(o, 0) != MAGIC || (seq & 1) || seq == o->drawn_seq)
        return false;

    const uint32_t w = header_word(o, 2);
    const uint32_t h = header_word(o, 3);
    if(w > MAX_W || h > MAX_H)
        return false;
    memcpy(o->pixels, (const void *)(o->shm + HEADER_SIZE), (size_t)w * h * 4);

    __atomic_thread_fence(__ATOMIC_ACQUIRE);
    if(header_word(o, 1) != seq)
        return false;

    o->drawn_seq = seq;
    o->frame_w = w;
    o->frame_h = h;
    return true;
}

static void upload(overlay *o) {
    gl_funcs *gl = &o->gl;
    gl->BindTexture(GL_TEXTURE_2D, o->texture);
    gl->PixelStorei(GL_UNPACK_ALIGNMENT, 4);
    gl->PixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    if(o->frame_w != o->tex_w || o->frame_h != o->tex_h) {
        gl->TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, o->frame_w, o->frame_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, o->pixels);
        o->tex_w = o->frame_w;
        o->tex_h = o->frame_h;
    } else {
        gl->TexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, o->frame_w, o->frame_h, GL_RGBA, GL_UNSIGNED_BYTE, o->pixels);
    }
}

static void draw(const gsr_plugin_draw_params *params, void *userdata) {
    overlay *o = userdata;
    gl_funcs *gl = &o->gl;

    if(!o->shm)
        try_open_shm(o);
    if(!o->shm)
        return;

    GLint prev_program, prev_vao, prev_buffer, prev_active, prev_texture, prev_align, prev_row_length;
    GLint prev_src_rgb, prev_dst_rgb, prev_src_a, prev_dst_a;
    gl->GetIntegerv(GL_CURRENT_PROGRAM, &prev_program);
    gl->GetIntegerv(GL_VERTEX_ARRAY_BINDING, &prev_vao);
    gl->GetIntegerv(GL_ARRAY_BUFFER_BINDING, &prev_buffer);
    gl->GetIntegerv(GL_ACTIVE_TEXTURE, &prev_active);
    gl->ActiveTexture(GL_TEXTURE0);
    gl->GetIntegerv(GL_TEXTURE_BINDING_2D, &prev_texture);
    gl->GetIntegerv(GL_UNPACK_ALIGNMENT, &prev_align);
    gl->GetIntegerv(GL_UNPACK_ROW_LENGTH, &prev_row_length);
    gl->GetIntegerv(GL_BLEND_SRC_RGB, &prev_src_rgb);
    gl->GetIntegerv(GL_BLEND_DST_RGB, &prev_dst_rgb);
    gl->GetIntegerv(GL_BLEND_SRC_ALPHA, &prev_src_a);
    gl->GetIntegerv(GL_BLEND_DST_ALPHA, &prev_dst_a);
    const GLboolean prev_blend = gl->IsEnabled(GL_BLEND);

    if(fetch_frame(o) && o->frame_w && o->frame_h)
        upload(o);

    if(o->frame_w && o->frame_h && o->tex_w) {
        const float scale = params->height / o->ref_height;
        const float margin = o->margin * scale;
        const float x1 = params->width - margin;
        const float x0 = x1 - o->tex_w * scale;
        const float y1 = params->height - margin;
        const float y0 = y1 - o->tex_h * scale;

        /* The target's first row is the top of the video. */
        const float l = x0 / params->width * 2.0f - 1.0f;
        const float r = x1 / params->width * 2.0f - 1.0f;
        const float t = y0 / params->height * 2.0f - 1.0f;
        const float b = y1 / params->height * 2.0f - 1.0f;
        const GLfloat quad[] = {
            l, t, 0.0f, 0.0f,
            r, t, 1.0f, 0.0f,
            l, b, 0.0f, 1.0f,
            r, b, 1.0f, 1.0f,
        };

        gl->BindTexture(GL_TEXTURE_2D, o->texture);
        gl->UseProgram(o->program);
        gl->BindVertexArray(o->vao);
        gl->BindBuffer(GL_ARRAY_BUFFER, o->vbo);
        gl->BufferSubData(GL_ARRAY_BUFFER, 0, sizeof(quad), quad);
        gl->Enable(GL_BLEND);
        gl->BlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        gl->DrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }

    if(!prev_blend)
        gl->Disable(GL_BLEND);
    gl->BlendFuncSeparate(prev_src_rgb, prev_dst_rgb, prev_src_a, prev_dst_a);
    gl->PixelStorei(GL_UNPACK_ALIGNMENT, prev_align);
    gl->PixelStorei(GL_UNPACK_ROW_LENGTH, prev_row_length);
    gl->BindTexture(GL_TEXTURE_2D, prev_texture);
    gl->ActiveTexture(prev_active);
    gl->BindBuffer(GL_ARRAY_BUFFER, prev_buffer);
    gl->BindVertexArray(prev_vao);
    gl->UseProgram(prev_program);
}

static bool is_damaged(void *userdata) {
    overlay *o = userdata;
    if(!o->shm)
        return false;
    const uint32_t seq = header_word(o, 1);
    return !(seq & 1) && seq != o->drawn_seq;
}

static void clear_damage(void *userdata) {
    (void)userdata;
}

bool gsr_plugin_init(const gsr_plugin_init_params *params, gsr_plugin_init_return *ret) {
    overlay *o = calloc(1, sizeof(*o));
    if(!o)
        return false;
    o->pixels = malloc((size_t)MAX_W * MAX_H * 4);
    if(!o->pixels || !load_gl(&o->gl, params->graphics_api)) {
        free(o->pixels);
        free(o);
        return false;
    }
    gl_funcs *gl = &o->gl;

    o->shm_path = getenv("GSR_WEB_OVERLAY_SHM");
    if(!o->shm_path || !*o->shm_path) {
        fprintf(stderr, "gsr-web-overlay: GSR_WEB_OVERLAY_SHM is not set\n");
        free(o->pixels);
        free(o);
        return false;
    }
    const char *hdr = getenv("GSR_WEB_OVERLAY_HDR");
    o->hdr = hdr && strcmp(hdr, "1") == 0;
    o->sdr_nits = env_float("GSR_WEB_OVERLAY_SDR_NITS", 203.0f);
    o->margin = env_float("GSR_WEB_OVERLAY_MARGIN", 32.0f);
    o->ref_height = env_float("GSR_WEB_OVERLAY_REF_HEIGHT", 2160.0f);

    const GLuint vs = compile(gl, GL_VERTEX_SHADER, vertex_src);
    const GLuint fs = compile(gl, GL_FRAGMENT_SHADER, fragment_src);
    o->program = gl->CreateProgram();
    gl->AttachShader(o->program, vs);
    gl->AttachShader(o->program, fs);
    gl->LinkProgram(o->program);
    gl->DeleteShader(vs);
    gl->DeleteShader(fs);

    GLint prev_program, prev_vao, prev_buffer, prev_texture;
    gl->GetIntegerv(GL_CURRENT_PROGRAM, &prev_program);
    gl->GetIntegerv(GL_VERTEX_ARRAY_BINDING, &prev_vao);
    gl->GetIntegerv(GL_ARRAY_BUFFER_BINDING, &prev_buffer);
    gl->GetIntegerv(GL_TEXTURE_BINDING_2D, &prev_texture);

    gl->UseProgram(o->program);
    gl->Uniform1i(gl->GetUniformLocation(o->program, "tex"), 0);
    gl->Uniform1i(gl->GetUniformLocation(o->program, "hdr"), o->hdr);
    gl->Uniform1f(gl->GetUniformLocation(o->program, "sdr_nits"), o->sdr_nits);

    gl->GenVertexArrays(1, &o->vao);
    gl->BindVertexArray(o->vao);
    gl->GenBuffers(1, &o->vbo);
    gl->BindBuffer(GL_ARRAY_BUFFER, o->vbo);
    gl->BufferData(GL_ARRAY_BUFFER, 16 * sizeof(GLfloat), NULL, GL_DYNAMIC_DRAW);
    gl->EnableVertexAttribArray(0);
    gl->VertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void *)0);

    gl->GenTextures(1, &o->texture);
    gl->BindTexture(GL_TEXTURE_2D, o->texture);
    gl->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    gl->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    gl->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    gl->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    gl->BindTexture(GL_TEXTURE_2D, prev_texture);
    gl->BindBuffer(GL_ARRAY_BUFFER, prev_buffer);
    gl->BindVertexArray(prev_vao);
    gl->UseProgram(prev_program);

    o->drawn_seq = UINT32_MAX;

    ret->name = "gsr-web-overlay";
    ret->version = 1;
    ret->userdata = o;
    ret->draw = draw;
    ret->is_damaged = is_damaged;
    ret->clear_damage = clear_damage;
    return true;
}

void gsr_plugin_deinit(void *userdata) {
    overlay *o = userdata;
    gl_funcs *gl = &o->gl;
    gl->DeleteTextures(1, &o->texture);
    gl->DeleteBuffers(1, &o->vbo);
    gl->DeleteVertexArrays(1, &o->vao);
    gl->DeleteProgram(o->program);
    if(o->shm)
        munmap((void *)o->shm, SHM_SIZE);
    free(o->pixels);
    free(o);
}
