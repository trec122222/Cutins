--[[
    CuTins Hack | Loader (v2.5 - Base64 + No Vararg)
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local API_URL = "https://cutins-api.nguyenxuanchuc788.workers.dev"
local DISCORD_INVITE = "https://discord.gg/MwZJ8azqrv"
local CACHE_FILE = "CutinsHack_KeyCache.json"

local httpRequest = nil
if typeof(request) == "function" then httpRequest = request
elseif typeof(http_request) == "function" then httpRequest = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then httpRequest = syn.request end

local function hasFileAPI()
    return typeof(writefile) == "function" and typeof(isfile) == "function" and typeof(readfile) == "function"
end

local function readCache()
    if not hasFileAPI() then return nil end
    local ok, res = pcall(function()
        if not isfile(CACHE_FILE) then return nil end
        return HttpService:JSONDecode(readfile(CACHE_FILE))
    end)
    if ok and type(res) == "table" then return res end
    return nil
end

local function writeCache(key, expire)
    if not hasFileAPI() then return end
    pcall(function()
        writefile(CACHE_FILE, HttpService:JSONEncode({ key = key, expire = expire }))
    end)
end

local function clearCache()
    if not hasFileAPI() then return end
    pcall(function()
        if isfile(CACHE_FILE) then delfile(CACHE_FILE) end
    end)
end

local function checkKeyOnline(key)
    if not httpRequest then return false, "Executor không hỗ trợ HTTP." end
    key = string.upper(string.gsub(key, "%s+", ""))
    if key == "" or #key < 8 then return false, "Key không hợp lệ." end

    local url = string.format("%s/verify?key=%s&userid=%s", API_URL, HttpService:UrlEncode(key), tostring(LocalPlayer.UserId))
    local ok, res = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)
    if not ok or not res or not res.Body then return false, "Không kết nối được server." end

    local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok2 or not data then return false, "Server trả dữ liệu lỗi." end

    if data.valid then return true, data.expire or 0
    else return false, data.reason or "Key không hợp lệ." end
end

local function fetchPayload(key)
    if not httpRequest then return nil end
    local url = string.format("%s/get_script_payload?key=%s", API_URL, HttpService:UrlEncode(key))
    local ok, res = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)
    if ok and res and res.Body and res.StatusCode == 200 then return res.Body end
    return nil
end

local function base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function runPayload(b64_body)
    if not b64_body or b64_body == "" then return false, "Payload rỗng" end
    local body = base64_decode(b64_body)
    local func, err = loadstring(body)
    if not func then return false, "Lỗi cú pháp: " .. tostring(err) end
    local ok, runErr = pcall(func)
    if not ok then return false, "Lỗi runtime: " .. tostring(runErr) end
    return true
end

-- TỰ ĐỘNG ĐĂNG NHẬP NẾU CÓ CACHE
local cached = readCache()
if cached and cached.key and cached.expire then
    if tonumber(cached.expire) and tonumber(cached.expire) > (os.time() * 1000) then
        local body = fetchPayload(cached.key)
        if body then
            if runPayload(body) then return end
        end
    else
        clearCache()
    end
end

-- UI NHẬP KEY
local oldGui = playerGui:FindFirstChild("CuTinsLoader")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CuTinsLoader"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 99999
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 230)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -115)
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
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 55, 0, 0)
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
    local key = textBox.Text
    if key == "" then
        consoleLog.Text = "> ERROR: Key cannot be empty."
        consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    btnAuth.Text = "[ CHECKING... ]"
    btnAuth.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    consoleLog.Text = "> Connecting to secure server..."
    consoleLog.TextColor3 = Color3.fromRGB(255, 200, 0)
    progressBg.Visible = true

    for i = 1, 10 do
        progressFill.Size = UDim2.new(i / 10, 0, 1, 0)
        task.wait(0.05)
    end

    task.spawn(function()
        local ok, expireOrMsg = checkKeyOnline(key)

        if ok then
            consoleLog.Text = "> ACCESS GRANTED. Loading hub..."
            consoleLog.TextColor3 = Color3.fromRGB(0, 255, 65)
            progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            task.wait(0.3)

            local body = fetchPayload(key)
            if body then
                local success, err = runPayload(body)
                if success then
                    writeCache(key, tonumber(expireOrMsg) or (os.time() * 1000 + 86400000))
                    screenGui:Destroy()
                    return
                else
                    consoleLog.Text = "> ERROR: " .. tostring(err)
                end
            else
                consoleLog.Text = "> ERROR: Không tải được Payload."
            end

            consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
            btnAuth.Text = "[ AUTHENTICATE ]"
            btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            progressBg.Visible = false
        else
            consoleLog.Text = "> ERROR: " .. tostring(expireOrMsg)
            consoleLog.TextColor3 = Color3.fromRGB(255, 80, 80)
            btnAuth.Text = "[ AUTHENTICATE ]"
            btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            progressFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            progressFill.Size = UDim2.new(1, 0, 1, 0)
            task.wait(1)
            progressBg.Visible = false
            progressFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end)
end)