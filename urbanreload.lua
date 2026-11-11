--[[
    CuTins Hack | Urban Reload (v1.1 - Key System Integrated)
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local VirtualUser      = game:GetService("VirtualUser")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local playerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- API CONFIG (BẠN SỬA LINK WORKER CỦA BẠN VÀO ĐÂY)
-- ============================================================
local API_URL = "https://cutins-api.nguyenxuanchuc788.workers.dev"
local DISCORD_INVITE = "https://discord.gg/MwZJ8azqrv"

-- ============================================================
-- HTTP REQUEST (HỖ TRỢ NHIỀU EXECUTOR)
-- ============================================================
local httpRequest = nil
if typeof(request) == "function" then httpRequest = request
elseif typeof(http_request) == "function" then httpRequest = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then httpRequest = syn.request end

local function checkKeyOnline(key)
    if not httpRequest then
        return false, "Executor không hỗ trợ HTTP."
    end
    key = string.upper(string.gsub(key, "%s+", "")) 
    if key == "" or #key < 8 then
        return false, "Key không hợp lệ."
    end
    
    local url = string.format("%s/verify?key=%s&userid=%s", 
        API_URL, 
        HttpService:UrlEncode(key), 
        tostring(LocalPlayer.UserId)
    )
    
    local ok, res = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)
    
    if not ok or not res or not res.Body then
        return false, "Không kết nối được server."
    end
    
    local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok2 or not data then
        return false, "Server trả dữ liệu lỗi."
    end
    
    if data.valid then
        return true, "OK"
    else
        return false, data.reason or "Key không hợp lệ."
    end
end

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    ESP = { 
        Enabled = true, ShowBox = true, ShowSkeleton = true, 
        ShowTracer = true, ShowHealthText = true, ShowDistance = true,
        MaxDistance = math.huge,
        Color = Color3.fromRGB(0,255,180),
        SkeletonColor = Color3.new(1,1,1),
        TracerColor = Color3.fromRGB(255,255,255)
    },
    Chams = { Enabled = false, Color = Color3.fromRGB(255,0,0) },
    Aimbot = { 
        Enabled = true, WallCheck = false, MaxFOV = 350, AlignBody = true,
        RequireFire = true, Prediction = 0.15, TeamCheck = true,
        SilentAim = false, AutoLock = true, AimOffsetY = 0, AimOffsetX = 0
    },
    AutoFarm = {
        Enabled   = false, FireRate  = 0.1, FireRange = 300, ClaimRange= 100,
        TeleNPC   = true, TeleLoot  = true, ClickLoot = true, LockPos   = true,
        WallCheck = false, AutoReload= true, Optimize  = false
    },
    Misc = { Fullbright = false }
}

-- ============================================================
-- STATE
-- ============================================================
local isFiring = false
local espObjects = {}
local lastFireTime = 0
local aimTargetPart = nil
local standCFrame = nil
local playerChars = {}
local deadNPCsCache = {}
local highlights = {}
local origLighting = {Brightness = Lighting.Brightness, Ambient = Lighting.Ambient}
local origEffects = {}

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircle.Visible = false

-- ============================================================
-- UTILS
-- ============================================================
local function getParts(char)
    return char:FindFirstChild("Head"), char:FindFirstChild("HumanoidRootPart")
end
local function isAlive(char)
    local h = char and char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function sDist(a, b)
    return (Vector2.new(a.X, a.Y) - Vector2.new(b.X, b.Y)).Magnitude
end
local function checkTeam(plr)
    if not Config.Aimbot.TeamCheck then return true end
    local myTeam = LocalPlayer.Team
    if not myTeam then return true end
    return plr.Team ~= myTeam
end

-- ============================================================
-- OPTIMIZE
-- ============================================================
local function toggleOptimize(on)
    if on then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                if v.Enabled then
                    v.Enabled = false
                    table.insert(origEffects, v)
                end
            end
        end
    else
        Lighting.GlobalShadows = true
        for _, v in ipairs(origEffects) do
            if v and v.Parent then v.Enabled = true end
        end
        origEffects = {}
    end
end

-- ============================================================
-- WALL CHECK
-- ============================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isVisible(targetPart)
    if not Config.Aimbot.WallCheck and not Config.AutoFarm.WallCheck then return true end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetPart then return false end
    
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    local origin = hrp.Position + Vector3.new(0, 1.5, 0)
    local dir = targetPart.Position - origin
    local res = Workspace:Raycast(origin, dir, rayParams)
    
    if res and res.Instance then
        if res.Instance:IsDescendantOf(targetPart.Parent) then return true end
        return false
    end
    return true
end

-- ============================================================
-- ESP & CHAMS
-- ============================================================
local function clearESPForPlayer(plr)
    local e = espObjects[plr]
    if not e then return end
    if e.Box then e.Box:Remove() end
    if e.Name then e.Name:Remove() end
    if e.HBg then e.HBg:Remove() end
    if e.HBar then e.HBar:Remove() end
    if e.HealthText then e.HealthText:Remove() end
    if e.DistText then e.DistText:Remove() end
    if e.Tracer then e.Tracer:Remove() end
    if e.Skel then
        for _, line in ipairs(e.Skel) do
            if line and line.Remove then line:Remove() end
        end
    end
    espObjects[plr] = nil
end

local BONES = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function updateESP()
    if not Config.ESP.Enabled then
        for p, _ in pairs(espObjects) do clearESPForPlayer(p) end
        return
    end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local vpCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local head, hrp = getParts(char)
            
            if not char or not head or not hrp or not isAlive(char) or (myHRP.Position - hrp.Position).Magnitude > Config.ESP.MaxDistance then
                clearESPForPlayer(plr)
                continue
            end

            if not espObjects[plr] then
                espObjects[plr] = {
                    Box  = Drawing.new("Square"), Name = Drawing.new("Text"),
                    HBg  = Drawing.new("Square"), HBar = Drawing.new("Square"),
                    HealthText = Drawing.new("Text"), DistText = Drawing.new("Text"),
                    Tracer = Drawing.new("Line"), Skel = {},
                }
                local e = espObjects[plr]
                e.Box.Thickness = 1.5; e.Box.Filled = false; e.Box.Color = Config.ESP.Color
                e.Name.Size = 14; e.Name.Center = true; e.Name.Outline = true; e.Name.Color = Color3.new(1,1,1)
                e.HBg.Filled = true; e.HBg.Color = Color3.fromRGB(40,40,40)
                e.HBar.Filled = true
                e.HealthText.Size = 12; e.HealthText.Center = true; e.HealthText.Outline = true
                e.DistText.Size = 12; e.DistText.Center = true; e.DistText.Outline = true; e.DistText.Color = Color3.fromRGB(200,200,200)
                e.Tracer.Thickness = 1; e.Tracer.Color = Config.ESP.TracerColor
            end

            local e = espObjects[plr]
            local hs, hon = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local rs, ron = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

            if not (hon and ron) then
                e.Box.Visible = false; e.Name.Visible = false; e.HBg.Visible = false; e.HBar.Visible = false
                e.HealthText.Visible = false; e.DistText.Visible = false; e.Tracer.Visible = false
                for _, line in ipairs(e.Skel) do line.Visible = false end
                continue
            end

            local h = math.abs(hs.Y - rs.Y) + 10
            local w = h * 0.55
            local dist = math.floor((myHRP.Position - hrp.Position).Magnitude)

            e.Box.Size = Vector2.new(w, h)
            e.Box.Position = Vector2.new(hs.X - w/2, hs.Y - 5)
            e.Box.Visible = Config.ESP.ShowBox

            e.Name.Text = plr.Name
            e.Name.Position = Vector2.new(hs.X, hs.Y - 22)
            e.Name.Visible = true
            e.DistText.Text = "[" .. dist .. "m]"
            e.DistText.Position = Vector2.new(hs.X, hs.Y - 36)
            e.DistText.Visible = Config.ESP.ShowDistance

            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local bh  = h * pct
                e.HBg.Size = Vector2.new(3, h)
                e.HBg.Position = Vector2.new(e.Box.Position.X - 6, e.Box.Position.Y)
                e.HBar.Size = Vector2.new(3, bh)
                e.HBar.Position = Vector2.new(e.Box.Position.X - 6, e.Box.Position.Y + (h - bh))
                e.HBar.Color = Color3.fromRGB(255*(1-pct), 255*pct, 0)
                e.HBg.Visible = true; e.HBar.Visible = true
                
                e.HealthText.Text = tostring(math.floor(hum.Health))
                e.HealthText.Position = Vector2.new(e.Box.Position.X - 12, e.Box.Position.Y + h/2)
                e.HealthText.Color = e.HBar.Color
                e.HealthText.Visible = Config.ESP.ShowHealthText
            end

            e.Tracer.From = vpCenter
            e.Tracer.To = Vector2.new(hs.X, hs.Y)
            e.Tracer.Visible = Config.ESP.ShowTracer

            local boneIndex = 0
            for _, pair in ipairs(BONES) do
                local a = char:FindFirstChild(pair[1])
                local b = char:FindFirstChild(pair[2])
                if a and b then
                    boneIndex = boneIndex + 1
                    local p1, o1 = Camera:WorldToViewportPoint(a.Position)
                    local p2, o2 = Camera:WorldToViewportPoint(b.Position)
                    if not e.Skel[boneIndex] then
                        e.Skel[boneIndex] = Drawing.new("Line")
                        e.Skel[boneIndex].Thickness = 1.5
                        e.Skel[boneIndex].Color = Config.ESP.SkeletonColor
                    end
                    local line = e.Skel[boneIndex]
                    if o1 and o2 then
                        line.From = Vector2.new(p1.X, p1.Y)
                        line.To = Vector2.new(p2.X, p2.Y)
                        line.Visible = Config.ESP.ShowSkeleton
                    else
                        line.Visible = false
                    end
                end
            end
        end
    end
    for plr, _ in pairs(espObjects) do
        if not plr.Parent or not Players:FindFirstChild(plr.Name) then clearESPForPlayer(plr) end
    end
end

local function updateChams()
    for plr, hl in pairs(highlights) do
        if not Config.Chams.Enabled or not plr.Character or plr == LocalPlayer then
            hl:Destroy(); highlights[plr] = nil
        end
    end
    if not Config.Chams.Enabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and isAlive(plr.Character) then
            if not highlights[plr] then
                local hl = Instance.new("Highlight")
                hl.Parent = plr.Character
                hl.FillColor = Config.Chams.Color
                hl.FillTransparency = 0.5
                hl.OutlineColor = Color3.new(1,1,1)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlights[plr] = hl
            end
        end
    end
end

-- ============================================================
-- NPC & TARGET
-- ============================================================
local npcCache, lastScan = {}, 0
local function refreshNPC()
    if tick() - lastScan < 0.3 then return end
    lastScan = tick()
    npcCache = {}
    playerChars = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then playerChars[p.Character] = true end
    end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Model") and not playerChars[o] then
            local hum = o:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = o:FindFirstChild("Head") or o.PrimaryPart
                if part then table.insert(npcCache, {model=o, part=part, hum=hum}) end
            end
        end
    end
end

local function getNPCTarget()
    refreshNPC()
    local best, bestPart, bestD = nil, nil, math.huge
    local cp = Camera.CFrame.Position
    for _, e in ipairs(npcCache) do
        if e.part and e.part.Parent and e.hum.Health > 0 then
            local d3 = (cp - e.part.Position).Magnitude
            if d3 <= Config.AutoFarm.FireRange and isVisible(e.part) then
                if d3 < bestD then bestD = d3; best = e; bestPart = e.part end
            end
        end
    end
    return best, bestPart
end

local function getPlayerTarget()
    local best, bestPart, bestD = nil, nil, Config.Aimbot.MaxFOV
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local bestPredPos = nil
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr.Character) and checkTeam(plr) then
            local head, hrp = getParts(plr.Character)
            local targetP = head or plr.Character.PrimaryPart
            if targetP and hrp and isVisible(targetP) then
                local vel = hrp.AssemblyLinearVelocity
                local predPos = targetP.Position + (vel * Config.Aimbot.Prediction)
                predPos = predPos + Vector3.new(Config.Aimbot.AimOffsetX, Config.Aimbot.AimOffsetY, 0)
                
                local sp, on = Camera:WorldToViewportPoint(predPos)
                if on then
                    local d = sDist(c, sp)
                    if d < bestD then bestD = d; best = plr; bestPart = targetP; bestPredPos = predPos end
                end
            end
        end
    end
    return best, bestPart, bestPredPos
end

-- ============================================================
-- AUTO FARM
-- ============================================================
local function teleFarmLogic()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local deadNPCs = {}
    local aliveNPCs = {}
    
    local pChars = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then pChars[p.Character] = true end
    end

    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Model") and not pChars[o] then
            local hum = o:FindFirstChildOfClass("Humanoid")
            if hum then
                local root = o:FindFirstChild("HumanoidRootPart") or o.PrimaryPart
                if root then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist <= Config.AutoFarm.ClaimRange then
                        if hum.Health > 0 then
                            table.insert(aliveNPCs, o)
                        else
                            table.insert(deadNPCs, {model=o, root=root})
                        end
                    end
                end
            end
        end
    end

    if Config.AutoFarm.TeleNPC then
        local index = 0
        for _, npc in ipairs(aliveNPCs) do
            local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
            if root then
                index += 1
                local offset = hrp.CFrame * CFrame.new((index % 3 - 1) * 5, 0, -10) 
                if (root.Position - offset.Position).Magnitude > 3 then
                    pcall(function() npc:PivotTo(offset) end)
                end
            end
        end
    end

    if Config.AutoFarm.TeleLoot then
        local index = 0
        for _, data in ipairs(deadNPCs) do
            local npc = data.model
            if not deadNPCsCache[npc] then
                index += 1
                local offset = hrp.CFrame * CFrame.new((index % 3 - 1) * 3, 0, -4)
                
                for _, p in ipairs(npc:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false; p.Anchored = false end
                end
                pcall(function() npc:PivotTo(offset) end)
                deadNPCsCache[npc] = true

                if Config.AutoFarm.ClickLoot then
                    task.spawn(function()
                        task.wait(0.2)
                        for _, d in ipairs(npc:GetDescendants()) do
                            if d:IsA("ClickDetector") then
                                pcall(function() fireclickdetector(d) end)
                                return
                            end
                        end
                        local head = npc:FindFirstChild("Head") or npc.PrimaryPart
                        if head then
                            local sp, on = Camera:WorldToViewportPoint(head.Position)
                            if on then
                                pcall(function()
                                    VirtualUser:Button1Down(Vector2.new(sp.X, sp.Y), Camera.CFrame)
                                    task.wait(0.03)
                                    VirtualUser:Button1Up(Vector2.new(sp.X, sp.Y), Camera.CFrame)
                                end)
                            end
                        end
                        local mg = playerGui:FindFirstChild("MobileGui")
                        local ib = mg and mg:FindFirstChild("Interact")
                        if ib and ib.Visible then pcall(function() ib:Click() end) end
                    end)
                end
            end
        end
    end
end

-- ============================================================
-- SILENT AIM
-- ============================================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if Config.Aimbot.SilentAim and aimTargetPart and aimTargetPart.Parent and not checkcaller() then
        if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
            local args = {...}
            local ray = args[1]
            if typeof(ray) == "Ray" then
                local newRay = Ray.new(ray.Origin, (aimTargetPart.Position - ray.Origin).Unit * 1000)
                args[1] = newRay
                return oldNamecall(self, unpack(args))
            end
        end
    end
    return oldNamecall(self, ...)
end)

-- ============================================================
-- SNAP / FIRE
-- ============================================================
local function snapTo(pos)
    if not pos then return end
    local tCF = CFrame.lookAt(Camera.CFrame.Position, pos, Vector3.new(0,1,0))
    Camera.CFrame = tCF
    if Config.Aimbot.AlignBody then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            hum.AutoRotate = false
            local look = Vector3.new(pos.X, hrp.Position.Y, pos.Z)
            hrp.CFrame = CFrame.lookAt(hrp.Position, look, Vector3.new(0,1,0))
        end
    end
end

local function getBtn(name)
    local mg = playerGui:FindFirstChild("MobileGui")
    if not mg then return nil end
    local exact = mg:FindFirstChild(name)
    if exact then return exact end
    for _, v in ipairs(mg:GetDescendants()) do
        if v:IsA("GuiButton") and v.Name:lower():find(name:lower()) then
            return v
        end
    end
    return nil
end

local function fireOnce()
    if tick() - lastFireTime < Config.AutoFarm.FireRate then return end
    lastFireTime = tick()
    local fb = getBtn("Fire") or getBtn("Shoot") or getBtn("Attack")
    if fb and fb.Visible then
        pcall(function() fb:Click() end)
        local pos = fb.AbsolutePosition + fb.AbsoluteSize / 2
        pcall(function()
            VirtualUser:Button1Down(pos, Camera.CFrame)
            task.wait(0.03)
            VirtualUser:Button1Up(pos, Camera.CFrame)
        end)
    end
end

local function checkReload()
    if not Config.AutoFarm.AutoReload then return end
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local ammo = tool:FindFirstChild("Ammo") or tool:FindFirstChild("AmmoCount")
        if ammo and ammo:IsA("ValueBase") and ammo.Value <= 0 then
            local rb = getBtn("Reload")
            if rb and rb.Visible then pcall(function() rb:Click() end) end
        end
    end
end

-- ============================================================
-- MISC
-- ============================================================
local function applyMisc()
    if Config.Misc.Fullbright then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(150,150,150)
        Lighting.OutdoorAmbient = Color3.fromRGB(150,150,150)
    else
        Lighting.Brightness = origLighting.Brightness
        Lighting.Ambient = origLighting.Ambient
        Lighting.OutdoorAmbient = origLighting.Ambient
    end
end

-- ============================================================
-- MAIN HUB FUNCTION (Chỉ chạy sau khi nhập đúng Key)
-- ============================================================
local function loadMainHub()
    print("[CuTins Hack] Key hợp lệ. Đang tải Hub...")
    
    -- RENDER LOOP
    RunService:BindToRenderStep("CH_Aim", Enum.RenderPriority.Camera.Value + 1, function()
        if Config.Aimbot.Enabled or Config.AutoFarm.Enabled then
            local vp = Camera.ViewportSize
            fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
            fovCircle.Radius = Config.Aimbot.MaxFOV
            fovCircle.Color = Config.ESP.Color
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end

        aimTargetPart = nil
        if Config.AutoFarm.Enabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum and Config.AutoFarm.LockPos then
                if not standCFrame then standCFrame = hrp.CFrame end
                if (hrp.Position - standCFrame.Position).Magnitude > 1 then
                    hrp.CFrame = CFrame.new(standCFrame.Position, hrp.CFrame.LookVector)
                end
                hum:MoveTo(hrp.Position)
            end

            local e, part = getNPCTarget()
            if e and part then
                aimTargetPart = part
                snapTo(part.Position)
            end
        else
            if Config.Aimbot.Enabled and (not Config.Aimbot.RequireFire or isFiring) then
                local _, part, predPos = getPlayerTarget()
                if part then
                    aimTargetPart = part
                    if Config.Aimbot.AutoLock or Config.Aimbot.SilentAim then snapTo(predPos or part.Position) end
                end
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        updateESP()
        updateChams()

        if Config.AutoFarm.Enabled then
            teleFarmLogic()
            checkReload()
            local e, part = getNPCTarget()
            if e and part and aimTargetPart then
                fireOnce()
            end
        else
            standCFrame = nil
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true end
        end

        if tick() % 10 < 0.01 then
            for model in pairs(deadNPCsCache) do
                if not model.Parent then deadNPCsCache[model] = nil end
            end
        end
    end)

    -- INPUT
    UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then isFiring = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then isFiring = false end
    end)

    -- UI HUB
    local sg = Instance.new("ScreenGui")
    sg.Name = "CuTinsHack"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 99999
    sg.Parent = playerGui

    local tgl = Instance.new("TextButton")
    tgl.Name = "ToggleBtn"
    tgl.Size = UDim2.new(0, 55, 0, 55)
    tgl.Position = UDim2.new(0, 20, 0.4, 0)
    tgl.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    tgl.Text = "CH"
    tgl.TextColor3 = Color3.fromRGB(0, 255, 180)
    tgl.TextSize = 20
    tgl.Font = Enum.Font.GothamBold
    tgl.AutoButtonColor = false
    tgl.Active = true
    tgl.ZIndex = 9999
    tgl.Parent = sg
    Instance.new("UICorner", tgl).CornerRadius = UDim.new(0.5, 0)
    local tglStroke = Instance.new("UIStroke", tgl)
    tglStroke.Color = Color3.fromRGB(0, 255, 180)
    tglStroke.Thickness = 1.5
    tglStroke.Parent = tgl

    local main = Instance.new("Frame")
    main.Name = "MainPanel"
    main.Size = UDim2.new(0, 380, 0, 380)
    main.Position = UDim2.new(0.5, -190, 0.5, -190)
    main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    main.BackgroundTransparency = 0.1
    main.Visible = false
    main.ZIndex = 9000
    main.Active = true
    main.Parent = sg
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
    local mainStroke = Instance.new("UIStroke", main)
    mainStroke.Color = Color3.fromRGB(0, 255, 100)
    mainStroke.Thickness = 1
    mainStroke.Parent = main

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    header.BackgroundTransparency = 0.8
    header.BorderSizePixel = 0
    header.ZIndex = 9001
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "root@cutins:~# ./hack.exe --v1.1"
    title.TextColor3 = Color3.fromRGB(0, 255, 100)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 9002
    title.Parent = header

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 30, 0, 20)
    close.Position = UDim2.new(1, -35, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.Code
    close.TextSize = 14
    close.ZIndex = 9003
    close.Parent = header
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(0, 80, 1, -40)
    tabBar.Position = UDim2.new(0, 5, 0, 35)
    tabBar.BackgroundTransparency = 1
    tabBar.ZIndex = 9001
    tabBar.Parent = main
    local tabLayout = Instance.new("UIListLayout", tabBar)
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = tabBar

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -95, 1, -40)
    contentArea.Position = UDim2.new(0, 90, 0, 35)
    contentArea.BackgroundTransparency = 1
    contentArea.ZIndex = 9001
    contentArea.Parent = main

    local function createTab(text, pageFrame)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        btn.Font = Enum.Font.Code
        btn.TextSize = 13
        btn.ZIndex = 9002
        btn.Parent = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        
        btn.MouseButton1Click:Connect(function()
            for _, child in ipairs(contentArea:GetChildren()) do
                if child:IsA("ScrollingFrame") then child.Visible = false end
            end
            for _, child in ipairs(tabBar:GetChildren()) do
                if child:IsA("TextButton") then 
                    child.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                    child.TextColor3 = Color3.fromRGB(150, 150, 150)
                end
            end
            pageFrame.Visible = true
            btn.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            btn.TextColor3 = Color3.fromRGB(10, 10, 12)
        end)
        return btn
    end

    local function createPage()
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 100)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0,0,0,0)
        page.Visible = false
        page.ZIndex = 9002
        page.Parent = contentArea
        local layout = Instance.new("UIListLayout", page)
        layout.Padding = UDim.new(0, 6)
        return page
    end

    local function addToggle(parent, label, init, cb)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -5, 0, 32)
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        f.ZIndex = 9003
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -60, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = Color3.fromRGB(200, 200, 200)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Code
        l.TextSize = 13
        l.ZIndex = 9004
        l.Parent = f

        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 45, 0, 22)
        b.Position = UDim2.new(1, -55, 0.5, -11)
        b.BackgroundColor3 = init and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(40, 40, 45)
        b.Text = init and "ON" or "OFF"
        b.TextColor3 = init and Color3.fromRGB(10,10,12) or Color3.fromRGB(150, 150, 150)
        b.Font = Enum.Font.Code
        b.TextSize = 12
        b.ZIndex = 9004
        b.Parent = f
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

        b.MouseButton1Click:Connect(function()
            local nv = not cb.state
            cb.state = nv
            b.BackgroundColor3 = nv and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(40, 40, 45)
            b.Text = nv and "ON" or "OFF"
            b.TextColor3 = nv and Color3.fromRGB(10,10,12) or Color3.fromRGB(150, 150, 150)
            cb.fn(nv) 
        end)
    end

    local function addSlider(parent, label, minVal, maxVal, initVal, cb)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -5, 0, 45)
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        f.ZIndex = 9003
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 22)
        l.Position = UDim2.new(0, 10, 0, 2)
        l.BackgroundTransparency = 1
        l.Text = label .. ": " .. tostring(initVal)
        l.TextColor3 = Color3.fromRGB(200, 200, 200)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Code
        l.TextSize = 13
        l.ZIndex = 9004
        l.Parent = f

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -20, 0, 8)
        bar.Position = UDim2.new(0, 10, 1, -18)
        bar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        bar.BorderSizePixel = 0
        bar.ZIndex = 9004
        bar.Parent = f
        Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((initVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        fill.BorderSizePixel = 0
        fill.ZIndex = 9005
        fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

        local hit = Instance.new("TextButton")
        hit.Size = UDim2.new(1, 0, 1, 20)
        hit.Position = UDim2.new(0, 0, 0, -6)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.ZIndex = 9006
        hit.Parent = bar

        local dragging = false
        local function setX(absX)
            local rel = math.clamp((absX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(minVal + (maxVal - minVal) * rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            l.Text = label .. ": " .. tostring(val)
            cb(val)
        end

        hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; setX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                setX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local pageVisuals = createPage()
    local pageCombat = createPage()
    local pageFarm = createPage()
    local pageMisc = createPage()

    local tabVis = createTab("Visuals", pageVisuals)
    local tabCom = createTab("Combat", pageCombat)
    local tabFarm = createTab("Farming", pageFarm)
    local tabMisc = createTab("Misc", pageMisc)

    pageFarm.Visible = true
    tabFarm.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    tabFarm.TextColor3 = Color3.fromRGB(10, 10, 12)

    addToggle(pageVisuals, "ESP Enabled", Config.ESP.Enabled, {state=Config.ESP.Enabled, fn=function(v) Config.ESP.Enabled = v end})
    addToggle(pageVisuals, "Show Box", Config.ESP.ShowBox, {state=Config.ESP.ShowBox, fn=function(v) Config.ESP.ShowBox = v end})
    addToggle(pageVisuals, "Show Skeleton", Config.ESP.ShowSkeleton, {state=Config.ESP.ShowSkeleton, fn=function(v) Config.ESP.ShowSkeleton = v end})

    addToggle(pageCombat, "Aimbot", Config.Aimbot.Enabled, {state=Config.Aimbot.Enabled, fn=function(v) Config.Aimbot.Enabled = v end})
    addToggle(pageCombat, "Silent Aim", Config.Aimbot.SilentAim, {state=Config.Aimbot.SilentAim, fn=function(v) Config.Aimbot.SilentAim = v end})
    addToggle(pageCombat, "Wall Check", Config.Aimbot.WallCheck, {state=Config.Aimbot.WallCheck, fn=function(v) Config.Aimbot.WallCheck = v; Config.AutoFarm.WallCheck = v end})
    addSlider(pageCombat, "FOV Size", 50, 800, Config.Aimbot.MaxFOV, function(v) Config.Aimbot.MaxFOV = v end)

    addToggle(pageFarm, "Auto Farm", Config.AutoFarm.Enabled, {state=Config.AutoFarm.Enabled, fn=function(v)
        Config.AutoFarm.Enabled = v
        if v then standCFrame = nil else
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true end
        end
    end})
    addToggle(pageFarm, "Tele NPC (Kéo lại gần)", Config.AutoFarm.TeleNPC, {state=Config.AutoFarm.TeleNPC, fn=function(v) Config.AutoFarm.TeleNPC = v end})
    addToggle(pageFarm, "Tele Loot (Kéo xác)", Config.AutoFarm.TeleLoot, {state=Config.AutoFarm.TeleLoot, fn=function(v) Config.AutoFarm.TeleLoot = v end})
    addToggle(pageFarm, "Click Loot (Nhặt tiền)", Config.AutoFarm.ClickLoot, {state=Config.AutoFarm.ClickLoot, fn=function(v) Config.AutoFarm.ClickLoot = v end})
    addToggle(pageFarm, "Fix Lag (Optimize)", Config.AutoFarm.Optimize, {state=Config.AutoFarm.Optimize, fn=function(v)
        Config.AutoFarm.Optimize = v
        toggleOptimize(v)
    end})

    addToggle(pageMisc, "Fullbright", Config.Misc.Fullbright, {state=Config.Misc.Fullbright, fn=function(v) Config.Misc.Fullbright = v; applyMisc() end})

    tgl.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)
    close.MouseButton1Click:Connect(function() main.Visible = false end)

    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ============================================================
-- UI NHẬP KEY (HACKER TERMINAL STYLE)
-- ============================================================
local keyGui = Instance.new("ScreenGui")
keyGui.Name = "CuTinsKeySystem"
keyGui.ResetOnSpawn = false
keyGui.DisplayOrder = 999999
keyGui.IgnoreGuiInset = true
keyGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 240)
frame.Position = UDim2.new(0.5, -160, 0.5, -120)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = keyGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(0, 255, 65)
stroke.Thickness = 1.5
stroke.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
header.BorderSizePixel = 0
header.Parent = frame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)

local dotR = Instance.new("Frame")
dotR.Size = UDim2.new(0, 10, 0, 10)
dotR.Position = UDim2.new(0, 10, 0.5, -5)
dotR.BackgroundColor3 = Color3.fromRGB(255, 95, 86)
dotR.Parent = header
Instance.new("UICorner", dotR).CornerRadius = UDim.new(1, 0)

local dotY = Instance.new("Frame")
dotY.Size = UDim2.new(0, 10, 0, 10)
dotY.Position = UDim2.new(0, 25, 0.5, -5)
dotY.BackgroundColor3 = Color3.fromRGB(255, 189, 46)
dotY.Parent = header
Instance.new("UICorner", dotY).CornerRadius = UDim.new(1, 0)

local dotG = Instance.new("Frame")
dotG.Size = UDim2.new(0, 10, 0, 10)
dotG.Position = UDim2.new(0, 40, 0.5, -5)
dotG.BackgroundColor3 = Color3.fromRGB(39, 201, 63)
dotG.Parent = header
Instance.new("UICorner", dotG).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 55, 0, 0)
title.BackgroundTransparency = 1
title.Text = "root@cutins: ~/auth"
title.TextColor = Color3.fromRGB(150, 150, 150)
title.Font = Enum.Font.Code
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -40)
body.Position = UDim2.new(0, 10, 0, 35)
body.BackgroundTransparency = 1
body.Parent = frame

local prompt = Instance.new("TextLabel")
prompt.Size = UDim2.new(1, 0, 0, 20)
prompt.BackgroundTransparency = 1
prompt.Text = "> Enter license key to continue..."
prompt.TextColor = Color3.fromRGB(0, 255, 65)
prompt.Font = Enum.Font.Code
prompt.TextSize = 13
prompt.TextXAlignment = Enum.TextXAlignment.Left
prompt.Parent = body

local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, 0, 0, 35)
inputFrame.Position = UDim2.new(0, 0, 0, 25)
inputFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
inputFrame.Parent = body
Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 4)
local inStroke = Instance.new("UIStroke", inputFrame)
inStroke.Color = Color3.fromRGB(50, 50, 50)

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -20, 1, 0)
input.Position = UDim2.new(0, 10, 0, 0)
input.BackgroundTransparency = 1
input.PlaceholderText = "CUTINS-XXXX-XXXX-XXXX"
input.Text = ""
input.TextColor3 = Color3.fromRGB(255, 255, 255)
input.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
input.Font = Enum.Font.Code
input.TextSize = 14
input.TextXAlignment = Enum.TextXAlignment.Left
input.ClearTextOnFocus = false
input.Parent = inputFrame

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, 0, 0, 20)
statusLbl.Position = UDim2.new(0, 0, 0, 65)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = ""
statusLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
statusLbl.Font = Enum.Font.Code
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = body

local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, 0, 0, 6)
progressBg.Position = UDim2.new(0, 0, 0, 90)
progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
progressBg.Visible = false
progressBg.Parent = body
Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
progressFill.Parent = progressBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

local btnContainer = Instance.new("Frame")
btnContainer.Size = UDim2.new(1, 0, 0, 35)
btnContainer.Position = UDim2.new(0, 0, 1, -40)
btnContainer.BackgroundTransparency = 1
btnContainer.Parent = body

local submit = Instance.new("TextButton")
submit.Size = UDim2.new(0.6, -5, 1, 0)
submit.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
submit.Text = "[ AUTHENTICATE ]"
submit.TextColor3 = Color3.fromRGB(10, 10, 12)
submit.Font = Enum.Font.Code
submit.TextSize = 13
submit.Parent = btnContainer
Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 4)

local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0.4, -5, 1, 0)
discordBtn.Position = UDim2.new(0.6, 5, 0, 0)
discordBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
discordBtn.Text = "DISCORD"
discordBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
discordBtn.Font = Enum.Font.Code
discordBtn.TextSize = 13
discordBtn.Parent = btnContainer
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 4)

-- LOGIC
discordBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        pcall(function() setclipboard(DISCORD_INVITE) end)
        statusLbl.Text = "> Link Discord copied."
        statusLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
    else
        statusLbl.Text = "> Join: " .. DISCORD_INVITE
        statusLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
    end
end)

submit.MouseButton1Click:Connect(function()
    local key = input.Text
    if key == "" then
        statusLbl.Text = "> ERROR: Key cannot be empty."
        statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    submit.Text = "[ CHECKING... ]"
    submit.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    statusLbl.Text = "> Connecting to secure server..."
    statusLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
    progressBg.Visible = true
    
    for i = 1, 10 do
        progressFill.Size = UDim2.new(i / 10, 0, 1, 0)
        task.wait(0.05)
    end

    task.spawn(function()
        local ok, msg = checkKeyOnline(key)
        
        if ok then
            statusLbl.Text = "> ACCESS GRANTED. Loading hub..."
            statusLbl.TextColor3 = Color3.fromRGB(0, 255, 65)
            progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            
            task.wait(0.8)
            
            for i = 1, 10 do
                frame.BackgroundTransparency = frame.BackgroundTransparency + 0.1
                stroke.Transparency = stroke.Transparency + 0.1
                if frame.BackgroundTransparency >= 1 then break end
                task.wait(0.03)
            end
            
            keyGui:Destroy()
            loadMainHub()
        else
            statusLbl.Text = "> ERROR: " .. (msg or "Invalid key.")
            statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
            submit.Text = "[ AUTHENTICATE ]"
            submit.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            
            progressFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            progressFill.Size = UDim2.new(1, 0, 1, 0)
            task.wait(1)
            progressBg.Visible = false
            progressFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end)
end)