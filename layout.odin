package main

// 2-set (dubeolsik) layout, indexed by letter A..Z.
base_layout := [26]rune{
	'ㅁ', 'ㅠ', 'ㅊ', 'ㅇ', 'ㄷ', 'ㄹ', 'ㅎ', 'ㅗ', 'ㅑ', 'ㅓ', 'ㅏ', 'ㅣ', 'ㅡ',
	'ㅜ', 'ㅐ', 'ㅔ', 'ㅂ', 'ㄱ', 'ㄴ', 'ㅅ', 'ㅕ', 'ㅍ', 'ㅈ', 'ㅌ', 'ㅛ', 'ㅋ',
}
shift_layout := [26]rune{
	'ㅁ', 'ㅠ', 'ㅊ', 'ㅇ', 'ㄸ', 'ㄹ', 'ㅎ', 'ㅗ', 'ㅑ', 'ㅓ', 'ㅏ', 'ㅣ', 'ㅡ',
	'ㅜ', 'ㅒ', 'ㅖ', 'ㅃ', 'ㄲ', 'ㄴ', 'ㅆ', 'ㅕ', 'ㅍ', 'ㅉ', 'ㅌ', 'ㅛ', 'ㅋ',
}

// letter is 'A'..'Z' (same as the Windows VK code).
jamo_for_letter :: proc(letter: u8, shift: bool) -> rune {
	i := int(letter - 'A')
	return shift_layout[i] if shift else base_layout[i]
}
