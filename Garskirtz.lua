-- ========================================= --
-- 1. SETUP UI & VARIABEL GLOBAL             --
-- ========================================= --
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not success or not WindUI then
    warn("Gagal memuat WindUI! Pastikan koneksi internet stabil.")
    return
end

local Window = WindUI:CreateWindow({
    Title = "Garskirtz Ganteng", 
    Icon = "car", 
    Folder = "AutoRaceConfig",
    Size = UDim2.fromOffset(500, 350),
    Transparent = true,
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightControl
})

local MainTab = Window:Tab({ Title = "Main", Icon = "home" })

-- Variabel Status
getgenv().AutoSolo = false
getgenv().AutoMulti = false
getgenv().FarmRunning = false 
getgenv().SoloRemote = nil    
getgenv().DynamicCarID = nil -- Memori untuk ID Mobil Baru

local Config = {
    Delay = 1.4, 
    RaceName = "Race8",
    RaceCoord = Vector3.new(-3306.07666015625, 2.989119052886963, 5396.876953125)
}

MainTab:Toggle({
    Title = "Auto Solo Race",
    Desc = "Catatan: Tekan sekali tombol 'Race Solo' secara manual untuk merekam.",
    Default = false,
    Callback = function(Value)
        getgenv().AutoSolo = Value
        if Value then 
            getgenv().AutoMulti = false 
            if not getgenv().SoloRemote then
                WindUI:Notify({Title = "PENTING!", Content = "KLIK tombol 'Race Solo' secara MANUAL 1x agar script merekam kodenya!", Duration = 5})
            end
            StartAutoFarm() 
        end
    end
})

MainTab:Toggle({
    Title = "Auto Multiplayer",
    Desc = "Otomatis parkir di lingkaran dan menunggu player lain.",
    Default = false,
    Callback = function(Value)
        getgenv().AutoMulti = Value
        if Value then 
            getgenv().AutoSolo = false 
            StartAutoFarm() 
        end
    end
})

MainTab:Input({
    Title = "Teleport Delay (Detik)",
    Desc = "Alert! gunakan waktu 1.2 keatas.\nKetik angka jeda teleport lalu tekan Enter.",
    Default = "1.4",
    PlaceholderText = "Contoh: 1.4",
    ClearTextOnFocus = false,
    Callback = function(Value)
        local num = tonumber(Value)
        if num then
            if num < 1.2 then
                WindUI:Notify({Title = "Peringatan!", Content = "Waktu di bawah 1.2 sangat berisiko gagal/terdeteksi server!", Duration = 3})
            end
            Config.Delay = num
            WindUI:Notify({Title = "Berhasil", Content = "Delay diubah menjadi " .. num .. " detik.", Duration = 2})
        else
            WindUI:Notify({Title = "Error", Content = "Masukkan angka yang valid! (Contoh: 1.4)", Duration = 2})
        end
    end
})

-- ========================================= --
-- 2. SERVICES & ANTI-AFK SYSTEM             --
-- ========================================= --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ========================================= --
-- 3. SISTEM PENYADAP (NAMECALL HOOK)        --
-- ========================================= --
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    -- Sadap Remote Race Solo
    if method == "FireServer" and type(args[1]) == "string" and args[1] == Config.RaceName then
        if self.Name:match("%-") and not getgenv().SoloRemote then
            getgenv().SoloRemote = self
            if WindUI and WindUI.Notify then
                WindUI:Notify({Title = "HACK BERHASIL!", Content = "Remote Solo telah direkam! Script mengambil alih.", Duration = 4})
            end
        end
    end
    
    -- Sadap Remote Spawn Mobil
    if method == "FireServer" and self.Name == "SpawnCar" then
        if type(args[1]) == "string" and not getgenv().DynamicCarID then
            getgenv().DynamicCarID = args[1]
            if WindUI and WindUI.Notify then
                WindUI:Notify({Title = "MOBIL DIREKAM!", Content = "ID Mobil disimpan. Auto Spawn aktif!", Duration = 4})
            end
        end
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

-- ========================================= --
-- 4. FUNGSI BANTUAN GAME                    --
-- ========================================= --
local function getVehicleSeat(character)
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("VehicleSeat") and v.Occupant and v.Occupant.Parent == character then return v, v.Parent end
    end
    return nil, nil
end

local function findMyRace()
    local racesDir = workspace:FindFirstChild("Races")
    if not racesDir then return nil end
    local raceFolder = racesDir:FindFirstChild(Config.RaceName)
    if not raceFolder then return nil end
    local racesSubFolder = raceFolder:FindFirstChild("Races")
    
    if racesSubFolder then
        for _, rFolder in pairs(racesSubFolder:GetChildren()) do
            local racers = rFolder:FindFirstChild("Racers")
            if racers and racers:FindFirstChild(player.Name) then return rFolder end
        end
    end
    return nil
end

local function getCheckpoints(raceFolder)
    local cps = {}
    local checkpoints = raceFolder:FindFirstChild("Checkpoints")
    if not checkpoints then return cps end
    for _, cp in pairs(checkpoints:GetChildren()) do
        local part = cp:FindFirstChild("Part")
        if part and part:IsA("BasePart") then
            local index = tonumber(cp.Name)
            if index then cps[index] = part.Position elseif cp.Name == "Finish" then cps[9999] = part.Position end
        end
    end
    return cps
end

local function SpawnCar()
    if getgenv().DynamicCarID then
        WindUI:Notify({Title = "Sistem", Content = "Auto Spawn Mobil...", Duration = 2})
        pcall(function()
            local spawnEvent = ReplicatedStorage:WaitForChild("SpawnCar", 3)
            if spawnEvent then spawnEvent:FireServer(getgenv().DynamicCarID) end
        end)
        task.wait(4)
    else
        WindUI:Notify({Title = "Tunggu!", Content = "Tolong SPAWN MOBIL secara manual 1x agar script hafal ID-nya!", Duration = 4})
        task.wait(3)
    end
end

-- ========================================= --
-- 5. LOOPING UTAMA (THE BRAIN)              --
-- ========================================= --
function StartAutoFarm()
    if getgenv().FarmRunning then return end
    getgenv().FarmRunning = true
    
    task.spawn(function()
        local isJoining = false
        
        while task.wait(1) do
            local currentMode = nil
            if getgenv().AutoSolo then currentMode = "Solo"
            elseif getgenv().AutoMulti then currentMode = "Multiplayer"
            end
            
            if not currentMode then 
                getgenv().FarmRunning = false
                break 
            end
            
            local character = player.Character or player.CharacterAdded:Wait()
            local myRace = findMyRace()
            local seat, vehicle = getVehicleSeat(character)

            -- JIKA SEDANG BALAPAN
            if myRace then
                isJoining = false
                WindUI:Notify({Title = "Race", Content = "Bersiap balapan...", Duration = 3})
                task.wait(5.5) 
                
                local cps = getCheckpoints(myRace)
                local sortedKeys = {}
                for k in pairs(cps) do table.insert(sortedKeys, k) end
                table.sort(sortedKeys)

                if #sortedKeys > 0 and vehicle then
                    for _, key in ipairs(sortedKeys) do
                        if not getgenv().AutoSolo and not getgenv().AutoMulti then break end
                        local pos = cps[key]
                        
                        if vehicle.PrimaryPart then
                            vehicle:SetPrimaryPartCFrame(CFrame.new(pos + Vector3.new(0, 3, 0)))
                        else
                            seat.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                        end
                        task.wait(Config.Delay) 
                    end
                    WindUI:Notify({Title = "Finish", Content = "Selesai! Mengulang...", Duration = 3})
                    task.wait(4)
                end

            -- JIKA BELUM BALAPAN
            else
                if not seat then
                    SpawnCar()
                elseif not isJoining then
                    isJoining = true 
                    
                    if vehicle and vehicle.PrimaryPart then
                        vehicle:SetPrimaryPartCFrame(CFrame.new(Config.RaceCoord + Vector3.new(0, 3, 0)))
                    elseif seat then
                        seat.CFrame = CFrame.new(Config.RaceCoord + Vector3.new(0, 3, 0))
                    end
                    task.wait(3.5)
                    
                    if currentMode == "Solo" then
                        if getgenv().SoloRemote then
                            WindUI:Notify({Title = "Sistem", Content = "Mengeksekusi Remote Solo...", Duration = 2})
                            pcall(function() getgenv().SoloRemote:FireServer(Config.RaceName) end)
                        else
                            WindUI:Notify({Title = "Menunggu...", Content = "Klik tombol 'Race Solo' secara manual 1x...", Duration = 3})
                        end
                        task.wait(3)
                        
                    elseif currentMode == "Multiplayer" then
                        WindUI:Notify({Title = "AFK Mode", Content = "Menunggu pemain lain masuk lingkaran...", Duration = 3})
                        task.wait(5)
                    end
                    
                    isJoining = false
                end
            end
        end
        getgenv().FarmRunning = false
    end)
end

-- ========================================= --
-- UI: FLOATING BUTTON (UNTUK MOBILE / HP)   --
-- ========================================= --
local CoreGui = game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WindUI_FloatingToggle"
ScreenGui.Parent = (gethui and gethui()) or CoreGui
local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Parent = ScreenGui
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Position = UDim2.new(0, 20, 0, 20)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.Image = "rbxassetid://6031280882"
ToggleBtn.Draggable = true
ToggleBtn.Active = true
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = ToggleBtn

ToggleBtn.MouseButton1Click:Connect(function()
    local VirtualInputManager = game:GetService("VirtualInputManager")
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
end)
