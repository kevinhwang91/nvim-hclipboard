local M = {}
local fn = vim.fn
local uv = vim.loop

local middleware_tbl = {}
local MiddleWare = {cache_enabled = true}

function M.get(regname)
    return middleware_tbl[regname]
end

function M.set(regname, middleware)
    middleware_tbl[regname] = middleware
end

function MiddleWare.new(o)
    local self = MiddleWare
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.regname = o.regname
    o.cache_enabled = o.cache_enabled

    o.get_cmds = o.get_cmds

    o.set_cmds = o.set_cmds
    if o.set_cmds then
        o.set_path = o.set_path or o.set_cmds[1]
        o.set_args = o.set_args
        local args = {}
        if not o.set_args then
            for i = 2, #o.set_cmds do
                table.insert(args, o.set_cmds[i])
            end
        end
        o.set_args = args
        o.handle = nil
        o.regdata = {''}
        o.regtype = 'v'
    else
        o.set_func = o.set_func
    end
    return o
end

function MiddleWare:set(input, regtype)
    local need_append = regtype ~= 'v' and regtype ~= ''
    if #input <= 0 then
        return
    end

    if self.set_func then
        if need_append then
            table.insert(input, '')
        end
        self.set_func(input, regtype)
    else
        local stdin = uv.new_pipe()
        local handle
        handle = uv.spawn(self.set_path, {
            args = self.set_args,
            stdio = {stdin},
            cmd = '/',
            detached = self.cache_enabled
        }, function(code, signal)
            handle:close()
            if self.handle == handle then
                self.handle = nil
            end
        end)

        if self.cache_enabled then
            local prev_handle = self.handle
            if prev_handle then
                vim.defer_fn(function()
                    if prev_handle and not prev_handle:is_closing() then
                        prev_handle:kill(15)
                    end
                end, 1000)
            end
            self.handle = handle
        end

        stdin:write(table.concat(input, '\n') .. (need_append and '\n' or ''), function()
            stdin:close()
        end)

        if need_append then
            table.insert(input, '')
        end
        self.regtype = regtype
        self.regdata = input
    end
end

local function tbl_str_equal(t1, t2)
    local ret = false
    if #t1 == #t2 then
        for i = 1, #t1 do
            if t1[i] ~= t2[i] then
                return ret
            end
        end
        ret = true
    end
    return ret
end

function MiddleWare:get()
    if self.handle then
        return {self.regdata, self.regtype}
    end
    local cbdata = fn.systemlist(self.get_cmds, {''}, true)
    if tbl_str_equal(cbdata, self.regdata) then
        return {cbdata, self.regtype}
    end
    return {cbdata, 'v'}
end

M.new = MiddleWare.new
return M
