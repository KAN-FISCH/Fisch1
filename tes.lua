-- ===============================================
-- NEKOTOOLS DYNAMIC AUTO REJOIN CLIENT (PURE LUA)
-- ===============================================
local apiKey    = "NK_API_KEY_ANDA" -- Otomatis terisi API Key Anda di Web
local serverUrl = "http://192.168.3.2:3555"

print("[+] NekoTools Dynamic Lua Client Initializing...")

-- FETCH LIVE CONFIG FROM WEB SERVER
local function getLiveConfig()
    local handle = io.popen(string.format('curl -s "%s/api/rejoin-config?apiKey=%s"', serverUrl, apiKey))
    if not handle then return nil end
    local res = handle:read("*a")
    handle:close()
    return res
end

print("[+] Connected to NekoTools Web Server. Listening for events...")

-- MONITOR LOGCAT FOR REJOIN KEYS
local pipe = io.popen('logcat | grep --line-buffered "receive key:"')
if pipe then
    for line in pipe:lines() do
        local key = line:match("receive key:%s*(%S+)")
        if key then
            local liveConfig = getLiveConfig()
            print("[!] Event Detected: " .. key)
            print("[!] Server Config: " .. (liveConfig or "OK"))
            
            local postCmd = string.format(
                'curl -s -X POST "%s/api/webhook" -H "Content-Type: application/json" -d \'{"apiKey":"%s","event":"auto_rejoin_trigger","key":"%s"}\' > /dev/null &',
                serverUrl, apiKey, key
            )
            os.execute(postCmd)
        end
    end
    pipe:close()
end
