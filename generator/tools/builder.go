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
				charMeta.Freq = 1000
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
		return charMetaList[i].Freq > charMetaList[j].Freq
	})
	for i, charMeta := range charMetaList {
		charMeta.Seq = i
	}

	// 按编码排序
	sort.SliceStable(charMetaList, func(i, j int) bool {
		return charMetaList[i].Code < charMetaList[j].Code ||
			charMetaList[i].Code == charMetaList[j].Code && charMetaList[i].Seq < charMetaList[j].Seq
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

	// 遍历词汇表
	for phrase, freq := range phraseFreqSet {
		phrase := []rune(phrase)

		switch len(phrase) {
		case 2:
			first, second := charMetaMap[string(phrase[0])], charMetaMap[string(phrase[1])]
			for _, f := range first {
				for _, s := range second {
					if f.Sel != 0 || s.Sel != 0 {
						// 两字首选
						cf, cs := codeCharMetaMap[f.Code][0], codeCharMetaMap[s.Code][0]
						cPhrase := cf.Char + cs.Char
						tip := ""
						if cFreq, ok := phraseFreqSet[cPhrase]; ok {
							// 双首选也是词
							if cf.Back || cs.Back {
								// 如果双首选存在后置字, 则后置
								cFreq = 0
							}
							addPhrase(cPhrase, cf.Code+cs.Code, tip, cFreq)
						} else {
							// 双首选作为提示
							addPhrase("_", f.Code+s.Code, tip, 0)
							tip = cPhrase
						}
						addPhrase(f.Char+s.Char, f.Code+s.Code, tip, freq)
					}
				}
			}
		case 3:
			continue
		default:
			continue
		}
	}

	// 按词频排序
	sort.SliceStable(phraseMetaList, func(i, j int) bool {
		return phraseMetaList[i].Code < phraseMetaList[j].Code ||
			phraseMetaList[i].Code == phraseMetaList[j].Code && phraseMetaList[i].Freq > phraseMetaList[j].Freq
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
		full += supp
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
