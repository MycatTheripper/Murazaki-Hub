local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Library = {}
Library.__index = Library

local Page = {}
Page.__index = Page

local TITLE_H = 48
local SIDEBAR_W = 150
local ROW_H = 43
local WHITE = Color3.new(1, 1, 1)

-- Gen2 look: near-black glass window, white-overlay elements (high transparency),
-- hairline white strokes, soft glow, pill inputs.
local DefaultTheme = {
	Background = Color3.fromRGB(12, 12, 16),
	BackgroundTop = Color3.fromRGB(22, 22, 29),
	Surface = WHITE,
	SurfaceTransparency = 0.95,
	SurfaceHoverTransparency = 0.9,
	Border = WHITE,
	BorderTransparency = 0.92,
	BorderHoverTransparency = 0.78,
	Accent = Color3.fromRGB(116, 148, 255),
	Text = Color3.fromRGB(242, 242, 247),
	SubText = Color3.fromRGB(150, 150, 168),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
}

local FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLOW = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local SNAP = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- helpers ---------------------------------------------------------------

local function create(class, props, parent)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(parent, radius)
	local corner = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 10)
	return create("UICorner", { CornerRadius = corner }, parent)
end

local function stroke(parent, color, transparency, thickness)
	return create("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function padding(parent, amount)
	local p = UDim.new(0, amount)
	return create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p }, parent)
end

local function glow(parent, color, spread, transparency)
	return create("ImageLabel", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, spread, 1, spread),
		BackgroundTransparency = 1,
		Image = "rbxassetid://5028857084",
		ImageColor3 = color,
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(24, 24, 276, 276),
		ZIndex = 0,
	}, parent)
end

local function tween(inst, goal, info)
	local t = TweenService:Create(inst, info or FAST, goal)
	t:Play()
	return t
end

local function toAsset(value)
	if type(value) == "number" or (type(value) == "string" and tonumber(value)) then
		return "rbxassetid://" .. value
	end
	return value
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function inside(frame, pos)
	local p, s = frame.AbsolutePosition, frame.AbsoluteSize
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function resolveLucide(provided)
	if provided then
		return provided
	end
	local module = ReplicatedStorage:FindFirstChild("Lucide")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
		warn("[UILib] failed to load Lucide module: " .. tostring(result))
		return nil
	end
	warn("[UILib] Lucide module not found in ReplicatedStorage. Icons by name are disabled.")
	return nil
end

-- page components -------------------------------------------------------

function Page.new(window, name)
	local self = setmetatable({}, Page)
	self.Window = window
	self.Content = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window.Pages)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 26), -- room for the drag pill
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, self.Content)
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, self.Content)
	return self
end

function Page:Select()
	if self._tabButton then
		self.Window:_selectTab(self)
	end
end

function Page:_row(height, clickable)
	local theme = self.Window.Theme
	local row = create(clickable and "TextButton" or "Frame", {
		Size = UDim2.new(1, 0, 0, height or ROW_H),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		BorderSizePixel = 0,
	}, self.Content)
	if clickable then
		row.AutoButtonColor = false
		row.Text = ""
	end
	round(row, 10)
	local line = stroke(row, theme.Border, theme.BorderTransparency)
	return row, line
end

function Page:_hoverable(row, line)
	local theme = self.Window.Theme
	row.MouseEnter:Connect(function()
		tween(row, { BackgroundTransparency = theme.SurfaceHoverTransparency })
		tween(line, { Transparency = theme.BorderHoverTransparency })
	end)
	row.MouseLeave:Connect(function()
		tween(row, { BackgroundTransparency = theme.SurfaceTransparency })
		tween(line, { Transparency = theme.BorderTransparency })
	end)
end

-- left icon + title, returns text label
function Page:_title(row, text, icon, rightReserve)
	local window = self.Window
	local theme = window.Theme
	local x = 16
	if window:_icon(row, icon, 16, { Position = UDim2.new(0, 16, 0.5, -8), ImageColor3 = theme.Text }) then
		x = 40
	end
	return create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + (rightReserve or 16)), 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
end

function Page:AddSection(title, icon)
	local window = self.Window
	local theme = window.Theme
	local holder = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, self.Content)
	local x = 4
	if window:_icon(holder, icon, 14, { Position = UDim2.new(0, 4, 0.5, -7), ImageColor3 = theme.SubText }) then
		x = 24
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 4),
		Size = UDim2.new(1, -x, 1, -4),
		BackgroundTransparency = 1,
		Text = string.upper(title),
		TextColor3 = theme.SubText,
		Font = theme.FontBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
end

function Page:AddLabel(text, icon)
	local window = self.Window
	local theme = window.Theme
	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, self.Content)
	local x = 4
	if window:_icon(holder, icon, 16, { Position = UDim2.new(0, 4, 0, 1), ImageColor3 = theme.SubText }) then
		x = 26
	end
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	return {
		Set = function(_, newText)
			label.Text = newText
		end,
	}
end

function Page:AddButton(text, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local button, line = self:_row(ROW_H, true)
	self:_hoverable(button, line)
	self:_title(button, text, icon, 44)
	window:_icon(button, "chevron-right", 16, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		ImageColor3 = theme.SubText,
	})

	button.Activated:Connect(function()
		-- press squish, like Gen2
		tween(line, { Transparency = 1 })
		tween(button, { Size = UDim2.new(1, -8, 0, ROW_H) }, SLOW)
		task.delay(0.11, function()
			if button.Parent then
				tween(button, { Size = UDim2.new(1, 0, 0, ROW_H) }, FAST)
				tween(line, { Transparency = theme.BorderTransparency })
			end
		end)
		if callback then
			task.spawn(callback)
		end
	end)
	return button
end

function Page:AddToggle(text, default, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local state = default == true
	local row, line = self:_row(ROW_H, true)
	self:_hoverable(row, line)
	self:_title(row, text, icon, 70)

	local pill = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(42, 22),
		BackgroundColor3 = state and theme.Accent or WHITE,
		BackgroundTransparency = state and 0 or 0.88,
		BorderSizePixel = 0,
	}, row)
	round(pill, UDim.new(1, 0))
	local halo = glow(pill, theme.Accent, 16, state and 0.6 or 1)

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, pill)
	round(knob, UDim.new(1, 0))

	local function render()
		tween(pill, {
			BackgroundColor3 = state and theme.Accent or WHITE,
			BackgroundTransparency = state and 0 or 0.88,
		})
		tween(halo, { ImageTransparency = state and 0.6 or 1 })
		tween(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, SLOW)
	end

	local function set(value, fire)
		state = value
		render()
		if fire and callback then
			task.spawn(callback, state)
		end
	end

	row.Activated:Connect(function()
		set(not state, true)
	end)

	return {
		Set = function(_, value)
			set(value == true, true)
		end,
		Get = function()
			return state
		end,
	}
end

function Page:AddSlider(text, min, max, default, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local value = min
	local row, line = self:_row(58)
	self:_hoverable(row, line)

	local x = 16
	if window:_icon(row, icon, 16, { Position = UDim2.new(0, 16, 0, 11), ImageColor3 = theme.Text }) then
		x = 40
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 8),
		Size = UDim2.new(1, -(x + 76), 0, 22),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 8),
		Size = UDim2.fromOffset(60, 22),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	-- hit area is taller than the bar so it is easy to grab on touch
	local hit = create("TextButton", {
		Position = UDim2.new(0, 16, 1, -26),
		Size = UDim2.new(1, -32, 0, 22),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, row)
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, hit)
	round(bar, UDim.new(1, 0))
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
	}, bar)
	round(fill, UDim.new(1, 0))
	glow(fill, theme.Accent, 14, 0.7)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, bar)
	round(knob, UDim.new(1, 0))

	local function apply(newValue, fire)
		value = math.clamp(math.floor(newValue + 0.5), min, max)
		local alpha = (value - min) / math.max(max - min, 1)
		tween(fill, { Size = UDim2.fromScale(alpha, 1) }, SNAP)
		tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, SNAP)
		valueLabel.Text = tostring(value)
		if fire and callback then
			task.spawn(callback, value)
		end
	end
	apply(default or min, false)

	local function setFromX(posX)
		local alpha = math.clamp((posX - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		apply(min + (max - min) * alpha, true)
	end

	local sliding = false
	hit.InputBegan:Connect(function(input)
		if isPointer(input) then
			sliding = true
			tween(knob, { Size = UDim2.fromOffset(16, 16) }, SNAP)
			setFromX(input.Position.X)
		end
	end)
	table.insert(window._connections, UserInputService.InputChanged:Connect(function(input)
		if sliding and isMove(input) then
			setFromX(input.Position.X)
		end
	end))
	table.insert(window._connections, UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) and sliding then
			sliding = false
			tween(knob, { Size = UDim2.fromOffset(12, 12) }, FAST)
		end
	end))

	return {
		Set = function(_, newValue)
			apply(newValue, true)
		end,
		Get = function()
			return value
		end,
	}
end

function Page:AddTextBox(placeholder, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local row, line = self:_row(ROW_H)

	local x = 16
	if window:_icon(row, icon, 16, { Position = UDim2.new(0, 16, 0.5, -8), ImageColor3 = theme.SubText }) then
		x = 40
	end
	local box = create("TextBox", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + 16), 1, 0),
		BackgroundTransparency = 1,
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = theme.SubText,
		Text = "",
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	}, row)

	box.Focused:Connect(function()
		tween(line, { Color = theme.Accent, Transparency = 0.4 })
		tween(row, { BackgroundTransparency = theme.SurfaceHoverTransparency })
	end)
	box.FocusLost:Connect(function(enterPressed)
		tween(line, { Color = theme.Border, Transparency = theme.BorderTransparency })
		tween(row, { BackgroundTransparency = theme.SurfaceTransparency })
		if callback then
			task.spawn(callback, box.Text, enterPressed)
		end
	end)
	return box
end

-- AddDropdown(text, {"a","b"}, default, callback, icon, multi)
-- single: default is string, callback(string). multi: default is table, callback(table)
function Page:AddDropdown(text, options, default, callback, icon, multi)
	local window = self.Window
	local theme = window.Theme
	options = options or {}

	local selected = {} -- set of option names
	if multi and type(default) == "table" then
		for _, v in ipairs(default) do
			selected[v] = true
		end
	elseif type(default) == "string" then
		selected[default] = true
	end

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Content)
	round(holder, 10)
	local line = stroke(holder, theme.Border, theme.BorderTransparency)

	local header = create("TextButton", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, holder)
	self:_title(header, text, icon, 190)

	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(150, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local chevron = window:_icon(header, "chevron-down", 16, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		ImageColor3 = theme.SubText,
	})

	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, ROW_H + 2),
		Size = UDim2.new(1, -16, 1, -(ROW_H + 10)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, holder)
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local open = false
	local buttons = {}

	local function names()
		local out = {}
		for _, name in ipairs(options) do
			if selected[name] then
				table.insert(out, name)
			end
		end
		return out
	end

	local function currentValue()
		if multi then
			return names()
		end
		return names()[1]
	end

	local function renderLabel()
		local picked = names()
		if #picked == 0 then
			valueLabel.Text = "None"
		elseif multi and #picked > 1 then
			valueLabel.Text = #picked .. " selected"
		else
			valueLabel.Text = picked[1]
		end
	end

	local function renderButtons()
		for name, btn in pairs(buttons) do
			local on = selected[name] == true
			tween(btn, { BackgroundTransparency = on and 0.88 or 1 })
			local label = btn:FindFirstChildOfClass("TextLabel")
			if label then
				tween(label, { TextColor3 = on and theme.Accent or theme.Text })
			end
		end
	end

	local function openHeight()
		local visible = math.clamp(#options, 1, 5)
		return ROW_H + 6 + visible * 32 + (visible - 1) * 4 + 8
	end

	local function setOpen(value)
		open = value
		tween(holder, { Size = UDim2.new(1, 0, 0, open and openHeight() or ROW_H) }, SLOW)
		if chevron then
			tween(chevron, { Rotation = open and 180 or 0 }, SLOW)
		end
		tween(line, { Transparency = open and theme.BorderHoverTransparency or theme.BorderTransparency })
	end

	local function fire()
		renderLabel()
		renderButtons()
		if callback then
			task.spawn(callback, currentValue())
		end
	end

	local function build()
		for _, btn in pairs(buttons) do
			btn:Destroy()
		end
		buttons = {}
		for index, name in ipairs(options) do
			local btn = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, list)
			round(btn, 8)
			create("TextLabel", {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = name,
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, btn)
			btn.MouseEnter:Connect(function()
				if not selected[name] then
					tween(btn, { BackgroundTransparency = 0.94 })
				end
			end)
			btn.MouseLeave:Connect(function()
				if not selected[name] then
					tween(btn, { BackgroundTransparency = 1 })
				end
			end)
			btn.Activated:Connect(function()
				if multi then
					selected[name] = not selected[name] or nil
				else
					selected = { [name] = true }
				end
				fire()
				if not multi then
					setOpen(false)
				end
			end)
			buttons[name] = btn
		end
		renderLabel()
		renderButtons()
	end
	build()

	header.MouseEnter:Connect(function()
		if not open then
			tween(holder, { BackgroundTransparency = theme.SurfaceHoverTransparency })
			tween(line, { Transparency = theme.BorderHoverTransparency })
		end
	end)
	header.MouseLeave:Connect(function()
		tween(holder, { BackgroundTransparency = theme.SurfaceTransparency })
		if not open then
			tween(line, { Transparency = theme.BorderTransparency })
		end
	end)
	header.Activated:Connect(function()
		setOpen(not open)
	end)
	table.insert(window._connections, UserInputService.InputBegan:Connect(function(input)
		if open and isPointer(input) and not inside(holder, input.Position) then
			setOpen(false)
		end
	end))

	return {
		Get = currentValue,
		Set = function(_, value)
			selected = {}
			if type(value) == "table" then
				for _, v in ipairs(value) do
					selected[v] = true
				end
			elseif value ~= nil then
				selected[value] = true
			end
			fire()
		end,
		Refresh = function(_, newOptions)
			options = newOptions or {}
			for name in pairs(selected) do
				if not table.find(options, name) then
					selected[name] = nil
				end
			end
			build()
			if open then
				setOpen(true)
			end
		end,
	}
end

-- AddKeybind(text, Enum.KeyCode.X, callback(key), icon)
-- click pill, press a key. Esc cancels, Backspace clears.
function Page:AddKeybind(text, default, callback, icon, onChanged)
	local window = self.Window
	local theme = window.Theme
	local key = default
	local listening = false
	local row, line = self:_row(ROW_H)
	self:_hoverable(row, line)
	self:_title(row, text, icon, 100)

	local pill = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.9,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
	}, row)
	round(pill, UDim.new(1, 0))
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, pill)
	local keyLabel = create("TextLabel", {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 14,
	}, pill)

	local function render()
		keyLabel.Text = listening and "..." or (key and key.Name or "None")
		tween(keyLabel, { TextColor3 = listening and theme.Accent or theme.SubText })
	end
	render()

	pill.Activated:Connect(function()
		listening = not listening
		render()
	end)

	table.insert(window._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			listening = false
			if input.KeyCode == Enum.KeyCode.Escape then
				-- cancel
			elseif input.KeyCode == Enum.KeyCode.Backspace then
				key = nil
				if onChanged then task.spawn(onChanged, key) end
			else
				key = input.KeyCode
				if onChanged then task.spawn(onChanged, key) end
			end
			render()
		elseif not processed and key and input.KeyCode == key then
			if callback then
				task.spawn(callback, key)
			end
		end
	end))

	return {
		Get = function()
			return key
		end,
		Set = function(_, newKey)
			key = newKey
			render()
		end,
	}
end

-- window ----------------------------------------------------------------

function Library:_icon(parent, name, size, props)
	if not name then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromOffset(size, size)
	image.ImageColor3 = self.Theme.Text

	if type(name) == "number" or tonumber(name) or string.find(name, "^rbx") then
		image.Image = toAsset(name)
	else
		if not self._lucide then
			image:Destroy()
			return nil
		end
		local ok, asset = pcall(self._lucide.GetAsset, name, 48)
		if not ok or not asset then
			warn(('[UILib] unknown Lucide icon "%s"'):format(name))
			image:Destroy()
			return nil
		end
		image.Image = asset.Url
		image.ImageRectSize = asset.ImageRectSize
		image.ImageRectOffset = asset.ImageRectOffset
	end

	for key, value in pairs(props or {}) do
		image[key] = value
	end
	image.Parent = parent
	return image
end

function Library.new(title, options)
	options = options or {}
	local self = setmetatable({}, Library)
	self.Theme = table.clone(DefaultTheme)
	for key, value in pairs(options.Theme or {}) do
		self.Theme[key] = value
	end
	self._connections = {}
	self._tabs = {}
	self._lucide = resolveLucide(options.Lucide)
	local theme = self.Theme

	local size = options.Size or UDim2.fromOffset(580, 400)
	local minSize = options.MinSize or Vector2.new(400, 260)
	local maxSize = options.MaxSize or Vector2.new(900, 700)

	self.Gui = create("ScreenGui", {
		Name = "UILib",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))

	-- main frame
	self.Main = create("Frame", {
		Name = "Main",
		Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
		Size = size,
		BackgroundColor3 = WHITE, -- real colors come from the gradient
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
	}, self.Gui)
	round(self.Main, 16)
	stroke(self.Main, WHITE, 0.9)
	create("UIGradient", {
		Color = ColorSequence.new(theme.BackgroundTop, theme.Background),
		Rotation = 90,
	}, self.Main)
	self._scale = create("UIScale", { Scale = 0.9 }, self.Main)

	-- title bar
	local bar = create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TITLE_H),
		BackgroundTransparency = 1,
	}, self.Main)
	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
	}, bar)

	local titleX = 18
	if self:_icon(bar, options.Icon, 20, { Position = UDim2.new(0, 18, 0.5, -10), ImageColor3 = theme.Text }) then
		titleX = 46
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -(titleX + 84), 1, 0),
		BackgroundTransparency = 1,
		Text = title or "Window",
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, bar)

	local function barButton(iconName, fallback, index)
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12 - (index - 1) * 32, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
		}, bar)
		round(button, UDim.new(1, 0))
		local icon = self:_icon(button, iconName, 16, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = theme.SubText,
		})
		if not icon then
			button.Text = fallback
			button.TextColor3 = theme.SubText
			button.Font = theme.Font
			button.TextSize = 14
		end
		button.MouseEnter:Connect(function()
			tween(button, { BackgroundTransparency = 0.9 })
		end)
		button.MouseLeave:Connect(function()
			tween(button, { BackgroundTransparency = 1 })
		end)
		return button
	end
	local closeButton = barButton("x", "X", 1)
	local minimizeButton = barButton("minus", "-", 2)

	-- body: sidebar (only when tabs exist) + pages
	self.Body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, TITLE_H),
		Size = UDim2.new(1, 0, 1, -TITLE_H),
		BackgroundTransparency = 1,
	}, self.Main)

	self.Sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.Body)
	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
	}, self.Sidebar)
	self.TabList = create("ScrollingFrame", {
		Size = UDim2.new(1, -1, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, self.Sidebar)
	padding(self.TabList, 10)
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, self.TabList)

	self.Pages = create("Frame", {
		Name = "Pages",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, self.Body)
	self._defaultPage = Page.new(self, "Default")

	-- drag pill (bottom center, Gen2 style) -------------------------------
	self.DragZone = create("TextButton", {
		Name = "DragZone",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(160, 20),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
	}, self.Main)
	local dragPill = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(100, 4),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, self.DragZone)
	round(dragPill, UDim.new(1, 0))
	self.DragZone.MouseEnter:Connect(function()
		tween(dragPill, { Size = UDim2.fromOffset(120, 4), BackgroundTransparency = 0.5 })
	end)
	self.DragZone.MouseLeave:Connect(function()
		tween(dragPill, { Size = UDim2.fromOffset(100, 4), BackgroundTransparency = 0.7 })
	end)

	-- resize grip (bottom-right)
	self.Grip = create("TextButton", {
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
	}, self.Main)
	local gripIcon = self:_icon(self.Grip, "grip", 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = theme.SubText,
		ImageTransparency = 0.4,
		ZIndex = 6,
	})
	if not gripIcon then
		self.Grip.Text = "◢"
		self.Grip.TextColor3 = theme.SubText
		self.Grip.Font = theme.Font
		self.Grip.TextSize = 12
	end

	-- collapsed pill (shown after minimize)
	self.Collapsed = create("CanvasGroup", {
		Name = "Collapsed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(190, 46),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
	}, self.Gui)
	round(self.Collapsed, UDim.new(1, 0))
	stroke(self.Collapsed, WHITE, 0.88)
	create("TextLabel", {
		Position = UDim2.fromOffset(20, 7),
		Size = UDim2.new(1, -40, 0, 18),
		BackgroundTransparency = 1,
		Text = title or "Window",
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, self.Collapsed)
	create("TextLabel", {
		Position = UDim2.fromOffset(20, 25),
		Size = UDim2.new(1, -40, 0, 14),
		BackgroundTransparency = 1,
		Text = "Tap to show",
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.Collapsed)
	local collapsedHit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, self.Collapsed)

	-- notifications (right side, Gen2 slide-in)
	self.Notifications = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(300, 500),
		BackgroundTransparency = 1,
	}, self.Gui)
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.Notifications)

	-- drag + resize --------------------------------------------------------
	local dragging, dragStart, startPos = false, nil, nil
	local resizing, resizeStart, startSize = false, nil, nil

	local function track(handle, onBegin, onEnd)
		handle.InputBegan:Connect(function(input)
			if isPointer(input) then
				onBegin(input)
				local changed
				changed = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						onEnd()
						changed:Disconnect()
					end
				end)
			end
		end)
	end

	local function beginDrag(input)
		dragging = true
		dragStart = input.Position
		startPos = self.Main.Position
	end
	local function endDrag()
		dragging = false
	end
	track(bar, beginDrag, endDrag)
	track(self.DragZone, beginDrag, endDrag)

	track(self.Grip, function(input)
		resizing = true
		resizeStart = input.Position
		startSize = self.Main.Size
	end, function()
		resizing = false
	end)

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if not isMove(input) then
			return
		end
		if dragging then
			local delta = input.Position - dragStart
			self.Main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		elseif resizing then
			local delta = input.Position - resizeStart
			self.Main.Size = UDim2.fromOffset(
				math.clamp(startSize.X.Offset + delta.X, minSize.X, maxSize.X),
				math.clamp(startSize.Y.Offset + delta.Y, minSize.Y, maxSize.Y)
			)
		end
	end))

	-- minimize / close -----------------------------------------------------
	minimizeButton.Activated:Connect(function()
		self:SetVisible(false)
		self.Collapsed.Visible = true
		tween(self.Collapsed, { GroupTransparency = 0 }, SLOW)
	end)
	collapsedHit.Activated:Connect(function()
		self:SetVisible(true)
	end)
	closeButton.Activated:Connect(function()
		self:Destroy()
	end)

	if options.ToggleKey then
		table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == options.ToggleKey then
				self:SetVisible(not self.Main.Visible)
			end
		end))
	end

	-- startup: profile card + optional intro, then open --------------------
	if options.Profile ~= false then
		self:_buildProfile()
	end
	if options.Intro then
		self:_playIntro(options.Intro, function()
			if not self._destroyed then
				self:_open()
			end
		end)
	else
		self:_open()
	end

	return self
end

function Library:_buildProfile()
	local theme = self.Theme
	local player = Players.LocalPlayer

	local card = create("CanvasGroup", {
		Name = "Profile",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(240, 60),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
	}, self.Gui)
	round(card, 14)
	stroke(card, WHITE, 0.9)

	local avatar = create("ImageLabel", {
		Position = UDim2.new(0, 10, 0.5, -20),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Image = "",
	}, card)
	round(avatar, UDim.new(1, 0))

	create("TextLabel", {
		Position = UDim2.fromOffset(62, 11),
		Size = UDim2.new(1, -72, 0, 20),
		BackgroundTransparency = 1,
		Text = player.DisplayName,
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	create("TextLabel", {
		Position = UDim2.fromOffset(62, 30),
		Size = UDim2.new(1, -72, 0, 18),
		BackgroundTransparency = 1,
		Text = "@" .. player.Name,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and avatar.Parent then
			avatar.Image = content
		end
	end)

	self.Profile = card
end

function Library:_playIntro(intro, done)
	local theme = self.Theme

	local overlay = create("TextButton", {
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ZIndex = 100,
	}, self.Gui)

	local imageSize = intro.ImageSize or Vector2.new(160, 160)
	local image, title
	if intro.Image then
		image = create("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, intro.Title and -24 or 0),
			Size = UDim2.fromOffset(imageSize.X, imageSize.Y),
			BackgroundTransparency = 1,
			Image = toAsset(intro.Image),
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 101,
		}, overlay)
		local pop = create("UIScale", { Scale = 0.85 }, image)
		tween(pop, { Scale = 1 }, SLOW)
	end
	if intro.Title then
		title = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, image and (imageSize.Y / 2 - 6) or 0),
			Size = UDim2.fromOffset(500, 30),
			BackgroundTransparency = 1,
			Text = intro.Title,
			TextColor3 = theme.Text,
			TextTransparency = 1,
			Font = theme.FontBold,
			TextSize = 22,
			ZIndex = 101,
		}, overlay)
	end

	if intro.Sound then
		local sound = create("Sound", {
			Name = "IntroSound",
			SoundId = toAsset(intro.Sound),
			Volume = intro.Volume or 1,
		}, self.Gui)
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		sound:Play()
	end

	tween(overlay, { BackgroundTransparency = 0.05 }, SLOW)
	if image then
		tween(image, { ImageTransparency = 0 }, SLOW)
	end
	if title then
		tween(title, { TextTransparency = 0 }, SLOW)
	end

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		tween(overlay, { BackgroundTransparency = 1 }, SLOW)
		if image then
			tween(image, { ImageTransparency = 1 }, SLOW)
		end
		if title then
			tween(title, { TextTransparency = 1 }, SLOW)
		end
		task.delay(0.5, function()
			overlay:Destroy()
			done()
		end)
	end

	if intro.Skippable ~= false then
		overlay.Activated:Connect(finish)
	end
	task.delay(intro.Duration or 2.5, finish)
end

function Library:_open()
	self:SetVisible(true)
	if self.Profile then
		self.Profile.Visible = true
		tween(self.Profile, { GroupTransparency = 0 }, SLOW)
	end
end

function Library:SetVisible(visible)
	if self._destroyed then
		return
	end
	if visible then
		self._visibleToken = (self._visibleToken or 0) + 1
		self._scale.Scale = 0.9
		self.Main.Visible = true
		tween(self._scale, { Scale = 1 }, SLOW)
		tween(self.Collapsed, { GroupTransparency = 1 }, FAST)
		self.Collapsed.Visible = false
	else
		self.Main.Visible = false
	end
end

function Library:_selectTab(page)
	local theme = self.Theme
	self._activeTab = page
	for _, tab in ipairs(self._tabs) do
		local active = tab == page
		tab.Content.Visible = active
		tween(tab._tabButton, { BackgroundTransparency = active and 0.92 or 1 })
		tween(tab._tabLabel, { TextColor3 = active and theme.Text or theme.SubText })
		if tab._tabIcon then
			tween(tab._tabIcon, { ImageColor3 = active and theme.Text or theme.SubText })
		end
	end
end

function Library:AddTab(name, icon)
	local theme = self.Theme

	if #self._tabs == 0 then
		self._defaultPage.Content.Visible = false
		self.Sidebar.Visible = true
		self.Pages.Position = UDim2.fromOffset(SIDEBAR_W, 0)
		self.Pages.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
	end

	local page = Page.new(self, name)
	page.Content.Visible = false

	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		LayoutOrder = #self._tabs + 1,
	}, self.TabList)
	round(button, 10)

	local textX = 14
	local iconImage = self:_icon(button, icon, 16, {
		Position = UDim2.new(0, 12, 0.5, -8),
		ImageColor3 = theme.SubText,
	})
	if iconImage then
		textX = 38
	end
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(textX, 0),
		Size = UDim2.new(1, -(textX + 6), 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button)

	page._tabButton, page._tabLabel, page._tabIcon = button, label, iconImage

	button.MouseEnter:Connect(function()
		if self._activeTab ~= page then
			tween(button, { BackgroundTransparency = 0.96 })
		end
	end)
	button.MouseLeave:Connect(function()
		if self._activeTab ~= page then
			tween(button, { BackgroundTransparency = 1 })
		end
	end)
	button.Activated:Connect(function()
		self:_selectTab(page)
	end)

	table.insert(self._tabs, page)
	if #self._tabs == 1 then
		self:_selectTab(page)
	end
	return page
end

-- Notify("text", duration, icon, "title")  or  Notify{ title=, content=, duration=, icon= }
function Library:Notify(text, duration, icon, title)
	if self._destroyed then
		return
	end
	local theme = self.Theme
	if type(text) == "table" then
		local o = text
		text, duration, icon, title = o.content or o.Content or o.text or "", o.duration or o.Duration, o.icon or o.Icon, o.title or o.Title
	end
	text = tostring(text or "")
	title = title or "Notification"
	duration = duration or math.clamp(#text * 0.06 + 3, 3, 9)

	self._notifyCount = (self._notifyCount or 0) + 1

	local wrapper = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self._notifyCount,
	}, self.Notifications)

	local toast = create("CanvasGroup", {
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, wrapper)
	round(toast, 14)
	stroke(toast, WHITE, 0.88)
	create("UIGradient", {
		Color = ColorSequence.new(theme.BackgroundTop, theme.Background),
		Rotation = 90,
	}, toast)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}, toast)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toast)

	local textWidth = 264
	local iconImage = self:_icon(toast, icon, 22, { LayoutOrder = 1, ImageColor3 = theme.Text })
	if iconImage then
		textWidth = 230
	end
	local column = create("Frame", {
		Size = UDim2.fromOffset(textWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, toast)
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, column)
	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	}, column)
	if text ~= "" then
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = theme.SubText,
			Font = theme.Font,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
		}, column)
	end

	local hovered, dismissed = false, false
	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 10,
	}, toast)
	hit.MouseEnter:Connect(function()
		hovered = true
	end)
	hit.MouseLeave:Connect(function()
		hovered = false
	end)

	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true
		tween(toast, { GroupTransparency = 1, Position = UDim2.fromOffset(60, 0) }, SLOW)
		task.wait(0.5)
		wrapper:Destroy()
	end
	hit.Activated:Connect(function()
		task.spawn(dismiss)
	end)

	tween(toast, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, SLOW)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and not dismissed and not self._destroyed do
			local dt = task.wait()
			if not hovered then
				elapsed += dt
			end
		end
		if not self._destroyed then
			dismiss()
		end
	end)
end

function Library:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

-- window-level Add* shortcuts go to the default page (no tabs)
for _, name in ipairs({ "AddSection", "AddLabel", "AddButton", "AddToggle", "AddSlider", "AddTextBox", "AddDropdown", "AddKeybind" }) do
	Library[name] = function(self, ...)
		local page = self._defaultPage
		return page[name](page, ...)
	end
end

return Library
