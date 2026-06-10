local M = {}

local go_query = [[
    [
        (identifier)
        (selector_expression)
        (call_expression)
        (index_expression)
        (binary_expression)
        (unary_expression)
        (slice_expression)
        (parenthesized_expression)
        (type_assertion_expression)
        (composite_literal)
    ] @prefix
]]

function M.setup()
    local ok, ts_postfix_mod = pcall(require, "luasnip.extras.treesitter_postfix")
    if not ok then
        vim.notify("[pofix] LuaSnip with treesitter_postfix support is required", vim.log.levels.ERROR)
        return
    end

    local ts_postfix = ts_postfix_mod.treesitter_postfix
    local ls = require("luasnip")
    local t = ls.text_node
    local i = ls.insert_node
    local f = ls.function_node

    local function expr()
        return f(function(_, parent)
            return parent.snippet.env.LS_TSMATCH or { "" }
        end, {})
    end

    local function postfix(trig, nodes)
        return ts_postfix({
            trig = trig,
            matchTSNode = {
                query = go_query,
                query_lang = "go",
            },
            reparseBuffer = "copy",
        }, nodes)
    end

    ls.add_snippets("go", {
        -- x > 5.if  →  if x > 5 { | }
        postfix(".if", { t("if "), expr(), t({ " {", "\t" }), i(0), t({ "", "}" }) }),

        -- mySlice.len  →  len(mySlice)|
        postfix(".len", { t("len("), expr(), t(")"), i(0) }),

        -- doSomething().err  →  if doSomething() != nil { return | }
        postfix(".err", { t("if "), expr(), t({ " != nil {", "\treturn " }), i(0), t({ "", "}" }) }),

        -- doSomething().iferr  →  if err := doSomething(); err != nil { return err }|
        postfix(".iferr", {
            t("if err := "),
            expr(),
            t({ "; err != nil {", "\treturn err", "}" }),
            i(0),
        }),

        -- myVar.print  →  fmt.Println(myVar)|
        postfix(".print", { t("fmt.Println("), expr(), t(")"), i(0) }),
    })
end

return M
