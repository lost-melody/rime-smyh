---wafel 核心庫, 給出 librime 的類型定義
---
---# References:
---
---- *LuaLS* 文檔: [Annotations](https://luals.github.io/wiki/annotations/)
---- *librime-lua* 文檔: [Scripting](https://github.com/hchunhui/librime-lua/wiki/Scripting)
---- *librime-lua* 類型定義: [src/types.cc](https://github.com/hchunhui/librime-lua/blob/master/src/types.cc)
---- *librime* 類型定義: [src/rime](https://github.com/rime/librime/tree/master/src/rime)
local librime = {}

-- 暫時不清楚的類型定義爲 `unknown`,
-- 不清楚的方法定義爲 `function`,
-- 後續將通過 *librime* 和 *librime-lua* 源碼進一步補全

---配置節點類型枚舉
---@enum ConfigType
librime.config_types = {
    kNull   = "kNull",   -- 空節點
    kScalar = "kScalar", -- 純數據節點
    kList   = "kList",   -- 列表節點
    kMap    = "kMap",    -- 字典節點
}

---分詞片段類型枚舉
---@enum SegmentType
librime.segment_types = {
    kVoid      = "kVoid",
    kGuess     = "kGuess",
    kSelected  = "kSelected",
    kConfirmed = "kConfirmed",
}

---對 *librime-lua* 構造方法的封裝
---例如原先構造候選項的方法:
--- `Candidate(type, start, _end, text, comment)`
---可封裝爲:
--- `librime.New.Candidate(type, start, _end, text, comment)`
--- `librime.New.Candidate({type="", start=1, _end=2, text=""})`
---實現, 增加了語法提示, 也允許一些個性化的封裝
librime.New = {}

---@class Set
---method
---@field empty fun(self: self): boolean
---@field __index function
---@field __add function
---@field __sub function
---@field __mul function
---@field __set function
local _Set

---@class Env
---element
---@field engine Engine
---@field name_space string
local _Env

---@class Engine
---element
---@field schema Schema
---@field context Context
---@field active_engine Engine
---method
---@field process_key fun(self: self, key_event: KeyEvent): boolean
---@field compose fun(self: self, ctx: Context)
---@field commit_text fun(self: self, text: string)
---@field apply_schema fun(self: self, schema: Schema)
local _Engine

---@class Context
---element
---@field composition Composition
---@field input string
---@field caret_pos integer
---@field commit_notifier Notifier
---@field select_notifier Notifier
---@field update_notifier Notifier
---@field delete_notifier Notifier
---@field option_update_notifier OptionUpdateNotifier
---@field property_notifier PropertyUpdateNotifier
---@field unhandled_key_notifier KeyEventNotifier
---method
---@field commit fun(self: self)
---@field get_commit_text fun(self: self): string
---@field get_script_text fun(self: self): string
---@field get_preedit fun(self: self): Preedit
---@field is_composing fun(self: self): boolean
---@field has_menu fun(self: self): boolean
---@field get_selected_candidate fun(self: self): Candidate
---@field push_input fun(self: self, text: string)
---@field pop_input fun(self: self, num: integer): boolean
---@field delete_input function
---@field clear fun(self: self)
---@field select fun(self: self, index: integer): boolean 通過下標選擇候選詞, 從0開始
---@field confirm_current_selection function
---@field delete_current_selection fun(self: self): boolean
---@field confirm_previous_selection function
---@field reopen_previous_selection function
---@field clear_previous_segment function
---@field reopen_previous_segment function
---@field clear_non_confirmed_composition function
---@field refresh_non_confirmed_composition function
---@field set_option function
---@field get_option function
---@field set_property fun(self: self, key: string, value: string) 與 `get_property` 配合使用, 在組件之間傳遞消息
---@field get_property fun(self: self, key: string): string 與 `set_property` 配合使用, 在組件之間傳遞消息
---@field clear_transient_options function
local _Context

---@class Preedit
---element
---@field text string
---@field caret_pos integer
---@field sel_start integer
---@field sel_end integer
local _Preedit

---@class Schema
---element
---@field schema_id string
---@field schema_name string
---@field config Config
---@field page_size integer
---@field select_keys string
local _Schema

---@class KeyEvent
---element
---@field keycode integer
---@field modifier unknown
---method
---@field shift fun(self: self): boolean
---@field ctrl fun(self: self): boolean
---@field alt fun(self: self): boolean
---@field caps fun(self: self): boolean
---@field super fun(self: self): boolean
---@field release fun(self: self): boolean
---@field repr fun(self: self): string 返回按鍵字符, 如 "1", "a", "space", "Shift_L", "Release+space"
---@field eq fun(self: self, key: KeyEvent): boolean
---@field lt fun(self: self, key: KeyEvent): boolean
local _KeyEvent

---@class Composition
---method
---@field empty fun(self: self): boolean
---@field back fun(self: self): Segment
---@field pop_back fun(self: self)
---@field push_back fun(self: self)
---@field has_finished_composition fun(self: self): boolean
---@field get_prompt fun(self: self): string
---@field toSegmentation fun(self: self): Segmentation
local _Composition

---@class Notifier
---method
---@field connect fun(self: self, f: function, group: integer|nil): function[]
local _Notifier

---@class OptionUpdateNotifier: Notifier
local _OptionUpdateNotifier

---@class PropertyUpdateNotifier: Notifier
local _PropertyUpdateNotifier

---@class KeyEventNotifier: Notifier
local _KeyEventNotifier

---@class Segment
---element
---@field status SegmentType
---@field start integer
---@field _start integer
---@field _end integer
---@field length integer
---@field tags Set
---@field menu Menu
---@field selected_index integer
---@field prompt string
---method
---@field clear function
---@field close function
---@field reopen function
---@field has_tag function
---@field get_candidate_at fun(self: self, index: integer): Candidate 獲取指定下標的候選, 從0開始
---@field get_selected_candidate fun(self: self): Candidate
local _Segment

---@class Segmentation
---element
---@field input string
---method
---@field empty fun(self: self): boolean
---@field back fun(self: self): Segment
---@field pop_back fun(self: self): Segment
---@field reset_length function
---@field add_segment fun(self: self, seg: Segment)
---@field forward function
---@field trim fun(self: self)
---@field has_finished_segmentation fun(self: self): boolean
---@field get_current_start_position fun(self: self): integer
---@field get_current_end_position fun(self: self): integer
---@field get_current_segment_length fun(self: self): integer
---@field get_confirmed_position fun(self: self): integer
local _Segmentation

---@class Candidate
---element
---@field type string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---method
---@field get_dynamic_type fun(self: self): "Phrase"|"Simple"|"Shadow"|"Uniquified"|"Other"
---@field get_genuine fun(self: self): Candidate
---@field get_genuines fun(self: self): Candidate[]
---@field to_shadow_candidate fun(self: self): ShadowCandidate
---@field to_uniquified_candidate fun(self: self): UniquifiedCandidate
---@field append fun(self: self, c: unknown)
local _Candidate

---@class UniquifiedCandidate: Candidate
local _UniquifiedCandidate

---@class ShadowCandidate: Candidate
local _ShadowCandidate

---@class Phrase
---element
---@field language string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field code Code
---@field entry DictEntry
---method
---@field toCandidate fun(self: self): Candidate
local _Phrase

---@class Menu
---method
---@field add_translation fun(self: self, translation: Translation)
---@field prepare function
---@field get_candidate_at fun(self: self, i: integer): Candidate|nil
---@field candidate_count fun(self: self): integer
---@field empty fun(self: self): boolean
local _Menu

---@class Translation
---method
---@field iter fun(self: self): function, integer
local _Translation

---@class Config
---method
---@field load_from_file function
---@field save_to_file function
---@field is_null fun(self: self, conf_path: string): boolean
---@field is_value fun(self: self, conf_path: string): boolean
---@field is_list fun(self: self, conf_path: string): boolean
---@field is_map fun(self: self, conf_path: string): boolean
---@field get_string fun(self: self, conf_path: string): string
---@field get_bool fun(self: self, conf_path: string): boolean|nil
---@field get_int fun(self: self, conf_path: string): integer|nil
---@field get_double fun(self: self, conf_path: string): number|nil
---@field set_string fun(self: self, conf_path: string, s: string)
---@field set_bool fun(self: self, conf_path: string, b: boolean)
---@field set_int fun(self: self, conf_path: string, i: integer)
---@field set_double fun(self: self, conf_path: string, f: number)
---@field get_item fun(self: self, conf_path: string): ConfigItem|nil
---@field set_item fun(self: self, conf_path: string, item: ConfigItem)
---@field get_value fun(self: self, conf_path: string): ConfigValue|nil
---@field set_value fun(self: self, conf_path: string, value: ConfigValue)
---@field get_list fun(self: self, conf_path: string): ConfigList|nil
---@field set_list fun(self: self, conf_path: string, list: ConfigList)
---@field get_map fun(self: self, conf_path: string): ConfigMap|nil
---@field set_map fun(self: self, conf_path: string, map: ConfigMap)
---@field get_list_size fun(self: self, conf_path: string): integer|nil
local _Config

---@class ConfigItem
---element
---@field type ConfigType
---@field empty unknown
---method
---@field get_value fun(self: self): ConfigValue|nil
---@field get_map fun(self: self): ConfigMap|nil
---@field get_list fun(self: self): ConfigList|nil
local _ConfigItem

---@class ConfigValue
---element
---@field type ConfigType
---@field value string
---@field element ConfigItem
---method
---@field get_string fun(self: self): string
---@field get_bool fun(self: self): boolean|nil
---@field get_int fun(self: self): integer|nil
---@field get_double fun(self: self): number|nil
---@field set_string fun(self: self, s: string)
---@field set_bool fun(self: self, b: boolean)
---@field set_int fun(self: self, i: integer)
---@field set_double fun(self: self, f: number)
local _ConfigValue

---@class ConfigMap
---element
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---method
---@field empty fun(self: self): boolean
---@field has_key fun(self: self, key: string): boolean
---@field keys fun(self: self): string[]
---@field get fun(self: self, key: string): ConfigItem|nil
---@field get_value fun(self: self, key: string): ConfigValue|nil
---@field set fun(self: self, key: string, item: ConfigItem)
---@field clear fun(self: self)
local _ConfigMap

---@class ConfigList
---element
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---method
---@field empty fun(self: self): boolean
---@field get_at fun(self: self, index: integer): ConfigItem|nil
---@field get_value_at fun(self: self, index: integer): ConfigValue|nil
---@field set_at fun(self: self, index: integer, item: ConfigItem)
---@field append function
---@field insert function
---@field clear function
---@field resize function
local _ConfigList

---@class Opencc
---method
---@field convert function
local _Opencc

---@class ReverseDb
---method
---@field lookup function
local _ReverseDb

---@class ReverseLookup
---method
---@field lookup fun(self: self, key: string): string "百" => "bai bo"
---@field lookup_stems fun(self: self, key: string): string
local _ReverseLookup

---@class DictEntry
---element
---@field text string
---@field comment string
---@field preedit string
---@field weight number `13.33`, `-13.33`
---@field commit_count integer `2`
---@field custom_code string "hao", "ni hao"
---@field remaining_code_length integer "~ao"
---@field code Code
local _DictEntry

---@class CommitEntry: DictEntry
---method
---@field get function
local _CommitEntry

---@class Code
---method
---@field push fun(self: self, inputCode: unknown)
---@field print fun(self: self): string
local _Code

---@class Memory
---method
---@field dict_lookup fun(self: self, input: string, predictive: boolean, limit: integer): boolean
---@field user_lookup fun(self: self, input: string, predictive: boolean): boolean
---@field memorize fun(self: self, callback: fun(ce: CommitEntry))
---@field decode fun(self: self, code: Code): { number: string }
---@field iter_dict fun(self: self): function, integer
---@field iter_user fun(self: self): function, integer
---@field update_userdict fun(self: self, entry: DictEntry, commits: number, prefix: string): boolean
local _Memory

---@class Projection
---method
---@field load fun(self: self, rules: ConfigList)
---@field apply fun(self: self, str: string, ret_org_str: boolean|nil): string
local _Projection

---@class LevelDb
---method
---@field open fun(self: self): boolean
---@field open_read_only fun(self: self): boolean
---@field close fun(self: self): boolean
---@field loaded fun(self: self): boolean
---@field query fun(self: self, prefix: string): DbAccessor
---@field fetch fun(self: self, key: string): string|nil
---@field update fun(self: self, key: string, value: string): boolean
---@field erase fun(self: self, key: string): boolean
local _LevelDb

---@class DbAccessor
---method
---@field reset fun(self: self): boolean
---@field jump fun(self: self, prefix: string): boolean
---@field iter fun(self: self): function, self
local _DbAccessor

---任意類型元素集合
---將形如 `{'a','b','c'}` 的列表轉換爲形如 `{a=true,b=true,c=true}` 的集合
---@param values any[]
---@return Set
function librime.New.Set(values)
    ---@diagnostic disable-next-line: undefined-global
    return Set(values)
end

---分词片段
---@param start_pos integer 開始下標
---@param end_pos integer 結束下標
---@return Segment
function librime.New.Segment(start_pos, end_pos)
    ---@diagnostic disable-next-line: undefined-global
    return Segment(start_pos, end_pos)
end

---方案
---@param schema_id string
---@return Schema
function librime.New.Schema(schema_id)
    ---@diagnostic disable-next-line: undefined-global
    return Schema(schema_id)
end

---配置值, 繼承自 ConfigItem
---@param str string 值, 卽 `get_string` 方法查詢的值
---@return ConfigValue
function librime.New.ConfigValue(str)
    ---@diagnostic disable-next-line: undefined-global
    return ConfigValue(str)
end

---候選詞
---@param type string 類型標識
---@param start integer 分詞開始
---@param _end integer 分詞結束
---@param text string 候選詞内容
---@param comment string 註解
---@return Candidate
function librime.New.Candidate(type, start, _end, text, comment)
    ---@diagnostic disable-next-line: undefined-global
    return Candidate(type, start, _end, text, comment)
end

---衍生擴展詞
---@param cand Candidate 基础候選詞
---@param type string 類型標識
---@param text string 分詞開始
---@param comment string 註解
---@param inherit_comment unknown
---@return ShadowCandidate
function librime.New.ShadowCandidate(cand, type, text, comment, inherit_comment)
    ---@diagnostic disable-next-line: undefined-global
    return ShadowCandidate(cand, type, text, comment, inherit_comment)
end

---候選詞
---@param memory Memory
---@param typ string
---@param start integer
---@param _end integer
---@param entry DictEntry
---@return Phrase
function librime.New.Phrase(memory, typ, start, _end, entry)
    ---@diagnostic disable-next-line: undefined-global
    return Phrase(memory, typ, start, _end, entry)
end

---Opencc
---@param filename string
---@return Opencc
function librime.New.Opencc(filename)
    ---@diagnostic disable-next-line: undefined-global
    return Opencc(filename)
end

---反查詞典
---@param file_name string
---@return ReverseDb
function librime.New.ReverseDb(file_name)
    ---@diagnostic disable-next-line: undefined-global
    return ReverseDb(file_name)
end

---反查接口
---@param dict_name string
---@return ReverseLookup
function librime.New.ReverseLookup(dict_name)
    ---@diagnostic disable-next-line: undefined-global
    return ReverseLookup(dict_name)
end

---詞典候選詞結果
---@return DictEntry
function librime.New.DictEntry()
    ---@diagnostic disable-next-line: undefined-global
    return DictEntry()
end

---編碼
---@return Code
function librime.New.Code()
    ---@diagnostic disable-next-line: undefined-global
    return Code()
end

---詞典處理接口
---@param engine Engine
---@param schema Schema
---@param namespace string|nil
---@return Memory
function librime.New.Memory(engine, schema, namespace)
    ---@diagnostic disable-next-line: undefined-global
    return Memory(engine, schema, namespace)
end

---候選詞註釋轉換
---@return Projection
function librime.New.Projection()
    ---@diagnostic disable-next-line: undefined-global
    return Projection()
end

---LevelDB
---@return LevelDb
function librime.New.LevelDb(dbname)
    ---@diagnostic disable-next-line: undefined-global
    return LevelDb(dbname)
end

return librime
