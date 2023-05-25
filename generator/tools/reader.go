package tools

import (
	"os"
	"smyh_gen/types"
	"strconv"
	"strings"
)

func ReadDivisionTable(filepath string) (table map[string][]*types.Division, err error) {
	buffer, err := os.ReadFile(filepath)
	if err != nil {
		return
	}

	table = map[string][]*types.Division{}
	for _, line := range strings.Split(string(buffer), "\n") {
		if len(line) == 0 {
			continue
		}
		line := strings.Split(strings.TrimSpace(line), "\t")
		div := types.Division{
			Char: line[0],
			Divs: strings.Split(line[1], " "),
		}
		if len(div.Divs) > 3 {
			div.Divs[2] = div.Divs[len(div.Divs)-1]
			div.Divs = div.Divs[:3]
		}
		table[div.Char] = append(table[div.Char], &div)
	}

	return
}

func ReadCharSimpTable(filepath string) (table map[string][]*types.CharSimp, err error) {
	buffer, err := os.ReadFile(filepath)
	if err != nil {
		return
	}

	table = map[string][]*types.CharSimp{}
	for _, line := range strings.Split(string(buffer), "\n") {
		if len(line) == 0 {
			continue
		}
		if strings.HasPrefix(line, "#") {
			continue
		}

		line := strings.Split(strings.TrimSpace(line), "\t")
		simp := types.CharSimp{
			Char: line[0],
			Simp: line[1],
		}
		table[simp.Char] = append(table[simp.Char], &simp)
	}

	return
}

func ReadCompMap(filepath string) (mappings map[string]string, err error) {
	buffer, err := os.ReadFile(filepath)
	if err != nil {
		return
	}

	mappings = map[string]string{}
	for _, line := range strings.Split(string(buffer), "\n") {
		if len(line) == 0 {
			continue
		}
		line := strings.Split(strings.TrimSpace(line), "\t")
		code, comp := line[0], line[1]
		mappings[comp] = code
	}

	return
}

func ReadCharFreq(filepath string) (freqSet map[string]int64, err error) {
	buffer, err := os.ReadFile(filepath)
	if err != nil {
		return
	}

	freqSet = map[string]int64{}
	for _, line  := range strings.Split(string(buffer), "\n") {
		if len(line) == 0 {
			continue
		}
		line := strings.Split(strings.TrimSpace(line), "\t")
		char, freqStr := line[0], line[1]
		freq, _ := strconv.ParseFloat(freqStr, 64)
		freqSet[char] = int64(freq * 100000000)
	}

	return
}

func ReadPhraseFreq(filepath string) (freqSet map[string]int64, err error) {
	buffer, err := os.ReadFile(filepath)
	if err != nil {
		return
	}

	freqSet = map[string]int64{}
	lines := strings.Split(string(buffer), "\n")
	for i, line := range lines {
		if len(line) == 0 {
			continue
		}
		line := strings.Split(strings.TrimSpace(line), "\t")
		// phrase, freqStr := line[0], line[1]
		// freqSet[phrase], _ = strconv.ParseInt(freqStr, 10, 64)
		phrase := line[0]
		if _, ok := freqSet[phrase]; !ok {
			freqSet[phrase] = int64(len(lines) - i)
		}
	}

	return
}
