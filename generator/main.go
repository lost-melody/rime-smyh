package main

import (
	"bytes"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"smyh_gen/tools"
	"smyh_gen/types"
)

type Args struct {
	Foo string
}

var (
	_    interface{} = (fmt.Stringer)(nil)
	_    interface{} = (*types.CharMeta)(nil)
	args Args
)

func main() {
	parseFlags()

	divTable, err := tools.ReadDivisionTable("../table/smyh_div.txt")
	if err != nil {
		log.Fatalln(err)
	}
	simpTable, err := tools.ReadCharSimpTable("../table/smyh_simp.txt")
	if err != nil {
		log.Fatalln(err)
	}
	compMap, err := tools.ReadCompMap("../table/smyh_map.txt")
	if err != nil {
		log.Fatalln(err)
	}
	freqSet, err := tools.ReadCharFreq("../table/freq.txt")
	if err != nil {
		log.Fatalln(err)
	}
	phraseFreqSet, err := tools.ReadPhraseFreq("../table/phrase.txt")
	if err != nil {
		log.Fatalln(err)
	}

	charMetaList := tools.BuildCharMetaList(divTable, simpTable, compMap, freqSet)
	charMetaMap := tools.BuildCharMetaMap(charMetaList)
	codeCharMetaMap := tools.BuildCodeCharMetaMap(charMetaList)
	fullCodeMetaList := tools.BuildFullCodeMetaList(divTable, compMap, freqSet, charMetaMap)
	phraseMetaList, phraseTipList := tools.BuildSmartPhraseList(charMetaMap, codeCharMetaMap, phraseFreqSet)
	fmt.Println("charMetaList:", len(charMetaList))
	fmt.Println("fullCodeMetaList:", len(fullCodeMetaList))
	fmt.Println("charMetaMap:", len(charMetaMap))
	fmt.Println("codeCharMetaMap:", len(codeCharMetaMap))
	fmt.Println("phraseFreqSet:", len(phraseFreqSet))
	fmt.Println("phraseMetaList:", len(phraseMetaList))
	fmt.Println("phraseTipList:", len(phraseTipList))

	buffer := bytes.Buffer{}

	// CHAR
	buffer.Truncate(0)
	for _, charMeta := range charMetaList {
		buffer.WriteString(fmt.Sprintf("%s\t%s\t%d\n", charMeta.Char, charMeta.Code, charMeta.Freq))
	}
	err = os.WriteFile("/tmp/char.txt", buffer.Bytes(), 0644)
	if err != nil {
		log.Fatalln(err)
	}

	// FULLCHAR
	buffer.Truncate(0)
	for _, charMeta := range fullCodeMetaList {
		buffer.WriteString(fmt.Sprintf("%s\t%s\n", charMeta.Char, charMeta.Code))
	}
	err = os.WriteFile("/tmp/fullcode.txt", buffer.Bytes(), 0644)
	if err != nil {
		log.Fatalln(err)
	}

	// DIVISION
	buffer.Truncate(0)
	accessedDiv := map[string]struct{}{}
	for _, charMeta := range charMetaList {
		for _, divs := range divTable[charMeta.Char] {
			if _, ok := accessedDiv[charMeta.Char]; ok {
				continue
			}
			accessedDiv[charMeta.Char] = struct{}{}
			div := strings.Join(divs.Divs, "")
			buffer.WriteString(fmt.Sprintf("%s\t[%s|%s]\n", charMeta.Char, div, charMeta.Full))
		}
	}
	err = os.WriteFile("/tmp/div.txt", buffer.Bytes(), 0644)
	if err != nil {
		log.Fatalln(err)
	}

	// PHRASE
	buffer.Truncate(0)
	for _, phraseMeta := range phraseMetaList {
		buffer.WriteString(fmt.Sprintf("%s\t%s\n", phraseMeta.Phrase, phraseMeta.Code))
	}
	err = os.WriteFile("/tmp/phrase.txt", buffer.Bytes(), 0644)
	if err != nil {
		log.Fatalln(err)
	}

	// buffer.Truncate(0)
	// phraseTipSet := map[string][]string{}
	// for _, phraseTip := range phraseTipList {
	// 	phraseTipSet[phraseTip.Phrase] = append(phraseTipSet[phraseTip.Phrase], phraseTip.CPhrase)
	// }
	// for phrase, cPhrases := range phraseTipSet {
	// 	buffer.WriteString(fmt.Sprintf("%s\t%s\n", phrase, strings.Join(cPhrases, " ")))
	// }
	// err = os.WriteFile("/tmp/tip.txt", buffer.Bytes(), 0644)
	// if err != nil {
	// 	log.Fatalln(err)
	// }
}

func parseFlags() {
	flag.StringVar(&args.Foo, "foo", "bar", "nothing here")
	flag.Parse()
}
