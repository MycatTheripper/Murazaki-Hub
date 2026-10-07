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
	Themes = {}, ThemeOrder = {}, Theme = {}, ThemeName = "blue",
	Folder = "VortexUI", ConfigName = "main",
	AutoSave = true, FireOnInit = true,
	-- >>> ใส่ค่า Supabase ตรงนี้ที่เดียว (สคริปต์ผู้ใช้ไม่ต้องใส่อีก) <<<
	Supabase = {
		Url = "https://xhiavkxmtsuyphmifkfu.supabase.co",
		Key = "sb_publishable_mPVKadPz1Uk5Tx10JF5Y_Q_v4kvmmuX",
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
		if not silent then self:Notify("ธีม", "เปลี่ยนเป็น " .. (self.Themes[key].DisplayName or key), 2) end
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
		if not silent then self:Notify("Config", "เก็บไว้ในหน่วยความจำ (Executor ไม่รองรับไฟล์)", 3) end
		return false
	end
	if hasFolders() then
		pcall(function() if not isfolder(self.Folder) then makefolder(self.Folder) end end)
	end
	local ok = pcall(function() writefile(self:_path(), HttpService:JSONEncode(cfg)) end)
	if not silent then self:Notify("Config", ok and "บันทึก Config สำเร็จ" or "บันทึกไม่สำเร็จ", 2) end
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
	if not silent then self:Notify("Config", "โหลด Config สำเร็จ", 2) end
end

function Library:ResetConfig(silent)
	for _, el in pairs(self.Elements) do
		if el.Reset then pcall(el.Reset, el) end
	end
	self:SaveConfig(true)
	if not silent then self:Notify("Config", "รีเซ็ตค่าทั้งหมดแล้ว", 2) end
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
		t.Button.Visible = q == "" or t.Name:lower():find(q, 1, true) ~= nil
	end
end

function WindowMT:CreateTab(name, icon, order, internal)
	local win = self
	name = tostring(name or "Tab")
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		LayoutOrder = order or (internal and 10000 or (#self.Tabs + 1) * 10), Parent = self.TabList,
	}, { BackgroundColor3 = "AccentSoft" })
	corner(btn, 6)
	local indicator = new("Frame", { Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 0, 0.5, -8), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = btn }, { BackgroundColor3 = "Accent" })
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
	local tab = self:CreateTab("Settings", "S", nil, true)
	local ap = tab:CreateGroupbox("APPEARANCE")
	ap:CreateThemePicker("Theme")
	local picker = ap:CreateColorPicker("Accent colour", Theme.Accent, nil, nil)
	picker._cb = function(c) Library:SetAccent(c) end
	ap:CreateButton("Reset accent colour", function()
		Library:SetAccent(nil)
		picker:Set(Theme.Accent, true)
	end)

	local wn = tab:CreateGroupbox("WINDOW")
	wn:CreateToggleMenuKeybind("Toggle key")
	wn:CreateButton("Reset window size and position", function() self:ResetLayout() end)
	wn:CreateButton("Unload UI", function() Library:Unload() end)

	local cf = tab:CreateGroupbox("CONFIG")
	cf:CreateParagraph("Auto-save", fsAvailable()
		and ("ทุก option ที่มี flag จะถูกบันทึกอัตโนมัติที่ " .. Library:_path())
		or "Executor นี้ไม่รองรับไฟล์ ค่าจะถูกจำไว้เฉพาะเซสชันนี้")
	cf:CreateToggle("Auto-save", Library.AutoSave, function(v) Library.AutoSave = v end)
	cf:CreateButton("Save config", function() Library:SaveConfig() end)
	cf:CreateButton("Load config", function() Library:LoadConfig() end)
	cf:CreateButton("Reset options to default", function() Library:ResetConfig() end)

	local tl = tab:CreateGroupbox("TOOLS")
	tl:CreateCFrameCopier()
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

local REASONS = {
	invalid = "คีย์ไม่ถูกต้อง",
	expired = "คีย์หมดอายุแล้ว",
	revoked = "คีย์ถูกยกเลิกแล้ว",
	used_by_other = "คีย์นี้ถูกใช้โดยบัญชีอื่นไปแล้ว",
}

-- 3600 -> "01:00:00" , 90000 -> "1d 01h 00m"
function Library:FormatTime(s)
	if s == nil or s == math.huge then return "ตลอดชีพ" end
	s = math.max(0, math.floor(s))
	local d, h, m, sec = s // 86400, (s % 86400) // 3600, (s % 3600) // 60, s % 60
	if d > 0 then return string.format("%dd %02dh %02dm", d, h, m) end
	return string.format("%02d:%02d:%02d", h, m, sec)
end

-- เหลือเวลากี่วินาที (nil = ยังไม่ผ่านคีย์, math.huge = ตลอดชีพ)
function Library:GetKeyRemaining()
	local k = self.KeyInfo
	if not (k and k.ok) then return nil end
	if not k.expireClock then return math.huge end
	return math.max(0, k.expireClock - os.clock())
end

function Library:_rpc(cfg, fn, body)
	local url = (tostring(cfg.SupabaseUrl or ""):gsub("/+$", ""))
	local ok, res = httpRequest({
		Url = url .. "/rest/v1/rpc/" .. fn,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["apikey"] = cfg.SupabaseKey,
			["Authorization"] = "Bearer " .. tostring(cfg.SupabaseKey),
		},
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
	if data.ok then
		local rem = tonumber(data.remaining)
		return {
			ok = true, key = key, reason = data.reason, username = data.username,
			lifetime = rem == nil, remaining = rem, expireClock = rem and (os.clock() + rem) or nil,
		}
	end
	return { ok = false, reason = data.reason, message = REASONS[data.reason] or "ตรวจสอบคีย์ไม่ผ่าน" }
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
			local dead, msg = rem ~= nil and rem <= 0, "คีย์หมดอายุแล้ว"
			if not dead and os.clock() - last >= (cfg.RecheckInterval or 120) then
				last = os.clock()
				local r = self:VerifyKey(cfg, self.KeyInfo.key)
				if r.ok then
					self.KeyInfo = r
				elseif r.reason ~= "network" then
					dead, msg = true, r.message
				end
			end
			if dead then
				self:Notify("Key", msg .. " กำลังปิดเมนู...", 4)
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
	self:_readConfig()
	if type(self._config["ui.accent"]) == "string" then self._accent = fromHex(self._config["ui.accent"]) end
	self:_loadPreset(resolveTheme(self._config["ui.theme"]) or resolveTheme(cfg.Theme) or "blue")

	local Gui = new("ScreenGui", { Name = "VortexKey", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	parentGui(Gui)
	table.insert(self._guis, Gui)

	local Backdrop = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.3, BorderSizePixel = 0, GroupTransparency = 1, Active = true, Parent = Gui,
	}, { BackgroundColor3 = "Background" })

	local cw = math.clamp(viewport().X * 0.9, 280, 380)
	local Card = new("Frame", {
		Size = UDim2.fromOffset(cw, 316), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 26),
		BackgroundTransparency = 0.06, Parent = Backdrop,
	}, { BackgroundColor3 = "Card" })
	corner(Card, 12)
	local CStroke = new("UIStroke", { Thickness = 1.4, Transparency = 0.2, Parent = Card })
	local CGrad = new("UIGradient", { Rotation = 35, Parent = CStroke })
	onTheme(Card, function()
		CGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Accent), ColorSequenceKeypoint.new(0.5, Theme.Stroke), ColorSequenceKeypoint.new(1, Theme.Accent2),
		})
	end)
	local CScale = new("UIScale", { Scale = 0.9, Parent = Card })

	-- โลโก้
	local img = tostring(cfg.Image or cfg.Icon or "")
	if tonumber(img) then img = "rbxassetid://" .. img end
	local Logo = new("Frame", { Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 0.25, Parent = Card }, { BackgroundColor3 = "Background" })
	corner(Logo, 16)
	stroke(Logo, "Accent", 0.35)
	if img ~= "" then
		new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Parent = Logo })
	else
		label(Logo, { Text = "🔑", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, "Text")
	end

	label(Card, { Text = tostring(cfg.Title or "Key System"), Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 22) }, "Text")
	label(Card, { Text = tostring(cfg.Subtitle or "ใส่คีย์เพื่อเข้าใช้งาน"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 117), Size = UDim2.new(1, 0, 0, 16) }, "SubText")

	local Input = new("TextBox", {
		Text = "", PlaceholderText = "XXXX-XXXX-XXXX", Font = Enum.Font.GothamMedium, TextSize = 13, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 146), Parent = Card,
	}, { BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "SubText" })
	corner(Input, 8)
	local IStroke = stroke(Input, "Stroke", 0.1)
	Input.Focused:Connect(function() tween(IStroke, { Color = Theme.Accent }, 0.15) end)
	Input.FocusLost:Connect(function() tween(IStroke, { Color = Theme.Stroke }, 0.2) end)

	local Status = label(Card, { Text = "", TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Position = UDim2.fromOffset(20, 190), Size = UDim2.new(1, -40, 0, 30) }, "SubText")

	local Row = new("Frame", { Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 228), BackgroundTransparency = 1, Parent = Card })
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

	if cfg.Discord then
		label(Card, { Text = tostring(cfg.Discord), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 282), Size = UDim2.new(1, 0, 0, 16) }, "SubText")
	end

	local CloseX = new("TextButton", {
		Text = "×", Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -34, 0, 8),
		BackgroundTransparency = 1, AutoButtonColor = false, Parent = Card,
	}, { TextColor3 = "SubText" })
	CloseX.MouseEnter:Connect(function() tween(CloseX, { TextColor3 = Theme.Error }, 0.12) end)
	CloseX.MouseLeave:Connect(function() tween(CloseX, { TextColor3 = Theme.SubText }, 0.12) end)

	-- ----- logic -----
	local busy, finished, result = false, false, false
	local done = Instance.new("BindableEvent")
	local hb = RunService.Heartbeat:Connect(function()
		CGrad.Rotation = (os.clock() * 40) % 360
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

	local Window = setmetatable({ ScreenGui = ScreenGui, Tabs = {}, Flags = {}, ToggleKey = toggleKey, _compact = false }, WindowMT)
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

	local TopLine = new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 48), BorderSizePixel = 0, BackgroundTransparency = 0.35, Parent = Main })
	local LineGrad = new("UIGradient", { Parent = TopLine })
	onTheme(TopLine, function() LineGrad.Color = ColorSequence.new(Theme.Accent, Theme.Accent2) end)

	-- SIDEBAR
	local Sidebar = new("Frame", { Name = "Sidebar", Size = UDim2.new(0, 190, 1, -49), Position = UDim2.fromOffset(0, 49), BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true, Parent = Main }, { BackgroundColor3 = "Sidebar" })
	corner(Sidebar, 10)
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, BackgroundTransparency = 0.3, Parent = Sidebar }, { BackgroundColor3 = "Stroke" })

	local Search = new("TextBox", {
		Text = "", PlaceholderText = "Search tabs", Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 10), Parent = Sidebar,
	}, { BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "SubText" })
	corner(Search, 8)
	pad(Search, 10, 0, 10, 0)
	Window.SearchBox = Search
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
	local UptimeLbl = label(Profile, { Text = "Uptime: 00:00:00", TextSize = 9, Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -54, 0, 14) }, "SubText")
	task.spawn(function()
		local t0 = tick()
		while task.wait(1) do
			if not UptimeLbl.Parent then break end
			local e = math.floor(tick() - t0)
			local rem = Library:GetKeyRemaining()
			if rem and (e // 4) % 2 == 1 then
				UptimeLbl.Text = rem == math.huge and "Key: ตลอดชีพ" or ("Key: " .. Library:FormatTime(rem))
			else
				UptimeLbl.Text = string.format("Uptime: %02d:%02d:%02d", e // 3600, (e % 3600) // 60, e % 60)
			end
		end
	end)

	-- CONTENT
	local Content = new("Frame", { Name = "Content", Size = UDim2.new(1, -206, 1, -59), Position = UDim2.fromOffset(198, 54), BackgroundTransparency = 1, Parent = Main })
	Window.Header = label(Content, { Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, 0, 0, 28) }, "Text")
	Window.Pages = new("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Content })

	local function applyLayout()
		local w = Main.AbsoluteSize.X
		local compact = w < 520
		local sw = compact and 58 or math.clamp(math.floor(w * 0.28), 130, 190)
		Sidebar.Size = UDim2.new(0, sw, 1, -49)
		Content.Position = UDim2.fromOffset(sw + 8, 54)
		Content.Size = UDim2.new(1, -(sw + 16), 1, -59)
		Search.Visible = not compact
		local top = compact and 10 or 46
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

	-- Exit modal
	local Modal = new("Frame", { Name = "Modal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = 0.45, Visible = false, ZIndex = 100, Parent = Main })
	Window.Modal = Modal
	local MCard = new("Frame", { Size = UDim2.fromOffset(260, 130), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.05, ZIndex = 101, Parent = Modal }, { BackgroundColor3 = "Background" })
	corner(MCard, 8)
	stroke(MCard, "Accent", 0.5)
	label(MCard, { Text = "Exit Confirmation", Font = Enum.Font.GothamBold, TextSize = 13, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 20), ZIndex = 102 }, "Text")
	label(MCard, { Text = "Are you sure you want to close the menu?", TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 30), ZIndex = 102 }, "SubText")
	local YesBtn = new("TextButton", { Text = "Close", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.5, -14, 0, 30), Position = UDim2.new(0, 10, 1, -40), AutoButtonColor = false, ZIndex = 103, Parent = MCard }, { BackgroundColor3 = "Error" })
	corner(YesBtn, 6)
	local NoBtn = new("TextButton", { Text = "Cancel", Font = Enum.Font.GothamMedium, TextSize = 11, Size = UDim2.new(0.5, -14, 0, 30), Position = UDim2.new(0.5, 4, 1, -40), BackgroundTransparency = 0.3, AutoButtonColor = false, ZIndex = 103, Parent = MCard }, { BackgroundColor3 = "Card", TextColor3 = "Text" })
	corner(NoBtn, 6)
	NoBtn.MouseButton1Click:Connect(function() Modal.Visible = false end)
	YesBtn.MouseButton1Click:Connect(function() Window:FadeDestroy() end)

	-- ย่อ / ขยาย / ปรับขนาด
	local isMin, isMax = false, false
	local normalSize, lastMinPos, preMax
	local normalPos = Main.Position
	local activeTween
	local Grip = new("TextButton", {
		Text = "◢", Font = Enum.Font.GothamBold, TextSize = 11, Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -3), BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 50, Parent = Main,
	}, { TextColor3 = "SubText" })
	local sizeConstraint = Main:FindFirstChildOfClass("UISizeConstraint")

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

	TopBar.InputBegan:Connect(function(input)
		if not isPress(input) or isMax then return end
		local startMouse, startPos = input.Position, Main.Position
		startDrag(function(i)
			local d = i.Position - startMouse
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end)
	end)
	Grip.InputBegan:Connect(function(input)
		if not isPress(input) or isMin or isMax then return end
		local startMouse, startSize, startPos = input.Position, Main.AbsoluteSize, Main.Position
		startDrag(function(i)
			local d, v = i.Position - startMouse, viewport()
			local nw = math.clamp(startSize.X + d.X, 300, v.X - 8)
			local nh = math.clamp(startSize.Y + d.Y, 300, v.Y - 8)
			Main.Size = UDim2.fromOffset(nw, nh)
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (nw - startSize.X) / 2, startPos.Y.Scale, startPos.Y.Offset + (nh - startSize.Y) / 2)
		end)
	end)

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
	if config.Settings ~= false then
		Window:_buildSettings()
	end
	-- ถ้าไม่มีแท็บผู้ใช้เลย ให้เปิด Settings เป็นหน้าแรก
	task.defer(function()
		if not Window.ActiveTab and Window.Tabs[1] then Window:SelectTab(Window.Tabs[1]) end
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

	local Loader = new("CanvasGroup", {
		Name = "LoadingScreen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.08, BorderSizePixel = 0,
		Active = true, ZIndex = 500, GroupTransparency = 1, Parent = ScreenGui,
	}, { BackgroundColor3 = "Background" })

	local LBox = new("Frame", { Size = UDim2.fromOffset(240, 230), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = Loader })
	local LScale = new("UIScale", { Scale = 0.85, Parent = LBox })

	local LImg = new("ImageLabel", {
		Size = UDim2.fromOffset(112, 112), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 0.2, Image = loadImage, ScaleType = Enum.ScaleType.Fit, Visible = loadImage ~= "", Parent = LBox,
	}, { BackgroundColor3 = "Card" })
	corner(LImg, 20)
	stroke(LImg, "Accent", 0.3)

	label(LBox, { Text = loadTitle, Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 22) }, "Text")
	local LStatus = label(LBox, { Text = "กำลังเริ่มต้น...", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 0, 16) }, "SubText")

	local LTrack = new("Frame", { Size = UDim2.new(1, -40, 0, 6), Position = UDim2.new(0, 20, 0, 184), BorderSizePixel = 0, Parent = LBox }, { BackgroundColor3 = "Card" })
	corner(LTrack, 3)
	local LFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = LTrack }, { BackgroundColor3 = "Accent" })
	corner(LFill, 3)
	local LPct = label(LBox, { Text = "0%", Font = Enum.Font.GothamMedium, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 14) }, "SubText")

	tween(LScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	tween(Loader, { GroupTransparency = 0 }, 0.3)
	-- รูปเต้นเบาๆ ระหว่างโหลด
	local pulse = TweenService:Create(LImg, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.6 })
	pulse:Play()

	local function setProgress(p, text)
		if not Loader.Parent then return end
		if text then LStatus.Text = text end
		LPct.Text = math.floor(p * 100 + 0.5) .. "%"
		tween(LFill, { Size = UDim2.new(p, 0, 1, 0) }, 0.3)
	end

	task.spawn(function()
		local t0 = os.clock()

		-- 1) โหลดรูป/ข้อมูลจริง (มี timeout กันค้าง)
		setProgress(0.25, "กำลังโหลดรูปภาพ...")
		local done = false
		task.spawn(function()
			pcall(function() ContentProvider:PreloadAsync({ LImg, BrandIcon }) end)
			done = true
		end)
		while not done and os.clock() - t0 < 6 do task.wait(0.05) end

		-- 2) รอสคริปต์ผู้ใช้สร้างแท็บ/ปุ่มให้เสร็จ
		setProgress(0.6, "กำลังโหลดข้อมูล...")
		task.wait()
		task.wait()

		-- 3) ครบเวลาขั้นต่ำ (ให้เห็นหน้าโหลดชัดๆ)
		setProgress(0.9, "กำลังสร้าง UI...")
		local left = loadMin - (os.clock() - t0)
		if left > 0 then task.wait(left) end

		setProgress(1, "พร้อมแล้ว!")
		task.wait(0.25)

		-- เฟดหน้าโหลดออก แล้วค่อยเข้า UI
		pulse:Cancel()
		if not Loader.Parent then return end
		local fade = tween(Loader, { GroupTransparency = 1 }, 0.35)
		tween(LScale, { Scale = 1.08 }, 0.35)
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
