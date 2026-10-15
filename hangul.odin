package main

// Pure Hangul composer for the 2-set (dubeolsik) layout. No OS dependencies.
//
// The composer tracks the one syllable currently being typed. Each input
// returns an Edit: "erase the composing char (if any), then type these runes".
// The last rune of Edit.out is the new composing char, when there is one.

initials := [19]rune{'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'}
medials  := [21]rune{'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'}
finals   := [28]rune{0, 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'}

Combo :: struct {
	a, b, out: rune,
}

vowel_combos := [?]Combo{
	{'ㅗ', 'ㅏ', 'ㅘ'}, {'ㅗ', 'ㅐ', 'ㅙ'}, {'ㅗ', 'ㅣ', 'ㅚ'},
	{'ㅜ', 'ㅓ', 'ㅝ'}, {'ㅜ', 'ㅔ', 'ㅞ'}, {'ㅜ', 'ㅣ', 'ㅟ'},
	{'ㅡ', 'ㅣ', 'ㅢ'},
}

final_combos := [?]Combo{
	{'ㄱ', 'ㅅ', 'ㄳ'}, {'ㄴ', 'ㅈ', 'ㄵ'}, {'ㄴ', 'ㅎ', 'ㄶ'},
	{'ㄹ', 'ㄱ', 'ㄺ'}, {'ㄹ', 'ㅁ', 'ㄻ'}, {'ㄹ', 'ㅂ', 'ㄼ'}, {'ㄹ', 'ㅅ', 'ㄽ'},
	{'ㄹ', 'ㅌ', 'ㄾ'}, {'ㄹ', 'ㅍ', 'ㄿ'}, {'ㄹ', 'ㅎ', 'ㅀ'},
	{'ㅂ', 'ㅅ', 'ㅄ'},
}

// Compatibility jamo (U+3131..U+3163). 0 means "empty slot".
Composer :: struct {
	ini, med, fin: rune,
}

Edit :: struct {
	erase: bool, // delete the previously composing char first
	out:   [3]rune,
	n:     int,
}

is_vowel :: proc(r: rune) -> bool {
	return r >= 0x314F && r <= 0x3163
}

index_of :: proc(table: []rune, r: rune) -> int {
	for t, i in table {
		if t == r {return i}
	}
	return -1
}

combine :: proc(table: []Combo, a, b: rune) -> (rune, bool) {
	for c in table {
		if c.a == a && c.b == b {return c.out, true}
	}
	return 0, false
}

// Splits a compound jamo into (first, second). Simple jamo give (0, r).
split :: proc(table: []Combo, r: rune) -> (a, b: rune) {
	for c in table {
		if c.out == r {return c.a, c.b}
	}
	return 0, r
}

// The char currently shown for the composing state, if any.
render :: proc(c: Composer) -> (r: rune, ok: bool) {
	switch {
	case c.ini != 0 && c.med != 0:
		i := index_of(initials[:], c.ini)
		m := index_of(medials[:], c.med)
		f := index_of(finals[:], c.fin) if c.fin != 0 else 0
		return rune(0xAC00 + (i * 21 + m) * 28 + f), true
	case c.ini != 0:
		return c.ini, true
	}
	return 0, false
}

feed :: proc(c: ^Composer, j: rune) -> Edit {
	before, was_composing := render(c^)
	e: Edit
	push :: proc(e: ^Edit, r: rune) {
		e.out[e.n] = r
		e.n += 1
	}

	vowel := is_vowel(j)
	switch {
	case c.ini == 0:
		if vowel {push(&e, j)} else {c.ini = j}

	case c.med == 0:
		if vowel {
			c.med = j
		} else {
			push(&e, c.ini)
			c.ini = j
		}

	case c.fin == 0:
		if vowel {
			if r, ok := combine(vowel_combos[:], c.med, j); ok {
				c.med = r
			} else {
				push(&e, before)
				push(&e, j)
				c^ = {}
			}
		} else if index_of(finals[:], j) > 0 {
			c.fin = j
		} else {
			push(&e, before)
			c^ = {ini = j}
		}

	case:
		if vowel {
			// Final moves to the next syllable: 한+ㅏ -> 하나, 닭+ㅏ -> 달가
			keep, moved := split(final_combos[:], c.fin)
			c.fin = keep
			reduced, _ := render(c^)
			push(&e, reduced)
			c^ = {ini = moved, med = j}
		} else if r, ok := combine(final_combos[:], c.fin, j); ok {
			c.fin = r
		} else {
			push(&e, before)
			c^ = {ini = j}
		}
	}

	if r, ok := render(c^); ok {push(&e, r)}
	e.erase = was_composing

	// Leading char unchanged -> don't erase and retype it.
	if e.erase && e.n > 0 && e.out[0] == before {
		e.erase = false
		copy(e.out[:], e.out[1:e.n])
		e.n -= 1
	}
	return e
}

// Undo one jamo of the composing syllable. handled=false means nothing is
// composing and the real Backspace should pass through.
backspace :: proc(c: ^Composer) -> (e: Edit, handled: bool) {
	if c.ini == 0 {return {}, false}
	switch {
	case c.fin != 0:
		c.fin, _ = split(final_combos[:], c.fin)
	case c.med != 0:
		c.med, _ = split(vowel_combos[:], c.med)
	case:
		c.ini = 0
	}
	e.erase = true
	if r, ok := render(c^); ok {
		e.out[0] = r
		e.n = 1
	}
	return e, true
}

reset :: proc(c: ^Composer) {
	c^ = {}
}
