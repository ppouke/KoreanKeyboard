package main

import "core:fmt"
import "core:strings"
import win "core:sys/windows"
import "core:unicode/utf8"
import rl "vendor:raylib"

KeyDef :: struct {
	letter: u8,
	rect:   rl.Rectangle,
}

	// Each key is a letter 'A'..'Z' (== its VK code); the jamo comes from the layout.
rows : [3]string : {"QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }

WINDOW_H: i32
WINDOW_W: i32

main :: proc() {

	WINDOW_W = 700
	WINDOW_H = 225

	height_ratio : f32 = 225.0 / 700.0
	min_size: [2]i32 = {500, i32(500.0*height_ratio)}
	rl.SetConfigFlags(
		{.WINDOW_TRANSPARENT, .WINDOW_UNDECORATED, .WINDOW_TOPMOST, .WINDOW_RESIZABLE},
	)
	rl.InitWindow(WINDOW_W, WINDOW_H, "Korean Keyboard")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	make_window_non_activating()

	if !install_hook() {
		fmt.eprintln("Failed to install keyboard hook")
		return
	}
	defer uninstall_hook()

	// Font needs every jamo we draw, plus the status label glyphs.
	codepoints: [dynamic]rune
	defer delete(codepoints)
	append(&codepoints, ..base_layout[:])
	append(&codepoints, ..shift_layout[:])
	append(&codepoints, '한', 'E', 'N')
	font := rl.LoadFontEx("NotoSansKR-Regular.ttf", 22, raw_data(codepoints), i32(len(codepoints)))
	defer rl.UnloadFont(font)


	button_ratio: f32 = 60.0 / 700.0
	start_ratio : f32 = 20.0 / 700.0
	start := start_ratio * f32(WINDOW_W)
	btn_w: f32 = button_ratio * f32(WINDOW_W)
	btn_h: f32 = button_ratio * f32(WINDOW_W)

	gap_ratio : f32 = 8.0 / 700.0
	gap: f32 = gap_ratio * f32(WINDOW_W)

	keys: [10 + 9 +7]KeyDef

	reset_key_positions(start, start, btn_w, btn_h, gap, &keys)

	is_dragging := false
	is_resizing := false
	drag_offset := rl.Vector2{}
	prev_mouse_pos := rl.Vector2{}
	last_foreground := win.GetForegroundWindow()
	resize_anchor_point := rl.Vector2{}
	resize_mouse_offset := rl.Vector2{}

	hwnd := win.HWND(rl.GetWindowHandle())
	overlay_visible := true

	for !rl.WindowShouldClose() && !g.quit {
		// Overlay follows Korean mode. SHOWNOACTIVATE keeps focus on the target app.
		if g.korean != overlay_visible {
			overlay_visible = g.korean
			win.ShowWindow(hwnd, win.SW_SHOWNOACTIVATE if overlay_visible else win.SW_HIDE)
		}

		// The hook fires inside PollInputEvents (EndDrawing), on this thread.
		// A syllable doesn't carry over to a different window.
		if fg := win.GetForegroundWindow(); fg != last_foreground {
			last_foreground = fg
			reset(&g.composer)
		}

		mouse_pos := rl.GetMousePosition()

		// --- Window dragging (top bar) ---
		top_bar_rect := rl.Rectangle{15, 0, f32(WINDOW_W - 15), 15}
		left_corner_rect := rl.Rectangle{0, 0, 15, 15}
		close_rect := rl.Rectangle{f32(WINDOW_W) - 15, 0, 15, 15}

		if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_pos, close_rect) {
			g.quit = true
		} else if rl.IsMouseButtonPressed(.LEFT) &&
		   rl.CheckCollisionPointRec(mouse_pos, top_bar_rect) {
			is_dragging = true
			drag_offset = mouse_pos
		} else if rl.IsMouseButtonPressed(.LEFT) &&
		   rl.CheckCollisionPointRec(mouse_pos, left_corner_rect) {
			resize_anchor_point = rl.GetWindowPosition() + rl.Vector2{f32(WINDOW_W), f32(WINDOW_H)}
			fmt.println(rl.GetWindowPosition())
			resize_mouse_offset = rl.GetMousePosition()
			is_resizing = true
		}
		if is_dragging {
			if rl.IsMouseButtonDown(.LEFT) {
				win_pos := rl.GetWindowPosition()
				rl.SetWindowPosition(
					i32(win_pos.x + (mouse_pos.x - drag_offset.x)),
					i32(win_pos.y + (mouse_pos.y - drag_offset.y)),
				)
			} else {
				is_dragging = false
			}
		}
		if is_resizing {
			if rl.IsMouseButtonDown(.LEFT) {

				global_mouse_pos := mouse_pos + rl.GetWindowPosition()

				size_x := i32(resize_anchor_point.x - global_mouse_pos.x + resize_mouse_offset.x)
				size_y := i32((resize_anchor_point.y - global_mouse_pos.y + resize_mouse_offset.y))

				size_x = max(min_size.x, size_x)
				size_y = max(min_size.y, size_y)

				ratio := f32(size_y)/f32(size_x)
				if ratio > height_ratio { // y is bigger than x
						size_y = i32(f32(size_x) * height_ratio)
				} else if ratio < height_ratio {
						size_x = i32(f32(size_y) / height_ratio)
				}

				WINDOW_W = size_x
				WINDOW_H = size_y

				if WINDOW_W > min_size.x && WINDOW_H > min_size.y {
					rl.SetWindowSize(WINDOW_W, WINDOW_H)
					btn_w = button_ratio * f32(WINDOW_W)
					btn_h = button_ratio * f32(WINDOW_W)
					gap= gap_ratio * f32(WINDOW_W)
					start = start_ratio * f32(WINDOW_W)
					reset_key_positions(start, start, btn_w, btn_h, gap, &keys)

					new_pos_x := i32(resize_anchor_point.x) - WINDOW_W
					new_pos_y := i32(resize_anchor_point.y) - WINDOW_H

					rl.SetWindowPosition(new_pos_x, new_pos_y)
				}

			} else {
				is_resizing = false
			}
		}

		prev_mouse_pos = mouse_pos

		shift := shift_held()

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)

		rl.DrawRectangleRounded(top_bar_rect, 0.1, 4, rl.Color{40, 40, 40, 200})
		rl.DrawRectangleRounded(left_corner_rect, 0.1, 4, rl.Color{20, 20, 20, 200})
		rl.DrawRectangleRounded(close_rect, 0.1, 4, rl.Color{255, 0, 0, 200})
		rl.DrawTextEx(font, "한", {6, -3}, 18, 1, rl.WHITE)

		for k in keys {
			jamo := jamo_for_letter(k.letter, shift)
			is_hovered := rl.CheckCollisionPointRec(mouse_pos, k.rect)
			is_down := g.down[k.letter] || (is_hovered && rl.IsMouseButtonDown(.LEFT))

			if is_hovered && rl.IsMouseButtonPressed(.LEFT) {
				send_edit(feed(&g.composer, jamo))
			}

			btn_color :=
				is_down \
				? rl.Color{100, 180, 240, 230} \
				: (is_hovered ? rl.Color{80, 80, 80, 220} : rl.Color{50, 50, 50, 200})
			rl.DrawRectangleRounded(k.rect, 0.2, 4, btn_color)
			rl.DrawRectangleRoundedLines(k.rect, 0.2, 4, rl.Color{90, 90, 90, 255})

			label, _ := strings.clone_to_cstring(
				utf8.runes_to_string([]rune{jamo}, context.temp_allocator),
				context.temp_allocator,
			)
			text_size := rl.MeasureTextEx(font, label, 22, 1)
			text_pos := rl.Vector2 {
				k.rect.x + (k.rect.width - text_size.x) * 0.5,
				k.rect.y + (k.rect.height - text_size.y) * 0.5,
			}
			rl.DrawTextEx(font, label, text_pos, 22, 1, rl.WHITE)
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}

// Clicking the overlay must not take focus from the app being typed into.
make_window_non_activating :: proc() {
	hwnd := win.HWND(rl.GetWindowHandle())
	ex := win.GetWindowLongPtrW(hwnd, win.GWL_EXSTYLE)
	ex |= win.LONG_PTR(win.WS_EX_NOACTIVATE | win.WS_EX_TOOLWINDOW)
	win.SetWindowLongPtrW(hwnd, win.GWL_EXSTYLE, ex)
}

reset_key_positions :: proc(
	start_x, start_y, btn_w, btn_h, gap: f32, keys: ^[10 + 9 +7]KeyDef) {

	indent_ratios : [3]f32 = {0, 25.0/700.0, 65.0/700.0}

	index := 0
	for row, y in rows {
		for i in 0 ..< len(row) {
				indent := indent_ratios[y] * f32(WINDOW_W)
			r := rl.Rectangle {
				start_x + indent + f32(i) * (btn_w + gap),
				start_y + f32(y) * (btn_h + gap),
				btn_w,
				btn_h,
			}

			keys[index] = KeyDef{row[i], r}
			index += 1
		}
	}
}
