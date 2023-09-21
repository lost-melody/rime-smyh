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
---@field empty fun(self): boolean
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
---@field process_key fun(self, key_event: KeyEvent): boolean
---@field compose fun(self, ctx: Context)
---@field commit_text fun(self, text: string)
---@field apply_schema fun(self, schema: Schema)
local _Engin

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
---@field commit fun(self)
---@field get_commit_text fun(self): string
---@field get_script_text fun(self): string
---@field get_preedit fun(self): Preedit
---@field is_composing fun(self): boolean
---@field has_menu fun(self): boolean
---@field get_selected_candidate fun(self): Candidate
---@field push_input fun(self, text: string)
---@field pop_input fun(self, num: integer): boolean
---@field delete_input function
---@field clear fun(self)
---@field select fun(self, index: integer): boolean 通過下標選擇候選詞, 從0開始
---@field confirm_current_selection function
---@field delete_current_selection fun(self): boolean
---@field confirm_previous_selection function
---@field reopen_previous_selection function
---@field clear_previous_segment function
---@field reopen_previous_segment function
---@field clear_non_confirmed_composition function
---@field refresh_non_confirmed_composition function
---@field set_option function
---@field get_option function
---@field set_property fun(self, key: string, value: string) 與 `get_property` 配合使用, 在組件之間傳遞消息
---@field get_property fun(self, key: string): string 與 `set_property` 配合使用, 在組件之間傳遞消息
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
local _Schema

---@class KeyEvent
---element
---@field keycode integer
---@field modifier unknown
---method
---@field shift fun(self): boolean
---@field ctrl fun(self): boolean
---@field alt fun(self): boolean
---@field caps fun(self): boolean
---@field super fun(self): boolean
---@field release fun(self): boolean
---@field repr fun(self): string 返回按鍵字符, 如 "1", "a", "space", "Shift_L", "Release+space"
---@field eq fun(self, key: KeyEvent): boolean
---@field lt fun(self, key: KeyEvent): boolean
local _KeyEvent

---@class Composition
local _Composition

---@class Notifier
local _Notifier

---@class OptionUpdateNotifier
local _OptionUpdateNotifier

---@class PropertyUpdateNotifier
local _PropertyUpdateNotifier

---@class KeyEventNotifier
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
---@field get_candidate_at fun(self, index: integer): Candidate 獲取指定下標的候選, 從0開始
---@field get_selected_candidate fun(self): Candidate
local _Segment

---@class Segmentation
---element
---@field input string
---method
---@field empty fun(self): boolean
---@field back fun(self): Segment
---@field pop_back fun(self): Segment
---@field reset_length function
---@field add_segment fun(self, seg: Segment)
---@field forward function
---@field trim fun(self)
---@field has_finished_segmentation fun(self): boolean
---@field get_current_start_position fun(self): integer
---@field get_current_end_position fun(self): integer
---@field get_current_segment_length fun(self): integer
---@field get_confirmed_position fun(self): integer
local _Segmentation

---@class Candidate
local _Candidate

---@class Menu
local _Menu

---@class Translation
---method
---@field iter fun(self): fun(self), integer
local _Translation

---@class Config
local _Config

---@class ConfigItem
---element
---@field type ConfigType
---@field empty unknown
---method
---@field get_value fun(self): ConfigValue|nil
---@field get_map fun(self): ConfigMap|nil
---@field get_list fun(self): ConfigList|nil
local _ConfigItem

---@class ConfigValue
---element
---@field type ConfigType
---@field value string
---@field element ConfigItem
---method
---@field get_string fun(self): string
---@field get_bool fun(self): boolean|nil
---@field get_int fun(self): integer|nil
---@field get_double fun(self): number|nil
---@field set_string fun(self, s: string)
---@field set_bool fun(self, b: boolean)
---@field set_int fun(self, i: integer)
---@field set_double fun(self, f: number)
local _ConfigValue

---@class ConfigMap
---element
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---method
---@field empty fun(self): boolean
---@field has_key fun(self, key: string): boolean
---@field keys fun(self): string[]
---@field get fun(self, key: string): ConfigItem|nil
---@field get_value fun(self, key: string): ConfigValue|nil
---@field set fun(self, key: string, item: ConfigItem)
---@field clear fun(self)
local _ConfigMap

---@class ConfigList
---element
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---method
---@field empty fun(self): boolean
---@field get_at fun(self, index: integer): ConfigItem|nil
---@field get_value_at fun(self, index: integer): ConfigValue|nil
---@field set_at fun(self, index: integer, item: ConfigItem)
---@field append function
---@field insert function
---@field clear function
---@field resize function
local _ConfigList

---任意類型元素集合
---將形如 `{'a','b','c'}` 的列表轉換爲形如 `{a=true,b=true,c=true}` 的集合
---@param values any[]
---@return Set
function librime.New.Set(values)
    return Set(values)
end

return librime
