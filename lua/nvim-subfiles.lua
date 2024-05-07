local M = {}

M.options = {
    include_dir = '',
    embed_dir = 'figures/',
    default_out_format = 'pdf',
    default_width_in = '4',
    default_height_in = '4',
    jump_to_file = true,
    tex_use_subfiles = false,
}

M.bindings = {
    include = 'IN',
    embed = 'EB',
    return_to_parent = 's<Left>',
    next_subfile = 's<Down>',
    prev_subfile = 's<Up>',
    return_to_parent_split = 'S<Left>',
    next_subfile_split = 'S<Down>',
    prev_subfile_split = 'S<Up>',
    delete_next_subfile = 'sd<Down>',
    delete_prev_subfile = 'sd<Up>',
}

-- Function to parse arguments from string given in vim command.
local parse_cmd_args = function (str, delim)
    local t = {}
    local counter = 1
    iterate = function (substr)
        if #substr == 0 then return end
        local delim_index = substr:find(delim)
        if not delim_index then
            t[tostring(counter)] = substr
            return
        end
        t[tostring(counter)] = (1 < delim_index and substr:sub(1, delim_index-1) or nil)
        counter = counter + 1
        if delim_index == #substr then return end
        iterate(substr:sub(delim_index+1))
    end
    iterate(str)
    return t
end

-- Function to pre-insert lines in the subfile created by the create_subfile function.
local write_to_subfile = function (fullpath, lines)
    vim.cmd('edit '..fullpath)
    if lines[1] then
        local len = #lines[1]
        for k,v in pairs(lines[1]) do
            vim.fn.append(0, lines[1][len-k+1])
        end
    end
    if lines[2] then
        local len = #lines[2]
        for k,v in pairs(lines[2]) do
            vim.fn.append(vim.fn.line('.'), lines[2][len-k+1])
        end
    end
    vim.cmd('silent write')
    if not M.options.jump_to_file then vim.cmd('b#') end
end

-- Function to insert lines to the main file (import function calls, jump references, etc.).
local write_to_main_file = function (lines)
    for k,v in pairs(lines) do
        vim.fn.append(vim.fn.line('.')-1, lines[k])
    end
end

-- The lines that are written in the main file (the import function call, etc.) when the create_subfile function is called.
M.parent_include_lines = {
    ['tex'] = function (dir, name, opts)
        return {
            '\\include{'..dir..name..'.tex}',
            '%|sub|['..dir..name..'.tex]',
        }
    end,
    ['asy'] = function (dir, name, opts)
        return {
            'include \"'..dir..name..'.asy\";',
            '//|sub|['..dir..name..'.asy]',
        }
    end
}
M.parent_embed_lines = {
    ['tex'] = function (dir, name, ftin, ftout, opts)
        return {
            '\\begin{figure}['..(opts.opts or '')..']',
            '    \\centering',
            '    \\includegraphics{'..dir..name..'.'..ftout..'}',
            '    \\caption{'..(opts.desc or '')..'}',
            '    \\label{fig:'..name..'}',
            '\\end{figure}',
            '%|sub|['..dir..name..'.'..ftin..']',
        }
    end,
}

-- The lines that are pre-inserted in the subfile created.
M.included_file_contents = {
    ['tex'] = function (parent)
        return {
            {
                '%|return|['..parent..']',
                '',
            }
        }
    end,
    ['asy'] = function (parent)
        return {
            {
                '//|return|['..parent..']',
                '',
            }
        }
    end,
}
M.embedded_file_contents = {
    ['asy'] = function (parent, name, ftout, opts)
        local curmar = opts.mar or '1cm'
        return {
            {
                'size(x = '..(opts.width_in or M.options.default_width_in)..' inches, y = '..(opts.height_in or M.options.default_height_in)..' inches);',
                'settings.outformat = \''..ftout..'\';',
                'import export;',
                '//|return|['..parent..']',
                '',
            },
            {
                '',
                'export(margin = '..curmar..');',
            }
        }
    end,
    ['r'] = function (parent, name, ftout, opts)
        local curmar = opts.mar or '2.5'
        return {
            {
                ftout..'(\''..name..'.'..ftout..'\', width = '..(opts.width_in or M.options.default_width_in)..', height = '..(opts.height_in or M.options.default_height_in)..')',
                'dlmargin <- '..curmar,
                'urmargin <- 0.5',
                'par(mar = c(dlmargin,dlmargin,urmargin,urmargin))',
                '#|return|['..parent..']',
                '',
            }
        }
    end,
}

M.subfile_determine_parent = {
    ['tex'] = function (dir)
        if not M.options.tex_use_subfiles then return (dir == '' and './' or '../')..vim.fn.expand('%:t') end
        for i = 1,1,vim.fn.line('$') do
            local line = vim.fn.getline(i);
            if string.find(line, '\\documentclass') then
                local class = line:match('%{.+%}')
                if (class == '{subfiles}') then
                    local opts = line:match('%[.+%]')
                    if opts then
                        return opts:sub(2, #opts-1)
                    else
                        print('please specify path to main document in the preamble')
                        return nil
                    end
                end
            end
        end
        return (dir == '' and './' or '../')..vim.fn.expand('%:t')
    end,
    ['asy'] = function (dir)
        return (dir == '' and './' or '../')..vim.fn.expand('%:t')
    end,
}

M.include_subfile = function (args)
    -- setting up variables
    local rargs = parse_cmd_args(args['args'], '/')
    local dir = rargs['1'] and (rargs['1']..'/') or M.options.include_dir
    local name = rargs['2']
    if not name then
        print('please provide a name for the subfile')
        return nil
    end
    local opts = rargs['3'] and parse_cmd_args(rargs['3'], ',') or {}
    local parent_ext = vim.fn.expand('%:e')
    local fullpath = dir..name..'.'..parent_ext

    -- writing to main file
    local parent_lines = M.parent_include_lines[parent_ext]
    if parent_lines then write_to_main_file(parent_lines(dir, name, opts)) else
        print('no directions how to include subfile for file type \"'..parent_ext..'\", needs to be configured')
        return nil
    end

    -- checking if file already exists
    if vim.fn.filereadable(fullpath) == 1 then
        if M.options.jump_to_file then vim.cmd('find '..fullpath) end
        return nil
    end

    -- writing to subfile
    local parent_func = M.subfile_determine_parent[parent_ext]
    local parent = parent_func and parent_func(dir) or './'..vim.fn.expand('%:t')

    if (not (dir == '') and vim.fn.isdirectory(dir) == 0) then os.execute('mkdir '..dir) end

    local subfile_contents = M.included_file_contents[parent_ext]
    write_to_subfile(fullpath, subfile_contents and subfile_contents(parent) or {})
end

M.embed_subfile = function (args)
    -- setting up variables
    local rargs = parse_cmd_args(args['args'], '/')
    local dir = rargs['1'] and (rargs['1']..'/') or M.options.embed_dir
    local name = rargs['2']
    if not name then
        print('please provide a name for the subfile')
        return nil
    end
    local ftin = rargs['3']
    if not ftin then
        print('please provide the input format of the subfile')
        return nil
    end
    local ftout = rargs['4'] or M.options.default_out_format
    local opts = rargs['5'] and parse_cmd_args(rargs['5'], ',') or {}
    local parent_ext = vim.fn.expand('%:e')
    local fullpath = dir..name..'.'..ftin

    -- writing to main file
    local parent_lines = M.parent_embed_lines[parent_ext]
    if parent_lines then write_to_main_file(parent_lines(dir, name, ftin, ftout, opts)) else
        print('no directions how to embed subfile for file type \"'..parent_ext..'\", needs to be configured')
        return nil
    end

    -- checking if file already exists
    if vim.fn.filereadable(fullpath) == 1 then
        if M.jump_to_file then vim.cmd('find '..fullpath) end
        return nil
    end

    -- writing to subfile
    local parent_func = M.subfile_determine_parent[parent_ext]
    local parent = parent_func and parent_func(dir) or './'..vim.fn.expand('%:t')

    if (not (dir == '') and vim.fn.isdirectory(dir) == 0) then os.execute('mkdir '..dir) end

    local subfile_contents = M.embedded_file_contents[ftin]
    write_to_subfile(fullpath, subfile_contents and subfile_contents(parent, name, ftout, opts) or {})
end

M.setup = function (arg)
    for k,v in pairs(arg) do
        if (M[k]) then
            for k2,v2 in pairs(v) do
                if (M[k][k2]) then
                    M[k][k2] = v2
                end
            end
        end
    end

    vim.api.nvim_create_user_command((M.bindings.include or 'IN'), M.include_subfile, { nargs = '?' })
    vim.api.nvim_create_user_command((M.bindings.embed or 'EB'), M.embed_subfile, { nargs = '?' })
    vim.keymap.set('n', M.bindings.return_to_parent, 'gg/|return|<CR>f[gf')
    vim.keymap.set('n', M.bindings.next_subfile, '/|sub|<CR>f[gf')
    vim.keymap.set('n', M.bindings.prev_subfile, '?|sub|<CR>f[gf')
    vim.keymap.set('n', M.bindings.return_to_parent_split, 'gg/|return|<CR>f[<C-w>f')
    vim.keymap.set('n', M.bindings.next_subfile_split, '/|sub|<CR>f[<C-w>f')
    vim.keymap.set('n', M.bindings.prev_subfile_split, '?|sub|<CR>f[<C-w>f')
    vim.keymap.set('n', M.bindings.delete_next_subfile, '/|sub|<CR>f[:e <C-r><C-f><CR><C-^> :silent !rm <C-r><C-f><CR> :silent bd <C-r><C-f><CR>dip:echo \"deleted subfile\"<CR>')
    vim.keymap.set('n', M.bindings.delete_prev_subfile, '?|sub|<CR>f[:e <C-r><C-f><CR><C-^> :silent !rm <C-r><C-f><CR> :silent bd <C-r><C-f><CR>dip:echo \"deleted subfile\"<CR>')
end

return M
