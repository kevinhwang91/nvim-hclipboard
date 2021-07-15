local M = {}

local mwm = require('hclipboard.middleware')
local user_bypass_cb

local function init()
    local conf = require('hclipboard')._config or {}
    vim.validate({user_bypass_cb = {conf.should_bypass_cb, 'function', true}})
    user_bypass_cb = conf.should_bypass_cb
end

local function should_bypass(rname)
    local ret = false
    local ev = vim.v.event
    if user_bypass_cb then
        ret = user_bypass_cb(rname, ev)
    else
        if ev.visual and ev.operator == 'c' then
            if ev.regname == '' or ev.regname == rname then
                ret = true
            end
        end
    end
    return ret
end

function M.send()
    local rname = vim.v.register
    local mw = mwm.get(rname)

    if not mw then
        return
    end

    if not should_bypass(rname) then
        mw:set()
    end
    mw:clear_pending_data()
end

function M.receive(regname)
    return mwm.get(regname):get()
end

init()

return M
