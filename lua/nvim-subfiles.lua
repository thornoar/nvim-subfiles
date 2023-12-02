local M = {}

local sub_file_count = 0
local create_subfile_dir = false
local subfile_dir = '.'

local figure_count = 0
local create_figure_dir = true
local figure_dir = 'figures'
local default_in_format = 'asy'
local default_out_format = 'pdf'
local default_width_in = '4'
local default_height_in = '4'

local jump_to_file = false

M.parse_cmd_args = function (str, delim)
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


M.subfile = function (args)
	local rargs = M.parse_cmd_args(args['args'], '/')
	local dir = (rargs['1'] or subfile_dir)..'/'
	local name = rargs['2']
	if (not name) then
		sub_file_count = sub_file_count + 1
		name = 'sub-'..vim.fn.expand('%:r')..'-'..tostring(sub_file_count)
	end
	name = name..'.tex'
	vim.fn.append(vim.fn.line('.')-1, '\\subfile{'..dir..name..'}')
	vim.fn.append(vim.fn.line('.')-1, '%|sub|['..dir..name..']')
	-- print (dir..name)
	if vim.fn.filereadable(dir..name) == 1 then
		vim.cmd('find '..dir..name)
		return
	end
	local parent = nil
	for i = 1,1,vim.fn.line('$') do
		local line = vim.fn.getline(i);
		if string.find(line, '\\documentclass') then
			local class = line:match('%{.+%}')
			if (class == '{subfiles}') then
				local opts = line:match('%[.+%]')
				if opts then
					parent = opts:sub(2, #opts-1)
				else
					print('please specify path to main document in the preamble')
					return
				end
			else
				parent = (dir == './' and './' or '../')..vim.fn.expand('%:t')
			end
		end
	end
	if vim.fn.isdirectory(dir) == 0 then os.execute('mkdir '..dir) end
	vim.cmd('edit '..dir..name)
	vim.fn.append(0, '')
	vim.fn.append(0, '\\begin{document}')
	vim.fn.append(0, '\\documentclass['..parent..']{subfiles}')
	vim.fn.append(vim.fn.line('.'), '\\end{document}')
	vim.fn.append(vim.fn.line('.'), '')
	vim.cmd('silent write')
	if not jump_to_file then vim.cmd('b#') end
end

M.subfigure = function (args)
	local rargs = M.parse_cmd_args(args['args'], '/')
	local dir = (rargs['1'] or figure_dir)..'/'
	local name = rargs['2']
	if not name then
		figure_count = figure_count + 1
		name = 'fig-'..vim.fn.expand('%:r')..'-'..tostring(figure_count)
	end
	local ftin = rargs['3'] or default_in_format
	local ftout = rargs['4'] or default_out_format
	local opts = rargs['5'] or ''
	local width_in = rargs['6'] or default_width_in
	local height_in = rargs['7'] or default_height_in
	local mar = rargs['8']
	local desc = rargs['9'] or ''
	vim.fn.append(vim.fn.line('.')-1, '\\begin{figure}['..opts..']')
	vim.fn.append(vim.fn.line('.')-1, '    \\centering')
	vim.fn.append(vim.fn.line('.')-1, '    \\includegraphics{'..dir..name..'.'..ftout..'}')
	vim.fn.append(vim.fn.line('.')-1, '    \\caption{'..desc..'}')
	vim.fn.append(vim.fn.line('.')-1, '    \\label{fig:'..dir..name..'}')
	vim.fn.append(vim.fn.line('.')-1, '\\end{figure}')
	vim.fn.append(vim.fn.line('.')-1, '%|fig|['..dir..name..'.'..ftin..']')
	if vim.fn.filereadable(dir..name) == 1 then
		vim.cmd('find '..dir..name)
		return
	end
	if vim.fn.isdirectory(dir) == 0 then os.execute('mkdir '..dir) end
	local figure_template = function ()
		if (ftin == 'asy') then
			local curmar = mar or '1cm'
			return {
				{
					'size(x = '..width_in..' inches, y = '..height_in..' inches);',
					'settings.outformat = \"'..ftout..'\";',
					'import export;',
					'//|return|[../'..vim.fn.expand("%:t")..']',
					'',
				},
				{
					'',
					'export(margin = '..curmar..');',
				}
			}
		elseif (ftin == 'r') then
			local curmar = mar or '2.5'
			return {
				{
					ftout..'(\"'..name..'.'..ftout..'\", width = '..width_in..', height = '..height_in..')',
					'margin <- '..curmar,
					'par(mar = c(margin,margin,margin,margin))',
					'#|return|[../'..vim.fn.expand("%:t")..']',
					'',
				}
			}
		end
		return {}
	end
	local templ = figure_template()
	vim.cmd('edit '..dir..name..'.'..ftin)
	if templ[1] then
		for k,v in pairs(templ[1]) do
			vim.fn.append(0, templ[1][#templ[1]-k+1])
		end
	end
	if templ[2] then
		for k,v in pairs(templ[2]) do
			vim.fn.append(vim.fn.line('.'), templ[2][#templ[2]-k+1])
		end
	end
	vim.cmd('silent write')
	if not jump_to_file then vim.cmd('b#') end
end

M.setup = function (names)
    vim.api.nvim_create_user_command(names['subfile'] or 'SF', M.subfile, { nargs = '?' })
    vim.api.nvim_create_user_command(names['subfigure'] or 'CF', M.subfigure, { nargs = '?' })
    vim.keymap.set('n', 'sf', ':SF<CR>:b#<CR>')

    vim.keymap.set('n', 's<Left>', 'gg0f[gf')
    vim.keymap.set('n', 's<Down>', '/|sub|<CR>f[gf')
    vim.keymap.set('n', 's<Up>', '?|sub|<CR>f[gf')
    vim.keymap.set('n', 'S<Left>', 'gg0f[<C-w>f')
    vim.keymap.set('n', 'S<Down>', '/|sub|<CR>f[<C-w>f')
    vim.keymap.set('n', 'S<Up>', '?|sub|<CR>f[<C-w>f')

    vim.keymap.set('n', 'f<Left>', '?|return|<CR>f[gf')
    vim.keymap.set('n', 'f<Down>', '/|fig|<CR>f[gf')
    vim.keymap.set('n', 'f<Up>', '?|fig|<CR>f[gf')
    vim.keymap.set('n', 'F<Left>', '?|return|<CR>f[<C-w>f')
    vim.keymap.set('n', 'F<Down>', '/|fig|<CR>f[<C-w>f')
    vim.keymap.set('n', 'F<Up>', '?|fig|<CR>f[<C-w>f')

    vim.keymap.set('n', 'sd<Down>', '/|sub|<CR>f[:silent !rm <C-r><C-f><CR>dk')
    vim.keymap.set('n', 'sd<Up>', '?|sub|<CR>f[:silent !rm <C-r><C-f><CR>dk')
    vim.keymap.set('n', 'fd<Down>', '/|fig|<CR>f[:silent !rm <C-r><C-f><CR>6dk')
    vim.keymap.set('n', 'fd<Up>', '?|fig|<CR>f[:silent !rm <C-r><C-f><CR>6dk')
end

return M
