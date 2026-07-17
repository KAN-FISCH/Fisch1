-- ======================================================================
-- Anti-Lag & Rate Limiting Remote Hook (ShieldTeam Optimizer)
-- ======================================================================
local function initRemoteOptimizer()
    local success, err = pcall(function()
        local BlockedRemotes = {}
        
        local RateLimits = {
            ["RE/PassiveVfx/Cleanup"] = {max = 5, interval = 1, lastReset = os.clock(), count = 0},
            ["Ping"]                  = {max = 1, interval = 1, lastReset = os.clock(), count = 0},
            ["Set"]                   = {max = 2, interval = 1, lastReset = os.clock(), count = 0},
            ["chat"]                  = {max = 3, interval = 1, lastReset = os.clock(), count = 0},
        }

        local oldFireServer
        oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
            local name = self.Name
            if BlockedRemotes[name] then
                return
            end
            
            local rl = RateLimits[name]
            if rl then
                local now = os.clock()
                if now - rl.lastReset >= rl.interval then
                    rl.lastReset = now
                    rl.count = 0
                end
                if rl.count >= rl.max then
                    return
                end
                rl.count = rl.count + 1
            end
            
            return oldFireServer(self, ...)
        end))

        local oldInvokeServer
        oldInvokeServer = hookfunction(Instance.new("RemoteFunction").InvokeServer, newcclosure(function(self, ...)
            local name = self.Name
            if BlockedRemotes[name] then
                return
            end
            
            local rl = RateLimits[name]
            if rl then
                local now = os.clock()
                if now - rl.lastReset >= rl.interval then
                    rl.lastReset = now
                    rl.count = 0
                end
                if rl.count >= rl.max then
                    return
                end
                rl.count = rl.count + 1
            end
            
            return oldInvokeServer(self, ...)
        end))
        
        print("[ShieldTeam] Remote Optimizer Loaded Successfully!")
    end)
    if not success then
        warn("[ShieldTeam] Failed to initialize Remote Optimizer: " .. tostring(err))
    end
end
task.spawn(initRemoteOptimizer)

local BaseURL = "https://raw.githubusercontent.com/KAN-FISCH/Fisch1/refs/heads/main/"
local FallbackBaseURL = "https://raw.githubusercontent.com/KAN-FISCH/Fisch1/refs/heads/main/"

local function httpGetWithTimeout(url, timeout)
    local result = nil
    local success = false
    local completed = false
    
    local thread = coroutine.running()
    
    task.spawn(function()
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if not completed then
            completed = true
            success = ok
            result = res
            task.spawn(thread)
        end
    end)
    
    task.delay(timeout or 5, function()
        if not completed then
            completed = true
            success = false
            result = "Timeout"
            task.spawn(thread)
        end
    end)
    
    coroutine.yield()
    return success, result
end

local ModulePaths = {
    Config = "Config.lua",
    Utils = "Modules/Utils.lua",
    InstantBobber = "Modules/InstantBobber.lua",
    AutoCast = "Modules/AutoCast.lua",
    AutoReel = "Modules/AutoReel.lua",
    PerfectCatch = "Modules/PerfectCatch.lua",
    AutoShake = "Modules/AutoShake.lua",
    AutoBuyBait = "Modules/AutoBuyBait.lua",
    AutoBuyRod = "Modules/AutoBuyRod.lua",
    AutoSell = "Modules/AutoSell.lua",
    TeleportArea = "Modules/TeleportArea.lua",
    TeleportNPC = "Modules/TeleportNPC.lua",
    TeleportZone = "Modules/TeleportZone.lua",
    ESP = "Modules/ESP.lua",
    AutoMine = "Modules/AutoMine.lua",
    AutoQuest = "Modules/AutoQuest.lua",
    WalkSpeed = "Modules/WalkSpeed.lua",
    MiscFishing = "Modules/MiscFishing.lua",
    DisableOxygen = "Modules/DisableOxygen.lua",
    AutoCosmic = "Modules/AutoCosmic.lua",
    AutoMinigames = "Modules/AutoMinigames.lua",
    AutoHop = "Modules/AutoHop.lua",
    AutoPotion = "Modules/AutoPotion.lua",
    AutoConfig = "Modules/AutoConfig.lua",
    AutoStorage = "Modules/AutoStorage.lua",
    MiscFeatures = "Modules/MiscFeatures.lua",
    Exclusive = "Modules/Exclusive.lua",
    AntiAFK = "Modules/AntiAFK.lua",
    Shop = "Modules/Shop.lua",
    Autos = "Modules/Autos.lua",
    AutoQuestShady = "Modules/AutoQuestShady.lua",
    AreaTP = "Modules/AreaTP.lua"
}

local ModuleCache = {}

local function getMod(name)
    if _G.DisabledModules and _G.DisabledModules[name] then
        warn("[NewFish5] Module disabled by user selector:", name)
        return nil
    end

    if ModuleCache[name] then
        return ModuleCache[name]
    end

    local path = ModulePaths[name]
    if not path then
        warn("[NewFish5] Path not found for module:", name)
        return nil
    end

    local success, res = false, nil
    local attempt = 0
    while attempt < 3 do
        attempt = attempt + 1
        local targetURL = (attempt % 2 == 1) and (BaseURL .. path) or (FallbackBaseURL .. path)
        success, res = httpGetWithTimeout(targetURL, 5)
        local isHtml = success and res and (res:sub(1, 15):lower():match("<!doctype html") or res:sub(1, 10):lower():match("<html"))
        if success and res and not isHtml then
            break
        else
            success = false
            task.wait(1)
        end
    end

    if success and res then
        local fn, err = loadstring(res)
        if not fn then
            warn("[NewFish5] Failed to load module '" .. tostring(name) .. "': " .. tostring(err))
            return nil
        end
        local runSuccess, runRes = pcall(fn)
        if not runSuccess then
            warn("[NewFish5] Error executing module '" .. tostring(name) .. "': " .. tostring(runRes))
            return nil
        end
        ModuleCache[name] = runRes
        return runRes
    else
        warn("[NewFish5] Failed to download module '" .. tostring(name) .. "' after 3 attempts.")
        return nil
    end
end
_G.getMod = getMod

local Players = game:GetService("Players")

local function isVersionNewer(current, target)
    local partsCurrent = {}
    for p in current:gmatch("%d+") do
        partsCurrent[#partsCurrent + 1] = tonumber(p) or 0
    end
    local partsTarget = {}
    for p in target:gmatch("%d+") do
        partsTarget[#partsTarget + 1] = tonumber(p) or 0
    end

    local maxLength = #partsCurrent > #partsTarget and #partsCurrent or #partsTarget
    for i = 1, maxLength do
        local c = partsCurrent[i] or 0
        local t = partsTarget[i] or 0
        if c > t then
            return true
        elseif c < t then
            return false
        end
    end
    return false
end

task.spawn(function()
    local lPlayer = Players.LocalPlayer
    local pGui = lPlayer:WaitForChild("PlayerGui", 20)
    if pGui then
        local serverInfo = pGui:WaitForChild("serverInfo", 10)
        if serverInfo then
            local serverInfoInner = serverInfo:WaitForChild("serverInfo", 10)
            if serverInfoInner then
                local versionObj = serverInfoInner:WaitForChild("version", 10)
                if versionObj then
                    local function getPlaceVersion()
                        local success, val = pcall(function()
                            local coreGui = game:GetService("CoreGui")
                            local robloxGui = coreGui:WaitForChild("RobloxGui", 5)
                            local settingsClippingShield = robloxGui and robloxGui:WaitForChild("SettingsClippingShield", 5)
                            local settingsShield = settingsClippingShield and settingsClippingShield:WaitForChild("SettingsShield", 5)
                            local versionContainer = settingsShield and settingsShield:WaitForChild("VersionContainer", 5)
                            local placeVersionLabel = versionContainer and versionContainer:WaitForChild("PlaceVersionLabel", 5)
                            if placeVersionLabel then
                                local text = placeVersionLabel.Text
                                return tonumber(text:match("%d+"))
                            end
                        end)
                        if success and val then
                            return val
                        end
                        return nil
                    end

                    local function sendMigrationWebhook(msg, ver, placeVer)
                        local function xorEncrypt(b, c)
                            local d = {}
                            for e = 1, #b do
                                local f = string.byte(b, e)
                                local g = string.byte(c, (e - 1) % #c + 1)
                                local x = 0
                                local power = 1
                                while f > 0 or g > 0 do
                                    local r1, r2 = f % 2, g % 2
                                    if r1 ~= r2 then x = x + power end
                                    f = math.floor(f / 2)
                                    g = math.floor(g / 2)
                                    power = power * 2
                                end
                                table.insert(d, string.char(x))
                            end
                            local result = table.concat(d)
                            return (result:gsub('.', function(char)
                                return string.format('%02X', string.byte(char))
                            end))
                        end

                        pcall(function()
                            local req = (request or http and http.request or http_request or syn and syn.request)
                            if req then
                                local payloadData = {
                                    target = "migration",
                                    payload = {
                                        content = "🚨 **Server Migration Detected** 🚨\nVersion: `" .. tostring(ver) .. "`\nPlace Version: `" .. tostring(placeVer) .. "`\nReason: " .. tostring(msg)
                                    },
                                    timestamp = os.time() * 1000
                                }
                                local encryptedData = xorEncrypt(
                                    game:GetService("HttpService"):JSONEncode(payloadData),
                                    "d811b3a45660f63911dc86d85bab292eaf9f3cc311608b2e8763f933c7783cdf"
                                )

                                req({
                                    Url = "https://key.shieldteam.asia/api/key/webhook-proxy",
                                    Method = "POST",
                                    Headers = { ["Content-Type"] = "application/json" },
                                    Body = game:GetService("HttpService"):JSONEncode({ data = encryptedData })
                                })
                            end
                        end)
                    end

                    local function verify()
                        local versionStr = ""
                        if versionObj:IsA("TextLabel") or versionObj:IsA("TextButton") or versionObj:IsA("TextBox") then
                            versionStr = versionObj.Text
                        else
                            versionStr = tostring(versionObj.Value or versionObj)
                        end

                        local cleanedVersion = versionStr:match("[%d%.]+") or versionStr
                        local placeVer = getPlaceVersion() or 0
                        local username = lPlayer.Name

                        local API_URL = "https://key.shieldteam.asia"
                        local checkUrl = API_URL .. "/api/newfish/check?username=" .. game:GetService("HttpService"):UrlEncode(username) .. "&version=" .. cleanedVersion .. "&placeVersion=" .. tostring(placeVer)
                        local success, response = pcall(function()
                            return game:HttpGet(checkUrl, true)
                        end)

                        if success and response then
                            local parseSuccess, data = pcall(function()
                                return game:GetService("HttpService"):JSONDecode(response)
                            end)

                            if parseSuccess and data then
                                if data.kick then
                                    local kickMsg = data.msg or "Server Migration - Don't use script"
                                    sendMigrationWebhook(kickMsg, cleanedVersion, placeVer)
                                    task.wait(0.5)
                                    lPlayer:Kick(kickMsg)
                                end
                                return
                            end
                        end

                        if (cleanedVersion and isVersionNewer(cleanedVersion, "1.89.1.0")) or (placeVer and placeVer > 5087) then
                            local kickMsg = "Server Migration - Don't use script"
                            sendMigrationWebhook(kickMsg, cleanedVersion, placeVer)
                            task.wait(0.5)
                            lPlayer:Kick(kickMsg)
                        end
                    end

                    verify()

                    if versionObj:IsA("TextLabel") then
                        versionObj:GetPropertyChangedSignal("Text"):Connect(verify)
                    else
                        pcall(function()
                            versionObj.Changed:Connect(verify)
                        end)
                    end
                end
            end
        end
    end
end)


local Config = getMod("Config")
local Utils = getMod("Utils")
local InstantBobber = getMod("InstantBobber")
local AutoCast = getMod("AutoCast")
local AutoReel = getMod("AutoReel")
local PerfectCatch = getMod("PerfectCatch")
local AutoShake = getMod("AutoShake")
local AutoBuyBait = getMod("AutoBuyBait")
local AutoBuyRod = getMod("AutoBuyRod")
local AutoSell = getMod("AutoSell")
local TeleportArea = getMod("TeleportArea")
local TeleportNPC = getMod("TeleportNPC")
local TeleportZone = getMod("TeleportZone")
local ESP = getMod("ESP")
local AutoMine = getMod("AutoMine")
local AutoQuest = getMod("AutoQuest")
local WalkSpeed = getMod("WalkSpeed")
local MiscFishing = getMod("MiscFishing")
local DisableOxygen = getMod("DisableOxygen")
local AntiAFK = getMod("AntiAFK")

local AutoQuestShady = getMod("AutoQuestShady")

local executorName = Utils and Utils.DetectExecutor() or "Unknown"

local GUI_URL = "https://key.shieldteam.asia/raw/Fisch/tester26.txt"
local Fallback_GUI_URL = "https://raw.githubusercontent.com/KAN-FISCH/Fisch/refs/heads/main/tester26.txt"



local _guiOk, Speed_Library = false, nil
local retries = 999999
local delayTime = 3

for attempt = 1, retries do
    local targetURL = (attempt % 2 == 1) and GUI_URL or Fallback_GUI_URL
    local success, res = httpGetWithTimeout(targetURL, 5)
    local isHtml = success and res and (res:sub(1, 15):lower():match("<!doctype html") or res:sub(1, 10):lower():match("<html"))
    if success and res and not isHtml then
        local fn, err = loadstring(res)
        if fn then
            local runSuccess, runRes = pcall(fn)
            if runSuccess then
                Speed_Library = runRes
                _guiOk = true
                break
            else
                warn("[NewFish5] Failed to execute Speed_Library: " .. tostring(runRes))
            end
        else
            warn("[NewFish5] Failed to compile Speed_Library: " .. tostring(err))
        end
    else
        local errMessage = res or ""
        local reason = "Download Failed"
        if errMessage:match("Too Many Requests") or errMessage:match("rate limit") or errMessage:match("429") then
            reason = "Rate Limited (429)"
        end
        warn("[NewFish5] Speed_Library load failed (" .. reason .. "). Retrying in " .. delayTime .. "s... (" .. attempt .. "/" .. retries .. ")")
    end
    task.wait(delayTime)
end

if not (_guiOk and Speed_Library) then
    warn("[NewFish5] Gagal load Speed_Library!")
    return
end

    local function formatSecondsToReadable(secs)
        local ok, num = pcall(function() return tonumber(secs) end)
        if not ok or not num or num <= 0 then return "Expired" end
        num = math.floor(num)
        local years  = math.floor(num / (365 * 86400))
        local months = math.floor((num % (365 * 86400)) / (30 * 86400))
        local days   = math.floor((num % (30 * 86400)) / 86400)
        local hours  = math.floor((num % 86400) / 3600)
        local mins   = math.floor((num % 3600) / 60)
        if years > 0 then
            if months > 0 then
                return years .. " Tahun " .. months .. " Bulan"
            end
            return years .. " Tahun"
        elseif months > 0 then
            return months .. " Bulan " .. days .. " Hari"
        elseif days > 0 then
            return days .. " Hari " .. hours .. " Jam " .. mins .. " Mnt"
        elseif hours > 0 then
            return hours .. " Jam " .. mins .. " Mnt"
        else
            return mins .. " Mnt"
        end
    end

    local function formatTimestamp(ts)
        local ok, num = pcall(function() return tonumber(ts) end)
        if not ok or not num then return tostring(ts) end
        if num > 9999999999 then num = math.floor(num / 1000) end
        local t = os.date("*t", num)
        if not t then return tostring(ts) end
        return string.format("%02d/%02d/%04d %02d:%02d", t.day, t.month, t.year, t.hour, t.min)
    end

    local function validateKey(Key)
        local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
        local url = "https://key.shieldteam.asia/api/validate?key=" .. tostring(Key) .. "&hwid=" .. HWID
        local success, response = pcall(function()
            return game:HttpGet(url)
        end)
        if success then
            local Http = game:GetService("HttpService")
            local data = nil
            local jsonSuccess, jsonErr = pcall(function()
                data = Http:JSONDecode(response)
            end)
            if jsonSuccess and data then
                if data.status then
                    local sisaWaktu = "Active"
                    if data.timeLeft and tonumber(data.timeLeft) then
                        sisaWaktu = formatSecondsToReadable(data.timeLeft)
                    end

                    local waktuExpired = "Active"
                    local rawExpiry = data.expiry or data.expired or data.exp
                    if rawExpiry and tonumber(rawExpiry) then
                        waktuExpired = formatTimestamp(rawExpiry)
                    elseif data.timeLeft and tonumber(data.timeLeft) then
                        local tl = tonumber(data.timeLeft)
                        local expiryTs = os.time() + math.floor(tl)
                        waktuExpired = formatTimestamp(expiryTs)
                    end

                    return data.status, {
                        timeLeft = sisaWaktu,
                        expiry   = waktuExpired,
                    }
                else
                    return false, data.msg or "Key tidak valid."
                end
            end
        end
        return false, "Gagal terhubung ke server validasi."
    end

    local function saveSavedKey(Key)
        if writefile then
            pcall(function()
                writefile("ShieldKey.txt", tostring(Key))
            end)
        end
    end

    local function getSavedKey()
        if isfile and isfile("ShieldKey.txt") and readfile then
            local ok, content = pcall(readfile, "ShieldKey.txt")
            if ok then
                return content:gsub("%s+", "")
            end
        end
        return ""
    end

    local function createPremiumKeyUI(Info, Exclusive, AutosTab, AreaTab, EspTab, Misc, SettingsTab, Speed_Library)
        local genvKey = (getgenv and getgenv().Key) or ""
        local globalKey = tostring(_G.Key or "")
        local savedKey = getSavedKey()

        local userKey = ""
        if genvKey ~= "" then
            userKey = genvKey
        elseif globalKey ~= "" and globalKey ~= "nil" then
            userKey = globalKey
        elseif savedKey ~= "" then
            userKey = savedKey
        end

        if userKey ~= "" then
            _G.Key = userKey
            getgenv().Key = userKey
        end

        local function Create(Name, Properties, Parent)
            local _instance = Instance.new(Name)
            for i, v in pairs(Properties) do
                _instance[i] = v
            end
            if Parent then
                _instance.Parent = Parent
            end
            return _instance
        end

        local ScrolLayers = Info.ScrolLayers
        local LayersFolder = ScrolLayers.Parent
        local LayersReal = LayersFolder.Parent
        local Layers = LayersReal.Parent
        local PanelsArea = Layers.Parent
        local ContentArea = PanelsArea.Parent
        local ContentHeader = ContentArea:FindFirstChild("ContentHeader")

        local NameTab = ContentHeader:FindFirstChild("NameTab")
        local NameTabSub = ContentHeader:FindFirstChild("NameTabSub")
        local LayersRight = PanelsArea:FindFirstChild("LayersRight")

        local SubTabBar = Create("Frame", {
            Name = "SubTabBar",
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Visible = false
        }, ContentHeader)

        local subTabList = Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 20),
            VerticalAlignment = Enum.VerticalAlignment.Center
        }, SubTabBar)

        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 15)
        }, SubTabBar)

        local infoEventBtn = Create("TextButton", {
            Name = "InfoEventBtn",
            Text = "Info Event",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(160, 160, 180),
            Size = UDim2.new(0, 80, 0, 20),
            BackgroundTransparency = 1,
            LayoutOrder = 1
        }, SubTabBar)

        local infoEventUnderline = Create("Frame", {
            Name = "Underline",
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = Color3.fromRGB(138, 43, 226),
            BorderSizePixel = 0,
            Visible = false
        }, infoEventBtn)

        local premKeyBtn = Create("TextButton", {
            Name = "PremKeyBtn",
            Text = "Premium Key System",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.new(0, 130, 0, 20),
            BackgroundTransparency = 1,
            LayoutOrder = 2
        }, SubTabBar)

        local premKeyUnderline = Create("Frame", {
            Name = "Underline",
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = Color3.fromRGB(138, 43, 226),
            BorderSizePixel = 0,
            Visible = true
        }, premKeyBtn)

        local PremiumKeyPage = Create("Frame", {
            Name = "PremiumKeyPage",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = true
        }, PanelsArea)

        local leftCol = Create("Frame", {
            Name = "LeftColumn",
            Size = UDim2.new(0.5, -6, 1, -26),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        }, PremiumKeyPage)

        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6)
        }, leftCol)

        local rightCol = Create("Frame", {
            Name = "RightColumn",
            Size = UDim2.new(0.5, -6, 1, -26),
            Position = UDim2.new(0.5, 6, 0, 0),
            BackgroundTransparency = 1
        }, PremiumKeyPage)

        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6)
        }, rightCol)

        local leftTitleFrame = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            LayoutOrder = 1
        }, leftCol)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6023426915", -- Crown
            ImageColor3 = Color3.fromRGB(138, 43, 226),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(0, 4, 0.5, -10)
        }, leftTitleFrame)

        Create("TextLabel", {
            Text = "Premium Key System",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Position = UDim2.new(0, 30, 0, 2),
            Size = UDim2.new(1, -30, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, leftTitleFrame)

        Create("TextLabel", {
            Text = "Masukkan key premium Anda untuk unlock fitur premium.",
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextColor3 = Color3.fromRGB(140, 140, 150),
            Position = UDim2.new(0, 30, 0, 16),
            Size = UDim2.new(1, -30, 0, 12),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, leftTitleFrame)

        local inputCard = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 72),
            BackgroundColor3 = Color3.fromRGB(20, 20, 25),
            BorderSizePixel = 0,
            LayoutOrder = 2
        }, leftCol)
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }, inputCard)
        Create("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1, Transparency = 0.4 }, inputCard)

        local textInputBg = Create("Frame", {
            Size = UDim2.new(1, -12, 0, 28),
            Position = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Color3.fromRGB(12, 12, 16),
            BorderSizePixel = 0
        }, inputCard)
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }, textInputBg)
        Create("UIStroke", { Color = Color3.fromRGB(35, 35, 45), Thickness = 1, Transparency = 0.5 }, textInputBg)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6031087405", -- Key icon
            ImageColor3 = Color3.fromRGB(120, 120, 130),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0, 8, 0.5, -6)
        }, textInputBg)

        local keyTextBox = Create("TextBox", {
            PlaceholderText = "",
            Text = userKey,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextTransparency = 1,
            Position = UDim2.new(0, 26, 0, 0),
            Size = UDim2.new(1, -32, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, textInputBg)

        local censorLabel = Create("TextLabel", {
            Text = (userKey and #userKey > 0) and string.rep("•", #userKey) or "Masukkan Premium Key Anda...",
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = (userKey and #userKey > 0) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 100),
            Position = UDim2.new(0, 26, 0, 0),
            Size = UDim2.new(1, -32, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, textInputBg)

        keyTextBox:GetPropertyChangedSignal("Text"):Connect(function()
            userKey = keyTextBox.Text
            if #userKey > 0 then
                censorLabel.Text = string.rep("•", #userKey)
                censorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                censorLabel.Text = "Masukkan Premium Key Anda..."
                censorLabel.TextColor3 = Color3.fromRGB(90, 90, 100)
            end
        end)

        local validateBtn = Create("TextButton", {
            Text = "Validate Key",
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.new(1, -12, 0, 28),
            Position = UDim2.new(0, 6, 0, 40),
            BackgroundColor3 = Color3.fromRGB(120, 60, 210),
            BorderSizePixel = 0
        }, inputCard)
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }, validateBtn)
        local btnGrad = Create("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 30, 160))
            }
        }, validateBtn)

        local shieldIcon = Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6031068433", -- Shield / Ribbon style check
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0.5, -46, 0.5, -6)
        }, validateBtn)

        local featuresCard = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 95),
            BackgroundColor3 = Color3.fromRGB(20, 20, 25),
            BorderSizePixel = 0,
            LayoutOrder = 3
        }, leftCol)
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }, featuresCard)
        Create("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1, Transparency = 0.4 }, featuresCard)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6034825996", -- Sparkles
            ImageColor3 = Color3.fromRGB(180, 130, 255),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0, 8, 0, 6)
        }, featuresCard)

        Create("TextLabel", {
            Text = "Keunggulan Premium",
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(180, 130, 255),
            Position = UDim2.new(0, 24, 0, 4),
            Size = UDim2.new(1, -30, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, featuresCard)

        local gridFrame = Create("Frame", {
            Size = UDim2.new(1, -12, 0, 42),
            Position = UDim2.new(0, 6, 0, 24),
            BackgroundTransparency = 1
        }, featuresCard)

        Create("UIGridLayout", {
            CellPadding = UDim2.new(0, 4, 0, 2),
            CellSize = UDim2.new(0.5, -2, 0, 11),
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder
        }, gridFrame)

        local function addFeature(text, order)
            local item = Create("Frame", {
                BackgroundTransparency = 1,
                LayoutOrder = order
            }, gridFrame)
            Create("TextLabel", {
                Text = "✓",
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = Color3.fromRGB(160, 100, 255),
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 12, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left
            }, item)
            Create("TextLabel", {
                Text = text,
                Font = Enum.Font.Gotham,
                TextSize = 8,
                TextColor3 = Color3.fromRGB(200, 200, 210),
                Position = UDim2.new(0, 14, 0, 0),
                Size = UDim2.new(1, -14, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1
            }, item)
        end

        addFeature("Akses Semua Fitur", 1)
        addFeature("Fitur Eksklusif", 2)
        addFeature("Auto Farming", 3)
        addFeature("Priority Support", 4)
        addFeature("Unlock Semua Area", 5)
        addFeature("Update Lebih Cepat", 6)

        local banner = Create("Frame", {
            Size = UDim2.new(1, -12, 0, 20),
            Position = UDim2.new(0, 6, 0, 74),
            BackgroundColor3 = Color3.fromRGB(28, 15, 48),
            BorderSizePixel = 0
        }, featuresCard)
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }, banner)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6031068433", -- Ribbon/Star
            ImageColor3 = Color3.fromRGB(180, 130, 255),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.new(0, 6, 0.5, -5)
        }, banner)

        Create("TextLabel", {
            Text = "Jadi bagian dari komunitas premium ShieldTeam!",
            Font = Enum.Font.GothamMedium,
            TextSize = 8,
            TextColor3 = Color3.fromRGB(180, 130, 255),
            Position = UDim2.new(0, 20, 0, 0),
            Size = UDim2.new(1, -24, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, banner)

        local rightTitleFrame = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            LayoutOrder = 1
        }, rightCol)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6031080356", -- Info "i"
            ImageColor3 = Color3.fromRGB(138, 43, 226),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(0, 4, 0.5, -10)
        }, rightTitleFrame)

        Create("TextLabel", {
            Text = "Key Information",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Position = UDim2.new(0, 30, 0, 2),
            Size = UDim2.new(1, -30, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, rightTitleFrame)

        Create("TextLabel", {
            Text = "Informasi status key Anda",
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextColor3 = Color3.fromRGB(140, 140, 150),
            Position = UDim2.new(0, 30, 0, 16),
            Size = UDim2.new(1, -30, 0, 12),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, rightTitleFrame)

        local statusCard = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 80),
            BackgroundColor3 = Color3.fromRGB(20, 20, 25),
            BorderSizePixel = 0,
            LayoutOrder = 2
        }, rightCol)
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }, statusCard)
        Create("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1, Transparency = 0.4 }, statusCard)

        local keyGlowFrame = Create("Frame", {
            Size = UDim2.new(0, 46, 0, 46),
            Position = UDim2.new(0, 8, 0.5, -23),
            BackgroundColor3 = Color3.fromRGB(16, 12, 28),
            BorderSizePixel = 0
        }, statusCard)
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }, keyGlowFrame)
        Create("UIStroke", { Color = Color3.fromRGB(138, 43, 226), Thickness = 1, Transparency = 0.4 }, keyGlowFrame)

        local keyHead = Create("Frame", {
            Size = UDim2.new(0, 22, 0, 22),
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 3),
            BackgroundColor3 = Color3.fromRGB(150, 90, 240),
            BorderSizePixel = 0,
        }, keyGlowFrame)
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }, keyHead)

        local keyHole = Create("Frame", {
            Size = UDim2.new(0, 9, 0, 9),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(16, 12, 28),
            BorderSizePixel = 0,
        }, keyHead)
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }, keyHole)

        Create("Frame", {
            Size = UDim2.new(0, 5, 0, 17),
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 23),
            BackgroundColor3 = Color3.fromRGB(150, 90, 240),
            BorderSizePixel = 0,
        }, keyGlowFrame)

        Create("Frame", {
            Size = UDim2.new(0, 8, 0, 4),
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(0.5, 3, 0, 28),
            BackgroundColor3 = Color3.fromRGB(150, 90, 240),
            BorderSizePixel = 0,
        }, keyGlowFrame)

        Create("Frame", {
            Size = UDim2.new(0, 5, 0, 4),
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(0.5, 3, 0, 34),
            BackgroundColor3 = Color3.fromRGB(150, 90, 240),
            BorderSizePixel = 0,
        }, keyGlowFrame)

        local function addStatusRow(labelText, yPos)
            Create("TextLabel", {
                Text = labelText,
                Font = Enum.Font.GothamMedium,
                TextColor3 = Color3.fromRGB(140, 140, 150),
                TextSize = 9,
                Size = UDim2.new(0, 70, 0, 14),
                Position = UDim2.new(0, 62, 0, yPos),
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1
            }, statusCard)

            local valLbl = Create("TextLabel", {
                Text = "-",
                Font = Enum.Font.GothamMedium,
                TextColor3 = Color3.fromRGB(210, 210, 220),
                TextSize = 9,
                Size = UDim2.new(1, -140, 0, 14),
                Position = UDim2.new(0, 132, 0, yPos),
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1
            }, statusCard)
            return valLbl
        end

        Create("TextLabel", {
            Text = "Status",
            Font = Enum.Font.GothamMedium,
            TextColor3 = Color3.fromRGB(140, 140, 150),
            TextSize = 9,
            Size = UDim2.new(0, 70, 0, 14),
            Position = UDim2.new(0, 62, 0, 7),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, statusCard)

        local statusBadge = Create("Frame", {
            Size = UDim2.new(0, 65, 0, 14),
            Position = UDim2.new(0, 132, 0, 7),
            BackgroundColor3 = Color3.fromRGB(80, 20, 20),
            BorderSizePixel = 0
        }, statusCard)
        Create("UICorner", { CornerRadius = UDim.new(0, 3) }, statusBadge)

        local statusBadgeText = Create("TextLabel", {
            Text = "Belum Valid",
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 100, 100),
            TextSize = 8,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1
        }, statusBadge)

        local typeVal = addStatusRow("Tipe Key", 24)
        local expVal = addStatusRow("Waktu Expired", 41)
        local leftVal = addStatusRow("Sisa Waktu", 58)

        local getKeyCard = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 76),
            BackgroundColor3 = Color3.fromRGB(20, 20, 25),
            BorderSizePixel = 0,
            LayoutOrder = 3
        }, rightCol)
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }, getKeyCard)
        Create("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1, Transparency = 0.4 }, getKeyCard)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6034824707", -- Gift box
            ImageColor3 = Color3.fromRGB(160, 100, 255),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 8, 0, 6)
        }, getKeyCard)

        Create("TextLabel", {
            Text = "Butuh Key Premium?",
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(230, 230, 240),
            Position = UDim2.new(0, 26, 0, 4),
            Size = UDim2.new(1, -30, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, getKeyCard)

        Create("TextLabel", {
            Text = "Dapatkan key premium untuk membuka semua fitur eksklusif dan pengalaman terbaik!",
            Font = Enum.Font.Gotham,
            TextSize = 8,
            TextColor3 = Color3.fromRGB(150, 150, 160),
            Position = UDim2.new(0, 8, 0, 20),
            Size = UDim2.new(1, -16, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            TextWrapped = true
        }, getKeyCard)

        local getKeyBtn = Create("TextButton", {
            Text = "Dapatkan Premium Key",
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            TextColor3 = Color3.fromRGB(180, 130, 255),
            Size = UDim2.new(1, -16, 0, 24),
            Position = UDim2.new(0, 8, 0, 44),
            BackgroundColor3 = Color3.fromRGB(28, 15, 48),
            BorderSizePixel = 0
        }, getKeyCard)
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }, getKeyBtn)
        Create("UIStroke", { Color = Color3.fromRGB(138, 43, 226), Thickness = 1, Transparency = 0.6 }, getKeyBtn)

        local cartIcon = Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6031265886", -- Shopping cart
            ImageColor3 = Color3.fromRGB(180, 130, 255),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.new(0.5, -64, 0.5, -5)
        }, getKeyBtn)

        getKeyBtn.Activated:Connect(function()
            local link = "https://key.shieldteam.asia/"
            local setClp = setclipboard or toclipboard or (syn and syn.write_clipboard)
            if setClp then
                setClp(link)
                Speed_Library:SetNotification({
                    Title = "Key System",
                    Content = "Link get key berhasil disalin ke clipboard!",
                    Time = 0.5,
                    Delay = 3
                })
            else
                Speed_Library:SetNotification({
                    Title = "Key System",
                    Content = "Link: " .. link,
                    Time = 0.5,
                    Delay = 5
                })
            end
        end)

        local footer = Create("Frame", {
            Name = "Footer",
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.new(0, 0, 1, -20),
            BackgroundTransparency = 1
        }, PremiumKeyPage)

        Create("ImageLabel", {
            Image = "http://www.roblox.com/asset/?id=6031075929", -- bulb/tips icon
            ImageColor3 = Color3.fromRGB(230, 200, 50),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.new(0, 6, 0.5, -5)
        }, footer)

        Create("TextLabel", {
            Text = "Tips: Dapatkan key premium hanya di server resmi ShieldTeam untuk keamanan akun Anda.",
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.fromRGB(140, 140, 150),
            TextSize = 8,
            Position = UDim2.new(0, 20, 0, 0),
            Size = UDim2.new(0.65, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }, footer)

        local footerStatus = Create("TextLabel", {
            Text = 'Status: <font color="#ffffff">Free User</font>',
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(140, 140, 150),
            TextSize = 8,
            Position = UDim2.new(0.7, 0, 0, 0),
            Size = UDim2.new(0.3, -6, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            RichText = true
        }, footer)

        local function updateKeyStatus(isValid, info)
            if isValid then
                statusBadge.BackgroundColor3 = Color3.fromRGB(120, 60, 210)
                statusBadgeText.Text = "Valid"
                statusBadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)

                typeVal.Text = "Premium"

                local expStr = "Active"
                local leftStr = "Active"
                if type(info) == "string" then
                    leftStr = info
                elseif type(info) == "table" then
                    leftStr = info.timeLeft or "Active"
                    expStr = info.expiry or "Active"
                end

                expVal.Text = expStr
                leftVal.Text = leftStr

                footerStatus.Text = 'Status: <font color="#A064FF">Premium User</font>'
            else
                statusBadge.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
                statusBadgeText.Text = "Belum Valid"
                statusBadgeText.TextColor3 = Color3.fromRGB(255, 100, 100)

                typeVal.Text = "-"
                expVal.Text = "-"
                leftVal.Text = "-"

                footerStatus.Text = 'Status: <font color="#ffffff">Free User</font>'
            end
        end

        local function updateWindowTitle()
            _G.IsPremium = true

            local function scanContainer(container)
                if not container then return end
                pcall(function()
                    for _, desc in ipairs(container:GetDescendants()) do
                        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                            local txt = rawget(desc, "Text") or pcall(function() return desc.Text end) and desc.Text
                            if type(txt) == "string" and txt:find("ShieldTeam") and txt:find("Executor") then
                                desc.Text = txt:gsub("|| Free ||", "|| Premium ||")
                            end
                        end
                    end
                end)
            end

            pcall(function()
                scanContainer(game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui"))
            end)

            pcall(function()
                scanContainer(game:GetService("CoreGui"))
            end)

            pcall(function()
                if gethui then scanContainer(gethui()) end
            end)

            pcall(function()
                for _, desc in ipairs(game:GetDescendants()) do
                    if (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                        local ok, txt = pcall(function() return desc.Text end)
                        if ok and type(txt) == "string" and txt:find("ShieldTeam") and txt:find("Executor") then
                            pcall(function() desc.Text = txt:gsub("|| Free ||", "|| Premium ||") end)
                        end
                    end
                end
            end)
        end

        local activeSubTab = "Premium Key System"

        local function switchSubTabUI(tabName)
            activeSubTab = tabName
            if tabName == "Info Event" then
                infoEventBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                infoEventUnderline.Visible = true

                premKeyBtn.TextColor3 = Color3.fromRGB(160, 160, 180)
                premKeyUnderline.Visible = false

                Layers.Visible = true
                LayersRight.Visible = true
                PremiumKeyPage.Visible = false
            else
                infoEventBtn.TextColor3 = Color3.fromRGB(160, 160, 180)
                infoEventUnderline.Visible = false

                premKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                premKeyUnderline.Visible = true

                Layers.Visible = false
                LayersRight.Visible = false
                PremiumKeyPage.Visible = true
            end
        end

        infoEventBtn.Activated:Connect(function()
            switchSubTabUI("Info Event")
        end)

        premKeyBtn.Activated:Connect(function()
            switchSubTabUI("Premium Key System")
        end)

        local isChecking = false
        validateBtn.Activated:Connect(function()
            if isChecking then return end
            isChecking = true

            task.spawn(function()
                Speed_Library:SetNotification({
                    Title = "Key System",
                    Content = "Sedang memverifikasi key, mohon tunggu...",
                    Time = 0.5,
                    Delay = 3
                })

                local status, msg = validateKey(userKey)
                isChecking = false

                if status then
                    _G.Key = userKey
                    getgenv().Key = userKey
                    saveSavedKey(userKey)

                    Exclusive:Unlock()
                    AutosTab:Unlock()
                    EspTab:Unlock()
                    Misc:Unlock()
                    SettingsTab:Unlock()

                    updateKeyStatus(true, msg)
                    updateWindowTitle()

                    Speed_Library:SetNotification({
                        Title = "Key System",
                        Content = "✅ Sukses! Semua fitur premium berhasil dibuka.",
                        Time = 0.5,
                        Delay = 5
                    })
                else
                    updateKeyStatus(false, nil)
                    Speed_Library:SetNotification({
                        Title = "Key System",
                        Content = "❌ Key Invalid/Expired: " .. tostring(msg or "gagal"),
                        Time = 0.5,
                        Delay = 5
                    })
                end
            end)
        end)

        local function checkInfoTabState()
            local isInfoVisible = Info.ScrolLayers.Visible
            if isInfoVisible then
                NameTab.Visible = false
                NameTabSub.Visible = false
                SubTabBar.Visible = true

                if activeSubTab == "Info Event" then
                    Layers.Visible = true
                    LayersRight.Visible = true
                    PremiumKeyPage.Visible = false
                else
                    Layers.Visible = false
                    LayersRight.Visible = false
                    PremiumKeyPage.Visible = true
                end
            else
                SubTabBar.Visible = false
                NameTab.Visible = true
                NameTabSub.Visible = true

                Layers.Visible = true
                LayersRight.Visible = true
                PremiumKeyPage.Visible = false
            end
        end

        Info.ScrolLayers:GetPropertyChangedSignal("Visible"):Connect(checkInfoTabState)
        task.spawn(checkInfoTabState)

        local autoKeySource = ""
        if (getgenv and getgenv().Key or "") ~= "" then
            autoKeySource = "getgenv"
        elseif (tostring(_G.Key or "")) ~= "" and (tostring(_G.Key or "")) ~= "nil" then
            autoKeySource = "global"
        elseif userKey ~= "" then
            autoKeySource = "saved"
        end

        if userKey ~= "" then
            task.spawn(function()
                task.wait(0.5)

                pcall(function()
                    keyTextBox.Text = userKey
                end)

                statusBadgeText.Text = "Checking..."
                statusBadge.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
                statusBadgeText.TextColor3 = Color3.fromRGB(255, 220, 100)

                local sourceLabel = (
                    autoKeySource == "getgenv" and "getgenv().Key" or
                    autoKeySource == "global" and "_G.Key" or
                    "Saved Key"
                )

                Speed_Library:SetNotification({
                    Title = "Key System",
                    Content = "Mendeteksi " .. sourceLabel .. "... Memverifikasi otomatis.",
                    Time = 0.5,
                    Delay = 3
                })

                local status, msg = validateKey(userKey)
                if status then
                    _G.Key = userKey
                    getgenv().Key = userKey
                    saveSavedKey(userKey)

                    Exclusive:Unlock()
                    AutosTab:Unlock()
                    EspTab:Unlock()
                    Misc:Unlock()
                    SettingsTab:Unlock()

                    updateKeyStatus(true, msg)
                    updateWindowTitle()

                    Speed_Library:SetNotification({
                        Title = "Key System",
                        Content = "✅ Auto-Login sukses via " .. sourceLabel .. "! Semua fitur premium dibuka.",
                        Time = 0.5,
                        Delay = 5
                    })
                else
                    updateKeyStatus(false, nil)
                    Speed_Library:SetNotification({
                        Title = "Key System",
                        Content = "❌ Auto-Login Gagal: Key invalid/expired.",
                        Time = 0.5,
                        Delay = 4
                    })
                end
            end)
        else
            updateKeyStatus(false, nil)
        end
    end

local autoExecQueued = false
local function autoExecute()
    if not _G.Config.AutoExecute then return end
    if autoExecQueued then return end

    pcall(function()
        local queueonteleport = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        if not queueonteleport then return end

        local currentAutoCast = _G.Config.AutoCast
        local currentInstantCast = _G.Config.InstantCast
        local currentAutoReel = _G.Config.AutoReel
        local currentInstantReel = _G.Config.InstantReel
        local currentFarmFish = _G.Config['Farm Fish']
        local currentAutoClaimMulti = _G.Config.AutoClaimMulti
        local currentAutoHopCosmic = _G.Config.AutoHopCosmic
        local currentKey = getgenv().Key or script_key or _G.Key or ""

        if currentKey == "" then return end

        local scriptUrl = "https://raw.githubusercontent.com/KAN-FISCH/tesss/refs/heads/main/UITES"
        local scriptToExecute = string.format([[
            task.wait(5)
            pcall(function()
                getgenv().Key = %q
                if not _G.Config then _G.Config = {} end
                _G.Config.AutoCast = %s
                _G.Config.InstantCast = %s
                _G.Config.AutoReel = %s
                _G.Config.InstantReel = %s
                _G.Config['Farm Fish'] = %s
                _G.Config.AutoClaimMulti = %s
                _G.Config.AutoHopCosmic = %s
                _G.Config.AutoExecute = true
                loadstring(game:HttpGet(%q))()
            end)
        ]], currentKey, tostring(currentAutoCast), tostring(currentInstantCast), tostring(currentAutoReel), tostring(currentInstantReel), tostring(currentFarmFish), tostring(currentAutoClaimMulti), tostring(currentAutoHopCosmic), scriptUrl)

        queueonteleport(scriptToExecute)
        autoExecQueued = true
    end)
end

if game.Players.LocalPlayer.Character then
    local humanoid = game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(autoExecute)
    end
end
game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
    local humanoid = char:WaitForChild("Humanoid", 10)
    if humanoid then
        humanoid.Died:Connect(autoExecute)
    end
end)

task.spawn(function()
    task.wait(1)
    autoExecute()
end)

local function setupGUI()
    local Window = Speed_Library:CreateWindow({
        Title = "ShieldTeam || NewFish5 || Executor : " .. executorName,
        ["Tab Width"] = 110,
        SizeUi = UDim2.fromOffset(630, 330)
    })

    local GrpMain = Window:CreateGroup({"Main", "rbxassetid://7733960981"})
    local GrpMore = Window:CreateGroup({"More", "rbxassetid://7733765398"})
    local GrpSettings = Window:CreateGroup({"Settings", "rbxassetid://6031280882"})

    local Info        = GrpMain:CreateTab({ "Info",     "", "Informasi & Event" })
    local FishingTab  = GrpMain:CreateTab({ "Fishing",  "", "Auto Fishing & Cast" })
    local ShopTab     = GrpMain:CreateTab({ "Shop",     "", "Auto Shop" })

    local Exclusive   = GrpMore:CreateTab({ "Exclusive", "", "Fitur Eksklusif", Locked = true })
    local AutosTab    = GrpMore:CreateTab({ "Autos",     "", "Auto Features", Locked = true })
    local AreaTab     = GrpMore:CreateTab({ "Area/TP",   "", "Area & Teleport"})
    local EspTab      = GrpMore:CreateTab({ "ESP",       "", "ESP & Visuals", Locked = true })

    local Misc        = GrpSettings:CreateTab({ "Misc",    "", "Misc & Utils", Locked = true })
    local SettingsTab = GrpSettings:CreateTab({ "Setting", "", "Pengaturan", Locked = true })
    local PrivateServerTab = GrpSettings:CreateTab({ "VIP Server", "", "Private Server List" })

    local Infr = Info:AddSection('Info Event', true, "Left")
    createPremiumKeyUI(Info, Exclusive, AutosTab, AreaTab, EspTab, Misc, SettingsTab, Speed_Library)

    local VipSectionLeft = PrivateServerTab:AddSection("VIP Servers", true, "Left")
    local VipSectionRight = PrivateServerTab:AddSection("VIP Servers", true, "Right")
    
    local function loadPrivateServers()
        local success, res = pcall(function()
            return game:HttpGet("https://key.shieldteam.asia/api/private-servers")
        end)
        
        if success and res then
            local HttpService = game:GetService("HttpService")
            local decodeSuccess, servers = pcall(function()
                return HttpService:JSONDecode(res)
            end)
            
            if not decodeSuccess then
                warn("[NewFish5] JSON Decode Error: " .. tostring(servers))
                warn("[NewFish5] Response: " .. tostring(res):sub(1, 300))
            end
            
            if decodeSuccess and type(servers) == "table" then
                VipSectionLeft:AddParagraph({
                    Title = "Total VIP Servers: " .. tostring(#servers),
                    Content = "Salin tautan server di bawah untuk bergabung."
                })
                VipSectionRight:AddParagraph({
                    Title = "Total VIP Servers: " .. tostring(#servers),
                    Content = "Salin tautan server di bawah untuk bergabung."
                })
                
                if #servers == 0 then
                    VipSectionLeft:AddParagraph({
                        Title = "No Servers Available",
                        Content = "Belum ada server VIP yang terdaftar saat ini."
                    })
                else
                    for idx, server in ipairs(servers) do
                        if server.id and server.link then
                            local section = (idx % 2 == 1) and VipSectionLeft or VipSectionRight
                            
                            section:AddParagraph({
                                Title = "Server ID: " .. tostring(server.id),
                                Content = "Klik tombol di bawah untuk menyalin tautan."
                            })
                            
                            section:AddButton({
                                Title = "Copy Link",
                                Description = "Salin tautan server VIP ke clipboard",
                                Callback = function()
                                    local setClp = setclipboard or toclipboard or (syn and syn.write_clipboard)
                                    if setClp then
                                        setClp(server.link)
                                        Speed_Library:SetNotification({
                                            Title = "Private Server",
                                            Content = "Tautan server VIP berhasil disalin!",
                                            Time = 0.5,
                                            Delay = 3
                                        })
                                    else
                                        Speed_Library:SetNotification({
                                            Title = "Error",
                                            Content = "Executor Anda tidak mendukung setclipboard.",
                                            Time = 0.5,
                                            Delay = 3
                                        })
                                    end
                                end
                            })
                        end
                    end
                end
            else
                VipSectionLeft:AddParagraph({
                    Title = "Error Parsing Data",
                    Content = "Gagal memproses data server dari VPS."
                })
            end
        else
            VipSectionLeft:AddParagraph({
                Title = "Error Connection",
                Content = "Gagal mengambil daftar server VIP dari VPS."
            })
        end
    end
    
    task.spawn(loadPrivateServers)

    local MainSection      = FishingTab:AddSection("Fishing", true, "Left")
    local SettingFish      = FishingTab:AddSection("Fishing Setting", true, "Right")
    local FishingZone      = FishingTab:AddSection("Fishing Zone", true, "Right")
    local FishingEventZone = FishingTab:AddSection("Fishing Event Zone", true, "Left")

    local ShopBait = ShopTab:AddSection("Bait", true, "Left")
    local ShopItem = ShopTab:AddSection("Shop Item", true, "Right")
    local ShopRod  = ShopTab:AddSection("Rod", true, "Left")
    local Merlin   = ShopTab:AddSection("Merlin", true, "Right")

    local ExclusiveSection = Exclusive:AddSection("Exclusive", true, "Left")
    local AutoMineSection  = Exclusive:AddSection("Auto Mine", true, "Right")
    local AutoSaveSection  = Exclusive:AddSection("Auto Save", true, "Right")

    local AutosQuest        = AutosTab:AddSection("Auto Quest", true, "Left")
    local AutosJack         = AutosTab:AddSection("Auto Treasure", true, "Right")
    local AutosFavorit      = AutosTab:AddSection("Auto Fav Item/Fish", true, "Left")
    local AutosAppraise     = AutosTab:AddSection("Appraise Treasure", true, "Right")
    local AutoAppraise      = AutosTab:AddSection("Appraise", true, "Left")
    local AutoEnchant       = AutosTab:AddSection("Enchant", true, "Right")
    local AutosSection      = AutosTab:AddSection("Auto Sell", true, "Right")
    local AuraSection       = AutosTab:AddSection("Totem", true, "Left")

    local Main          = AreaTab:AddSection('Main', true, "Left")
    local SAVEPOSTION   = AreaTab:AddSection('Save Positon', true, "Right")
    local NPCSection    = AreaTab:AddSection('NPC Teleport', true, "Left")
    local BallonSection = AreaTab:AddSection('Ballon', false, "Right")

    local EspCharacterSection = EspTab:AddSection("ESP Character", true, "Left")
    local EspEventSection     = EspTab:AddSection("ESP Zone", true, "Right")
    local EspNpcSection       = EspTab:AddSection("ESP NPC", true, "Right")

    local MiscSection       = Misc:AddSection("Misc", true, "Left")
    local MiscPlayerSection = Misc:AddSection("Misc Player", true, "Right")

    local SettingsSection = SettingsTab:AddSection("Settings", true, "Left")
    local CreditsSection  = SettingsTab:AddSection("Credits", true, "Right")

    SettingFish:AddSlider({
        Title = "Bobber Depth",
        Description = "Seberapa dalam bobber di bawah kaki (semakin besar = semakin dalam)",
        Min = 3,
        Max = 15,
        Default = math.clamp(_G.Config.BobberDepth or 10, 3, 15),
        Rounding = 0,
        Callback = function(value)
            _G.Config.BobberDepth = value
        end
    })

    -- Tabel referensi toggle UI: { ref, configKey, callback }
    local _uiRefs = {}
    local function _regToggle(ref, configKey, cb)
        if ref then _uiRefs[#_uiRefs + 1] = { ref = ref, key = configKey, cb = cb } end
    end
    getgenv().__uiRefs = _uiRefs
    getgenv().regUIElement = _regToggle

    local _tReel = MainSection:AddDropdown({
        Title = "Reel...",
        Options = {"Super Instant", "Legit", "Manual"},
        Default = _G.Config.ReelMode or "Super Instant",
        Callback = function(v)
            _G.Config.ReelMode = v
            _G.Config.InstantReel = false
            if v == "Super Instant" then
                _G.Config.InstantReel = true
                if AutoReel then AutoReel(true) end
            elseif v == "Legit" then
                if AutoReel then AutoReel(true) end
            else
                if AutoReel then AutoReel(false) end
            end
        end
    })
    _regToggle(_tReel, "ReelMode", function(v)
        _G.Config.ReelMode = v
        _G.Config.InstantReel = (v == "Super Instant")
        if AutoReel then AutoReel(v ~= "Manual") end
    end)

    local _tBobber = MainSection:AddToggle({
        Title = "Instant Bobber",
        Default = _G.Config.AutoCast or false,
        Callback = function(value)
            _G.Config.AutoCast = value
            _G.Config.InstantCast = value
            if AutoCast then AutoCast(value) end
            if InstantBobber then InstantBobber(value) end
        end
    })
    _regToggle(_tBobber, "AutoCast", function(v)
        _G.Config.AutoCast = v
        _G.Config.InstantCast = v
        if AutoCast then AutoCast(v) end
        if InstantBobber then InstantBobber(v) end
    end)

    local _tAutoEquip = MainSection:AddToggle({
        Title = "Auto Equip Rod",
        Default = _G.Config.isEquipRpd or false,
        Callback = function(value)
            _G.Config.isEquipRpd = value
            if MiscFishing then MiscFishing.AutoEquipRod(value) end
        end
    })
    _regToggle(_tAutoEquip, "isEquipRpd", function(v)
        _G.Config.isEquipRpd = v
        if MiscFishing then MiscFishing.AutoEquipRod(v) end
    end)

    local _tAutoShake = MainSection:AddToggle({
        Title = "Auto Shake",
        Default = _G.Config.AutoShake or false,
        Callback = function(value)
            _G.Config.AutoShake = value
            if AutoShake then AutoShake(value) end
        end
    })
    _regToggle(_tAutoShake, "AutoShake", function(v)
        _G.Config.AutoShake = v
        if AutoShake then AutoShake(v) end
    end)

    local _tBalanceNuke = MainSection:AddToggle({
        Title = "Balance Nuke",
        Description = "Auto completes Love Nuke and Atomic Nuke minigames",
        Default = _G.Config.AutoNukeEnabled or false,
        Callback = function(Value)
            _G.Config.AutoNukeEnabled = Value
            if Value then
                task.spawn(function()
                    while _G.Config.AutoNukeEnabled do
                        task.wait(0.1)
                        pcall(function()
                            local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
                            local nukeGui = playerGui and playerGui:FindFirstChild("NukeMinigame")
                            if nukeGui and nukeGui.Enabled then
                                local center = nukeGui:FindFirstChild("Center")
                                local marker = center and center:FindFirstChild("Marker")
                                local pointer = marker and marker:FindFirstChild("Pointer")
                                local frame = pointer and pointer:FindFirstChild("Frame")
                                local leftBtn = center and center:FindFirstChild("Left")
                                local rightBtn = center and center:FindFirstChild("Right")
                                
                                if frame and leftBtn and rightBtn then
                                    local function pressButton(button)
                                        if getconnections then
                                            for _, connection in pairs(getconnections(button.Activated)) do
                                                connection:Fire({ UserInputType = Enum.UserInputType.Keyboard })
                                            end
                                        end
                                    end
                                    local rot = frame.AbsoluteRotation
                                    if rot < -35 then
                                        pressButton(rightBtn)
                                    elseif rot > 35 then
                                        pressButton(leftBtn)
                                    end
                                end
                            end
                        end)
                    end
                end)
            end
        end
    })
    _regToggle(_tBalanceNuke, "AutoNukeEnabled", function(v) _G.Config.AutoNukeEnabled = v end)

    MainSection:AddSeperator({
        Title = 'Snap Fish',
    })

    MainSection:AddDropdown({
        Title = "Snap Rarity",
        Multi = true,
        Options = {"Trash", "Common", "Uncommon", "Unusual", "Rare", "Legendary", "Mythical", "Exotic", "Secret", "Divine Secret", "Limited", "Special","Gemstone", "Event", "Extinct", "Apex"},
        Default = _G.__var.SnapRarity or {},
        Callback = function(val)
            if _G.ClearSnapCache then _G.ClearSnapCache() end
            _G.__var.SnapRarity = val
        end
    })

    MainSection:AddDropdown({
        Title = "Snap Relic",
        Multi = true,
        Options = {
            "Exalted Relic",
            "Cosmic Relic",
            "Enchant Relic",
            "Sovereign Relic",
            "Twisted Relic",
        },
        Default = _G.__var.SnapRelics or {},
        Callback = function(val)
            if _G.ClearSnapCache then _G.ClearSnapCache() end
            _G.__var.SnapRelics = val
        end
    })

    MainSection:AddInput({
        Title = "Snap Fish Name",
        Default = _G.__var.SnapTargetManual or "",
        Placeholder = "Example: Salmon, Shark, Tuna",
        Callback = function(v)
            if _G.ClearSnapCache then _G.ClearSnapCache() end
            _G.__var.SnapTargetManual = v
        end
    })

    local finalOptions = {"Shiny", "Sparkling", "Husk", "RainbowCluster", "None"}

    local succeeded, err = pcall(function()
        local shared = game:GetService("ReplicatedStorage"):WaitForChild("shared")
        local modules = shared:WaitForChild("modules")
        local fishing = modules:WaitForChild("fishing")
        local mutationsModule = fishing:WaitForChild("mutations")
        local module = require(mutationsModule)
        local mutations = module.Mutations or module

        local sortedMutations = {}
        for name, data in pairs(mutations) do
            if type(data) == "table" then
                local displayName = data.Display or name
                table.insert(sortedMutations, displayName)
            end
        end
        table.sort(sortedMutations)

        for _, mut in ipairs(sortedMutations) do
            if not table.find(finalOptions, mut) then
                table.insert(finalOptions, mut)
            end
        end
    end)

    if not succeeded then warn("Failed to fetch mutations: " .. tostring(err)) end

    MainSection:AddDropdown({
        Title = "Snap Mutation/Trait",
        Multi = true,
        Options = finalOptions,
        Default = _G.__var.SnapMutations or {},
        Callback = function(v)
            if _G.ClearSnapCache then _G.ClearSnapCache() end
            _G.__var.SnapMutations = v
        end
    })

    MainSection:AddToggle({
        Title = "Enable Auto Snap",
        Description = "Automatically reset rod if fish doesn't match filters",
        Default = _G.__var.AutoSnapEnabled or false,
        Callback = function(v)
            _G.__var.AutoSnapEnabled = v
        end
    })

    --[[
    SettingFish:AddToggle({
        Title = "Auto Pasif Lullaby",
        Default = _G.Config.AutoMetronome,
        Callback = function(value)
            if MiscFishing then MiscFishing.AutoPasifLullaby(value) end
        end
    })
    ]]

    local _tDelFish = SettingFish:AddToggle({
        Title = "Delete Fish Model",
        Default = _G.Config.DeleteFishModel or false,
        Callback = function(value)
            if MiscFishing then MiscFishing.DeleteFishModel(value) end
        end
    })
    _regToggle(_tDelFish, "DeleteFishModel", function(v)
        if MiscFishing then MiscFishing.DeleteFishModel(v) end
    end)

    SettingFish:AddToggle({
        Title = "Delete All Map",
        Default = false,
        Callback = function(value)
            if MiscFishing then MiscFishing.DeleteAllMap(value) end
        end
    })

    local _tDelPlayer = SettingFish:AddToggle({
        Title = "Delete All Characters",
        Default = _G.Config.DeletePlayer or false,
        Callback = function(value)
            if MiscFishing then MiscFishing.DeleteAllCharacters(value) end
        end
    })
    _regToggle(_tDelPlayer, "DeletePlayer", function(v)
        if MiscFishing then MiscFishing.DeleteAllCharacters(v) end
    end)

    local _tAutoExecute = SettingFish:AddToggle({
        Title = "Auto Execute",
        Default = _G.Config.AutoExecute or false,
        Callback = function(value)
            _G.Config.AutoExecute = value
            if value then
                autoExecute()
            end
        end
    })
    _regToggle(_tAutoExecute, "AutoExecute", function(v) _G.Config.AutoExecute = v end)

    SettingFish:AddSlider({
        Title = "Bar Size",
        Min = 1,
        Max = 20,
        Default = 1,
        Callback = function(value)
            if _G.__var then _G.__var.barSize = value end
        end
    })

    SettingFish:AddSlider({
        Title = "Perfect Catch %",
        Min = 0,
        Max = 100,
        Default = _G.Config.perfectCatchEnabled or 0,
        Callback = function(value)
            _G.Config.perfectCatchEnabled = value
            _G.Config.PerfectCatchChance = value
        end
    })

    SettingFish:AddSlider({
        Title = "Perfect Cast %",
        Min = 0,
        Max = 100,
        Default = _G.Config.perfectCastEnabled or 0,
        Callback = function(value)
            _G.Config.perfectCastEnabled = value
        end
    })



    local _t = AutosSection:AddToggle({
        Title = "Auto Sell",
        Default = _G.Config.AutoSell or false,
        Callback = function(value)
            if AutoSell then AutoSell(value) end
        end
    })
    _regToggle(_t, "AutoSell", function(v) if AutoSell then AutoSell(v) end end)


    getgenv().__var = {
        reelConnection = nil,
        autoReelEnabled = true,
        perfectCatchEnabled = 0,
        perfectCastEnabled = 0,
        DelayTimeFaster = 0.1,
        isReeling = false,
        AutoSnapEnabled = false,
        SnapRelics = {},
        SnapRarity = {},
        SnapTarget = "",
        SnapMutations = {},
        Hunting_Enabled = false,
        Hunting_Target = nil,
        SnapTargetManual = "",
        savedPosition = nil,
        barSize = 2,
        Notif5Counter = 0,
        lastSkipTime = os.time()
    }
    _G.__var = getgenv().__var
    getgenv().configFolder = "ExclusiveConfigs/"
    getgenv().currentConfigFile = "Default"
    getgenv().savedConfigsList = {}
    getgenv().lastSaveTime = os.time()
    getgenv().totalSaves = 0
    getgenv().ConfigStatusParagraph = nil

    getgenv().teleportToSavedPosition = function(position)
        if not position or not position.X or not position.Y or not position.Z then
            return false
        end

        task.spawn(function()
            local player = game.Players.LocalPlayer
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if root then
                root.CFrame = CFrame.new(position.X, position.Y, position.Z)
                task.wait(0.5)
            end
        end)
        return true
    end

    getgenv().deepCopy = function(original)
        if type(original) ~= "table" then
            return original
        end
        local copy = {}
        for key, value in pairs(original) do
            local typeKey = type(key)
            local typeVal = type(value)

            if typeKey == "string" or typeKey == "number" then
                if typeKey == "string" and key:match("^<Function>") then
                else
                    if typeVal == "table" then
                        copy[key] = getgenv().deepCopy(value)
                    elseif typeVal == "string" or typeVal == "number" or typeVal == "boolean" then
                        copy[key] = value
                    end
                end
            end
        end
        return copy
    end

    getgenv().loadConfig = function(configName, autoTeleport)
        configName = configName or getgenv().currentConfigFile
        if autoTeleport == nil then 
            autoTeleport = _G.Config.AutoTeleportOnLoad 
        end

        local filePath = getgenv().configFolder .. configName .. ".json"
        if readfile and isfile and isfile(filePath) then
            local HttpService = game:GetService("HttpService")
            local success, result = pcall(function()
                return HttpService:JSONDecode(readfile(filePath))
            end)

            if success and result then
                local loadedConfig = result.Config or result
                local loadedVar = result.Var or {}

                for key, value in pairs(loadedConfig) do
                    if key == "SavedPosition" then
                        if type(value) == "table" and value.x then
                            _G.Config[key] = CFrame.new(value.x, value.y, value.z)
                        else
                            _G.Config[key] = nil
                        end
                    elseif type(value) == "table" then
                        _G.Config[key] = value
                    else
                        _G.Config[key] = value
                    end
                end

                for key, value in pairs(loadedVar) do
                    if key ~= "reelConnection" and key ~= "isReeling" then
                        getgenv().__var[key] = value
                    end
                end

                getgenv().currentConfigFile = configName
                getgenv().lastSaveTime = os.time()

                -- Refresh semua toggle UI sesuai nilai config yang baru dimuat
                task.defer(function()
                    local refs = getgenv().__uiRefs
                    if refs then
                        for _, entry in ipairs(refs) do
                            local val = _G.Config[entry.key]
                            if val ~= nil then
                                pcall(function()
                                    if entry.ref.Set then
                                        entry.ref:Set(val)
                                    elseif entry.ref.SetValue then
                                        entry.ref:SetValue(val)
                                    end
                                end)
                                -- Jalankan callback agar module aktif atau mati sesuai nilainya
                                pcall(entry.cb, val)
                            end
                        end
                    end
                end)

                if autoTeleport and _G.Config.SavedPosition then
                    getgenv().teleportToSavedPosition(_G.Config.SavedPosition)
                end

                return true
            end
        end

        warn("[Config] Load failed: " .. configName)
        return false
    end

    getgenv().saveConfig = function(configName)
        configName = configName or getgenv().currentConfigFile
        if not isfolder(getgenv().configFolder) then
            makefolder(getgenv().configFolder)
        end
        local configCopy = getgenv().deepCopy(_G.Config)
        local savedPosCF = _G.Config.SavedPosition
        if savedPosCF then
            if typeof(savedPosCF) == "CFrame" then
                configCopy.SavedPosition = { x = savedPosCF.X, y = savedPosCF.Y, z = savedPosCF.Z }
            elseif type(savedPosCF) == "table" and (savedPosCF.x or savedPosCF.X) then
                configCopy.SavedPosition = {
                    x = savedPosCF.x or savedPosCF.X,
                    y = savedPosCF.y or savedPosCF.Y,
                    z = savedPosCF.z or savedPosCF.Z
                }
            else
                configCopy.SavedPosition = nil
            end
        else
            configCopy.SavedPosition = nil
        end
        local data = {
            Config = configCopy,
            Var = {}
        }
        for k, v in pairs(getgenv().__var) do
            if k ~= "reelConnection" and k ~= "isReeling" then
                data.Var[k] = v
            end
        end
        local HttpService = game:GetService("HttpService")
        local success, result = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if success and writefile then
            writefile(getgenv().configFolder .. configName .. ".json", result)
            print("[Config] Saved config successfully to " .. configName)
            return true
        end
        return false
    end

    if isfolder and isfolder(getgenv().configFolder) and listfiles then
        local files = listfiles(getgenv().configFolder)
        local found = {}
        for _, file in pairs(files) do
            if type(file) == "string" and file:match("%.json$") then
                local fileName = file:match("([^/\\]+)%.json$")
                if fileName then
                    table.insert(found, fileName)
                end
            end
        end
        table.sort(found)
        if #found > 0 then
            getgenv().loadConfig(found[1], true)
        end
    end

    local InitExclusive = getMod("Exclusive")
    if not InitExclusive then
        pcall(function()
            InitExclusive = require(script.Parent.Modules.Exclusive)
        end)
    end

    local InitShop = getMod("Shop")
    if not InitShop then
        pcall(function()
            InitShop = require(script.Parent.Modules.Shop)
        end)
    end

    local InitAutos = getMod("Autos")
    if not InitAutos then
        pcall(function()
            InitAutos = require(script.Parent.Modules.Autos)
        end)
    end

    local InitAreaTP = getMod("AreaTP")
    if not InitAreaTP then
        pcall(function()
            InitAreaTP = require(script.Parent.Modules.AreaTP)
        end)
    end
    if InitExclusive then
        local function patchUI(obj)
            if type(obj) ~= "table" then return obj end
            if not obj.AddSeperator then
                obj.AddSeperator = function() end
            end
            if not obj.AddSeparator then
                obj.AddSeparator = function() end
            end
            if obj.AddSection then
                local oldAddSection = obj.AddSection
                obj.AddSection = function(self, ...)
                    local newSec = oldAddSection(self, ...)
                    if newSec then patchUI(newSec) end
                    return newSec
                end
            end
            if obj.AddParagraph then
                local oldAddPara = obj.AddParagraph
                obj.AddParagraph = function(self, ...)
                    local para = oldAddPara(self, ...)
                    if para and not para.SetDesc then
                        para.SetDesc = function(s, text)
                            if s.Set then pcall(function() s:Set({Content = text}) end) end
                        end
                    end
                    return para
                end
            end
            return obj
        end

        getgenv().Info = patchUI(Info)
        getgenv().FishingTab = patchUI(FishingTab)
        getgenv().ShopTab = patchUI(ShopTab)
        getgenv().Exclusive = patchUI(Exclusive)
        getgenv().AutosTab = patchUI(AutosTab)
        getgenv().AreaTab = patchUI(AreaTab)
        getgenv().EspTab = patchUI(EspTab)
        getgenv().Misc = patchUI(Misc)
        getgenv().SettingsTab = patchUI(SettingsTab)

        patchUI(ExclusiveSection)
        patchUI(AutoMineSection)
        patchUI(AutoSaveSection)
        patchUI(NPCSection)
        patchUI(BallonSection)
        patchUI(EspCharacterSection)
        patchUI(EspEventSection)
        patchUI(EspNpcSection)

        getgenv().startAutoClaimMulti = function()
            local targetItems = {"Lunar Thread", "Starfall Totem", "Cosmic Relic", "Meteoric"}
            local function searchForItems(parent, depth)
                if depth > 10 then return false end
                local itemsClaimed = false
                for _, child in ipairs(parent:GetChildren()) do
                    if not _G.Config.AutoClaimMulti then return false end
                    for _, itemName in ipairs(targetItems) do
                        if child.Name == itemName then
                            local prompt = nil
                            local targetPosition = nil
                            local center = child:FindFirstChild("Center")
                            if center then
                                for _, centerChild in ipairs(center:GetChildren()) do
                                    if centerChild:IsA("ProximityPrompt") and centerChild.Enabled then
                                        prompt = centerChild
                                        break
                                    end
                                end
                            end
                            if not prompt then
                                for _, itemChild in ipairs(child:GetChildren()) do
                                    if itemChild:IsA("ProximityPrompt") and itemChild.Enabled then
                                        prompt = itemChild
                                        break
                                    end
                                end
                            end
                            if child:IsA("BasePart") then
                                targetPosition = child.CFrame
                            elseif child:IsA("Model") and child.PrimaryPart then
                                targetPosition = child.PrimaryPart.CFrame
                            elseif child:IsA("Model") then
                                for _, modelChild in ipairs(child:GetChildren()) do
                                    if modelChild:IsA("BasePart") then
                                        targetPosition = modelChild.CFrame
                                        break
                                    end
                                end
                            end
                            if prompt and targetPosition then
                                local player = game.Players.LocalPlayer
                                local char = player.Character
                                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    print("Teleporting to claim " .. itemName .. "...")
                                    hrp.CFrame = targetPosition + Vector3.new(0, 3, 0)
                                    task.wait(0.5)
                                    local claimAttempts = 0
                                    while _G.Config.AutoClaimMulti and prompt and prompt.Parent and prompt.Enabled and claimAttempts < 10 do
                                        pcall(function()
                                            fireproximityprompt(prompt)
                                        end)
                                        task.wait(0.2)
                                        claimAttempts = claimAttempts + 1
                                    end

                                    if not prompt.Enabled then
                                        print("Successfully claimed " .. itemName .. "!")
                                        itemsClaimed = true
                                    end
                                    task.wait(0.5)
                                end
                            end
                        end
                    end
                    if child:IsA("Folder") or child:IsA("Model") or child.Name == "StarCrater" or child.Name == "Root" then
                        if searchForItems(child, depth + 1) then
                            itemsClaimed = true
                        end
                    end
                end
                return itemsClaimed
            end

            task.spawn(function()
                while _G.Config.AutoClaimMulti do
                    local player = game.Players.LocalPlayer
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local oldCFrame = hrp.CFrame
                        local claimed = searchForItems(workspace, 0)
                        if _G.Config.AutoClaimMulti and claimed and hrp then
                            hrp.CFrame = oldCFrame
                            print("Returned to original position")
                        end
                        task.wait(2)
                    else
                        task.wait(2)
                    end
                end
            end)
        end

        if InitExclusive then
            pcall(function()
                InitExclusive(ExclusiveSection, AutoMineSection, AutoSaveSection, EspCharacterSection, EspEventSection, EspNpcSection)
            end)
        end

        if InitShop then
            pcall(function()
                InitShop(ShopBait, ShopItem, ShopRod, Merlin)
            end)
        end

        if InitAutos then
            pcall(function()
                InitAutos(nil, AutosQuest, AutosJack, AutosFavorit, AutosAppraise, AutoAppraise, AutoEnchant, nil, AutosSection, AuraSection, nil, nil)
            end)
        end

        pcall(function()
            local shadyStatus = AutosQuest:AddParagraph({
                Title = "Shady Rod Requirements Status",
                Content = "Inactive"
            })

            local function updateParagraph(para, text)
                if not para then return end
                local ok = pcall(function()
                    para:Set({ Title = "Shady Rod Requirements Status", Content = text })
                end)
                if not ok then
                    pcall(function() para:Set(text) end)
                    pcall(function() para:SetText(text) end)
                    pcall(function() para:SetContent(text) end)
                    pcall(function()
                        if typeof(para) == "table" and para.Instance then
                            para = para.Instance
                        end
                        if typeof(para) == "Instance" then
                            local desc = para:FindFirstChild("ParagraphContent") or para:FindFirstChildWhichIsA("TextLabel")
                            if desc then desc.Text = text end
                        end
                    end)
                end
            end

            if AutoQuestShady then
                AutoQuestShady.StatusCallback = function(statusString)
                    updateParagraph(shadyStatus, statusString)
                end
                -- Tampilkan requirements sekarang juga (bukan "Inactive")
                task.spawn(function()
                    task.wait(1)
                    pcall(function()
                        if AutoQuestShady.RefreshStatus then
                            AutoQuestShady.RefreshStatus("Siap (aktifkan toggle untuk mulai)")
                        end
                    end)
                end)
            end

            AutosQuest:AddToggle({
                Title = "Auto Quest Shady Rod",
                Default = _G.Config.AutoQuestShady or false,
                Callback = function(value)
                    if AutoQuestShady then
                        AutoQuestShady(value)
                    end
                end
            })

            -- ── Bazaar Quest Status Paragraph ──────────────────────
            local bazaarStatus = AutosQuest:AddParagraph({
                Title = "Bazaar Quest Status",
                Content = "Checking..."
            })

            local function updateBazaarParagraph(text)
                if not bazaarStatus then return end
                local ok = pcall(function()
                    bazaarStatus:Set({ Title = "Bazaar Quest Status", Content = text })
                end)
                if not ok then
                    pcall(function() bazaarStatus:Set(text) end)
                    pcall(function() bazaarStatus:SetText(text) end)
                    pcall(function() bazaarStatus:SetContent(text) end)
                    pcall(function()
                        local para = bazaarStatus
                        if typeof(para) == "table" and para.Instance then para = para.Instance end
                        if typeof(para) == "Instance" then
                            local desc = para:FindFirstChild("ParagraphContent") or para:FindFirstChildWhichIsA("TextLabel")
                            if desc then desc.Text = text end
                        end
                    end)
                end
            end

            if AutoQuestShady then
                AutoQuestShady.BazaarCallback = function(statusStr)
                    updateBazaarParagraph(statusStr)
                end
                -- Tampilkan status bazaar saat ini sekali
                pcall(function()
                    if AutoQuestShady.GetBazaarStatus then
                        local bs = AutoQuestShady.GetBazaarStatus()
                        if bs then
                            local str = ""
                            if bs.BazaarUnlocked then
                                str = "✓ Bazaar Terbuka\n✓ Quest 1 (3 Figur) SELESAI\n✓ Quest 2 (Lighthouse) SELESAI"
                            elseif bs.FindFiguresDone then
                                str = "✓ Quest 1 (3 Figur) SELESAI\n✗ Quest 2 (Lighthouse) BELUM"
                            else
                                str = "✗ Quest 1 (3 Figur) BELUM\n✗ Quest 2 (Lighthouse) BELUM"
                            end
                            updateBazaarParagraph(str)
                        end
                    end
                end)
            end

            -- ── Force Open Bazaar Hatch Button ─────────────────────
            AutosQuest:AddButton({
                Title = "Force Open Bazaar Hatch",
                Callback = function()
                    pcall(function()
                        if AutoQuestShady and AutoQuestShady.ForceOpenHatch then
                            local opened = AutoQuestShady.ForceOpenHatch()
                            updateBazaarParagraph(opened
                                and "✓ Hatch berhasil dibuka (client-side)!"
                                or  "✗ Hatch tidak ditemukan (LighthouseHatch tag)")
                        end
                    end)
                end
            })

            -- ── Teleport ke Shady Fishing Spot Button ──────────────
            AutosQuest:AddButton({
                Title = "Teleport ke Shady Fishing Spot",
                Callback = function()
                    pcall(function()
                        local char = game.Players.LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.CFrame = CFrame.new(-1067.4, 130.8, -1163.3)
                        end
                    end)
                end
            })
        end)

        if InitAreaTP then
            pcall(function()
                InitAreaTP(Main, SAVEPOSTION, NPCSection, BallonSection)
            end)
        end
    end

    ExclusiveSection:AddButton({
        Title = "Save Config",
        Callback = function()
            local HttpService = game:GetService("HttpService")
            pcall(function()
                writefile("ShieldTeamConfig.json", HttpService:JSONEncode(_G.Config))
            end)
        end
    })

    ExclusiveSection:AddToggle({
        Title = "Anti AFK",
        Default = _G.Config.AntiAFK or false,
        Callback = function(value)
            if AntiAFK then AntiAFK(value) end
        end
    })



    MiscPlayerSection:AddSlider({
        Title = "WalkSpeed",
        Min = 16,
        Max = 200,
        Default = 16,
        Callback = function(value)
            if WalkSpeed then WalkSpeed(value) end
        end
    })

    local function SetFreezeCharacter(enabled)
        _G.Config.FreezeCharacter = enabled
        local player = game.Players.LocalPlayer
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = enabled
        end
    end

    if not getgenv()._freezeCharAddedConn then
        getgenv()._freezeCharAddedConn = game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
            if _G.Config.FreezeCharacter then
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                if hrp then
                    hrp.Anchored = true
                end
            end
        end)
    end

    local _tInfJump = MiscPlayerSection:AddToggle({
        Title = "Infinity Jump",
        Default = _G.Config.InfinityJump or false,
        Callback = function(value)
            _G.Config.InfinityJump = value
            if WalkSpeed and WalkSpeed.SetInfJump then
                WalkSpeed.SetInfJump(value)
            end
        end
    })
    _regToggle(_tInfJump, "InfinityJump", function(v)
        _G.Config.InfinityJump = v
        if WalkSpeed and WalkSpeed.SetInfJump then
            WalkSpeed.SetInfJump(v)
        end
    end)

    local _tFreeze = MiscPlayerSection:AddToggle({
        Title = "Freeze Character",
        Default = _G.Config.FreezeCharacter or false,
        Callback = function(value)
            SetFreezeCharacter(value)
        end
    })
    _regToggle(_tFreeze, "FreezeCharacter", function(v)
        SetFreezeCharacter(v)
    end)

    MiscSection:AddToggle({
        Title = "Disable Oxygen",
        Default = false,
        Callback = function(value)
            if DisableOxygen then DisableOxygen(value) end
        end
    })

    MiscSection:AddToggle({
        Title = "Low Graphics (Level 1)",
        Default = _G.Config.LowGraphics or false,
        Callback = function(value)
            _G.Config.LowGraphics = value
            pcall(function()
                local userSettings = UserSettings():GetService("UserGameSettings")
                if value then
                    userSettings.SavedQualityLevel = Enum.SavedQualityLevel.Level01
                else
                    userSettings.SavedQualityLevel = Enum.SavedQualityLevel.Automatic
                end
            end)
            pcall(function()
                if value then
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                else
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
                end
            end)
        end
    })

    EspCharacterSection:AddToggle({
        Title = "ESP Player",
        Default = false,
        Callback = function(value)
            if ESP then ESP("Players", value) end
        end
    })
    
    CreditsSection:AddParagraph({
        Title = "ShieldTeam || NewFish5",
        Content = "Full GUI Layout Re-added.\nSemua Tab & Section sudah dibuatkan.\nSilahkan tambahkan Toggle lebih lanjut jika perlu!"
    })

end

setupGUI()
print("[NewFish5] GUI Loaded Successfully from ReplicatedStorage!")

task.spawn(function()
    task.wait(1)
    if _G.Config then
        if _G.Config['Farm Fish'] then
            _G.Config.AutoCast = true
            _G.Config.AutoReel = true
            _G.Config.AutoShake = true
            _G.Config.InstantCast = true
        end
        if AntiAFK and _G.Config.AntiAFK then AntiAFK(true) end
        if InstantBobber and _G.Config.InstantCast then InstantBobber(true) end
        if AutoCast and _G.Config.AutoCast then AutoCast(true) end
        if AutoReel and _G.Config.AutoReel then AutoReel(true) end
        if AutoShake and _G.Config.AutoShake then AutoShake(true) end
        if AutoSell and _G.Config.AutoSell then AutoSell(true) end
        if MiscFishing and MiscFishing.AutoEquipRod and _G.Config.isEquipRpd then MiscFishing.AutoEquipRod(true) end
        
        -- Otomatis atur grafis ke level 1 untuk performa/afk
        if _G.Config.LowGraphics then
            pcall(function()
                UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualityLevel.Level01
            end)
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
        end
    end
end)
