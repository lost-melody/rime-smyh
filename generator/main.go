package main

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"sort"
	"strings"

	"smyh_gen/tools"
	"smyh_gen/utils"
)

type Args struct {
	Div    string `flag:"d" usage:"smyh_div.txt"  default:"../table/smyh_div.txt"`
	Simp   string `flag:"s" usage:"smyh_simp.txt" default:"../table/smyh_simp.txt"`
	Map    string `flag:"m" usage:"smyh_map.txt"  default:"../table/smyh_map.txt"`
	Freq   string `flag:"f" usage:"freq.txt"      default:"../table/freq.txt"`
	White  string `flag:"w" usage:"whitelist.txt" default:"../table/cjkext_whitelist.txt"`
}

var args Args

func main() {
	err := utils.ParseFlags(&args)
	if err != nil {
		return
	}

	divTable, err := tools.ReadDivisionTable(args.Div)
	if err != nil {
		log.Fatalln(err)
	}
	simpTable, err := tools.ReadCharSimpTable(args.Simp)
	if err != nil {
		log.Fatalln(err)
	}
	compMap, err := tools.ReadCompMap(args.Map)
	if err != nil {
		log.Fatalln(err)
	}
	freqSet, err := tools.ReadCharFreq(args.Freq)
	if err != nil {
		log.Fatalln(err)
	}
	cjkExtWhiteSet, err := tools.ReadCJKExtWhitelist(args.White)
	if err != nil {
		log.Fatalln(err)
	}

	charMetaList := tools.BuildCharMetaList(divTable, simpTable, compMap, freqSet, cjkExtWhiteSet)
	charMetaMap := tools.BuildCharMetaMap(charMetaList)
	codeCharMetaMap := tools.BuildCodeCharMetaMap(charMetaList)
	fullCodeMetaList := tools.BuildFullCodeMetaList(divTable, compMap, freqSet, charMetaMap)
	fmt.Println("charMetaList:", len(charMetaList))
	fmt.Println("fullCodeMetaList:", len(fullCodeMetaList))
	fmt.Println("charMetaMap:", len(charMetaMap))
	fmt.Println("codeCharMetaMap:", len(codeCharMetaMap))

	buffer := bytes.Buffer{}

	// CHAR
	buffer.Truncate(0)
	for _, charMeta := range charMetaList {
		buffer.WriteString(fmt.Sprintf("%s\t%s\t%d\n", charMeta.Char, charMeta.Code, charMeta.Freq))
	}
	err = os.WriteFile("/tmp/char.txt", buffer.Bytes(), 0o644)
	if err != nil {
		log.Fatalln(err)
	}

	// FULLCHAR
	buffer.Truncate(0)
	for _, charMeta := range fullCodeMetaList {
		buffer.WriteString(fmt.Sprintf("%s\t%s\n", charMeta.Char, charMeta.Code))
	}
	err = os.WriteFile("/tmp/fullcode.txt", buffer.Bytes(), 0o644)
	if err != nil {
		log.Fatalln(err)
	}

	// DIVISION
	buffer.Truncate(0)
	accessedDiv := map[string]struct{}{}
	sort.Slice(fullCodeMetaList, func(i, j int) bool {
		return fullCodeMetaList[i].Char < fullCodeMetaList[j].Char
	})
	for _, charMeta := range fullCodeMetaList {
		for _, divs := range divTable[charMeta.Char] {
			if _, ok := accessedDiv[charMeta.Char]; ok {
				continue
			}
			accessedDiv[charMeta.Char] = struct{}{}
			div := strings.Join(divs.Divs, "")
			buffer.WriteString(fmt.Sprintf("%s\t(%s,%s,%s,%s)\n", charMeta.Char, div, charMeta.Full, divs.Pin, divs.Set))
		}
	}
	err = os.WriteFile("/tmp/div.txt", buffer.Bytes(), 0o644)
	if err != nil {
		log.Fatalln(err)
	}
}
