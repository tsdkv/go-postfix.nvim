# go-postfix.nvim

> [!WARNING]
> **This plugin is currently under active development.**


Postfix completions for Go in Neovim, powered by [LuaSnip](https://github.com/L3MON4D3/LuaSnip) + treesitter.

```
x > 5.if       →  if x > 5 { | }
mySlice.len     →  len(mySlice)|
doSomething().err  →  if doSomething() != nil { return | }
```

## Requirements

- Neovim ≥ 0.10
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip)
- Treesitter Go parser

## Installation

**Using [lazy.nvim](https://github.com/folke/lazy.nvim):**
```lua
{
    "tsdkv/go-postfix.nvim",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = {},
}
```

## Built-in snippets

| Trigger   | Output                                              |
|-----------|-----------------------------------------------------|
| `.if`     | `if expr { \| }`                                    |
| `.len`    | `len(expr)\|`                                       |
| `.err`    | `if expr != nil { return \| }`                      |
| `.iferr`  | `if err := expr; err != nil { return err }\|`       |
| `.print`  | `fmt.Println(expr)\|`                               |
