local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local API_URL = "https://cutins-api.nguyenxuanchuc788.workers.dev"
local DISCORD_INVITE = "https://discord.gg/MwZJ8azqrv"

local httpRequest = nil
if typeof(request) == "function" then httpRequest = request
elseif typeof(http_request) == "function" then httpRequest = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then httpRequest = syn.request end

-- Xóa UI cũ nếu có (tránh bị trùng)
local oldGui = playerGui:FindFirstChild("CuTinsLoader")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CuTinsLoader"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 99999
screenGui.Parent = playerGui

-- 1. KHUNG CHÍNH (Màu đen đặc)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 220)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -110)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(0, 255, 65)
mainFrame.Parent = screenGui

-- 2. TIÊU ĐỀ
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
title.Text = " CUTINS HACK - AUTH"
title.TextColor3 = Color3.fromRGB(0, 0, 0)
title.Font = Enum.Font.Code
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- 3. Ô NHẬP KEY
local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(0.9, 0, 0, 35)
textBox.Position = UDim2.new(0.05, 0, 0, 50)
textBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
textBox.TextColor3 = Color3.fromRGB(0, 255, 65)
textBox.PlaceholderText = "Dán Key vào đây..."
textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
textBox.Font = Enum.Font.Code
textBox.TextSize = 14
textBox.ClearTextOnFocus = false
textBox.Parent = mainFrame

-- 4. NÚT XÁC NHẬN (To, màu xanh)
local btnAuth = Instance.new("TextButton")
btnAuth.Size = UDim2.new(0.9, 0, 0, 40)
btnAuth.Position = UDim2.new(0.05, 0, 0, 100)
btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
btnAuth.Text = "AUTHENTICATE"
btnAuth.TextColor3 = Color3.fromRGB(0, 0, 0)
btnAuth.Font = Enum.Font.GothamBold
btnAuth.TextSize = 16
btnAuth.Parent = mainFrame

-- 5. NÚT DISCORD
local btnDiscord = Instance.new("TextButton")
btnDiscord.Size = UDim2.new(0.9, 0, 0, 30)
btnDiscord.Position = UDim2.new(0.05, 0, 0, 160)
btnDiscord.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
btnDiscord.Text = "JOIN DISCORD"
btnDiscord.TextColor3 = Color3.fromRGB(255, 255, 255)
btnDiscord.Font = Enum.Font.GothamBold
btnDiscord.TextSize = 14
btnDiscord.Parent = mainFrame

-- 6. DÒNG TRẠNG THÁI
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(0.9, 0, 0, 20)
statusLbl.Position = UDim2.new(0.05, 0, 0, 195)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "> Waiting for Key..."
statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLbl.Font = Enum.Font.Code
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = mainFrame

-- ==========================================
-- CHỨC NĂNG NÚT BẤM
-- ==========================================

btnDiscord.MouseButton1Click:Connect(function()
    if setclipboard then
        pcall(function() setclipboard(DISCORD_INVITE) end)
        statusLbl.Text = "> Đã copy link Discord!"
    else
        statusLbl.Text = "> Link: " .. DISCORD_INVITE
    end
end)

btnAuth.MouseButton1Click:Connect(function()
    local key = textBox.Text
    if key == "" then
        statusLbl.Text = "> Lỗi: Chưa nhập Key!"
        return
    end

    btnAuth.Text = "CHECKING..."
    btnAuth.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    statusLbl.Text = "> Đang xác thực..."

    task.spawn(function()
        local url = string.format("%s/get_script_payload?key=%s", API_URL, HttpService:UrlEncode(key))
        local ok, res = pcall(function()
            return httpRequest({ Url = url, Method = "GET" })
        end)
        
        if ok and res and res.Body and res.StatusCode == 200 then
            statusLbl.Text = "> Thành công! Đang tải Hub..."
            statusLbl.TextColor3 = Color3.fromRGB(0, 255, 65)
            task.wait(0.5)
            
            local success = pcall(function()
                loadstring(res.Body)()
            end)
            
            if success then
                screenGui:Destroy()
            else
                statusLbl.Text = "> Lỗi: Code bị hỏng!"
            end
        else
            statusLbl.Text = "> Lỗi: Key sai hoặc hết hạn!"
            btnAuth.Text = "AUTHENTICATE"
            btnAuth.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
        end
    end)
end)
