#pragma once

#include <lvgl.h>

// Starts polling the RGB underglow on/off state. ZMK raises no event when it
// changes, so the state is polled on the display work queue and redraw_cb is
// called (on that same queue) only when the state changes.
void rgb_status_init(void (*redraw_cb)(void));

// Draws the last polled RGB underglow state as a small "R" marker:
// filled box when ON, outlined box when OFF, "?" until the first read succeeds.
void draw_rgb_status(lv_obj_t *canvas);
