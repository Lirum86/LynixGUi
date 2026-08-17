local Config = {}

local HttpService = game:GetService("HttpService")

local lib = nil
local folder = "RadiantHub/configs"

local del = typeof(delfile) == "function" and delfile or nil

local function canFiles()
	return typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
end

local function ensureFolder()
	if typeof(isfolder) ~= "function" or typeof(makefolder) ~= "function" then
		return
	end
	local parts = {}
	for part in string.gmatch(folder, "[^/]+") do
		table.insert(parts, part)
		local path = table.concat(parts, "/")
		if not isfolder(path) then
			pcall(makefolder, path)
		end
	end
end

local function serialize()
	local data = {}
	for flag, e in pairs(lib.Flags) do
		if e.kind == "bool" or e.kind == "slider" or e.kind == "input" then
			data[flag] = { kind = e.kind, value = e.get() }
		elseif e.kind == "dropdown" then
			if e.multi then
				local sel = {}
				for _, opt in ipairs(e.options()) do
					if e.isOn(opt) then
						table.insert(sel, opt)
					end
				end
				data[flag] = { kind = "dropdown", multi = true, value = sel }
			else
				local sel = nil
				for _, opt in ipairs(e.options()) do
					if e.isOn(opt) then
						sel = opt
						break
					end
				end
				data[flag] = { kind = "dropdown", value = sel }
			end
		end
	end
	return data
end

local function applyEntry(e, saved)
	if e.kind == "bool" or e.kind == "slider" or e.kind == "input" then
		if saved.value ~= nil then
			e.set(saved.value)
		end
	elseif e.kind == "dropdown" then
		if e.multi then
			local wanted = {}
			for _, opt in ipairs(saved.value or {}) do
				wanted[opt] = true
			end
			for _, opt in ipairs(e.options()) do
				if e.isOn(opt) ~= (wanted[opt] == true) then
					e.choose(opt)
				end
			end
		elseif saved.value ~= nil and not e.isOn(saved.value) then
			e.choose(saved.value)
		end
	end
end

function Config.Init(library, folderName)
	lib = library
	if folderName then
		folder = folderName
	end
	if not canFiles() then
		return false
	end
	ensureFolder()
	local auto = folder .. "/autoload.txt"
	if isfile(auto) then
		local ok, name = pcall(readfile, auto)
		if ok and name and name ~= "" then
			task.defer(function()
				Config.Load(name)
			end)
		end
	end
	return true
end

function Config.Save(name)
	if not lib or not canFiles() or not name or name == "" then
		return false
	end
	ensureFolder()
	local ok = pcall(function()
		writefile(folder .. "/" .. name .. ".json", HttpService:JSONEncode(serialize()))
	end)
	return ok
end

function Config.Load(name)
	if not lib or not canFiles() or not name or name == "" then
		return false
	end
	local path = folder .. "/" .. name .. ".json"
	if not isfile(path) then
		return false
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then
		return false
	end
	for flag, saved in pairs(data) do
		local e = lib.Flags[flag]
		if e and type(saved) == "table" and saved.kind == e.kind then
			pcall(applyEntry, e, saved)
		end
	end
	return true
end

function Config.Delete(name)
	if not canFiles() or not del or not name or name == "" then
		return false
	end
	local path = folder .. "/" .. name .. ".json"
	if isfile(path) then
		local ok = pcall(del, path)
		return ok
	end
	return false
end

function Config.List()
	local out = {}
	if typeof(listfiles) ~= "function" then
		return out
	end
	local ok, files = pcall(listfiles, folder)
	if not ok or type(files) ~= "table" then
		return out
	end
	for _, path in ipairs(files) do
		local name = string.match(path, "([^/\\]+)%.json$")
		if name then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function Config.SetAutoload(name)
	if not canFiles() then
		return
	end
	ensureFolder()
	local auto = folder .. "/autoload.txt"
	if name and name ~= "" then
		pcall(writefile, auto, name)
	elseif isfile(auto) and del then
		pcall(del, auto)
	end
end

function Config.BuildSection(Library, tab)
	local sec = tab.CreateSection("Config", "right")
	local current = ""

	sec.AddInput({
		Name = "Config Name",
		Placeholder = "Name...",
		Callback = function(text)
			current = text
		end,
	})
	sec.AddDropdown({
		Name = "Configs",
		Options = Config.List(),
		Callback = function(sel)
			if sel then
				current = sel
			end
		end,
	})
	sec.AddButton({
		Name = "Save Config",
		Callback = function()
			if Config.Save(current) then
				Library.Notify("Config", "Saved '" .. current .. "'", 3)
			else
				Library.Notify("Config", "Enter a config name first", 3)
			end
		end,
	})
	sec.AddButton({
		Name = "Load Config",
		Callback = function()
			if Config.Load(current) then
				Library.Notify("Config", "Loaded '" .. current .. "'", 3)
			else
				Library.Notify("Config", "Config not found", 3)
			end
		end,
	})
	sec.AddButton({
		Name = "Delete Config",
		Callback = function()
			if Config.Delete(current) then
				Library.Notify("Config", "Deleted '" .. current .. "'", 3)
			end
		end,
	})
	sec.AddToggle({
		Name = "Auto Load",
		Default = false,
		Callback = function(on)
			Config.SetAutoload(on and current or nil)
		end,
	})

	return sec
end

return Config
