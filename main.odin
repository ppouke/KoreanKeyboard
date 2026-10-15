package main

import "core:strings"
import "core:fmt"
import rl "vendor:raylib"
import win "core:sys/windows"

KeyDef :: struct {
	label: string,
	key:   rl.KeyboardKey,
	rect:  rl.Rectangle,
}

main :: proc() {
	// 1. Transparent & Undecorated window configuration
	rl.SetConfigFlags({.WINDOW_TRANSPARENT, .WINDOW_UNDECORATED})
	rl.InitWindow(760, 320, "Pure Raylib Korean Keyboard")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Load Korean Font (Make sure NotoSansKR-Regular.ttf is in your folder)
	korean_codepoints := []rune{
		'ㅂ', 'ㅈ', 'ㄷ', 'ㄱ', 'ㅅ', 'ㅛ', 'ㅕ', 'ㅑ', 'ㅐ', 'ㅔ',
		'ㅁ', 'ㄴ', 'ㅇ', 'ㄹ', 'ㅎ', 'ㅗ', 'ㅓ', 'ㅏ', 'ㅣ',
		'ㅋ', 'ㅌ', 'ㅊ', 'ㅍ', 'ㅠ', 'ㅜ', 'ㅡ',
	}
	font := rl.LoadFontEx("NotoSansKR-Regular.ttf", 22, raw_data(korean_codepoints), i32(len(korean_codepoints)))
	defer rl.UnloadFont(font)

	// Define Keyboard layout rows with explicit layout positions (x, y, w, h)
	start_x: f32 = 20
	start_y: f32 = 70
	btn_w: f32 = 60
	btn_h: f32 = 60
	gap: f32 = 8

	Row_Key :: struct {
			label: string,
			key: rl.KeyboardKey
	}

	// Row 1 (10 keys)
	row1_keys := []Row_Key{
		{"ㅂ", .Q}, {"ㅈ", .W}, {"ㄷ", .E}, {"ㄱ", .R}, {"ㅅ", .T},
		{"ㅛ", .Y}, {"ㅕ", .U}, {"ㅑ", .I}, {"ㅐ", .O}, {"ㅔ", .P},
	}
	
	// Row 2 (9 keys, slightly indented)
	row2_keys := []Row_Key{
		{"ㅁ", .A}, {"ㄴ", .S}, {"ㅇ", .D}, {"ㄹ", .F}, {"ㅎ", .G},
		{"ㅗ", .H}, {"ㅓ", .J}, {"ㅏ", .K}, {"ㅣ", .L},
	}

	// Row 3 (7 keys, more indented)
	row3_keys := []Row_Key{
		{"ㅋ", .Z}, {"ㅌ", .X}, {"ㅊ", .C}, {"ㅍ", .V},
		{"ㅠ", .B}, {"ㅜ", .N}, {"ㅡ", .M},
	}

	// Build dynamic key definitions with calculated positions
	keys: [dynamic]KeyDef
	defer delete(keys)

	// Populate Row 1
	for item, i in row1_keys {
		r := rl.Rectangle{start_x + f32(i) * (btn_w + gap), start_y, btn_w, btn_h}
		append(&keys, KeyDef{item.label, item.key, r})
	}
	// Populate Row 2
	for item, i in row2_keys {
		r := rl.Rectangle{start_x + 25 + f32(i) * (btn_w + gap), start_y + btn_h + gap, btn_w, btn_h}
		append(&keys, KeyDef{item.label, item.key, r})
	}
	// Populate Row 3
	for item, i in row3_keys {
		r := rl.Rectangle{start_x + 65 + f32(i) * (btn_w + gap), start_y + (btn_h + gap) * 2, btn_w, btn_h}
		append(&keys, KeyDef{item.label, item.key, r})
	}

	last_pressed := "없음"
	is_dragging := false
	drag_offset := rl.Vector2{}

	for !rl.WindowShouldClose() {
		mouse_pos := rl.GetMousePosition()

		// --- Window Dragging Logic (Click & drag the top bar) ---
		top_bar_rect := rl.Rectangle{0, 0, 760, 45}
		if rl.IsMouseButtonPressed(.LEFT) {
			if rl.CheckCollisionPointRec(mouse_pos, top_bar_rect) {
				is_dragging = true
				drag_offset = mouse_pos
			}
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

		// --- Drawing ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK) // Transparent background!

		// 1. Draw Container Background & Top Bar
		rl.DrawRectangleRounded(top_bar_rect, 0.1, 4, rl.Color{40, 40, 40, 245})                 // Top bar

		// Top bar title text & status info
		rl.DrawText("Korean Virtual Keyboard", 15, 12, 18, rl.WHITE)
		status_text := strings.clone_to_cstring(fmt.tprintf("Last Key: %s", last_pressed))
		defer delete(status_text)
		rl.DrawText(status_text, 450, 14, 16, rl.LIGHTGRAY)

		// 2. Render Keys
		for &k in keys {
			is_hovered := rl.CheckCollisionPointRec(mouse_pos, k.rect)
			is_down    := rl.IsKeyDown(k.key) || (is_hovered && rl.IsMouseButtonDown(.LEFT))

			if is_down {
				last_pressed = k.label
				if rl.IsMouseButtonPressed(.LEFT) || rl.IsKeyPressed(k.key) {
						type_unicode_char(k.label)
				}
			}

			// Key styling colors
			btn_color := is_down ? rl.Color{100, 180, 240, 230} : (is_hovered ? rl.Color{80, 80, 80, 220} : rl.Color{50, 50, 50, 200})
			
			// Draw Key Shape
			rl.DrawRectangleRounded(k.rect, 0.2, 4, btn_color)
			rl.DrawRectangleRoundedLines(k.rect, 0.2, 4,rl.Color{90, 90, 90, 255}) // subtle border

			// Draw Korean Character Centered inside Button
			char_str := strings.clone_to_cstring(k.label)
			defer delete(char_str)
			
			text_size := rl.MeasureTextEx(font, char_str, 22, 1)
			text_pos := rl.Vector2{
				k.rect.x + (k.rect.width - text_size.x) * 0.5,
				k.rect.y + (k.rect.height - text_size.y) * 0.5,
			}
			rl.DrawTextEx(font, char_str, text_pos, 22, 1, rl.WHITE)
		}

		rl.EndDrawing()
	}
}

// Simulates copying a string to the clipboard and sending Ctrl+V to the active window
type_unicode_char :: proc(s: string) {
	KEYEVENT_KEYUP :: 0x0002
	KEYEVENT_UNICODE :: 0x0004
	r: rune = rune(s[0])
	inputs: [2]win.INPUT
	for &i, idx in inputs {
		i.type = win.INPUT_TYPE.KEYBOARD
		i.ki.wScan = win.WORD(r)
		i.ki.dwFlags = KEYEVENT_UNICODE
			if idx == 1 {i.ki.dwFlags |= KEYEVENT_KEYUP}
	}

	win.SendInput(len(inputs), &inputs[0], size_of(win.INPUT))
}
