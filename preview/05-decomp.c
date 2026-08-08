/**
 * 05-decomp.c — implementation half of the C sample.
 *
 * Pairs with 05-decomp.h. Compiles clean with:
 *     cc -std=c11 -Wall -Wextra -c 05-decomp.c -o /dev/null
 */

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "05-decomp.h"

/* ── Globals ────────────────────────────────────────────────────────────── */

u32 gObjectCount = 0;
Object gObjectPool[MAX_OBJECTS];

static u32 sGeneration = 1u;
static const char *const sLevelNames[LOG_COUNT] = {
    [LOG_DEBUG] = "debug",
    [LOG_INFO]  = "info",
    [LOG_WARN]  = "warn",
    [LOG_FATAL] = "fatal",
};

/* Designated initialisers, another decomp staple. */
static const Object sTemplate = {
    .handle = { .index = -1, .generation = 0u },
    .pos    = { 0.0f, 0.0f, 0.0f },
    .vel    = { 0.0f, GRAVITY, 0.0f },
    .angle  = { 0, 0, 0 },
    .flags  = OBJ_FLAG_ACTIVE | OBJ_FLAG_VISIBLE,
    .name   = "unnamed",
    .parent = NULL,
};

/* ── Logging ────────────────────────────────────────────────────────────── */

void preview_log(enum LogLevel level, const char *fmt, ...) {
    if (level < LOG_DEBUG || level >= LOG_COUNT) {
        return;
    }

    va_list args;
    va_start(args, fmt);

    fprintf(stderr, "[%s/%-5s] ", PREVIEW_PLATFORM, sLevelNames[level]);
    vfprintf(stderr, fmt, args);
    fputc('\n', stderr);

    va_end(args);
}

/* ── Pool ───────────────────────────────────────────────────────────────── */

s32 object_pool_init(void) {
    memset(gObjectPool, 0, sizeof(gObjectPool));

    for (u32 i = 0; i < MAX_OBJECTS; i++) {
        gObjectPool[i] = sTemplate;
        gObjectPool[i].handle.index = (s32) i;
    }

    gObjectCount = 0;
    sGeneration = 1u;

    TRACE("pool initialised: %u slots, %zu bytes", MAX_OBJECTS, sizeof(gObjectPool));
    return 0;
}

Object *object_alloc(const char *name) {
    if (gObjectCount >= MAX_OBJECTS) {
        preview_log(LOG_WARN, "pool exhausted at %u/%d", gObjectCount, MAX_OBJECTS);
        return NULL;
    }

    Object *obj = &gObjectPool[gObjectCount++];
    *obj = sTemplate;
    obj->handle.index      = (s32) (gObjectCount - 1u);
    obj->handle.generation = sGeneration++;
    obj->name              = (name != NULL) ? name : "unnamed";
    obj->flags            |= OBJ_FLAG_COLLIDES;
    obj->flags            &= ~OBJ_FLAG_PERSISTED;

    return obj;
}

s32 object_each(ObjectVisitor visit, void *ctx) {
    s32 visited = 0;

    if (visit == NULL) {
        return -1;
    }

    for (u32 i = 0; i < gObjectCount; i++) {
        Object *obj = &gObjectPool[i];

        if (!(obj->flags & OBJ_FLAG_ACTIVE)) {
            continue;
        }

        s32 rc = visit(obj, ctx);
        if (rc < 0) {
            return rc;
        }
        visited++;
    }

    return visited;
}

/* ── Math ───────────────────────────────────────────────────────────────── */

f32 vec3f_length(const Vec3f v) {
    return sqrtf(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

static void vec3f_scale(Vec3f dst, const Vec3f src, f32 k) {
    dst[0] = src[0] * k;
    dst[1] = src[1] * k;
    dst[2] = src[2] * k;
}

/* ── Field formatting: switch, ternary, char literals, escapes ──────────── */

static s32 field_format(const Field *f, char *out, size_t cap) {
    if (f == NULL || out == NULL || cap == 0u) {
        return -1;
    }

    switch (f->kind) {
        case FIELD_NONE:
            return snprintf(out, cap, "empty");

        case FIELD_COUNT:
            return snprintf(out, cap, "count(%llu)",
                            (unsigned long long) f->as.count);

        case FIELD_RATIO: {
            f64 clamped = CLAMP(f->as.ratio, 0.0, 1.0);
            return snprintf(out, cap, "ratio(%.3f%s)", clamped,
                            (clamped != f->as.ratio) ? " clamped" : "");
        }

        case FIELD_TEXT:
            return snprintf(out, cap, "text(\"%s\")\t/* tab, quote, backslash \\ */",
                            f->as.text != NULL ? f->as.text : "(null)");

        default:
            return snprintf(out, cap, "unknown(%d)", (int) f->kind);
    }
}

/* ── Entry point for a standalone build ─────────────────────────────────── */

static s32 print_visitor(Object *obj, void *ctx) {
    u32 *total = (u32 *) ctx;
    char buf[64];

    Field f = { .kind = FIELD_RATIO, .as = { .ratio = (f64) vec3f_length(obj->vel) } };
    (void) field_format(&f, buf, ARRAY_COUNT(buf));

    printf("%3d %-10s flags=0x%02X %s\n",
           obj->handle.index, obj->name, obj->flags, buf);

    *total += 1u;
    return 0;
}

int main(void) {
    u32 total = 0u;
    char version[32];

    snprintf(version, ARRAY_COUNT(version), "%d.%d.%d",
             PREVIEW_VERSION_MAJOR, PREVIEW_VERSION_MINOR, PREVIEW_VERSION_PATCH);

    object_pool_init();

    for (int i = 0; i < 4; i++) {
        Object *obj = object_alloc(i % 2 == 0 ? "even" : "odd");
        if (obj == NULL) {
            break;
        }
        vec3f_scale(obj->vel, obj->vel, (f32) (i + 1));
    }

    s32 visited = object_each(print_visitor, &total);

    preview_log(LOG_INFO, "preview " STRINGIFY(PREVIEW_VERSION_MAJOR)
                          " build %s visited %d of %u", version, visited, gObjectCount);

    do {
        total--;
    } while (total > 0u);

    return (visited < 0) ? 1 : 0;
}
