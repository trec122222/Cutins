local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local API_URL = "https://cutins-api.nguyenxuanchuc788.workers.dev"
local DISCORD_INVITE = "https://discord.gg/MwZJ8azqrv"

local httpRequest = nil
if typeof(request) == "function" then httpRequest = request
elseif typeof(http_request) == "function" then httpRequest = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then httpRequest = syn.request end

local keyGui = Instance.new("ScreenGui")
keyGui.Name = "CuTinsLoader"
keyGui.ResetOnSpawn = false
keyGui.DisplayOrder = 999999
keyGui.IgnoreGuiInset = true
keyGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 240)
frame.Position = UDim2.new(0.5, -160, 0.5, -120)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
frame.BackgroundTransparency = 0  -- Sửa thành 0 để nền đặc, không bị xuyên thấu
frame.BorderSizePixel = 0
frame.Parent = keyGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(0, 255, 65)
stroke.Thickness = 1.5
stroke.Parent = frame

-- Header
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

-- Body
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

-- LOGIC XỬ LÝ
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
    statusLbl.Text = "> Downloading secure payload..."
    statusLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
    progressBg.Visible = true
    
    for i = 1, 10 do
        progressFill.Size = UDim2.new(i / 10, 0, 1, 0)
        task.wait(0.05)
    end

    task.spawn(function()
        local url = string.format("%s/get_script_payload?key=%s", API_URL, HttpService:UrlEncode(key))
        local ok, res = pcall(function()
            return httpRequest({ Url = url, Method = "GET" })
        end)
        
        if ok and res and res.Body and res.StatusCode == 200 then
            statusLbl.Text = "> ACCESS GRANTED. Loading hub..."
            statusLbl.TextColor3 = Color3.fromRGB(0, 255, 65)
            progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 65)
            task.wait(0.5)
            
            local success, err = pcall(function()
                loadstring(res.Body)()
            end)
            
            if success then
                keyGui:Destroy()
            else
                statusLbl.Text = "> ERROR: Corrupted payload."
                statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
            end
        else
            statusLbl.Text = "> ERROR: Invalid or expired key."
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
