local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Library = {
	Version = "1.0.0",
	Flags = {}, Elements = {}, Windows = {},
	Themes = {},
	ThemeOrder = { "Midnight", "Graphite", "Ocean", "Rose", "Emerald", "Amber", "Violet" },
	Theme = {}, ThemeName = "Midnight",
	Folder = "Library", ConfigName = nil,
	AutoSave = true, FireOnInit = true,
	_painters = {}, _config = {}, _conns = {}, _keybinds = {},
}

local Elements, Tab, Groupbox, Window = {}, {}, {}, {}
Tab.__index = setmetatable(Tab, { __index = Elements })
Groupbox.__index = setmetatable(Groupbox, { __index = Elements })
Window.__index = Window

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function theme(bg, side, card, stroke, text, sub, accent)
	return { Background = bg, Sidebar = side, Card = card, Stroke = stroke, Text = text, SubText = sub, Accent = accent }
end
Library.Themes.Midnight = theme(rgb(15, 16, 20), rgb(19, 20, 25), rgb(25, 27, 33), rgb(44, 47, 58), rgb(232, 234, 240), rgb(138, 144, 160), rgb(124, 140, 255))
Library.Themes.Graphite = theme(rgb(17, 17, 17), rgb(21, 21, 21), rgb(28, 28, 28), rgb(48, 48, 48), rgb(236, 236, 236), rgb(150, 150, 150), rgb(214, 214, 214))
Library.Themes.Ocean = theme(rgb(11, 18, 24), rgb(14, 23, 31), rgb(20, 31, 41), rgb(35, 52, 66), rgb(226, 238, 246), rgb(120, 146, 163), rgb(74, 186, 214))
Library.Themes.Rose = theme(rgb(20, 14, 17), rgb(25, 17, 21), rgb(33, 23, 28), rgb(58, 40, 49), rgb(244, 230, 235), rgb(160, 130, 142), rgb(242, 120, 150))
Library.Themes.Emerald = theme(rgb(12, 19, 16), rgb(15, 24, 20), rgb(22, 34, 28), rgb(38, 58, 48), rgb(228, 244, 236), rgb(124, 154, 138), rgb(80, 200, 140))
Library.Themes.Amber = theme(rgb(19, 16, 11), rgb(24, 20, 13), rgb(32, 27, 18), rgb(56, 48, 32), rgb(246, 238, 224), rgb(166, 150, 120), rgb(240, 180, 70))
Library.Themes.Violet = theme(rgb(16, 13, 22), rgb(20, 16, 28), rgb(28, 23, 39), rgb(49, 41, 68), rgb(238, 232, 248), rgb(146, 134, 170), rgb(170, 120, 255))

local function lum(c) return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end
local function derive(base, accent)
	local t = {}
	for k, v in pairs(base) do t[k] = v end
	if accent then t.Accent = accent end
	t.CardHover = t.Card:Lerp(t.Text, 0.06)
	t.Input = t.Background:Lerp(t.Card, 0.45)
	t.AccentSoft = t.Card:Lerp(t.Accent, 0.2)
	t.AccentText = lum(t.Accent) > 0.6 and rgb(14, 15, 19) or rgb(255, 255, 255)
	return t
end

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------
local function safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[Library] callback error: " .. tostring(err)) end
end

local function new(class, props)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function tween(inst, props, t, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function apply(inst, props, anim)
	if anim then
		tween(inst, props, 0.22)
	else
		for k, v in pairs(props) do inst[k] = v end
	end
end

local function toHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function fromHex(s)
	local r, g, b = tostring(s):match("^#?(%x%x)(%x%x)(%x%x)$")
	if not r then return nil end
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

-- Painters keep every themed instance in sync when the theme changes live.
function Library:_paint(inst, fn)
	local entry = { inst = inst, fn = fn }
	table.insert(self._painters, entry)
	fn(false)
	return entry
end
function Library:_unpaint(entry)
	for i = #self._painters, 1, -1 do
		if self._painters[i] == entry then table.remove(self._painters, i) break end
	end
end
function Library:_repaint()
	local list = self._painters
	for i = #list, 1, -1 do
		local e = list[i]
		if e.inst.Parent == nil then table.remove(list, i) else e.fn(true) end
	end
end
local function bind(inst, prop, key)
	return Library:_paint(inst, function(anim) apply(inst, { [prop] = Library.Theme[key] }, anim) end)
end

local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p }) end
local function pad(p, l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), Parent = p })
end
local function stroke(p, key, transparency)
	local s = new("UIStroke", { Thickness = 1, Transparency = transparency or 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
	bind(s, "Color", key or "Stroke")
	return s
end
local function list(p, gap, horizontal)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical, Parent = p,
	})
end
local function label(parent, props, colorKey)
	local t = new("TextLabel", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
	})
	for k, v in pairs(props or {}) do t[k] = v end
	t.Parent = parent
	if colorKey then bind(t, "TextColor3", colorKey) end
	return t
end
local function chevron(parent, pos)
	local c = new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, BackgroundTransparency = 1, Parent = parent })
	for _, s in ipairs({ { 3.5, 45 }, { 8.5, -45 } }) do
		local b = new("Frame", { Size = UDim2.fromOffset(7, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s[1], 6), Rotation = s[2], BorderSizePixel = 0, Parent = c })
		corner(b, 1)
		bind(b, "BackgroundColor3", "SubText")
	end
	return c
end

local function isPointer(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local function isMove(i) return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end
local function frac(v, lo, size) return math.clamp((v - lo) / math.max(size, 1), 0, 1) end

-- onBegin(input) may return false to cancel; onMove(input) runs on press and on every move
local function dragger(handle, onBegin, onMove, onEnd)
	handle.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		if onBegin and onBegin(input) == false then return end
		local c1, c2
		c1 = UIS.InputChanged:Connect(function(i) if isMove(i) then onMove(i) end end)
		c2 = UIS.InputEnded:Connect(function(i)
			if i == input or i.UserInputType == input.UserInputType then
				c1:Disconnect(); c2:Disconnect()
				if onEnd then onEnd() end
			end
		end)
		onMove(input)
	end)
end

----------------------------------------------------------------------
-- Config (auto-save / auto-load)
----------------------------------------------------------------------
local function fsAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
function Library:_cfgPath()
	return self.Folder .. "/" .. tostring(self.ConfigName or "default") .. ".json"
end
function Library:_readConfig()
	self._loaded = true
	self._config = {}
	if fsAvailable() then
		local ok, data = pcall(function()
			local p = self:_cfgPath()
			if isfile(p) then return HttpService:JSONDecode(readfile(p)) end
		end)
		if ok and type(data) == "table" then self._config = data end
	elseif type(self._mem) == "table" then
		self._config = self._mem
	end
end
function Library:SaveConfig()
	local out = {}
	for k, v in pairs(self._config) do out[k] = v end
	for flag, el in pairs(self.Elements) do
		if el._encode and self.Flags[flag] ~= nil then out[flag] = el._encode(self.Flags[flag]) end
	end
	self._config = out
	if fsAvailable() then
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(self.Folder) then makefolder(self.Folder) end
			writefile(self:_cfgPath(), HttpService:JSONEncode(out))
		end)
	else
		self._mem = out
	end
end
function Library:_queueSave()
	if not self.AutoSave or self._saveQueued then return end
	self._saveQueued = true
	task.delay(0.5, function()
		self._saveQueued = false
		self:SaveConfig()
	end)
end
function Library:LoadConfig()
	self:_readConfig()
	for flag, el in pairs(self.Elements) do
		local saved = self._config[flag]
		if saved ~= nil and el._decode then
			local ok, v = pcall(el._decode, saved)
			if ok and v ~= nil then el:Set(v) end
		end
	end
end
function Library:ResetConfig()
	for flag, el in pairs(self.Elements) do
		if el.Default ~= nil and flag:sub(1, 3) ~= "ui." then el:Set(el.Default) end
	end
end

----------------------------------------------------------------------
-- Theme API
----------------------------------------------------------------------
function Library:SetTheme(t, keepAccent)
	local base
	if type(t) == "string" then
		base = self.Themes[t]
		if not base then return false end
		self.ThemeName = t
	elseif type(t) == "table" then
		base = t
		self.ThemeName = t.Name or "Custom"
	else
		return false
	end
	self._base = base
	if not keepAccent then self._accent = nil end
	self.Theme = derive(base, self._accent)
	self:_repaint()
	if type(t) == "string" and self.Elements["ui.theme"] then self.Elements["ui.theme"]:Set(t, true) end
	if self.Elements["ui.accent"] then self.Elements["ui.accent"]:Set(self.Theme.Accent, true) end
	return true
end
function Library:SetAccent(c)
	local b = self._base or self.Themes.Midnight
	if c and math.abs(c.R - b.Accent.R) + math.abs(c.G - b.Accent.G) + math.abs(c.B - b.Accent.B) < 0.01 then c = nil end
	self._accent = c
	self.Theme = derive(b, c)
	self:_repaint()
	if c == nil and self.Elements["ui.accent"] then self.Elements["ui.accent"]:Set(self.Theme.Accent, true) end
end

----------------------------------------------------------------------
-- Root gui, global input, notifications
----------------------------------------------------------------------
function Library:_gui()
	if self.Gui and self.Gui.Parent then return self.Gui end
	local gui = new("ScreenGui", { Name = "Library", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
	local parent
	if type(gethui) == "function" then pcall(function() parent = gethui() end) end
	if not parent then
		local ok, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok then parent = cg end
	end
	local ok = parent and pcall(function() gui.Parent = parent end)
	if not ok or not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
	self.Gui = gui
	self._notifHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 300, 1, -32),
		BackgroundTransparency = 1, ZIndex = 50, Parent = gui,
	})
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = self._notifHolder })
	return gui
end

function Library:_init()
	if self._inited then return end
	self._inited = true
	table.insert(self._conns, UIS.InputBegan:Connect(function(input)
		local l = self._listening
		if l and input.UserInputType == Enum.UserInputType.Keyboard then
			l:_capture(input.KeyCode)
			return
		end
		if UIS:GetFocusedTextBox() then return end
		for _, w in ipairs(self.Windows) do
			if w.ToggleKey and input.KeyCode == w.ToggleKey then w:Toggle() end
		end
		for _, el in ipairs(self._keybinds) do
			if el.Value ~= Enum.KeyCode.Unknown and input.KeyCode == el.Value then safe(el.Callback, el.Value) end
		end
	end))
end

function Library:Notify(title, text, duration)
	local holder = (self:_gui() and self._notifHolder)
	duration = tonumber(duration) or 4
	self._notifId = (self._notifId or 0) + 1
	local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self._notifId, Parent = holder })
	local c = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, 60, 0, 0), BorderSizePixel = 0, Parent = wrap })
	corner(c, 10)
	local entries = { bind(c, "BackgroundColor3", "Card"), stroke(c, "Stroke", 0.2) }
	local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = c })
	pad(body, 16, 11, 12, 13)
	list(body, 3)
	label(body, { Text = tostring(title or ""), Font = Enum.Font.GothamMedium, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 }, "Text")
	label(body, { Text = tostring(text or ""), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2 }, "SubText")
	local accent = new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(6, 8), BorderSizePixel = 0, Parent = c })
	corner(accent, 2)
	bind(accent, "BackgroundColor3", "Accent")
	local prog = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -3), Size = UDim2.new(1, -24, 0, 2), BorderSizePixel = 0, Parent = c })
	corner(prog, 1)
	bind(prog, "BackgroundColor3", "Accent")
	local click = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = c })

	local closed = false
	local function dismiss()
		if closed then return end
		closed = true
		tween(c, { Position = UDim2.new(1, 60, 0, 0) }, 0.22)
		task.delay(0.25, function()
			wrap:Destroy()
			for _, e in ipairs(entries) do Library:_unpaint(e) end
		end)
	end
	click.MouseButton1Click:Connect(dismiss)
	tween(c, { Position = UDim2.new(0, 0, 0, 0) }, 0.28, Enum.EasingStyle.Back)
	tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
	task.delay(duration, dismiss)
end

function Library:Unload()
	self:SaveConfig()
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	self._conns, self._keybinds, self._painters, self.Windows = {}, {}, {}, {}
	self.Flags, self.Elements = {}, {}
	if self.Gui then self.Gui:Destroy() end
	self.Gui, self._inited, self._loaded = nil, false, false
end

----------------------------------------------------------------------
-- Elements (shared by Tab and Groupbox)
----------------------------------------------------------------------
local function nextOrder(self)
	self._order = self._order + 1
	return self._order
end

local function card(self, height, hoverable)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, height or 40), BorderSizePixel = 0, LayoutOrder = nextOrder(self), Parent = self._container })
	corner(row, 8)
	local hov = false
	local entry = Library:_paint(row, function(anim)
		apply(row, { BackgroundColor3 = hov and Library.Theme.CardHover or Library.Theme.Card }, anim)
	end)
	stroke(row, "Stroke", 0.4)
	if hoverable ~= false then
		row.MouseEnter:Connect(function() hov = true; entry.fn(true) end)
		row.MouseLeave:Connect(function() hov = false; entry.fn(true) end)
	end
	return row
end

local function commit(el, v, silent)
	el.Value = v
	if el.Flag then Library.Flags[el.Flag] = v end
	if silent then return end
	if el.Type ~= "Keybind" then safe(el.Callback, v) end
	if el._changed then
		for _, f in ipairs(el._changed) do safe(f, v) end
	end
	Library:_queueSave()
end

-- picks the saved value (if any), registers the flag and returns the initial value
local function setup(el, flag, default, encode, decode, callback)
	el.Flag, el.Default, el.Callback, el._encode, el._decode = flag, default, callback, encode, decode
	local init = default
	if flag then
		Library.Elements[flag] = el
		local saved = Library._config[flag]
		if saved ~= nil then
			local ok, v = pcall(decode, saved)
			if ok and v ~= nil then init = v end
		end
	end
	return init
end

local function finish(el, init, noFire)
	el:Set(init, true)
	if Library.FireOnInit and not noFire and el.Callback then
		task.defer(function() safe(el.Callback, el.Value) end)
	end
	return el
end

function Elements:CreateLabel(text)
	local t = label(self._container, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
		Text = tostring(text or ""), TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = nextOrder(self),
	}, "SubText")
	pad(t, 4, 2, 4, 2)
	local obj = { Instance = t }
	function obj:SetText(s) t.Text = tostring(s) end
	return obj
end

function Elements:CreateParagraph(title, content)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder(self), Parent = self._container })
	corner(row, 8)
	bind(row, "BackgroundColor3", "Card")
	stroke(row, "Stroke", 0.4)
	pad(row, 14, 11, 14, 12)
	list(row, 4)
	local t = label(row, { Text = tostring(title or ""), Font = Enum.Font.GothamMedium, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 }, "Text")
	local c = label(row, { Text = tostring(content or ""), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2 })
	local custom
	local entry = Library:_paint(c, function(anim) apply(c, { TextColor3 = custom or Library.Theme.SubText }, anim) end)
	local obj = { Instance = row }
	function obj:SetTitle(s) t.Text = tostring(s) end
	function obj:SetContent(text, color)
		c.Text = tostring(text)
		custom = color
		entry.fn(true)
	end
	function obj:GetContent() return c.Text end
	return obj
end

function Elements:CreateButton(text, callback)
	local row = card(self, 38)
	local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 2, Parent = row })
	local t = label(row, { Text = tostring(text or "Button"), Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -50, 1, 0) }, "Text")
	local dot = new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), BorderSizePixel = 0, Parent = row })
	corner(dot, 4)
	bind(dot, "BackgroundColor3", "Accent")
	local obj = { Instance = row, Type = "Button" }
	function obj:Fire() safe(callback) end
	function obj:SetText(s) t.Text = tostring(s) end
	btn.MouseButton1Click:Connect(function()
		tween(dot, { Size = UDim2.fromOffset(14, 14) }, 0.08)
		task.delay(0.1, function() tween(dot, { Size = UDim2.fromOffset(8, 8) }, 0.15) end)
		obj:Fire()
	end)
	return obj
end

function Elements:CreateToggle(text, default, callback, flag, desc)
	local row = card(self, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	pad(row, 14, 10, 14, 10)
	local box = new("Frame", { Size = UDim2.new(1, -52, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = row })
	list(box, 2)
	local title = label(box, { Text = tostring(text or "Toggle"), Font = Enum.Font.GothamMedium, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 }, "Text")
	local d = label(box, { Text = tostring(desc or ""), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, Visible = desc ~= nil and desc ~= "" }, "SubText")
	local track = new("Frame", { Size = UDim2.fromOffset(38, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BorderSizePixel = 0, Parent = row })
	corner(track, 10)
	local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), BorderSizePixel = 0, Parent = track })
	corner(knob, 7)
	local state = false
	local function paint(anim)
		local T = Library.Theme
		apply(track, { BackgroundColor3 = state and T.Accent or T.Input }, anim)
		apply(knob, { BackgroundColor3 = state and T.AccentText or T.SubText }, anim)
	end
	Library:_paint(track, paint)
	local click = new("TextButton", { Position = UDim2.fromOffset(-14, -10), Size = UDim2.new(1, 28, 1, 20), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = row })

	local obj = { Instance = row, Type = "Toggle" }
	local init = setup(obj, flag, default and true or false, function(v) return v end, function(v) return v == true end, callback)
	function obj:Set(v, silent)
		v = v and true or false
		local changed = v ~= obj.Value
		state = v
		tween(knob, { Position = UDim2.new(0, v and 21 or 3, 0.5, 0) }, 0.15)
		paint(true)
		if changed then commit(obj, v, silent) end
	end
	function obj:Get() return obj.Value end
	function obj:SetDesc(s) d.Text = tostring(s or ""); d.Visible = s ~= nil and s ~= "" end
	function obj:SetText(s) title.Text = tostring(s) end
	click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
	return finish(obj, init)
end

function Elements:CreateSlider(text, min, max, default, callback, flag, increment)
	min, max = tonumber(min) or 0, tonumber(max) or 100
	local span = max - min
	if span == 0 then span = 1 end
	default = tonumber(default) or min
	local inc = tonumber(increment) or ((min % 1 == 0 and max % 1 == 0 and default % 1 == 0) and 1 or 0.01)
	local decimals = (tostring(inc):match("%.(%d+)") or ""):len()

	local row = card(self, 52)
	label(row, { Text = tostring(text or "Slider"), Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -100, 0, 16) }, "Text")
	local val = label(row, { TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(80, 16) }, "SubText")
	local track = new("Frame", { Position = UDim2.fromOffset(14, 35), Size = UDim2.new(1, -28, 0, 6), BorderSizePixel = 0, Parent = row })
	corner(track, 3)
	bind(track, "BackgroundColor3", "Input")
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track })
	corner(fill, 3)
	bind(fill, "BackgroundColor3", "Accent")
	local knob = new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BorderSizePixel = 0, ZIndex = 2, Parent = track })
	corner(knob, 6)
	bind(knob, "BackgroundColor3", "Text")
	local hit = new("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = row })

	local obj = { Instance = row, Type = "Slider" }
	local init = setup(obj, flag, default, function(v) return v end, function(v) return tonumber(v) end, callback)
	function obj:Set(v, silent)
		v = math.clamp(tonumber(v) or min, min, max)
		v = math.floor((v - min) / inc + 0.5) * inc + min
		v = tonumber(string.format("%." .. decimals .. "f", v)) or v
		v = math.clamp(v, min, max)
		local f = (v - min) / span
		tween(fill, { Size = UDim2.fromScale(f, 1) }, 0.06)
		tween(knob, { Position = UDim2.fromScale(f, 0.5) }, 0.06)
		val.Text = string.format("%." .. decimals .. "f", v)
		if v ~= obj.Value then commit(obj, v, silent) end
	end
	function obj:Get() return obj.Value end
	function obj:SetRange(lo, hi) min, max = lo, hi; span = (hi - lo == 0) and 1 or (hi - lo); obj:Set(obj.Value) end
	dragger(hit, nil, function(i)
		obj:Set(min + frac(i.Position.X, track.AbsolutePosition.X, track.AbsoluteSize.X) * span)
	end)
	return finish(obj, init)
end

function Elements:CreateDropdown(text, options, default, callback, flag)
	local opts = options or {}
	local row = card(self, 40)
	row.ClipsDescendants = true
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 2, Parent = row })
	label(row, { Text = tostring(text or "Dropdown"), Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.5, -14, 0, 40) }, "Text")
	local cur = label(row, { TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -38, 0, 40) }, "SubText")
	local chev = chevron(row, UDim2.new(1, -20, 0, 20))
	local listFrame = new("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 46), Size = UDim2.new(1, -16, 0, 0), BorderSizePixel = 0, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = row,
	})
	corner(listFrame, 8)
	bind(listFrame, "BackgroundColor3", "Input")
	bind(listFrame, "ScrollBarImageColor3", "SubText")
	pad(listFrame, 4, 4, 4, 4)
	list(listFrame, 2)

	local obj = { Instance = row, Type = "Dropdown" }
	local open, buttons, entries = false, {}, {}
	local function listHeight() return math.min(#opts * 30 + 8, 148) end
	local function resize()
		listFrame.Size = UDim2.new(1, -16, 0, listHeight())
		tween(row, { Size = UDim2.new(1, 0, 0, open and (40 + 6 + listHeight() + 8) or 40) }, 0.2)
		tween(chev, { Rotation = open and 180 or 0 }, 0.18)
	end
	local function rebuild()
		for _, e in ipairs(entries) do Library:_unpaint(e) end
		for _, b in ipairs(buttons) do b:Destroy() end
		buttons, entries = {}, {}
		for i, name in ipairs(opts) do
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 28), AutoButtonColor = false, Text = tostring(name), Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, LayoutOrder = i, Parent = listFrame })
			corner(b, 6)
			pad(b, 10, 0, 6, 0)
			local hov = false
			entries[#entries + 1] = Library:_paint(b, function(anim)
				local T, sel = Library.Theme, (obj.Value == name)
				apply(b, { BackgroundColor3 = sel and T.AccentSoft or T.CardHover, BackgroundTransparency = (sel or hov) and 0 or 1, TextColor3 = sel and T.Text or T.SubText }, anim)
			end)
			local e = entries[#entries]
			b.MouseEnter:Connect(function() hov = true; e.fn(true) end)
			b.MouseLeave:Connect(function() hov = false; e.fn(true) end)
			b.MouseButton1Click:Connect(function()
				obj:Set(name)
				open = false
				resize()
			end)
			buttons[#buttons + 1] = b
		end
		resize()
	end
	local init = setup(obj, flag, default, function(v) return v end, function(v) return tostring(v) end, callback)
	if init == nil or not table.find(opts, init) then init = opts[1] end
	function obj:Set(v, silent)
		if not table.find(opts, v) then return end
		local changed = v ~= obj.Value
		obj.Value = v
		cur.Text = tostring(v)
		for _, e in ipairs(entries) do e.fn(true) end
		if changed then commit(obj, v, silent) end
	end
	function obj:Get() return obj.Value end
	function obj:Refresh(newOptions)
		opts = newOptions or {}
		rebuild()
		if not table.find(opts, obj.Value) and opts[1] ~= nil then obj:Set(opts[1]) end
	end
	head.MouseButton1Click:Connect(function()
		open = not open
		resize()
	end)
	rebuild()
	return finish(obj, init)
end

function Elements:CreateColorPicker(text, defaultColor, callback, flag)
	local row = card(self, 40)
	row.ClipsDescendants = true
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 2, Parent = row })
	label(row, { Text = tostring(text or "Colour"), Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -90, 0, 40) }, "Text")
	local swatch = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 20), Size = UDim2.fromOffset(34, 18), BorderSizePixel = 0, Parent = row })
	corner(swatch, 6)
	stroke(swatch, "Stroke", 0.2)

	local sv = new("Frame", { Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -56, 0, 100), BorderSizePixel = 0, Parent = row })
	corner(sv, 6)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sv })
	corner(white, 6)
	new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = sv })
	corner(black, 6)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	local svCur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = sv })
	corner(svCur, 6)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svCur })

	local hue = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 50), Size = UDim2.fromOffset(16, 100), BorderSizePixel = 0, Parent = row })
	corner(hue, 6)
	local stops = {}
	for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(stops), Parent = hue })
	local hueCur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 6, 0, 5), BackgroundTransparency = 1, ZIndex = 3, Parent = hue })
	corner(hueCur, 2)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = hueCur })

	local hex = new("TextBox", { Position = UDim2.fromOffset(14, 158), Size = UDim2.fromOffset(100, 26), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Text = "", BorderSizePixel = 0, Parent = row })
	corner(hex, 6)
	pad(hex, 8, 0, 8, 0)
	bind(hex, "BackgroundColor3", "Input")
	bind(hex, "TextColor3", "Text")

	local h, s, v = 0, 0, 1
	local obj = { Instance = row, Type = "ColorPicker" }
	local function refresh()
		local c = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = c
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCur.Position = UDim2.fromScale(s, 1 - v)
		hueCur.Position = UDim2.fromScale(0.5, h)
		hex.Text = toHex(c)
		return c
	end
	local function push(silent) commit(obj, refresh(), silent) end
	local init = setup(obj, flag, defaultColor or Color3.new(1, 1, 1), toHex, function(x) return fromHex(x) end, callback)
	function obj:Set(color, silent)
		if typeof(color) ~= "Color3" then return end
		local ch, cs, cv = color:ToHSV()
		if cs > 0.001 and cv > 0.001 then h = ch end
		s, v = cs, cv
		push(silent)
	end
	function obj:Get() return obj.Value end
	dragger(sv, nil, function(i)
		s = frac(i.Position.X, sv.AbsolutePosition.X, sv.AbsoluteSize.X)
		v = 1 - frac(i.Position.Y, sv.AbsolutePosition.Y, sv.AbsoluteSize.Y)
		push(false)
	end)
	dragger(hue, nil, function(i)
		h = frac(i.Position.Y, hue.AbsolutePosition.Y, hue.AbsoluteSize.Y)
		push(false)
	end)
	hex.FocusLost:Connect(function()
		local c = fromHex(hex.Text)
		if c then obj:Set(c) else refresh() end
	end)
	local open = false
	head.MouseButton1Click:Connect(function()
		open = not open
		tween(row, { Size = UDim2.new(1, 0, 0, open and 196 or 40) }, 0.2)
	end)
	return finish(obj, init)
end

function Elements:CreateKeybind(text, defaultKey, callback, flag)
	local row = card(self, 40)
	label(row, { Text = tostring(text or "Keybind"), Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0) }, "Text")
	local btn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(78, 24), AutoButtonColor = false, Text = "", BorderSizePixel = 0, Parent = row })
	corner(btn, 6)
	bind(btn, "BackgroundColor3", "Input")
	stroke(btn, "Stroke", 0.3)
	local listening = false
	local keyLabel = label(btn, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamMedium, TextSize = 12 })
	local entry = Library:_paint(keyLabel, function(anim) apply(keyLabel, { TextColor3 = listening and Library.Theme.Accent or Library.Theme.Text }, anim) end)

	local obj = { Instance = row, Type = "Keybind", _changed = {} }
	local init = setup(obj, flag, defaultKey or Enum.KeyCode.Unknown, function(k) return k.Name end, function(n) return Enum.KeyCode[n] end, callback)
	function obj:Set(key, silent)
		if not key then return end
		obj.Value = key
		keyLabel.Text = (key == Enum.KeyCode.Unknown) and "None" or key.Name
		commit(obj, key, silent)
	end
	function obj:Get() return obj.Value end
	function obj:OnChanged(fn) table.insert(obj._changed, fn) end
	function obj:_capture(key)
		listening = false
		Library._listening = nil
		entry.fn(true)
		if key == Enum.KeyCode.Escape then
			keyLabel.Text = (obj.Value == Enum.KeyCode.Unknown) and "None" or obj.Value.Name
		elseif key == Enum.KeyCode.Backspace then
			obj:Set(Enum.KeyCode.Unknown)
		else
			obj:Set(key)
		end
	end
	btn.MouseButton1Click:Connect(function()
		if Library._listening and Library._listening ~= obj then Library._listening:_capture(Enum.KeyCode.Escape) end
		listening = true
		Library._listening = obj
		keyLabel.Text = "..."
		entry.fn(true)
	end)
	table.insert(Library._keybinds, obj)
	return finish(obj, init, true)
end

function Elements:CreateGroupbox(title)
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder(self), Parent = self._container })
	corner(box, 10)
	bind(box, "BackgroundColor3", "Sidebar")
	stroke(box, "Stroke", 0.5)
	pad(box, 10, 10, 10, 10)
	list(box, 8)
	local head = label(box, { Text = tostring(title or ""), Font = Enum.Font.GothamBold, TextSize = 12, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0 }, "SubText")
	local inner = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = box })
	list(inner, 6)
	local gb = setmetatable({ _container = inner, _window = self._window, _order = 0, Instance = box, _head = head }, Groupbox)
	return gb
end
function Groupbox:SetTitle(t) self._head.Text = tostring(t) end

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------
local function makeIcon(parent, icon, name)
	local isImage = type(icon) == "number" or (type(icon) == "string" and (icon:find("rbxasset") ~= nil or icon:match("^%d+$") ~= nil))
	local o
	if isImage then
		local id = tonumber(icon) and ("rbxassetid://" .. icon) or icon
		o = new("ImageLabel", { BackgroundTransparency = 1, Image = id, Size = UDim2.fromScale(1, 1), Parent = parent })
		return o, "ImageColor3"
	end
	local glyph = (type(icon) == "string" and icon ~= "") and icon or tostring(name):sub(1, 1):upper()
	o = new("TextLabel", { BackgroundTransparency = 1, Text = glyph, Font = Enum.Font.GothamBold, TextSize = 14, Size = UDim2.fromScale(1, 1), Parent = parent })
	return o, "TextColor3"
end

function Tab:Select() self._window:SelectTab(self) end
function Tab:_setCompact(c)
	self._name.Visible = not c
	self._iconBox.Position = c and UDim2.new(0.5, -10, 0.5, -10) or UDim2.new(0, 12, 0.5, -10)
end

function Window:CreateTab(name, icon, order, internal)
	name = tostring(name or "Tab")
	local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = order or (#self.Tabs + 1), Parent = self._tabList })
	corner(btn, 8)
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 16), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = btn })
	corner(bar, 2)
	local iconBox = new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 12, 0.5, -10), BackgroundTransparency = 1, Parent = btn })
	local iconObj, iconProp = makeIcon(iconBox, icon, name)
	local nameLabel = label(btn, { Text = name, Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -46, 1, 0) })

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, Visible = false,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = self._pages,
	})
	bind(page, "ScrollBarImageColor3", "SubText")
	pad(page, 0, 2, 8, 10)
	list(page, 8)

	local tab = setmetatable({ Name = name, _window = self, _container = page, _order = 0, _page = page, _btn = btn, _name = nameLabel, _iconBox = iconBox, Instance = page }, Tab)
	local hov = false
	tab._paint = Library:_paint(btn, function(anim)
		local T, act = Library.Theme, (self.Active == tab)
		apply(btn, { BackgroundColor3 = act and T.AccentSoft or T.CardHover, BackgroundTransparency = act and 0 or (hov and 0.4 or 1) }, anim)
		apply(bar, { BackgroundColor3 = T.Accent, BackgroundTransparency = act and 0 or 1 }, anim)
		apply(nameLabel, { TextColor3 = act and T.Text or T.SubText }, anim)
		apply(iconObj, { [iconProp] = act and T.Accent or T.SubText }, anim)
	end)
	btn.MouseEnter:Connect(function() hov = true; tab._paint.fn(true) end)
	btn.MouseLeave:Connect(function() hov = false; tab._paint.fn(true) end)
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

	table.insert(self.Tabs, tab)
	tab:_setCompact(self._compact)
	if not internal and (not self.Active or self.Active._internal) then self:SelectTab(tab) end
	if internal then tab._internal = true; if not self.Active then self:SelectTab(tab) end end
	self:_filter()
	return tab
end

function Window:SelectTab(tab)
	self.Active = tab
	for _, t in ipairs(self.Tabs) do
		t._page.Visible = (t == tab)
		t._paint.fn(true)
	end
	self._header.Text = tab.Name
end

function Window:_filter()
	local q = string.lower(self._search.Text or "")
	for _, t in ipairs(self.Tabs) do
		t._btn.Visible = q == "" or string.find(string.lower(t.Name), q, 1, true) ~= nil
	end
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Window:SetVisible(v) self.Main.Visible = v and true or false end
function Window:Toggle() self.Main.Visible = not self.Main.Visible end
function Window:SetTitle(t) self.Title = tostring(t); self._title.Text = self.Title end
function Window:Notify(...) Library:Notify(...) end

function Window:Minimize()
	if self._max then return end
	local main = self.Main
	if not self._min then
		self._min = true
		self._fullSize = main.Size
		self.Body.Visible = false
		self.Grip.Visible = false
		tween(main, { Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 44) }, 0.2)
	else
		self._min = false
		self.Body.Visible = true
		self.Grip.Visible = true
		tween(main, { Size = self._fullSize }, 0.2)
	end
end

function Window:Maximize()
	if self._min then self:Minimize() end
	local main = self.Main
	if not self._max then
		self._max = true
		self._prev = { pos = main.Position, size = main.Size }
		self.Grip.Visible = false
		tween(main, { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16) }, 0.22)
	else
		self._max = false
		self.Grip.Visible = true
		tween(main, { Position = self._prev.pos, Size = self._prev.size }, 0.22)
	end
end

function Window:ResetLayout()
	if self._max then self:Maximize() end
	if self._min then self:Minimize() end
	local w, h = self._w, self._h
	tween(self.Main, { Size = UDim2.fromOffset(w, h), Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2) }, 0.22)
end

function Window:Destroy()
	for i, w in ipairs(Library.Windows) do
		if w == self then table.remove(Library.Windows, i) break end
	end
	self.Main:Destroy()
end

function Window:_fit()
	if self._max then return end
	local gui, main = Library.Gui, self.Main
	local vp = gui.AbsoluteSize
	local size = main.AbsoluteSize
	local pos = main.AbsolutePosition - gui.AbsolutePosition
	local w, h = math.min(size.X, vp.X - 16), math.min(size.Y, vp.Y - 16)
	if not self._min and (w ~= size.X or h ~= size.Y) then main.Size = UDim2.fromOffset(w, h) end
	main.Position = UDim2.fromOffset(math.clamp(pos.X, 0, math.max(0, vp.X - w)), math.clamp(pos.Y, 0, math.max(0, vp.Y - 44)))
end

local function controlButton(top, slot, hoverColor, draw)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10 - slot * 32, 0.5, 0), Size = UDim2.fromOffset(28, 28), AutoButtonColor = false, Text = "", BorderSizePixel = 0, Parent = top })
	corner(b, 7)
	local hov = false
	local parts = draw(b)
	local entry = Library:_paint(b, function(anim)
		local T = Library.Theme
		apply(b, { BackgroundColor3 = T.CardHover, BackgroundTransparency = hov and 0 or 1 }, anim)
		for _, p in ipairs(parts) do apply(p[1], { [p[2]] = hov and (hoverColor or T.Text) or T.SubText }, anim) end
	end)
	b.MouseEnter:Connect(function() hov = true; entry.fn(true) end)
	b.MouseLeave:Connect(function() hov = false; entry.fn(true) end)
	return b
end

local function bar(parent, w, h, rot)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), Rotation = rot or 0, BorderSizePixel = 0, Parent = parent })
	corner(f, 1)
	return f
end

function Library:CreateWindow(opts)
	opts = opts or {}
	self:_init()
	local gui = self:_gui()
	self.Folder = opts.Folder or self.Folder
	self.ConfigName = opts.ConfigName or tostring(opts.Title or "Window"):gsub("[^%w%-_ ]", "_")
	if opts.AutoSave ~= nil then self.AutoSave = opts.AutoSave end
	if not self._loaded then self:_readConfig() end

	-- theme: saved choice wins over the script default so there is no flash on load
	local savedAccent = type(self._config["ui.accent"]) == "string" and fromHex(self._config["ui.accent"]) or nil
	local savedTheme = self._config["ui.theme"]
	if savedAccent then self._accent = savedAccent end
	local startTheme = (type(savedTheme) == "string" and self.Themes[savedTheme]) and savedTheme or opts.Theme or "Midnight"
	if not self:SetTheme(startTheme, savedAccent ~= nil) then self:SetTheme("Midnight", savedAccent ~= nil) end

	local win = setmetatable({ Tabs = {}, ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift, Title = opts.Title or "Library", _compact = false, _opts = opts }, Window)
	local size = opts.Size or UDim2.fromOffset(660, 440)
	local vp = gui.AbsoluteSize
	local W, H = math.min(size.X.Offset, vp.X - 16), math.min(size.Y.Offset, vp.Y - 16)
	win._w, win._h = W, H

	local main = new("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2), BorderSizePixel = 0, ClipsDescendants = true, Parent = gui })
	corner(main, 12)
	bind(main, "BackgroundColor3", "Background")
	stroke(main, "Stroke", 0.15)
	win.Main = main

	-- title bar
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = main })
	local dot = new("Frame", { Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Parent = top })
	corner(dot, 4)
	bind(dot, "BackgroundColor3", "Accent")
	win._title = label(top, { Text = win.Title, Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -150, 1, 0) }, "Text")
	local div = new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.5, Parent = top })
	bind(div, "BackgroundColor3", "Stroke")

	controlButton(top, 0, rgb(235, 87, 87), function(b)
		local a, c = bar(b, 13, 2, 45), bar(b, 13, 2, -45)
		return { { a, "BackgroundColor3" }, { c, "BackgroundColor3" } }
	end).MouseButton1Click:Connect(function()
		if opts.CloseAction == "Destroy" then
			win:Destroy()
		else
			win:SetVisible(false)
			if not win._hinted then
				win._hinted = true
				Library:Notify(win.Title, "Hidden. Press " .. tostring(win.ToggleKey.Name) .. " to open it again.", 4)
			end
		end
	end)
	controlButton(top, 1, nil, function(b)
		local sq = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = b })
		corner(sq, 2)
		local s = new("UIStroke", { Thickness = 1.5, Parent = sq })
		return { { s, "Color" } }
	end).MouseButton1Click:Connect(function() win:Maximize() end)
	controlButton(top, 2, nil, function(b)
		return { { bar(b, 11, 2), "BackgroundColor3" } }
	end).MouseButton1Click:Connect(function() win:Minimize() end)

	-- body: floating sidebar + content
	local SW = 172
	local body = new("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1, Parent = main })
	win.Body = body
	local sidebar = new("Frame", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, SW, 1, -8), BorderSizePixel = 0, Parent = body })
	corner(sidebar, 10)
	bind(sidebar, "BackgroundColor3", "Sidebar")
	stroke(sidebar, "Stroke", 0.55)
	local search = new("TextBox", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30), Text = "", PlaceholderText = "Search tabs", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, Parent = sidebar })
	corner(search, 8)
	pad(search, 10, 0, 10, 0)
	bind(search, "BackgroundColor3", "Input")
	bind(search, "TextColor3", "Text")
	bind(search, "PlaceholderColor3", "SubText")
	win._search = search
	win._tabList = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar })
	pad(win._tabList, 8, 0, 8, 8)
	list(win._tabList, 4)

	local content = new("Frame", { Position = UDim2.fromOffset(SW + 16, 0), Size = UDim2.new(1, -(SW + 24), 1, -8), BackgroundTransparency = 1, Parent = body })
	win._header = label(content, { Size = UDim2.new(1, 0, 0, 36), Font = Enum.Font.GothamBold, TextSize = 18 }, "Text")
	win._pages = new("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, ClipsDescendants = true, Parent = content })
	search:GetPropertyChangedSignal("Text"):Connect(function() win:_filter() end)

	-- resize grip
	local grip = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, ZIndex = 5, Parent = main })
	win.Grip = grip
	for _, g in ipairs({ { 12, 2 }, { 6, 2 } }) do
		local l = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(g[1] + 2, 16 - g[1] + 2 - 4), Size = UDim2.fromOffset(g[1], g[2]), Rotation = -45, BorderSizePixel = 0, Parent = grip })
		bind(l, "BackgroundColor3", "SubText")
	end

	-- drag + resize
	local startMouse, startPos, startSize
	dragger(top, function(input)
		if win._max then return false end
		startMouse = input.Position
		startPos = main.AbsolutePosition - gui.AbsolutePosition
	end, function(i)
		local d = i.Position - startMouse
		local v = gui.AbsoluteSize
		main.Position = UDim2.fromOffset(
			math.clamp(startPos.X + d.X, -main.AbsoluteSize.X + 90, v.X - 90),
			math.clamp(startPos.Y + d.Y, 0, v.Y - 44))
	end)
	dragger(grip, function(input)
		if win._max or win._min then return false end
		startMouse = input.Position
		startSize = main.AbsoluteSize
	end, function(i)
		local d = i.Position - startMouse
		local v = gui.AbsoluteSize
		local p = main.AbsolutePosition - gui.AbsolutePosition
		main.Size = UDim2.fromOffset(
			math.clamp(startSize.X + d.X, 400, math.max(400, v.X - p.X - 4)),
			math.clamp(startSize.Y + d.Y, 280, math.max(280, v.Y - p.Y - 4)))
		win._w, win._h = main.Size.X.Offset, main.Size.Y.Offset
	end)

	-- responsive: icon-only sidebar on narrow windows, keep the window on screen
	main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local compact = main.AbsoluteSize.X < 520
		if compact == win._compact then return end
		win._compact = compact
		local sw = compact and 52 or SW
		sidebar.Size = UDim2.new(0, sw, 1, -8)
		content.Position = UDim2.fromOffset(sw + 16, 0)
		content.Size = UDim2.new(1, -(sw + 24), 1, -8)
		search.Visible = not compact
		win._tabList.Position = UDim2.fromOffset(0, compact and 8 or 46)
		win._tabList.Size = UDim2.new(1, 0, 1, compact and -8 or -46)
		for _, t in ipairs(win.Tabs) do t:_setCompact(compact) end
	end)
	table.insert(self._conns, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() win:_fit() end))

	table.insert(self.Windows, win)
	win:_buildSettings(opts)
	return win
end

-- built-in Settings tab: theme, accent, toggle key, config
function Window:_buildSettings(opts)
	if opts.Settings == false then return end
	local tab = self:CreateTab("Settings", nil, 9999, true)
	local ap = tab:CreateGroupbox("APPEARANCE")
	local names = {}
	for _, n in ipairs(Library.ThemeOrder) do if Library.Themes[n] then names[#names + 1] = n end end
	for n in pairs(Library.Themes) do if not table.find(names, n) then names[#names + 1] = n end end
	ap:CreateDropdown("Theme", names, Library.ThemeName, function(v) if v ~= Library.ThemeName then Library:SetTheme(v) end end, "ui.theme")
	ap:CreateColorPicker("Accent colour", Library.Theme.Accent, function(c) Library:SetAccent(c) end, "ui.accent")
	ap:CreateButton("Reset accent colour", function() Library:SetAccent(nil) end)

	local wn = tab:CreateGroupbox("WINDOW")
	local kb = wn:CreateKeybind("Toggle key", self.ToggleKey, nil, "ui.togglekey")
	self.ToggleKey = kb:Get()
	kb:OnChanged(function(k) self.ToggleKey = k end)
	wn:CreateButton("Reset window size and position", function() self:ResetLayout() end)
	wn:CreateButton("Unload UI", function() Library:Unload() end)

	local cf = tab:CreateGroupbox("CONFIG")
	cf:CreateParagraph("Auto-save", fsAvailable()
		and ("Every option with a flag is saved automatically to " .. Library:_cfgPath())
		or "File access is not available here, so options are remembered for this session only.")
	cf:CreateButton("Reset options to default", function()
		Library:ResetConfig()
		Library:Notify("Config", "Options were reset to their defaults.", 3)
	end)
end

return Library
