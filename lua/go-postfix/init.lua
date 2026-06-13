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

                -- Strip surrounding parens
                if match:match("^%((.*)%)$") then
                    inner = match:match("^%((.*)%)$")
                end

                -- Use Neovim's built-in Tree-sitter to parse the variables flawlessly
                local vars = {}
                local dummy_code = "var _ = []any{" .. inner .. "}"
                local ok, parser = pcall(vim.treesitter.get_string_parser, dummy_code, "go")

                if ok and parser then
                    local tree = parser:parse()[1]
                    if tree then
                        local root = tree:root()
                        -- Find all named nodes immediately inside the literal_value
                        local query_str = "(literal_value (_) @var)"
                        local ok_q, query = pcall(vim.treesitter.query.parse, "go", query_str)
                        if not ok_q then
                            ok_q, query = pcall(vim.treesitter.query.parse_query, "go", query_str)
                        end
                        if ok_q and query then
                            for _, node in query:iter_captures(root, dummy_code, 0, -1) do
                                local var_text = vim.treesitter.get_node_text(node, dummy_code)
                                table.insert(vars, var_text)
                            end
                        end
                    end
                end

                -- Fallback to regex if tree-sitter couldn't load or parse it
                if #vars == 0 and inner:match("%S") then
                    for v in inner:gmatch("[^,]+") do
                        v = v:match("^%s*(.-)%s*$")
                        if v ~= "" then
                            table.insert(vars, v)
                        end
                    end
                end

                if #vars == 0 then
                    return 'fmt.Printf("\\n")'
                end

                local fmt_parts = {}
                local args_parts = {}
                for _, v in ipairs(vars) do
                    -- Sanitize quotes so they don't break the fmt string
                    local name = v:gsub('"', '\\"')
                    -- Remove newlines for a cleaner print template
                    name = name:gsub("\n", " ")
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
