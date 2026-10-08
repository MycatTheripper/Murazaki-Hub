local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Library = {
	Version = "2.0.0",
	Flags = {}, Elements = {}, Windows = {},
	Themes = {}, ThemeOrder = {}, Theme = {}, ThemeName = "blue", Lang = "th",
	Folder = "VortexUI", ConfigName = "main",
	AutoSave = true, FireOnInit = true,
	-- >>> ใส่ค่า Supabase ตรงนี้ที่เดียว (สคริปต์ผู้ใช้ไม่ต้องใส่อีก) <<<
	Supabase = {
		Url = "https://xhiavkxmtsuyphmifkfu.supabase.co",
		Key = "sb_publishable_mPVKadPz1Uk5Tx10JF5Y_Q_v4kvmmuX",
		-- ตารางคีย์ใน Supabase + ชื่อคอลัมน์ (แก้ให้ตรงกับตารางจริง)
		Table = "license_keys", KeyColumn = "key", PlanColumn = "plan",
	},
	_config = {}, _conns = {}, _guis = {}, _paints = {}, _keybinds = {},
	_inited = false, _loaded = false, _listening = false, _accent = nil,
}
local Theme = Library.Theme
local WindowMT, TabMT = {}, {}
WindowMT.__index = WindowMT
TabMT.__index = TabMT

local NotifHolder, TooltipFrame, TooltipLabel
local activeDrag

local LOAD_CLOCK = os.clock()

----------------------------------------------------------------------
-- ภาษา / Language (th, en)
----------------------------------------------------------------------
local I18N = {
	th = {
		tab_account = "บัญชี", tab_settings = "ตั้งค่า",
		acc_account = "บัญชี", acc_userid = "User ID", acc_key = "คีย์", acc_age = "อายุบัญชี", acc_days = "วัน",
		acc_plan = "แพลน", acc_remain = "เวลาที่เหลือ", acc_device = "อุปกรณ์", acc_exec = "Executor",
		acc_ver = "เวอร์ชันไลบรารี", acc_place = "Place ID",
		acc_nolicense = "ไม่มีไลเซนส์", acc_nokeysys = "ไม่ได้เปิดระบบคีย์",
		acc_active_never = "ไลเซนส์ใช้งานได้ - ไม่หมดอายุ",
		acc_active_until = "ไลเซนส์ใช้งานได้ - ถึง %s %s UTC",
		acc_active_life = "ไลเซนส์ใช้งานได้ - ตลอดชีพ",
		acc_lifetime = "ตลอดชีพ",
		acc_never_sub = "ไม่หมดอายุ • ใช้งานมา %s",
		acc_key_age = "ใช้คีย์นี้มาแล้ว %s",
		acc_keyage = "อายุคีย์", age_d = "%d วัน", age_h = "%d ชั่วโมง", age_hm = "%d ชั่วโมง %d นาที", age_m = "%d นาที",
		acc_signout = "ออกจากระบบ", acc_signout_desc = "ลบคีย์ที่บันทึกไว้และปิดเมนู",
		signout_notify = "ออกจากระบบแล้ว ลบคีย์ที่บันทึกไว้",
		r_invalid = "คีย์ไม่ถูกต้อง", r_expired = "คีย์หมดอายุแล้ว", r_revoked = "คีย์ถูกยกเลิกแล้ว",
		r_used_by_other = "คีย์นี้ถูกใช้โดยบัญชีอื่นไปแล้ว", r_disabled = "คีย์ถูกปิดใช้งานอยู่ (ติดต่อแอดมิน)",
		r_fail = "ตรวจสอบคีย์ไม่ผ่าน", closing = "กำลังปิดเมนู...",
		side_uptime = "เวลาใช้งาน: ", side_key = "คีย์: ", search_tabs = "ค้นหาแท็บ",
		modal_title = "ยืนยันการปิด", modal_msg = "ต้องการปิดเมนูใช่หรือไม่?", modal_close = "ปิด", modal_cancel = "ยกเลิก",
		set_language_box = "ภาษา", set_language = "ภาษาของเมนู", lang_changed = "เปลี่ยนภาษาเป็นไทยแล้ว",
		set_appearance = "รูปลักษณ์", set_theme = "ธีม", set_accent = "สีหลัก", set_reset_accent = "รีเซ็ตสีหลัก",
		set_window = "หน้าต่าง", set_togglekey = "ปุ่มเปิด-ปิดเมนู", set_resetwin = "รีเซ็ตขนาดและตำแหน่งหน้าต่าง",
		set_unload = "ปิดเมนูทั้งหมด (Unload)",
		set_config = "คอนฟิก", set_autosave = "บันทึกอัตโนมัติ",
		set_autosave_fs = "ทุก option ที่มี flag จะถูกบันทึกอัตโนมัติที่ %s",
		set_autosave_nofs = "Executor นี้ไม่รองรับไฟล์ ค่าจะถูกจำไว้เฉพาะเซสชันนี้",
		set_save = "บันทึกคอนฟิก", set_load = "โหลดคอนฟิก", set_reset = "รีเซ็ตค่าทั้งหมด", set_tools = "เครื่องมือ",
		set_cframe = "คัดลอกตำแหน่งที่ยืน (CFrame)",
		n_theme = "ธีม", n_theme_to = "เปลี่ยนเป็น %s",
		n_cfg_mem = "เก็บไว้ในหน่วยความจำ (Executor ไม่รองรับไฟล์)", n_cfg_saved = "บันทึก Config สำเร็จ",
		n_cfg_savefail = "บันทึกไม่สำเร็จ", n_cfg_loaded = "โหลด Config สำเร็จ", n_cfg_reset = "รีเซ็ตค่าทั้งหมดแล้ว",
	},
	en = {
		tab_account = "Account", tab_settings = "Settings",
		acc_account = "Account", acc_userid = "User ID", acc_key = "License Key", acc_age = "Account Age", acc_days = "days",
		acc_plan = "Plan", acc_remain = "Time Remaining", acc_device = "Device ID", acc_exec = "Executor",
		acc_ver = "Library Version", acc_place = "Place ID",
		acc_nolicense = "No license", acc_nokeysys = "Key system disabled",
		acc_active_never = "Active License - Never expires",
		acc_active_until = "Active License - Valid until %s %s UTC",
		acc_active_life = "Active License - Lifetime",
		acc_lifetime = "Lifetime",
		acc_never_sub = "Never expires • active for %s",
		acc_key_age = "Key in use for %s",
		acc_keyage = "Key Age", age_d = "%dd", age_h = "%dh", age_hm = "%dh %dm", age_m = "%dm",
		acc_signout = "Sign Out", acc_signout_desc = "Remove saved key and close menu",
		signout_notify = "Signed out, saved key removed",
		r_invalid = "Invalid key", r_expired = "Key has expired", r_revoked = "Key has been revoked",
		r_used_by_other = "Key is already used by another account", r_disabled = "Key is disabled (contact admin)",
		r_fail = "Key verification failed", closing = "Closing menu...",
		side_uptime = "Uptime: ", side_key = "Key: ", search_tabs = "Search tabs",
		modal_title = "Exit Confirmation", modal_msg = "Are you sure you want to close the menu?", modal_close = "Close", modal_cancel = "Cancel",
		set_language_box = "LANGUAGE", set_language = "Menu language", lang_changed = "Language set to English",
		set_appearance = "APPEARANCE", set_theme = "Theme", set_accent = "Accent colour", set_reset_accent = "Reset accent colour",
		set_window = "WINDOW", set_togglekey = "Toggle key", set_resetwin = "Reset window size and position",
		set_unload = "Unload UI",
		set_config = "CONFIG", set_autosave = "Auto-save",
		set_autosave_fs = "Every option with a flag is saved automatically to %s",
		set_autosave_nofs = "This executor has no file support, values are kept for this session only",
		set_save = "Save config", set_load = "Load config", set_reset = "Reset options to default", set_tools = "TOOLS",
		set_cframe = "Copy current position (CFrame)",
		n_theme = "Theme", n_theme_to = "Changed to %s",
		n_cfg_mem = "Saved in memory (executor has no file support)", n_cfg_saved = "Config saved",
		n_cfg_savefail = "Save failed", n_cfg_loaded = "Config loaded", n_cfg_reset = "All options reset",
	},
}
local function T(k, ...)
	local s = (I18N[Library.Lang] or I18N.th)[k] or I18N.th[k] or k
	if select("#", ...) > 0 then return s:format(...) end
	return s
end

function Library:_loadLang()
	local l = self._config["ui.lang"]
	if l == "en" or l == "th" then self.Lang = l end
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[VortexUI] callback error: " .. tostring(err)) end
end

local function tween(obj, props, dur, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function conn(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library._conns, c)
	return c
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- ระบบลาก (ใช้ร่วมกันทั้ง slider, ลากหน้าต่าง, ปรับขนาด)
local function startDrag(fn) activeDrag = fn end

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function toHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function fromHex(s)
	local r, g, b = tostring(s):match("^#?(%x%x)(%x%x)(%x%x)$")
	if not r then return nil end
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

-- ผูกสีของ Instance กับคีย์ธีม (จดไว้ใน Attribute เพื่อให้เปลี่ยนธีมสดได้แม่นยำ)
local function setBind(inst, prop, key, anim)
	inst:SetAttribute("Bind_" .. prop, key)
	if anim then tween(inst, { [prop] = Theme[key] }, 0.15) else inst[prop] = Theme[key] end
end
local function bindColor(inst, prop, key) setBind(inst, prop, key, false) end

local function new(class, props, binds)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for p, key in pairs(binds or {}) do bindColor(inst, p, key) end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = p }) end
local function stroke(p, key, tr)
	return new("UIStroke", { Transparency = tr or 0.4, Thickness = 1, Parent = p }, { Color = key or "Stroke" })
end
local function pad(p, l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), Parent = p })
end
local function list(p, gap)
	return new("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p })
end
local function label(parent, props, key)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Gotham
	props.TextSize = props.TextSize or 12
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Parent = parent
	return new("TextLabel", props, { TextColor3 = key or "Text" })
end

-- เรียกทุกครั้งที่เปลี่ยนธีม (ใช้กับสิ่งที่ผูก Attribute ไม่ได้ เช่น Gradient)
local function onTheme(inst, fn)
	table.insert(Library._paints, { inst = inst, fn = fn })
	fn()
end

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
local function lum(c) return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end
local function shiftHue(c)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV((h + 0.08) % 1, s, v)
end

local function addTheme(key, display, t)
	t.DisplayName = display
	t.CardHover = t.CardHover or t.Card:Lerp(t.Text, 0.06)
	t.Accent2 = t.Accent2 or shiftHue(t.Accent)
	t.Success = t.Success or rgb(90, 200, 130)
	t.Error = t.Error or rgb(225, 80, 80)
	Library.Themes[key] = t
	table.insert(Library.ThemeOrder, key)
end
local function lib(bg, side, card, stroke_, text, sub, accent)
	return { Background = bg, Sidebar = side, Card = card, Stroke = stroke_, Text = text, SubText = sub, Accent = accent }
end

-- ธีมจากไฟล์ txt เดิม
addTheme("blue", "Default Blue", {
	Background = rgb(18, 18, 18), Sidebar = rgb(14, 14, 14), Card = rgb(24, 24, 24), CardHover = rgb(32, 32, 40),
	Accent = rgb(255, 255, 255), Accent2 = rgb(138, 90, 255), Text = rgb(240, 240, 240), SubText = rgb(130, 130, 130), Stroke = rgb(45, 45, 45),
})
addTheme("violet", "Neon Violet", {
	Background = rgb(20, 16, 24), Sidebar = rgb(16, 12, 22), Card = rgb(31, 24, 40), CardHover = rgb(42, 32, 54),
	Accent = rgb(160, 107, 255), Accent2 = rgb(255, 94, 196), Text = rgb(240, 234, 255), SubText = rgb(163, 150, 194), Stroke = rgb(51, 40, 69),
})
addTheme("emerald", "Emerald Noir", {
	Background = rgb(15, 22, 19), Sidebar = rgb(11, 16, 14), Card = rgb(24, 36, 32), CardHover = rgb(31, 48, 42),
	Accent = rgb(51, 201, 143), Accent2 = rgb(212, 175, 55), Text = rgb(234, 255, 243), SubText = rgb(143, 173, 163), Stroke = rgb(40, 56, 47),
})
addTheme("sunset", "Synthwave", {
	Background = rgb(20, 10, 26), Sidebar = rgb(16, 7, 26), Card = rgb(36, 17, 48), CardHover = rgb(48, 23, 64),
	Accent = rgb(255, 77, 148), Accent2 = rgb(255, 180, 68), Text = rgb(253, 238, 255), SubText = rgb(185, 146, 201), Stroke = rgb(58, 31, 76),
})
addTheme("amber", "Amber Gold", {
	Background = rgb(21, 18, 12), Sidebar = rgb(16, 13, 8), Card = rgb(36, 29, 18), CardHover = rgb(48, 38, 23),
	Accent = rgb(224, 168, 61), Accent2 = rgb(138, 90, 44), Text = rgb(251, 241, 222), SubText = rgb(182, 166, 137), Stroke = rgb(58, 47, 28),
})
-- ธีมจาก Library.lua
addTheme("midnight", "Midnight", lib(rgb(15, 16, 20), rgb(19, 20, 25), rgb(25, 27, 33), rgb(44, 47, 58), rgb(232, 234, 240), rgb(138, 144, 160), rgb(124, 140, 255)))
addTheme("graphite", "Graphite", lib(rgb(17, 17, 17), rgb(21, 21, 21), rgb(28, 28, 28), rgb(48, 48, 48), rgb(236, 236, 236), rgb(150, 150, 150), rgb(214, 214, 214)))
addTheme("ocean", "Ocean", lib(rgb(11, 18, 24), rgb(14, 23, 31), rgb(20, 31, 41), rgb(35, 52, 66), rgb(226, 238, 246), rgb(120, 146, 163), rgb(74, 186, 214)))
addTheme("rose", "Rose", lib(rgb(20, 14, 17), rgb(25, 17, 21), rgb(33, 23, 28), rgb(58, 40, 49), rgb(244, 230, 235), rgb(160, 130, 142), rgb(242, 120, 150)))
addTheme("forest", "Forest", lib(rgb(12, 19, 16), rgb(15, 24, 20), rgb(22, 34, 28), rgb(38, 58, 48), rgb(228, 244, 236), rgb(124, 154, 138), rgb(80, 200, 140)))
addTheme("honey", "Honey", lib(rgb(19, 16, 11), rgb(24, 20, 13), rgb(32, 27, 18), rgb(56, 48, 32), rgb(246, 238, 224), rgb(166, 150, 120), rgb(240, 180, 70)))
addTheme("iris", "Iris", lib(rgb(16, 13, 22), rgb(20, 16, 28), rgb(28, 23, 39), rgb(49, 41, 68), rgb(238, 232, 248), rgb(146, 134, 170), rgb(170, 120, 255)))

local function resolveTheme(name)
	if name == nil then return nil end
	if Library.Themes[name] then return name end
	local l = tostring(name):lower()
	for key, t in pairs(Library.Themes) do
		if key:lower() == l or (t.DisplayName or ""):lower() == l then return key end
	end
	return nil
end

local function derive()
	Theme.Input = Theme.Background:Lerp(Theme.Card, 0.45)
	Theme.AccentSoft = Theme.Card:Lerp(Theme.Accent, 0.2)
	Theme.AccentText = lum(Theme.Accent) > 0.6 and rgb(14, 15, 19) or rgb(255, 255, 255)
end

function Library:_loadPreset(key)
	local preset = self.Themes[key]
	for k in pairs(Theme) do Theme[k] = nil end
	for k, v in pairs(preset) do Theme[k] = v end
	if self._accent then
		Theme.Accent = self._accent
		Theme.Accent2 = shiftHue(self._accent)
	end
	derive()
	self.ThemeName = key
end

-- รีเฟรชสีทั้ง UI ตาม Attribute "Bind_<Property>" + มี Overlay จางๆ ให้นุ่มนวล
local function repaintTheme(gui)
	if not gui or not gui.Parent then return end
	local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 200, Parent = gui })
	tween(overlay, { BackgroundTransparency = 0.6 }, 0.09)
	task.delay(0.1, function()
		for _, inst in ipairs(gui:GetDescendants()) do
			for attr, key in pairs(inst:GetAttributes()) do
				local prop = attr:match("^Bind_(.+)$")
				if prop and Theme[key] ~= nil then pcall(function() inst[prop] = Theme[key] end) end
			end
		end
		for i = #Library._paints, 1, -1 do
			local e = Library._paints[i]
			if not e.inst.Parent then table.remove(Library._paints, i) else pcall(e.fn) end
		end
		tween(overlay, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function() overlay:Destroy() end)
	end)
end

function Library:_repaint()
	for _, g in ipairs(self._guis) do repaintTheme(g) end
end

function Library:SetTheme(t, silent)
	if type(t) == "table" then
		for k, v in pairs(t) do Theme[k] = v end
		derive()
	else
		local key = resolveTheme(t)
		if not key then return false end
		self:_loadPreset(key)
		self._config["ui.theme"] = key
		if not silent then self:Notify(T("n_theme"), T("n_theme_to", self.Themes[key].DisplayName or key), 2) end
	end
	self:_repaint()
	self:_queueSave()
	return true
end

function Library:SetAccent(color)
	self._accent = color
	self:_loadPreset(self.ThemeName)
	self._config["ui.accent"] = color and toHex(color) or nil
	self:_repaint()
	self:_queueSave()
end

----------------------------------------------------------------------
-- Config (บันทึก/โหลดอัตโนมัติ)
----------------------------------------------------------------------
local function fsAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
local function hasFolders() return type(makefolder) == "function" and type(isfolder) == "function" end

function Library:_path()
	if hasFolders() then return self.Folder .. "/" .. self.ConfigName .. ".json" end
	return self.Folder .. "_" .. self.ConfigName .. ".json"
end

function Library:_readConfig(force)
	if self._loaded and not force then return end
	self._loaded = true
	if not fsAvailable() then return end
	local path = self:_path()
	local ok, exists = pcall(isfile, path)
	if not (ok and exists) then return end
	local ok2, raw = pcall(readfile, path)
	if not ok2 then return end
	local ok3, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok3 and type(data) == "table" then self._config = data end
end

function Library:SaveConfig(silent)
	local cfg = {}
	for k, v in pairs(self._config) do cfg[k] = v end
	for flag, el in pairs(self.Elements) do
		local ok, v = pcall(el.Get, el)
		if ok and v ~= nil then cfg[flag] = v end
	end
	self._config = cfg
	if not fsAvailable() then
		if not silent then self:Notify("Config", T("n_cfg_mem"), 3) end
		return false
	end
	if hasFolders() then
		pcall(function() if not isfolder(self.Folder) then makefolder(self.Folder) end end)
	end
	local ok = pcall(function() writefile(self:_path(), HttpService:JSONEncode(cfg)) end)
	if not silent then self:Notify("Config", ok and T("n_cfg_saved") or T("n_cfg_savefail"), 2) end
	return ok
end

function Library:LoadConfig(silent)
	self:_readConfig(true)
	local cfg = self._config
	local k = resolveTheme(cfg["ui.theme"])
	if k then self:SetTheme(k, true) end
	if type(cfg["ui.accent"]) == "string" and fromHex(cfg["ui.accent"]) then
		self:SetAccent(fromHex(cfg["ui.accent"]))
	end
	for flag, el in pairs(self.Elements) do
		if cfg[flag] ~= nil then pcall(el.Set, el, cfg[flag]) end
	end
	if not silent then self:Notify("Config", T("n_cfg_loaded"), 2) end
end

function Library:ResetConfig(silent)
	for _, el in pairs(self.Elements) do
		if el.Reset then pcall(el.Reset, el) end
	end
	self:SaveConfig(true)
	if not silent then self:Notify("Config", T("n_cfg_reset"), 2) end
end

function Library:_queueSave()
	if not self.AutoSave or self._savePending then return end
	self._savePending = true
	task.delay(0.6, function()
		self._savePending = false
		if self.AutoSave then self:SaveConfig(true) end
	end)
end

----------------------------------------------------------------------
-- Notify / Tooltip / CFrame
----------------------------------------------------------------------
function Library:Notify(title, text, duration)
	if not NotifHolder then return end
	duration = tonumber(duration) or 3
	local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = NotifHolder })
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1.2, 0, 0, 0),
		BackgroundTransparency = 0.12, ClipsDescendants = true, Parent = wrap,
	}, { BackgroundColor3 = "Card" })
	corner(card, 8)
	stroke(card, "Stroke", 0.35)
	new("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Parent = card }, { BackgroundColor3 = "Accent" })
	local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card })
	pad(body, 14, 9, 12, 12)
	list(body, 2)
	label(body, { Text = tostring(title or "แจ้งเตือน"), Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1 }, "Text")
	label(body, {
		Text = tostring(text or ""), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
	}, "SubText")
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, Parent = card }, { BackgroundColor3 = "Accent" })
	card.BackgroundTransparency = 1
	tween(card, { BackgroundTransparency = 0.12 }, 0.3)
	tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back)
	tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
	task.delay(duration, function()
		if not card.Parent then return end
		tween(card, { Position = UDim2.new(1.2, 0, 0, 0), BackgroundTransparency = 1 }, 0.25)
		task.wait(0.28)
		wrap:Destroy()
	end)
end

function Library:AddTooltip(obj, text)
	if not obj or not TooltipFrame then return end
	obj.MouseEnter:Connect(function() TooltipLabel.Text = text; TooltipFrame.Visible = true end)
	obj.MouseLeave:Connect(function() TooltipFrame.Visible = false end)
	obj.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TooltipFrame.Position = UDim2.fromOffset(input.Position.X + 16, input.Position.Y + 16)
		end
	end)
end

function Library:GetCharacterCFrameString()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = hrp.CFrame:GetComponents()
	return string.format("CFrame.new(%.3f, %.3f, %.3f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f)",
		x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

function Library:CopyCharacterCFrame()
	local s = self:GetCharacterCFrameString()
	if not s then self:Notify("CFrame", "ไม่พบตัวละคร (Character) ในตอนนี้", 3) return false end
	local ok = type(setclipboard) == "function" and pcall(setclipboard, s)
	self:Notify("CFrame", ok and "คัดลอกลงคลิปบอร์ดแล้ว" or "Executor ไม่รองรับ setclipboard", 2)
	return ok and true or false, s
end

function Library:_init()
	if self._inited then return end
	self._inited = true
	conn(UserInputService.InputChanged, function(input)
		if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			safe(activeDrag, input)
		end
	end)
	conn(UserInputService.InputEnded, function(input) if isPress(input) then activeDrag = nil end end)
	conn(UserInputService.InputBegan, function(input, gpe)
		for _, handler in ipairs(self._keybinds) do handler(input, gpe) end
	end)
end

function Library:Unload()
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	for _, g in ipairs(self._guis) do pcall(function() g:Destroy() end) end
	self._conns, self._guis, self._paints, self._keybinds, self.Windows = {}, {}, {}, {}, {}
	for k in pairs(self.Flags) do self.Flags[k] = nil end
	for k in pairs(self.Elements) do self.Elements[k] = nil end
	self.KeyInfo = nil
	self._keyWatchId = (self._keyWatchId or 0) + 1
	self._inited, self._listening = false, false
	NotifHolder, TooltipFrame, TooltipLabel, activeDrag = nil, nil, nil, nil
end

----------------------------------------------------------------------
-- Element helpers
----------------------------------------------------------------------
local function nextOrder(tab)
	tab._n = (tab._n or 0) + 1
	return tab._n
end

local function initial(flag, default)
	if flag then
		local v = Library._config[flag]
		if v ~= nil then return v end
	end
	return default
end

local function register(tab, obj, flag, callback, noInit)
	obj.Flag, obj._cb = flag, callback
	if flag then
		Library.Elements[flag] = obj
		Library.Flags[flag] = obj._cbValue and obj._cbValue() or obj:Get()
		if tab.Window then tab.Window.Flags[flag] = obj end
	end
	if Library.FireOnInit and callback and not noInit then
		local v = obj._cbValue and obj._cbValue() or obj:Get()
		task.defer(safe, callback, v)
	end
	return obj
end

local function emit(obj, silent)
	local v = obj._cbValue and obj._cbValue() or obj:Get()
	if obj.Flag then Library.Flags[obj.Flag] = v end
	if silent then return end
	safe(obj._cb, v)
	if obj.Flag then Library:_queueSave() end
end

-- การ์ดมาตรฐาน (36px) ที่ยุบ/ขยายได้ ใช้กับ Dropdown/ColorPicker/CFrame
local function makeCard(tab, height)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, height or 36), BackgroundTransparency = 0.3, ClipsDescendants = true,
		LayoutOrder = nextOrder(tab), Parent = tab.Page,
	}, { BackgroundColor3 = "Card" })
	corner(card, 6)
	stroke(card, "Stroke", 0.4)
	return card
end

----------------------------------------------------------------------
-- TAB ELEMENTS
----------------------------------------------------------------------
function TabMT:CreateLabel(text)
	local l = label(self.Page, {
		Text = tostring(text or ""), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = nextOrder(self),
	}, "SubText")
	return { Instance = l, SetText = function(_, s) l.Text = tostring(s) end }
end

function TabMT:CreateSection(text)
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self.Page })
	label(holder, { Text = tostring(text), Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, 18) }, "Accent")
	new("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.3, Parent = holder }, { BackgroundColor3 = "Stroke" })
	return holder
end

function TabMT:CreateGroupbox(title)
	local box = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.35,
		LayoutOrder = nextOrder(self), Parent = self.Page,
	}, { BackgroundColor3 = "Sidebar" })
	corner(box, 6)
	stroke(box, "Stroke", 0.4)
	pad(box, 10, 10, 10, 10)
	list(box, 8)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 0, Parent = box })
	new("Frame", { Size = UDim2.new(0, 3, 0, 12), Position = UDim2.new(0, 0, 0.5, -6), BorderSizePixel = 0, Parent = head }, { BackgroundColor3 = "Accent" })
	local t = label(head, { Text = tostring(title), Font = Enum.Font.GothamBold, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -10, 1, 0) }, "Text")
	local g = setmetatable({ Page = box, Window = self.Window, _n = 0 }, TabMT)
	g.SetTitle = function(_, s) t.Text = tostring(s) end
	return g
end

function TabMT:CreateParagraph(title, content)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.35,
		LayoutOrder = nextOrder(self), Parent = self.Page,
	}, { BackgroundColor3 = "Sidebar" })
	corner(card, 6)
	stroke(card, "Stroke", 0.4)
	pad(card, 12, 10, 12, 10)
	list(card, 4)
	local t = label(card, { Text = tostring(title or ""), Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1 }, "Text")
	local c = label(card, {
		Text = tostring(content or ""), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
	}, "SubText")
	return {
		Instance = card,
		SetTitle = function(_, s) t.Text = tostring(s) end,
		GetContent = function() return c.Text end,
		SetContent = function(_, s, color)
			c.Text = tostring(s)
			if color then c:SetAttribute("Bind_TextColor3", nil); c.TextColor3 = color
			else bindColor(c, "TextColor3", "SubText") end
		end,
	}
end

function TabMT:CreateText(text)
	return self:CreateParagraph("", text)
end

function TabMT:CreateButton(text, callback)
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 0.3, Text = tostring(text or "Button"),
		Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, LayoutOrder = nextOrder(self), Parent = self.Page,
	}, { BackgroundColor3 = "Card", TextColor3 = "Text" })
	corner(btn, 6)
	local st = stroke(btn, "Stroke", 0.4)
	btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundColor3 = Theme.CardHover }, 0.12)
		tween(st, { Color = Theme.Accent, Transparency = 0.2 }, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundColor3 = Theme.Card }, 0.15)
		tween(st, { Color = Theme.Stroke, Transparency = 0.4 }, 0.15)
	end)
	local obj = { Instance = btn, Type = "Button" }
	function obj:Fire() safe(callback) end
	function obj:SetText(s) btn.Text = tostring(s) end
	btn.MouseButton1Click:Connect(function()
		tween(btn, { BackgroundColor3 = Theme.AccentSoft }, 0.06)
		task.delay(0.1, function() tween(btn, { BackgroundColor3 = Theme.CardHover }, 0.18) end)
		obj:Fire()
	end)
	return obj
end

function TabMT:CreateToggle(text, default, callback, flag, desc)
	local state = initial(flag, default) == true
	local hasDesc = desc ~= nil and desc ~= ""
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self.Page })
	local box = new("Frame", { Size = UDim2.new(1, -50, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = row })
	list(box, 1)
	local title = label(box, { Text = tostring(text or "Toggle"), Size = UDim2.new(1, 0, 0, hasDesc and 16 or 24), LayoutOrder = 1 }, "Text")
	label(box, {
		Text = hasDesc and tostring(desc) or "", TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = hasDesc, LayoutOrder = 2,
	}, "SubText")
	local Switch = new("Frame", { Size = UDim2.fromOffset(36, 18), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Parent = row })
	corner(Switch, 9)
	local Knob = new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0, 0.5), Parent = Switch })
	corner(Knob, 6)
	local function visual(anim)
		local sk = state and "Accent" or "CardHover"
		local kk = state and "AccentText" or "SubText"
		local pos = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		setBind(Switch, "BackgroundColor3", sk, anim)
		setBind(Knob, "BackgroundColor3", kk, anim)
		if anim then
			tween(Switch, { BackgroundTransparency = state and 0 or 0.3 }, 0.15)
			tween(Knob, { Position = pos }, 0.15)
		else
			Switch.BackgroundTransparency = state and 0 or 0.3
			Knob.Position = pos
		end
	end
	visual(false)
	local click = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = row })

	local obj = { Instance = row, Type = "Toggle", Default = default == true }
	function obj:Get() return state end
	function obj:Set(v, silent)
		v = v and true or false
		local changed = v ~= state
		state = v
		visual(true)
		if changed then emit(obj, silent) end
	end
	function obj:Reset() obj:Set(obj.Default) end
	function obj:SetText(s) title.Text = tostring(s) end
	click.MouseButton1Click:Connect(function() obj:Set(not state) end)
	return register(self, obj, flag, callback)
end

function TabMT:CreateSlider(text, min, max, default, callback, flag, increment)
	min, max = tonumber(min) or 0, tonumber(max) or 100
	if max == min then max = min + 1 end
	local span = max - min
	local def = tonumber(default) or min
	local inc = tonumber(increment) or ((min % 1 == 0 and max % 1 == 0 and def % 1 == 0) and 1 or 0.01)
	local decimals = (tostring(inc):match("%.(%d+)") or ""):len()
	local function snap(v)
		v = math.clamp(tonumber(v) or min, min, max)
		v = math.floor((v - min) / inc + 0.5) * inc + min
		v = tonumber(string.format("%." .. decimals .. "f", v)) or v
		return math.clamp(v, min, max)
	end
	local value = snap(initial(flag, def))

	local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self.Page })
	label(frame, { Text = tostring(text or "Slider"), Size = UDim2.new(0.4, 0, 1, 0) }, "Text")
	local vbox = new("Frame", { Size = UDim2.fromOffset(46, 22), Position = UDim2.new(1, -46, 0.5, -11), BackgroundTransparency = 0.3, Parent = frame }, { BackgroundColor3 = "Card" })
	corner(vbox, 4)
	local vlabel = label(vbox, { Size = UDim2.fromScale(1, 1), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center }, "Text")
	local track = new("Frame", { Size = UDim2.new(0.6, -100, 0, 4), Position = UDim2.new(0.4, 10, 0.5, -2), BackgroundTransparency = 0.2, Parent = frame }, { BackgroundColor3 = "Input" })
	corner(track, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track }, { BackgroundColor3 = "Accent" })
	corner(fill, 2)
	local knob = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -5, 0.5, -5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = fill })
	corner(knob, 5)
	local hit = new("TextButton", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundTransparency = 1, Text = "", Parent = track })

	local obj = { Instance = frame, Type = "Slider", Default = snap(def) }
	local function visual(anim)
		local f = (value - min) / span
		vlabel.Text = string.format("%." .. decimals .. "f", value)
		if anim then tween(fill, { Size = UDim2.fromScale(f, 1) }, 0.06) else fill.Size = UDim2.fromScale(f, 1) end
	end
	visual(false)
	function obj:Get() return value end
	function obj:Set(v, silent)
		v = snap(v)
		local changed = v ~= value
		value = v
		visual(true)
		if changed then emit(obj, silent) end
	end
	function obj:Reset() obj:Set(obj.Default) end
	local function fromInput(i)
		local ratio = math.clamp((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + ratio * span)
	end
	hit.InputBegan:Connect(function(input)
		if isPress(input) then fromInput(input); startDrag(fromInput) end
	end)
	return register(self, obj, flag, callback)
end

function TabMT:CreateDropdown(text, options, default, callback, flag)
	options = options or {}
	local ROW, MAXV = 26, 6
	local selected = initial(flag, default)
	local function exists(v) for _, o in ipairs(options) do if tostring(o) == tostring(v) then return true end end return false end
	if not exists(selected) then selected = exists(default) and default or options[1] end
	local open = false

	local card = makeCard(self, 36)
	label(card, { Text = tostring(text or "Dropdown"), Size = UDim2.new(1, -110, 0, 36), Position = UDim2.fromOffset(12, 0) }, "Text")
	local sel = label(card, { Text = tostring(selected or ""), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(86, 36), Position = UDim2.new(1, -112, 0, 0) }, "SubText")
	local arrow = label(card, { Text = "▾", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(20, 36), Position = UDim2.new(1, -24, 0, 0) }, "Accent")
	local click = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", Parent = card })
	local holder = new("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 40), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = card,
	}, { ScrollBarImageColor3 = "Accent" })
	list(holder, 2)

	local function listHeight() return math.min(#options, MAXV) * ROW end
	local function openHeight() return 40 + listHeight() + 6 end
	local function marks(anim)
		for _, b in ipairs(holder:GetChildren()) do
			if b:IsA("TextButton") then
				local on = b.Text == tostring(selected)
				setBind(b, "BackgroundColor3", on and "AccentSoft" or "CardHover", anim)
				setBind(b, "TextColor3", on and "Accent" or "Text", anim)
			end
		end
	end
	local obj = { Instance = card, Type = "Dropdown", Default = default }
	local function close()
		open = false
		tween(card, { Size = UDim2.new(1, 0, 0, 36) }, 0.15)
		tween(arrow, { Rotation = 0 }, 0.15)
	end
	local function build()
		for _, c in ipairs(holder:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		for i, o in ipairs(options) do
			local b = new("TextButton", {
				Text = tostring(o), Font = Enum.Font.Gotham, TextSize = 11, Size = UDim2.new(1, -4, 0, 24),
				AutoButtonColor = false, LayoutOrder = i, Parent = holder,
			})
			corner(b, 4)
			b.MouseButton1Click:Connect(function() obj:Set(o); close() end)
		end
		holder.Size = UDim2.new(1, -16, 0, listHeight())
		marks(false)
	end
	function obj:Get() return selected end
	function obj:Set(v, silent)
		if not exists(v) then return end
		local changed = tostring(v) ~= tostring(selected)
		selected = v
		sel.Text = tostring(v)
		marks(true)
		if changed then emit(obj, silent) end
	end
	function obj:Reset() if exists(default) then obj:Set(default) elseif options[1] ~= nil then obj:Set(options[1]) end end
	function obj:Refresh(newOptions)
		options = newOptions or {}
		if not exists(selected) then selected = options[1]; sel.Text = tostring(selected or "") end
		build()
		if open then tween(card, { Size = UDim2.new(1, 0, 0, openHeight()) }, 0.15) end
	end
	obj.SetValues = obj.Refresh
	build()
	click.MouseButton1Click:Connect(function()
		open = not open
		tween(card, { Size = UDim2.new(1, 0, 0, open and openHeight() or 36) }, 0.15)
		tween(arrow, { Rotation = open and 180 or 0 }, 0.15)
	end)
	return register(self, obj, flag, callback)
end

function TabMT:CreateMultiDropdown(text, options, defaults, callback, flag)
	options = options or {}
	local ROW, MAXV = 26, 6
	local selected = {}
	local saved = initial(flag, nil)
	for _, v in ipairs(type(saved) == "table" and saved or defaults or {}) do selected[tostring(v)] = true end
	local open = false

	local card = makeCard(self, 36)
	label(card, { Text = tostring(text or "Multi"), Size = UDim2.new(1, -110, 0, 36), Position = UDim2.fromOffset(12, 0) }, "Text")
	local count = label(card, { TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(86, 36), Position = UDim2.new(1, -112, 0, 0) }, "SubText")
	local arrow = label(card, { Text = "▾", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(20, 36), Position = UDim2.new(1, -24, 0, 0) }, "Accent")
	local click = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", Parent = card })
	local holder = new("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 40), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = card,
	}, { ScrollBarImageColor3 = "Accent" })
	list(holder, 2)
	holder.Size = UDim2.new(1, -16, 0, math.min(#options, MAXV) * ROW)

	local obj = { Instance = card, Type = "MultiDropdown", Default = defaults or {} }
	local function getList()
		local out = {}
		for _, o in ipairs(options) do if selected[tostring(o)] then table.insert(out, tostring(o)) end end
		return out
	end
	local function marks(anim)
		local n = 0
		for _, b in ipairs(holder:GetChildren()) do
			if b:IsA("TextButton") then
				local on = selected[b.Text] == true
				if on then n = n + 1 end
				setBind(b, "BackgroundColor3", on and "AccentSoft" or "CardHover", anim)
				setBind(b, "TextColor3", on and "Accent" or "Text", anim)
			end
		end
		count.Text = n .. " selected"
	end
	for i, o in ipairs(options) do
		local b = new("TextButton", {
			Text = tostring(o), Font = Enum.Font.Gotham, TextSize = 11, Size = UDim2.new(1, -4, 0, 24),
			AutoButtonColor = false, LayoutOrder = i, Parent = holder,
		})
		corner(b, 4)
		b.MouseButton1Click:Connect(function()
			selected[tostring(o)] = not selected[tostring(o)] or nil
			marks(true)
			emit(obj, false)
		end)
	end
	marks(false)
	function obj:Get() return getList() end
	function obj:Set(listv, silent)
		selected = {}
		for _, v in ipairs(listv or {}) do selected[tostring(v)] = true end
		marks(true)
		emit(obj, silent)
	end
	function obj:Reset() obj:Set(obj.Default) end
	click.MouseButton1Click:Connect(function()
		open = not open
		tween(card, { Size = UDim2.new(1, 0, 0, open and (40 + math.min(#options, MAXV) * ROW + 6) or 36) }, 0.15)
		tween(arrow, { Rotation = open and 180 or 0 }, 0.15)
	end)
	return register(self, obj, flag, callback)
end

function TabMT:CreateInput(text, placeholder, callback, flag)
	local value = tostring(initial(flag, "") or "")
	local card = makeCard(self, 36)
	label(card, { Text = tostring(text or "Input"), Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(12, 0) }, "Text")
	local box = new("TextBox", {
		Text = value, PlaceholderText = placeholder or "", Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, -12, 0, 26), Position = UDim2.new(0.5, 0, 0.5, -13), Parent = card,
	}, { TextColor3 = "Text", PlaceholderColor3 = "SubText", BackgroundColor3 = "Input" })
	corner(box, 5)
	pad(box, 8, 0, 8, 0)
	local obj = { Instance = card, Type = "Input", Default = "" }
	function obj:Get() return box.Text end
	function obj:Set(v, silent) box.Text = tostring(v or ""); emit(obj, silent) end
	function obj:Reset() obj:Set("") end
	box.FocusLost:Connect(function() emit(obj, false) end)
	return register(self, obj, flag, callback)
end

function TabMT:CreateKeybind(text, defaultKey, callback, flag)
	local function toKey(k)
		if typeof(k) == "EnumItem" then return k end
		if type(k) == "string" then
			local ok, v = pcall(function() return Enum.KeyCode[k] end)
			if ok and v then return v end
		end
		return nil
	end
	local def = toKey(defaultKey) or Enum.KeyCode.Unknown
	local key = toKey(initial(flag, nil)) or def
	local listening = false
	local changed = {}

	local card = makeCard(self, 36)
	label(card, { Text = tostring(text or "Keybind"), Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(12, 0) }, "Text")
	local btn = new("TextButton", {
		Font = Enum.Font.GothamMedium, TextSize = 11, Size = UDim2.fromOffset(80, 26), Position = UDim2.new(1, -92, 0.5, -13),
		AutoButtonColor = false, Parent = card,
	}, { TextColor3 = "Accent", BackgroundColor3 = "Input" })
	corner(btn, 5)
	local function show() btn.Text = key == Enum.KeyCode.Unknown and "None" or key.Name end
	show()

	local obj = { Instance = card, Type = "Keybind", Default = def }
	function obj:Get() return key.Name end
	obj._cbValue = function() return key end
	function obj:GetKeyCode() return key end
	function obj:Set(k, silent)
		local kc = toKey(k)
		if not kc then return end
		key = kc
		show()
		if flag then Library.Flags[flag] = key end
		if not silent then
			for _, fn in ipairs(changed) do safe(fn, key) end
			if flag then Library:_queueSave() end
		end
	end
	function obj:Reset() obj:Set(obj.Default) end
	function obj:OnChanged(fn) table.insert(changed, fn); return obj end

	btn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		Library._listening = true
		btn.Text = "..."
	end)
	table.insert(Library._keybinds, function(input, gpe)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				Library._listening = false
				if input.KeyCode ~= Enum.KeyCode.Escape then obj:Set(input.KeyCode) else show() end
			end
			return
		end
		if not gpe and key ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key then
			safe(obj._cb, key)
		end
	end)
	return register(self, obj, flag, callback, true)
end

function TabMT:CreateColorPicker(text, defaultColor, callback, flag)
	local def = typeof(defaultColor) == "Color3" and defaultColor or rgb(255, 255, 255)
	local color = def
	local saved = initial(flag, nil)
	if type(saved) == "string" then color = fromHex(saved) or def end
	local open = false

	local card = makeCard(self, 36)
	label(card, { Text = tostring(text or "Color"), Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(12, 0) }, "Text")
	local preview = new("TextButton", { Text = "", Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -38, 0, 5), AutoButtonColor = false, Parent = card })
	corner(preview, 5)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.7, Parent = preview })

	local panel = new("Frame", { Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 106), BackgroundTransparency = 1, Parent = card })
	local ch, fills = { R = 0, G = 0, B = 0 }, {}
	local hexBox
	local obj = { Instance = card, Type = "ColorPicker", Default = def }

	local function refresh()
		preview.BackgroundColor3 = color
		ch.R, ch.G, ch.B = math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
		for k, f in pairs(fills) do f.Size = UDim2.fromScale(ch[k] / 255, 1) end
		if hexBox then hexBox.Text = "#" .. toHex(color) end
	end
	local function setColor(c, silent)
		color = c
		refresh()
		emit(obj, silent)
	end
	local names = { "R", "G", "B" }
	for i, name in ipairs(names) do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, (i - 1) * 26), BackgroundTransparency = 1, Parent = panel })
		label(row, { Text = name, Size = UDim2.fromOffset(16, 22), TextSize = 11 }, "SubText")
		local tr = new("Frame", { Size = UDim2.new(1, -26, 0, 6), Position = UDim2.new(0, 22, 0.5, -3), Parent = row }, { BackgroundColor3 = "Input" })
		corner(tr, 3)
		local fl = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = tr }, { BackgroundColor3 = "Accent" })
		corner(fl, 3)
		fills[name] = fl
		local hit = new("TextButton", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundTransparency = 1, Text = "", Parent = tr })
		local function fromInput(inp)
			local ratio = math.clamp((inp.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
			ch[name] = math.floor(ratio * 255 + 0.5)
			setColor(Color3.fromRGB(ch.R, ch.G, ch.B))
		end
		hit.InputBegan:Connect(function(inp) if isPress(inp) then fromInput(inp); startDrag(fromInput) end end)
	end
	local hexRow = new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 80), BackgroundTransparency = 1, Parent = panel })
	label(hexRow, { Text = "HEX", Size = UDim2.fromOffset(34, 24), TextSize = 11 }, "SubText")
	hexBox = new("TextBox", {
		Font = Enum.Font.Code, TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(38, 0), Parent = hexRow,
	}, { TextColor3 = "Text", BackgroundColor3 = "Input" })
	corner(hexBox, 5)
	pad(hexBox, 8, 0, 8, 0)
	hexBox.FocusLost:Connect(function()
		local c = fromHex(hexBox.Text)
		if c then setColor(c) else refresh() end
	end)
	refresh()

	function obj:Get() return toHex(color) end
	obj._cbValue = function() return color end
	function obj:GetColor3() return color end
	function obj:Set(v, silent)
		local c = v
		if type(v) == "string" then c = fromHex(v) end
		if typeof(c) ~= "Color3" then return end
		setColor(c, silent)
	end
	function obj:Reset() obj:Set(obj.Default) end
	preview.MouseButton1Click:Connect(function()
		open = not open
		tween(card, { Size = UDim2.new(1, 0, 0, open and 154 or 36) }, 0.15)
	end)
	return register(self, obj, flag, callback)
end

function TabMT:CreateThemePicker(text)
	local names, map = {}, {}
	for _, key in ipairs(Library.ThemeOrder) do
		local dn = Library.Themes[key].DisplayName or key
		table.insert(names, dn)
		map[dn] = key
	end
	local dd = self:CreateDropdown(text or "Theme", names, Library.Themes[Library.ThemeName].DisplayName, nil, nil)
	dd._cb = function(dn) if map[dn] then Library:SetTheme(map[dn]) end end
	return dd
end

function TabMT:CreateToggleMenuKeybind(text)
	local win = self.Window
	local kb = self:CreateKeybind(text or "คีย์เปิด-ปิดเมนู", win.ToggleKey or Enum.KeyCode.RightControl, nil, "ui.togglekey")
	win.ToggleKey = kb:GetKeyCode()
	kb:OnChanged(function(k) win.ToggleKey = k end)
	return kb
end

function TabMT:CreateCFrameCopier(text)
	local card = makeCard(self, 36)
	label(card, { Text = tostring(text or "คัดลอกตำแหน่งที่ยืน (CFrame)"), Size = UDim2.new(1, -92, 0, 36), Position = UDim2.fromOffset(12, 0) }, "Text")
	local btn = new("TextButton", {
		Text = "คัดลอก", Font = Enum.Font.GothamBold, TextSize = 11, Size = UDim2.fromOffset(72, 26), Position = UDim2.new(1, -84, 0, 5),
		AutoButtonColor = false, Parent = card,
	}, { TextColor3 = "Text", BackgroundColor3 = "Input" })
	corner(btn, 5)
	local out = new("TextBox", {
		Text = "", Font = Enum.Font.Code, TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 40), Visible = false, Parent = card,
	}, { TextColor3 = "SubText", BackgroundColor3 = "Input" })
	corner(out, 5)
	pad(out, 8, 0, 8, 0)
	btn.MouseButton1Click:Connect(function()
		local s = Library:GetCharacterCFrameString()
		if not s then Library:Notify("CFrame", "ไม่พบตัวละคร (Character) ในตอนนี้", 3) return end
		out.Text = s
		out.Visible = true
		tween(card, { Size = UDim2.new(1, 0, 0, 74) }, 0.15)
		if not Library:CopyCharacterCFrame() then out:CaptureFocus() end
	end)
	return { GetCFrameString = function() return Library:GetCharacterCFrameString() end }
end

----------------------------------------------------------------------
-- WINDOW METHODS
----------------------------------------------------------------------
function WindowMT:SetIcon(id) if self.BrandIcon then self.BrandIcon.Image = id end end
function WindowMT:SetTitle(t) self.TitleLabel.Text = tostring(t) end
function WindowMT:SetSubtitle(t) self.SubtitleLabel.Text = tostring(t) end
function WindowMT:SetVisible(v)
	v = v and true or false
	if not self.Loaded or self._shown == v then return end
	self._shown = v
	local main, sc = self.Main, self._scale
	if v then
		main.Visible = true
		tween(main, { GroupTransparency = 0 }, 0.22)
		tween(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
	else
		self.Modal.Visible = false
		local tw = tween(main, { GroupTransparency = 1 }, 0.18)
		tween(sc, { Scale = 0.94 }, 0.18)
		tw.Completed:Connect(function() if not self._shown then main.Visible = false end end)
	end
end
function WindowMT:Toggle() self:SetVisible(not self._shown) end
function WindowMT:FadeDestroy()
	if self._dying then return end
	self._dying = true
	if not (self.Loaded and self._shown) then self:Destroy() return end
	tween(self._scale, { Scale = 0.9 }, 0.25)
	local tw = tween(self.Main, { GroupTransparency = 1 }, 0.25)
	tw.Completed:Connect(function() self:Destroy() end)
end
function WindowMT:Notify(...) Library:Notify(...) end
function WindowMT:SetTheme(k) return Library:SetTheme(k) end
function WindowMT:SaveConfig(s) return Library:SaveConfig(s) end
function WindowMT:LoadConfig(s) return Library:LoadConfig(s) end
function WindowMT:ResetConfig(s) return Library:ResetConfig(s) end
function WindowMT:Minimize() self._setMin(true) end
function WindowMT:Maximize() self._setMax(not self._maximized) end
function WindowMT:ResetLayout() self._resetLayout() end

-- สร้างหน้า Account / Settings ใหม่ด้วยภาษาปัจจุบัน
function WindowMT:_rebuildTabs()
	if not (self.ScreenGui and self.ScreenGui.Parent) then return end
	local cfg = self._cfg or {}
	local active = self.ActiveTab
	local reselect
	if active and active == self.AccountTab then reselect = "acc" elseif active and active == self.SettingsTab then reselect = "set" end
	local function kill(t)
		if not t then return end
		for i, x in ipairs(self.Tabs) do if x == t then table.remove(self.Tabs, i) break end end
		pcall(function() t.Button:Destroy() end)
		pcall(function() t.MainPage:Destroy() end)
	end
	kill(self.AccountTab)
	kill(self.SettingsTab)
	self.AccountTab, self.SettingsTab = nil, nil
	if reselect then self.ActiveTab = nil end
	if cfg.Account ~= false then self.AccountTab = self:_buildAccount(cfg) end
	if cfg.Settings ~= false then self.SettingsTab = self:_buildSettings() end
	if reselect == "acc" and self.AccountTab then self:SelectTab(self.AccountTab)
	elseif reselect == "set" and self.SettingsTab then self:SelectTab(self.SettingsTab) end
	self:_filter()
end

function WindowMT:_applyLang()
	if self._applyStatic then self._applyStatic() end
	task.defer(function() self:_rebuildTabs() end)
end

function Library:SetLang(code)
	if code ~= "en" then code = "th" end
	if self.Lang == code then return end
	self.Lang = code
	self._config["ui.lang"] = code
	for _, w in ipairs(self.Windows) do w:_applyLang() end
	self:Notify(T("tab_settings"), T("lang_changed"), 2)
	self:_queueSave()
end

function WindowMT:Destroy()
	for i, w in ipairs(Library.Windows) do if w == self then table.remove(Library.Windows, i) break end end
	for i, g in ipairs(Library._guis) do if g == self.ScreenGui then table.remove(Library._guis, i) break end end
	if self.ScreenGui then self.ScreenGui:Destroy() end
	if #Library.Windows == 0 then Library:Unload() end
end

function WindowMT:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		t.MainPage.Visible = false
		tween(t.Button, { BackgroundTransparency = 1 }, 0.15)
		t.Indicator.BackgroundTransparency = 1
		bindColor(t.Label, "TextColor3", "SubText")
		bindColor(t.IconObj, t.IconProp, "SubText")
	end
	tab.MainPage.Visible = true
	tween(tab.Button, { BackgroundTransparency = 0.25 }, 0.15)
	tab.Indicator.BackgroundTransparency = 0
	bindColor(tab.Label, "TextColor3", "Text")
	bindColor(tab.IconObj, tab.IconProp, "Accent")
	self.Header.Text = tab.Name
	self.ActiveTab = tab
	if self.Loaded then
		tab.MainPage.Position = UDim2.fromOffset(0, 14)
		tween(tab.MainPage, { Position = UDim2.new() }, 0.28, Enum.EasingStyle.Quint)
		tab.Page.BackgroundTransparency = 1
		tween(tab.Page, { BackgroundTransparency = 0.35 }, 0.3)
		self.Header.TextTransparency = 1
		tween(self.Header, { TextTransparency = 0 }, 0.25)
	end
end

function WindowMT:_filter()
	local q = self.SearchBox.Text:lower()
	for _, t in ipairs(self.Tabs) do
		t.Button.Visible = not t.Hidden and (q == "" or t.Name:lower():find(q, 1, true) ~= nil)
	end
end

function WindowMT:CreateTab(name, icon, order, internal)
	local win = self
	name = tostring(name or "Tab")
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		LayoutOrder = order or (internal and 10000 or (#self.Tabs + 1) * 10), Parent = self.TabList,
	}, { BackgroundColor3 = "AccentSoft" })
	corner(btn, 9)
	local indicator = new("Frame", { Visible = false, Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 0, 0.5, -8), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = btn }, { BackgroundColor3 = "Accent" })
	corner(indicator, 2)
	local iconHolder = new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 10, 0.5, -11), BackgroundTransparency = 1, Parent = btn })
	local iconObj, iconProp
	local asset = icon
	if type(asset) == "number" then asset = "rbxassetid://" .. asset end
	if type(asset) == "string" and (asset:find("rbxasset") or asset:match("^%d+$")) then
		if asset:match("^%d+$") then asset = "rbxassetid://" .. asset end
		iconObj = new("ImageLabel", { Image = asset, BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), ScaleType = Enum.ScaleType.Fit, Parent = iconHolder }, { ImageColor3 = "SubText" })
		iconProp = "ImageColor3"
	else
		iconObj = label(iconHolder, { Text = tostring(icon or name:sub(1, 1):upper()), Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, "SubText")
		iconProp = "TextColor3"
	end
	local lbl = label(btn, { Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -46, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, "SubText")

	local page = new("ScrollingFrame", {
		Name = name .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = self.Pages,
	}, { ScrollBarImageColor3 = "Accent" })
	local section = new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.35, Parent = page }, { BackgroundColor3 = "Card" })
	corner(section, 8)
	stroke(section, "Stroke", 0.4)
	pad(section, 14, 14, 14, 14)
	list(section, 12)
	pad(page, 0, 0, 0, 10)

	local tab = setmetatable({
		Page = section, MainPage = page, Button = btn, Label = lbl, Indicator = indicator, IconObj = iconObj, IconProp = iconProp,
		Name = name, Window = win, _n = 0,
	}, TabMT)
	function tab:Select() win:SelectTab(tab) end
	function tab:_setCompact(c)
		lbl.Visible = not c
		iconHolder.Position = c and UDim2.new(0.5, -11, 0.5, -11) or UDim2.new(0, 10, 0.5, -11)
	end
	tab:_setCompact(self._compact)
	bindColor(iconObj, iconProp, "SubText")
	btn.MouseButton1Click:Connect(function() win:SelectTab(tab) end)
	btn.MouseEnter:Connect(function() if win.ActiveTab ~= tab then tween(btn, { BackgroundTransparency = 0.7 }, 0.1) end end)
	btn.MouseLeave:Connect(function() if win.ActiveTab ~= tab then tween(btn, { BackgroundTransparency = 1 }, 0.12) end end)

	table.insert(self.Tabs, tab)
	if not internal and not self._userTab then
		self._userTab = true
		self:SelectTab(tab)
	end
	return tab
end

function WindowMT:_buildSettings()
	local tab = self:CreateTab(T("tab_settings"), "S", nil, true)

	local lg = tab:CreateGroupbox(T("set_language_box"))
	local dd = lg:CreateDropdown(T("set_language"), { "ไทย", "English" }, Library.Lang == "en" and "English" or "ไทย", nil, nil)
	dd._cb = function(v) Library:SetLang(v == "English" and "en" or "th") end

	local ap = tab:CreateGroupbox(T("set_appearance"))
	ap:CreateThemePicker(T("set_theme"))
	local picker = ap:CreateColorPicker(T("set_accent"), Theme.Accent, nil, nil)
	picker._cb = function(c) Library:SetAccent(c) end
	ap:CreateButton(T("set_reset_accent"), function()
		Library:SetAccent(nil)
		picker:Set(Theme.Accent, true)
	end)

	local wn = tab:CreateGroupbox(T("set_window"))
	wn:CreateToggleMenuKeybind(T("set_togglekey"))
	wn:CreateButton(T("set_resetwin"), function() self:ResetLayout() end)
	wn:CreateButton(T("set_unload"), function() Library:Unload() end)

	local cf = tab:CreateGroupbox(T("set_config"))
	cf:CreateParagraph(T("set_autosave"), fsAvailable()
		and T("set_autosave_fs", Library:_path())
		or T("set_autosave_nofs"))
	cf:CreateToggle(T("set_autosave"), Library.AutoSave, function(v) Library.AutoSave = v end)
	cf:CreateButton(T("set_save"), function() Library:SaveConfig() end)
	cf:CreateButton(T("set_load"), function() Library:LoadConfig() end)
	cf:CreateButton(T("set_reset"), function() Library:ResetConfig() end)

	local tl = tab:CreateGroupbox(T("set_tools"))
	tl:CreateCFrameCopier(T("set_cframe"))
	return tab
end

----------------------------------------------------------------------
-- CREATE WINDOW
----------------------------------------------------------------------
local function parentGui(gui)
	local targets = {}
	if type(gethui) == "function" then table.insert(targets, function() return gethui() end) end
	table.insert(targets, function() return CoreGui end)
	table.insert(targets, function() return LocalPlayer:WaitForChild("PlayerGui") end)
	for _, get in ipairs(targets) do
		local ok, parent = pcall(get)
		if ok and parent then
			local old = parent:FindFirstChild(gui.Name)
			if old and old ~= gui then pcall(function() old:Destroy() end) end
		end
	end
	for _, get in ipairs(targets) do
		local ok = pcall(function() gui.Parent = get() end)
		if ok and gui.Parent then return end
	end
end

----------------------------------------------------------------------
-- KEY SYSTEM (Supabase)
----------------------------------------------------------------------
local function httpRequest(opts)
	local req = (type(request) == "function" and request)
		or (type(http_request) == "function" and http_request)
		or (syn and type(syn.request) == "function" and syn.request)
		or (fluxus and type(fluxus.request) == "function" and fluxus.request)
	if req then return pcall(req, opts) end
	return pcall(function() return HttpService:RequestAsync(opts) end)
end

local function getHwid()
	local ok, v = pcall(function()
		if type(gethwid) == "function" then return gethwid() end
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	return ok and tostring(v) or nil
end

local function keyFile(folder)
	if hasFolders() then return folder .. "/key.txt" end
	return folder .. "_key.txt"
end
local function readSavedKey(folder)
	if not fsAvailable() then return nil end
	local ok, exists = pcall(isfile, keyFile(folder))
	if not (ok and exists) then return nil end
	local ok2, raw = pcall(readfile, keyFile(folder))
	if not ok2 then return nil end
	raw = tostring(raw):gsub("%s+", "")
	return raw ~= "" and raw or nil
end
local function writeSavedKey(folder, key)
	if not fsAvailable() then return end
	pcall(function()
		if hasFolders() and not isfolder(folder) then makefolder(folder) end
		writefile(keyFile(folder), key or "")
	end)
end


-- แปลงเวลา ISO (จาก Supabase) -> unix timestamp
local function isoToTs(str)
	if type(str) ~= "string" or str == "" then return nil end
	str = str:gsub(" ", "T", 1)
	str = str:gsub("(%d%d:%d%d:%d%d)%.%d+", "%1")
	str = str:gsub("([+-]%d%d)$", "%1:00")
	if not str:find("[Zz]$") and not str:find("[+-]%d%d:%d%d$") then str = str .. "Z" end
	local ok, dt = pcall(DateTime.fromIsoDate, str)
	return ok and dt and dt.UnixTimestamp or nil
end

-- 3600 -> "01:00:00" , 90000 -> "1d 01h 00m 00s"
function Library:FormatTime(s)
	if s == nil or s == math.huge then return T("acc_lifetime") end
	s = math.max(0, math.floor(s))
	local d, h, m, sec = s // 86400, (s % 86400) // 3600, (s % 3600) // 60, s % 60
	if d > 0 then return string.format("%dd %02dh %02dm %02ds", d, h, m, sec) end
	return string.format("%02d:%02d:%02d", h, m, sec)
end

-- อายุคีย์ (นับขึ้น ไม่มีลด): <1 ชม. = นาที | <1 วัน = "1 ชั่วโมง" / "1 ชั่วโมง 30 นาที" | >=1 วัน = "30 วัน"
function Library:FormatAge(s)
	s = math.max(0, math.floor(s or 0))
	local d, h, m = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
	if d > 0 then return T("age_d", d) end
	if h > 0 then return m > 0 and T("age_hm", h, m) or T("age_h", h) end
	return T("age_m", m)
end

-- เหลือเวลากี่วินาที (nil = ยังไม่ผ่านคีย์, math.huge = ตลอดชีพ) ใช้ตัดสินหมดอายุจริง
function Library:GetKeyRemaining()
	local k = self.KeyInfo
	if not (k and k.ok) then return nil end
	if not k.expireClock then return math.huge end
	return math.max(0, k.expireClock - os.clock())
end

-- เวลาที่เหลือ "สำหรับแสดงผล" (นับสด) -- คีย์ never=true ไม่ถูกตัดแม้เวลาถึง 0
function Library:GetDisplayRemaining()
	local k = self.KeyInfo
	if not (k and k.ok) then return nil end
	if k.expireClock then return math.max(0, k.expireClock - os.clock()) end
	if k.never and k.expiresAt then
		if k._expTs == nil then k._expTs = isoToTs(k.expiresAt) or false end
		if k._expTs then
			local left = k._expTs - DateTime.now().UnixTimestamp
			if left > 0 then return left end
		end
	end
	return math.huge
end

function Library:_rpc(cfg, fn, body)
	local url = (tostring(cfg.SupabaseUrl or ""):gsub("/+$", ""))
	local headers = { ["Content-Type"] = "application/json", ["apikey"] = cfg.SupabaseKey }
	-- คีย์แบบเก่า (eyJ...) เป็น JWT ส่งใน Authorization ได้ / คีย์ใหม่ (sb_publishable_...) ไม่ใช่ JWT ห้ามส่ง
	if not tostring(cfg.SupabaseKey):find("^sb_") then
		headers["Authorization"] = "Bearer " .. tostring(cfg.SupabaseKey)
	end
	local ok, res = httpRequest({
		Url = url .. "/rest/v1/rpc/" .. fn,
		Method = "POST",
		Headers = headers,
		Body = HttpService:JSONEncode(body),
	})
	if not ok or type(res) ~= "table" then return nil, "network" end
	local code = res.StatusCode or res.status_code or 0
	local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body or res.body or "") end)
	if code < 200 or code >= 300 or not ok2 then return nil, "http " .. tostring(code) end
	return data
end

-- เติมค่าที่ขาดจาก Library.Supabase (cfg.SupabaseUrl / SupabaseKey ใส่ทับได้ถ้าต้องการ)
local function resolveKeyCfg(cfg)
	cfg.SupabaseUrl = cfg.SupabaseUrl or Library.Supabase.Url
	cfg.SupabaseKey = cfg.SupabaseKey or Library.Supabase.Key
	return cfg
end

-- ดึงค่า plan ของคีย์ (text) : ลอง RPC get_plan ก่อน แล้วค่อยอ่านตรงจากตาราง
-- คืน plan หรือ nil + ข้อความ error (เอาไว้ debug)
function Library:FetchPlan(key)
	key = tostring(key or "")
	if key == "" then return nil, "empty key" end
	local sb = self.Supabase
	local errs = {}

	local d, e = self:_rpc({ SupabaseUrl = sb.Url, SupabaseKey = sb.Key }, "get_plan", { p_key = key })
	if type(d) == "table" and d.plan ~= nil and tostring(d.plan) ~= "" then return tostring(d.plan) end
	table.insert(errs, "rpc get_plan: " .. tostring(e or "no plan"))

	local url = (tostring(sb.Url or ""):gsub("/+$", ""))
	local headers = { ["apikey"] = sb.Key }
	if not tostring(sb.Key):find("^sb_") then headers["Authorization"] = "Bearer " .. tostring(sb.Key) end
	local col = sb.PlanColumn or "plan"
	local ok, res = httpRequest({
		Url = string.format("%s/rest/v1/%s?%s=eq.%s&select=%s&limit=1", url, sb.Table or "license_keys", sb.KeyColumn or "key", HttpService:UrlEncode(key), col),
		Method = "GET",
		Headers = headers,
	})
	if not ok or type(res) ~= "table" then
		table.insert(errs, "table: network")
		return nil, table.concat(errs, " | ")
	end
	local code = res.StatusCode or res.status_code or 0
	if code < 200 or code >= 300 then
		table.insert(errs, "table: http " .. tostring(code))
		return nil, table.concat(errs, " | ")
	end
	local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body or res.body or "") end)
	if not ok2 or type(data) ~= "table" or type(data[1]) ~= "table" then
		table.insert(errs, "table: 0 rows (RLS บล็อก / ชื่อคอลัมน์คีย์ไม่ตรง)")
		return nil, table.concat(errs, " | ")
	end
	local v = data[1][col]
	if v == nil or v == "" then
		table.insert(errs, "table: plan ว่าง")
		return nil, table.concat(errs, " | ")
	end
	return tostring(v)
end

-- ตรวจ + ผูกคีย์กับผู้ใช้ (ครั้งแรกจะบันทึกชื่อผู้ใช้ลง Supabase และเริ่มนับเวลา)
function Library:VerifyKey(cfg, key)
	key = (tostring(key or ""):gsub("%s+", ""))
	if key == "" then return { ok = false, reason = "empty", message = "กรุณาใส่คีย์ก่อน" } end
	resolveKeyCfg(cfg)
	local url, anon = tostring(cfg.SupabaseUrl or ""), tostring(cfg.SupabaseKey or "")
	if url == "" or anon == "" or url:find("xxxx", 1, true) or anon == "anon key ของคุณ" then
		return { ok = false, reason = "config", message = "ยังไม่ได้ใส่ Supabase Url / Key ใน Library.Supabase" }
	end
	local data, err = self:_rpc(cfg, "use_key", {
		p_key = key, p_username = LocalPlayer.Name, p_user_id = LocalPlayer.UserId, p_hwid = getHwid(),
	})
	if not data then
		return { ok = false, reason = "network", message = "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (" .. tostring(err) .. ")" }
	end
	-- enabled = false -> เซิร์ฟเวอร์ปิดคีย์ไว้ (เปิด/ปิดได้ตลอดเวลาจากตาราง)
	if data.enabled == false or data.reason == "disabled" then
		return { ok = false, reason = "disabled", message = T("r_disabled") }
	end
	if data.ok then
		-- never = true -> คีย์ไม่หมดอายุ (ไม่สนค่า remaining / expires_at)
		local never = data.never == true
		local rem = (not never) and tonumber(data.remaining) or nil
		return {
			ok = true, key = key, reason = data.reason, username = data.username,
			never = never, enabled = data.enabled ~= false,
			lifetime = rem == nil, remaining = rem, expireClock = rem and (os.clock() + rem) or nil,
			expiresAt = (not never) and data.expires_at or nil, activatedAt = data.activated_at, note = data.note, plan = data.plan ~= nil and tostring(data.plan) or nil, hwid = getHwid(),
		}
	end
	return { ok = false, reason = data.reason, message = I18N[Library.Lang]["r_" .. tostring(data.reason)] or T("r_fail") }
end

-- เฝ้าคีย์ระหว่างใช้งาน: หมดเวลา/ถูกยกเลิก -> เฟดปิด UI
function Library:_keyWatch(cfg)
	self._keyWatchId = (self._keyWatchId or 0) + 1
	local id = self._keyWatchId
	task.spawn(function()
		local last = os.clock()
		while self.KeyInfo and self._keyWatchId == id do
			task.wait(1)
			if not (self.KeyInfo and self._keyWatchId == id) then return end
			local rem = self:GetKeyRemaining()
			local dead, msg = rem ~= nil and rem <= 0, T("r_expired")
			if not dead and os.clock() - last >= (cfg.RecheckInterval or 30) then
				last = os.clock()
				local r = self:VerifyKey(cfg, self.KeyInfo.key)
				if r.ok then
					r.plan = r.plan or self.KeyInfo.plan
					self.KeyInfo = r
				elseif r.reason ~= "network" then
					dead, msg = true, r.message
				end
			end
			if dead then
				self:Notify("Key", msg .. " " .. T("closing"), 4)
				task.wait(2.5)
				self.KeyInfo = nil
				local wins = { table.unpack(self.Windows) }
				for _, w in ipairs(wins) do w:FadeDestroy() end
				task.wait(0.5)
				self:Unload()
				return
			end
		end
	end)
end

function Library:KeySystem(cfg)
	if cfg == true or cfg == nil then cfg = {} end
	if cfg.Enabled == false then return true end
	resolveKeyCfg(cfg)
	if self.KeyInfo and self.KeyInfo.ok then return true, self.KeyInfo end

	self.Folder = cfg.Folder or self.Folder
	self._keyFolder = self.Folder
	self:_readConfig()
	self:_loadLang()
	if type(self._config["ui.accent"]) == "string" then self._accent = fromHex(self._config["ui.accent"]) end
	self:_loadPreset(resolveTheme(self._config["ui.theme"]) or resolveTheme(cfg.Theme) or "blue")

	local Gui = new("ScreenGui", { Name = "VortexKey", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	parentGui(Gui)
	table.insert(self._guis, Gui)

	local Backdrop = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.5, BorderSizePixel = 0, GroupTransparency = 1, Active = true, Parent = Gui,
	}, { BackgroundColor3 = "Background" })

	local vpK = viewport()
	local cw = math.clamp(vpK.X * 0.92, 300, 540)
	local wide = cw >= 460
	local ch = wide and 222 or 300
	local Card = new("Frame", {
		Size = UDim2.fromOffset(cw, ch), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 26),
		BackgroundTransparency = 0.03, Parent = Backdrop,
	}, { BackgroundColor3 = "Background" })
	corner(Card, 14)
	local CStroke = stroke(Card, "Accent", 0.2)
	CStroke.Thickness = 1.6
	local CScale = new("UIScale", { Scale = 0.9, Parent = Card })

	-- หัวการ์ด: โลโก้เล็ก + ชื่อ + คำอธิบายใต้ชื่อ
	local img = tostring(cfg.Image or cfg.Icon or "")
	if tonumber(img) then img = "rbxassetid://" .. img end
	local hx = 20
	if img ~= "" then
		local lg = new("ImageLabel", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(18, 14), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Parent = Card })
		corner(lg, 8)
		hx = 58
	end
	label(Card, { Text = tostring(cfg.Title or "Key System"), Font = Enum.Font.GothamBold, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(hx, 13), Size = UDim2.new(1, -(hx + 44), 0, 20) }, "Text")
	label(Card, { Text = tostring(cfg.Subtitle or "Key System"), TextSize = 11, Position = UDim2.fromOffset(hx, 33), Size = UDim2.new(1, -(hx + 44), 0, 14) }, "SubText")

	-- ซ้าย: ช่องกรอก + ปุ่ม + สถานะ | ขวา: ข้อความอธิบาย
	local colW = wide and 240 or (cw - 40)
	local Input = new("TextBox", {
		Text = "", PlaceholderText = "key", Font = Enum.Font.GothamMedium, TextSize = 13, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(colW, 38), Position = UDim2.fromOffset(20, 70), Parent = Card,
	}, { BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "SubText" })
	corner(Input, 8)
	pad(Input, 12, 0, 12, 0)
	local IStroke = stroke(Input, "Stroke", 0.1)
	Input.Focused:Connect(function() tween(IStroke, { Color = Theme.Accent }, 0.15) end)
	Input.FocusLost:Connect(function() tween(IStroke, { Color = Theme.Stroke }, 0.2) end)

	local Row = new("Frame", { Size = UDim2.fromOffset(colW, 34), Position = UDim2.fromOffset(20, 118), BackgroundTransparency = 1, Parent = Card })
	local hasLink = cfg.GetKeyLink ~= nil and tostring(cfg.GetKeyLink) ~= ""

	local function press(btn)
		local sc = new("UIScale", { Parent = btn })
		btn.MouseEnter:Connect(function() tween(btn, { BackgroundTransparency = 0 }, 0.12) end)
		btn.MouseLeave:Connect(function() tween(btn, { BackgroundTransparency = 0.15 }, 0.15) tween(sc, { Scale = 1 }, 0.1) end)
		btn.MouseButton1Down:Connect(function() tween(sc, { Scale = 0.95 }, 0.08) end)
		btn.MouseButton1Up:Connect(function() tween(sc, { Scale = 1 }, 0.14, Enum.EasingStyle.Back) end)
	end

	local VerifyBtn = new("TextButton", {
		Text = "ตรวจสอบคีย์", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.AccentText, AutoButtonColor = false,
		Size = hasLink and UDim2.new(0.6, -4, 1, 0) or UDim2.fromScale(1, 1), BackgroundTransparency = 0.15, Parent = Row,
	}, { BackgroundColor3 = "Accent" })
	corner(VerifyBtn, 8)
	press(VerifyBtn)

	local GetBtn
	if hasLink then
		GetBtn = new("TextButton", {
			Text = "รับคีย์", Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
			Size = UDim2.new(0.4, -4, 1, 0), Position = UDim2.new(0.6, 4, 0, 0), BackgroundTransparency = 0.15, Parent = Row,
		}, { BackgroundColor3 = "Input", TextColor3 = "Text" })
		corner(GetBtn, 8)
		stroke(GetBtn, "Stroke", 0.3)
		press(GetBtn)
	end

	local Status = label(Card, { Text = "", TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(20, 160), Size = UDim2.fromOffset(colW, 44) }, "SubText")

	local descText = tostring(cfg.Description or ("ใส่คีย์ที่ได้จากแอดมินเพื่อเข้าใช้งาน" .. (cfg.Discord and ("\nหากไม่มีคีย์ ติดต่อ " .. tostring(cfg.Discord)) or "")))
	label(Card, {
		Text = descText, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		Position = wide and UDim2.fromOffset(280, 70) or UDim2.fromOffset(20, 206), Size = wide and UDim2.new(1, -300, 0, 134) or UDim2.new(1, -40, 0, 70),
	}, "SubText")

	local CloseX = new("TextButton", {
		Text = "X", Font = Enum.Font.GothamBold, TextSize = 15, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 8),
		BackgroundTransparency = 1, AutoButtonColor = false, Parent = Card,
	}, { TextColor3 = "Text" })
	CloseX.MouseEnter:Connect(function() tween(CloseX, { TextColor3 = Theme.Error }, 0.12) end)
	CloseX.MouseLeave:Connect(function() tween(CloseX, { TextColor3 = Theme.Text }, 0.12) end)

	-- ----- logic -----
	local busy, finished, result = false, false, false
	local done = Instance.new("BindableEvent")
	local hb = RunService.Heartbeat:Connect(function()
		CStroke.Transparency = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(os.clock() * 2.2))
	end)
	Gui.Destroying:Connect(function()
		finished = true
		hb:Disconnect()
		done:Fire()
	end)

	local function setStatus(text, kind)
		Status.Text = text
		local col = kind == "ok" and Theme.Success or kind == "err" and Theme.Error or Theme.SubText
		Status.TextTransparency = 0.7
		tween(Status, { TextColor3 = col, TextTransparency = 0 }, 0.25)
	end

	local function shake()
		for _, dx in ipairs({ 10, -10, 6, -6, 0 }) do
			tween(Card, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05, Enum.EasingStyle.Sine)
			task.wait(0.05)
		end
	end

	local function close(ok)
		if finished then return end
		finished, result = true, ok
		tween(CScale, { Scale = ok and 1.06 or 0.9 }, 0.3)
		tween(Card, { Position = UDim2.new(0.5, 0, 0.5, ok and -10 or 20) }, 0.3)
		local t = tween(Backdrop, { GroupTransparency = 1 }, 0.35)
		t.Completed:Connect(function()
			for i, g in ipairs(self._guis) do if g == Gui then table.remove(self._guis, i) break end end
			Gui:Destroy()
		end)
	end

	local function attempt(key)
		if busy or finished then return end
		busy = true
		local spinning = true
		task.spawn(function()
			local n = 0
			while spinning and Gui.Parent do
				n = n % 3 + 1
				VerifyBtn.Text = "กำลังตรวจสอบ" .. string.rep(".", n)
				task.wait(0.3)
			end
		end)
		setStatus("กำลังเชื่อมต่อฐานข้อมูล...", nil)
		local r = self:VerifyKey(cfg, key)
		spinning = false
		if finished then return end
		VerifyBtn.Text = "ตรวจสอบคีย์"
		if r.ok then
			self.KeyInfo = r
			if cfg.SaveKey ~= false then writeSavedKey(self.Folder, r.key) end
			tween(IStroke, { Color = Theme.Success }, 0.2)
			setStatus(r.remaining and ("สำเร็จ! เหลือเวลา " .. self:FormatTime(r.remaining)) or "สำเร็จ! คีย์ตลอดชีพ", "ok")
			task.wait(1)
			self:_keyWatch(cfg)
			close(true)
		else
			busy = false
			if r.reason == "invalid" or r.reason == "expired" or r.reason == "revoked" or r.reason == "used_by_other" then
				writeSavedKey(self.Folder, "")
			end
			setStatus(r.message or "คีย์ไม่ถูกต้อง", "err")
			tween(IStroke, { Color = Theme.Error }, 0.15)
			task.spawn(shake)
			task.delay(1, function() if Gui.Parent then tween(IStroke, { Color = Theme.Stroke }, 0.3) end end)
		end
	end

	VerifyBtn.MouseButton1Click:Connect(function() attempt(Input.Text) end)
	Input.FocusLost:Connect(function(enter) if enter then attempt(Input.Text) end end)
	CloseX.MouseButton1Click:Connect(function() if not busy then close(false) end end)
	if GetBtn then
		GetBtn.MouseButton1Click:Connect(function()
			local ok = pcall(function() setclipboard(tostring(cfg.GetKeyLink)) end)
			setStatus(ok and "คัดลอกลิงก์รับคีย์แล้ว นำไปเปิดในเบราว์เซอร์ได้เลย" or ("ลิงก์รับคีย์: " .. tostring(cfg.GetKeyLink)), nil)
		end)
	end

	-- intro: จางเข้า + เด้งขึ้น
	tween(Backdrop, { GroupTransparency = 0 }, 0.3)
	tween(CScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
	tween(Card, { Position = UDim2.fromScale(0.5, 0.5) }, 0.4, Enum.EasingStyle.Quint)

	-- มีคีย์ที่เคยบันทึกไว้ -> ตรวจให้อัตโนมัติ
	local saved = cfg.SaveKey ~= false and readSavedKey(self.Folder) or nil
	if saved then
		Input.Text = saved
		task.spawn(function()
			task.wait(0.5)
			setStatus("พบคีย์ที่บันทึกไว้ กำลังตรวจสอบ...", nil)
			attempt(saved)
		end)
	end

	done.Event:Wait()
	done:Destroy()
	return result, self.KeyInfo
end

----------------------------------------------------------------------
-- ACCOUNT PAGE (สไตล์หน้า Account: ผู้ใช้ / คีย์ / เวลาที่เหลือ / ออกจากระบบ)
----------------------------------------------------------------------
function WindowMT:_buildAccount(config)
	local tab = self:CreateTab(T("tab_account"), config.AccountIcon, 9990, true)
	tab.Hidden = true -- ไม่โชว์ในแถบแท็บ เปิดจากการกดโปรไฟล์ด้านล่าง
	tab.Button.Visible = false
	local page = tab.Page
	local info = Library.KeyInfo
	local order = 0
	local function nextO() order = order + 1 return order end

	local function row(h)
		return new("Frame", { Size = UDim2.new(1, 0, 0, h or 56), BackgroundTransparency = 1, LayoutOrder = nextO(), Parent = page })
	end
	local function divider()
		new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0, LayoutOrder = nextO(), Parent = page }, { BackgroundColor3 = "Stroke" })
	end
	-- ช่องข้อมูล: หัวข้อเล็ก + ค่าตัวหนา (+ บรรทัดย่อย)
	local function cell(parent, right, title, value, sub)
		local f = new("Frame", { Size = UDim2.new(0.5, -6, 1, 0), Position = right and UDim2.new(0.5, 6, 0, 0) or UDim2.new(), BackgroundTransparency = 1, Parent = parent })
		local al = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		label(f, { Text = title, TextSize = 10, TextXAlignment = al, Size = UDim2.new(1, 0, 0, 14) }, "SubText")
		local v = label(f, { Text = tostring(value), Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = al, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 18) }, "Text")
		local sl
		if sub then
			sl = label(f, { Text = tostring(sub), TextSize = 10, TextXAlignment = al, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 35), Size = UDim2.new(1, 0, 0, 14) }, "SubText")
		end
		return v, sl, f
	end

	-- แถว 1: ผู้ใช้ | User ID
	local r1 = row(56)
	local nameV = cell(r1, false, T("acc_account"), LocalPlayer.DisplayName .. "  (@" .. LocalPlayer.Name .. ")")
	nameV.Position, nameV.Size = UDim2.fromOffset(26, 16), UDim2.new(1, -26, 0, 18)
	local av = new("ImageLabel", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(0, 16), BackgroundTransparency = 0.8, Parent = nameV.Parent }, { BackgroundColor3 = "Card" })
	corner(av, 10)
	task.spawn(function()
		pcall(function() av.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	end)
	cell(r1, true, T("acc_userid"), LocalPlayer.UserId)
	divider()

	-- แถว 2: คีย์ (ปิดบางส่วน) + อายุการใช้คีย์ (วัน/ชม.) | อายุบัญชี Roblox
	local r2 = row(56)
	local maskedKey = "-"
	if info and info.key then maskedKey = info.key:sub(1, math.min(8, #info.key)) .. string.rep("*", 8) end
	cell(r2, false, T("acc_key"), maskedKey)
	local ageV = cell(r2, true, T("acc_keyage"), "-")
	divider()

	-- แถว 3: แพลน (ดึงจากตาราง Supabase) | เวลาที่เหลือ (นับสด)
	local r3 = row(60)
	local plan, planSub = T("acc_nolicense"), T("acc_nokeysys")
	if info then
		plan = info.plan or "..."
		local d, t = tostring(info.expiresAt or ""):match("^(%d+%-%d+%-%d+)T(%d+:%d+)")
		if info.never then
			planSub = T("acc_active_never")
		else
			planSub = d and T("acc_active_until", d, t) or T("acc_active_life")
		end
	end
	local planV = cell(r3, false, T("acc_plan"), plan, planSub)
	if info and not info.plan then
		task.spawn(function()
			local p, perr
			for _ = 1, 3 do
				p, perr = Library:FetchPlan(info.key)
				if p or not planV.Parent then break end
				task.wait(3)
			end
			if not p and planV.Parent then
				warn("[VortexUI] FetchPlan: " .. tostring(perr))
				Library:Notify("Plan", tostring(perr), 6)
			end
			if not planV.Parent then return end
			if p then
				info.plan = p
				if Library.KeyInfo then Library.KeyInfo.plan = p end
				planV.Text = p
			else
				planV.Text = "-"
			end
		end)
	end
	local remV, remSub = cell(r3, true, T("acc_remain"), "-", " ")
	task.spawn(function()
		while remV.Parent do
			local k = Library.KeyInfo
			local kp = k and k.plan
			if kp and planV.Text ~= kp then planV.Text = kp end

			-- เวลาที่เหลือ (นับสดทุกวินาที) / คีย์ never = ไม่หมดอายุ แสดงเวลาใช้งานแทน
			local rem = Library:GetDisplayRemaining()
			if rem == nil then
				remV.Text, remSub.Text = "-", ""
				remV.TextColor3 = Theme.Text
			elseif rem == math.huge then
				remV.Text = T("acc_lifetime")
				remSub.Text = T("acc_never_sub", Library:FormatTime(os.clock() - LOAD_CLOCK))
				remV.TextColor3 = Theme.Text
			else
				remV.Text = Library:FormatTime(rem)
				remSub.Text = k and k.never and T("acc_never_sub", Library:FormatTime(os.clock() - LOAD_CLOCK)) or ""
				remV.TextColor3 = (not (k and k.never) and rem < 600) and Theme.Error or Theme.Text
			end

			-- คีย์นี้ใช้มากี่วัน/ชั่วโมง
			if k and k.ok then
				if k._actTs == nil then k._actTs = isoToTs(k.activatedAt) or false end
				local secs = k._actTs and (DateTime.now().UnixTimestamp - k._actTs) or (os.clock() - LOAD_CLOCK)
				ageV.Text = Library:FormatAge(secs)
			else
				ageV.Text = "-"
			end
			task.wait(1)
		end
	end)
	divider()

	-- แถว 4: อุปกรณ์ | Executor
	local r4 = row(56)
	local hw = info and info.hwid and tostring(info.hwid):sub(1, 10) or "-"
	cell(r4, false, T("acc_device"), hw)
	local exName = "Unknown"
	pcall(function() if type(identifyexecutor) == "function" then exName = tostring((identifyexecutor())) end end)
	cell(r4, true, T("acc_exec"), exName)
	divider()

	-- แถว 5: เวอร์ชัน | Place
	local r5 = row(56)
	cell(r5, false, T("acc_ver"), Library.Version)
	cell(r5, true, T("acc_place"), game.PlaceId)

	-- ออกจากระบบ (เฉพาะตอนมีคีย์)
	if info then
		divider()
		local r6 = row(44)
		cell(r6, false, T("acc_signout_desc"), T("acc_signout"))
		local btn = new("TextButton", {
			Text = T("acc_signout"), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(104, 32),
			BackgroundTransparency = 0.7, Parent = r6,
		}, { BackgroundColor3 = "Error", TextColor3 = "Error" })
		corner(btn, 8)
		stroke(btn, "Error", 0.6)
		local sc = new("UIScale", { Parent = btn })
		btn.MouseEnter:Connect(function() tween(btn, { BackgroundTransparency = 0.45 }, 0.12) end)
		btn.MouseLeave:Connect(function() tween(btn, { BackgroundTransparency = 0.7 }, 0.15) tween(sc, { Scale = 1 }, 0.1) end)
		btn.MouseButton1Down:Connect(function() tween(sc, { Scale = 0.95 }, 0.08) end)
		btn.MouseButton1Up:Connect(function() tween(sc, { Scale = 1 }, 0.14, Enum.EasingStyle.Back) end)
		btn.MouseButton1Click:Connect(function()
			writeSavedKey(Library._keyFolder or Library.Folder, "")
			Library.KeyInfo = nil -- หยุดตัวเฝ้าคีย์
			Library:Notify("Sign Out", T("signout_notify"), 2)
			task.delay(0.9, function()
				local wins = { table.unpack(Library.Windows) }
				for _, w in ipairs(wins) do w:FadeDestroy() end
			end)
		end)
	end
	return tab
end

function Library:CreateWindow(config)
	if type(config) == "string" then config = { Title = config } end
	config = config or {}
	if config.KeySystem and (config.KeySystem == true or config.KeySystem.Enabled ~= false) then
		local ok = self:KeySystem(config.KeySystem)
		if not ok then
			self:Unload()
			error("[VortexUI] ไม่ผ่านระบบคีย์ / ยกเลิก", 0)
		end
	end
	self:_init()

	local titleText = config.Title or config[1] or "Vortex UI"
	local subtitleText = config.Subtitle or ("Universal | v" .. self.Version)
	local iconId = config.Icon or ""
	local closeAction = config.CloseAction or "Confirm"
	self.Folder = config.Folder or self.Folder
	self.ConfigName = config.ConfigName or (tostring(titleText):gsub("[^%w%-_ ]", "_"))
	if config.AutoSave ~= nil then self.AutoSave = config.AutoSave end
	if config.FireOnInit ~= nil then self.FireOnInit = config.FireOnInit end
	self:_readConfig()
	self:_loadLang()

	-- ธีม/สี/ปุ่มเปิดเมนู: ค่าที่บันทึกไว้ชนะค่าในสคริปต์ (กันหน้าจอกะพริบ)
	if type(self._config["ui.accent"]) == "string" then self._accent = fromHex(self._config["ui.accent"]) end
	self:_loadPreset(resolveTheme(self._config["ui.theme"]) or resolveTheme(config.Theme) or "blue")
	local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
	if type(self._config["ui.togglekey"]) == "string" then
		local ok, k = pcall(function() return Enum.KeyCode[self._config["ui.togglekey"]] end)
		if ok and k then toggleKey = k end
	end

	local ScreenGui = new("ScreenGui", { Name = "VortexUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	parentGui(ScreenGui)
	table.insert(self._guis, ScreenGui)

	local Window = setmetatable({ ScreenGui = ScreenGui, Tabs = {}, Flags = {}, ToggleKey = toggleKey, _compact = false, _cfg = config }, WindowMT)
	table.insert(self.Windows, Window)

	-- Notification holder
	NotifHolder = new("Frame", { Name = "Notifications", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 260, 1, -32), BackgroundTransparency = 1, Parent = ScreenGui })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = NotifHolder })

	-- Tooltip
	TooltipFrame = new("Frame", { Name = "Tooltip", BackgroundTransparency = 0.15, Visible = false, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 100, Parent = ScreenGui }, { BackgroundColor3 = "Card" })
	corner(TooltipFrame, 5)
	stroke(TooltipFrame, "Stroke", 0.4)
	pad(TooltipFrame, 8, 6, 8, 6)
	TooltipLabel = label(TooltipFrame, { Text = "", TextSize = 11, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 100 }, "Text")

	-- ขนาดหน้าต่าง: ปรับอัตโนมัติตามจอ (มือถือ/PC)
	local vp = viewport()
	local want = config.Size or UDim2.fromOffset(680, 460)
	local W = math.clamp(want.X.Offset, 300, math.max(300, vp.X * 0.94))
	local H = math.clamp(want.Y.Offset, 300, math.max(300, vp.Y * 0.92))

	local Main = new("CanvasGroup", {
		Name = "MainFrame", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.12, BorderSizePixel = 0, ClipsDescendants = true, GroupTransparency = 1, Parent = ScreenGui,
	}, { BackgroundColor3 = "Background" })
	corner(Main, 10)
	new("UISizeConstraint", { MinSize = Vector2.new(300, 300), Parent = Main })
	local MainScale = new("UIScale", { Scale = 0.94, Parent = Main })
	Window._scale, Window._shown = MainScale, true
	local MainStroke = new("UIStroke", { Thickness = 1.2, Transparency = 0.25, Parent = Main })
	local StrokeGrad = new("UIGradient", { Rotation = 35, Parent = MainStroke })
	onTheme(Main, function()
		StrokeGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Accent), ColorSequenceKeypoint.new(0.5, Theme.Stroke), ColorSequenceKeypoint.new(1, Theme.Accent2),
		})
	end)
	Window.Main = Main

	-- TOP BAR
	local TopBar = new("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, ZIndex = 10, Parent = Main })
	local Brand = new("Frame", { Size = UDim2.new(1, -130, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, ZIndex = 11, Parent = TopBar })
	local BrandIcon = new("ImageLabel", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 0, 0.5, -15), BackgroundTransparency = 1, Image = iconId, ScaleType = Enum.ScaleType.Fit, ZIndex = 12, Parent = Brand })
	corner(BrandIcon, 6)
	Window.BrandIcon = BrandIcon
	Window.TitleLabel = label(Brand, { Text = titleText, Font = Enum.Font.GothamBold, TextSize = 13, Position = UDim2.fromOffset(38, 7), Size = UDim2.new(1, -38, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12 }, "Text")
	Window.SubtitleLabel = label(Brand, { Text = subtitleText, TextSize = 10, Position = UDim2.fromOffset(38, 25), Size = UDim2.new(1, -38, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12 }, "SubText")

	local Controls = new("Frame", { Size = UDim2.fromOffset(96, 48), Position = UDim2.new(1, -104, 0, 0), BackgroundTransparency = 1, ZIndex = 11, Parent = TopBar })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = Controls })
	local function ctl(text, size, order, hoverKey)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0.3, Text = text, Font = Enum.Font.GothamBold, TextSize = size,
			AutoButtonColor = false, ZIndex = 12, LayoutOrder = order, Parent = Controls,
		}, { BackgroundColor3 = "Card", TextColor3 = "SubText" })
		corner(b, 6)
		b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Theme[hoverKey], BackgroundTransparency = 0.1 }, 0.12) end)
		b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.3 }, 0.12) end)
		return b
	end
	local MinBtn = ctl("-", 14, 1, "CardHover")
	local MaxBtn = ctl("□", 12, 2, "CardHover")
	local CloseBtn = ctl("×", 16, 3, "Error")

	-- แถบลาก (pill) กลางด้านบน: ลากตรงนี้เพื่อย้ายหน้าต่าง
	local DragHit = new("TextButton", {
		Name = "DragHandle", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(120, 22), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(-500, -500), ZIndex = 30, Visible = false, Parent = ScreenGui,
	})
	local DragPill = new("Frame", {
		Size = UDim2.fromOffset(48, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2),
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 31, Parent = DragHit,
	}, { BackgroundColor3 = "SubText" })
	corner(DragPill, 3)
	DragHit.MouseEnter:Connect(function()
		tween(DragPill, { Size = UDim2.fromOffset(76, 6), BackgroundTransparency = 0.05, BackgroundColor3 = Theme.Text }, 0.18, Enum.EasingStyle.Back)
	end)
	DragHit.MouseLeave:Connect(function()
		tween(DragPill, { Size = UDim2.fromOffset(48, 3), BackgroundTransparency = 0.25, BackgroundColor3 = Theme.SubText }, 0.18)
	end)

	local TopLine = new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 48), BorderSizePixel = 0, BackgroundTransparency = 0.35, Parent = Main })
	local LineGrad = new("UIGradient", { Parent = TopLine })
	onTheme(TopLine, function() LineGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2) end)

	-- SIDEBAR
	local Sidebar = new("Frame", { Name = "Sidebar", Size = UDim2.new(0, 190, 1, -49), Position = UDim2.fromOffset(0, 49), BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true, Parent = Main }, { BackgroundColor3 = "Sidebar" })
	corner(Sidebar, 10)
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, BackgroundTransparency = 0.3, Parent = Sidebar }, { BackgroundColor3 = "Stroke" })

	local Search = new("TextBox", {
		Text = "", PlaceholderText = T("search_tabs"), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 46), Parent = Sidebar,
	}, { BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "SubText" })
	corner(Search, 8)
	pad(Search, 10, 0, 10, 0)
	Window.SearchBox = Search

	-- หัวแถบเมนู (ชื่อ + ปุ่มพับ/ขยาย แบบในรูป)
	local HeaderLbl = label(Sidebar, { Text = "Home", Font = Enum.Font.GothamBold, TextSize = 17, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -56, 0, 28) }, "Text")
	local CollapseBtn = new("TextButton", {
		Text = "‹", Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 8), Parent = Sidebar,
	}, { TextColor3 = "SubText" })
	corner(CollapseBtn, 8)
	CollapseBtn.MouseEnter:Connect(function() tween(CollapseBtn, { BackgroundTransparency = 0.7 }, 0.1) end)
	CollapseBtn.MouseLeave:Connect(function() tween(CollapseBtn, { BackgroundTransparency = 1 }, 0.12) end)
	Search:GetPropertyChangedSignal("Text"):Connect(function() Window:_filter() end)

	local TabList = new("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -114), Position = UDim2.fromOffset(10, 46), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Sidebar,
	})
	list(TabList, 4)
	Window.TabList = TabList

	-- PROFILE
	local Profile = new("Frame", { Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0, 10, 1, -62), BackgroundTransparency = 0.35, Parent = Sidebar }, { BackgroundColor3 = "Card" })
	corner(Profile, 8)
	stroke(Profile, "Stroke", 0.4)
	local AvatarBg = new("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0, 8, 0.5, -18), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, Parent = Profile })
	corner(AvatarBg, 18)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.7, Parent = AvatarBg })
	local Avatar = new("ImageLabel", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0.5, -16, 0.5, -16), BackgroundTransparency = 1, Parent = AvatarBg })
	corner(Avatar, 16)
	local Dot = new("Frame", { Size = UDim2.fromOffset(9, 9), Position = UDim2.new(1, -9, 1, -9), BorderSizePixel = 0, Parent = AvatarBg }, { BackgroundColor3 = "Success" })
	corner(Dot, 5)
	new("UIStroke", { Thickness = 1.5, Transparency = 0.2, Parent = Dot }, { Color = "Card" })
	task.spawn(function()
		pcall(function()
			Avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
	end)
	local UserLbl = label(Profile, { Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 11, Position = UDim2.fromOffset(50, 9), Size = UDim2.new(1, -54, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd }, "Text")
	local UptimeLbl = label(Profile, { Text = T("side_uptime") .. "00:00:00", TextSize = 9, Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -54, 0, 14) }, "SubText")
	task.spawn(function()
		local t0 = tick()
		while task.wait(1) do
			if not UptimeLbl.Parent then break end
			local e = math.floor(tick() - t0)
			local rem = Library:GetDisplayRemaining()
			if rem and (e // 4) % 2 == 1 then
				UptimeLbl.Text = T("side_key") .. Library:FormatTime(rem)
			else
				UptimeLbl.Text = T("side_uptime") .. string.format("%02d:%02d:%02d", e // 3600, (e % 3600) // 60, e % 60)
			end
		end
	end)

	-- กดโปรไฟล์ = เปิดหน้า Account
	local ProfileBtn = new("TextButton", { Name = "ProfileButton", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = Profile })
	ProfileBtn.MouseEnter:Connect(function() tween(Profile, { BackgroundTransparency = 0.15 }, 0.12) end)
	ProfileBtn.MouseLeave:Connect(function() tween(Profile, { BackgroundTransparency = 0.35 }, 0.15) end)
	ProfileBtn.MouseButton1Click:Connect(function()
		if Window.AccountTab then Window:SelectTab(Window.AccountTab) end
	end)

	-- CONTENT
	local Content = new("Frame", { Name = "Content", Size = UDim2.new(1, -206, 1, -59), Position = UDim2.fromOffset(198, 54), BackgroundTransparency = 1, Parent = Main })
	Window.Header = label(Content, { Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, 0, 0, 28) }, "Text")
	Window.Pages = new("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Content })

	local function applyLayout()
		local w = Main.AbsoluteSize.X
		local compact = w < 520 or Window._collapsed == true
		local sw = compact and 58 or math.clamp(math.floor(w * 0.28), 130, 190)
		HeaderLbl.Visible = not compact
		CollapseBtn.Text = compact and "›" or "‹"
		CollapseBtn.Position = compact and UDim2.new(0.5, -14, 0, 8) or UDim2.new(1, -38, 0, 8)
		Sidebar.Size = UDim2.new(0, sw, 1, -49)
		Content.Position = UDim2.fromOffset(sw + 8, 54)
		Content.Size = UDim2.new(1, -(sw + 16), 1, -59)
		Search.Visible = not compact
		local top = compact and 44 or 82
		TabList.Position = UDim2.fromOffset(compact and 6 or 10, top)
		TabList.Size = UDim2.new(1, compact and -12 or -20, 1, -(top + 68))
		Profile.Position = UDim2.new(0, compact and 6 or 10, 1, -62)
		Profile.Size = UDim2.new(1, compact and -12 or -20, 0, 52)
		AvatarBg.Position = compact and UDim2.new(0.5, -18, 0.5, -18) or UDim2.new(0, 8, 0.5, -18)
		UserLbl.Visible, UptimeLbl.Visible = not compact, not compact
		Window._compact = compact
		for _, t in ipairs(Window.Tabs) do t:_setCompact(compact) end
	end
	Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	CollapseBtn.MouseButton1Click:Connect(function()
		Window._collapsed = not Window._collapsed
		applyLayout()
	end)

	-- Exit modal
	local Modal = new("Frame", { Name = "Modal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = 0.45, Visible = false, ZIndex = 100, Parent = Main })
	Window.Modal = Modal
	local MCard = new("Frame", { Size = UDim2.fromOffset(260, 130), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.05, ZIndex = 101, Parent = Modal }, { BackgroundColor3 = "Background" })
	corner(MCard, 8)
	stroke(MCard, "Accent", 0.5)
	local MTitle = label(MCard, { Text = T("modal_title"), Font = Enum.Font.GothamBold, TextSize = 13, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 20), ZIndex = 102 }, "Text")
	local MMsg = label(MCard, { Text = T("modal_msg"), TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 30), ZIndex = 102 }, "SubText")
	local YesBtn = new("TextButton", { Text = T("modal_close"), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.5, -14, 0, 30), Position = UDim2.new(0, 10, 1, -40), AutoButtonColor = false, ZIndex = 103, Parent = MCard }, { BackgroundColor3 = "Error" })
	corner(YesBtn, 6)
	local NoBtn = new("TextButton", { Text = T("modal_cancel"), Font = Enum.Font.GothamMedium, TextSize = 11, Size = UDim2.new(0.5, -14, 0, 30), Position = UDim2.new(0.5, 4, 1, -40), BackgroundTransparency = 0.3, AutoButtonColor = false, ZIndex = 103, Parent = MCard }, { BackgroundColor3 = "Card", TextColor3 = "Text" })
	corner(NoBtn, 6)
	NoBtn.MouseButton1Click:Connect(function() Modal.Visible = false end)
	YesBtn.MouseButton1Click:Connect(function() Window:FadeDestroy() end)
	Window._applyStatic = function()
		Search.PlaceholderText = T("search_tabs")
		MTitle.Text, MMsg.Text = T("modal_title"), T("modal_msg")
		YesBtn.Text, NoBtn.Text = T("modal_close"), T("modal_cancel")
	end

	-- ย่อ / ขยาย / ปรับขนาด
	local isMin, isMax = false, false
	local normalSize, lastMinPos, preMax
	local normalPos = Main.Position
	local activeTween
	local Grip = new("TextButton", {
		Text = "", Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0, 0), ClipsDescendants = true,
		Position = UDim2.fromOffset(-500, -500), BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 50, Visible = false, Parent = ScreenGui,
	})
	-- วงกลมใหญ่ตัดเหลือแค่เสี้ยวขวาล่าง = เส้นโค้งรับกับมุมหน้าต่าง (รัศมีมุม 10 + ห่าง 3)
	local GripRing = new("Frame", {
		Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(-13, -13), BackgroundTransparency = 1, ZIndex = 51, Parent = Grip,
	})
	corner(GripRing, 13)
	local GripStroke = new("UIStroke", { Thickness = 2.5, Transparency = 0.25, Parent = GripRing }, { Color = "SubText" })
	Grip.MouseEnter:Connect(function() tween(GripStroke, { Thickness = 4, Transparency = 0, Color = Theme.Text }, 0.15) end)
	Grip.MouseLeave:Connect(function() tween(GripStroke, { Thickness = 2.5, Transparency = 0.25, Color = Theme.SubText }, 0.18) end)
	local sizeConstraint = Main:FindFirstChildOfClass("UISizeConstraint")

	-- ที่จับลาก/ปรับขนาดอยู่นอกหน้าต่าง (ใต้หน้าต่าง + มุมขวาล่างด้านนอก) ตามหน้าต่างทุกเฟรม
	conn(RunService.RenderStepped, function()
		if not Main.Parent then return end
		local shown = Main.Visible and Window._shown and Main.GroupTransparency < 0.9
		DragHit.Visible = shown
		Grip.Visible = shown and not isMin and not isMax
		if not shown then return end
		local p, sz, vpz = Main.AbsolutePosition, Main.AbsoluteSize, ScreenGui.AbsoluteSize
		local bottom = p.Y + sz.Y
		DragHit.Position = UDim2.fromOffset(math.floor(p.X + sz.X / 2), math.floor(math.min(bottom + 1, vpz.Y - 22)))
		Grip.Position = UDim2.fromOffset(math.floor(math.min(p.X + sz.X - 10, vpz.X - 18)), math.floor(math.min(bottom - 10, vpz.Y - 18)))
	end)

	Main:GetPropertyChangedSignal("Position"):Connect(function() if isMin then lastMinPos = Main.Position end end)

	local function setMin(state)
		if isMin == state then return end
		isMin = state
		if activeTween then activeTween:Cancel() end
		Sidebar.Visible, Content.Visible, TopLine.Visible, Grip.Visible = not state, not state, not state, not state
		MinBtn.Text = state and "+" or "-"
		if state then
			normalSize = Main.Size
			sizeConstraint.MinSize = Vector2.new(0, 0)
			activeTween = tween(Main, { Size = UDim2.fromOffset(310, 48), Position = lastMinPos or Main.Position })
		else
			sizeConstraint.MinSize = Vector2.new(300, 300)
			local a = tween(Main, { Size = normalSize or UDim2.fromOffset(W, H), Position = normalPos })
			activeTween = a
			a.Completed:Connect(function()
				if not isMin then Sidebar.Visible, Content.Visible, TopLine.Visible, Grip.Visible = true, true, true, true end
			end)
		end
	end
	local function setMax(state)
		if isMin then setMin(false) return end
		isMax = state
		Window._maximized = state
		MaxBtn.Text = state and "❐" or "□"
		if state then
			preMax = { Size = Main.Size, Pos = Main.Position }
			local v = viewport()
			tween(Main, { Size = UDim2.fromOffset(v.X - 24, v.Y - 24), Position = UDim2.fromScale(0.5, 0.5) })
		elseif preMax then
			tween(Main, { Size = preMax.Size, Position = preMax.Pos })
		end
	end
	Window._setMin, Window._setMax = setMin, setMax
	Window._resetLayout = function()
		if isMin then setMin(false) end
		isMax = false; Window._maximized = false; MaxBtn.Text = "□"
		tween(Main, { Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5) })
	end

	MinBtn.MouseButton1Click:Connect(function() setMin(not isMin) end)
	MaxBtn.MouseButton1Click:Connect(function() setMax(not isMax) end)
	CloseBtn.MouseButton1Click:Connect(function()
		if closeAction == "Destroy" then Window:FadeDestroy()
		elseif closeAction == "Hide" then
			Window:SetVisible(false)
			if not Window._hinted then
				Window._hinted = true
				Library:Notify(titleText, "ซ่อนแล้ว กด " .. Window.ToggleKey.Name .. " เพื่อเปิดอีกครั้ง", 4)
			end
		else
			if isMin then setMin(false) end
			Modal.Visible = true
		end
	end)

	-- ตำแหน่งกึ่งกลางหน้าต่าง (พิกเซล) + บีบให้อยู่ในขอบจอเสมอ
	local function toCenter(pos)
		local vpz = ScreenGui.AbsoluteSize
		return pos.X.Scale * vpz.X + pos.X.Offset, pos.Y.Scale * vpz.Y + pos.Y.Offset
	end
	local function clampCenter(cx, cy)
		local vpz, s = ScreenGui.AbsoluteSize, Main.AbsoluteSize
		local hx, hy = s.X / 2, s.Y / 2
		cx = (s.X >= vpz.X) and vpz.X / 2 or math.clamp(cx, hx, vpz.X - hx)
		cy = (s.Y >= vpz.Y) and vpz.Y / 2 or math.clamp(cy, hy, vpz.Y - hy)
		return cx, cy
	end

	DragHit.InputBegan:Connect(function(input)
		if not isPress(input) or isMax then return end
		local startMouse = input.Position
		local sx, sy = toCenter(Main.Position)
		startDrag(function(i)
			local d = i.Position - startMouse
			local cx, cy = clampCenter(sx + d.X, sy + d.Y)
			Main.Position = UDim2.fromOffset(cx, cy)
		end)
	end)

	-- ปรับขนาดจากมุมขวาล่าง: ขยายออกพร้อมกันทุกมุม (จุดกึ่งกลางอยู่ที่เดิม)
	Grip.InputBegan:Connect(function(input)
		if not isPress(input) or isMin or isMax then return end
		local startMouse, startSize = input.Position, Main.AbsoluteSize
		local cx, cy = toCenter(Main.Position)
		startDrag(function(i)
			local d, vpz = i.Position - startMouse, ScreenGui.AbsoluteSize
			local maxW = math.max(300, math.min(2 * cx, 2 * (vpz.X - cx)))
			local maxH = math.max(300, math.min(2 * cy, 2 * (vpz.Y - cy)))
			local nw = math.clamp(startSize.X + d.X * 2, 300, maxW)
			local nh = math.clamp(startSize.Y + d.Y * 2, 300, maxH)
			Main.Size = UDim2.fromOffset(nw, nh)
			Main.Position = UDim2.fromOffset(cx, cy)
		end)
	end)

	-- ตัวอักษรปรับตามขนาดหน้าต่าง: ขยาย = ใหญ่ขึ้น / หด = เล็กลง (อ่านง่ายทุกขนาด)
	local textScale = 1
	local function styleText(o)
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			local b = o:GetAttribute("BaseTS")
			if not b then b = o.TextSize; o:SetAttribute("BaseTS", b) end
			o.TextSize = math.max(8, math.floor(b * textScale + 0.5))
		end
	end
	local function applyTextScale(force)
		local sz = Main.Size
		if sz.Y.Offset < 200 then return end -- ตอนย่อหน้าต่างไม่ปรับ
		local f = math.clamp(math.min(sz.X.Offset / 680, sz.Y.Offset / 460), 0.8, 1.3)
		f = math.floor(f * 20 + 0.5) / 20
		if f == textScale and not force then return end
		textScale = f
		for _, o in ipairs(Main:GetDescendants()) do styleText(o) end
	end
	conn(Main.DescendantAdded, styleText)
	conn(Main:GetPropertyChangedSignal("Size"), function() applyTextScale(false) end)

	-- ปุ่มเปิด/ปิดเมนูบนคีย์บอร์ด + ปุ่มลอยสำหรับมือถือ
	conn(UserInputService.InputBegan, function(input, gpe)
		if gpe or Library._listening then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Window.ToggleKey then Window:Toggle() end
	end)
	if config.MobileButton ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local fab = new("ImageButton", {
			Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 12, 0.5, -22), BackgroundTransparency = 0.15,
			Image = iconId, AutoButtonColor = false, ZIndex = 60, Parent = ScreenGui,
		}, { BackgroundColor3 = "Card" })
		corner(fab, 22)
		stroke(fab, "Accent", 0.2)
		fab.MouseButton1Click:Connect(function() Window:Toggle() end)
	end

	applyLayout()
	if config.Account ~= false then
		Window.AccountTab = Window:_buildAccount(config)
	end
	if config.Settings ~= false then
		Window.SettingsTab = Window:_buildSettings()
	end
	applyTextScale(true)
	-- ถ้าไม่มีแท็บผู้ใช้เลย ให้เปิด Settings เป็นหน้าแรก
	task.defer(function()
		if not Window.ActiveTab then
			for _, t in ipairs(Window.Tabs) do
				if not t.Hidden then Window:SelectTab(t) break end
			end
		end
	end)

	-- Animation ตอนเปิด UI (เรียกหลังหน้าโหลดจบ)
	Window.Loaded = false
	local function openUI()
		Window.Loaded = true
		tween(Main, { GroupTransparency = 0 }, 0.25)
		tween(MainScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
		-- เส้นขอบ/เส้นหัวขยับเบาๆ
		conn(RunService.Heartbeat, function()
			if not Main.Visible then return end
			local t = os.clock()
			StrokeGrad.Rotation = (t * 25) % 360
			LineGrad.Offset = Vector2.new(math.sin(t * 0.8) * 0.35, 0)
		end)
	end

	-- หน้าโหลด (Loading Screen) เป็นรูป: config.Loading = false เพื่อปิด
	if config.Loading == false then
		openUI()
		return Window
	end

	local loadImage = tostring(config.LoadingImage or config.LoadImage or iconId or "")
	if tonumber(loadImage) then loadImage = "rbxassetid://" .. loadImage end
	local loadTitle = tostring(config.LoadingTitle or titleText)
	local loadMin = tonumber(config.LoadingTime) or 1.8

	-- หน้าโหลดสไตล์ Rayfield: โลโก้ + ชื่อ กลางจอ ไม่มีกรอบ เห็นเกมข้างหลัง
	local Loader = new("CanvasGroup", {
		Name = "LoadingScreen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Active = true, ZIndex = 500, GroupTransparency = 1, Parent = ScreenGui,
	}, { BackgroundColor3 = "Background" })

	local tSize = math.clamp(math.floor(viewport().X / 24), 26, 44)
	local LBox = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, math.floor(tSize * 1.5)),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = Loader,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, math.floor(tSize * 0.35)), SortOrder = Enum.SortOrder.LayoutOrder, Parent = LBox,
	})
	local LScale = new("UIScale", { Scale = 0.9, Parent = LBox })
	local LImg = new("ImageLabel", {
		Size = UDim2.fromOffset(math.floor(tSize * 1.5), math.floor(tSize * 1.5)), BackgroundTransparency = 1, Image = loadImage,
		ScaleType = Enum.ScaleType.Fit, Visible = loadImage ~= "", LayoutOrder = 1, Parent = LBox,
	})
	local LTitle = label(LBox, {
		Text = loadTitle, Font = Enum.Font.GothamMedium, TextSize = tSize, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, math.floor(tSize * 1.5)), LayoutOrder = 2,
	}, "Text")
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.75, Parent = LTitle })

	-- แถบโหลดบางๆ (ปิดไว้ เปิดด้วย LoadingBar = true)
	local showBar = config.LoadingBar == true
	local LTrack = new("Frame", {
		Size = UDim2.fromOffset(180, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, math.floor(tSize * 0.75) + 22),
		BackgroundTransparency = 0.7, BorderSizePixel = 0, Visible = showBar, Parent = Loader,
	}, { BackgroundColor3 = "Card" })
	corner(LTrack, 2)
	local LFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = LTrack }, { BackgroundColor3 = "Accent" })
	corner(LFill, 2)

	tween(Loader, { GroupTransparency = 0 }, 0.45)
	tween(LScale, { Scale = 1 }, 0.55, Enum.EasingStyle.Quint)

	local function setProgress(p)
		if showBar and Loader.Parent then tween(LFill, { Size = UDim2.new(p, 0, 1, 0) }, 0.3) end
	end

	task.spawn(function()
		local t0 = os.clock()

		-- 1) โหลดรูป/ข้อมูลจริง (มี timeout กันค้าง)
		setProgress(0.25)
		local done = false
		task.spawn(function()
			pcall(function() ContentProvider:PreloadAsync({ LImg, BrandIcon }) end)
			done = true
		end)
		while not done and os.clock() - t0 < 6 do task.wait(0.05) end

		-- 2) รอสคริปต์ผู้ใช้สร้างแท็บ/ปุ่มให้เสร็จ
		setProgress(0.6)
		task.wait()
		task.wait()

		-- 3) ครบเวลาขั้นต่ำ
		setProgress(0.9)
		local left = loadMin - (os.clock() - t0)
		if left > 0 then task.wait(left) end

		setProgress(1)
		task.wait(0.3)

		-- โลโก้จางออก แล้วค่อยเข้า UI
		if not Loader.Parent then return end
		local fade = tween(Loader, { GroupTransparency = 1 }, 0.4)
		tween(LScale, { Scale = 1.08 }, 0.4)
		fade.Completed:Wait()
		Loader:Destroy()
		if ScreenGui.Parent then openUI() end
	end)

	return Window
end

-- ถ้าเคยรันสคริปต์นี้ไว้แล้ว ให้ปิดตัวเก่าก่อน กันซ้อน
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.__VortexLibrary and env.__VortexLibrary ~= Library then
	pcall(function() env.__VortexLibrary:Unload() end)
end
env.__VortexLibrary = Library

return Library
