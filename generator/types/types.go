package types

// Division 拆分字元
type Division struct {
	Char string   // 字符
	Divs []string // 拆分部件列表
	Pin  string   // 拼音
	Set  string   // 字集
}

// CharSimp 简码字元
type CharSimp struct {
	Char string // 字符
	Simp string // 字符简码
}

// CharMeta 编码字元
type CharMeta struct {
	Char string // 字符
	Full string // 字符提示码
	Code string // 字符全码
	Stem string // 智能词构词码
	Freq int64  // 字频
	Sel  int    // 选重编号
	Simp bool   // 字符简码
	Back bool   // 是否后置
}

// PhraseMeta 智能词元
type PhraseMeta struct {
	Phrase string // 词汇
	Code   string // 词汇编码
	Freq   int64  // 词频
}

// PhraseTip 智能词双首选字映射
type PhraseTip struct {
	Phrase  string
	CPhrase string
}
