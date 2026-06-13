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

        -- doSomething().err  →  if doSomething() != nil { return | }
        postfix(".err", { t("if "), expr(), t({ " != nil {", "\treturn " }), i(0), t({ "", "}" }) }),

        -- (var1, var2).dbg → fmt.Printf("var1=%+v; var2=%+v\n", var1, var2)
        postfix(".dbg", {
            f(function(_, parent)
                local match = parent.snippet.env.LS_TSMATCH and parent.snippet.env.LS_TSMATCH[1] or ""
                local inner = match

                -- Strip surrounding parens or slice literals if the user used them
                if match:match("^%((.*)%)$") then
                    inner = match:match("^%((.*)%)$")
                elseif match:match("^%[%]any%{(.*)%}$") then
                    inner = match:match("^%[%]any%{(.*)%}$")
                elseif match:match("^%[%]interface%{%}%{(.*)%}$") then
                    inner = match:match("^%[%]interface%{%}%{(.*)%}$")
                end

                local vars = {}
                for v in inner:gmatch("[^,]+") do
                    v = v:match("^%s*(.-)%s*$")
                    if v ~= "" then
                        table.insert(vars, v)
                    end
                end

                if #vars == 0 then
                    return 'fmt.Printf("\\n")'
                end

                local fmt_parts = {}
                local args_parts = {}
                for _, v in ipairs(vars) do
                    local name = v:gsub('"', '\\"')
                    table.insert(fmt_parts, name .. "=%+v")
                    table.insert(args_parts, v)
                end

                local fmt_str = table.concat(fmt_parts, "; ") .. "\\n"
                local args_str = table.concat(args_parts, ", ")

                return string.format('fmt.Printf("%s", %s)', fmt_str, args_str)
            end, {}),
        }),
    })
end

return M
