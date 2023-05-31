package tools

import (
	"sort"
	"strings"

	"smyh_gen/types"
)

var (
	leftHandKeys   = []byte("qwertasdfgzxcvb")
	leftHandKeySet = map[byte]struct{}{}
)

func init() {
	for _, key := range leftHandKeys {
		leftHandKeySet[key] = struct{}{}
	}
}

// BuildCharMetaList 构造字符编码列表
func BuildCharMetaList(table map[string][]*types.Division, simpTable map[string][]*types.CharSimp, mappings map[string]string, freqSet map[string]int64) (charMetaList []*types.CharMeta) {
	charMetaList = make([]*types.CharMeta, 0, len(table))
	// 遍历字符表
	for char, divs := range table {
		// 遍历字符的所有拆分表
		for _, div := range divs {
			full, code := calcCodeByDiv(div.Divs, mappings)
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
				charMeta.Freq = 10000
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
	// 決定是否加詞
	dealPhrase := func(phrase []rune, freq int64) {
		if len(phrase) < 2 || len(phrase) > 4 {
			return
		}

		phraseChars := make([][]*types.CharMeta, len(phrase))
		// 進位加法器記録下標, 詞語各字的各編碼笛卡爾積
		charIndexes := make([]int, len(phrase))
		for i, char := range phrase {
			phraseChars[i] = charMetaMap[string(char)]
		}

		commitPhrase := func(current []*types.CharMeta) {
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
			if cFreq, ok := phraseFreqSet[cPhrase]; ok {
				// 雙首選也是詞
				backed := false
				for _, char := range cPhraseChars {
					if char.Back {
						// 雙首選存在後置字, 後置之
						backed = true
					}
				}
				if backed {
					cFreq = 0
				}
				addPhrase(cPhrase, cPhraseCode, "", cFreq)
			} else {
				// 雙首選作爲提示詞
				tip = cPhrase
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

func calcCodeByDiv(div []string, mappings map[string]string) (full string, code string) {
	for _, comp := range div {
		compCode := mappings[comp]
		code += compCode[:1]
		full += compCode
	}
	if len(code) < 3 {
		code += full[len(full)-1:]
	}

	if len(code) == 2 {
		supp := getCodeSupplement(full)
		code += supp
		// full += supp
	}

	code = strings.ToLower(code)
	return
}

func getCodeSupplement(code string) (supp string) {
	// 使用互擊EI方式
	// if _, ok := leftHandKeySet[strings.ToLower(code)[1]]; ok {
	// 	supp = "i"
	// } else {
	// 	supp = "e"
	// }
	// 使用雙寫小碼方式
	supp = string(code[len(code)-1])
	return
}
