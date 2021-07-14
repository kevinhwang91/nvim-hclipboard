local M = {}

local mwm = require('hclipboard.middleware')
local user_passby_cb

local function init()
    local conf = require('hclipboard')._config or {}
    vim.validate({user_passby_cb = {conf.should_passby_cb, 'function', true}})
    user_passby_cb = conf.should_passby_cb
end

local function should_passby(rname)
    local ret = false
    local ev = vim.v.event
    if user_passby_cb then
        ret = user_passby_cb(rname, ev)
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

    if not should_passby(rname) then
        mw:set()
    end
    mw:clear_pending_data()
end

function M.receive(regname)
    return mwm.get(regname):get()
end

init()

return M
