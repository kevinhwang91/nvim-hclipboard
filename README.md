# nvim-hclipboard

Hijack your clipboard, make you become the host of the clipboard!!!

## Table of contents

## Features

- Hijacked your clipboard unconsciously
- Customize your clipboard

## Quickstart

### Requirements

- [Neovim](https://github.com/neovim/neovim) 0.5 or later

### Installation

Install nvim-hclipboard with [Vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'kevinhwang91/nvim-hclipboard'
```

Install nvim-hclipboard with [Packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {'kevinhwang91/nvim-hclipboard'}
```

### Minimal configuration

```vim
" vimscript
lua require('hclipboard').setup().start()
```

```lua
-- lua
require('hclipboard').setup().start()
```

### Usage

## Documentation

### Setup and description

## Advanced configuration

### Customize configuration

```lua
-- lua
require('hclipboard').setup({
    should_passby_cb = function(regname, ev)
        local ret = false
        if ev.visual and (ev.operator == 'd' or ev.operator == 'c') then
            if ev.regname == '' or ev.regname == regname then
                ret = true
            end
        end
        return ret
    end
}).start()
```

## Feedback

- If you get an issue or come up with an awesome idea, don't hesitate to open an issue in github.
- If you think this plugin is useful or cool, consider rewarding it a star.

## License

The project is licensed under a BSD-3-clause license. See [LICENSE](./LICENSE) file for details.
