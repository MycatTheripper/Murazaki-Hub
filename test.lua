-- Script Path: game:GetService("Players")["4f8khx"].PlayerGui.EliminationModeSongUI.CurrentRoundFrame.EliminationSongUIController
-- Took 0s to decompile.
-- Executor: Real (2.7.3)

--[[
__________                   __               __    __________              .__
\______   \_______  ____    |__| ____   _____/  |_  \______   \ ____ _____  |  |
 |     ___/\_  __ \/  _ \   |  |/ __ \_/ ___\   __\  |       _// __ \\__  \ |  |
 |    |     |  | \(  <_> )  |  \  ___/\  \___|  |    |    |   \  ___/ / __ \|  |__
 |____|     |__|   \____/\__|  |\___  >\___  >__|    |____|_  /\___  >____  /____/
                        \______|    \/     \/               \/     \/     \/
]]
--                           Project Real  |  Luau Decompiler
--                                   Made by @zinvera
--File: Players.4f8khx.PlayerGui.EliminationModeSongUI.CurrentRoundFrame.EliminationSongUIController
--                               Dumped in 0.00821 seconds
--                         Bytecode version 12  |  17 functions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local SongGuessEvents = ReplicatedStorage:WaitForChild("SongGuessEvents")
local ShowEliminationSongUI = SongGuessEvents:WaitForChild("ShowEliminationSongUI")
local UpdateLivesUi = SongGuessEvents:WaitForChild("UpdateLivesUi")
local EliminationModeSongUI = PlayerGui:WaitForChild("EliminationModeSongUI")
local CurrentRoundFrame = EliminationModeSongUI:WaitForChild("CurrentRoundFrame")
local VoteSongFrame = EliminationModeSongUI:WaitForChild("VoteSongFrame")

local function createSound(p1, p2) -- Line: 30 -- upvalues: SoundService (val)
    local Sound = Instance.new("Sound")
    Sound.SoundId = p1
    Sound.Volume = p2 or 1
    Sound.Parent = SoundService
    return Sound
end

local Sound = Instance.new("Sound")
Sound.SoundId = "rbxassetid://123796710194563"
Sound.Volume = 1
Sound.Parent = SoundService
local Sound_2 = Instance.new("Sound")
Sound_2.SoundId = "rbxassetid://123796710194563"
Sound_2.Volume = 1
Sound_2.Parent = SoundService
local Sound_3 = Instance.new("Sound")
Sound_3.SoundId = "rbxassetid://7218169592"
Sound_3.Volume = 1
Sound_3.Parent = SoundService
local Sound_4 = Instance.new("Sound")
Sound_4.SoundId = "rbxassetid://138567614125924"
Sound_4.Volume = 1
Sound_4.Parent = SoundService
local HeartImage1 = VoteSongFrame:FindFirstChild("HeartImage1")
local HeartImage2 = VoteSongFrame:FindFirstChild("HeartImage2")
local HeartImage3 = VoteSongFrame:FindFirstChild("HeartImage3")
local u87 = {}
u87[1] = HeartImage1
u87[2] = HeartImage2
u87[3] = HeartImage3
local u91 = {}
for i, v in ipairs(u87) do
    if v then
        u91[v] = v.Size
    end
end
local RoundTextLabel = CurrentRoundFrame:FindFirstChild("RoundTextLabel")
local ProgressBarFrame = CurrentRoundFrame:FindFirstChild("ProgressBarFrame")
local ProgressBar = ProgressBarFrame
if ProgressBar then
    ProgressBar = ProgressBarFrame:FindFirstChild("ProgressBar")
end
local Container = CurrentRoundFrame:FindFirstChild("Container")
local SubmitAnswerEliminationMode = SongGuessEvents:WaitForChild("SubmitAnswerEliminationMode")
local u129 = false
local u130 = 3
local Position = CurrentRoundFrame.Position
local Position_2 = VoteSongFrame.Position
local u142 = UDim2.new(Position.X.Scale, Position.X.Offset, -0.3, 0)
local u150 = UDim2.new(Position_2.X.Scale, Position_2.X.Offset, 1.3, 0)
CurrentRoundFrame.Position = u142
VoteSongFrame.Position = u150
CurrentRoundFrame.Visible = false
VoteSongFrame.Visible = false
local u157 = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local u162 = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local u167 = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local u172 = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local u177 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local u182 = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local u187 = Color3.fromRGB(85, 255, 127)
local u192 = Color3.fromRGB(255, 223, 63)
local u197 = Color3.fromRGB(255, 79, 79)
local u198 = nil
local u199 = nil
local u200 = {}
for i2, i3 in ipairs(VoteSongFrame:GetChildren()) do
    if i3:IsA("ImageButton") then
        table.insert(u200, i3)
    end
end

local function updateHeartsDisplay(p1, p2) -- Line: 112
    -- upvalues: u130 (ref), u87 (val), u91 (val), TweenService (val), u182 (val)
    local v1, v2, v3
    u130 = math.clamp(p1, 0, 3)
    local v4 = p2
    for i, v in ipairs(u87) do
        if v then
            local Size = u91[v]
            if not Size then
                Size = v.Size
            end
            if i <= u130 then
                v.Visible = true
                v.Size = Size
                v.ImageTransparency = 0
            elseif not v.Visible or not v4 then
                v.Visible = false
            else
                v3 = TweenService
                v1 = u182
                v2 = {ImageTransparency = 1, Size = UDim2.new(0, 0, 0, 0)}
                v3 = v3:Create(v, v1, v2)
                v3:Play()
                v3.Completed:Connect(function() -- Line: 130 -- upvalues: v (val), Size (val)
                    v.Visible = false
                    v.Size = Size
                end)
            end
        end
    end
end

UpdateLivesUi.OnClientEvent:Connect(function(p1) -- Line: 142 -- upvalues: updateHeartsDisplay (val)
    updateHeartsDisplay(p1, true)
end)

local function getSpectrumBars() -- Line: 149 -- upvalues: Container (val)
    local v1 = {}
    if not Container then
        return v1
    end
    for i, v in ipairs(Container:GetChildren()) do
        if v:IsA("Frame") then
            table.insert(v1, v)
        end
    end
    table.sort(v1, function(p1, p2) -- Line: 155
        local v1 = p1.LayoutOrder < p2.LayoutOrder
        return v1
    end)
    return v1
end

local function stopSpectrum() -- Line: 159 -- upvalues: u199 (ref)
    if u199 then
        u199:Disconnect()
        u199 = nil
    end
end

local function startSpectrum() -- Line: 166
    -- upvalues: u199 (ref), getSpectrumBars (val), RunService (val), SoundService (val)
    if u199 then
        u199:Disconnect()
        u199 = nil
    end
    local u7 = getSpectrumBars()
    if #u7 == 0 then
        return
    end
    local v1 = RunService
    u199 = v1.RenderStepped:Connect(function(p1) -- Line: 171 -- upvalues: SoundService (upval), u7 (val)
        local Size, v1, v2, v3, v4, v5, v6, v7, v8
        local v9 = nil
        for i, v in ipairs(SoundService:GetChildren()) do
            if v:IsA("Sound") and v.IsPlaying then
                v9 = v
                break
            end
        end
        if not v9 then
            for i4, j in ipairs(u7) do
                j.Size = UDim2.new(j.Size.X.Scale, j.Size.X.Offset, 0.25, 0)
            end
            return
        end
        local v10 = v9.PlaybackLoudness / 450
        local v11 = math.clamp(v10, 0, 1)
        v10 = #u7
        local v12 = p1
        for i2, i3 in ipairs(u7) do
            v3 = (os.clock()) * 12
            v2 = v3 + i2
            v8 = (math.sin(v2)) * 0.15
            v2 = v11 * 1.1 + v8
            v1 = math.clamp(v2, 0.05, 1)
            Size = i3.Size
            v5 = UDim2.new(Size.X.Scale, Size.X.Offset, v1, 0)
            v7 = v12 * 15
            v6 = math.min(1, v7)
            i3.Size = Size:Lerp(v5, v6)
            if not (1 < v10) then
                v3 = 0
            else
                v3 = (i2 - 1) / (v10 - 1)
                if not v3 then
                    v3 = 0
                end
            end
            v4 = (os.clock() * 0.25 + v3) % 1
            i3.BackgroundColor3 = Color3.fromHSV(v4, 1, 1)
        end
    end)
end

local u238 = Color3.fromRGB(255, 255, 255)
local u243 = Color3.fromRGB(80, 80, 80)

local function resetOptionButtonColors() -- Line: 209 -- upvalues: u200 (val), u238 (val)
    local TextLabel
    for i, v in ipairs(u200) do
        v.ImageColor3 = u238
        TextLabel = v:FindFirstChildOfClass("TextLabel")
        if TextLabel then
            TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

for i4, j in ipairs(u200) do
    local Size = j.Size
    j.MouseEnter:Connect(function() -- Line: 222 -- upvalues: u129 (ref), Sound_3 (val), Size (val), TweenService (val), j (val), u157 (val)
        if u129 then
            return
        end
        Sound_3:Play()
        local new = UDim2.new
        local v1 = Size.X.Scale * 1.05
        local v2 = Size
        local v3 = new(v1, v2.X.Offset, Size.Y.Scale * 1.05, Size.Y.Offset)
        v1 = TweenService
        local v4 = j
        local v5 = u157
        local v6 = {Size = v3}
        v1:Create(v4, v5, v6):Play()
    end)
    j.MouseLeave:Connect(function() -- Line: 232 -- upvalues: TweenService (val), j (val), u157 (val), Size (val)
        local v1 = TweenService
        local v2 = j
        local v3 = u157
        local v4 = {Size = Size}
        v1:Create(v2, v3, v4):Play()
    end)
    j.MouseButton1Click:Connect(function() -- Line: 236
        -- upvalues: u129 (ref), Sound_4 (val), SubmitAnswerEliminationMode (val), i4 (val), Size (val)
        -- upvalues: TweenService (val), j (val), u157 (val), u200 (val), u238 (val), u243 (val)
        local v1, v2, v3
        if u129 then
            return
        end
        u129 = true
        Sound_4:Play()
        local v4 = SubmitAnswerEliminationMode
        local v5 = i4
        v4:FireServer(v5)
        local new = UDim2.new
        local v6 = Size.X.Scale * 0.95
        v5 = Size
        v4 = new(v6, v5.X.Offset, Size.Y.Scale * 0.95, Size.Y.Offset)
        v6 = TweenService
        local v7 = j
        local v8 = u157
        local v9 = {Size = v4}
        v6:Create(v7, v8, v9):Play()
        for i, v in ipairs(u200) do
            if v ~= j then
                v2 = TweenService
                v3 = u157
                v1 = {ImageColor3 = u243}
                v2:Create(v, v3, v1):Play()
            else
                v2 = TweenService
                v3 = u157
                v1 = {ImageColor3 = u238}
                v2:Create(v, v3, v1):Play()
            end
        end
    end)
end
ShowEliminationSongUI.OnClientEvent:Connect(function(p1, p2) -- Line: 261
    -- upvalues: u129 (ref), resetOptionButtonColors (val), updateHeartsDisplay (val), u130 (ref), u198 (ref)
    -- upvalues: RoundTextLabel (val), ProgressBar (val), u187 (val), CurrentRoundFrame (val), u142 (val)
    -- upvalues: VoteSongFrame (val), u150 (val), Sound (val), TweenService (val), u167 (val), Position (val)
    -- upvalues: Position_2 (val), u199 (ref), getSpectrumBars (val), RunService (val), SoundService (val), u172 (val)
    -- upvalues: u177 (val), u192 (val), u197 (val), u200 (val), u162 (val), Sound_2 (val)
    local TextLabel, v1, v2
    u129 = false
    resetOptionButtonColors()
    updateHeartsDisplay(u130, false)
    if u198 then
        task.cancel(u198)
        u198 = nil
    end
    if RoundTextLabel then
        RoundTextLabel.Text = "ROUND " .. tostring(p2 or 1)
    end
    if ProgressBar then
        ProgressBar.Size = UDim2.new(1, 0, 1, 0)
        ProgressBar.BackgroundColor3 = u187
    end
    CurrentRoundFrame.Position = u142
    VoteSongFrame.Position = u150
    CurrentRoundFrame.Visible = true
    VoteSongFrame.Visible = true
    Sound:Play()
    local v3 = TweenService
    local v4 = CurrentRoundFrame
    local v5 = u167
    local v6 = {Position = Position}
    v3:Create(v4, v5, v6):Play()
    v3 = TweenService
    v4 = VoteSongFrame
    v5 = u167
    v6 = {Position = Position_2}
    v3:Create(v4, v5, v6):Play()
    if u199 then
        u199:Disconnect()
        u199 = nil
    end
    local u73 = getSpectrumBars()
    if #u73 ~= 0 then
        v1 = RunService
        u199 = v1.RenderStepped:Connect(function(p1) -- Line: 171 -- upvalues: SoundService (upval), u73 (val)
            local Size, v1, v2, v3, v4, v5, v6, v7, v8
            local v9 = nil
            for i, v in ipairs(SoundService:GetChildren()) do
                if v:IsA("Sound") and v.IsPlaying then
                    v9 = v
                    break
                end
            end
            if not v9 then
                for i4, j in ipairs(u73) do
                    j.Size = UDim2.new(j.Size.X.Scale, j.Size.X.Offset, 0.25, 0)
                end
                return
            end
            local v10 = v9.PlaybackLoudness / 450
            local v11 = math.clamp(v10, 0, 1)
            v10 = #u73
            local v12 = p1
            for i2, i3 in ipairs(u73) do
                v3 = (os.clock()) * 12
                v2 = v3 + i2
                v8 = (math.sin(v2)) * 0.15
                v2 = v11 * 1.1 + v8
                v1 = math.clamp(v2, 0.05, 1)
                Size = i3.Size
                v5 = UDim2.new(Size.X.Scale, Size.X.Offset, v1, 0)
                v7 = v12 * 15
                v6 = math.min(1, v7)
                i3.Size = Size:Lerp(v5, v6)
                if not (1 < v10) then
                    v3 = 0
                else
                    v3 = (i2 - 1) / (v10 - 1)
                    if not v3 then
                        v3 = 0
                    end
                end
                v4 = (os.clock() * 0.25 + v3) % 1
                i3.BackgroundColor3 = Color3.fromHSV(v4, 1, 1)
            end
        end)
    end
    if ProgressBar then
        v3 = TweenService
        v4 = ProgressBar
        v5 = u172
        v6 = {Size = UDim2.new(0, 0, 1, 0)}
        v3:Create(v4, v5, v6):Play()
        u198 = task.spawn(function() -- Line: 297 -- upvalues: ProgressBar (upval), TweenService (upval), u177 (upval), u192 (upval), u197 (upval)
            local v1, v2, v3, v4
            task.wait(5)
            if ProgressBar then
                v1 = TweenService
                v2 = ProgressBar
                v3 = u177
                v4 = {BackgroundColor3 = u192}
                v1:Create(v2, v3, v4):Play()
            end
            task.wait(2.5)
            if ProgressBar then
                v1 = TweenService
                v2 = ProgressBar
                v3 = u177
                v4 = {BackgroundColor3 = u197}
                v1:Create(v2, v3, v4):Play()
            end
        end)
    end
    local v7 = p1
    for i, v in ipairs(u200) do
        v2 = v7[i]
        if not v2 then
            v.Visible = false
        else
            v.Visible = true
            if v2.imageId then
                v.Image = v2.imageId
            end
            TextLabel = v:FindFirstChildOfClass("TextLabel")
            if TextLabel and v2.name then
                TextLabel.Text = v2.name
            end
            local Size = v.Size
            v.Size = UDim2.new(0, 0, 0, 0)
            task.delay(0.3 + i * 0.08, function() -- Line: 326 -- upvalues: TweenService (upval), v (val), u162 (upval), Size (val)
                local v1 = TweenService
                local v2 = v
                local v3 = u162
                local v4 = {Size = Size}
                v1:Create(v2, v3, v4):Play()
            end)
        end
    end
    task.wait(10)
    if u199 then
        u199:Disconnect()
        u199 = nil
    end
    if u198 then
        task.cancel(u198)
        u198 = nil
    end
    Sound_2:Play()
    v3 = TweenService
    v4 = CurrentRoundFrame
    v5 = u167
    v6 = {Position = u142}
    v3 = v3:Create(v4, v5, v6)
    v1 = TweenService
    v5 = VoteSongFrame
    v6 = u167
    v2 = {Position = u150}
    v1 = v1:Create(v5, v6, v2)
    v3:Play()
    v1:Play()
    v3.Completed:Wait()
    CurrentRoundFrame.Visible = false
    VoteSongFrame.Visible = false
end)
