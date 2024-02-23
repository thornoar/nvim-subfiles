local M = {}

local create_subfile_dir = false
local subfile_dir = ''

local create_figure_dir = true
local figure_dir = 'figures/'
local default_in_format = 'asy'
local default_out_format = 'pdf'
local default_width_in = '4'
local default_height_in = '4'

local jump_to_file = false

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
	if not jump_to_file then vim.cmd('b#') end
end

-- Function to insert lines to the main file (import function calls, jump references, etc.).
local write_to_main_file = function (lines)
    local len = #lines
    for k,v in pairs(lines) do
        vim.fn.append(vim.fn.line('.')-1, lines[k])
    end
end

-- The lines that are written in the main file (the import function call, etc.) when the create_subfile function is called.
local subfile_import_lines = {
    ['tex'] = function (dir, name)
        return {
            '\\subfile{'..dir..name..'.tex}',
            '%|sub|['..dir..name..'.tex]',
        }
    end
}

-- The lines that are pre-inserted in the subfile created.
local subfile_file_contents = {
    ['tex'] = function (parent)
        return {
            {
                '\\documentclass['..parent..']{subfiles}',
                '%|return|['..parent..']',
                '',
                '\\begin{document}',
                '',
            },
            {
                '',
                '\\end{document}',
            }
        }
    end
}

local subfile_determine_parent = {
    ['tex'] = function (dir)
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

M.create_subfile = function (args)
	local rargs = parse_cmd_args(args['args'], '/')
	local dir = rargs['1'] and (rargs['1']..'/') or subfile_dir
	local name = rargs['2']
    local ext = vim.fn.expand('%:e')
	if (not name) then
        local subfilecount = 1
        local mainname = vim.expand('%:r')
        while io.open(dir..'sub-'..mainname..'-'..tostring(subfilecount)..'.'..ext, 'r') ~= nil do
            subfilecount = subfilecount + 1
        end
		name = 'sub-'..vim.fn.expand('%:r')..'-'..tostring(subfilecount)..'.'..ext
	end
    local fullpath = dir..name..'.'..ext

    write_to_main_file(subfile_import_lines[ext](dir, name))

	if vim.fn.filereadable(fullpath) == 1 then
		vim.cmd('find '..fullpath)
		return
	end

	local parent = subfile_determine_parent[ext](dir)
    if not parent then return end

	if (not (dir == '')) and vim.fn.isdirectory(dir) == 0 then os.execute('mkdir '..dir) end

    write_to_subfile(fullpath, subfile_file_contents[ext](parent))
end

local figure_import_lines = {
    ['tex'] = function (dir, name, desc, opts, ftin, ftout)
        return {
            '\\begin{figure}['..opts..']',
            '    \\centering',
            '    \\includegraphics{'..dir..name..'.'..ftout..'}',
            '    \\caption{'..desc..'}',
            '    \\label{fig:'..name..'}',
            '\\end{figure}',
            '%|fig|['..dir..name..'.'..ftin..']',
        }
    end,
}

local figure_file_contents = {
    ['asy'] = function (name, ftout, width_in, height_in)
        local curmar = mar or '1cm'
        return {
            {
                'size(x = '..width_in..' inches, y = '..height_in..' inches);',
                'settings.outformat = \''..ftout..'\';',
                'import export;',
                '//|return|[../'..vim.fn.expand('%:t')..']',
                '',
            },
            {
                '',
                'export(margin = '..curmar..');',
            }
        }
    end,
    ['r'] = function (name, ftout, width_in, height_in)
        local curmar = mar or '2.5'
        return {
            {
                ftout..'(\''..name..'.'..ftout..'\', width = '..width_in..', height = '..height_in..')',
                'dlmargin <- '..curmar,
                'urmargin <- 0.5',
                'par(mar = c(dlmargin,dlmargin,urmargin,urmargin))',
                '#|return|[../'..vim.fn.expand('%:t')..']',
                '',
            }
        }
    end,
}

M.create_subfigure = function (args)
	local rargs = parse_cmd_args(args['args'], '/')
	local dir = rargs['1'] and (rargs['1']..'/') or figure_dir
	local name = rargs['2']
	local ftin = rargs['3'] or default_in_format
	local ftout = rargs['4'] or default_out_format
	if (not name) then
        local figurecount = 1
        while io.open(dir..'fig-'..tostring(figurecount)..'.'..ftin, 'r') ~= nil do
            figurecount = figurecount + 1
        end
		name = 'fig-'..tostring(figurecount)
	end
	local desc = rargs['5'] or ''
	local opts = rargs['6'] or ''
	local width_in = rargs['7'] or default_width_in
	local height_in = rargs['8'] or default_height_in
	local mar = rargs['9']
    local ext = vim.fn.expand('%:e')
    local fullpath = dir..name..'.'..ftin

    local import_lines = figure_import_lines[ext](dir, name, desc, opts, ftin, ftout)
    if import_lines then write_to_main_file(import_lines) else return end

	if vim.fn.filereadable(fullpath) == 1 then
		vim.cmd('find '..fullpath)
		return
	end

	if vim.fn.isdirectory(dir) == 0 then os.execute('mkdir '..dir) end
	local templ = figure_file_contents[ftin](name, ftout, width_in, height_in)
    
    if templ then write_to_subfile(fullpath, templ) else return end
end

M.setup = function (names, bindings)
    vim.api.nvim_create_user_command((names['subfile'] or 'SF'), M.create_subfile, { nargs = '?' })
    vim.api.nvim_create_user_command((names['subfigure'] or 'F'), M.create_subfigure, { nargs = '?' })
    vim.keymap.set('n', 'sf', ':SF<CR>:b#<CR>')

    vim.keymap.set('n', bindings['first_subfile'] or 's<Left>', 'gg/|return|<CR>f[gf')
    vim.keymap.set('n', bindings['next_subfile'] or 's<Down>', '/|sub|<CR>f[gf')
    vim.keymap.set('n', bindings['prev_subfile'] or 's<Up>', '?|sub|<CR>f[gf')
    vim.keymap.set('n', bindings['first_subfile_split'] or 'S<Left>', 'gg/|return|<CR>f[<C-w>f')
    vim.keymap.set('n', bindings['next_subfile_split'] or 'S<Down>', '/|sub|<CR>f[<C-w>f')
    vim.keymap.set('n', bindings['prev_subfile_split'] or 'S<Up>', '?|sub|<CR>f[<C-w>f')

    vim.keymap.set('n', bindings['first_figure'] or 'f<Left>', '?|return|<CR>f[gf')
    vim.keymap.set('n', bindings['next_figure'] or 'f<Down>', '/|fig|<CR>f[gf')
    vim.keymap.set('n', bindings['prev_figure'] or 'f<Up>', '?|fig|<CR>f[gf')
    vim.keymap.set('n', bindings['first_figure_split'] or 'F<Left>', '?|return|<CR>f[<C-w>f')
    vim.keymap.set('n', bindings['next_figure_split'] or 'F<Down>', '/|fig|<CR>f[<C-w>f')
    vim.keymap.set('n', bindings['prev_figure_split'] or 'F<Up>', '?|fig|<CR>f[<C-w>f')

    vim.keymap.set('n', bindings['delete_next_subfile'] or 'sd<Down>', '/|sub|<CR>f[:e <C-r><C-f><CR><C-^> :silent !rm <C-r><C-f><CR> :silent bd <C-r><C-f><CR>dip')
    vim.keymap.set('n', bindings['delete_prev_subfile'] or 'sd<Up>', '?|sub|<CR>f[:e <C-r><C-f><CR><C-^> :silent !rm <C-r><C-f><CR> :silent bd <C-r><C-f><CR>dip')
    vim.keymap.set('n', bindings['delete_next_figure'] or 'fd<Down>', '/|fig|<CR>f[:e <C-r><C-f><CR><C-^> :silent !rm <C-r><C-f><CR> :silent bd <C-r><C-f><CR>dip')
    vim.keymap.set('n', bindings['delete_prev_figure'] or 'fd<Up>', '?|fig|<CR>f[:e <C-r><C-f><CR><C-^> :silent !rm <C-r><C-f><CR> :silent bd <C-r><C-f><CR>:<CR>dip')
end

return M
