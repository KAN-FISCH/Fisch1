-- AntiAFK.lua - Cegah kick AFK secara aman menggunakan getconnections murni
local Players = game:GetService("Players")

local disabledConnections = {}

local function start()
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then
        task.spawn(function()
            while not Players.LocalPlayer do
                task.wait(0.5)
            end
            start()
        end)
        return
    end

    -- Menggunakan getconnections untuk menonaktifkan deteksi Idled bawaan game
    pcall(function()
        for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
            if conn.Disable then 
                conn:Disable()
                table.insert(disabledConnections, conn)
            elseif conn.Disconnect then 
                conn:Disconnect()
                table.insert(disabledConnections, conn)
            end
        end
    end)
end

local function stop()
    -- Aktifkan kembali koneksi Idled asli jika sebelumnya dinonaktifkan
    for _, conn in ipairs(disabledConnections) do
        pcall(function()
            if conn.Enable then
                conn:Enable()
            end
        end)
    end
    disabledConnections = {}
end

local AntiAFK = {}
setmetatable(AntiAFK, {
    __call = function(_, value)
        _G.Config.AntiAFK = value
        if value then
            start()
        else
            stop()
        end
    end
})

return AntiAFK
