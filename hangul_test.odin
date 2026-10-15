package main

import "core:testing"
import "core:unicode/utf8"

// Simulates a text field: applies each Edit to a buffer.
@(private = "file")
apply :: proc(buf: ^[dynamic]rune, e: Edit) {
	if e.erase {pop(buf)}
	for i in 0 ..< e.n {append(buf, e.out[i])}
}

@(private = "file")
type_jamo :: proc(jamo: string) -> string {
	c: Composer
	buf: [dynamic]rune
	defer delete(buf)
	for r in jamo {apply(&buf, feed(&c, r))}
	return utf8.runes_to_string(buf[:], context.temp_allocator)
}

@(test)
test_basic_syllable :: proc(t: ^testing.T) {
	testing.expect_value(t, type_jamo("ㅎㅏㄴ"), "한")
}

@(test)
test_final_moves_to_next_syllable :: proc(t: ^testing.T) {
	testing.expect_value(t, type_jamo("ㅎㅏㄴㅏ"), "하나")
}

@(test)
test_compound_final_splits :: proc(t: ^testing.T) {
	testing.expect_value(t, type_jamo("ㄷㅏㄹㄱ"), "닭")
	testing.expect_value(t, type_jamo("ㄷㅏㄹㄱㅏ"), "달가")
}

@(test)
test_compound_vowel :: proc(t: ^testing.T) {
	testing.expect_value(t, type_jamo("ㅇㅗㅏ"), "와")
}

@(test)
test_word :: proc(t: ^testing.T) {
	testing.expect_value(t, type_jamo("ㅎㅏㄴㄱㅜㄱㅇㅓ"), "한국어")
}

@(test)
test_lone_vowel_and_double_initial :: proc(t: ^testing.T) {
	testing.expect_value(t, type_jamo("ㅏㅏ"), "ㅏㅏ")
	testing.expect_value(t, type_jamo("ㄸㅏ"), "따")
	testing.expect_value(t, type_jamo("ㄸㄸ"), "ㄸㄸ")
}

@(test)
test_backspace_decomposes :: proc(t: ^testing.T) {
	c: Composer
	buf: [dynamic]rune
	defer delete(buf)
	for r in ([]rune{'ㄷ', 'ㅏ', 'ㄹ', 'ㄱ'}) {apply(&buf, feed(&c, r))}
	e, ok := backspace(&c)
	testing.expect(t, ok)
	apply(&buf, e)
	testing.expect_value(t, buf[0], '달')
	e, _ = backspace(&c)
	apply(&buf, e)
	testing.expect_value(t, buf[0], '다')
	e, _ = backspace(&c)
	apply(&buf, e)
	testing.expect_value(t, buf[0], 'ㄷ')
	e, _ = backspace(&c)
	apply(&buf, e)
	testing.expect_value(t, len(buf), 0)
	_, ok = backspace(&c)
	testing.expect(t, !ok) // nothing composing: real Backspace passes through
}
