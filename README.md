# nvim-hclipboard

Hijack your clipboard, make you become the host of the clipboard!!!

Hclipboard will bypass the text into clipboard for change operator in visual/select mode.

Run `:help v_c` or `:help v_s` to get more information.

Expanding snippet will enter select mode automatically which will pollute your clipboard.
The initial motivation of Hclipboard is to solve this issue.

<!-- markdownlint-disable MD034-->
https://user-images.githubusercontent.com/17562139/125729031-5ab3385c-1a33-4d48-9e35-c615d07e091e.mp4
<!-- markdownlint-enable MD034-->

> set clipboard=unnamedplus in Neovim and use xsel as my system clipboard

## Table of contents

* [Table of contents](#table-of-contents)
* [Features](#features)
* [Quickstart](#quickstart)
  * [Requirements](#requirements)
  * [Installation](#installation)
  * [Usage](#usage)
* [Documentation](#documentation)
* [Function](#function)
* [Setup and description](#setup-and-description)
* [Advanced configuration](#advanced-configuration)
* [Feedback](#feedback)
* [License](#license)

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

### Usage

```vim
" vimscript
lua require('hclipboard').start()
```

```lua
-- lua
require('hclipboard').start()
```

## Documentation

## Function

Functions are all inside `hclipboard` module, get module by `require('hclipboard')`

- start(): start to hijack clipboard provider

- stop(): stop to hijack clipboard provider

## Setup and description

```lua
{
    should_bypass_cb = {
        description = [[Callback function to decide whether to let text bypass the clipboard.
            *WIP*
            There's no guarantee that this function will not be changed in the future. If it is
            changed, it will be listed in the CHANGES file.]],
        default = nil
    },
}
```

## Advanced configuration

```lua
-- bypass text into clipboard for change and delete operator in visual/select mode.
require('hclipboard').setup({
    -- Return true the text will be bypassed the clipboard
    -- @param regname register name
    -- @param ev vim.v.ev TextYankPost event
    should_bypass_cb = function(regname, ev)
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

> default behavior bypass change operator but don't bypass delete operator

## Feedback

- If you get an issue or come up with an awesome idea, don't hesitate to open an issue in github.
- If you think this plugin is useful or cool, consider rewarding it a star.

## License

The project is licensed under a BSD-3-clause license. See [LICENSE](./LICENSE) file for details.
