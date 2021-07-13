local M = {}
local cmd = vim.cmd
local fn = vim.fn

local initialized

function M.setup(opts)
    if initialized then
        return
    end

    opts = opts or {}

    M._config = opts
    initialized = true
    return M
end

function M.start()
    M.setup()
    cmd([[let g:hclipboard = get(g:, 'clipboard', {})]])
    local cb = vim.g.clipboard or {}
    cb.name = 'hclipboard'
    cb.copy = cb.copy or {['*'] = true, ['+'] = true}
    cb.paste = cb.paste or {}
    for rname in pairs(cb.copy) do
        cb.copy[rname] = function()
            require('hclipboard.boot').do_once('set', rname)
        end
        cb.paste[rname] = function()
            return require('hclipboard.boot').do_once('get', rname)
        end
    end
    vim.g.clipboard = cb
    fn['provider#clipboard#Executable']()
end

return M