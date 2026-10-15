package main

import "base:runtime"
import win "core:sys/windows"

// Win+K toggles Korean mode (and the overlay). Win+Shift+Q quits.

LLKHF_INJECTED :: 0x10
KEYEVENTF_KEYUP :: 0x0002
KEYEVENTF_UNICODE :: 0x0004

Input_State :: struct {
	hook:      win.HHOOK,
	korean:    bool, // also controls overlay visibility (main loop syncs it)
	quit:      bool,
	down:      [256]bool, // physical key state, drives the overlay highlight
	swallowed: [256]bool, // keys whose key-down we ate; eat the key-up too
	composer:  Composer,
}
g: Input_State

// The hook callback runs on the installing thread while it pumps messages
// (raylib's PollInputEvents does), so g is only ever touched from that thread.
install_hook :: proc() -> bool {
	g.korean = true
	g.hook = win.SetWindowsHookExW(win.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
	return g.hook != nil
}

uninstall_hook :: proc() {
	if g.hook != nil {win.UnhookWindowsHookEx(g.hook)}
}

keyboard_proc :: proc "system" (code: win.c_int, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	context = runtime.default_context()
	if code == win.HC_ACTION {
		kb := (^win.KBDLLHOOKSTRUCT)(uintptr(lparam))
		if kb.flags & LLKHF_INJECTED == 0 && kb.vkCode < 256 {
			is_down := wparam == win.WM_KEYDOWN || wparam == win.WM_SYSKEYDOWN
			if handle_key(kb.vkCode, is_down) {return 1}
		}
	}
	return win.CallNextHookEx(g.hook, code, wparam, lparam)
}

// Returns true to swallow the key.
handle_key :: proc(vk: u32, is_down: bool) -> bool {
	was_down := g.down[vk]
	g.down[vk] = is_down

	if !is_down {
		s := g.swallowed[vk]
		g.swallowed[vk] = false
		return s
	}

	// Global shortcuts, active even when Korean mode is off.
	if vk == 'K' && win_held() {
		if !was_down {
			set_enabled(!g.korean)
			cancel_start_menu()
		}
		g.swallowed[vk] = true
		return true
	}
	if vk == 'Q' && win_held() && shift_held() {
		g.quit = true
		cancel_start_menu()
		g.swallowed[vk] = true
		return true
	}
	if !g.korean {return false}

	switch {
	case vk >= 'A' && vk <= 'Z' && !command_held():
		send_edit(feed(&g.composer, jamo_for_letter(u8(vk), shift_held())))
		g.swallowed[vk] = true
		return true
	case vk == win.VK_BACK && !command_held():
		if e, ok := backspace(&g.composer); ok {
			send_edit(e)
			g.swallowed[vk] = true
			return true
		}
	case !is_modifier(vk):
		reset(&g.composer) // space, enter, arrows, digits... end the syllable
	}
	return false
}

set_enabled :: proc(on: bool) {
	g.korean = on
	reset(&g.composer)
}

win_held :: proc() -> bool {
	return g.down[win.VK_LWIN] || g.down[win.VK_RWIN]
}

// Swallowing the key after Win leaves a lone Win press, which opens Start on
// release. An injected unassigned key in between cancels that.
cancel_start_menu :: proc() {
	inputs: [2]win.INPUT
	for &i, idx in inputs {
		i.type = .KEYBOARD
		i.ki = {wVk = 0xE8, dwFlags = KEYEVENTF_KEYUP if idx == 1 else 0}
	}
	win.SendInput(len(inputs), &inputs[0], size_of(win.INPUT))
}

shift_held :: proc() -> bool {
	return g.down[win.VK_LSHIFT] || g.down[win.VK_RSHIFT]
}

command_held :: proc() -> bool {
	return g.down[win.VK_LCONTROL] || g.down[win.VK_RCONTROL] || g.down[win.VK_LMENU] || g.down[win.VK_RMENU] || g.down[win.VK_LWIN] || g.down[win.VK_RWIN]
}

is_modifier :: proc(vk: u32) -> bool {
	return (vk >= win.VK_LSHIFT && vk <= win.VK_RMENU) || vk == win.VK_LWIN || vk == win.VK_RWIN
}

// Types an Edit into whichever window has focus.
send_edit :: proc(e: Edit) {
	inputs: [16]win.INPUT
	n := 0
	add :: proc(inputs: []win.INPUT, n: ^int, vk, scan: win.WORD, flags: win.DWORD) {
		inputs[n^].type = .KEYBOARD
		inputs[n^].ki = {wVk = vk, wScan = scan, dwFlags = flags}
		n^ += 1
	}

	if e.erase {
		add(inputs[:], &n, win.VK_BACK, 0, 0)
		add(inputs[:], &n, win.VK_BACK, 0, KEYEVENTF_KEYUP)
	}
	for i in 0 ..< e.n {
		r := e.out[i]
		add(inputs[:], &n, 0, win.WORD(r), KEYEVENTF_UNICODE)
		add(inputs[:], &n, 0, win.WORD(r), KEYEVENTF_UNICODE | KEYEVENTF_KEYUP)
	}
	if n > 0 {
		win.SendInput(win.UINT(n), &inputs[0], size_of(win.INPUT))
	}
}
