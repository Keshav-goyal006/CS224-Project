#include <stdint.h>

#include "accelerator.h"

extern const uint8_t image_data[19200];

static volatile uint8_t *const vram = (volatile uint8_t *)0x00005000u;
static volatile uint32_t *const switches = (volatile uint32_t *)0x00003100u;

static const int32_t edge_kernel[9] = {
    -1, -1, -1,
    -1,  8, -1,
    -1, -1, -1
};

static const int32_t blur_kernel[9] = {
    1, 2, 1,
    2, 4, 2,
    1, 2, 1
};

static const int32_t emboss_kernel[9] = {
    -2, -1, 0,
    -1,  1, 1,
     0,  1, 2
};

enum {
    FILTER_EDGE = 0,
    FILTER_BLUR = 1,
    FILTER_EMBOSS = 2
};

int main(void)
{
    uint32_t current_filter = FILTER_EDGE;
    uint32_t scale_shift = 0u;
    int32_t bias = 0;

    load_weights(edge_kernel);

    while (1) {
        uint32_t switch_bits = (*switches) & 0x7u;
        uint32_t selected_filter = current_filter;

        if ((switch_bits & 0x1u) != 0u) {
            selected_filter = FILTER_EDGE;
        } else if ((switch_bits & 0x2u) != 0u) {
            selected_filter = FILTER_BLUR;
        } else if ((switch_bits & 0x4u) != 0u) {
            selected_filter = FILTER_EMBOSS;
        }

        if (selected_filter != current_filter) {
            current_filter = selected_filter;

            if (current_filter == FILTER_EDGE) {
                load_weights(edge_kernel);
                scale_shift = 0u;
                bias = 0;
            } else if (current_filter == FILTER_BLUR) {
                load_weights(blur_kernel);
                scale_shift = 4u;
                bias = 0;
            } else {
                load_weights(emboss_kernel);
                scale_shift = 0u;
                bias = 128;
            }
        }

        for (uint32_t y = 0; y < 120u; ++y) {
            uint32_t row_base = y * 160u;

            for (uint32_t x = 0; x < 160u; ++x) {
                uint8_t window[9];
                uint32_t idx = 0;

                for (int32_t ky = -1; ky <= 1; ++ky) {
                    int32_t py = (int32_t)y + ky;

                    for (int32_t kx = -1; kx <= 1; ++kx) {
                        int32_t px = (int32_t)x + kx;

                        if ((py < 0) || (py >= 120) || (px < 0) || (px >= 160)) {
                            window[idx++] = 0u;
                        } else {
                            uint32_t src_index = (uint32_t)py * 160u + (uint32_t)px;
                            window[idx++] = image_data[src_index];
                        }
                    }
                }

                load_pixels(window);

                {
                    int32_t mac = (int32_t)get_mac();
                    int32_t adjusted;
                    uint8_t out_px;

                    if (scale_shift != 0u) {
                        mac = mac >> scale_shift;
                    }
                    adjusted = mac + bias;

                    if (adjusted < 0) {
                        out_px = 0u;
                    } else if (adjusted > 255) {
                        out_px = 255u;
                    } else {
                        out_px = (uint8_t)adjusted;
                    }

                    vram[row_base + x] = out_px;
                }
            }
        }
    }
}
