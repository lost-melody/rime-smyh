package tools

import (
	"sort"
	"strings"

	"smyh_gen/types"
)

const fallBackFreq = 100

var (
	leftHandKeys   = []byte("qwertasdfgzxcvb")
	leftHandKeySet = map[byte]struct{}{}
)

var cjkExtSet = map[rune]rune{
	// 0x4e00:  0x9fff,  // CJK
	0x3400:  0x4dbf,  // CJK-A
	0x20000: 0x2a6df, // CJK-B
	0x2a700: 0x2b73f, // CJK-C
	0x2b740: 0x2b81f, // CJK-D
	0x2b820: 0x2ceaf, // CJK-E
	0x2ceb0: 0x2ebef, // CJK-F
	0x30000: 0x3134f, // CJK-G
	0x31350: 0x323af, // CJK-H
	0x2ebf0: 0x2ee4a, // CJK-I
	0xf900:  0xfaff,  // Dup, Uni, Cor
	0x2f800: 0x2fa1f, // Uni
	0x2f00: 0x2fdf,   // Kangxi
	0x2e80: 0x2eff,   // CJK radical ext
}

func init() {
	for _, key := range leftHandKeys {
		leftHandKeySet[key] = struct{}{}
	}
}

func acceptCharacter(char string, cjkExtWhiteSet map[rune]bool) (accept bool) {
	runes := []rune(char)
	if len(runes) == 0 {
		return
	}

	u := runes[0]
	// CJK擴展區字符白名單
	if cjkExtWhiteSet[u] {
		accept = true
		return
	}

	for left, right := range cjkExtSet {
		if u >= left && u <= right {
			return
		}
	}

	accept = true
	return
}

// BuildCharMetaList 构造字符编码列表
func BuildCharMetaList(table map[string][]*types.Division, simpTable map[string][]*types.CharSimp, mappings map[string]string, freqSet map[string]int64, cjkExtWhiteSet map[rune]bool) (charMetaList []*types.CharMeta) {
	charMetaList = make([]*types.CharMeta, 0, len(table))
	// 遍历字符表
	for char, divs := range table {
		if !acceptCharacter(char, cjkExtWhiteSet) {
			continue
		}

		// 遍历字符的所有拆分表
		for _, div := range divs {
			full, code := calcCodeByDiv(div.Divs, mappings, freqSet[char])
			charMeta := types.CharMeta{
				Char: char,
				Full: full,
				Code: code,
				Freq: freqSet[char],
			}
			if len(simpTable[charMeta.Char]) != 0 {
				// 遍历字符简码表
				for _, simp := range simpTable[charMeta.Char] {
					cm := charMeta
					cm.Code = simp.Simp
					cm.Simp = true
					charMetaList = append(charMetaList, &cm)
				}
				// 全码后置
				charMeta.Freq = fallBackFreq
				charMeta.Back = true
				charMetaList = append(charMetaList, &charMeta)
			} else {
				// 无简码
				charMetaList = append(charMetaList, &charMeta)
			}
		}
	}

	// 按字频编号
	sort.SliceStable(charMetaList, func(i, j int) bool {
		a, b := charMetaList[i], charMetaList[j]
		return a.Freq > b.Freq ||
			a.Freq == b.Freq && a.Char < b.Char
	})
	for i, charMeta := range charMetaList {
		charMeta.Seq = i
	}

	// 按编码排序
	sort.SliceStable(charMetaList, func(i, j int) bool {
		a, b := charMetaList[i], charMetaList[j]
		return a.Code < b.Code ||
			a.Code == b.Code && a.Seq < b.Seq
	})

	return
}

// BuildFullCodeMetaList 构造字符四码全码编码列表
func BuildFullCodeMetaList(table map[string][]*types.Division, mappings map[string]string, freqSet map[string]int64, charMetaMap map[string][]*types.CharMeta) (charMetaList []*types.CharMeta) {
	charMetaList = make([]*types.CharMeta, 0, len(table))
	getSel := func(char string) (sel int) {
		sel = -1
		for _, charMeta := range charMetaMap[char] {
			if sel == -1 || sel > charMeta.Sel {
				sel = charMeta.Sel
			}
		}
		return
	}

	// 遍历字符表
	for char, divs := range table {
		// 遍历字符的所有拆分表
		for _, div := range divs {
			full, code := calcFullCodeByDiv(div.Divs, mappings)
			charMeta := types.CharMeta{
				Char: char,
				Full: full,
				Code: code,
				Freq: freqSet[char],
			}
			if getSel(char) == 0 {
				charMeta.Freq = fallBackFreq
			}
			charMetaList = append(charMetaList, &charMeta)
		}
	}

	// 按字频编号
	sort.SliceStable(charMetaList, func(i, j int) bool {
		a, b := charMetaList[i], charMetaList[j]
		return a.Freq > b.Freq ||
			a.Freq == b.Freq && a.Char < b.Char
	})
	for i, charMeta := range charMetaList {
		charMeta.Seq = i
	}

	// 按编码排序
	sort.SliceStable(charMetaList, func(i, j int) bool {
		a, b := charMetaList[i], charMetaList[j]
		return a.Code < b.Code ||
			a.Code == b.Code && a.Seq < b.Seq
	})

	return
}

// BuildCharMetaMap 构造字符编码集合
func BuildCharMetaMap(charMetaList []*types.CharMeta) (charMetaMap map[string][]*types.CharMeta) {
	charMetaMap = map[string][]*types.CharMeta{}
	for _, charMeta := range charMetaList {
		charMetaMap[charMeta.Char] = append(charMetaMap[charMeta.Char], charMeta)
	}
	return
}

// BuildCodeCharMetaMap 构造编码字符集合
func BuildCodeCharMetaMap(charMetaList []*types.CharMeta) (codeCharMetaMap map[string][]*types.CharMeta) {
	codeCharMetaMap = map[string][]*types.CharMeta{}
	for _, charMeta := range charMetaList {
		codeCharMetaMap[charMeta.Code] = append(codeCharMetaMap[charMeta.Code], charMeta)
	}
	for _, codeCharMetas := range codeCharMetaMap {
		for i, charMeta := range codeCharMetas[1:] {
			charMeta.Sel = i + 1
		}
	}
	return
}

func BuildSmartPhraseList(charMetaMap map[string][]*types.CharMeta, codeCharMetaMap map[string][]*types.CharMeta, phraseFreqSet map[string]int64) (phraseMetaList []*types.PhraseMeta, phraseTipList []*types.PhraseTip) {
	// 暫存 ["詞語code"]: &PhraseMeta{}
	smartSet := map[string]*types.PhraseMeta{}
	// 加詞
	addPhrase := func(phrase, code, tip string, freq int64) {
		if pm, ok := smartSet[phrase+code]; ok {
			// 詞語已存在時, 若有更高權重, 則更新
			if freq > pm.Freq {
				pm.Freq = freq
			}
			return
		}
		phraseMeta := types.PhraseMeta{
			Phrase: phrase,
			Code:   code,
			Freq:   freq,
		}
		smartSet[phrase+code] = &phraseMeta
		phraseMetaList = append(phraseMetaList, &phraseMeta)
		if len(tip) != 0 {
			phraseTip := types.PhraseTip{
				Phrase:  phrase,
				CPhrase: tip,
			}
			phraseTipList = append(phraseTipList, &phraseTip)
		}
	}

	// 輔表, 用於記錄 "入法" 這類不成詞, 又應比 "乘法" 優先的候選
	compFreqSet := map[string]int64{}
	for phrase, freq := range phraseFreqSet {
		if compFreqSet[phrase] < freq {
			compFreqSet[phrase] = freq
		}
		phrase := []rune(phrase)
		if len(phrase) == 3 {
			a, b := string(phrase[:2]), string(phrase[1:])
			if compFreqSet[a] < freq {
				compFreqSet[a] = freq
			}
			if compFreqSet[b] < freq {
				compFreqSet[b] = freq
			}
		}
	}

	// 決定是否加詞
	dealPhrase := func(phrase []rune, freq int64) {
		if len(phrase) < 2 || len(phrase) > 3 {
			return
		}

		phraseChars := make([][]*types.CharMeta, len(phrase))
		// 進位加法器記録下標, 詞語各字的各編碼笛卡爾積
		charIndexes := make([]int, len(phrase))
		for i, char := range phrase {
			phraseChars[i] = charMetaMap[string(char)]
		}

		commitPhrase := func(current []*types.CharMeta) {
			for _, c := range current {
				// 若詞中存在後置全碼字, 則不計入詞條
				if c.Back {
					return
				}
			}

			// 首選字成詞
			cPhraseChars := make([]*types.CharMeta, len(current))
			phrase, cPhrase := "", ""
			phraseCode, cPhraseCode := "", ""
			for i := range current {
				cPhraseChars[i] = codeCharMetaMap[current[i].Code][0]
				phrase += current[i].Char
				cPhrase += cPhraseChars[i].Char
				phraseCode += current[i].Code
				cPhraseCode += cPhraseChars[i].Code
			}
			tip := ""
			if cFreq, ok := compFreqSet[cPhrase]; ok {
				// 雙首選成詞
				backed := false
				for _, char := range cPhraseChars {
					if char.Back {
						// 後置字
						backed = true
					}
				}
				if backed {
					cFreq = 0
				}
				addPhrase(cPhrase, cPhraseCode, "", cFreq)
			}
			addPhrase(phrase, phraseCode, tip, freq)
		}

		for {
			current := make([]*types.CharMeta, len(phrase))
			for i := range charIndexes {
				current[i] = phraseChars[i][charIndexes[i]]
			}

			// 雙指針滑動窗口
			for i, j := 0, 1; j < len(current); {
				if current[i].Sel != 0 {
					if i-1 >= 0 {
						if _, ok := phraseFreqSet[current[i-1].Char+current[i].Char]; ok {
							// 根[据], 根[据]地; 而不是 根[据], [据]地
							i, j = i-1, j-1
						}
					}
					// [電]力
					commitPhrase(current[i : j+1])
					if current[j].Sel != 0 {
						for j++; j < len(current) && current[j].Sel != 0; j++ {
							// [電]動[機], [電]動[機][器], 採[集][器]
							commitPhrase(current[i : j+1])
						}
						i, j = j, j+1
						continue
					} else if j+1 == len(current)-1 && current[j+1].Sel != 0 {
						// [七]年[级]
						commitPhrase(current[i:])
						break
					}
				} else if j == len(current)-1 && current[j].Sel != 0 {
					// 机[器]
					commitPhrase(current[i:])
					break
				}
				i, j = i+1, j+1
			}

			done := false
			// 模拟進位加法器, 匹配所有組合
			for i := range charIndexes {
				// 當位加一
				charIndexes[i]++
				if charIndexes[i] == len(phraseChars[i]) {
					// 進位
					charIndexes[i] = 0
					if i == len(charIndexes)-1 {
						// 最高位進位, 結束
						done = true
						break
					}
				} else {
					// 无進位
					break
				}
			}
			if done {
				break
			}
		}
	}

	// 遍历词汇表
	for phrase, freq := range phraseFreqSet {
		dealPhrase([]rune(phrase), freq)
	}

	// 按词频排序
	sort.SliceStable(phraseMetaList, func(i, j int) bool {
		a, b := phraseMetaList[i], phraseMetaList[j]
		return a.Code < b.Code ||
			a.Code == b.Code && a.Freq > b.Freq ||
			a.Code == b.Code && a.Freq == b.Freq && a.Phrase < b.Phrase
	})
	sort.SliceStable(phraseTipList, func(i, j int) bool {
		return phraseTipList[i].Phrase < phraseTipList[j].Phrase
	})

	return
}

func calcCodeByDiv(div []string, mappings map[string]string, freq int64) (full string, code string) {
	if len(div) > 3 {
		div = []string{div[0], div[1], div[len(div)-1]}
	}
	stack := "1"
	if freq < 10 {
		stack = "3"
	}
	for _, comp := range div {
		compCode := mappings[comp]
		code += compCode[:1]
		stack = compCode[1:] + stack
		full += compCode
	}
	code += stack[:3-len(code)]
	code = strings.ToLower(code)
	return
}

func calcFullCodeByDiv(div []string, mappings map[string]string) (full string, code string) {
	stack := "11"
	for _, comp := range div {
		compCode := mappings[comp]
		code += compCode[:1]
		stack = compCode[1:] + stack
		full += compCode
	}
	code += stack[:4-len(code)]
	code = strings.ToLower(code)
	return
}
