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
-- OPTIMIZE (FIX LAG)
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
                        if ib and ib.Visible then pcall(function() ib:Click()
