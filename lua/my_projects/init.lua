local API = {
	default_path = vim.fn.stdpath("data") .. "/my_projects.json",
	file_exists = function(path)
		local stat = vim.loop.fs_stat(path)
		return stat ~= nil
	end,
	read_file = function(path)
		local file = io.open(path)
		if not file then
			return nil
		end
		local content = file:read("*all")
		file:close()
		return content
	end,
	write_file = function(content, path)
		local file = io.open(path, "w")
		if not file then
			return false
		end
		file:write(content)
		file:close()
	end,
	is_json = function(content)
		local success, data = pcall(vim.fn.json_decode, content)
		if not success then
			return nil
		end
		return data
	end
}

local M = {}
local _props = {}
local _fzf = nil
local _fzf_props = {}

local function serach_selected_path(item, buffer)
	for _, v in pairs(buffer) do
		if item == v.name .. " | " .. v.path then
			return v
		end
	end
	return nil
end

local function selected_item(choice, buffer)
	local item = serach_selected_path(choice, buffer)
	if type(item) == "nil" then
		vim.print("I can not open this project!")
		return
	end
	vim.g.projpath = item.path
	vim.fn.chdir(vim.g.projpath or vim.loop.cwd())
	if type(_props.onOpen) == "function" then
		_props.onOpen(item)
	end
end

local function Select()
	local fullpath = _props.file_path or API.default_path
	local file_exists = API.file_exists(fullpath)
	if file_exists ~= true then
		vim.print("I do not have projects to deploy yet!")
		return
	end
	local content = API.read_file(fullpath)
	if type(content) == "nil" then
		vim.print("I can not open the projects file!")
		return
	end
	local json = API.is_json(content)
	if type(json) == "nil" then
		vim.print("I can not understand the projects file!")
		return
	end

	local list = {}
	for _, v in pairs(json) do
		table.insert(list, v.name .. " | " .. v.path)
	end

	local title = "  My Projects (WorkSpaces)"

	if _fzf ~= nil then
		_fzf_props["prompt"] = title
		_fzf_props["cwd"] = vim.loop.cwd()
		_fzf_props["actions"] = {
			["default"] = function(selected)
				local choice = selected[1]
				if choice then
					selected_item(choice, json)
				end
			end
		}
		if _fzf_props["winopts"] == nil then
			_fzf_props["winopts"] = {
				height = 0.35,
				width = 0.50,
				border = "rounded",
			}
		end
		_fzf.fzf_exec(list, _fzf_props)
		return
	end
	vim.ui.select(list, { prompt = title }, function(choice)
		if choice then
			selected_item(choice, json)
		end
	end)
end

local function add_project_data(data)
	local fullpath = _props.file_path or API.default_path
	local file_exists = API.file_exists(fullpath)
	local content = API.read_file(fullpath)
	local json = API.is_json(content) or {}
	table.insert(json, data)
	local encode = vim.fn.json_encode(json)
	local saved = API.write_file(encode, fullpath)
	if saved == false then
		vim.print("I can not find the file by paths troubles!")
		return
	end
	vim.print("Project saved successfully!")
end

M.add = function(props)
	props = props or {}
	local path = props.path
	if type(path) == "nil" then
		vim.print("I need a path to save the project!")
		return
	end
	vim.ui.input({ prompt = "Project name: " }, function(input)
		if input then
			local data = {
				name = input,
				path = path
			}
			add_project_data(data)
		else
			return
		end
	end)
end

M.setup = function(props)
	props = props or {}
	_props = props.props or {}
	local has_fzflua, _ = pcall(require, "fzf-lua")
	if has_fzflua == true then
		_fzf_props = props.fzf_lua or {}
		_fzf = require("fzf-lua")
	end
	vim.api.nvim_create_user_command("MyProjects", Select, {})
end

return M
