local M = {}
local cmd = vim.cmd
local api = vim.api
local fn = vim.fn

local mwm = require('hclipboard.middleware')

local map_tbl

local function get_tbl()
    map_tbl = map_tbl and map_tbl or {
        pbcopy = {
            copy = {['+'] = {'pbcopy'}, ['*'] = {'pbcopy'}},
            paste = {['+'] = {'pbpaste'}, ['*'] = {'pbpaste'}},
            cache_enabled = false
        },
        ['wl-copy'] = {
            copy = {
                ['+'] = {'wl-copy', '--foreground', '--type', 'text/plain'},
                ['*'] = {'wl-copy', '--foreground', '--primary', '--type', 'text/plain'}
            },
            paste = {
                ['+'] = {'wl-paste', '--no-newline'},
                ['*'] = {'wl-paste', '--no-newline', '--primary'}
            }
        },
        xclip = {
            copy = {
                ['+'] = {'xclip', '-quiet', '-i', '-selection', 'clipboard'},
                ['*'] = {'xclip', '-quiet', '-i', '-selection', 'primary'}
            },
            paste = {
                ['+'] = {'xclip', '-o', '-selection', 'clipboard'},
                ['*'] = {'xclip', '-o', '-selection', 'primary'}
            }
        },
        xsel = {
            copy = {
                ['+'] = {'xsel', '--nodetach', '-i', '-b'},
                ['*'] = {'xsel', '--nodetach', '-i', '-p'}
            },
            paste = {['+'] = {'xsel', '-o', '-b'}, ['*'] = {'xsel', '-o', '-p'}}
        },
        lemonade = {
            copy = {['+'] = {'lemonade', 'copy'}, ['*'] = {'lemonade', 'copy'}},
            paste = {['+'] = {'lemonade', 'paste'}, ['*'] = {'lemonade', 'paste'}}
        },
        doitclient = {
            copy = {['+'] = {'doitclient', 'wclip'}, ['*'] = {'doitclient', 'wclip'}},
            paste = {['+'] = {'doitclient', 'wclip', '-r'}, ['*'] = {'doitclient', 'wclip', '-r'}}
        },
        win32yank = {
            copy = {
                ['+'] = {'win32yank.exe', '-i', '--crlf'},
                ['*'] = {'win32yank.exe', '-i', '--crlf'}
            },
            paste = {
                ['+'] = {'win32yank.exe', '-o', '--lf'},
                ['*'] = {'win32yank.exe', '-o', '--lf'}
            }
        },
        ['termux-clipboard'] = {
            copy = {['+'] = {'termux-clipboard-set'}, ['*'] = {'termux-clipboard-set'}},
            paste = {['+'] = {'termux-clipboard-get'}, ['*'] = {'termux-clipboard-get'}}
        },
        tmux = {
            copy = {['+'] = {'tmux', 'load-buffer', '-'}, ['*'] = {'tmux', 'load-buffer', '-'}},
            paste = {['+'] = {'tmux', 'save-buffer', '-'}, ['*'] = {'tmux', 'save-buffer', '-'}}
        }
    }
    return map_tbl
end

local function map_provider(name)
    local mapped = get_tbl()[name]
    if mapped then
        if name == 'win32yank' then
            if fn.has('wsl') and fn.getftype(fn.exepath('win32yank.exe')) == 'link' then
                local win32yank = fn.resolve(fn.exepath('win32yank.exe'))
                mapped.copy['+'][1] = win32yank
                mapped.copy['*'][1] = win32yank
                mapped.paste['+'][1] = win32yank
                mapped.paste['*'][1] = win32yank
            end
        end
        if mapped.cache_enabled == nil then
            mapped.cache_enabled = true
        end
        mapped[name] = name
        mapped = vim.deepcopy(mapped)
    end
    return mapped
end

local function parse_action(dict, key, regname)
    local function viml_func_name(k, rname)
        local func_name = api.nvim_exec(([[echo g:hclipboard.%s[%q] ]]):format(k, rname), true)
        local lambda_name = func_name:match('<lambda>%d+')
        if lambda_name then
            func_name = lambda_name
        end
        return func_name
    end

    local action = dict[key][regname]
    local atype = type(action)

    local cmds, func
    if atype == 'userdata' and action == vim.NIL then
        -- vimscript -> lua, function can't be transformed directly
        -- get the name of function in vimscript instead of function reference
        local func_name = viml_func_name(key, regname)
        func = fn[func_name]
    elseif atype == 'string' then
        cmds = vim.split(action, '%s+')
    else
        cmds = action
    end
    return cmds, func
end

function M.do_once(method, regname, lines, regtype)
    local hcb = vim.g.hclipboard
    if not hcb or type(hcb) ~= 'table' or vim.tbl_isempty(hcb) then
        vim.g.clipboard = nil
        local pname = fn['provider#clipboard#Executable']()
        hcb = map_provider(pname)
        if not hcb then
            api.nvim_echo({
                {
                    'clipboard: No clipboard tool.:help clipboard or open an issue to nvim-hclipboard',
                    'Error'
                }
            }, true, {})
            M.clear()
            return
        end
    end

    for rname in pairs(hcb.copy) do
        local get_cmds, get_func = parse_action(hcb, 'paste', rname)
        local set_cmds, set_func = parse_action(hcb, 'copy', rname)
        local mw = mwm.new({
            regname = rname,
            set_cmds = set_cmds,
            set_func = set_func,
            get_cmds = get_cmds,
            get_func = get_func,
            cache_enabled = hcb.cache_enabled
        })
        hcb.paste[rname] = function()
            return mw:get()
        end
        hcb.copy[rname] = function(rdata, rtype)
            -- hclipboard need context within TextYankPost, but `setreg` or `let @` can't fire
            -- TextYankPost event, so store the data and type for schedule fucntion to make sure
            -- that it is called after TextYankPost
            mw:store_pending_data(rdata, rtype)
            vim.schedule(function()
                mw:set()
                mw:clear_pending_data()
            end)
        end
        mwm.set(rname, mw)
    end

    vim.g.clipboard = hcb

    fn['provider#clipboard#Executable']()

    cmd([[
        aug HClipBoard
            au!
            au TextYankPost * lua require('hclipboard.action').send()
        aug END
     ]])

    if method == 'get' then
        return hcb.paste[regname]()
    else
        hcb.copy[regname](lines, regtype)
    end
end

function M.clear()
    local hcb = vim.g.hclipboard
    if not hcb or type(hcb) ~= 'table' or vim.tbl_isempty(hcb) then
        vim.g.clipboard = nil
    else
        cmd([[let g:clipboard = g:hclipboard]])
    end
    vim.g.hclipboard = nil
    mwm.clear()
    pcall(cmd, [[
        au! HClipBoard
        aug! HClipBoard
    ]])
    fn['provider#clipboard#Executable']()
end

return M
