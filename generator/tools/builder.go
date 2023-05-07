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
	smartSet := map[string]struct{}{}
	// 加詞
	addPhrase := func(phrase, code, tip string, freq int64) {
		if _, ok := smartSet[phrase+code]; ok {
			return
		}
		phraseMeta := types.PhraseMeta{
			Phrase: phrase,
			Code:   code,
			Freq:   freq,
		}
		smartSet[phrase+code] = struct{}{}
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
		phraseChars := make([][]*types.CharMeta, len(phrase))
		// 進位加法器記録下標, 詞語各字的各編碼笛卡爾積
		charIndexes := make([]int, len(phrase))
		for i, char := range phrase {
			phraseChars[i] = charMetaMap[string(char)]
		}

		for {
			current := make([]*types.CharMeta, len(phrase))
			for i := range charIndexes {
				current[i] = phraseChars[i][charIndexes[i]]
			}

			// 是否需要選重
			needSel := false

			switch len(current) {
			case 2:
				// 二字詞
				fs, ss := current[0].Sel != 0, current[1].Sel != 0
				if fs || ss {
					needSel = true
				}
			case 3:
				// 三字詞
				fs, ss, ts := current[0].Sel != 0, current[1].Sel != 0, current[2].Sel != 0
				if fs {
					// 首字選重
					needSel = true
					if !ts {
						// 末字不選重
						current = current[:2]
					}
				} else if ss {
					// 次字選重
					needSel = true
					if _, ok := phraseFreqSet[current[0].Char+current[1].Char]; ok {
						// 若有前二字詞, 則需組首字
						if !ts {
							// 不組末字
							current = current[:2]
						}
					} else {
						// 不組之
						current = current[1:]
					}
				} else if ts {
					// 末字選重
					needSel = true
					// 不組首字
					current = current[1:]
				}
			default:
			}

			// 需要選重, 即需要組詞
			if needSel {
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
	if _, ok := leftHandKeySet[strings.ToLower(code)[1]]; ok {
		supp = "k"
	} else {
		supp = "d"
	}
	return
}
