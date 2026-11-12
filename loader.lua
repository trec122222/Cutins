--[[
    CuTins Hack | Loader (v3.2 - Auto Save Key & Expiry)
    Lưu key khi nhập đúng. Hết hạn tự động hiện lại UI nhập.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local API_URL = "https://cutins-api.nguyenxuanchuc788.workers.dev"
local DISCORD_INVITE = "https://discord.gg/MwZJ8azqrv"
local SAVE_FILE = "cutins_saved_key.txt"

local httpRequest = nil
if typeof(request) == "function" then httpRequest = request
elseif typeof(http_request) == "function" then httpRequest = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then httpRequest = syn.request end

-- ============================================================
-- LƯU / ĐỌC KEY
-- ============================================================
local function saveKeyToFile(key, expireTs)
    if not writefile then return end
    local content = key .. "|" .. tostring(expireTs)
    pcall(function() writefile(SAVE_FILE, content) end)
end

local function loadKeyFromFile()
    if not readfile or not isfile then return nil, nil end
    if not isfile(SAVE_FILE) then return nil, nil end
    local ok, content = pcall(function() return readfile(SAVE_FILE) end)
    if not ok or not content or content == "" then return nil, nil end

    local key, expireStr = content:match("^(.-)|(%d+)$")
    if not key or not expireStr then return nil, nil end
    return key, tonumber(expireStr)
end

local function clearSavedKey()
    if not delfile then return end
    pcall(function() delfile(SAVE_FILE) end)
end

local function isKeyExpired(expireTs)
    if not expireTs then return true end
    -- expireTs là Unix timestamp (giây)
    return os.time() >= expireTs
end

-- ============================================================
-- UI NHẬP KEY
-- ============================================================
-- Xóa UI cũ nếu có
local oldGui = playerGui:FindFirstChild("CuTinsLoader")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CuTinsLoader"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 99999
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 240)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -120)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(0, 255, 65)
mainFrame.Parent = screenGui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 25)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -50, 1, 0)
titleText.Position = UDim2.new(0, 5, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "root@cutins:~# ./auth.sh"
titleText.TextColor3 = Color3.fromRGB(150, 150, 150)
titleText.Font = Enum.Font.Code
titleText.TextSize = 12
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local function makeDot(posX, color)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, posX, 0.5, -4)
    dot.BackgroundColor3 = color
    dot.Parent = titleBar
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
end
makeDot(10, Color3.fromRGB(255, 95, 86))
makeDot(25, Color3.fromRGB(255, 189, 46))
makeDot(40, Color3.fromRGB(39, 201, 63))

local consoleLog = Instance.new("TextLabel")
consoleLog.Size = UDim2.new(1, -20, 0, 40)
consoleLog.Position = UDim2.new(0, 10, 0, 35)
consoleLog.BackgroundTransparency = 1
consoleLog.Text = "> Initializing secure environment...\n> Waiting for payload..."
consoleLog.TextColor3 = Color3.fromRGB(0, 255, 65)
consoleLog.Font = Enum.Font.Code
consoleLog.TextSize = 12
consoleLog.TextXAlignment = Enum.TextXAlignment.Left
consoleLog.TextYAlignment = Enum.TextYAlignment.Top
consoleLog.Parent = mainFrame

local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -20, 0, 35)
inputFrame.Position = UDim2.new(0, 10, 0, 80)
inputFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
inputFrame.BorderSizePixel = 1
inputFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
inputFrame.Parent = mainFrame

local inputPrompt = Instance.new("TextLabel")
inputPrompt.Size = UDim2.new(0, 30, 1, 0)
inputPrompt.Position = UDim2.new(0, 10, 0, 0)
inputPrompt.BackgroundTransparency = 1
inputPrompt.Text = "> "
inputPrompt.TextColor3 = Color3.fromRGB(0, 255, 65)
inputPrompt.Font = Enum.Font.Code
inputPrompt.TextSize = 14
inputPrompt.Parent = inputFrame

local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(1, -50, 1, 0)
textBox.Position = UDim2.new(0, 35, 0, 0)
textBox.BackgroundTransparency = 1
textBox.Text = ""
textBox.PlaceholderText = "CUTINS-XXXX-XXXX-XXXX"
textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
textBox.Font = Enum.Font.Code
textBox.TextSize = 14
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = false
textBox.Parent = inputFrame

local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, -20, 0, 6)
progressBg.Position = UDim2.new(0, 10, 0, 130)
progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
progressBg.Visible = false
progressBg.Parent = mainFrame

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
progressFill.Parent = progressBg

local btnContainer = Instance.new("Frame")
btnContainer.Size = UDim2.new(1, -20, 0, 35)
btnContainer.Position = UDim2.new(0, 10, 1, -45)
btnContainer.BackgroundTransparency = 1
btnContainer.Parent = mainFrame

local btnAuth = Instance.new("TextButton")
btnAuth.Size = UDim2.new(0.65, -5, 1, 0)
btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
btnAuth.Text = "[ AUTHENTICATE ]"
btnAuth.TextColor3 = Color3.fromRGB(0, 0, 0)
btnAuth.Font = Enum.Font.Code
btnAuth.TextSize = 13
btnAuth.Parent = btnContainer

local btnDiscord = Instance.new("TextButton")
btnDiscord.Size = UDim2.new(0.35, -5, 1, 0)
btnDiscord.Position = UDim2.new(0.65, 5, 0, 0)
btnDiscord.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
btnDiscord.Text = "DISCORD"
btnDiscord.TextColor3 = Color3.fromRGB(200, 200, 200)
btnDiscord.Font = Enum.Font.Code
btnDiscord.TextSize = 13
btnDiscord.Parent = btnContainer

-- ============================================================
-- LOGIC
-- ============================================================
local function executePayload(key)
    local url = string.format("%s/get_script_payload?key=%s", API_URL, HttpService:UrlEncode(key))
    local ok, res = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)
    
    if ok and res and res.Body and res.StatusCode == 200 then
        consoleLog.Text = "> ACCESS GRANTED. Loading hub..."
        consoleLog.TextColor3 = Color3.fromRGB(0, 255, 65)
        progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
        progressBg.Visible = true
        for i = 1, 10 do
            progressFill.Size = UDim2.new(i / 10, 0, 1, 0)
            task.wait(0.02)
        end
        task.wait(0.2)
        
        local success, err = pcall(function()
            local func, loadErr = loadstring(res.Body)
            if not func then error("Lỗi cú pháp Lua: " .. tostring(loadErr)) end
            func()
        end)
        
        if success then
            screenGui:Destroy()
        else
            consoleLog.Text = "> ERROR: " .. tostring(err)
            consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
            btnAuth.Text = "[ AUTHENTICATE ]"
            btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            progressBg.Visible = false
        end
    else
        consoleLog.Text = "> ERROR: Invalid or expired key."
        consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
        btnAuth.Text = "[ AUTHENTICATE ]"
        btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
        progressFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        progressFill.Size = UDim2.new(1, 0, 1, 0)
        task.wait(1)
        progressBg.Visible = false
        progressFill.Size = UDim2.new(0, 0, 1, 0)
    end
end

local function verifyAndSave(key)
    key = string.upper(string.gsub(key, "%s+", ""))
    if key == "" or #key < 8 then
        consoleLog.Text = "> ERROR: Key không hợp lệ."
        consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    btnAuth.Text = "[ CHECKING... ]"
    btnAuth.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    consoleLog.Text = "> Connecting to secure server..."
    consoleLog.TextColor3 = Color3.fromRGB(255, 200, 0)
    progressBg.Visible = true
    progressFill.Size = UDim2.new(0, 0, 1, 0)

    for i = 1, 10 do
        progressFill.Size = UDim2.new(i / 10, 0, 1, 0)
        task.wait(0.03)
    end

    task.spawn(function()
        local url = string.format("%s/verify?key=%s&userid=%s", API_URL, HttpService:UrlEncode(key), tostring(LocalPlayer.UserId))
        local ok, res = pcall(function()
            return httpRequest({ Url = url, Method = "GET" })
        end)
        
        if ok and res and res.Body then
            local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
            if ok2 and data and data.valid then
                -- Key hợp lệ -> Lưu key và thời gian hết hạn
                local expireTs = data.expire and math.floor(data.expire / 1000) or (os.time() + 86400)
                saveKeyToFile(key, expireTs)
                
                -- Chạy payload
                executePayload(key)
            else
                consoleLog.Text = "> ERROR: " .. (data and data.reason or "Key không hợp lệ.")
                consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
                btnAuth.Text = "[ AUTHENTICATE ]"
                btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
                progressBg.Visible = false
            end
        else
            consoleLog.Text = "> ERROR: Không kết nối được server."
            consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
            btnAuth.Text = "[ AUTHENTICATE ]"
            btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            progressBg.Visible = false
        end
    end)
end

btnDiscord.MouseButton1Click:Connect(function()
    if setclipboard then
        pcall(function() setclipboard(DISCORD_INVITE) end)
        consoleLog.Text = "> Link Discord copied to clipboard!"
        consoleLog.TextColor3 = Color3.fromRGB(0, 200, 255)
    else
        consoleLog.Text = "> Join: " .. DISCORD_INVITE
    end
end)

btnAuth.MouseButton1Click:Connect(function()
    verifyAndSave(textBox.Text)
end)

-- ============================================================
-- TỰ ĐỘNG ĐIỀN KEY CŨ (NẾU CÒN HẠN)
-- ============================================================
task.spawn(function()
    local savedKey, savedExpire = loadKeyFromFile()
    if savedKey and savedExpire and not isKeyExpired(savedExpire) then
        textBox.Text = savedKey
        consoleLog.Text = "> Saved key loaded. Auto verifying..."
        consoleLog.TextColor3 = Color3.fromRGB(0, 200, 255)
        task.wait(1)
        verifyAndSave(savedKey)
    elseif savedKey and savedExpire and isKeyExpired(savedExpire) then
        -- Key hết hạn -> xóa và hiện UI
        clearSavedKey()
        consoleLog.Text = "> Key cũ đã hết hạn. Vui lòng nhập key mới."
        consoleLog.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
end)
