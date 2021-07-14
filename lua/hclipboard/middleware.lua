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
    o.get_func = o.get_func

    o.set_cmds = o.set_cmds
    o.set_func = o.set_func
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
    end
    o.regdata = {''}
    o.regtype = 'v'
    return o
end

function MiddleWare:store_pending_data(rdata, rtype)
    self.pending_regdata = rdata
    self.pending_regtype = rtype
end

function MiddleWare:clear_pending_data()
    self.pending_regdata = nil
    self.pending_regtype = nil
end

function MiddleWare:set()
    local input = self.pending_regdata
    local regtype = self.pending_regtype
    if not input or not regtype or #input <= 0 then
        return
    end

    if self.set_func then
        self.set_func(input, regtype)
    else
        local stdin = uv.new_pipe(false)
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

        stdin:write(table.concat(input, '\n'), function()
            stdin:close()
        end)
    end
    self.regtype = regtype
    self.regdata = input
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
    if self.pending_regdata and self.pending_regtype then
        return {self.pending_regdata, self.pending_regtype}
    end
    if self.get_func then
        return self.get_func()
    else
        if self.handle then
            return {self.regdata, self.regtype}
        end
        local cbdata = fn.systemlist(self.get_cmds, {''}, true)
        if tbl_str_equal(cbdata, self.regdata) then
            return {cbdata, self.regtype}
        end
        return {cbdata, 'v'}
    end
end

M.new = MiddleWare.new
return M
