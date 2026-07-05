--[[
    Arsenal Hub | Rayfield UI
    Aimbot / Silent Aim / Player ESP / Infinite Ammo / Rapid Fire / No Recoil / Speed
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Window = Rayfield:CreateWindow({
    Name = "Arsenal Hub",
    LoadingTitle = "Arsenal Hub",
    LoadingSubtitle = "Enjoy!",
    Theme = "Default",
    ConfigurationSaving = { Enabled = false }
})

local State = {
    Aimbot = false,
    AimbotKey = Enum.UserInputType.MouseButton2,
    SilentAim = false,
    ESP = false,
    TeamCheck = true,
    InfAmmo = false,
    RapidFire = false,
    NoRecoil = false,
    WalkSpeed = 16,
    SpeedEnabled = false,
    FOV = 120,
}

-- ================= Target helpers =================
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if State.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
        return false
    end
    return true
end

local function getHead(plr)
    local char = plr.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if head and hum and hum.Health > 0 then return head, hum end
    return nil
end

-- closest enemy head to crosshair within FOV circle
local function getClosestTarget()
    local best, bestDist = nil, State.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local head = getHead(plr)
            if head then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < bestDist then
                        best, bestDist = head, d
                    end
                end
            end
        end
    end
    return best
end

-- ================= Aimbot =================
local aimHeld = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == State.AimbotKey then aimHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == State.AimbotKey then aimHeld = false end
end)

RunService.RenderStepped:Connect(function()
    if State.Aimbot and aimHeld then
        local target = getClosestTarget()
        if target then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        end
    end
end)

-- ================= Silent Aim (redirect raycasts / mouse hit) =================
local oldNamecall
local canHook = hookmetamethod and getnamecallmethod and newcclosure
if canHook then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if State.SilentAim and not checkcaller() then
            if method == "Raycast" and self == workspace then
                local target = getClosestTarget()
                if target then
                    local origin = args[1]
                    args[2] = (target.Position - origin).Unit * 1000
                    return oldNamecall(self, unpack(args))
                end
            elseif method == "FindPartOnRayWithIgnoreList" and self == workspace then
                local target = getClosestTarget()
                if target then
                    local ray = args[1]
                    args[1] = Ray.new(ray.Origin, (target.Position - ray.Origin).Unit * 1000)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end))
end

-- ================= ESP =================
local espFolder = Instance.new("Folder")
espFolder.Name = "ArsenalESP"
espFolder.Parent = game:GetService("CoreGui")

local espObjects = {}

local function removeESP(plr)
    if espObjects[plr] then
        espObjects[plr].hl:Destroy()
        espObjects[plr].bb:Destroy()
        espObjects[plr] = nil
    end
end

local function updateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        local head, hum = getHead(plr)
        if State.ESP and isEnemy(plr) and head then
            if not espObjects[plr] then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255, 40, 40)
                hl.OutlineColor = Color3.new(1, 1, 1)
                hl.FillTransparency = 0.6
                hl.Parent = espFolder

                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 130, 0, 30)
                bb.StudsOffset = Vector3.new(0, 2.6, 0)
                bb.AlwaysOnTop = true
                bb.Parent = espFolder
                local label = Instance.new("TextLabel")
                label.Name = "Info"
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(255, 60, 60)
                label.TextStrokeTransparency = 0
                label.TextScaled = true
                label.Parent = bb

                espObjects[plr] = {hl = hl, bb = bb}
            end
            espObjects[plr].hl.Adornee = plr.Character
            espObjects[plr].bb.Adornee = head
            espObjects[plr].bb.Info.Text = string.format("%s [%d HP]", plr.Name, math.floor(hum.Health))
        else
            removeESP(plr)
        end
    end
end

RunService.Heartbeat:Connect(updateESP)
Players.PlayerRemoving:Connect(removeESP)

-- ================= Weapon mods (Inf Ammo / Rapid Fire / No Recoil) =================
-- Arsenal keeps weapon config in the client gun module; patch tool values each equip.
local function patchGun(tool)
    if not tool:IsA("Tool") then return end
    task.wait(0.2)
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name:lower()
            if State.InfAmmo and (n:find("ammo") or n:find("clip") or n:find("mag")) then
                v.Value = math.max(v.Value, 9999)
            end
            if State.RapidFire and (n:find("firerate") or n:find("cooldown") or n:find("delay")) then
                v.Value = 0.01
            end
            if State.NoRecoil and (n:find("recoil") or n:find("spread")) then
                v.Value = 0
            end
        end
    end
end

local function hookCharacter(char)
    char.ChildAdded:Connect(patchGun)
    for _, tool in ipairs(char:GetChildren()) do patchGun(tool) end
end

if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(hookCharacter)

-- continuous re-patch while toggles are on
task.spawn(function()
    while task.wait(1) do
        if State.InfAmmo or State.RapidFire or State.NoRecoil then
            local char = LocalPlayer.Character
            if char then
                for _, tool in ipairs(char:GetChildren()) do patchGun(tool) end
            end
        end
    end
end)

-- ================= Speed =================
RunService.Heartbeat:Connect(function()
    if State.SpeedEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
        end
    end
end)

-- ================= UI =================
local CombatTab = Window:CreateTab("Combat", 4483362458)

CombatTab:CreateToggle({
    Name = "Aimbot (hold Right Mouse)",
    CurrentValue = false,
    Callback = function(Value) State.Aimbot = Value end
})

CombatTab:CreateSlider({
    Name = "Aimbot FOV (px)",
    Range = {20, 500},
    Increment = 10,
    CurrentValue = 120,
    Callback = function(Value) State.FOV = Value end
})

CombatTab:CreateToggle({
    Name = "Silent Aim" .. (canHook and "" or " (executor not supported)"),
    CurrentValue = false,
    Callback = function(Value)
        if not canHook then
            Rayfield:Notify({Title = "Silent Aim", Content = "Your executor lacks hookmetamethod.", Duration = 4})
            State.SilentAim = false
            return
        end
        State.SilentAim = Value
    end
})

CombatTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Callback = function(Value) State.TeamCheck = Value end
})

local WeaponTab = Window:CreateTab("Weapons", 4483362458)

WeaponTab:CreateToggle({
    Name = "Infinite Ammo",
    CurrentValue = false,
    Callback = function(Value) State.InfAmmo = Value end
})

WeaponTab:CreateToggle({
    Name = "Rapid Fire",
    CurrentValue = false,
    Callback = function(Value) State.RapidFire = Value end
})

WeaponTab:CreateToggle({
    Name = "No Recoil / No Spread",
    CurrentValue = false,
    Callback = function(Value) State.NoRecoil = Value end
})

local VisualTab = Window:CreateTab("Visuals", 4483362458)

VisualTab:CreateToggle({
    Name = "Player ESP (box + name + HP)",
    CurrentValue = false,
    Callback = function(Value)
        State.ESP = Value
        if not Value then
            for plr in pairs(espObjects) do removeESP(plr) end
        end
    end
})

local PlayerTab = Window:CreateTab("Player", 4483362458)

PlayerTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Callback = function(Value)
        State.SpeedEnabled = Value
        if not Value then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

PlayerTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(Value) State.WalkSpeed = Value end
})

-- Anti AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

Rayfield:Notify({Title = "Arsenal Hub", Content = "Loaded successfully!", Duration = 4})
