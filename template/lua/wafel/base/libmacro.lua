local _module_0 = {}
local enum, os_name
do
    local _obj_0 = require("wafel.base.librime")
    enum, os_name = _obj_0.enum, _obj_0.os_name
end
local switcher
local _anon_func_0 = function(Switcher, env)
    if Switcher ~= nil then
        return Switcher(env.engine)
    end
    return nil
end
local _anon_func_1 = function(args)
    local _accum_0 = {}
    local _len_0 = 1
    for _index_0 = 1, #args do
        local arg = args[_index_0]
        _accum_0[_len_0] = '"' .. arg .. '"'
        _len_0 = _len_0 + 1
    end
    return _accum_0
end
local Macro
do
    local _class_0
    local _base_0 = {
        hijack = function(self)
            return false
        end,
        display = function(self, env, ctx, args)
            return self.name
        end,
        trigger = function(self, env, ctx, args)
            return ctx:clear()
        end,
        set_option = function(self, env, ctx, name, value, save)
            if save == nil then
                save = false
            end
            ctx:set_option(name, value)
            if save then
                switcher = switcher or _anon_func_0(Switcher, env)
            end
            if switcher and switcher:is_auto_save(name and switcher.user_config) then
                return switcher.user_config:set_bool("var/option/" .. name, value)
            end
        end,
        get_cmd_fd = function(self, cmd, args)
            local cmdargs = table.concat(_anon_func_1(args), " ")
            local cmdline = string.format("__macrowrapper() { %s ; }; __macrowrapper %s <<<''", cmd, cmdargs)
            return io.popen(cmdline, "r")
        end,
    }
    if _base_0.__index == nil then
        _base_0.__index = _base_0
    end
    _class_0 = setmetatable({
        __init = function(self, name)
            self.name = name
        end,
        __base = _base_0,
        __name = "Macro",
    }, {
        __index = _base_0,
        __call = function(cls, ...)
            local _self_0 = setmetatable({}, _base_0)
            cls.__init(_self_0, ...)
            return _self_0
        end,
    })
    _base_0.__class = _class_0
    Macro = _class_0
end
_module_0["Macro"] = Macro
local MacroTip
do
    local _class_0
    local _parent_0 = Macro
    local _base_0 = {
        display = function(self, env, ctx, args)
            if #self.name ~= 0 then
                return self.name
            else
                return self.text
            end
        end,
        trigger = function(self, env, ctx, args)
            if #self.text ~= 0 then
                env.engine:commit_text(self.text)
            end
            return _class_0.__parent.__base.trigger(self, env, ctx, args)
        end,
    }
    for _key_0, _val_0 in pairs(_parent_0.__base) do
        if
            _base_0[_key_0] == nil
            and _key_0:match("^__")
            and not (_key_0 == "__index" and _val_0 == _parent_0.__base)
        then
            _base_0[_key_0] = _val_0
        end
    end
    if _base_0.__index == nil then
        _base_0.__index = _base_0
    end
    setmetatable(_base_0, _parent_0.__base)
    _class_0 = setmetatable({
        __init = function(self, name, text)
            self.name = name
            self.text = text
        end,
        __base = _base_0,
        __name = "MacroTip",
        __parent = _parent_0,
    }, {
        __index = function(cls, name)
            local val = rawget(_base_0, name)
            if val == nil then
                local parent = rawget(cls, "__parent")
                if parent then
                    return parent[name]
                end
            else
                return val
            end
        end,
        __call = function(cls, ...)
            local _self_0 = setmetatable({}, _base_0)
            cls.__init(_self_0, ...)
            return _self_0
        end,
    })
    _base_0.__class = _class_0
    if _parent_0.__inherited then
        _parent_0.__inherited(_parent_0, _class_0)
    end
    MacroTip = _class_0
end
_module_0["MacroTip"] = MacroTip
local _anon_func_2 = function(states)
    if states ~= nil then
        return states[1]
    end
    return nil
end
local _anon_func_3 = function(states)
    if states ~= nil then
        return states[2]
    end
    return nil
end
local MacroSwitch
do
    local _class_0
    local _parent_0 = Macro
    local _base_0 = {
        display = function(self, env, ctx, args)
            if ctx:get_option(self.name) then
                return self.states[2]
            else
                return self.states[1]
            end
        end,
        trigger = function(self, env, ctx, args)
            local current_value = ctx:get_option(self.name)
            if current_value ~= nil then
                self.__class:set_option(env, ctx, self.name, not current_value, self.save)
            end
            return _class_0.__parent.__base.trigger(self, env, ctx, args)
        end,
    }
    for _key_0, _val_0 in pairs(_parent_0.__base) do
        if
            _base_0[_key_0] == nil
            and _key_0:match("^__")
            and not (_key_0 == "__index" and _val_0 == _parent_0.__base)
        then
            _base_0[_key_0] = _val_0
        end
    end
    if _base_0.__index == nil then
        _base_0.__index = _base_0
    end
    setmetatable(_base_0, _parent_0.__base)
    _class_0 = setmetatable({
        __init = function(self, name, states, save)
            if save == nil then
                save = false
            end
            self.name = name
            self.save = save
            self.states = {
                _anon_func_2(states) or "關",
                _anon_func_3(states) or "開",
            }
        end,
        __base = _base_0,
        __name = "MacroSwitch",
        __parent = _parent_0,
    }, {
        __index = function(cls, name)
            local val = rawget(_base_0, name)
            if val == nil then
                local parent = rawget(cls, "__parent")
                if parent then
                    return parent[name]
                end
            else
                return val
            end
        end,
        __call = function(cls, ...)
            local _self_0 = setmetatable({}, _base_0)
            cls.__init(_self_0, ...)
            return _self_0
        end,
    })
    _base_0.__class = _class_0
    if _parent_0.__inherited then
        _parent_0.__inherited(_parent_0, _class_0)
    end
    MacroSwitch = _class_0
end
_module_0["MacroSwitch"] = MacroSwitch
local MacroRadio
do
    local _class_0
    local _parent_0 = Macro
    local _base_0 = {
        display = function(self, env, ctx, args)
            local _list_0 = self.states
            for _index_0 = 1, #_list_0 do
                local op = _list_0[_index_0]
                if ctx:get_option(op.name) then
                    return op.display
                end
            end
            return _class_0.__parent.__base.display(self, env, ctx, args)
        end,
        trigger = function(self, env, ctx, args)
            for i, op in ipairs(self.states) do
                local value = ctx:get_option(op.name)
                if value then
                    self.__class:set_option(env, ctx, op.name, not value, self.save)
                    self.__class:set_option(env, ctx, self.states[i % #self.states + 1], value, self.save)
                    return
                end
            end
            return self.__class:set_option(env, ctx, self.states[1], true, self.save)
        end,
    }
    for _key_0, _val_0 in pairs(_parent_0.__base) do
        if
            _base_0[_key_0] == nil
            and _key_0:match("^__")
            and not (_key_0 == "__index" and _val_0 == _parent_0.__base)
        then
            _base_0[_key_0] = _val_0
        end
    end
    if _base_0.__index == nil then
        _base_0.__index = _base_0
    end
    setmetatable(_base_0, _parent_0.__base)
    _class_0 = setmetatable({
        __init = function(self, name, states, save)
            if save == nil then
                save = false
            end
            self.name = name
            self.save = save
            self.states = states or {}
        end,
        __base = _base_0,
        __name = "MacroRadio",
        __parent = _parent_0,
    }, {
        __index = function(cls, name)
            local val = rawget(_base_0, name)
            if val == nil then
                local parent = rawget(cls, "__parent")
                if parent then
                    return parent[name]
                end
            else
                return val
            end
        end,
        __call = function(cls, ...)
            local _self_0 = setmetatable({}, _base_0)
            cls.__init(_self_0, ...)
            return _self_0
        end,
    })
    _base_0.__class = _class_0
    if _parent_0.__inherited then
        _parent_0.__inherited(_parent_0, _class_0)
    end
    MacroRadio = _class_0
end
_module_0["MacroRadio"] = MacroRadio
local MacroCmd
do
    local _class_0
    local _parent_0 = Macro
    local _base_0 = {
        hijack = function(self)
            return self.hi
        end,
        display = function(self, env, ctx, args)
            if self.tip then
                return self.tip:display(env, ctx, args)
            elseif #self.name ~= 0 then
                return self.name
            elseif self.commit then
                local _with_0 = self.__class:get_cmd_fd(self.cmd, args)
                local text = _with_0:read("a")
                _with_0:close()
                return text
            else
                return ""
            end
        end,
        trigger = function(self, env, ctx, args)
            if self.tip then
                return self.tip:trigger(env, ctx, args)
            else
                do
                    local _with_0 = self.__class:get_cmd_fd(self.cmd, args)
                    local text = _with_0:read("a")
                    _with_0:close()
                    if #text ~= 0 then
                        env.engine:commit_text(text)
                    end
                end
                return _class_0.__parent.__base.trigger(self, env, ctx, args)
            end
        end,
    }
    for _key_0, _val_0 in pairs(_parent_0.__base) do
        if
            _base_0[_key_0] == nil
            and _key_0:match("^__")
            and not (_key_0 == "__index" and _val_0 == _parent_0.__base)
        then
            _base_0[_key_0] = _val_0
        end
    end
    if _base_0.__index == nil then
        _base_0.__index = _base_0
    end
    setmetatable(_base_0, _parent_0.__base)
    _class_0 = setmetatable({
        __init = function(self, name, cmd, commit, hijack)
            self.name = name
            self.cmd = cmd
            self.commit = commit
            local android, linux, darwin
            do
                local _obj_0 = enum.os_types
                android, linux, darwin = _obj_0.android, _obj_0.linux, _obj_0.darwin
            end
            if not (android == os_name or linux == os_name or darwin == os_name) then
                self.tip = MacroTip(self.name, self.cmd)
            end
            self.hi = hijack or nil
        end,
        __base = _base_0,
        __name = "MacroCmd",
        __parent = _parent_0,
    }, {
        __index = function(cls, name)
            local val = rawget(_base_0, name)
            if val == nil then
                local parent = rawget(cls, "__parent")
                if parent then
                    return parent[name]
                end
            else
                return val
            end
        end,
        __call = function(cls, ...)
            local _self_0 = setmetatable({}, _base_0)
            cls.__init(_self_0, ...)
            return _self_0
        end,
    })
    _base_0.__class = _class_0
    if _parent_0.__inherited then
        _parent_0.__inherited(_parent_0, _class_0)
    end
    MacroCmd = _class_0
end
_module_0["MacroCmd"] = MacroCmd
local MacroFunc
local _class_0
local _parent_0 = Macro
local _base_0 = {
    hijack = function(self)
        return self.hi
    end,
    display = function(self, env, ctx, args)
        if #self.name ~= 0 then
            return self.name
        else
            return self:func(args, env)
        end
    end,
    trigger = function(self, env, ctx, args)
        do
            local res = (self:func(args, env)) and #res ~= 0
            if res then
                env.engine:commit_text(res)
            end
        end
        return _class_0.__parent.__base.trigger(self, env, ctx, args)
    end,
}
for _key_0, _val_0 in pairs(_parent_0.__base) do
    if _base_0[_key_0] == nil and _key_0:match("^__") and not (_key_0 == "__index" and _val_0 == _parent_0.__base) then
        _base_0[_key_0] = _val_0
    end
end
if _base_0.__index == nil then
    _base_0.__index = _base_0
end
setmetatable(_base_0, _parent_0.__base)
_class_0 = setmetatable({
    __init = function(self, name, func, hijack)
        self.name = name
        self.func = func
        self.hi = hijack or nil
    end,
    __base = _base_0,
    __name = "MacroFunc",
    __parent = _parent_0,
}, {
    __index = function(cls, name)
        local val = rawget(_base_0, name)
        if val == nil then
            local parent = rawget(cls, "__parent")
            if parent then
                return parent[name]
            end
        else
            return val
        end
    end,
    __call = function(cls, ...)
        local _self_0 = setmetatable({}, _base_0)
        cls.__init(_self_0, ...)
        return _self_0
    end,
})
_base_0.__class = _class_0
if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
end
MacroFunc = _class_0
_module_0["MacroFunc"] = MacroFunc
return _module_0
