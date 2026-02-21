-- Kojo Hub | Powered by LinoriaLib
-- Hợp nhất và tối ưu hóa (Fix TeamCheck Arsenal & Thêm Chams)

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({
    Title = 'Kojo Hub',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Visuals = Window:AddTab('Visuals'),
    Player = Window:AddTab('Player'),
    Skins = Window:AddTab('Skins'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- Hàm kiểm tra Team chuẩn xác cho Arsenal (Dùng TeamColor)
local function isEnemy(player)
    if not player then return false end
    if player.TeamColor ~= LocalPlayer.TeamColor then 
        return true 
    end
    return false
end

----------------------------------------------------------------------
-- [ LOGIC: AIMBOT ]
----------------------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8
FOVCircle.Visible = false

local CurrentTarget = nil

local function IsPartVisible(Part, TargetPosition)
    if not Part or not Camera then return false end
    local Origin = Camera.CFrame.Position
    local Direction = (TargetPosition - Origin)
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()}
    RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    RaycastParams.IgnoreWater = true
    local Result = workspace:Raycast(Origin, Direction.Unit * Direction.Magnitude, RaycastParams)
    return Result == nil or Result.Instance:IsDescendantOf(Part.Parent)
end

local function GetClosestPlayerInFOV()
    local Closest = nil
    local BestDist = math.huge
    local MousePos = UserInputService:GetMouseLocation()
    
    if not Options.AimPart or not Options.FOVRadius then return nil end 

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        
        -- TeamCheck Logic cho Aimbot
        if Toggles.AimbotTeamCheck and Toggles.AimbotTeamCheck.Value and not isEnemy(Player) then 
            continue 
        end

        if Player.Character then
            local Char = Player.Character
            local Humanoid = Char:FindFirstChild("Humanoid")
            if Humanoid and Humanoid.Health > 0 then
                local PartsToCheck = {}
                local AimPartStr = Options.AimPart.Value

                if AimPartStr == "Head" then
                    local Head = Char:FindFirstChild("Head")
                    if Head then table.insert(PartsToCheck, Head) end
                elseif AimPartStr == "HumanoidRootPart" then
                    local RootPart = Char:FindFirstChild("HumanoidRootPart")
                    if RootPart then table.insert(PartsToCheck, RootPart) end
                else
                    local Head = Char:FindFirstChild("Head")
                    local RootPart = Char:FindFirstChild("HumanoidRootPart")
                    if Head then table.insert(PartsToCheck, Head) end
                    if RootPart then table.insert(PartsToCheck, RootPart) end
                end

                for _, Part in ipairs(PartsToCheck) do
                    local PartPos, OnScreen = Camera:WorldToViewportPoint(Part.Position)
                    if OnScreen then
                        local ScreenPos = Vector2.new(PartPos.X, PartPos.Y)
                        local Dist = (ScreenPos - MousePos).Magnitude
                        if Dist < Options.FOVRadius.Value and IsPartVisible(Part, Part.Position) then
                            if Dist < BestDist then
                                BestDist = Dist
                                Closest = {Player = Player, Part = Part}
                            end
                        end
                    end
                end
            end
        end
    end
    return Closest
end

RunService.RenderStepped:Connect(function(DeltaTime)
    if Toggles.AimbotToggle and Toggles.AimbotToggle.Value then
        local TargetData = GetClosestPlayerInFOV()
        if TargetData then CurrentTarget = TargetData.Part.Position else CurrentTarget = nil end

        if CurrentTarget then
            local CurrentCF = Camera.CFrame
            local TargetCF = CFrame.lookAt(CurrentCF.Position, CurrentTarget)
            local LerpAlpha = math.min(1, Options.Smoothness.Value * 60 * DeltaTime)
            Camera.CFrame = CurrentCF:Lerp(TargetCF, LerpAlpha)
        end
    end

    if Toggles.ShowFOV and Toggles.ShowFOV.Value then
        local MousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = MousePos
        FOVCircle.Radius = Options.FOVRadius.Value
        FOVCircle.Color = Options.FOVColor.Value
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
end)

----------------------------------------------------------------------
-- [ LOGIC: ESP & CHAMS ]
----------------------------------------------------------------------
local ESPObjects = {}
local UpdateConnection

local ChamsFolder = CoreGui:FindFirstChild("KojoChamsFolder")
if not ChamsFolder then
    ChamsFolder = Instance.new("Folder")
    ChamsFolder.Name = "KojoChamsFolder"
    ChamsFolder.Parent = CoreGui
end

local function CreateESP(Player)
    if Player == LocalPlayer or ESPObjects[Player] then return end
    
    local Box = Drawing.new("Square")
    Box.Thickness = 2; Box.Filled = false; Box.Transparency = 1; Box.Visible = false
    
    local Name = Drawing.new("Text")
    Name.Size = 16; Name.Center = true; Name.Font = 2; Name.Outline = true; Name.Transparency = 1; Name.Visible = false
    
    local Tracer = Drawing.new("Line")
    Tracer.Thickness = 2; Tracer.Transparency = 1; Tracer.Visible = false

    local Highlight = Instance.new("Highlight")
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Enabled = false
    Highlight.Parent = ChamsFolder

    ESPObjects[Player] = {Box = Box, Name = Name, Tracer = Tracer, Highlight = Highlight}
end

local function RemoveESP(Player)
    if ESPObjects[Player] then
        ESPObjects[Player].Box:Remove()
        ESPObjects[Player].Name:Remove()
        ESPObjects[Player].Tracer:Remove()
        if ESPObjects[Player].Highlight then
            ESPObjects[Player].Highlight:Destroy()
        end
        ESPObjects[Player] = nil
    end
end

local function UpdateESPColors()
    if not Options.ESPColor then return end
    for _, objs in pairs(ESPObjects) do
        objs.Box.Color = Options.ESPColor.Value
        objs.Name.Color = Options.ESPColor.Value
        objs.Tracer.Color = Options.ESPColor.Value
    end
end

local function UpdateESP()
    for Player, objs in pairs(ESPObjects) do
        local Char = Player.Character
        
        -- TeamCheck Logic cho ESP
        if Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value and not isEnemy(Player) then
            objs.Box.Visible = false; objs.Name.Visible = false; objs.Tracer.Visible = false
            if objs.Highlight then objs.Highlight.Enabled = false end
            continue
        end

        if not Char then 
            if objs.Highlight then objs.Highlight.Enabled = false end
            continue 
        end
        
        local Humanoid = Char:FindFirstChild("Humanoid")
        local RootPart = Char:FindFirstChild("HumanoidRootPart")
        local Head = Char:FindFirstChild("Head")

        if not (Humanoid and RootPart and Head and Humanoid.Health > 0) or not (Toggles.ESPToggle and Toggles.ESPToggle.Value) then
            objs.Box.Visible = false; objs.Name.Visible = false; objs.Tracer.Visible = false
            if objs.Highlight then objs.Highlight.Enabled = false end
            continue
        end

        -- Xử lý Chams
        if objs.Highlight then
            objs.Highlight.Adornee = Char
            objs.Highlight.Enabled = Toggles.ESPChams and Toggles.ESPChams.Value or false
            if Options.ChamsFillColor then objs.Highlight.FillColor = Options.ChamsFillColor.Value end
            if Options.ChamsOutlineColor then objs.Highlight.OutlineColor = Options.ChamsOutlineColor.Value end
            if Options.ChamsTransparency then objs.Highlight.FillTransparency = Options.ChamsTransparency.Value end
        end

        -- Xử lý Drawing ESP
        local HeadPos3D = Head.Position + Vector3.new(0, 0.5, 0)
        local LegPos3D = RootPart.Position - Vector3.new(0, 3.5, 0)
        local HeadScreen, HeadOnScreen = Camera:WorldToViewportPoint(HeadPos3D)
        local LegScreen, LegOnScreen = Camera:WorldToViewportPoint(LegPos3D)
        local RootScreen, RootOnScreen = Camera:WorldToViewportPoint(RootPart.Position)

        if HeadOnScreen or LegOnScreen or RootOnScreen then
            local BoxHeight = math.max(math.abs(HeadScreen.Y - LegScreen.Y), 30)
            local BoxWidth = BoxHeight * 0.65
            local BoxX = HeadScreen.X - BoxWidth / 2
            local BoxY = HeadScreen.Y

            objs.Box.Position = Vector2.new(BoxX, BoxY)
            objs.Box.Size = Vector2.new(BoxWidth, BoxHeight)
            objs.Box.Visible = Toggles.ESPBoxes and Toggles.ESPBoxes.Value or false

            objs.Name.Position = Vector2.new(BoxX + BoxWidth / 2, BoxY - 20)
            objs.Name.Text = Player.Name .. " [" .. math.floor(Humanoid.Health) .. "]"
            objs.Name.Visible = Toggles.ESPNames and Toggles.ESPNames.Value or false

            local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            objs.Tracer.From = ScreenCenter
            objs.Tracer.To = Vector2.new(LegScreen.X, LegScreen.Y)
            objs.Tracer.Visible = Toggles.ESPTracers and Toggles.ESPTracers.Value or false
        else
            objs.Box.Visible = false; objs.Name.Visible = false; objs.Tracer.Visible = false
        end
    end
end

local function ToggleESPState(state)
    if state then
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then CreateESP(Player) end
        end
        if not UpdateConnection then UpdateConnection = RunService.Heartbeat:Connect(UpdateESP) end
    else
        for Player, _ in pairs(ESPObjects) do RemoveESP(Player) end
        if UpdateConnection then UpdateConnection:Disconnect(); UpdateConnection = nil end
    end
end

Players.PlayerRemoving:Connect(RemoveESP)
Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function()
        task.wait(0.1)
        if Toggles.ESPToggle and Toggles.ESPToggle.Value then CreateESP(Player) end
    end)
end)

----------------------------------------------------------------------
-- [ LOGIC: ARSENAL HITBOX & GUNS ]
----------------------------------------------------------------------
local hitbox_original_properties = {}
local originalValues = { FireRate = {}, ReloadTime = {}, EReloadTime = {}, Auto = {}, Spread = {}, Recoil = {} }

local function restoredPart(player)
    if hitbox_original_properties[player] then
        for partName, properties in pairs(hitbox_original_properties[player]) do
            local part = player.Character and player.Character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.CanCollide = properties.CanCollide
                part.Transparency = properties.Transparency
                part.Size = properties.Size
            end
        end
    end
end

local function extendHitbox(player)
    local parts = {"UpperTorso", "Head", "HumanoidRootPart"}
    local size = Options.HitboxSize and Options.HitboxSize.Value or 21
    local trans = Options.HitboxTrans and Options.HitboxTrans.Value / 10 or 0.6
    local nocollide = Toggles.NoCollision and Toggles.NoCollision.Value or false

    for _, partName in ipairs(parts) do
        local part = player.Character and player.Character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            if not hitbox_original_properties[player] then hitbox_original_properties[player] = {} end
            if not hitbox_original_properties[player][part.Name] then
                hitbox_original_properties[player][part.Name] = { CanCollide = part.CanCollide, Transparency = part.Transparency, Size = part.Size }
            end
            part.CanCollide = not nocollide
            part.Transparency = trans
            part.Size = Vector3.new(size, size, size)
        end
    end
end

local function updateHitboxes()
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            if Toggles.HitboxToggle and Toggles.HitboxToggle.Value then
                if Toggles.HitboxTeamCheck and Toggles.HitboxTeamCheck.Value and not isEnemy(v) then
                    restoredPart(v)
                else
                    extendHitbox(v)
                end
            else
                restoredPart(v)
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if Toggles.HitboxToggle and Toggles.HitboxToggle.Value then
            updateHitboxes()
        end
    end
end)

----------------------------------------------------------------------
-- [ UI SETUP: TAB MAIN ]
----------------------------------------------------------------------
local AimbotGroup = Tabs.Main:AddLeftGroupbox('Aimbot Settings')

AimbotGroup:AddToggle('AimbotToggle', {
    Text = 'Enable Aimbot', Default = false,
}):AddKeyPicker('AimbotKey', {
    Default = 'MB2', SyncToggleState = true, Mode = 'Toggle', Text = 'Aimbot', Tooltip = "Right click gear to change Toggle/Hold"
})

AimbotGroup:AddToggle('AimbotTeamCheck', { Text = 'Team Check', Default = true })

AimbotGroup:AddDropdown('AimPart', {
    Values = {"Head", "HumanoidRootPart", "Closest Body Part"}, Default = 1, Multi = false, Text = 'Aim Part'
})

AimbotGroup:AddSlider('Smoothness', {
    Text = 'Aimbot Smoothness', Default = 0.4, Min = 0, Max = 1, Rounding = 2
})

AimbotGroup:AddToggle('ShowFOV', { Text = 'Show FOV Circle', Default = true })
AimbotGroup:AddSlider('FOVRadius', { Text = 'FOV Radius', Default = 100, Min = 50, Max = 300, Rounding = 0 })
AimbotGroup:AddLabel('FOV Circle Color'):AddColorPicker('FOVColor', { Default = Color3.fromRGB(255, 0, 0), Title = 'FOV Color' })

local HitboxGroup = Tabs.Main:AddRightGroupbox('Hitbox Extender')
HitboxGroup:AddToggle('HitboxToggle', { Text = 'Enable Hitbox', Default = false, Callback = function(v) if not v then updateHitboxes() end end})
HitboxGroup:AddToggle('HitboxTeamCheck', { Text = 'Team Check', Default = true })
HitboxGroup:AddSlider('HitboxSize', { Text = 'Hitbox Size', Default = 21, Min = 1, Max = 50, Rounding = 0 })
HitboxGroup:AddSlider('HitboxTrans', { Text = 'Hitbox Transparency', Default = 6, Min = 1, Max = 10, Rounding = 0 })
HitboxGroup:AddToggle('NoCollision', { Text = 'No Collision', Default = false })

local GunGroup = Tabs.Main:AddRightGroupbox('Weapon Modifications')
GunGroup:AddToggle('InfAmmo', { Text = 'Infinite Ammo', Default = false, Callback = function(v)
    pcall(function() game:GetService("ReplicatedStorage").wkspc.CurrentCurse.Value = v and "Infinite Ammo" or "" end)
end})

GunGroup:AddToggle('FastReload', { Text = 'Fast Reload', Default = false, Callback = function(x)
    for _, v in pairs(game.ReplicatedStorage.Weapons:GetChildren()) do
        if v:FindFirstChild("ReloadTime") then
            if x then
                if not originalValues.ReloadTime[v] then originalValues.ReloadTime[v] = v.ReloadTime.Value end
                v.ReloadTime.Value = 0.01
            elseif originalValues.ReloadTime[v] then v.ReloadTime.Value = originalValues.ReloadTime[v] end
        end
    end
end})

GunGroup:AddToggle('FastFireRate', { Text = 'Fast Fire Rate', Default = false, Callback = function(state)
    for _, v in pairs(game.ReplicatedStorage.Weapons:GetDescendants()) do
        if v.Name == "FireRate" or v.Name == "BFireRate" then
            if state then
                if not originalValues.FireRate[v] then originalValues.FireRate[v] = v.Value end
                v.Value = 0.02
            elseif originalValues.FireRate[v] then v.Value = originalValues.FireRate[v] end
        end
    end
end})

GunGroup:AddToggle('AlwaysAuto', { Text = 'Always Auto', Default = false, Callback = function(state)
    for _, v in pairs(game.ReplicatedStorage.Weapons:GetDescendants()) do
        if v.Name == "Auto" or v.Name == "AutoFire" or v.Name == "Automatic" then
            if state then
                if not originalValues.Auto[v] then originalValues.Auto[v] = v.Value end
                v.Value = true
            elseif originalValues.Auto[v] then v.Value = originalValues.Auto[v] end
        end
    end
end})

GunGroup:AddToggle('NoSpread', { Text = 'No Spread', Default = false, Callback = function(state)
    for _, v in pairs(game:GetService("ReplicatedStorage").Weapons:GetDescendants()) do
        if v.Name == "MaxSpread" or v.Name == "Spread" then
            if state then
                if not originalValues.Spread[v] then originalValues.Spread[v] = v.Value end
                v.Value = 0
            elseif originalValues.Spread[v] then v.Value = originalValues.Spread[v] end
        end
    end
end})

GunGroup:AddToggle('NoRecoil', { Text = 'No Recoil', Default = false, Callback = function(state)
    for _, v in pairs(game:GetService("ReplicatedStorage").Weapons:GetDescendants()) do
        if v.Name == "RecoilControl" or v.Name == "Recoil" then
            if state then
                if not originalValues.Recoil[v] then originalValues.Recoil[v] = v.Value end
                v.Value = 0
            elseif originalValues.Recoil[v] then v.Value = originalValues.Recoil[v] end
        end
    end
end})

local FarmGroup = Tabs.Main:AddLeftGroupbox('AutoFarm')
FarmGroup:AddToggle('AutoFarmToggle', { Text = 'Enable AutoFarm', Default = false, Callback = function(bool)
    getgenv().AutoFarm = bool
    if bool then
        pcall(function() game:GetService("ReplicatedStorage").wkspc.CurrentCurse.Value = "Infinite Ammo" end)
        task.spawn(function()
            while getgenv().AutoFarm do task.wait() end
        end)
    else
        pcall(function() game:GetService("ReplicatedStorage").wkspc.CurrentCurse.Value = "" end)
    end
end})

----------------------------------------------------------------------
-- [ UI SETUP: TAB VISUALS ]
----------------------------------------------------------------------
local ESPGroup = Tabs.Visuals:AddLeftGroupbox('ESP Settings')

ESPGroup:AddToggle('ESPToggle', {
    Text = 'Enable ESP', Default = false, Callback = function(Value) ToggleESPState(Value) end
}):AddKeyPicker('ESPKey', {
    Default = 'C', SyncToggleState = true, Mode = 'Toggle', Text = 'ESP'
})

ESPGroup:AddToggle('ESPTeamCheck', { Text = 'Team Check', Default = true })
ESPGroup:AddToggle('ESPBoxes', { Text = 'Boxes', Default = true })
ESPGroup:AddToggle('ESPNames', { Text = 'Names', Default = true })
ESPGroup:AddToggle('ESPTracers', { Text = 'Tracers/Lines', Default = false })

ESPGroup:AddLabel('ESP Box Color'):AddColorPicker('ESPColor', {
    Default = Color3.fromRGB(255, 0, 255), Title = 'ESP Color', Callback = function() UpdateESPColors() end
})

local ChamsGroup = Tabs.Visuals:AddRightGroupbox('ESP Chams (Highlight)')

ChamsGroup:AddToggle('ESPChams', { Text = 'Enable Chams', Default = false })
ChamsGroup:AddSlider('ChamsTransparency', { Text = 'Fill Transparency', Default = 0.5, Min = 0, Max = 1, Rounding = 1 })
ChamsGroup:AddLabel('Fill Color'):AddColorPicker('ChamsFillColor', { Default = Color3.fromRGB(255, 0, 0), Title = 'Fill Color' })
ChamsGroup:AddLabel('Outline Color'):AddColorPicker('ChamsOutlineColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Outline Color' })


local ExtraVisualGroup = Tabs.Visuals:AddRightGroupbox('Extra Visuals')
ExtraVisualGroup:AddToggle('XrayToggle', {
    Text = 'Toggle Xray', Default = false, Callback = function(enabled)
        for _, descendant in pairs(workspace:GetDescendants()) do
            if descendant:IsA("BasePart") then
                if enabled then
                    if not descendant:FindFirstChild("OriginalTransparency") then
                        local orig = Instance.new("NumberValue"); orig.Name = "OriginalTransparency"; orig.Value = descendant.Transparency; orig.Parent = descendant
                    end
                    descendant.Transparency = 0.5
                else
                    if descendant:FindFirstChild("OriginalTransparency") then
                        descendant.Transparency = descendant.OriginalTransparency.Value
                        descendant.OriginalTransparency:Destroy()
                    end
                end
            end
        end
    end
})

----------------------------------------------------------------------
-- [ UI SETUP: TAB PLAYER ]
----------------------------------------------------------------------
local MoveGroup = Tabs.Player:AddLeftGroupbox('Movement Mods')
MoveGroup:AddToggle('WalkSpeedToggle', { Text = 'Custom WalkSpeed', Default = false })
MoveGroup:AddDropdown('WalkMethod', { Values = {"Velocity", "Vector", "CFrame"}, Default = 1, Text = 'Method' })
MoveGroup:AddSlider('WalkSpeedValue', { Text = 'Speed Power', Default = 16, Min = 16, Max = 500, Rounding = 0 })

RunService.Stepped:Connect(function(deltaTime)
    if Toggles.WalkSpeedToggle and Toggles.WalkSpeedToggle.Value then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root then
            local speed = Options.WalkSpeedValue.Value
            if Options.WalkMethod.Value == "Velocity" then
                local dir = hum.MoveDirection * speed
                root.Velocity = Vector3.new(dir.X, root.Velocity.Y, dir.Z)
            else
                hum.WalkSpeed = speed
            end
        end
    end
end)

local MiscPlayerGroup = Tabs.Player:AddRightGroupbox('Misc Mods')
MiscPlayerGroup:AddToggle('InfJump', { Text = 'Infinite Jump', Default = false })
UserInputService.JumpRequest:Connect(function()
    if Toggles.InfJump and Toggles.InfJump.Value then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass('Humanoid')
        if hum then hum:ChangeState("Jumping") end
    end
end)

MiscPlayerGroup:AddToggle('DeadHPToggle', { Text = 'AutoHeal (DeadHP)', Default = false })
MiscPlayerGroup:AddToggle('DeadAmmoToggle', { Text = 'AutoAmmo (DeadAmmo)', Default = false })

task.spawn(function()
    while task.wait(0.5) do
        if (Toggles.DeadHPToggle and Toggles.DeadHPToggle.Value) or (Toggles.DeadAmmoToggle and Toggles.DeadAmmoToggle.Value) then
            pcall(function()
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, v in pairs(workspace.Debris:GetChildren()) do
                        if (Toggles.DeadHPToggle.Value and v.Name == "DeadHP") or (Toggles.DeadAmmoToggle.Value and v.Name == "DeadAmmo") then
                            v.CFrame = root.CFrame
                        end
                    end
                end
            end)
        end
    end
end)

----------------------------------------------------------------------
-- [ UI SETUP: TAB SKINS ]
----------------------------------------------------------------------
local SkinGroup = Tabs.Skins:AddLeftGroupbox('Weapon & Arms Skin')
local rainbowEnabled = false
local hueValue = 0

SkinGroup:AddToggle('RainbowGun', { Text = 'Rainbow Gun', Default = false, Callback = function(state) rainbowEnabled = state end })

RunService.RenderStepped:Connect(function()
    if Camera:FindFirstChild('Arms') and rainbowEnabled then
        hueValue = (hueValue + 0.005) % 1
        for _, v in pairs(Camera.Arms:GetDescendants()) do
            if v:IsA('MeshPart') then
                v.Color = Color3.fromHSV(hueValue, 1, 1)
            end
        end
    end
end)

----------------------------------------------------------------------
-- [ UI SETUP: TAB UI SETTINGS ]
----------------------------------------------------------------------
local SystemGroup = Tabs['UI Settings']:AddLeftGroupbox('System')
SystemGroup:AddToggle('FullBright', { Text = 'Full Bright', Default = false, Callback = function(enabled)
    if enabled then
        game:GetService("Lighting").Ambient = Color3.new(1, 1, 1)
    else
        game:GetService("Lighting").Ambient = Color3.new(0.5, 0.5, 0.5)
    end
end})
SystemGroup:AddButton('Rejoin Server', function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)

local MenuGroup = Tabs['UI Settings']:AddRightGroupbox('Menu')
MenuGroup:AddButton('Unload', function() 
    if ChamsFolder then ChamsFolder:Destroy() end
    Library:Unload() 
end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightControl', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('KojoHub')
SaveManager:SetFolder('KojoHub/Configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

Library:SetWatermark('Kojo Hub | Arsenal | LinoriaLib')
Library.KeybindFrame.Visible = true

Library:OnUnload(function()
    print('Unloaded Kojo Hub!')
    Library.Unloaded = true
end)