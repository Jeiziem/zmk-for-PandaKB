#include "rgb_status.h"
#include "util.h"
#include <fonts.h>
#include <zephyr/kernel.h>

#include <zmk/display.h>
#include <zmk/rgb_underglow.h>

// Free spot right of the output icon and below the profile number
// (canvas coordinates, before rotation).
#define RGB_STATUS_X 22
#define RGB_STATUS_Y 40
#define RGB_STATUS_WIDTH 10
#define RGB_STATUS_HEIGHT 9
#define RGB_STATUS_POLL_MS 1000

static void (*rgb_status_redraw_cb)(void);
static bool rgb_status_known;
static bool rgb_status_on;

static void rgb_status_poll(struct k_work *work);
static K_WORK_DELAYABLE_DEFINE(rgb_status_work, rgb_status_poll);

static void rgb_status_poll(struct k_work *work) {
    bool on = false;

    if (zmk_rgb_underglow_get_state(&on) == 0 && (!rgb_status_known || on != rgb_status_on)) {
        rgb_status_known = true;
        rgb_status_on = on;
        if (rgb_status_redraw_cb != NULL) {
            rgb_status_redraw_cb();
        }
    }

    k_work_schedule_for_queue(zmk_display_work_q(), &rgb_status_work, K_MSEC(RGB_STATUS_POLL_MS));
}

void rgb_status_init(void (*redraw_cb)(void)) {
    rgb_status_redraw_cb = redraw_cb;
    k_work_schedule_for_queue(zmk_display_work_q(), &rgb_status_work, K_NO_WAIT);
}

void draw_rgb_status(lv_obj_t *canvas) {
    bool filled = rgb_status_known && rgb_status_on;

    lv_draw_rect_dsc_t rect_dsc;
    init_rect_dsc(&rect_dsc, filled ? LVGL_FOREGROUND : LVGL_BACKGROUND);
    rect_dsc.border_color = LVGL_FOREGROUND;
    rect_dsc.border_width = 1;
    lv_canvas_draw_rect(canvas, RGB_STATUS_X, RGB_STATUS_Y, RGB_STATUS_WIDTH, RGB_STATUS_HEIGHT,
                        &rect_dsc);

    lv_draw_label_dsc_t label_dsc;
    init_label_dsc(&label_dsc, filled ? LVGL_BACKGROUND : LVGL_FOREGROUND, &pixel_operator_mono_8,
                   LV_TEXT_ALIGN_CENTER);
    lv_canvas_draw_text(canvas, RGB_STATUS_X, RGB_STATUS_Y + 1, RGB_STATUS_WIDTH, &label_dsc,
                        rgb_status_known ? "R" : "?");
}
