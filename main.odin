package main

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import win "core:sys/windows"

WINDOW_W :: 700
WINDOW_H :: 225

main :: proc() {
	rl.SetConfigFlags({.WINDOW_TRANSPARENT, .WINDOW_UNDECORATED, .WINDOW_TOPMOST})
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

	// Each key is a letter 'A'..'Z' (== its VK code); the jamo comes from the layout.
	KeyDef :: struct {
		letter: u8,
		rect:   rl.Rectangle,
	}
	rows := [3]struct {
		letters: string,
		indent:  f32,
	}{{"QWERTYUIOP", 0}, {"ASDFGHJKL", 25}, {"ZXCVBNM", 65}}

	start_x: f32 = 20
	start_y: f32 = 20
	btn_w: f32 = 60
	btn_h: f32 = 60
	gap: f32 = 8

	keys: [dynamic]KeyDef
	defer delete(keys)
	for row, y in rows {
		for i in 0 ..< len(row.letters) {
			r := rl.Rectangle{start_x + row.indent + f32(i) * (btn_w + gap), start_y + f32(y) * (btn_h + gap), btn_w, btn_h}
			append(&keys, KeyDef{row.letters[i], r})
		}
	}

	is_dragging := false
	drag_offset := rl.Vector2{}
	last_foreground := win.GetForegroundWindow()

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
		top_bar_rect := rl.Rectangle{0, 0, WINDOW_W, 15}
		close_rect := rl.Rectangle{WINDOW_W - 30, 0, 30, 15}
		if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_pos, close_rect) {
			g.quit = true
		} else if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse_pos, top_bar_rect) {
			is_dragging = true
			drag_offset = mouse_pos
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

		shift := shift_held()

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)

		rl.DrawRectangleRounded(top_bar_rect, 0.1, 4, rl.Color{40, 40, 40, 245})
		rl.DrawTextEx(font, "한", {6, -3}, 18, 1, rl.WHITE)
		rl.DrawTextEx(font, "X", {WINDOW_W - 20, -3}, 18, 1, rl.Color{230, 100, 100, 255})

		for k in keys {
			jamo := jamo_for_letter(k.letter, shift)
			is_hovered := rl.CheckCollisionPointRec(mouse_pos, k.rect)
			is_down := g.down[k.letter] || (is_hovered && rl.IsMouseButtonDown(.LEFT))

			if is_hovered && rl.IsMouseButtonPressed(.LEFT) {
				send_edit(feed(&g.composer, jamo))
			}

			btn_color := is_down ? rl.Color{100, 180, 240, 230} : (is_hovered ? rl.Color{80, 80, 80, 220} : rl.Color{50, 50, 50, 200})
			rl.DrawRectangleRounded(k.rect, 0.2, 4, btn_color)
			rl.DrawRectangleRoundedLines(k.rect, 0.2, 4, rl.Color{90, 90, 90, 255})

			label, _ := strings.clone_to_cstring(utf8.runes_to_string([]rune{jamo}, context.temp_allocator), context.temp_allocator)
			text_size := rl.MeasureTextEx(font, label, 22, 1)
			text_pos := rl.Vector2{
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
