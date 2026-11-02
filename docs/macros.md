# Macros in ZMK: a beginner's manual for this Corne

A macro is one key that plays back a recorded list of actions: type a word, press a shortcut, switch a layer, change a Bluetooth profile, or any combination. This guide shows how to write macros in `config/Corne.keymap`, bind them to a key, build the firmware, and flash it.

It targets this repository: a Corne split keyboard with nice!nano v2 controllers, running ZMK v0.3. Every property and behavior name here was checked against the ZMK v0.3 sources in `.zmk/zmk/` (mainly `app/dts/behaviors/macros.dtsi` and `docs/docs/keymaps/behaviors/macros.md`).

## Quick path

If you only want one working macro, do this:

1. Open `config/Corne.keymap` and add a node inside the existing `macros { }` block:

   ```dts
                   hello: hello {
                           compatible = "zmk,behavior-macro";
                           #binding-cells = <0>;
                           wait-ms = <40>;
                           tap-ms = <40>;
                           bindings = <&kp H &kp E &kp L &kp L &kp O>;
                   };
   ```

2. Replace one `&trans` in a layer with `&hello` (see [Bind the macro to a key](#bind-the-macro-to-a-key)).
3. Build the left half: `scripts/build.sh Corne_left_oled`.
4. Flash `firmware/Corne_left_oled.uf2` to the **left** half only.
5. Press the key. The computer types `hello`.

The rest of this document explains each step and builds up to more advanced macros.

## Contents

1. [Key ideas before you start](#key-ideas-before-you-start)
2. [Where macros live in the keymap](#where-macros-live-in-the-keymap)
3. [Anatomy of a macro node](#anatomy-of-a-macro-node)
4. [Activation modes: tap, press, release](#activation-modes-tap-press-release)
5. [Timing: wait-ms and tap-ms](#timing-wait-ms-and-tap-ms)
6. [Recipes](#recipes)
7. [Parameterized macros](#parameterized-macros)
8. [Bind the macro to a key](#bind-the-macro-to-a-key)
9. [Build and flash](#build-and-flash)
10. [ZMK Studio and macros](#zmk-studio-and-macros)
11. [Troubleshooting](#troubleshooting)
12. [Limits in ZMK v0.3](#limits-in-zmk-v03)
13. [Cheat sheet](#cheat-sheet)

## Key ideas before you start

| Idea | What it means for you |
|------|-----------------------|
| A macro is a behavior | Like `&kp` or `&mo`, a macro is a behavior you place on a key. You define it once and reference it as `&name`. |
| A macro is a list of other behaviors | Anything you can put on a key (`&kp`, `&mo`, `&tog`, `&to`, `&bt`, `&rgb_ug`, ...) can go in a macro's list. |
| Macros send key positions, not characters | ZMK sends HID keycodes ("the key at this position was pressed"). The computer's keyboard layout setting decides which character appears. |
| Macros run on the left half | The left half is the central. It holds the keymap and talks to the computer, so only the left half needs new firmware when you change a macro. |
| Simple shortcuts do not need a macro | `&kp LC(LS(T))` already sends Ctrl+Shift+T in one key. Use a macro when you need a sequence of several steps. |

### The OS layout gotcha (important for this keyboard)

This keymap has two base layers because the computer may be set to the **US** layout or the **Latin American (latam)** layout. A macro does not know which one is active. It only says "press the key at this position".

Example: the key named `SQT` (single quote) in ZMK is the key to the right of `;` on a US board.

| Macro step | OS layout US | OS layout latam |
|------------|--------------|-----------------|
| `&kp SQT` | `'` | `{` |
| `&kp LBRC` | `{` | not `{` (the latam key at that position is a dead accent) |
| `&kp AT` | `@` | `"` |
| `&kp RA(N2)` | nothing useful | `@` |

So a macro that types text must be written for the OS layout you use when you press it. This repository already follows that rule: the `RAISE` layer uses US codes and the `RAISE LA` layer uses latam codes.

Latam mappings you will need most often:

| Character (latam OS) | ZMK binding |
|----------------------|-------------|
| `{` | `&kp SQT` |
| `}` | `&kp BSLH` |
| `[` | `&kp LS(SQT)` |
| `]` | `&kp LS(BSLH)` |
| `@` | `&kp RA(N2)` |
| `ñ` | `&kp SEMI` |
| dead acute (´) | `&kp LBKT` |
| `"` | `&kp LS(N2)` |
| `/` | `&kp LS(N7)` |
| `-` | `&kp FSLH` |
| `_` | `&kp LS(FSLH)` |
| `=` | `&kp LS(N0)` |

`LS()` means "with Left Shift", `RA()` means "with Right Alt (AltGr)", `LC()` means "with Left Ctrl".

## Where macros live in the keymap

Macros are defined in a `macros { }` node inside the root `/ { }` node of `config/Corne.keymap`. This file already has one, with two macros:

```dts
/ {
        behaviors {
                // shift_caps and lower_lock live here
        };

        // Latam has no plain ^ or ` key, only dead keys: tap them followed by space.
        macros {
                la_caret: la_caret {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        bindings = <&kp RA(SQT) &kp SPACE>;
                };
                la_grave: la_grave {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        bindings = <&kp RA(BSLH) &kp SPACE>;
                };
        };

        keymap {
                // layers use &la_caret and &la_grave
        };
};
```

Rules:

- Add new macros **inside** the existing `macros { }` block. Do not create a second one.
- Keep `macros { }` **before** `keymap { }`, as it is now, so the names are defined before the layers use them.
- The `#define` lines at the top (`BASE_US 0`, `BASE_LA 1`, `LOWER 2`, `RAISE_US 3`, `RAISE_LA 4`) can be used inside macros, for example `&to BASE_US`.
- The file already includes `behaviors.dtsi`, `keys.h`, `bt.h`, and `rgb.h`. That is everything the examples below need. The macro controls (`&macro_tap` and the rest) come from `behaviors.dtsi`, so you do not include anything extra.

## Anatomy of a macro node

```dts
                la_caret: la_caret {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        bindings = <&kp RA(SQT) &kp SPACE>;
                };
```

| Part | Required | Meaning |
|------|----------|---------|
| `la_caret:` (before the colon) | Yes | The **label**. You use it in layers as `&la_caret`. Must be unique in the whole file, and must not clash with built-in names such as `kp`, `mo`, `to`. Use lowercase letters, digits, and `_`. |
| `la_caret` (after the colon) | Yes | The **node name**. Use the same text as the label; that is the ZMK convention. |
| `compatible` | Yes | `"zmk,behavior-macro"` for a normal macro. Parameterized macros use other values (see below). |
| `#binding-cells` | Yes | How many values the macro takes when placed on a key. `<0>` for a normal macro. |
| `bindings` | Yes | The ordered list of behaviors to run. |
| `wait-ms` | No | Delay in milliseconds between steps. Default 15 (`CONFIG_ZMK_MACRO_DEFAULT_WAIT_MS`). |
| `tap-ms` | No | How long each tapped key is held down, in milliseconds. Default 30 (`CONFIG_ZMK_MACRO_DEFAULT_TAP_MS`). |
| `display-name` | No | Friendly name shown in ZMK Studio, for example `display-name = "Hello";`. |

### Two ways to write `bindings`

Both forms below are identical. Use whichever is easier to read.

```dts
// One group: fine for short lists
bindings = <&kp H &kp E &kp L &kp L &kp O>;

// Several groups: one step or idea per line, separated by commas
bindings
        = <&kp H &kp E>
        , <&kp L &kp L &kp O>
        ;
```

Syntax rules that cause most build errors:

- Every property line ends with `;`.
- The macro node itself ends with `};`.
- Each group is wrapped in `< >`. Groups are separated by `,`.
- Numbers are written in angle brackets: `wait-ms = <40>;`, not `wait-ms = 40;`.

## Activation modes: tap, press, release

Each step in `bindings` is run in the current **mode**. You switch modes with a macro control placed anywhere in the list.

| Control | Mode | What happens to each following behavior |
|---------|------|------------------------------------------|
| `&macro_tap` | Tap (default) | Press, then release. Normal typing. |
| `&macro_press` | Press | Press only. Use it to hold a modifier down. |
| `&macro_release` | Release | Release only. Use it to let go of what you pressed earlier. |

The mode stays in effect until the next mode control. Every macro starts in tap mode.

Pattern for "hold a modifier while tapping keys":

```dts
bindings
        = <&macro_press &kp LCTRL &kp LSHFT>
        , <&macro_tap &kp T>
        , <&macro_release &kp LCTRL &kp LSHFT>
        ;
```

Always release what you press. If you forget the `&macro_release` step, the computer thinks Ctrl and Shift are still held down.

## Timing: wait-ms and tap-ms

Timing matters most when the keyboard is connected over Bluetooth. If steps are sent too fast, the computer may group them and drop or reorder characters. The ZMK docs recommend at least 30 ms for both values when typing text.

| Setting | Where | Effect |
|---------|-------|--------|
| `wait-ms = <N>;` | Macro property | Default pause between steps for this macro. |
| `tap-ms = <N>;` | Macro property | Default hold time of each tap for this macro. |
| `&macro_wait_time N` | Inside `bindings` | Changes the wait time from that point on. |
| `&macro_tap_time N` | Inside `bindings` | Changes the tap time from that point on. |

Example of a per-step override: type "fast" quickly, wait half a second between the remaining steps, then type "slow".

```dts
                fast_slow: fast_slow {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <30>;
                        tap-ms = <30>;
                        bindings
                                = <&kp F &kp A &kp S &kp T>
                                , <&macro_wait_time 500>
                                , <&kp S &kp L &kp O &kp W>
                                ;
                };
```

A per-step override is useful when the computer needs time to react, for example after opening a launcher before you type into it.

## Recipes

Each recipe is a complete node. Paste it inside the existing `macros { }` block, keeping the 8-space indentation style of the file.

### 1. Hold modifiers across steps: Ctrl+Shift+T

Reopens the last closed browser tab. This works the same on US and latam because it only uses letters and modifiers.

```dts
                reopen_tab: reopen_tab {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        bindings
                                = <&macro_press &kp LCTRL &kp LSHFT>
                                , <&macro_tap &kp T>
                                , <&macro_release &kp LCTRL &kp LSHFT>
                                ;
                };
```

Note: for a single shortcut, `&kp LC(LS(T))` does the same with no macro. The macro form becomes useful when you add more steps, such as tapping several keys while the modifiers stay held.

### 2. Type a word: "hello"

```dts
                hello: hello {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <40>;
                        tap-ms = <40>;
                        bindings = <&kp H &kp E &kp L &kp L &kp O>;
                };
```

Letters are in the same position on US and latam, so this works on both.

Capital letters: use `&kp LS(H)` for `H`. Turn Caps Lock off before testing: with Caps Lock on, `&kp H` types `H`, and on Windows and Linux `&kp LS(H)` types `h`.

### 3. Type an email-like string: two versions

The `@` key differs between layouts, so write one macro per layout. The dot (`DOT`) is in the same place on both.

US OS layout, types `me@example.com`:

```dts
                email_us: email_us {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <40>;
                        tap-ms = <40>;
                        bindings
                                = <&kp M &kp E>
                                , <&kp AT>
                                , <&kp E &kp X &kp A &kp M &kp P &kp L &kp E>
                                , <&kp DOT &kp C &kp O &kp M>
                                ;
                };
```

Latam OS layout, types `me@example.com`:

```dts
                email_la: email_la {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <40>;
                        tap-ms = <40>;
                        bindings
                                = <&kp M &kp E>
                                , <&kp RA(N2)>
                                , <&kp E &kp X &kp A &kp M &kp P &kp L &kp E>
                                , <&kp DOT &kp C &kp O &kp M>
                                ;
                };
```

Bind `&email_us` on the `RAISE` layer and `&email_la` on the `RAISE LA` layer, so each one is only reachable while the matching base layer is active. If you press `&email_us` while the computer is set to latam, you get `me"example.com`.

Typing symbols on latam: use the latam mapping table above. For example, `{}` on latam is `&kp SQT &kp BSLH`, not `&kp LBRC &kp RBRC`.

### 4. Switch Bluetooth profile and layer

Selects Bluetooth profile 1 (the first one, index 0) and returns to the US base layer.

```dts
                home_pc: home_pc {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        bindings
                                = <&bt BT_SEL 0>
                                , <&to BASE_US>
                                ;
                };
```

| Step | Behavior | Effect |
|------|----------|--------|
| `&bt BT_SEL 0` | Bluetooth | Connects to profile 0. Profiles are numbered from 0, so `BT_SEL 0` is the key labeled BT1 on the lower layer. |
| `&to BASE_US` | Layer | Turns on layer `BASE_US` and turns off every other layer except the default layer (which is `BASE_US` itself here). |

A latam variant would use `&to BASE_LA` instead, so the keyboard lands on the latam base layer after switching to a computer set to latam.

### 5. Hold behavior with pause-for-release: Alt+Tab switcher

`&macro_pause_for_release` splits a macro in two. Steps before it run when you press the key. Steps after it run when you release the key.

This macro holds Alt and taps Tab when pressed, which opens the window switcher with the next window selected. Alt stays held while you hold the key. Releasing the key releases Alt, which switches to the selected window.

```dts
                alt_tab: alt_tab {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <0>;
                        tap-ms = <30>;
                        bindings
                                = <&macro_press &kp LALT>
                                , <&macro_tap &kp TAB>
                                , <&macro_pause_for_release>
                                , <&macro_release &kp LALT>
                                ;
                };
```

The same pattern combines a layer with a modifier. This macro holds Shift and activates the lower layer while the key is held:

```dts
                shift_lower: shift_lower {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <0>;
                        tap-ms = <0>;
                        bindings
                                = <&macro_press &mo LOWER &kp LSHFT>
                                , <&macro_pause_for_release>
                                , <&macro_release &mo LOWER &kp LSHFT>
                                ;
                };
```

`wait-ms = <0>` makes the hold feel instant. The ZMK docs use 0 ms for this layer pattern.

## Parameterized macros

A parameterized macro takes values when you place it on a key, like `&kp` takes a keycode. You write the macro once and reuse it with different keys.

### Pick the right header

| Parameters | `compatible` | `#binding-cells` | Use in a layer |
|------------|--------------|------------------|----------------|
| 0 | `"zmk,behavior-macro"` | `<0>` | `&my_macro` |
| 1 | `"zmk,behavior-macro-one-param"` | `<1>` | `&my_macro A` |
| 2 | `"zmk,behavior-macro-two-param"` | `<2>` | `&my_macro A B` |

The `compatible` value and `#binding-cells` must match. A mismatch is a build error. Two parameters is the maximum.

### Forward a parameter with `&macro_param_*`

Inside the list, a parameter control tells ZMK where to put the value you passed. It applies only to the **next** non-control behavior in the list ("one shot").

| Control | Copies | Into |
|---------|--------|------|
| `&macro_param_1to1` | first macro parameter | first parameter of the next behavior |
| `&macro_param_1to2` | first macro parameter | second parameter of the next behavior |
| `&macro_param_2to1` | second macro parameter | first parameter of the next behavior |
| `&macro_param_2to2` | second macro parameter | second parameter of the next behavior |

The target behavior still needs a value written in its slot, because `&kp` always expects one. That value is replaced at run time. Use `MACRO_PLACEHOLDER` (an alias for `0`, defined in `macros.dtsi`) to make that clear.

### One parameter: Ctrl+Shift+any key

```dts
                ctrl_shift: ctrl_shift {
                        compatible = "zmk,behavior-macro-one-param";
                        #binding-cells = <1>;
                        bindings
                                = <&macro_press &kp LCTRL &kp LSHFT>
                                , <&macro_param_1to1>
                                , <&macro_tap &kp MACRO_PLACEHOLDER>
                                , <&macro_release &kp LCTRL &kp LSHFT>
                                ;
                };
```

Use it as `&ctrl_shift T` (reopen tab), `&ctrl_shift ESC` (task manager on Windows), and so on.

### Two parameters: layer plus modifier

This is the `lm` example from the ZMK docs. It activates a layer (first parameter) and holds a modifier (second parameter) while the key is held.

```dts
                lm: lm {
                        compatible = "zmk,behavior-macro-two-param";
                        #binding-cells = <2>;
                        wait-ms = <0>;
                        tap-ms = <0>;
                        bindings
                                = <&macro_param_1to1>
                                , <&macro_press &mo MACRO_PLACEHOLDER>
                                , <&macro_param_2to1>
                                , <&macro_press &kp MACRO_PLACEHOLDER>
                                , <&macro_pause_for_release>
                                , <&macro_param_2to1>
                                , <&macro_release &kp MACRO_PLACEHOLDER>
                                , <&macro_param_1to1>
                                , <&macro_release &mo MACRO_PLACEHOLDER>
                                ;
                };
```

Use it as `&lm LOWER LSHFT`. Note that each `&macro_param_*` is repeated before every behavior that needs the value, because the control is used up by the next behavior.

## Bind the macro to a key

A layer's `bindings` is a grid of 42 entries, one per key: three rows of 12, then six thumb keys. Replace an existing `&trans` (transparent, "use the key from the layer below") with your macro. Keep the number of entries the same.

Free slots in this keymap:

| Layer | Free slots (`&trans`) | Best for |
|-------|------------------------|----------|
| `raise_layer` (RAISE, US) | Left half, rows 2 and 3, columns 2 to 6 (10 keys) | US-only text macros and layout-independent macros |
| `lower_layer` (LOWER, shared) | Row 2, column 11 (left of `&tog BASE_LA`) | Layout-independent macros, reachable from both base layers |
| `raise_latam_layer` (RAISE LA) | None outside the thumb keys | To add a latam macro here, replace an existing symbol you do not use |

Do not replace the `&trans` thumb keys in `lower_layer` and `raise_layer`. They sit under the keys you are holding to reach the layer.

### Example 1: `&reopen_tab` on RAISE, under the A position

Before (line 117 of `config/Corne.keymap`):

```dts
   &kp LCTRL &trans   &trans &trans   &trans   &trans      &kp MINUS &kp EQUAL &kp LBKT        &kp RBKT &kp BSLH &kp GRAVE
```

After:

```dts
   &kp LCTRL &reopen_tab &trans &trans   &trans   &trans      &kp MINUS &kp EQUAL &kp LBKT        &kp RBKT &kp BSLH &kp GRAVE
```

Result: hold Raise (right inner thumb) and press the A key to send Ctrl+Shift+T. Spacing between entries does not matter to the build; it only helps readability.

### Example 2: `&home_pc` on LOWER, reachable from both base layers

Before (line 101):

```dts
   &bt BT_CLR &bt BT_SEL 0    &bt BT_SEL 1    &bt BT_SEL 2    &bt BT_SEL 3    &bt BT_SEL 4      &kp LEFT        &kp DOWN        &kp UP          &kp RIGHT       &trans          &tog BASE_LA
```

After:

```dts
   &bt BT_CLR &bt BT_SEL 0    &bt BT_SEL 1    &bt BT_SEL 2    &bt BT_SEL 3    &bt BT_SEL 4      &kp LEFT        &kp DOWN        &kp UP          &kp RIGHT       &home_pc        &tog BASE_LA
```

Result: hold Lower and press the `;` key position.

Also update the ASCII diagram comment above the layer, so the drawing matches the bindings. The comment does not affect the firmware, but it is your map later.

## Build and flash

The keymap and all macros run on the **left half** (the central). The right half only reports key presses, so it does not need new firmware for a macro change.

1. Build the left half:

   ```bash
   scripts/build.sh Corne_left_oled
   ```

   This runs the ZMK build in Docker, the same way as the GitHub Actions workflow. The output is `firmware/Corne_left_oled.uf2`.

2. Connect the **left** half by USB.
3. Double-press its reset button quickly. A USB drive (usually named `NICENANO`) appears.
4. Copy `firmware/Corne_left_oled.uf2` to that drive. The board reboots by itself when the copy finishes.
5. Test the key in a text editor.

| Situation | What to build |
|-----------|---------------|
| Changed a macro or layer | `Corne_left_oled` only |
| Changed `config/west.yml` (modules) | Run `scripts/build.sh --update Corne_left_oled` |
| Not sure of the target names | `scripts/build.sh --list` |
| Using the dongle setup | The dongle is the central and reads `config/Corne_dongle.keymap`. Add the macro there and build `Corne_central_dongle_eyeslash` instead. |

## ZMK Studio and macros

This firmware has ZMK Studio enabled (`CONFIG_ZMK_STUDIO=y` in `config/Corne.conf`, and the `studio-rpc-usb-uart` snippet on the left half in `build.yaml`).

| Task | Studio in ZMK v0.3 |
|------|--------------------|
| Assign an existing macro (defined in the keymap file) to a key | Supported. Macros appear as user-defined behaviors. Add `display-name` to give them a readable name. |
| Create a new macro | Not supported. Define it in `config/Corne.keymap`. |
| Edit a macro's steps or timing | Not supported (listed as planned). Edit the keymap file. |

Important: once you save keymap changes from Studio, the keyboard uses the Studio-saved keymap and **ignores later changes to the `.keymap` file**. If you flash a new macro and your key change does not show up:

1. Open ZMK Studio and connect to the keyboard.
2. Run **Restore Stock Settings**.
3. The keyboard now uses the keymap from the flashed firmware, including your macro.

Restoring discards anything you changed in Studio. Either manage the keymap in Studio or in the file, not both.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Characters missing or out of order | Steps sent too fast, often over Bluetooth | Raise `wait-ms` and `tap-ms` to 40 or 50. |
| Wrong symbols (`"` instead of `@`, accents instead of `{`) | Macro written for a different OS layout | Check the computer's layout setting. Use US codes on RAISE and latam codes on RAISE LA. |
| Uppercase when you expected lowercase | Caps Lock is on | Tap the bottom-left Shift/Caps key once to turn Caps Lock off. |
| Ctrl, Shift, or Alt stays "stuck" after the macro | A `&macro_press` without a matching `&macro_release` | Release every key you pressed, in the same macro. Tap the stuck modifier to clear it. |
| Long macro stops partway | Behavior queue is full (64 events by default; each tap uses 2) | Add `CONFIG_ZMK_BEHAVIORS_QUEUE_SIZE=512` to `config/Corne.conf`. |
| Key does nothing new after flashing | Flashed the wrong half, or Studio settings override the file | Flash the left half. Run **Restore Stock Settings** in Studio. |
| Key does nothing at all | The layer is not active, or the entry count in the layer changed | Confirm you are holding the right layer key. Count the entries in the row. |

### Common build errors

The build prints a devicetree error with a line number. Check these first:

| Mistake | Example of the error cause | Correct form |
|---------|----------------------------|--------------|
| Missing `;` after a property or `}` | `bindings = <&kp A>` | `bindings = <&kp A>;` |
| Missing `#binding-cells` | Node has no `#binding-cells` line | `#binding-cells = <0>;` |
| `compatible` and `#binding-cells` do not match | `"zmk,behavior-macro"` with `<1>` | `"zmk,behavior-macro-one-param"` with `<1>` |
| Duplicate label | Two nodes named `hello:` | Give each macro a unique label. |
| Label clashes with a built-in | A macro labeled `kp:` or `mo:` | Pick a descriptive name like `email_us`. |
| Using a macro before it is defined | Macro defined after `keymap { }` | Keep `macros { }` above `keymap { }`. |
| Typo in a key name | `&kp SHIFT` | Use names from the ZMK keycode list, for example `LSHFT`. |
| Number without brackets | `wait-ms = 40;` | `wait-ms = <40>;` |
| Parameterized macro used without values | `&ctrl_shift` alone | `&ctrl_shift T` |

## Limits in ZMK v0.3

| Limit | Detail |
|-------|--------|
| Maximum parameters | Two (`zmk,behavior-macro-two-param`). |
| Queue size | 64 events by default (`CONFIG_ZMK_BEHAVIORS_QUEUE_SIZE`). A tapped key uses 2 events; a press or release uses 1. |
| Bindings per list | Devicetree allows at most 256 bindings in one `bindings` property. |
| No text or Unicode type-out | There is no "type this string" helper. Each character is a `&kp` step, and it depends on the OS layout. |
| Studio | Can assign macros to keys, cannot create or edit them. |
| `ZMK_MACRO()` helper | Available in v0.3 as a shortcut for zero-parameter macros (see below). The v0.3 docs say parameterized versions are not supported. The v0.3 source also defines `ZMK_MACRO1` and `ZMK_MACRO2`, but they are undocumented, so prefer the full node form for parameterized macros. |

### Optional: the `ZMK_MACRO()` shortcut

For zero-parameter macros, this short form produces the same node as the full form. It fills in `compatible` and `#binding-cells` for you. Write it directly inside `macros { }`:

```dts
                ZMK_MACRO(hello2,
                        wait-ms = <40>;
                        tap-ms = <40>;
                        bindings = <&kp H &kp E &kp L &kp L &kp O>;
                )
```

Note: there is no `;` after the closing `)`. This guide uses the full form everywhere because it matches the existing macros in this file and is easier to debug.

## Cheat sheet

### Template

```dts
                my_macro: my_macro {
                        compatible = "zmk,behavior-macro";
                        #binding-cells = <0>;
                        wait-ms = <40>;
                        tap-ms = <40>;
                        bindings
                                = <&macro_press &kp LSHFT>
                                , <&macro_tap &kp A>
                                , <&macro_release &kp LSHFT>
                                ;
                };
```

### Controls

| Control | Parameters | Purpose |
|---------|------------|---------|
| `&macro_tap` | none | Following steps: press and release (default). |
| `&macro_press` | none | Following steps: press only. |
| `&macro_release` | none | Following steps: release only. |
| `&macro_pause_for_release` | none | Stop here until the key is released, then continue. |
| `&macro_wait_time N` | ms | Change the delay between steps from here on. |
| `&macro_tap_time N` | ms | Change the tap hold time from here on. |
| `&macro_param_1to1` | none | Macro param 1 into next behavior's param 1. |
| `&macro_param_1to2` | none | Macro param 1 into next behavior's param 2. |
| `&macro_param_2to1` | none | Macro param 2 into next behavior's param 1. |
| `&macro_param_2to2` | none | Macro param 2 into next behavior's param 2. |
| `MACRO_PLACEHOLDER` | n/a | Alias for `0`; marks a value that a param control replaces. |

### Properties

| Property | Default | Notes |
|----------|---------|-------|
| `compatible` | required | `zmk,behavior-macro`, `-one-param`, or `-two-param`. |
| `#binding-cells` | required | `<0>`, `<1>`, or `<2>`, matching `compatible`. |
| `bindings` | required | Ordered list of steps. |
| `wait-ms` | 15 | Delay between steps. Use 30 to 50 for typing over Bluetooth. |
| `tap-ms` | 30 | Hold time per tap. Use 30 to 50 for typing over Bluetooth. |
| `display-name` | none | Name shown in ZMK Studio. |

### Workflow checklist

- [ ] Macro node added inside the existing `macros { }` block.
- [ ] Label is unique and every line ends with `;`.
- [ ] Text macros use codes for the OS layout of the layer they are on.
- [ ] Every `&macro_press` has a matching `&macro_release`.
- [ ] One `&trans` replaced with `&my_macro`; entry count unchanged; diagram comment updated.
- [ ] `scripts/build.sh Corne_left_oled` succeeds.
- [ ] `firmware/Corne_left_oled.uf2` flashed to the left half.
- [ ] If Studio was used before: **Restore Stock Settings**.

### Where to read more

- ZMK v0.3 macro docs (local copy): `.zmk/zmk/docs/docs/keymaps/behaviors/macros.md`
- Macro control definitions: `.zmk/zmk/app/dts/behaviors/macros.dtsi`
- Key names and modifier functions: `.zmk/zmk/docs/docs/keymaps/list-of-keycodes.mdx` and `.zmk/zmk/docs/docs/keymaps/modifiers.mdx`
- Layers (`&mo`, `&to`, `&tog`): `.zmk/zmk/docs/docs/keymaps/behaviors/layers.md`
