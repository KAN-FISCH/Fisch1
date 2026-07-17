local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local running = false
local AutoQuestShady = {
    StatusCallback    = nil,
    BazaarCallback    = nil,   -- callback update UI bazaar status
    ForceOpenHatch    = nil,   -- dipasang setelah fungsi terdefinisi
    GetBazaarStatus   = nil,   -- dipasang setelah fungsi terdefinisi
}

-- ─────────────────────────────────────────────────────────
-- Koordinat mancing area Shady (Moosewood Bazaar area)
-- ─────────────────────────────────────────────────────────
local SHADY_FISHING_POS     = Vector3.new(-1067.4, 130.8, -1163.3)
local MOOSEWOOD_FISHING_POS = Vector3.new(388, 135, 245)

-- ─────────────────────────────────────────────────────────
-- Threshold koin untuk beli Shady Rod
-- Shady Rod harganya ~4k shady coin (bukan gold coin)
-- Kita detect via getCoins() / shady bazaar currency
-- ─────────────────────────────────────────────────────────
local SHADY_ROD_PRICE   = 4000   -- 4k shady coins
local SUNDIAL_PRICE     = 2000   -- 2k gold untuk sundial totem

local function formatAmount(val)
    if val >= 1000000 then
        local m = val / 1000000
        return (m % 1 == 0 and string.format("%dM", m) or string.format("%.1fM", m))
    elseif val >= 1000 then
        local k = val / 1000
        return (k % 1 == 0 and string.format("%dk", k) or string.format("%.1fk", k))
    end
    return tostring(val)
end

local function getDataController()
    local dc = nil
    pcall(function()
        dc = require(ReplicatedStorage:WaitForChild("client"):WaitForChild("legacyControllers"):WaitForChild("DataController"))
    end)
    if not dc then
        pcall(function()
            dc = require(ReplicatedStorage:WaitForChild("client"):WaitForChild("controllers"):WaitForChild("DataController"))
        end)
    end
    return dc
end

local function getLevel()
    local success, val = pcall(function()
        local stats = workspace:FindFirstChild("PlayerStats")
        local pFolder = stats and stats:FindFirstChild(LocalPlayer.Name)
        local tFolder = pFolder and pFolder:FindFirstChild("T")
        local subFolder = tFolder and tFolder:FindFirstChild(LocalPlayer.Name)
        local statsSub = subFolder and subFolder:FindFirstChild("Stats")
        local levelObj = statsSub and statsSub:FindFirstChild("level")
        return levelObj and levelObj.Value
    end)
    if success and val then return val end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local levelObj = leaderstats and leaderstats:FindFirstChild("Level")
    return levelObj and levelObj.Value or 0
end

local function getCoins()
    local success, val = pcall(function()
        local stats = workspace:FindFirstChild("PlayerStats")
        local pFolder = stats and stats:FindFirstChild(LocalPlayer.Name)
        local tFolder = pFolder and pFolder:FindFirstChild("T")
        local subFolder = tFolder and tFolder:FindFirstChild(LocalPlayer.Name)
        local statsSub = subFolder and subFolder:FindFirstChild("Stats")
        local coinsObj = statsSub and statsSub:FindFirstChild("coins")
        return coinsObj and coinsObj.Value
    end)
    if success and val then return val end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local cashObj = leaderstats and (leaderstats:FindFirstChild("C$") or leaderstats:FindFirstChild("E$"))
    return cashObj and cashObj.Value or 0
end

-- ─────────────────────────────────────────────────────────
-- Ambil shady coins (mata uang Bazaar, tampil sebagai "S$" di game)
-- Path: PlayerGui.hud.safezone.ShadyCoinGui
-- ─────────────────────────────────────────────────────────
local function getShadyCoins()
    local val = 0

    -- ── 1. Baca dari ShadyCoinGui di HUD (sumber utama) ────
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local hud = pGui and pGui:FindFirstChild("hud")
        local safezone = hud and hud:FindFirstChild("safezone")
        local shadyCoinGui = safezone and safezone:FindFirstChild("ShadyCoinGui")
        if shadyCoinGui then
            -- Cari TextLabel di dalam (bisa langsung atau child)
            local label = shadyCoinGui:IsA("TextLabel") and shadyCoinGui
                or shadyCoinGui:FindFirstChildWhichIsA("TextLabel")
                or shadyCoinGui:FindFirstChildWhichIsA("TextButton")
            local text = label and label.Text or (shadyCoinGui:IsA("TextLabel") and shadyCoinGui.Text)
            if text then
                -- Format: "4,372 S$" → hapus koma, hapus " S$", parse angka
                local cleaned = text:gsub(",", ""):gsub("%s*S%$.*", ""):gsub("[^%d]", "")
                val = tonumber(cleaned) or 0
            end
        end
    end)
    if val > 0 then return val end

    -- ── 2. Cek leaderstats ("S$" atau variasi) ─────────────
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            local obj = ls:FindFirstChild("S$")
                or ls:FindFirstChild("sc")
                or ls:FindFirstChild("ShadyCoins")
                or ls:FindFirstChild("Shady")
                or ls:FindFirstChild("Bazaar")
            if obj then
                val = tonumber(obj.Value) or 0
            end
        end
    end)
    if val > 0 then return val end

    -- ── 3. Cek PlayerStats → Stats ──────────────────────────
    pcall(function()
        local stats = workspace:FindFirstChild("PlayerStats")
        local pFolder = stats and stats:FindFirstChild(LocalPlayer.Name)
        local tFolder = pFolder and pFolder:FindFirstChild("T")
        local subFolder = tFolder and tFolder:FindFirstChild(LocalPlayer.Name)
        local statsSub = subFolder and subFolder:FindFirstChild("Stats")
        if statsSub then
            local obj = statsSub:FindFirstChild("sc")
                or statsSub:FindFirstChild("S$")
                or statsSub:FindFirstChild("shadyCoins")
                or statsSub:FindFirstChild("ShadyCoins")
                or statsSub:FindFirstChild("bazaarCoins")
                or statsSub:FindFirstChild("Bazaar_Coins")
            if obj then
                val = tonumber(obj.Value) or 0
            end
        end
    end)

    return val
end

-- ─────────────────────────────────────────────────────────
-- Helper: set transparansi semua part dalam model
-- (mirror dari ShadyHatchController.setModelTransparency)
-- ─────────────────────────────────────────────────────────
local function setModelTransparency(model, transparency)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
            descendant.Transparency = transparency
            if descendant:IsA("BasePart") then
                descendant.CanCollide = (transparency == 0)
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────
-- Cek status Bazaar quest via legacyLocalPlayerData
-- (mirror dari ShadyHatchController.Start)
-- ─────────────────────────────────────────────────────────
local function getBazaarQuestStatus()
    local status = {
        FindFiguresDone  = false,
        LighthouseDone   = false,
        BazaarUnlocked   = false,
        -- per-figur
        FoundLantern     = false,
        FoundDiver       = false,
        FoundWatchman    = false,
    }
    -- Cara utama: legacyLocalPlayerData (sama persis dgn controller)
    pcall(function()
        local legacyLocalPlayerData = require(ReplicatedStorage.client.modules.legacyLocalPlayerData)
        local playerData = legacyLocalPlayerData.fetch()
        if not playerData then return end
        local Cache = playerData:FindFirstChild("Cache")
        if not Cache then return end
        local lantern    = Cache:FindFirstChild("Bazaar_FoundLantern")
        local diver      = Cache:FindFirstChild("Bazaar_FoundDiver")
        local watchman   = Cache:FindFirstChild("Bazaar_FoundWatchman")
        local lighthouse = Cache:FindFirstChild("Bazaar_LighthousePassed")
        status.FoundLantern   = lantern   and lantern.Value   == true
        status.FoundDiver     = diver     and diver.Value     == true
        status.FoundWatchman  = watchman  and watchman.Value  == true
        status.FindFiguresDone = status.FoundLantern and status.FoundDiver and status.FoundWatchman
        status.LighthouseDone  = lighthouse and lighthouse.Value == true
    end)
    -- Fallback: workspace PlayerStats/Cache
    if not status.FindFiguresDone and not status.LighthouseDone then
        pcall(function()
            local stats = workspace:FindFirstChild("PlayerStats")
            local pFolder = stats and stats:FindFirstChild(LocalPlayer.Name)
            local tFolder = pFolder and pFolder:FindFirstChild("T")
            local subFolder = tFolder and tFolder:FindFirstChild(LocalPlayer.Name)
            local cacheFolder = subFolder and subFolder:FindFirstChild("Cache")
            if cacheFolder then
                local lantern    = cacheFolder:FindFirstChild("Bazaar_FoundLantern")
                local diver      = cacheFolder:FindFirstChild("Bazaar_FoundDiver")
                local watchman   = cacheFolder:FindFirstChild("Bazaar_FoundWatchman")
                local lighthouse = cacheFolder:FindFirstChild("Bazaar_LighthousePassed")
                status.FoundLantern   = lantern   and lantern.Value   == true
                status.FoundDiver     = diver     and diver.Value     == true
                status.FoundWatchman  = watchman  and watchman.Value  == true
                status.FindFiguresDone = status.FoundLantern and status.FoundDiver and status.FoundWatchman
                status.LighthouseDone  = lighthouse and lighthouse.Value == true
            end
        end)
    end
    status.BazaarUnlocked = status.FindFiguresDone and status.LighthouseDone
    return status
end

-- ─────────────────────────────────────────────────────────
-- Helper: interact dengan satu NPC/model via ProximityPrompt
-- ─────────────────────────────────────────────────────────
local function fireProximityOn(model)
    if not model then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Teleport ke dekat model secara aman
    local modelCF = nil
    pcall(function()
        if model:IsA("BasePart") then
            modelCF = model.CFrame
        elseif model:IsA("Model") then
            if model.PrimaryPart then
                modelCF = model.PrimaryPart.CFrame
            else
                local cf, size = model:GetBoundingBox()
                modelCF = cf
            end
        end
    end)

    if modelCF then
        hrp.CFrame = modelCF * CFrame.new(0, 0, 4)  -- 4 studs di depan
        task.wait(1.0)
    end

    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        pcall(function()
            if prompt.Enabled then
                prompt:InputHoldBegin()
                prompt.HoldDuration = 0
                prompt:InputHoldEnd()
            end
        end)
        task.wait(1.0) -- Tunggu dialog inisialisasi di client agar tidak tabrakan/hilang

        -- Dialog interact agar figure-nya terdaftar di-save
        pcall(function()
            local rf = ReplicatedStorage:FindFirstChild("packages")
                and ReplicatedStorage.packages:FindFirstChild("Net")
                and ReplicatedStorage.packages.Net:FindFirstChild("RF/DialogInteract")
            if rf then
                rf:InvokeServer(2, 1)
            end
        end)
        task.wait(1.0)
        return true
    end
    return false
end

-- ─────────────────────────────────────────────────────────
-- Auto temukan 3 figur Shady di Moosewood (malam hari)
-- Pakai CollectionService tag "ShadyFigure" (dari quest data)
-- ─────────────────────────────────────────────────────────
local function autoFindFigures()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local origCF = hrp.CFrame
    local oldAutoCast = _G.Config and _G.Config.AutoCast
    if _G.Config then _G.Config.AutoCast = false end
    task.wait(0.3)

    -- Teleport ke Moosewood spot terlebih dahulu agar model NPC dimuat (stream in)
    hrp.CFrame = CFrame.new(MOOSEWOOD_FISHING_POS)
    task.wait(1.5)

    -- Ambil semua model dengan tag ShadyFigure
    local rawFigures = CollectionService:GetTagged("ShadyFigure")
    if #rawFigures == 0 then
        -- Tag tidak ada, coba cari manual di workspace
        pcall(function()
            local world = workspace:FindFirstChild("world")
            local npcs  = world and world:FindFirstChild("npcs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    local n = npc.Name:lower()
                    if n:find("shady") or n:find("lantern") or n:find("diver") or n:find("watchman") or n:find("figure") or n:find("fisher") or n:find("bobber") then
                        rawFigures[#rawFigures + 1] = npc
                    end
                end
            end
        end)
    end

    -- Saring hanya figur yang aktif: memiliki ProximityPrompt dan berada di ketinggian wajar (Y < 220)
    local figures = {}
    for _, npc in ipairs(rawFigures) do
        local hasPrompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        local cf = nil
        pcall(function()
            cf = npc:IsA("BasePart") and npc.CFrame
                or (npc.PrimaryPart and npc.PrimaryPart.CFrame)
                or cf
        end)
        if hasPrompt and cf then
            local y = cf.Position.Y
            -- Moosewood docks Y adalah ~135, kita batasi Y antara 100 s/d 220
            if y > 100 and y < 220 then
                table.insert(figures, npc)
            end
        end
    end

    if #figures == 0 then
        -- Belum spawn (mungkin siang) — tidak ada yang dilakukan
        if _G.Config then _G.Config.AutoCast = oldAutoCast end
        return false
    end

    -- Re-cek status per figur sebelum jalan
    local bs = getBazaarQuestStatus()

    for _, figure in ipairs(figures) do
        -- Skip figur yang sudah ditemukan berdasarkan nama
        local figName = figure.Name:lower()
        local skip = false
        if (figName:find("fisher") or figName:find("lantern")) and bs.FoundLantern then
            skip = true
        elseif (figName:find("bobber") or figName:find("diver")) and bs.FoundDiver then
            skip = true
        elseif figName:find("watchman") and bs.FoundWatchman then
            skip = true
        end

        if not skip then
            fireProximityOn(figure)
            -- Update status setelah interact
            bs = getBazaarQuestStatus()
            if bs.FindFiguresDone then break end
        end
    end

    -- Kalau masih belum semua, coba interact semua figur yang ada
    if not getBazaarQuestStatus().FindFiguresDone then
        for _, figure in ipairs(figures) do
            fireProximityOn(figure)
            task.wait(0.5)
        end
    end

    hrp.CFrame = origCF
    task.wait(0.5)
    if _G.Config then _G.Config.AutoCast = oldAutoCast end
    return getBazaarQuestStatus().FindFiguresDone
end

-- ─────────────────────────────────────────────────────────
-- Force-open hatch client-side
-- (mirror persis dari ShadyHatchController.openHatch)
-- ─────────────────────────────────────────────────────────
local function forceOpenHatch()
    -- Ambil model bertag "LighthouseHatch" (sama persis dgn controller)
    local hatchModel = CollectionService:GetTagged("LighthouseHatch")[1]
    if hatchModel then
        local ShadyHatch     = hatchModel:FindFirstChild("ShadyHatch")
        local ShadyHatchOpen = hatchModel:FindFirstChild("ShadyHatchOpen")
        if ShadyHatch and ShadyHatchOpen then
            setModelTransparency(ShadyHatch, 1)     -- sembunyikan hatch tertutup
            setModelTransparency(ShadyHatchOpen, 0) -- tampilkan hatch terbuka
            return true
        end
    end
    return false
end

-- ─────────────────────────────────────────────────────────
-- Teleport ke titik mancing shady
-- ─────────────────────────────────────────────────────────
local function teleportToShadyFishingSpot()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(SHADY_FISHING_POS)
    task.wait(0.8)
end

local function teleportToMoosewoodFishingSpot()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(MOOSEWOOD_FISHING_POS)
    task.wait(0.8)
end

-- ─────────────────────────────────────────────────────────
-- Open Bazaar: force-open hatch + fallback FireServer
-- ─────────────────────────────────────────────────────────
local function tryOpenBazaar()
    -- 1. Force-open hatch client-side (visual) seperti ShadyHatchController
    local hatchOpened = forceOpenHatch()

    -- 2. Jika bazaar_LighthousePassed sudah true, listener sudah handle — done
    if hatchOpened then return end

    -- 3. Fallback: coba FireServer event jika ada
    pcall(function()
        local events = ReplicatedStorage:FindFirstChild("events")
        if events then
            local openBazaar = events:FindFirstChild("openBazaar")
                or events:FindFirstChild("OpenBazaar")
                or events:FindFirstChild("bazaarOpen")
            if openBazaar then
                openBazaar:FireServer()
                return
            end
        end
        -- via packages/Net
        local Net = ReplicatedStorage:FindFirstChild("packages") and ReplicatedStorage.packages:FindFirstChild("Net")
        if Net then
            local rf = Net:FindFirstChild("RF/OpenBazaar") or Net:FindFirstChild("RE/OpenBazaar")
            if rf then
                if rf:IsA("RemoteFunction") then rf:InvokeServer()
                else rf:FireServer() end
            end
        end
    end)
end

-- ─────────────────────────────────────────────────────────
-- Interaksi NPC / proximity prompt Bazaar
-- ─────────────────────────────────────────────────────────
local function interactBazaarNPC()
    -- Todd (accept indicator) & Shady Lighthouse Figure
    local npcNames = {"Todd", "ShadyLighthouseFigure", "ShadyFigure", "Shady Figure", "Lighthouse Figure"}
    for _, npcName in ipairs(npcNames) do
        pcall(function()
            local npc = workspace:FindFirstChild(npcName, true)
            if npc then
                local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and prompt.Enabled then
                    pcall(function()
                        prompt:InputHoldBegin()
                        prompt.HoldDuration = 0
                        prompt:InputHoldEnd()
                    end)
                    task.wait(0.5)
                end
            end
        end)
    end
end

local function hasSundialTotem()
    if LocalPlayer.Backpack:FindFirstChild("Sundial Totem") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Sundial Totem")) then
        return true
    end
    
    local inventory = nil
    local DataController = getDataController()
    if DataController then
        pcall(function()
            if DataController.InventoryReplicator then
                inventory = DataController.InventoryReplicator:Index({"Inventory"})
            else
                inventory = DataController.fetch("Inventory")
            end
        end)
    end
    
    if inventory then
        for _, itemData in pairs(inventory) do
            if type(itemData) == "table" and itemData.name == "Sundial Totem" then
                return true
            end
        end
    end
    return false
end

local function ownsShadyRod()
    local success, equipped = pcall(function()
        return workspace.PlayerStats[LocalPlayer.Name].T[LocalPlayer.Name].Stats.rod.Value == "Shady Rod"
    end)
    if success and equipped then return true end
    
    if LocalPlayer.Backpack:FindFirstChild("Shady Rod") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Shady Rod")) then
        return true
    end
    
    local inventory = nil
    local DataController = getDataController()
    if DataController then
        pcall(function()
            if DataController.InventoryReplicator then
                inventory = DataController.InventoryReplicator:Index({"Inventory"})
            else
                inventory = DataController.fetch("Inventory")
            end
        end)
    end
    if inventory then
        for _, itemData in pairs(inventory) do
            if type(itemData) == "table" and itemData.name == "Shady Rod" then
                return true
            end
        end
    end
    return false
end

local function buySundialTotem()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local origCF = hrp.CFrame
    local oldAutoCast = _G.Config.AutoCast
    _G.Config.AutoCast = false
    task.wait(0.2)
    
    hrp.CFrame = CFrame.new(-1215, 195.3, -1040)
    task.wait(1.5)
    
    pcall(function()
        local events = ReplicatedStorage:FindFirstChild("events")
        local purchase = events and events:FindFirstChild("purchase")
        if purchase then
            purchase:FireServer("Sundial Totem", "Item", nil, 1)
        end
    end)
    task.wait(1.0)
    
    hrp.CFrame = origCF
    task.wait(0.5)
    _G.Config.AutoCast = oldAutoCast
end

local function useSundialTotem()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local totem = LocalPlayer.Backpack:FindFirstChild("Sundial Totem")
    if not totem then return end
    
    local oldAutoCast = _G.Config.AutoCast
    _G.Config.AutoCast = false
    task.wait(0.2)
    
    totem.Parent = char
    task.wait(0.5)
    
    pcall(function()
        totem:Activate()
    end)
    task.wait(4.0)
    
    if totem.Parent == char then
        totem.Parent = LocalPlayer.Backpack
    end
    
    _G.Config.AutoCast = oldAutoCast
end

-- ─────────────────────────────────────────────────────────
-- Beli Shady Rod via Bazaar (4k shady coins)
-- ─────────────────────────────────────────────────────────
local function buyShadyRodBazaar()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local origCF = hrp.CFrame
    local oldAutoCast = _G.Config.AutoCast
    _G.Config.AutoCast = false
    task.wait(0.2)

    -- Teleport ke area bazaar (bawah lighthouse Moosewood)
    hrp.CFrame = CFrame.new(-1067.4, 130.8, -1163.3)
    task.wait(1.5)

    -- Coba beli lewat event purchase dengan currency ShadyCoins
    local bought = false
    pcall(function()
        local events = ReplicatedStorage:FindFirstChild("events")
        local purchase = events and events:FindFirstChild("purchase")
        if purchase then
            purchase:FireServer("Shady Rod", "Rod", "ShadyCoins", 1)
            bought = true
        end
    end)

    if not bought then
        -- Fallback: direct purchase tanpa currency hint
        pcall(function()
            local purchase = ReplicatedStorage:FindFirstChild("events") and ReplicatedStorage.events:FindFirstChild("purchase")
            if purchase then
                purchase:FireServer("Shady Rod", "Rod", nil, 1)
            end
        end)
    end

    task.wait(1.5)
    hrp.CFrame = origCF
    task.wait(0.5)
    _G.Config.AutoCast = oldAutoCast
end

-- ─────────────────────────────────────────────────────────
-- Beli Shady Rod via Shady Merchant (lama, fallback)
-- ─────────────────────────────────────────────────────────
local function buyShadyRod()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local origCF = hrp.CFrame
    local oldAutoCast = _G.Config.AutoCast
    _G.Config.AutoCast = false
    task.wait(0.2)
    
    hrp.CFrame = CFrame.new(-2997, -1023, 6067)
    task.wait(1.5)
    
    pcall(function()
        local shadyMerchant = workspace:FindFirstChild("world")
            and workspace.world:FindFirstChild("npcs")
            and (workspace.world.npcs:FindFirstChild("Shady Merchant") or workspace:FindFirstChild("Shady Merchant"))
        if not shadyMerchant then
            shadyMerchant = workspace:FindFirstChild("Shady Merchant")
        end
        if shadyMerchant then
            local prompt = shadyMerchant:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                pcall(function()
                    prompt:InputHoldBegin()
                    prompt.HoldDuration = 0
                    prompt:InputHoldEnd()
                end)
            end
        end
    end)
    task.wait(0.5)
    
    pcall(function()
        local dialogInteract = ReplicatedStorage:WaitForChild("packages"):WaitForChild("Net"):WaitForChild("RF/DialogInteract")
        if dialogInteract then
            dialogInteract:InvokeServer(1, 1)
        end
    end)
    task.wait(0.2)
    
    pcall(function()
        local purchase = ReplicatedStorage:FindFirstChild("events") and ReplicatedStorage.events:FindFirstChild("purchase")
        if purchase then
            purchase:FireServer("Shady Rod", "Rod", nil, 1)
        end
    end)
    task.wait(1.5)
    
    hrp.CFrame = origCF
    task.wait(0.5)
    _G.Config.AutoCast = oldAutoCast
end

-- ─────────────────────────────────────────────────────────
-- Update status UI
-- ─────────────────────────────────────────────────────────
local function updateStatusUI(currentActionText)
    if not AutoQuestShady.StatusCallback then return end
    
    pcall(function()
        local lvl = getLevel()
        local coins = getCoins()
        local shadyCoins = getShadyCoins()
        local hasTotem = hasSundialTotem()
        local bazaarStatus = getBazaarQuestStatus()
        
        local isDay = false
        pcall(function()
            isDay = (ReplicatedStorage.world.cycle.Value == "Day")
        end)
        
        local reqCoins = hasTotem and 150000 or 152000
        
        local bazaarStr = ""
        if bazaarStatus.BazaarUnlocked then
            bazaarStr = "Terbuka ✓"
        elseif bazaarStatus.FindFiguresDone then
            bazaarStr = "Quest 1 ✓ | Quest 2 ✗"
        else
            bazaarStr = "Belum terbuka"
        end

        local statusString = string.format(
            "• Level: %d/50 [%s]\n" ..
            "• Gold Coins: %s/%s [%s]\n" ..
            "• Shady Coins: %s/%s [%s]\n" ..
            "• Totem Sundial: %s\n" ..
            "• Bazaar: %s\n" ..
            "• Waktu: %s\n\n" ..
            "Status: %s",
            lvl, lvl >= 50 and "OK" or "BELUM",
            formatAmount(coins), formatAmount(reqCoins), coins >= reqCoins and "OK" or "BELUM",
            formatAmount(shadyCoins), formatAmount(SHADY_ROD_PRICE), shadyCoins >= SHADY_ROD_PRICE and "OK" or "BELUM",
            hasTotem and "Ada" or "Tidak Ada (Butuh 2k C$)",
            bazaarStr,
            isDay and "Siang" or "Malam",
            currentActionText or "Checking..."
        )
        
        AutoQuestShady.StatusCallback(statusString)
    end)
end

-- ─────────────────────────────────────────────────────────
-- Paksa fishing di koordinat shady
-- ─────────────────────────────────────────────────────────
local function setFishingAtShadySpot()
    if _G.Config then
        -- Override TeleportArea / fishing spot ke koordinat shady
        if _G.Config.FishingPosition ~= nil then
            _G.Config.FishingPosition = SHADY_FISHING_POS
        end
        -- Kalau pakai override position
        if _G.Config.OverridePosition ~= nil then
            _G.Config.OverridePosition = SHADY_FISHING_POS
        end
        -- Set custom cast position
        if _G.Config.CastPosition ~= nil then
            _G.Config.CastPosition = SHADY_FISHING_POS
        end
    end
    -- Teleport ke spot
    teleportToShadyFishingSpot()
end

-- ─────────────────────────────────────────────────────────
-- Paksa fishing di koordinat Moosewood (leveling & gold coins)
-- ─────────────────────────────────────────────────────────
local function setFishingAtMoosewood()
    if _G.Config then
        -- Override TeleportArea / fishing spot ke koordinat Moosewood
        if _G.Config.FishingPosition ~= nil then
            _G.Config.FishingPosition = MOOSEWOOD_FISHING_POS
        end
        -- Kalau pakai override position
        if _G.Config.OverridePosition ~= nil then
            _G.Config.OverridePosition = MOOSEWOOD_FISHING_POS
        end
        -- Set custom cast position
        if _G.Config.CastPosition ~= nil then
            _G.Config.CastPosition = MOOSEWOOD_FISHING_POS
        end
    end
    -- Teleport ke spot Moosewood
    teleportToMoosewoodFishingSpot()
end

-- ─────────────────────────────────────────────────────────
-- Quest Helper Functions
-- ─────────────────────────────────────────────────────────
local function findNPC(name)
    local world = workspace:FindFirstChild("world")
    local npcs = world and world:FindFirstChild("npcs")
    if npcs then
        local npc = npcs:FindFirstChild(name)
        if npc then return npc end
    end
    return workspace:FindFirstChild(name, true)
end

local function teleportToNPC(npcName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    if npcName == "Todd" then
        hrp.CFrame = CFrame.new(499, 159, 218)
        task.wait(1.0)
        return findNPC("Todd")
    end

    local npc = findNPC(npcName)
    if not npc then return nil end
    
    local npcCF = nil
    if npc:IsA("BasePart") then
        npcCF = npc.CFrame
    elseif npc:IsA("Model") then
        npcCF = npc:GetPivot()
    end
    
    if npcCF then
        hrp.CFrame = npcCF * CFrame.new(0, 0, 3)
        task.wait(1.0)
    end
    return npc
end

local function talkToNPC(npcName, optionIndex)
    local npc = teleportToNPC(npcName)
    if not npc then return false end
    
    local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        pcall(function()
            prompt:InputHoldBegin()
            prompt.HoldDuration = 0
            prompt:InputHoldEnd()
        end)
        task.wait(1.0)
        
        local chosenOption = optionIndex
        if npcName == "Todd" then
            chosenOption = 5
        end
        
        if chosenOption then
            pcall(function()
                local dialogInteract = ReplicatedStorage:FindFirstChild("packages")
                    and ReplicatedStorage.packages:FindFirstChild("Net")
                    and ReplicatedStorage.packages.Net:FindFirstChild("RF/DialogInteract")
                if dialogInteract then
                    dialogInteract:InvokeServer(optionIndex, 1)
                end
            end)
            task.wait(0.5)
        end
        return true
    end
    return false
end

local function findFigureNPC(type)
    for _, child in ipairs(workspace:GetDescendants()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            local name = child.Name:lower()
            if type == "Fisher" and (name:find("fisher") or name:find("lantern")) then
                return child
            elseif type == "Diver" and (name:find("diver") or name:find("bobber") or name:find("hook")) then
                return child
            elseif type == "Watchman" and (name:find("watchman") or name:find("crow") or name:find("charm") or name:find("feather")) then
                return child
            end
        end
    end
    return nil
end

local function equipQuestItem(name)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local item = backpack:FindFirstChild(name)
        if item and item:FindFirstChild("link") then
            pcall(function()
                local equipRemote = ReplicatedStorage:WaitForChild("packages"):WaitForChild("Net"):WaitForChild("RE/Backpack/Equip")
                if equipRemote then
                    equipRemote:FireServer(item.link.Value)
                end
            end)
            task.wait(0.2)
        end
    end
end

local function forceEquipTool(name)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if hum and backpack then
        local tool = backpack:FindFirstChild(name)
        if tool then
            hum:EquipTool(tool)
            task.wait(0.2)
        end
    end
end

local function solveLighthouseRiddle()
    local npcNames = {"Some Shady Guy", "ShadyLighthouseFigure", "Lighthouse Figure"}
    local npc = nil
    for _, name in ipairs(npcNames) do
        npc = workspace:FindFirstChild(name, true)
        if npc then break end
    end
    if not npc then return false end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = npc:GetPivot() * CFrame.new(0, 0, 3)
    task.wait(1.0)
    
    local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        pcall(function()
            prompt:InputHoldBegin()
            prompt.HoldDuration = 0
            prompt:InputHoldEnd()
        end)
        task.wait(1.5)
        
        local dialogInteract = ReplicatedStorage:WaitForChild("packages"):WaitForChild("Net"):WaitForChild("RF/DialogInteract")
        if dialogInteract then
            -- Question 1: chat atas (Option 1)
            pcall(function() dialogInteract:InvokeServer(1, 1) end)
            task.wait(1.0)
            -- Question 2: chat atas (Option 1)
            pcall(function() dialogInteract:InvokeServer(1, 1) end)
            task.wait(1.0)
            -- Question 3: chat bawah (Option 2)
            pcall(function() dialogInteract:InvokeServer(2, 1) end)
            task.wait(1.0)
        end
        return true
    end
    return false
end

local function talkToBazaarGuard()
    local npcNames = {"Bazaar Guard", "Bazaar guard", "Guard"}
    local npc = nil
    for _, name in ipairs(npcNames) do
        npc = workspace:FindFirstChild(name, true)
        if npc then break end
    end
    if not npc then return false end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = npc:GetPivot() * CFrame.new(0, 0, 3)
    task.wait(1.0)
    
    local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        pcall(function()
            prompt:InputHoldBegin()
            prompt.HoldDuration = 0
            prompt:InputHoldEnd()
        end)
        task.wait(1.0)
        
        pcall(function()
            local dialogInteract = ReplicatedStorage:WaitForChild("packages"):WaitForChild("Net"):WaitForChild("RF/DialogInteract")
            if dialogInteract then
                dialogInteract:InvokeServer(1, 1)
            end
        end)
        task.wait(1.0)
        return true
    end
    return false
end

-- ─────────────────────────────────────────────────────────
-- Main loop
-- ─────────────────────────────────────────────────────────
local function AutoQuestShadyLoop()
    if running then return end
    running = true
    
    task.spawn(function()
        while _G.Config and _G.Config.AutoQuestShady do
            task.wait(1.0)
            pcall(function()
                if ownsShadyRod() then
                    updateStatusUI("Sudah memiliki Shady Rod! ✓")
                    _G.Config.AutoQuestShady = false
                    return
                end

                local lvl      = getLevel()
                local coins    = getCoins()
                local shadyCoins = getShadyCoins()
                local hasTotem = hasSundialTotem()
                local bazaarStatus = getBazaarQuestStatus()

                -- ── FASE 1: Selesaikan Questline ─────────
                if not bazaarStatus.BazaarUnlocked then
                    -- Cek status item
                    local hasLantern = LocalPlayer.Backpack:FindFirstChild("Tarnished Lantern") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Tarnished Lantern"))
                    local hasHook    = LocalPlayer.Backpack:FindFirstChild("Barnacled Hook")    or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Barnacled Hook"))
                    local hasCharm   = LocalPlayer.Backpack:FindFirstChild("Crow Feather Charm")   or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Crow Feather Charm"))
                    local gotAllItems = hasLantern and hasHook and hasCharm

                    if not gotAllItems then
                        -- Quest belum dimulai atau item belum lengkap -> ajak bicara Todd dulu
                        local stats = getBazaarQuestStatus()
                        if not stats.FoundLantern and not stats.FoundDiver and not stats.FoundWatchman then
                            updateStatusUI("Memulai quest: Bicara dengan NPC Todd...")
                            talkToNPC("Todd", 1)
                            task.wait(2.0)
                            return
                        end

                        -- Cek siang/malam
                        local isDay = false
                        pcall(function()
                            isDay = (ReplicatedStorage.world.cycle.Value == "Day")
                        end)

                        if isDay then
                            if hasSundialTotem() then
                                updateStatusUI("Siang -> Mengaktifkan Sundial Totem untuk malam...")
                                useSundialTotem()
                                task.wait(3.0)
                                return
                            else
                                updateStatusUI("Siang: Menunggu malam tiba untuk mencari figur...")
                                task.wait(2.0)
                                return
                            end
                        end

                        -- Malam hari -> cari figur yang belum didapatkan
                        updateStatusUI("Mencari figur quest malam...")
                        local statsNow = getBazaarQuestStatus()
                        if not statsNow.FoundLantern then
                            updateStatusUI("Mencari Fisher (Lantern)...")
                            local fig = findFigureNPC("Fisher")
                            if fig then
                                fireProximityOn(fig)
                                task.wait(2.0)
                            end
                        elseif not statsNow.FoundDiver then
                            updateStatusUI("Mencari Diver (Barnacled Hook)...")
                            local fig = findFigureNPC("Diver")
                            if fig then
                                fireProximityOn(fig)
                                task.wait(2.0)
                            end
                        elseif not statsNow.FoundWatchman then
                            updateStatusUI("Mencari Watchman (Crow Feather Charm)...")
                            local fig = findFigureNPC("Watchman")
                            if fig then
                                fireProximityOn(fig)
                                task.wait(2.0)
                            end
                        end
                        return
                    else
                        -- Sudah punya semua item -> Equip semuanya
                        updateStatusUI("Equip semua item quest...")
                        equipQuestItem("Tarnished Lantern")
                        equipQuestItem("Barnacled Hook")
                        equipQuestItem("Crow Feather Charm")
                        forceEquipTool("Tarnished Lantern")
                        forceEquipTool("Barnacled Hook")
                        forceEquipTool("Crow Feather Charm")
                        task.wait(1.5)

                        if not _G.TalkedToToddSecondTime then
                            updateStatusUI("Bicara dengan NPC Todd setelah equip item...")
                            talkToNPC("Todd", 1)
                            _G.TalkedToToddSecondTime = true
                            task.wait(2.0)
                            return
                        end

                        -- Solve riddle mercusuar
                        if not bazaarStatus.LighthouseDone then
                            updateStatusUI("Menuju mercusuar untuk memecahkan riddle...")
                            solveLighthouseRiddle()
                            task.wait(2.0)
                            return
                        end

                        -- Talk ke Bazaar Guard
                        updateStatusUI("Bicara ke Bazaar Guard...")
                        talkToBazaarGuard()
                        task.wait(2.0)
                        return
                    end
                end

                -- Jika LighthouseDone sudah true tetapi Bazaar belum sepenuhnya terbuka
                if bazaarStatus.LighthouseDone and not bazaarStatus.BazaarUnlocked then
                    updateStatusUI("Bicara ke Bazaar Guard...")
                    talkToBazaarGuard()
                    task.wait(2.0)
                    return
                end

                -- ── FASE 2: Beli Shady Rod jika sudah terbuka dan cukup koin ─
                if shadyCoins >= SHADY_ROD_PRICE then
                    updateStatusUI("Membeli Shady Rod di Bazaar...")
                    buyShadyRodBazaar()
                    task.wait(2.0)
                    if ownsShadyRod() then
                        updateStatusUI("Sukses memiliki Shady Rod! ✓")
                        _G.Config.AutoQuestShady = false
                    end
                    return
                end

                -- ── FASE 3: Koin tidak cukup -> farming shady coins ────────────
                updateStatusUI(string.format("Farming Shady Coins... (%s/%s)", formatAmount(shadyCoins), formatAmount(SHADY_ROD_PRICE)))
                setFishingAtShadySpot()
                _G.Config.AutoCast         = true
                _G.Config.AutoReel         = true
                _G.Config.InstantReel      = true
                _G.Config.InstantCast      = true
                _G.Config.AutoShake        = true
                _G.Config.AutoPerfectCatch = true
                _G.Config.AutoSell         = true
            end)
        end
        running = false
    end)
end

-- Wire up public API setelah semua fungsi terdefinisi
AutoQuestShady.ForceOpenHatch  = forceOpenHatch
AutoQuestShady.GetBazaarStatus = getBazaarQuestStatus
AutoQuestShady.RefreshStatus   = function(msg)
    updateStatusUI(msg or "Siap (aktifkan toggle untuk mulai)")
end

-- Debug: print semua kemungkinan path untuk S$ shady coins
AutoQuestShady.DebugShadyCoins = function()
    print("=== DEBUG SHADY COINS ===")
    -- Leaderstats
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            print("[leaderstats]", v.Name, "=", v.Value)
        end
    end
    -- PlayerStats Stats
    pcall(function()
        local sub = workspace.PlayerStats[LocalPlayer.Name].T[LocalPlayer.Name]
        local statsSub = sub:FindFirstChild("Stats")
        if statsSub then
            for _, v in ipairs(statsSub:GetChildren()) do
                print("[PlayerStats/Stats]", v.Name, "=", (pcall(function() return v.Value end)))
            end
        end
        local cacheFolder = sub:FindFirstChild("Cache")
        if cacheFolder then
            for _, v in ipairs(cacheFolder:GetChildren()) do
                if v.Name:lower():find("coin") or v.Name:lower():find("shady") or v.Name:lower():find("bazaar") or v.Name == "sc" or v.Name == "S$" then
                    print("[PlayerStats/Cache]", v.Name, "=", (pcall(function() return v.Value end)))
                end
            end
        end
    end)
    print("getShadyCoins() =", getShadyCoins())
    print("=========================")
end

setmetatable(AutoQuestShady, {
    __call = function(self, value)
        _G.Config.AutoQuestShady = value
        if value then
            AutoQuestShadyLoop()
        else
            updateStatusUI("Inactive")
        end
    end
})

return AutoQuestShady
