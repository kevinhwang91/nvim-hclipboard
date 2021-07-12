local M = {}
local cmd = vim.cmd
local api = vim.api
local fn = vim.fn

local map_tbl

local function init()
    map_tbl = {
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
end

local function map_provider(name)
    local mapped = map_tbl[name]
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
    return mapped
end

local function get_viml_func(dname, rname)
    local func_name = api.nvim_exec(([[echo g:hclipboard.%s[%q] ]]):format(dname, rname), true)
    local lambda_name = func_name:match('<lambda>%d+')
    if lambda_name then
        func_name = lambda_name
    end
    return func_name
end

function M.do_once(method, regname)
    local hcb = vim.g.hclipboard
    if not hcb or type(hcb) ~= 'table' or vim.tbl_isempty(hcb) then
        vim.g.clipboard = nil
        local pname = fn['provider#clipboard#Executable']()
        hcb = map_provider(pname)
    end

    local mwm = require('hclipboard.middleware')
    for rname in pairs(hcb.copy) do
        local get_action, set_action = hcb.paste[rname], hcb.copy[rname]
        local t_ga, t_sa = type(get_action), type(set_action)

        if t_ga == 'string' then
            get_action = vim.split(get_action, '%s+')
        end
        local get_cmds
        if t_ga ~= 'userdata' or get_action ~= vim.NIL then
            get_cmds = get_action
        end

        local set_cmds, set_func
        if t_sa == 'userdata' and set_action == vim.NIL then
            local func_name = get_viml_func('copy', rname)
            set_func = vim.fn[func_name]
        elseif t_sa == 'string' then
            set_cmds = vim.split(set_action, '%s+')
        else
            set_cmds = set_action
        end
        local mw = mwm.new({
            regname = rname,
            set_cmds = set_cmds,
            set_func = set_func,
            get_cmds = get_cmds,
            cache_enabled = hcb.cache_enabled
        })
        if get_cmds then
            hcb.paste[rname] = function()
                return mw:get()
            end
        end
        mwm.set(rname, mw)
    end

    vim.g.clipboard = hcb
    cmd([[
        let Elambda = {l, e -> 0}
        let HcbPasteExists = exists('g:hclipboard.paste') && type(g:hclipboard.paste) == v:t_dict
        for rname in keys(g:clipboard.copy)
            let g:clipboard.copy[rname] = Elambda
            if HcbPasteExists && g:clipboard.paste[rname] == v:null
                if type(get(g:hclipboard.paste, rname)) == v:t_func
                    let g:clipboard.paste[rname] = g:hclipboard.paste[rname]
                endif
            endif
        endfor
        unlet HcbPasteExists
        unlet Elambda
     ]])

    fn['provider#clipboard#Executable']()

    cmd([[
         aug HClipBoard
             au!
             au TextYankPost * lua require('hclipboard.action').send()
         aug END
     ]])

    if method == 'get' then
        local res
        if api.nvim_eval(
            ([[exists('g:hclipboard.paste') && type(get(g:hclipboard.paste, %q)) == v:t_func]]):format(
                regname)) == 1 then
            local func_name = get_viml_func('paste', regname)
            res = vim.fn[func_name]()
        else
            res = require('hclipboard.action').receive(regname)
        end
        return res
    end
    -- vim.g.hclipboard = nil
end

init()

return M
