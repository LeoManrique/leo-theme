/**
 * 05-decomp.h — header half of the C sample.
 *
 * C is the largest single language by file count in your tree (3516 .c plus
 * 1115 .h, nearly all of it sm64coopdx-ios). It is also the only sample that
 * reaches the `preproc` capture: include guards, object- and function-like
 * macros, conditional compilation, and pragmas live here and nowhere else.
 */

#ifndef PREVIEW_DECOMP_H
#define PREVIEW_DECOMP_H

#include <stdint.h>
#include <stddef.h>

/* ── Object-like macros ─────────────────────────────────────────────────── */

#define PREVIEW_VERSION_MAJOR 1
#define PREVIEW_VERSION_MINOR 0
#define PREVIEW_VERSION_PATCH 2

#define MAX_OBJECTS   0x100
#define GRAVITY      (-4.0f)
#define DEG_TO_RAD    0.017453292519943295
#define NULL_HANDLE   ((ObjectHandle){ .index = -1, .generation = 0u })

/* ── Function-like macros, including the classic decomp idioms ──────────── */

#define ARRAY_COUNT(a)      (sizeof(a) / sizeof((a)[0]))
#define MIN(a, b)           (((a) < (b)) ? (a) : (b))
#define MAX(a, b)           (((a) > (b)) ? (a) : (b))
#define CLAMP(x, lo, hi)    MIN(MAX((x), (lo)), (hi))
#define BIT(n)              (1u << (n))
#define STRINGIFY_(x)       #x
#define STRINGIFY(x)        STRINGIFY_(x)
#define CONCAT(a, b)        a##b

#define VEC3_COPY(dst, src)      \
    do {                         \
        (dst)[0] = (src)[0];     \
        (dst)[1] = (src)[1];     \
        (dst)[2] = (src)[2];     \
    } while (0)

/* ── Conditional compilation ────────────────────────────────────────────── */

#if defined(__APPLE__) && defined(__aarch64__)
#define PREVIEW_PLATFORM "macos-arm64"
#elif defined(_WIN32)
#define PREVIEW_PLATFORM "windows"
#else
#define PREVIEW_PLATFORM "unknown"
#endif

#ifdef DEBUG
#define TRACE(fmt, ...) preview_log(LOG_DEBUG, fmt, ##__VA_ARGS__)
#else
#define TRACE(fmt, ...) ((void) 0)
#endif

#ifndef PREVIEW_INLINE
#define PREVIEW_INLINE static inline
#endif

/* ── Types ──────────────────────────────────────────────────────────────── */

typedef int8_t   s8;
typedef int16_t  s16;
typedef int32_t  s32;
typedef int64_t  s64;
typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef float    f32;
typedef double   f64;

typedef f32 Vec3f[3];
typedef s16 Vec3s[3];

enum LogLevel {
    LOG_DEBUG = 0,
    LOG_INFO,
    LOG_WARN,
    LOG_FATAL,
    LOG_COUNT
};

enum ObjectFlags {
    OBJ_FLAG_NONE      = 0,
    OBJ_FLAG_ACTIVE    = BIT(0),
    OBJ_FLAG_VISIBLE   = BIT(1),
    OBJ_FLAG_COLLIDES  = BIT(2),
    OBJ_FLAG_PERSISTED = BIT(7),
    OBJ_FLAG_ALL       = 0xFFu
};

typedef struct ObjectHandle {
    s32 index;
    u32 generation;
} ObjectHandle;

typedef struct Object {
    ObjectHandle handle;
    Vec3f        pos;
    Vec3f        vel;
    Vec3s        angle;
    u32          flags;
    const char  *name;
    struct Object *parent;
} Object;

/* A tagged union — the other struct shape worth colouring. */
typedef struct Field {
    enum { FIELD_NONE, FIELD_COUNT, FIELD_RATIO, FIELD_TEXT } kind;
    union {
        u64         count;
        f64         ratio;
        const char *text;
    } as;
} Field;

/* Function pointer typedef. */
typedef s32 (*ObjectVisitor)(Object *obj, void *ctx);

/* ── API ────────────────────────────────────────────────────────────────── */

extern u32 gObjectCount;
extern Object gObjectPool[MAX_OBJECTS];

void  preview_log(enum LogLevel level, const char *fmt, ...);
s32   object_pool_init(void);
Object *object_alloc(const char *name);
s32   object_each(ObjectVisitor visit, void *ctx);
f32   vec3f_length(const Vec3f v);

PREVIEW_INLINE s32 handle_is_null(ObjectHandle h) {
    return h.index < 0;
}

#endif /* PREVIEW_DECOMP_H */
