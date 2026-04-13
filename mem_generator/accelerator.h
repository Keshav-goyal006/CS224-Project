#ifndef ACCELERATOR_H
#define ACCELERATOR_H

#include <stdint.h>

#define ACCEL_BASE_ADDR      0x00002000u
#define ACCEL_WEIGHTS_ADDR   0x00002000u
#define ACCEL_PIXELS_ADDR    0x00002080u
#define ACCEL_RESULT_ADDR    0x000020F0u

#define ACCEL_WEIGHTS_COUNT   9u
#define ACCEL_PIXELS_COUNT    9u

static volatile int32_t *const ACCEL_WEIGHTS = (volatile int32_t *)ACCEL_WEIGHTS_ADDR;
static volatile int32_t *const ACCEL_PIXELS  = (volatile int32_t *)ACCEL_PIXELS_ADDR;
static volatile int32_t *const ACCEL_RESULT   = (volatile int32_t *)ACCEL_RESULT_ADDR;

static inline void load_weights(const int32_t *w)
{
    for (uint32_t i = 0; i < ACCEL_WEIGHTS_COUNT; ++i) {
        ACCEL_WEIGHTS[i] = w[i];
    }
}

static inline void load_pixels(const uint8_t *p)
{
    for (uint32_t i = 0; i < ACCEL_PIXELS_COUNT; ++i) {
        ACCEL_PIXELS[i] = (int32_t)p[i];
    }
}

static inline uint32_t get_mac(void)
{
    return (uint32_t)(*ACCEL_RESULT);
}

#endif
