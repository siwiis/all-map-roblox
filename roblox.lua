--[[
    ============================================================================
    BimSakSin Hub v3.0 — Luxury 3D HD Skull Edition (Complete Release)
    Architecture: Modular Layered Luau Hub
      1. Environment & Safe Executor Wrappers
      2. Lifecycle & Cleanup Manager (Zero Memory Leaks / Clean Unload)
      3. Persistent JSON Config Manager (Schema-Safe Merge)
      4. GeoLangAPI (Real-Time IP/Geolocation + 16 Global Languages)
      5. Luxury 3D HD Skull Viewport Renderer & Animated Verified Badge
      6. Glassmorphic UI Component Factory (6 Complete Tabs)
      7. Feature Controllers (Defense, Unlimited Movement, Combat, ESP, TP)
      8. Optimized Render & Physics Loops
    ============================================================================
]]

-- ============================================================================
-- 1. SERVICES & SAFE ENVIRONMENT WRAPPERS
-- ============================================================================
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    HttpService = game:GetService("HttpService"),
    CoreGui = game:GetService("CoreGui"),
    Workspace = game:GetService("Workspace"),
    VirtualUser = game:GetService("VirtualUser"),
    StarterGui = game:GetService("StarterGui"),
    Lighting = game:GetService("Lighting")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

local Env = {}
function Env.GetGuiParent()
    local ok, hui = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if ok and hui then
        return hui
    end
    local okCore, core = pcall(function()
        return Services.CoreGui
    end)
    if okCore and core then
        return core
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function Env.ProtectGui(gui)
    pcall(function()
        if syn and type(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        end
    end)
end

function Env.HttpGet(url)
    local ok, result = pcall(function()
        if type(request) == "function" then
            local res = request({ Url = url, Method = "GET" })
            if res and res.Body then
                return res.Body
            end
        elseif type(http_request) == "function" then
            local res = http_request({ Url = url, Method = "GET" })
            if res and res.Body then
                return res.Body
            end
        elseif syn and type(syn.request) == "function" then
            local res = syn.request({ Url = url, Method = "GET" })
            if res and res.Body then
                return res.Body
            end
        end
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end
    return false, nil
end

Env.HasFileIO = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
Env.HasDrawing = (type(Drawing) == "table" or type(Drawing) == "function")

-- ============================================================================
-- 2. LIFECYCLE & CLEANUP MANAGER
-- ============================================================================
local CleanupManager = {
    Alive = true,
    Connections = {},
    Instances = {},
    Drawings = {},
    Callbacks = {}
}

function CleanupManager:AddConnection(conn)
    if conn then
        table.insert(self.Connections, conn)
    end
    return conn
end

function CleanupManager:AddInstance(inst)
    if inst then
        table.insert(self.Instances, inst)
    end
    return inst
end

function CleanupManager:AddDrawing(drawObj)
    if drawObj then
        table.insert(self.Drawings, drawObj)
    end
    return drawObj
end

function CleanupManager:OnUnload(fn)
    if type(fn) == "function" then
        table.insert(self.Callbacks, fn)
    end
end

function CleanupManager:Unload()
    if not self.Alive then
        return
    end
    self.Alive = false

    for _, fn in ipairs(self.Callbacks) do
        pcall(fn)
    end

    for _, conn in ipairs(self.Connections) do
        pcall(function()
            if conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    table.clear(self.Connections)

    for _, drawObj in ipairs(self.Drawings) do
        pcall(function()
            drawObj.Visible = false
            drawObj:Remove()
        end)
    end
    table.clear(self.Drawings)

    for _, inst in ipairs(self.Instances) do
        pcall(function()
            if inst and inst.Parent then
                inst:Destroy()
            end
        end)
    end
    table.clear(self.Instances)

    -- Restore safe character defaults
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
                hum.PlatformStand = false
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end)
end

-- Clean previous instance if re-executed
pcall(function()
    local parent = Env.GetGuiParent()
    local existing = parent:FindFirstChild("BimSakSinHub_v3")
    if existing then
        existing:Destroy()
    end
end)

-- ============================================================================
-- 3. CONFIG & STATE MANAGER (JSON PERSISTENCE)
-- ============================================================================
local DefaultConfig = {
    -- Visual & UI
    AccentPreset = "RoyalGold",
    WindowOpacity = 0.06,
    Language = "auto",
    MaskIP = false,
    ToggleKey = "RightShift",

    -- Defense & Utility
    AntiAFK = true,
    AntiRagdoll = false,
    AntiFling = false,
    AntiVoid = false,
    AutoHeal = false,
    SelectedEmote = "Wave",

    -- Unlimited Movement
    WalkSpeedEnabled = false,
    WalkSpeedValue = 32,
    JumpPowerEnabled = false,
    JumpPowerValue = 75,
    FlyEnabled = false,
    FlySpeedValue = 120,
    NoclipEnabled = false,
    InfiniteJumpEnabled = false,

    -- Combat (Aimbot)
    AimbotEnabled = false,
    AimbotFOVVisible = true,
    AimbotFOV = 140,
    AimbotSmoothness = 0.22,
    AimbotTargetPart = "Head",
    AimbotTeamCheck = true,
    AimbotWallCheck = false,

    -- Visuals (ESP)
    ESPEnabled = false,
    ESPBox = true,
    ESPName = true,
    ESPHealth = true,
    ESPTracers = false,
    ESPChams = true,
    ESPTeamCheck = false,
    ESPMaxDistance = 2500,

    -- Teleport
    CtrlClickTP = false
}

local State = {}
for k, v in pairs(DefaultConfig) do
    State[k] = v
end

local ConfigManager = {
    Folder = "BimSakSinHub",
    FilePath = "BimSakSinHub/config_v3.json"
}

function ConfigManager:Save()
    if not Env.HasFileIO then
        return false, "File I/O unavailable in executor"
    end
    local ok, err = pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder(self.Folder) then
                makefolder(self.Folder)
            end
        end
        local encoded = Services.HttpService:JSONEncode(State)
        writefile(self.FilePath, encoded)
    end)
    return ok, err
end

function ConfigManager:Load()
    if not Env.HasFileIO then
        return false
    end
    local ok, decoded = pcall(function()
        if isfile(self.FilePath) then
            local raw = readfile(self.FilePath)
            return Services.HttpService:JSONDecode(raw)
        end
        return nil
    end)
    if ok and type(decoded) == "table" then
        for key, defaultVal in pairs(DefaultConfig) do
            if decoded[key] ~= nil and type(decoded[key]) == type(defaultVal) then
                State[key] = decoded[key]
            else
                State[key] = defaultVal
            end
        end
        return true
    end
    return false
end

function ConfigManager:Reset()
    for key, defaultVal in pairs(DefaultConfig) do
        State[key] = defaultVal
    end
    self:Save()
end

ConfigManager:Load()

-- ============================================================================
-- 4. GEOLANG API (REAL-TIME IP/LOCATION + 16 GLOBAL LANGUAGES)
-- ============================================================================
local GeoLangAPI = {
    CurrentLang = "en",
    GeoData = {
        IP = "Detecting...",
        City = "Unknown",
        Region = "",
        Country = "Global",
        CountryCode = "US",
        ISP = "Unknown",
        Status = "Syncing"
    },
    BoundElements = {},
    OnGeoUpdated = {}
}

GeoLangAPI.LanguageNames = {
    { Code = "auto", Label = "Auto-Detect (GeoIP)" },
    { Code = "en",   Label = "English (EN)" },
    { Code = "id",   Label = "Bahasa Indonesia (ID)" },
    { Code = "es",   Label = "Español (ES)" },
    { Code = "pt",   Label = "Português (PT)" },
    { Code = "ru",   Label = "Русский (RU)" },
    { Code = "zh",   Label = "中文 (ZH)" },
    { Code = "ja",   Label = "日本語 (JA)" },
    { Code = "ko",   Label = "한국어 (KO)" },
    { Code = "ar",   Label = "العربية (AR)" },
    { Code = "fr",   Label = "Français (FR)" },
    { Code = "de",   Label = "Deutsch (DE)" },
    { Code = "tr",   Label = "Türkçe (TR)" },
    { Code = "vi",   Label = "Tiếng Việt (VI)" },
    { Code = "th",   Label = "ภาษาไทย (TH)" },
    { Code = "ms",   Label = "Bahasa Melayu (MS)" },
    { Code = "hi",   Label = "हिन्दी (HI)" }
}

GeoLangAPI.CountryToLang = {
    ID = "id",
    MY = "ms", BN = "ms", SG = "en",
    ES = "es", MX = "es", AR = "es", CO = "es", CL = "es", PE = "es",
    BR = "pt", PT = "pt",
    RU = "ru", BY = "ru", KZ = "ru",
    CN = "zh", TW = "zh", HK = "zh",
    JP = "ja",
    KR = "ko",
    SA = "ar", AE = "ar", EG = "ar", IQ = "ar", MA = "ar", QA = "ar", KW = "ar",
    FR = "fr", BE = "fr", CH = "fr",
    DE = "de", AT = "de",
    TR = "tr",
    VN = "vi",
    TH = "th",
    IN = "hi"
}

GeoLangAPI.Translations = {
    en = {
        TabMain = "Main & Defense",
        TabMovement = "Movement",
        TabCombat = "Combat",
        TabVisuals = "Visuals",
        TabTeleport = "Teleport",
        TabSettings = "Settings",
        SecDefense = "Character Defense & Protection",
        SecEmote = "Emote Replicator",
        SecSpeed = "Unlimited Speed & Physics (No Cap)",
        SecFlight = "6-DOF Flight & Traversal",
        SecAimbot = "Precision Aimbot Controller",
        SecESP = "3D / 2D ESP Overlay Suite",
        SecTPPlayer = "Player Teleportation & Spectate",
        SecTPWaypoints = "Coordinate Waypoints & Click-TP",
        SecLangGeo = "Language & Real-Time Geolocation API",
        SecTheme = "Luxury 3D Skull Theme & Config",
        SecSystem = "System Lifecycle & Cleanup",
        AntiAFK = "Anti-AFK Idle Bypass",
        AntiRagdoll = "Anti-Ragdoll & Knockback Guard",
        AntiFling = "Anti-Fling Velocity Shield",
        AntiVoid = "Anti-Void Auto Recovery",
        AutoHeal = "Character Stability Regen",
        PlayEmote = "Play Selected Emote",
        StopEmote = "Stop Emote",
        EnableWalkSpeed = "Enable Custom WalkSpeed",
        WalkSpeedInput = "WalkSpeed Value (Unlimited)",
        EnableJumpPower = "Enable Custom JumpPower",
        JumpPowerInput = "JumpPower Value (Unlimited)",
        EnableFly = "Enable Smooth Fly (WASD + Space/Ctrl)",
        FlySpeedInput = "Fly Speed Value (Unlimited)",
        EnableNoclip = "Enable Noclip (Phase Walls)",
        EnableInfJump = "Enable Infinite Jump",
        ResetPhysics = "Reset Physics to Default (16 / 50)",
        EnableAimbot = "Enable Aimbot (Hold Right-Click)",
        ShowFOV = "Show FOV Circle",
        AimFOV = "Aimbot FOV Radius",
        AimSmooth = "Aimbot Smoothness",
        TeamCheck = "Ignore Teammates",
        WallCheck = "Visibility Wall Check",
        EnableESP = "Master ESP Switch",
        BoxESP = "2D Bounding Box",
        NameESP = "Player Name & Distance",
        HealthESP = "Dynamic Health Bar",
        TracerESP = "Bottom Screen Tracers",
        ChamsESP = "3D Highlight Chams",
        ESPDist = "Max ESP Distance (Studs)",
        TPToPlayer = "Teleport to Selected Player",
        SpectatePlayer = "Spectate Selected Player",
        RefreshPlayers = "Refresh Player List",
        SaveWaypoint = "Save Current Position",
        LoadWaypoint = "Teleport to Saved Position",
        CtrlClickTP = "Ctrl + Left-Click Teleport",
        SelectLanguage = "Interface Language (16 Languages)",
        AutoDetectLang = "Re-Sync Language from IP",
        MaskIPToggle = "Mask Public IP Address",
        RefreshGeo = "Refresh Real-Time Geolocation",
        SaveConfig = "Save JSON Config",
        LoadConfig = "Load JSON Config",
        ResetConfig = "Reset Default Config",
        UnloadHub = "UNLOAD HUB & CLEANUP SYSTEM"
    },
    id = {
        TabMain = "Utama & Pertahanan",
        TabMovement = "Pergerakan",
        TabCombat = "Tempur",
        TabVisuals = "Visual ESP",
        TabTeleport = "Teleportasi",
        TabSettings = "Pengaturan",
        SecDefense = "Pertahanan & Perlindungan Karakter",
        SecEmote = "Replikator Emote Universal",
        SecSpeed = "Kecepatan & Fisika Tanpa Batas (No Limit)",
        SecFlight = "Terbang 6-DOF & Penjelajahan",
        SecAimbot = "Kontroler Aimbot Presisi",
        SecESP = "Paket Overlay ESP 3D / 2D",
        SecTPPlayer = "Teleportasi & Pantau Pemain",
        SecTPWaypoints = "Titik Koordinat & Klik-TP",
        SecLangGeo = "Bahasa & API Geolokasi Real-Time",
        SecTheme = "Tema Tengkorak 3D Mewah & Konfigurasi",
        SecSystem = "Siklus Sistem & Pembersihan",
        AntiAFK = "Anti-AFK (Anti Kick Diam)",
        AntiRagdoll = "Anti-Ragdoll & Anti Terjatuh",
        AntiFling = "Perisai Anti-Fling Kecepatan",
        AntiVoid = "Anti-Void Penyelamat Jurang",
        AutoHeal = "Stabilitas Kesehatan Karakter",
        PlayEmote = "Jalankan Emote Terpilih",
        StopEmote = "Hentikan Emote",
        EnableWalkSpeed = "Aktifkan WalkSpeed Kustom",
        WalkSpeedInput = "Nilai WalkSpeed (Tanpa Batas)",
        EnableJumpPower = "Aktifkan JumpPower Kustom",
        JumpPowerInput = "Nilai JumpPower (Tanpa Batas)",
        EnableFly = "Aktifkan Terbang Bebas (WASD + Spasi/Ctrl)",
        FlySpeedInput = "Kecepatan Terbang (Tanpa Batas)",
        EnableNoclip = "Aktifkan Noclip (Tembus Dinding)",
        EnableInfJump = "Aktifkan Lompat Tanpa Batas",
        ResetPhysics = "Reset Fisika ke Standar (16 / 50)",
        EnableAimbot = "Aktifkan Aimbot (Tahan Klik Kanan)",
        ShowFOV = "Tampilkan Lingkaran FOV",
        AimFOV = "Radius FOV Aimbot",
        AimSmooth = "Kehalusan Aimbot",
        TeamCheck = "Abaikan Satu Tim",
        WallCheck = "Cek Dinding Penghalang",
        EnableESP = "Saklar Utama ESP",
        BoxESP = "Kotak 2D Pemain",
        NameESP = "Nama & Jarak Pemain",
        HealthESP = "Bar Darah Dinamis",
        TracerESP = "Garis Pelacak Pemain",
        ChamsESP = "Sorotan 3D Chams",
        ESPDist = "Jarak Maksimal ESP (Studs)",
        TPToPlayer = "Teleport ke Pemain Terpilih",
        SpectatePlayer = "Pantau Kamera Pemain",
        RefreshPlayers = "Segarkan Daftar Pemain",
        SaveWaypoint = "Simpan Posisi Saat Ini",
        LoadWaypoint = "Teleport ke Posisi Tersimpan",
        CtrlClickTP = "Ctrl + Klik Kiri untuk Teleport",
        SelectLanguage = "Bahasa Antarmuka (16 Bahasa)",
        AutoDetectLang = "Sinkron Otomatis dari IP",
        MaskIPToggle = "Sembunyikan Alamat IP Publik",
        RefreshGeo = "Segarkan Lokasi & IP Real-Time",
        SaveConfig = "Simpan Konfigurasi JSON",
        LoadConfig = "Muat Konfigurasi JSON",
        ResetConfig = "Reset Konfigurasi Awal",
        UnloadHub = "TUTUP HUB & BERSIHKAN SISTEM"
    },
    es = {
        TabMain = "Principal", TabMovement = "Movimiento", TabCombat = "Combate",
        TabVisuals = "Visuales", TabTeleport = "Teletransporte", TabSettings = "Ajustes",
        SecDefense = "Defensa del Personaje", SecEmote = "Replicador de Emotes",
        SecSpeed = "Velocidad y Física Sin Límites", SecFlight = "Vuelo 6-DOF y Travesía",
        SecAimbot = "Controlador Aimbot", SecESP = "Suite Visual ESP 3D/2D",
        SecTPPlayer = "Teletransporte a Jugadores", SecTPWaypoints = "Puntos Guardados y Click-TP",
        SecLangGeo = "Idioma y API Geolocalización", SecTheme = "Tema Calavera 3D y Config",
        SecSystem = "Limpieza del Sistema",
        AntiAFK = "Anti-AFK Activo", AntiRagdoll = "Protección Anti-Ragdoll",
        AntiFling = "Escudo Anti-Fling", AntiVoid = "Recuperación Anti-Vacío",
        AutoHeal = "Estabilidad de Personaje", PlayEmote = "Reproducir Emote",
        StopEmote = "Detener Emote", EnableWalkSpeed = "Activar WalkSpeed",
        WalkSpeedInput = "Valor WalkSpeed (Sin Límite)", EnableJumpPower = "Activar JumpPower",
        JumpPowerInput = "Valor JumpPower (Sin Límite)", EnableFly = "Activar Vuelo Libre",
        FlySpeedInput = "Velocidad de Vuelo (Sin Límite)", EnableNoclip = "Activar Noclip",
        EnableInfJump = "Salto Infinito", ResetPhysics = "Restablecer Física (16 / 50)",
        EnableAimbot = "Activar Aimbot (Clic Derecho)", ShowFOV = "Mostrar Círculo FOV",
        AimFOV = "Radio FOV", AimSmooth = "Suavizado Aimbot", TeamCheck = "Ignorar Equipo",
        WallCheck = "Comprobar Paredes", EnableESP = "Interruptor Maestro ESP",
        BoxESP = "Caja 2D", NameESP = "Nombre y Distancia", HealthESP = "Barra de Salud",
        TracerESP = "Líneas Trazadoras", ChamsESP = "Resaltado 3D Chams",
        ESPDist = "Distancia Máx ESP", TPToPlayer = "Teletransportar al Jugador",
        SpectatePlayer = "Espectar Jugador", RefreshPlayers = "Actualizar Lista",
        SaveWaypoint = "Guardar Posición", LoadWaypoint = "Ir a Posición Guardada",
        CtrlClickTP = "Ctrl + Clic para Teletransportar", SelectLanguage = "Idioma (16 Idiomas)",
        AutoDetectLang = "Detectar por IP", MaskIPToggle = "Ocultar IP Pública",
        RefreshGeo = "Actualizar Geolocalización", SaveConfig = "Guardar Config JSON",
        LoadConfig = "Cargar Config JSON", ResetConfig = "Restablecer Config",
        UnloadHub = "DESCARGAR HUB Y LIMPIAR SISTEMA"
    },
    pt = {
        TabMain = "Principal", TabMovement = "Movimento", TabCombat = "Combate",
        TabVisuals = "Visuais", TabTeleport = "Teleporte", TabSettings = "Configurações",
        SecDefense = "Defesa do Personagem", SecEmote = "Replicador de Emotes",
        SecSpeed = "Velocidade e Física Sem Limites", SecFlight = "Voo 6-DOF e Travessia",
        SecAimbot = "Controlador Aimbot", SecESP = "Pacote Visual ESP 3D/2D",
        SecTPPlayer = "Teleporte para Jogadores", SecTPWaypoints = "Pontos Salvos e Click-TP",
        SecLangGeo = "Idioma e API Geolocalização", SecTheme = "Tema Caveira 3D e Config",
        SecSystem = "Limpeza do Sistema",
        AntiAFK = "Anti-AFK Ativo", AntiRagdoll = "Proteção Anti-Ragdoll",
        AntiFling = "Escudo Anti-Fling", AntiVoid = "Recuperação Anti-Void",
        AutoHeal = "Estabilidade do Personagem", PlayEmote = "Executar Emote",
        StopEmote = "Parar Emote", EnableWalkSpeed = "Ativar WalkSpeed",
        WalkSpeedInput = "Valor WalkSpeed (Sem Limite)", EnableJumpPower = "Ativar JumpPower",
        JumpPowerInput = "Valor JumpPower (Sem Limite)", EnableFly = "Ativar Voo Livre",
        FlySpeedInput = "Velocidade de Voo (Sem Limite)", EnableNoclip = "Ativar Noclip",
        EnableInfJump = "Pulo Infinito", ResetPhysics = "Resetar Física (16 / 50)",
        EnableAimbot = "Ativar Aimbot (Botão Direito)", ShowFOV = "Mostrar Círculo FOV",
        AimFOV = "Raio FOV", AimSmooth = "Suavidade Aimbot", TeamCheck = "Ignorar Equipe",
        WallCheck = "Verificar Paredes", EnableESP = "Chave Geral ESP",
        BoxESP = "Caixa 2D", NameESP = "Nome e Distância", HealthESP = "Barra de Vida",
        TracerESP = "Linhas Rastreadoras", ChamsESP = "Destaque 3D Chams",
        ESPDist = "Distância Máx ESP", TPToPlayer = "Teleportar ao Jogador",
        SpectatePlayer = "Espectar Jogador", RefreshPlayers = "Atualizar Lista",
        SaveWaypoint = "Salvar Posição Atual", LoadWaypoint = "Ir para Posição Salva",
        CtrlClickTP = "Ctrl + Clique para Teleportar", SelectLanguage = "Idioma (16 Idiomas)",
        AutoDetectLang = "Sincronizar por IP", MaskIPToggle = "Ocultar IP Público",
        RefreshGeo = "Atualizar Geolocalização", SaveConfig = "Salvar Config JSON",
        LoadConfig = "Carregar Config JSON", ResetConfig = "Resetar Config",
        UnloadHub = "DESCARREGAR HUB E LIMPAR SISTEMA"
    },
    ru = {
        TabMain = "Главная", TabMovement = "Движение", TabCombat = "Бой",
        TabVisuals = "Визуалы", TabTeleport = "Телепорт", TabSettings = "Настройки",
        SecDefense = "Защита Персонажа", SecEmote = "Репликатор Эмоций",
        SecSpeed = "Безлимитная Скорость и Физика", SecFlight = "Полёт 6-DOF",
        SecAimbot = "Контроллер Аимбота", SecESP = "3D/2D ESP Оверлей",
        SecTPPlayer = "Телепорт к Игрокам", SecTPWaypoints = "Точки и Клик-ТП",
        SecLangGeo = "Язык и Геолокация API", SecTheme = "3D Череп и Конфиг",
        SecSystem = "Очистка Системы",
        AntiAFK = "Анти-АФК", AntiRagdoll = "Анти-Рэгдолл",
        AntiFling = "Щит Анти-Флинг", AntiVoid = "Защита от Пустоты",
        AutoHeal = "Стабильность Персонажа", PlayEmote = "Запустить Эмоцию",
        StopEmote = "Остановить Эмоцию", EnableWalkSpeed = "Включить WalkSpeed",
        WalkSpeedInput = "Скорость Бега (Без лимита)", EnableJumpPower = "Включить JumpPower",
        JumpPowerInput = "Сила Прыжка (Без лимита)", EnableFly = "Включить Полёт",
        FlySpeedInput = "Скорость Полёта (Без лимита)", EnableNoclip = "Включить Ноуклип",
        EnableInfJump = "Бесконечный Прыжок", ResetPhysics = "Сбросить Физику (16 / 50)",
        EnableAimbot = "Включить Аимбот (ПКМ)", ShowFOV = "Показать Круг FOV",
        AimFOV = "Радиус FOV", AimSmooth = "Плавность Аимбота", TeamCheck = "Проверка Команды",
        WallCheck = "Проверка Стен", EnableESP = "Главный Переключатель ESP",
        BoxESP = "2D Рамка", NameESP = "Имя и Дистанция", HealthESP = "Полоса Здоровья",
        TracerESP = "Линии к Игрокам", ChamsESP = "3D Подсветка Chams",
        ESPDist = "Макс. Дистанция ESP", TPToPlayer = "Телепорт к Игроку",
        SpectatePlayer = "Наблюдать за Игроком", RefreshPlayers = "Обновить Список",
        SaveWaypoint = "Сохранить Позицию", LoadWaypoint = "Телепорт к Точке",
        CtrlClickTP = "Ctrl + ЛКМ Телепорт", SelectLanguage = "Язык (16 языков)",
        AutoDetectLang = "Автоопределение по IP", MaskIPToggle = "Скрыть Публичный IP",
        RefreshGeo = "Обновить Геолокацию", SaveConfig = "Сохранить JSON",
        LoadConfig = "Загрузить JSON", ResetConfig = "Сбросить Конфиг",
        UnloadHub = "ВЫГРУЗИТЬ ХАБ И ОЧИСТИТЬ"
    },
    zh = {
        TabMain = "主页与防御", TabMovement = "移动系统", TabCombat = "战斗辅助",
        TabVisuals = "透视视觉", TabTeleport = "传送功能", TabSettings = "系统设置",
        SecDefense = "角色防御与保护", SecEmote = "动作表情复制器",
        SecSpeed = "无限制速度与物理引擎", SecFlight = "六自由度飞行与穿墙",
        SecAimbot = "精准自瞄控制器", SecESP = "3D/2D 透视套件",
        SecTPPlayer = "玩家传送与观战", SecTPWaypoints = "坐标传送点与点击传送",
        SecLangGeo = "语言与实时IP定位API", SecTheme = "奢华3D骷髅主题与配置",
        SecSystem = "系统生命周期与清理",
        AntiAFK = "防挂机踢出 (Anti-AFK)", AntiRagdoll = "防布娃娃击倒",
        AntiFling = "防甩飞护盾", AntiVoid = "防掉入虚空保护",
        AutoHeal = "角色状态稳定", PlayEmote = "播放选定动作",
        StopEmote = "停止动作", EnableWalkSpeed = "启用自定义移动速度",
        WalkSpeedInput = "移动速度数值 (无上限)", EnableJumpPower = "启用自定义跳跃高度",
        JumpPowerInput = "跳跃高度数值 (无上限)", EnableFly = "启用自由飞行",
        FlySpeedInput = "飞行速度数值 (无上限)", EnableNoclip = "启用穿墙模式",
        EnableInfJump = "启用无限跳跃", ResetPhysics = "重置默认物理 (16 / 50)",
        EnableAimbot = "启用自瞄 (按住右键)", ShowFOV = "显示FOV范围圈",
        AimFOV = "自瞄FOV半径", AimSmooth = "自瞄平滑度", TeamCheck = "忽略队友",
        WallCheck = "障碍物检测", EnableESP = "ESP总开关",
        BoxESP = "2D方框透视", NameESP = "玩家名称与距离", HealthESP = "动态血条",
        TracerESP = "屏幕射线追踪", ChamsESP = "3D高亮透视",
        ESPDist = "最大ESP距离", TPToPlayer = "传送到选定玩家",
        SpectatePlayer = "观战选定玩家", RefreshPlayers = "刷新玩家列表",
        SaveWaypoint = "保存当前坐标", LoadWaypoint = "传送到保存坐标",
        CtrlClickTP = "Ctrl + 左键点击传送", SelectLanguage = "界面语言 (16种语言)",
        AutoDetectLang = "根据IP自动匹配语言", MaskIPToggle = "隐藏公网IP地址",
        RefreshGeo = "刷新实时地理位置", SaveConfig = "保存JSON配置",
        LoadConfig = "加载JSON配置", ResetConfig = "重置默认配置",
        UnloadHub = "卸载面板并清理系统"
    },
    ja = {
        TabMain = "メイン・防御", TabMovement = "移動・物理", TabCombat = "戦闘",
        TabVisuals = "視覚ESP", TabTeleport = "テレポート", TabSettings = "設定",
        SecDefense = "キャラクター防御システム", SecEmote = "エモート再生",
        SecSpeed = "無制限スピード＆物理演算", SecFlight = "自由飛行＆すり抜け",
        SecAimbot = "エイムボット制御", SecESP = "3D/2D ESPオーバーレイ",
        SecTPPlayer = "プレイヤー移動・観戦", SecTPWaypoints = "座標保存＆クリック移動",
        SecLangGeo = "言語＆リアルタイムIP位置情報", SecTheme = "3Dスカルテーマ＆設定",
        SecSystem = "システム終了・クリーンアップ",
        AntiAFK = "放置キック防止 (Anti-AFK)", AntiRagdoll = "ラグドール防止",
        AntiFling = "吹き飛ばし防止シールド", AntiVoid = "奈落落下防止",
        AutoHeal = "キャラクター安定化", PlayEmote = "エモート再生",
        StopEmote = "エモート停止", EnableWalkSpeed = "移動速度変更を有効化",
        WalkSpeedInput = "移動速度 (上限なし)", EnableJumpPower = "ジャンプ力変更を有効化",
        JumpPowerInput = "ジャンプ力 (上限なし)", EnableFly = "フライ飛行を有効化",
        FlySpeedInput = "飛行速度 (上限なし)", EnableNoclip = "壁すり抜け (Noclip)",
        EnableInfJump = "無限ジャンプ", ResetPhysics = "物理設定を初期化 (16 / 50)",
        EnableAimbot = "エイムボット (右クリック長押し)", ShowFOV = "FOV円を表示",
        AimFOV = "FOV半径", AimSmooth = "エイム滑らかさ", TeamCheck = "味方を除外",
        WallCheck = "壁判定チェック", EnableESP = "ESPマスタースイッチ",
        BoxESP = "2Dボックス", NameESP = "名前と距離", HealthESP = "体力バー",
        TracerESP = "トレーサー線", ChamsESP = "3DハイライトChams",
        ESPDist = "ESP最大距離", TPToPlayer = "選択プレイヤーへ移動",
        SpectatePlayer = "プレイヤーを観戦", RefreshPlayers = "リスト更新",
        SaveWaypoint = "現在位置を保存", LoadWaypoint = "保存位置へ移動",
        CtrlClickTP = "Ctrl + クリックで移動", SelectLanguage = "表示言語 (16言語対応)",
        AutoDetectLang = "IPから言語を自動同期", MaskIPToggle = "IPアドレスを隠す",
        RefreshGeo = "位置情報を再取得", SaveConfig = "JSON設定を保存",
        LoadConfig = "JSON設定を読込", ResetConfig = "初期設定に戻す",
        UnloadHub = "ハブを終了してシステム清掃"
    },
    ko = {
        TabMain = "메인 및 방어", TabMovement = "이동", TabCombat = "전투",
        TabVisuals = "시각 ESP", TabTeleport = "텔레포트", TabSettings = "설정",
        SecDefense = "캐릭터 방어 및 보호", SecEmote = "이모트 리플리케이터",
        SecSpeed = "무제한 속도 및 물리 엔진", SecFlight = "자유 비행 및 노클립",
        SecAimbot = "에임봇 컨트롤러", SecESP = "3D/2D ESP 오버레이",
        SecTPPlayer = "플레이어 텔레포트 및 관전", SecTPWaypoints = "좌표 저장 및 클릭 이동",
        SecLangGeo = "언어 및 실시간 IP 위치 API", SecTheme = "럭셔리 3D 해골 테마",
        SecSystem = "시스템 종료 및 정리",
        AntiAFK = "자리비움 방지 (Anti-AFK)", AntiRagdoll = "래그돌 방지",
        AntiFling = "날아감 방지 실드", AntiVoid = "공허 추락 방지",
        AutoHeal = "캐릭터 상태 유지", PlayEmote = "이모트 실행",
        StopEmote = "이모트 중지", EnableWalkSpeed = "이동 속도 활성화",
        WalkSpeedInput = "이동 속도 값 (무제한)", EnableJumpPower = "점프력 활성화",
        JumpPowerInput = "점프력 값 (무제한)", EnableFly = "플라이 비행 활성화",
        FlySpeedInput = "비행 속도 값 (무제한)", EnableNoclip = "벽 통과 (Noclip)",
        EnableInfJump = "무한 점프", ResetPhysics = "물리 기본값 복원 (16 / 50)",
        EnableAimbot = "에임봇 활성화 (우클릭 유지)", ShowFOV = "FOV 원 표시",
        AimFOV = "FOV 반경", AimSmooth = "에임 부드러움", TeamCheck = "팀원 제외",
        WallCheck = "벽 감지 확인", EnableESP = "ESP 마스터 스위치",
        BoxESP = "2D 박스", NameESP = "이름 및 거리", HealthESP = "체력 바",
        TracerESP = "트레이서 선", ChamsESP = "3D 하이라이트 Chams",
        ESPDist = "최대 ESP 거리", TPToPlayer = "선택 플레이어로 이동",
        SpectatePlayer = "플레이어 관전", RefreshPlayers = "목록 새로고침",
        SaveWaypoint = "현재 위치 저장", LoadWaypoint = "저장된 위치로 이동",
        CtrlClickTP = "Ctrl + 클릭 텔레포트", SelectLanguage = "인터페이스 언어 (16개국어)",
        AutoDetectLang = "IP 기반 자동 언어 동기화", MaskIPToggle = "공인 IP 주소 가리기",
        RefreshGeo = "실시간 위치 새로고침", SaveConfig = "JSON 설정 저장",
        LoadConfig = "JSON 설정 불러오기", ResetConfig = "기본 설정 초기화",
        UnloadHub = "허브 종료 및 시스템 정리"
    },
    ar = {
        TabMain = "الرئيسية", TabMovement = "الحركة", TabCombat = "القتال",
        TabVisuals = "الرؤية ESP", TabTeleport = "الانتقال", TabSettings = "الإعدادات",
        SecDefense = "حماية الشخصية", SecEmote = "مشغل الحركات",
        SecSpeed = "سرعة وفيزياء بلا حدود", SecFlight = "الطيران الحر",
        SecAimbot = "التصويب التلقائي", SecESP = "نظام كشف اللاعبين",
        SecTPPlayer = "الانتقال للاعبين", SecTPWaypoints = "حفظ الإحداثيات",
        SecLangGeo = "اللغة وتحديد الموقع IP", SecTheme = "تصميم الجمجمة 3D",
        SecSystem = "تنظيف النظام",
        AntiAFK = "منع الطرد التلقائي", AntiRagdoll = "منع السقوط",
        AntiFling = "درع منع القذف", AntiVoid = "الحماية من الفراغ",
        AutoHeal = "استقرار الشخصية", PlayEmote = "تشغيل الحركة",
        StopEmote = "إيقاف الحركة", EnableWalkSpeed = "تفعيل سرعة المشي",
        WalkSpeedInput = "قيمة السرعة (بلا حدود)", EnableJumpPower = "تفعيل قوة القفز",
        JumpPowerInput = "قيمة القفز (بلا حدود)", EnableFly = "تفعيل الطيران",
        FlySpeedInput = "سرعة الطيران (بلا حدود)", EnableNoclip = "اختراق الجدران",
        EnableInfJump = "قفز لا نهائي", ResetPhysics = "إعادة ضبط الفيزياء",
        EnableAimbot = "تفعيل التصويب", ShowFOV = "إظهار دائرة FOV",
        AimFOV = "نطاق FOV", AimSmooth = "نعومة التصويب", TeamCheck = "تجاهل الفريق",
        WallCheck = "فحص الجدران", EnableESP = "تشغيل ESP",
        BoxESP = "مربع 2D", NameESP = "الاسم والمسافة", HealthESP = "شريط الصحة",
        TracerESP = "خطوط التتبع", ChamsESP = "إبراز 3D",
        ESPDist = "أقصى مسافة ESP", TPToPlayer = "انتقال للاعب",
        SpectatePlayer = "مراقبة اللاعب", RefreshPlayers = "تحديث القائمة",
        SaveWaypoint = "حفظ الموقع الحالي", LoadWaypoint = "الانتقال للموقع المحفوظ",
        CtrlClickTP = "Ctrl + نقر للانتقال", SelectLanguage = "اللغة (16 لغة)",
        AutoDetectLang = "تحديد تلقائي عبر IP", MaskIPToggle = "إخفاء عنوان IP",
        RefreshGeo = "تحديث الموقع الجغرافي", SaveConfig = "حفظ الإعدادات JSON",
        LoadConfig = "تحميل الإعدادات", ResetConfig = "إعادة الضبط",
        UnloadHub = "إغلاق وتنظيف النظام"
    },
    fr = {
        TabMain = "Défense", TabMovement = "Mouvement", TabCombat = "Combat",
        TabVisuals = "Visuels", TabTeleport = "Téléportation", TabSettings = "Paramètres",
        SecDefense = "Défense du Personnage", SecEmote = "Réplicateur d'Emotes",
        SecSpeed = "Vitesse & Physique Illimitées", SecFlight = "Vol 6-DOF & Traversée",
        SecAimbot = "Contrôleur Aimbot", SecESP = "Suite Visuelle ESP 3D/2D",
        SecTPPlayer = "Téléportation Joueurs", SecTPWaypoints = "Points Sauvegardés",
        SecLangGeo = "Langue & API Géolocalisation", SecTheme = "Thème Crâne 3D & Config",
        SecSystem = "Nettoyage Système",
        AntiAFK = "Anti-AFK Actif", AntiRagdoll = "Protection Anti-Ragdoll",
        AntiFling = "Bouclier Anti-Fling", AntiVoid = "Protection Anti-Vide",
        AutoHeal = "Stabilité Personnage", PlayEmote = "Jouer l'Emote",
        StopEmote = "Arrêter l'Emote", EnableWalkSpeed = "Activer WalkSpeed",
        WalkSpeedInput = "Valeur WalkSpeed (Illimité)", EnableJumpPower = "Activer JumpPower",
        JumpPowerInput = "Valeur JumpPower (Illimité)", EnableFly = "Activer Vol Libre",
        FlySpeedInput = "Vitesse de Vol (Illimité)", EnableNoclip = "Activer Noclip",
        EnableInfJump = "Saut Infini", ResetPhysics = "Réinitialiser Physique (16 / 50)",
        EnableAimbot = "Activer Aimbot (Clic Droit)", ShowFOV = "Afficher Cercle FOV",
        AimFOV = "Rayon FOV", AimSmooth = "Fluidité Aimbot", TeamCheck = "Ignorer Équipe",
        WallCheck = "Vérification Murs", EnableESP = "Interrupteur Principal ESP",
        BoxESP = "Boîte 2D", NameESP = "Nom & Distance", HealthESP = "Barre de Vie",
        TracerESP = "Lignes Traceurs", ChamsESP = "Surbrillance 3D Chams",
        ESPDist = "Distance Max ESP", TPToPlayer = "Téléporter au Joueur",
        SpectatePlayer = "Observer le Joueur", RefreshPlayers = "Actualiser Liste",
        SaveWaypoint = "Sauvegarder Position", LoadWaypoint = "Aller à la Position",
        CtrlClickTP = "Ctrl + Clic Téléportation", SelectLanguage = "Langue (16 Langues)",
        AutoDetectLang = "Synchroniser via IP", MaskIPToggle = "Masquer IP Publique",
        RefreshGeo = "Actualiser Géolocalisation", SaveConfig = "Sauvegarder JSON",
        LoadConfig = "Charger JSON", ResetConfig = "Réinitialiser Config",
        UnloadHub = "DÉCHARGER LE HUB & NETTOYER"
    },
    de = {
        TabMain = "Schutz", TabMovement = "Bewegung", TabCombat = "Kampf",
        TabVisuals = "Visuell", TabTeleport = "Teleport", TabSettings = "Einstellungen",
        SecDefense = "Charakterschutz", SecEmote = "Emote-Replikator",
        SecSpeed = "Unbegrenzte Geschwindigkeit", SecFlight = "6-DOF Flug & Noclip",
        SecAimbot = "Aimbot-Steuerung", SecESP = "3D/2D ESP Overlay",
        SecTPPlayer = "Spieler-Teleport", SecTPWaypoints = "Wegpunkte & Klick-TP",
        SecLangGeo = "Sprache & Echtzeit-GeoIP", SecTheme = "3D-Schädel-Design & Config",
        SecSystem = "Systembereinigung",
        AntiAFK = "Anti-AFK Schutz", AntiRagdoll = "Anti-Ragdoll",
        AntiFling = "Anti-Fling Schild", AntiVoid = "Anti-Void Rettung",
        AutoHeal = "Charakterstabilität", PlayEmote = "Emote Abspielen",
        StopEmote = "Emote Stoppen", EnableWalkSpeed = "WalkSpeed Aktivieren",
        WalkSpeedInput = "WalkSpeed Wert (Unbegrenzt)", EnableJumpPower = "JumpPower Aktivieren",
        JumpPowerInput = "JumpPower Wert (Unbegrenzt)", EnableFly = "Flug Aktivieren",
        FlySpeedInput = "Fluggeschwindigkeit (Unbegrenzt)", EnableNoclip = "Noclip Aktivieren",
        EnableInfJump = "Unendlicher Sprung", ResetPhysics = "Physik Zurücksetzen (16 / 50)",
        EnableAimbot = "Aimbot (Rechtsklick halten)", ShowFOV = "FOV-Kreis Anzeigen",
        AimFOV = "FOV-Radius", AimSmooth = "Aimbot-Glättung", TeamCheck = "Team Ignorieren",
        WallCheck = "Wandprüfung", EnableESP = "ESP Hauptschalter",
        BoxESP = "2D Box", NameESP = "Name & Distanz", HealthESP = "Lebensbalken",
        TracerESP = "Tracer-Linien", ChamsESP = "3D Chams Hervorhebung",
        ESPDist = "Max. ESP-Distanz", TPToPlayer = "Zum Spieler Teleportieren",
        SpectatePlayer = "Spieler Beobachten", RefreshPlayers = "Liste Aktualisieren",
        SaveWaypoint = "Position Speichern", LoadWaypoint = "Zur Position Teleportieren",
        CtrlClickTP = "Strg + Klick Teleport", SelectLanguage = "Sprache (16 Sprachen)",
        AutoDetectLang = "Über IP Erkennen", MaskIPToggle = "Öffentliche IP Verbergen",
        RefreshGeo = "Standort Aktualisieren", SaveConfig = "JSON Speichern",
        LoadConfig = "JSON Laden", ResetConfig = "Zurücksetzen",
        UnloadHub = "HUB ENTLADEN & BEREINIGEN"
    },
    tr = {
        TabMain = "Savunma", TabMovement = "Hareket", TabCombat = "Savaş",
        TabVisuals = "Görsel ESP", TabTeleport = "Işınlanma", TabSettings = "Ayarlar",
        SecDefense = "Karakter Koruması", SecEmote = "Emote Oynatıcı",
        SecSpeed = "Sınırsız Hız ve Fizik", SecFlight = "Serbest Uçuş ve Noclip",
        SecAimbot = "Aimbot Kontrolcüsü", SecESP = "3D/2D ESP Paketi",
        SecTPPlayer = "Oyuncuya Işınlanma", SecTPWaypoints = "Konum Kaydetme",
        SecLangGeo = "Dil ve Gerçek Zamanlı IP API", SecTheme = "3D Kafatası Teması",
        SecSystem = "Sistem Temizliği",
        AntiAFK = "Anti-AFK Koruması", AntiRagdoll = "Anti-Ragdoll",
        AntiFling = "Anti-Fling Kalkanı", AntiVoid = "Boşluktan Kurtarma",
        AutoHeal = "Karakter Dengesi", PlayEmote = "Emote Başlat",
        StopEmote = "Emote Durdur", EnableWalkSpeed = "WalkSpeed Aç",
        WalkSpeedInput = "WalkSpeed Değeri (Sınırsız)", EnableJumpPower = "JumpPower Aç",
        JumpPowerInput = "JumpPower Değeri (Sınırsız)", EnableFly = "Uçuşu Aç",
        FlySpeedInput = "Uçuş Hızı (Sınırsız)", EnableNoclip = "Duvardan Geçme (Noclip)",
        EnableInfJump = "Sınırsız Zıplama", ResetPhysics = "Fiziği Sıfırla (16 / 50)",
        EnableAimbot = "Aimbot Aç (Sağ Tık)", ShowFOV = "FOV Dairesini Göster",
        AimFOV = "FOV Yarıçapı", AimSmooth = "Aimbot Yumuşaklığı", TeamCheck = "Takımı Yoksay",
        WallCheck = "Duvar Kontrolü", EnableESP = "Ana ESP Anahtarı",
        BoxESP = "2D Kutu", NameESP = "İsim ve Mesafe", HealthESP = "Can Çubuğu",
        TracerESP = "İzleyici Çizgiler", ChamsESP = "3D Chams Vurgusu",
        ESPDist = "Maks ESP Mesafesi", TPToPlayer = "Oyuncuya Işınlan",
        SpectatePlayer = "Oyuncuyu İzle", RefreshPlayers = "Listeyi Yenile",
        SaveWaypoint = "Konumu Kaydet", LoadWaypoint = "Kayıtlı Konuma Git",
        CtrlClickTP = "Ctrl + Tık Işınlanma", SelectLanguage = "Arayüz Dili (16 Dil)",
        AutoDetectLang = "IP'den Otomatik Algıla", MaskIPToggle = "IP Adresini Gizle",
        RefreshGeo = "Konumu Yenile", SaveConfig = "JSON Kaydet",
        LoadConfig = "JSON Yükle", ResetConfig = "Varsayılana Sıfırla",
        UnloadHub = "HUB'I KAPAT VE TEMİZLE"
    },
    vi = {
        TabMain = "Chính & Bảo Vệ", TabMovement = "Di Chuyển", TabCombat = "Chiến Đấu",
        TabVisuals = "Hiển Thị ESP", TabTeleport = "Dịch Chuyển", TabSettings = "Cài Đặt",
        SecDefense = "Bảo Vệ Nhân Vật", SecEmote = "Trình Phát Hành Động",
        SecSpeed = "Tốc Độ & Vật Lý Không Giới Hạn", SecFlight = "Bay Tự Do & Xuyên Tường",
        SecAimbot = "Điều Khiển Aimbot", SecESP = "Bộ Công Cụ ESP 3D/2D",
        SecTPPlayer = "Dịch Chuyển & Theo Dõi", SecTPWaypoints = "Lưu Tọa Độ & Click-TP",
        SecLangGeo = "Ngôn Ngữ & API Vị Trí IP", SecTheme = "Giao Diện Đầu Lâu 3D",
        SecSystem = "Dọn Dẹp Hệ Thống",
        AntiAFK = "Chống Kick AFK", AntiRagdoll = "Chống Ngã Ragdoll",
        AntiFling = "Khiên Chống Văng", AntiVoid = "Chống Rơi Vực",
        AutoHeal = "Ổn Định Nhân Vật", PlayEmote = "Chạy Hành Động",
        StopEmote = "Dừng Hành Động", EnableWalkSpeed = "Bật Tốc Độ Chạy",
        WalkSpeedInput = "Giá Trị WalkSpeed (Không Giới Hạn)", EnableJumpPower = "Bật Lực Nhảy",
        JumpPowerInput = "Giá Trị JumpPower (Không Giới Hạn)", EnableFly = "Bật Bay Tự Do",
        FlySpeedInput = "Tốc Độ Bay (Không Giới Hạn)", EnableNoclip = "Bật Xuyên Tường",
        EnableInfJump = "Nhảy Vô Hạn", ResetPhysics = "Đặt Lại Vật Lý (16 / 50)",
        EnableAimbot = "Bật Aimbot (Giữ Chuột Phải)", ShowFOV = "Hiện Vòng FOV",
        AimFOV = "Bán Kính FOV", AimSmooth = "Độ Mượt Aimbot", TeamCheck = "Bỏ Qua Đồng Đội",
        WallCheck = "Kiểm Tra Tường", EnableESP = "Công Tắc Chính ESP",
        BoxESP = "Khung 2D", NameESP = "Tên & Khoảng Cách", HealthESP = "Thanh Máu",
        TracerESP = "Đường Kẻ Theo Dõi", ChamsESP = "Nổi Bật 3D Chams",
        ESPDist = "Khoảng Cách ESP Tối Đa", TPToPlayer = "Dịch Chuyển Tới Người Chơi",
        SpectatePlayer = "Theo Dõi Người Chơi", RefreshPlayers = "Làm Mới Danh Sách",
        SaveWaypoint = "Lưu Vị Trí Hiện Tại", LoadWaypoint = "Đến Vị Trí Đã Lưu",
        CtrlClickTP = "Ctrl + Click Dịch Chuyển", SelectLanguage = "Ngôn Ngữ (16 Ngôn Ngữ)",
        AutoDetectLang = "Tự Động Theo IP", MaskIPToggle = "Ẩn Địa Chỉ IP",
        RefreshGeo = "Làm Mới Vị Trí IP", SaveConfig = "Lưu Cấu Hình JSON",
        LoadConfig = "Tải Cấu Hình JSON", ResetConfig = "Đặt Lại Mặc Định",
        UnloadHub = "ĐÓNG HUB & DỌN DẸP HỆ THỐNG"
    },
    th = {
        TabMain = "หลัก & ป้องกัน", TabMovement = "การเคลื่อนที่", TabCombat = "การต่อสู้",
        TabVisuals = "มองทะลุ ESP", TabTeleport = "เทเลพอร์ต", TabSettings = "ตั้งค่า",
        SecDefense = "ระบบป้องกันตัวละคร", SecEmote = "ตัวเล่นท่าทาง Emote",
        SecSpeed = "ความเร็วและฟิสิกส์ไร้ขีดจำกัด", SecFlight = "บินอิสระและทะลุกำแพง",
        SecAimbot = "ตัวควบคุม Aimbot", SecESP = "ชุดแสดงผล ESP 3D/2D",
        SecTPPlayer = "วาร์ปหาผู้เล่นและส่องกล้อง", SecTPWaypoints = "บันทึกพิกัดและคลิกวาร์ป",
        SecLangGeo = "ภาษาและตำแหน่ง IP แบบเรียลไทม์", SecTheme = "ธีมหัวกะโหลก 3D หรูหรา",
        SecSystem = "ล้างระบบและปิดการทำงาน",
        AntiAFK = "ป้องกันเตะ AFK", AntiRagdoll = "ป้องกันตัวล้ม Ragdoll",
        AntiFling = "โล่ป้องกันโดนเหวี่ยง", AntiVoid = "ป้องกันตกเหว",
        AutoHeal = "รักษาเสถียรภาพตัวละคร", PlayEmote = "เล่นท่าทางที่เลือก",
        StopEmote = "หยุดท่าทาง", EnableWalkSpeed = "เปิดใช้ความเร็วเดิน",
        WalkSpeedInput = "ค่าความเร็วเดิน (ไม่จำกัด)", EnableJumpPower = "เปิดใช้พลังกระโดด",
        JumpPowerInput = "ค่าพลังกระโดด (ไม่จำกัด)", EnableFly = "เปิดโหมดบินอิสระ",
        FlySpeedInput = "ความเร็วบิน (ไม่จำกัด)", EnableNoclip = "เปิดเดินทะลุกำแพง",
        EnableInfJump = "กระโดดไม่จำกัด", ResetPhysics = "รีเซ็ตฟิสิกส์ (16 / 50)",
        EnableAimbot = "เปิด Aimbot (กดคลิกขวาค้าง)", ShowFOV = "แสดงวงกลม FOV",
        AimFOV = "รัศมี FOV", AimSmooth = "ความนุ่มนวล Aimbot", TeamCheck = "ไม่ล็อกเพื่อนร่วมทีม",
        WallCheck = "ตรวจสอบกำแพง", EnableESP = "สวิตช์หลัก ESP",
        BoxESP = "กรอบ 2D", NameESP = "ชื่อและระยะห่าง", HealthESP = "แถบเลือด",
        TracerESP = "เส้นลากหาผู้เล่น", ChamsESP = "ไฮไลต์ 3D Chams",
        ESPDist = "ระยะ ESP สูงสุด", TPToPlayer = "วาร์ปไปหาผู้เล่น",
        SpectatePlayer = "ส่องดูผู้เล่น", RefreshPlayers = "รีเฟรชรายชื่อ",
        SaveWaypoint = "บันทึกตำแหน่งปัจจุบัน", LoadWaypoint = "วาร์ปไปตำแหน่งที่บันทึก",
        CtrlClickTP = "กด Ctrl + คลิกเพื่อวาร์ป", SelectLanguage = "ภาษา (รองรับ 16 ภาษา)",
        AutoDetectLang = "ตรวจจับภาษาจาก IP อัตโนมัติ", MaskIPToggle = "ซ่อนหมายเลข IP สาธารณะ",
        RefreshGeo = "รีเฟรชตำแหน่งเรียลไทม์", SaveConfig = "บันทึกการตั้งค่า JSON",
        LoadConfig = "โหลดการตั้งค่า JSON", ResetConfig = "คืนค่าเริ่มต้น",
        UnloadHub = "ปิดฮับและล้างระบบทั้งหมด"
    },
    ms = {
        TabMain = "Utama & Pertahanan", TabMovement = "Pergerakan", TabCombat = "Pertempuran",
        TabVisuals = "Visual ESP", TabTeleport = "Teleportasi", TabSettings = "Tetapan",
        SecDefense = "Pertahanan Watak", SecEmote = "Replikator Emote",
        SecSpeed = "Kelajuan & Fizik Tanpa Had", SecFlight = "Terbang 6-DOF & Noclip",
        SecAimbot = "Pengawal Aimbot", SecESP = "Sut Visual ESP 3D/2D",
        SecTPPlayer = "Teleportasi Pemain", SecTPWaypoints = "Koordinat & Klik-TP",
        SecLangGeo = "Bahasa & API Geolokasi", SecTheme = "Tema Tengkorak 3D Mewah",
        SecSystem = "Pembersihan Sistem",
        AntiAFK = "Anti-AFK Aktif", AntiRagdoll = "Perlindungan Anti-Ragdoll",
        AntiFling = "Perisai Anti-Fling", AntiVoid = "Penyelamat Anti-Void",
        AutoHeal = "Kestabilan Watak", PlayEmote = "Mainkan Emote",
        StopEmote = "Hentikan Emote", EnableWalkSpeed = "Aktifkan WalkSpeed",
        WalkSpeedInput = "Nilai WalkSpeed (Tanpa Had)", EnableJumpPower = "Aktifkan JumpPower",
        JumpPowerInput = "Nilai JumpPower (Tanpa Had)", EnableFly = "Aktifkan Terbang Bebas",
        FlySpeedInput = "Kelajuan Terbang (Tanpa Had)", EnableNoclip = "Aktifkan Noclip",
        EnableInfJump = "Lompat Tanpa Had", ResetPhysics = "Tetap Semula Fizik (16 / 50)",
        EnableAimbot = "Aktifkan Aimbot (Klik Kanan)", ShowFOV = "Papar Bulatan FOV",
        AimFOV = "Jejari FOV", AimSmooth = "Kelancaran Aimbot", TeamCheck = "Abaikan Rakan Sepasukan",
        WallCheck = "Semakan Dinding", EnableESP = "Suis Utama ESP",
        BoxESP = "Kotak 2D", NameESP = "Nama & Jarak", HealthESP = "Bar Nyawa",
        TracerESP = "Garis Pengesan", ChamsESP = "Sorotan 3D Chams",
        ESPDist = "Jarak Maksimum ESP", TPToPlayer = "Teleport ke Pemain",
        SpectatePlayer = "Tonton Pemain", RefreshPlayers = "Segar Semula Senarai",
        SaveWaypoint = "Simpan Kedudukan Semasa", LoadWaypoint = "Pergi ke Kedudukan Disimpan",
        CtrlClickTP = "Ctrl + Klik untuk Teleport", SelectLanguage = "Bahasa Antaramuka (16 Bahasa)",
        AutoDetectLang = "Kesan Automatik dari IP", MaskIPToggle = "Sembunyikan Alamat IP",
        RefreshGeo = "Segar Semula Lokasi IP", SaveConfig = "Simpan Konfigurasi JSON",
        LoadConfig = "Muat Konfigurasi JSON", ResetConfig = "Tetap Semula Konfigurasi",
        UnloadHub = "TUTUP HUB & BERSIHKAN SISTEM"
    },
    hi = {
        TabMain = "मुख्य और रक्षा", TabMovement = "गति और भौतिकी", TabCombat = "युद्ध",
        TabVisuals = "विज़ुअल ESP", TabTeleport = "टेलीपोर्ट", TabSettings = "सेटिंग्स",
        SecDefense = "चरित्र सुरक्षा प्रणाली", SecEmote = "इमोट प्लेयर",
        SecSpeed = "असीमित गति और भौतिकी", SecFlight = "फ्री फ्लाई और नोक्लिप",
        SecAimbot = "एमबॉट नियंत्रक", SecESP = "3D/2D ESP ओवरले",
        SecTPPlayer = "खिलाड़ी टेलीपोर्ट", SecTPWaypoints = "निर्देशांक और क्लिक-TP",
        SecLangGeo = "भाषा और लाइव IP लोकेशन", SecTheme = "3D खोपड़ी थीम और कॉन्फ़िग",
        SecSystem = "सिस्टम क्लीनअप",
        AntiAFK = "एंटी-AFK सुरक्षा", AntiRagdoll = "एंटी-रैगडॉल",
        AntiFling = "एंटी-फ्लिंग शील्ड", AntiVoid = "एंटी-वॉइड सुरक्षा",
        AutoHeal = "चरित्र स्थिरता", PlayEmote = "इमोट चलाएं",
        StopEmote = "इमोट रोकें", EnableWalkSpeed = "WalkSpeed सक्रिय करें",
        WalkSpeedInput = "WalkSpeed मान (असीमित)", EnableJumpPower = "JumpPower सक्रिय करें",
        JumpPowerInput = "JumpPower मान (असीमित)", EnableFly = "फ्री फ्लाई सक्रिय करें",
        FlySpeedInput = "उड़ान गति (असीमित)", EnableNoclip = "नोक्लिप सक्रिय करें",
        EnableInfJump = "असीमित छलांग", ResetPhysics = "भौतिकी रीसेट करें (16 / 50)",
        EnableAimbot = "एमबॉट सक्रिय करें (राइट क्लिक)", ShowFOV = "FOV सर्कल दिखाएं",
        AimFOV = "FOV त्रिज्या", AimSmooth = "एमबॉट स्मूथनेस", TeamCheck = "टीम जांच",
        WallCheck = "दीवार जांच", EnableESP = "मुख्य ESP स्विच",
        BoxESP = "2D बॉक्स", NameESP = "नाम और दूरी", HealthESP = "हेल्थ बार",
        TracerESP = "ट्रेसर लाइनें", ChamsESP = "3D चैंप्स हाइलाइट",
        ESPDist = "अधिकतम ESP दूरी", TPToPlayer = "खिलाड़ी पर टेलीपोर्ट करें",
        SpectatePlayer = "खिलाड़ी को देखें", RefreshPlayers = "सूची रीफ़्रेश करें",
        SaveWaypoint = "वर्तमान स्थान सहेजें", LoadWaypoint = "सहेजे गए स्थान पर जाएं",
        CtrlClickTP = "Ctrl + क्लिक टेलीपोर्ट", SelectLanguage = "भाषा चुनें (16 भाषाएं)",
        AutoDetectLang = "IP से स्वचालित भाषा", MaskIPToggle = "सार्वजनिक IP छुपाएं",
        RefreshGeo = "लोकेशन रीफ़्रेश करें", SaveConfig = "JSON कॉन्फ़िग सहेजें",
        LoadConfig = "JSON कॉन्फ़िग लोड करें", ResetConfig = "डिफ़ॉल्ट रीसेट करें",
        UnloadHub = "हब बंद करें और सिस्टम साफ करें"
    }
}

function GeoLangAPI:T(key)
    local dict = self.Translations[self.CurrentLang] or self.Translations.en
    return dict[key] or self.Translations.en[key] or key
end

function GeoLangAPI:BindText(textObj, key, prefix, suffix)
    table.insert(self.BoundElements, {
        Object = textObj,
        Key = key,
        Prefix = prefix or "",
        Suffix = suffix or ""
    })
    if textObj and textObj.Parent then
        textObj.Text = (prefix or "") .. self:T(key) .. (suffix or "")
    end
end

function GeoLangAPI:SetLanguage(langCode)
    if langCode == "auto" then
        local mapped = self.CountryToLang[self.GeoData.CountryCode] or "en"
        self.CurrentLang = mapped
    elseif self.Translations[langCode] then
        self.CurrentLang = langCode
    else
        self.CurrentLang = "en"
    end

    for _, item in ipairs(self.BoundElements) do
        pcall(function()
            if item.Object and item.Object.Parent then
                item.Object.Text = item.Prefix .. self:T(item.Key) .. item.Suffix
            end
        end)
    end
end

function GeoLangAPI:FormatIPDisplay()
    local ip = self.GeoData.IP or "Unknown"
    if State.MaskIP and ip:find("%.") then
        local parts = ip:split(".")
        if #parts == 4 then
            ip = parts[1] .. "." .. parts[2] .. ".***.***"
        end
    elseif State.MaskIP and #ip > 6 then
        ip = ip:sub(1, 6) .. "****"
    end
    return ip
end

function GeoLangAPI:NotifyGeoListeners()
    for _, cb in ipairs(self.OnGeoUpdated) do
        pcall(cb, self.GeoData)
    end
end

function GeoLangAPI:FetchAsync()
    self.GeoData.Status = "Syncing"
    self:NotifyGeoListeners()

    task.spawn(function()
        if not CleanupManager.Alive then return end

        local parsed = nil
        -- Primary endpoint: ip-api.com
        local ok1, body1 = Env.HttpGet("http://ip-api.com/json/?fields=status,country,countryCode,regionName,city,isp,query")
        if ok1 and body1 then
            local s1, data1 = pcall(function()
                return Services.HttpService:JSONDecode(body1)
            end)
            if s1 and type(data1) == "table" and data1.status == "success" then
                parsed = {
                    IP = tostring(data1.query or "Unknown"),
                    City = tostring(data1.city or "Unknown"),
                    Region = tostring(data1.regionName or ""),
                    Country = tostring(data1.country or "Global"),
                    CountryCode = tostring(data1.countryCode or "US"):upper(),
                    ISP = tostring(data1.isp or "Unknown"),
                    Status = "Live"
                }
            end
        end

        -- Fallback endpoint: ipwho.is
        if not parsed then
            local ok2, body2 = Env.HttpGet("https://ipwho.is/")
            if ok2 and body2 then
                local s2, data2 = pcall(function()
                    return Services.HttpService:JSONDecode(body2)
                end)
                if s2 and type(data2) == "table" and data2.success ~= false then
                    parsed = {
                        IP = tostring(data2.ip or "Unknown"),
                        City = tostring(data2.city or "Unknown"),
                        Region = tostring(data2.region or ""),
                        Country = tostring(data2.country or "Global"),
                        CountryCode = tostring(data2.country_code or "US"):upper(),
                        ISP = tostring((data2.connection and data2.connection.isp) or "Unknown"),
                        Status = "Live"
                    }
                end
            end
        end

        if parsed then
            self.GeoData = parsed
        else
            self.GeoData.IP = "Offline / Local"
            self.GeoData.City = "Roblox Client"
            self.GeoData.Country = "Global"
            self.GeoData.CountryCode = "US"
            self.GeoData.ISP = "Local Session"
            self.GeoData.Status = "Fallback"
        end

        if State.Language == "auto" then
            self:SetLanguage("auto")
        end
        self:NotifyGeoListeners()
    end)
end

-- ============================================================================
-- 5. LUXURY 3D HD SKULL VIEWPORT RENDERER & ANIMATED VERIFIED BADGE
-- ============================================================================
local Themes = {
    RoyalGold = {
        BgPrimary = Color3.fromRGB(11, 12, 16),
        BgSecondary = Color3.fromRGB(18, 20, 27),
        BgCard = Color3.fromRGB(24, 27, 36),
        Accent = Color3.fromRGB(245, 194, 66),
        AccentAlt = Color3.fromRGB(255, 224, 130),
        TextPrimary = Color3.fromRGB(245, 247, 252),
        TextMuted = Color3.fromRGB(152, 160, 179),
        Stroke = Color3.fromRGB(58, 52, 38)
    },
    CrimsonSkull = {
        BgPrimary = Color3.fromRGB(13, 10, 13),
        BgSecondary = Color3.fromRGB(22, 16, 21),
        BgCard = Color3.fromRGB(30, 21, 28),
        Accent = Color3.fromRGB(239, 68, 68),
        AccentAlt = Color3.fromRGB(252, 165, 165),
        TextPrimary = Color3.fromRGB(248, 245, 246),
        TextMuted = Color3.fromRGB(175, 150, 158),
        Stroke = Color3.fromRGB(68, 34, 42)
    },
    CyberCyan = {
        BgPrimary = Color3.fromRGB(10, 14, 19),
        BgSecondary = Color3.fromRGB(15, 22, 30),
        BgCard = Color3.fromRGB(20, 30, 41),
        Accent = Color3.fromRGB(34, 211, 238),
        AccentAlt = Color3.fromRGB(165, 243, 252),
        TextPrimary = Color3.fromRGB(242, 249, 252),
        TextMuted = Color3.fromRGB(145, 170, 185),
        Stroke = Color3.fromRGB(32, 62, 76)
    },
    EmeraldVenom = {
        BgPrimary = Color3.fromRGB(10, 15, 13),
        BgSecondary = Color3.fromRGB(15, 24, 20),
        BgCard = Color3.fromRGB(21, 33, 28),
        Accent = Color3.fromRGB(16, 185, 129),
        AccentAlt = Color3.fromRGB(110, 231, 183),
        TextPrimary = Color3.fromRGB(242, 252, 247),
        TextMuted = Color3.fromRGB(146, 178, 163),
        Stroke = Color3.fromRGB(32, 68, 54)
    },
    PhantomViolet = {
        BgPrimary = Color3.fromRGB(13, 11, 19),
        BgSecondary = Color3.fromRGB(21, 18, 31),
        BgCard = Color3.fromRGB(28, 24, 42),
        Accent = Color3.fromRGB(168, 85, 247),
        AccentAlt = Color3.fromRGB(216, 180, 254),
        TextPrimary = Color3.fromRGB(246, 243, 253),
        TextMuted = Color3.fromRGB(163, 152, 186),
        Stroke = Color3.fromRGB(56, 42, 82)
    }
}

local ActiveTheme = Themes[State.AccentPreset] or Themes.RoyalGold

local Utils = {}

function Utils.Create(className, props, children)
    local inst = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                inst[k] = v
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

function Utils.Corner(parent, radius)
    return Utils.Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
end

function Utils.Stroke(parent, color, thickness, transparency)
    return Utils.Create("UIStroke", {
        Color = color or ActiveTheme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

-- Luxury 3D HD Skull Builder (Replaces legacy pumpkin asset with sculptural 3D Viewport skull)
function Utils.CreateSkull3D(parent, sizeUDim2)
    local container = Utils.Create("Frame", {
        Name = "LuxurySkull3DContainer",
        Size = sizeUDim2 or UDim2.new(0, 44, 0, 44),
        BackgroundColor3 = Color3.fromRGB(16, 18, 25),
        BorderSizePixel = 0,
        Parent = parent
    })
    Utils.Corner(container, 10)
    local containerStroke = Utils.Stroke(container, ActiveTheme.Accent, 1.4, 0.15)

    local glowGradient = Utils.Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 32, 24)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 20, 28)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 18))
        }),
        Rotation = 45,
        Parent = container
    })

    local viewport = Utils.Create("ViewportFrame", {
        Name = "SkullViewport3D",
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(145, 145, 160),
        LightColor = Color3.fromRGB(255, 244, 214),
        LightDirection = Vector3.new(-0.5, -1, -0.8),
        Parent = container
    })

    local worldModel = Utils.Create("WorldModel", {
        Name = "SkullWorld",
        Parent = viewport
    })

    local skullRig = Utils.Create("Model", {
        Name = "LuxurySkullModel",
        Parent = worldModel
    })

    local function makePart(name, size, cf, color, material, shape, reflectance)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Color = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.Shape = shape or Enum.PartType.Block
        p.Reflectance = reflectance or 0.15
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Parent = skullRig
        return p
    end

    local boneWhite = Color3.fromRGB(238, 236, 230)
    local boneShade = Color3.fromRGB(205, 201, 194)
    local socketDark = Color3.fromRGB(14, 14, 18)
    local goldAccent = ActiveTheme.Accent

    -- Sculpted 3D Cranium Dome
    local cranium = makePart(
        "Cranium",
        Vector3.new(2.15, 1.95, 2.25),
        CFrame.new(0, 0.42, 0.08),
        boneWhite,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Ball,
        0.18
    )
    skullRig.PrimaryPart = cranium

    -- Brow Ridge (Upper Frontal Bone)
    makePart(
        "BrowRidge",
        Vector3.new(1.78, 0.34, 0.72),
        CFrame.new(0, 0.28, -0.78) * CFrame.Angles(math.rad(8), 0, 0),
        boneWhite,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Block,
        0.15
    )

    -- Left & Right Zygomatic Cheekbones
    makePart(
        "CheekLeft",
        Vector3.new(0.58, 0.48, 0.85),
        CFrame.new(-0.68, -0.15, -0.62) * CFrame.Angles(0, math.rad(18), math.rad(-8)),
        boneShade,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Block,
        0.12
    )
    makePart(
        "CheekRight",
        Vector3.new(0.58, 0.48, 0.85),
        CFrame.new(0.68, -0.15, -0.62) * CFrame.Angles(0, math.rad(-18), math.rad(8)),
        boneShade,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Block,
        0.12
    )

    -- Deep Orbital Eye Sockets + Glowing Core Pupils
    makePart(
        "SocketLeft",
        Vector3.new(0.52, 0.46, 0.36),
        CFrame.new(-0.42, 0.04, -0.92),
        socketDark,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Ball,
        0
    )
    makePart(
        "SocketRight",
        Vector3.new(0.52, 0.46, 0.36),
        CFrame.new(0.42, 0.04, -0.92),
        socketDark,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Ball,
        0
    )

    local eyeLeft = makePart(
        "EyeGlowLeft",
        Vector3.new(0.22, 0.22, 0.22),
        CFrame.new(-0.42, 0.04, -0.98),
        goldAccent,
        Enum.Material.Neon,
        Enum.PartType.Ball,
        0
    )
    local eyeRight = makePart(
        "EyeGlowRight",
        Vector3.new(0.22, 0.22, 0.22),
        CFrame.new(0.42, 0.04, -0.98),
        goldAccent,
        Enum.Material.Neon,
        Enum.PartType.Ball,
        0
    )

    -- Nasal Cavity
    makePart(
        "NasalCavity",
        Vector3.new(0.26, 0.38, 0.32),
        CFrame.new(0, -0.24, -0.96) * CFrame.Angles(math.rad(-12), 0, 0),
        socketDark,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Block,
        0
    )

    -- Maxilla & Mandible (Jaw + Sculpted Teeth)
    makePart(
        "Maxilla",
        Vector3.new(1.12, 0.36, 0.95),
        CFrame.new(0, -0.52, -0.52),
        boneShade,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Block,
        0.1
    )
    makePart(
        "Mandible",
        Vector3.new(1.04, 0.34, 1.02),
        CFrame.new(0, -0.86, -0.44),
        boneWhite,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Block,
        0.12
    )

    -- Luxury Metallic Crown Crest on Skull
    local crownBand = makePart(
        "LuxuryCrown",
        Vector3.new(1.36, 0.22, 1.36),
        CFrame.new(0, 1.24, 0.02) * CFrame.Angles(0, 0, math.rad(4)),
        goldAccent,
        Enum.Material.Neon,
        Enum.PartType.Cylinder,
        0.4
    )
    crownBand.Orientation = Vector3.new(0, 0, 90)

    local vpCam = Instance.new("Camera")
    vpCam.Name = "SkullCamera"
    vpCam.FieldOfView = 38
    vpCam.CFrame = CFrame.new(Vector3.new(0, 0.15, -4.1), Vector3.new(0, 0.1, 0))
    vpCam.Parent = viewport
    viewport.CurrentCamera = vpCam

    -- Record base CFrames for smooth 3D rotation
    local baseParts = {}
    for _, part in ipairs(skullRig:GetChildren()) do
        if part:IsA("BasePart") then
            baseParts[part] = part.CFrame
        end
    end

    return {
        Container = container,
        Stroke = containerStroke,
        Viewport = viewport,
        Rig = skullRig,
        BaseParts = baseParts,
        EyeLeft = eyeLeft,
        EyeRight = eyeRight,
        Crown = crownBand,
        Gradient = glowGradient
    }
end

-- Animated Professional Blue Verified Badge
function Utils.CreateVerifiedBadge(parent)
    local badge = Utils.Create("Frame", {
        Name = "VerifiedBadge",
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = Color3.fromRGB(29, 155, 240),
        BorderSizePixel = 0,
        Parent = parent
    })
    Utils.Corner(badge, 10)
    local ringStroke = Utils.Stroke(badge, Color3.fromRGB(125, 211, 252), 1.3, 0.2)

    local shimmer = Utils.Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 155, 240)),
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(56, 189, 248)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(224, 242, 254)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(56, 189, 248)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 116, 210))
        }),
        Rotation = 25,
        Parent = badge
    })

    local checkLabel = Utils.Create("TextLabel", {
        Name = "CheckIcon",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "✓",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        Parent = badge
    })

    return {
        Badge = badge,
        Stroke = ringStroke,
        Shimmer = shimmer,
        Icon = checkLabel
    }
end

-- ============================================================================
-- 6. GLASSMORPHIC UI COMPONENT FACTORY (6 COMPLETE TABS)
-- ============================================================================
local ScreenGui = Utils.Create("ScreenGui", {
    Name = "BimSakSinHub_v3",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true
})
Env.ProtectGui(ScreenGui)
ScreenGui.Parent = Env.GetGuiParent()
CleanupManager:AddInstance(ScreenGui)

-- Toast Notification System
local ToastContainer = Utils.Create("Frame", {
    Name = "ToastContainer",
    Size = UDim2.new(0, 310, 1, -24),
    Position = UDim2.new(1, -326, 0, 12),
    BackgroundTransparency = 1,
    ZIndex = 50,
    Parent = ScreenGui
})
Utils.Create("UIListLayout", {
    Padding = UDim.new(0, 8),
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = ToastContainer
})

local function Notify(title, message, duration)
    if not CleanupManager.Alive then return end
    task.spawn(function()
        local toast = Utils.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 56),
            BackgroundColor3 = ActiveTheme.BgSecondary,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ZIndex = 51,
            Parent = ToastContainer
        })
        Utils.Corner(toast, 10)
        Utils.Stroke(toast, ActiveTheme.Accent, 1.2, 0.25)

        Utils.Create("Frame", {
            Size = UDim2.new(0, 4, 1, -14),
            Position = UDim2.new(0, 7, 0, 7),
            BackgroundColor3 = ActiveTheme.Accent,
            BorderSizePixel = 0,
            ZIndex = 52,
            Parent = toast
        })

        Utils.Create("TextLabel", {
            Size = UDim2.new(1, -24, 0, 20),
            Position = UDim2.new(0, 18, 0, 7),
            BackgroundTransparency = 1,
            Text = tostring(title),
            TextColor3 = ActiveTheme.AccentAlt,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
            Parent = toast
        })

        Utils.Create("TextLabel", {
            Size = UDim2.new(1, -24, 0, 22),
            Position = UDim2.new(0, 18, 0, 27),
            BackgroundTransparency = 1,
            Text = tostring(message),
            TextColor3 = ActiveTheme.TextPrimary,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 52,
            Parent = toast
        })

        task.wait(duration or 3.2)
        if toast and toast.Parent then
            local tw = Services.TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
            tw:Play()
            tw.Completed:Wait()
            if toast and toast.Parent then
                toast:Destroy()
            end
        end
    end)
end

-- Main Hub Window
local MainWindow = Utils.Create("Frame", {
    Name = "MainWindow",
    Size = UDim2.new(0, 720, 0, 470),
    Position = UDim2.new(0.5, -360, 0.5, -235),
    BackgroundColor3 = ActiveTheme.BgPrimary,
    BackgroundTransparency = State.WindowOpacity,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = ScreenGui
})
Utils.Corner(MainWindow, 14)
local MainStroke = Utils.Stroke(MainWindow, ActiveTheme.Accent, 1.5, 0.25)

-- Top Luxury Header Bar (Zero Sponsor Text — Pure BimSakSin Hub v3.0)
local TopBar = Utils.Create("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 62),
    BackgroundColor3 = ActiveTheme.BgSecondary,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Parent = MainWindow
})
Utils.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = ActiveTheme.Stroke,
    BorderSizePixel = 0,
    Parent = TopBar
})

-- 3D HD Skull Emblem in Header
local SkullVisual = Utils.CreateSkull3D(TopBar, UDim2.new(0, 46, 0, 46))
SkullVisual.Container.Position = UDim2.new(0, 12, 0.5, -23)

-- Title + Version Pill + Animated Blue Verified Checkmark Badge
local TitleRow = Utils.Create("Frame", {
    Name = "TitleRow",
    Size = UDim2.new(0, 300, 0, 26),
    Position = UDim2.new(0, 68, 0, 9),
    BackgroundTransparency = 1,
    Parent = TopBar
})
Utils.Create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = TitleRow
})

local HubTitleLabel = Utils.Create("TextLabel", {
    Name = "HubTitle",
    Size = UDim2.new(0, 134, 0, 24),
    BackgroundTransparency = 1,
    Text = "BimSakSin Hub",
    TextColor3 = ActiveTheme.TextPrimary,
    TextSize = 17,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 1,
    Parent = TitleRow
})

local VerifiedVisual = Utils.CreateVerifiedBadge(TitleRow)
VerifiedVisual.Badge.LayoutOrder = 2

local VersionBadge = Utils.Create("Frame", {
    Name = "VersionBadge",
    Size = UDim2.new(0, 48, 0, 20),
    BackgroundColor3 = ActiveTheme.BgCard,
    BorderSizePixel = 0,
    LayoutOrder = 3,
    Parent = TitleRow
})
Utils.Corner(VersionBadge, 6)
local VersionStroke = Utils.Stroke(VersionBadge, ActiveTheme.Accent, 1, 0.35)
local VersionLabel = Utils.Create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "v3.0",
    TextColor3 = ActiveTheme.Accent,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    Parent = VersionBadge
})

-- Subtitle / Edition Tagline (No Sponsors)
local SubtitleLabel = Utils.Create("TextLabel", {
    Name = "Subtitle",
    Size = UDim2.new(0, 280, 0, 16),
    Position = UDim2.new(0, 68, 0, 36),
    BackgroundTransparency = 1,
    Text = "3D HD Skull Edition • Unlimited Physics & GeoLang",
    TextColor3 = ActiveTheme.TextMuted,
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
})

-- Real-Time IP & Geolocation Live Pill in Header
local GeoPill = Utils.Create("Frame", {
    Name = "GeoPill",
    Size = UDim2.new(0, 246, 0, 32),
    Position = UDim2.new(1, -326, 0.5, -16),
    BackgroundColor3 = ActiveTheme.BgCard,
    BorderSizePixel = 0,
    Parent = TopBar
})
Utils.Corner(GeoPill, 8)
local GeoPillStroke = Utils.Stroke(GeoPill, ActiveTheme.Stroke, 1, 0.1)

local GeoPulseDot = Utils.Create("Frame", {
    Name = "GeoPulseDot",
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(0, 10, 0.5, -4),
    BackgroundColor3 = Color3.fromRGB(34, 197, 94),
    BorderSizePixel = 0,
    Parent = GeoPill
})
Utils.Corner(GeoPulseDot, 4)

local GeoHeaderLabel = Utils.Create("TextLabel", {
    Name = "GeoHeaderLabel",
    Size = UDim2.new(1, -28, 1, 0),
    Position = UDim2.new(0, 24, 0, 0),
    BackgroundTransparency = 1,
    Text = "Syncing IP & Location...",
    TextColor3 = ActiveTheme.TextPrimary,
    TextSize = 11,
    Font = Enum.Font.GothamSemibold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = GeoPill
})

-- Header Minimize & Quick Unload Buttons
local MinimizeBtn = Utils.Create("TextButton", {
    Name = "MinimizeBtn",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -72, 0.5, -15),
    BackgroundColor3 = ActiveTheme.BgCard,
    Text = "—",
    TextColor3 = ActiveTheme.TextPrimary,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true,
    Parent = TopBar
})
Utils.Corner(MinimizeBtn, 8)
Utils.Stroke(MinimizeBtn, ActiveTheme.Stroke, 1, 0.2)

local CloseUnloadBtn = Utils.Create("TextButton", {
    Name = "CloseUnloadBtn",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -36, 0.5, -15),
    BackgroundColor3 = Color3.fromRGB(153, 27, 27),
    Text = "✕",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true,
    Parent = TopBar
})
Utils.Corner(CloseUnloadBtn, 8)

-- Floating Re-Open Pill when Minimized
local RestorePill = Utils.Create("TextButton", {
    Name = "RestorePill",
    Size = UDim2.new(0, 178, 0, 36),
    Position = UDim2.new(0, 18, 0.5, -18),
    BackgroundColor3 = ActiveTheme.BgSecondary,
    Text = "💀 BimSakSin Hub v3.0",
    TextColor3 = ActiveTheme.Accent,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    Visible = false,
    Parent = ScreenGui
})
Utils.Corner(RestorePill, 18)
Utils.Stroke(RestorePill, ActiveTheme.Accent, 1.4, 0.1)

CleanupManager:AddConnection(MinimizeBtn.MouseButton1Click:Connect(function()
    MainWindow.Visible = false
    RestorePill.Visible = true
end))

CleanupManager:AddConnection(RestorePill.MouseButton1Click:Connect(function()
    MainWindow.Visible = true
    RestorePill.Visible = false
end))

CleanupManager:AddConnection(CloseUnloadBtn.MouseButton1Click:Connect(function()
    CleanupManager:Unload()
end))

-- Smooth Dragging for TopBar
do
    local dragging = false
    local dragStart, startPos

    CleanupManager:AddConnection(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainWindow.Position
        end
    end))

    CleanupManager:AddConnection(Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainWindow.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    CleanupManager:AddConnection(Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- Navigation Sidebar & Content Pages
local Sidebar = Utils.Create("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0, 174, 1, -62),
    Position = UDim2.new(0, 0, 0, 62),
    BackgroundColor3 = ActiveTheme.BgSecondary,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Parent = MainWindow
})
Utils.Create("Frame", {
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = ActiveTheme.Stroke,
    BorderSizePixel = 0,
    Parent = Sidebar
})

local NavList = Utils.Create("Frame", {
    Name = "NavList",
    Size = UDim2.new(1, -16, 1, -56),
    Position = UDim2.new(0, 8, 0, 10),
    BackgroundTransparency = 1,
    Parent = Sidebar
})
Utils.Create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = NavList
})

-- Sidebar Footer Status Badge
local SidebarFooter = Utils.Create("Frame", {
    Name = "SidebarFooter",
    Size = UDim2.new(1, -16, 0, 36),
    Position = UDim2.new(0, 8, 1, -44),
    BackgroundColor3 = ActiveTheme.BgCard,
    BorderSizePixel = 0,
    Parent = Sidebar
})
Utils.Corner(SidebarFooter, 8)
Utils.Stroke(SidebarFooter, ActiveTheme.Stroke, 1, 0.2)

local PlayerFooterLabel = Utils.Create("TextLabel", {
    Size = UDim2.new(1, -12, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = "@" .. LocalPlayer.Name .. " • RShift",
    TextColor3 = ActiveTheme.TextMuted,
    TextSize = 11,
    Font = Enum.Font.GothamSemibold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = SidebarFooter
})

local ContentArea = Utils.Create("Frame", {
    Name = "ContentArea",
    Size = UDim2.new(1, -174, 1, -62),
    Position = UDim2.new(0, 174, 0, 62),
    BackgroundTransparency = 1,
    Parent = MainWindow
})

-- Tab Registry & Page Factory
local Tabs = {}
local TabButtons = {}
local ActiveTabName = nil

local function SelectTab(tabId)
    ActiveTabName = tabId
    for id, page in pairs(Tabs) do
        page.Visible = (id == tabId)
    end
    for id, btnData in pairs(TabButtons) do
        local isSelected = (id == tabId)
        btnData.Button.BackgroundColor3 = isSelected and ActiveTheme.BgCard or ActiveTheme.BgSecondary
        btnData.Button.BackgroundTransparency = isSelected and 0 or 0.4
        btnData.Indicator.Visible = isSelected
        btnData.Label.TextColor3 = isSelected and ActiveTheme.Accent or ActiveTheme.TextMuted
    end
end

local function CreateTab(tabId, iconText, langKey, order)
    local btn = Utils.Create("TextButton", {
        Name = "TabBtn_" .. tabId,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = ActiveTheme.BgSecondary,
        BackgroundTransparency = 0.4,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        Parent = NavList
    })
    Utils.Corner(btn, 8)

    local indicator = Utils.Create("Frame", {
        Name = "Indicator",
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 4, 0.5, -10),
        BackgroundColor3 = ActiveTheme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        Parent = btn
    })
    Utils.Corner(indicator, 2)

    local icon = Utils.Create("TextLabel", {
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = iconText,
        TextColor3 = ActiveTheme.AccentAlt,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Parent = btn
    })

    local label = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -42, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = ActiveTheme.TextMuted,
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = btn
    })
    GeoLangAPI:BindText(label, langKey)

    local page = Utils.Create("ScrollingFrame", {
        Name = "Page_" .. tabId,
        Size = UDim2.new(1, -20, 1, -16),
        Position = UDim2.new(0, 10, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = ActiveTheme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = ContentArea
    })
    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page
    })
    Utils.Create("UIPadding", {
        PaddingBottom = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 6),
        Parent = page
    })

    Tabs[tabId] = page
    TabButtons[tabId] = {
        Button = btn,
        Indicator = indicator,
        Icon = icon,
        Label = label
    }

    CleanupManager:AddConnection(btn.MouseButton1Click:Connect(function()
        SelectTab(tabId)
    end))

    return page
end

-- Reusable UI Control Builders
local UIControls = {}

function UIControls.CreateSection(parentPage, langKey, order)
    local section = Utils.Create("Frame", {
        Name = "Section_" .. langKey,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = ActiveTheme.BgSecondary,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
        Parent = parentPage
    })
    Utils.Corner(section, 10)
    Utils.Stroke(section, ActiveTheme.Stroke, 1, 0.15)
    Utils.Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = section
    })
    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = section
    })

    local header = Utils.Create("TextLabel", {
        Name = "SectionHeader",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = ActiveTheme.Accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
        Parent = section
    })
    GeoLangAPI:BindText(header, langKey)

    return section
end

function UIControls.CreateToggle(section, langKey, stateKey, order, onChanged)
    local row = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = ActiveTheme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
        Parent = section
    })
    Utils.Corner(row, 8)

    local lbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -64, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = ActiveTheme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })
    GeoLangAPI:BindText(lbl, langKey)

    local switchBg = Utils.Create("TextButton", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -54, 0.5, -11),
        BackgroundColor3 = State[stateKey] and ActiveTheme.Accent or Color3.fromRGB(48, 52, 66),
        Text = "",
        AutoButtonColor = false,
        Parent = row
    })
    Utils.Corner(switchBg, 11)

    local knob = Utils.Create("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = State[stateKey] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = switchBg
    })
    Utils.Corner(knob, 8)

    local function setVisual(val)
        switchBg.BackgroundColor3 = val and ActiveTheme.Accent or Color3.fromRGB(48, 52, 66)
        Services.TweenService:Create(knob, TweenInfo.new(0.16), {
            Position = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
    end

    CleanupManager:AddConnection(switchBg.MouseButton1Click:Connect(function()
        State[stateKey] = not State[stateKey]
        setVisual(State[stateKey])
        if onChanged then
            onChanged(State[stateKey])
        end
    end))

    return {
        Row = row,
        Refresh = function()
            setVisual(State[stateKey])
        end
    }
end

-- Unlimited Numeric Input + Quick Preset Bar (Zero Upper Limit for Speed/Jump/Fly)
function UIControls.CreateUnlimitedNumberInput(section, langKey, stateKey, presets, defaultFallback, order, onChanged)
    local box = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 66),
        BackgroundColor3 = ActiveTheme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
        Parent = section
    })
    Utils.Corner(box, 8)

    local lbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -140, 0, 24),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = ActiveTheme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = box
    })
    GeoLangAPI:BindText(lbl, langKey)

    local inputBox = Utils.Create("TextBox", {
        Size = UDim2.new(0, 118, 0, 26),
        Position = UDim2.new(1, -128, 0, 5),
        BackgroundColor3 = ActiveTheme.BgPrimary,
        Text = tostring(State[stateKey]),
        PlaceholderText = "Any number...",
        TextColor3 = ActiveTheme.Accent,
        PlaceholderColor3 = ActiveTheme.TextMuted,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        Parent = box
    })
    Utils.Corner(inputBox, 6)
    Utils.Stroke(inputBox, ActiveTheme.Accent, 1, 0.35)

    local presetRow = Utils.Create("Frame", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 12, 0, 36),
        BackgroundTransparency = 1,
        Parent = box
    })
    Utils.Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = presetRow
    })

    local function applyNumber(num)
        if type(num) == "number" and num == num and math.abs(num) ~= math.huge then
            State[stateKey] = num
            inputBox.Text = tostring(num)
            if onChanged then
                onChanged(num)
            end
        else
            inputBox.Text = tostring(State[stateKey] or defaultFallback)
        end
    end

    CleanupManager:AddConnection(inputBox.FocusLost:Connect(function()
        local parsed = tonumber(inputBox.Text)
        if parsed then
            applyNumber(parsed)
        else
            inputBox.Text = tostring(State[stateKey])
        end
    end))

    for idx, presetVal in ipairs(presets or { 16, 50, 150, 500, 2500, 10000 }) do
        local pBtn = Utils.Create("TextButton", {
            Size = UDim2.new(0, 66, 1, 0),
            BackgroundColor3 = ActiveTheme.BgSecondary,
            Text = tostring(presetVal),
            TextColor3 = ActiveTheme.TextMuted,
            TextSize = 11,
            Font = Enum.Font.GothamSemibold,
            LayoutOrder = idx,
            Parent = presetRow
        })
        Utils.Corner(pBtn, 5)
        Utils.Stroke(pBtn, ActiveTheme.Stroke, 1, 0.3)

        CleanupManager:AddConnection(pBtn.MouseButton1Click:Connect(function()
            applyNumber(presetVal)
        end))
    end

    return {
        SetValue = applyNumber
    }
end

function UIControls.CreateSlider(section, langKey, stateKey, minVal, maxVal, decimals, order, onChanged)
    local holder = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = ActiveTheme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
        Parent = section
    })
    Utils.Corner(holder, 8)

    local lbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -80, 0, 22),
        Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = ActiveTheme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })
    GeoLangAPI:BindText(lbl, langKey)

    local fmt = decimals and ("%." .. tostring(decimals) .. "f") or "%d"
    local valLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(0, 68, 0, 22),
        Position = UDim2.new(1, -78, 0, 4),
        BackgroundTransparency = 1,
        Text = string.format(fmt, State[stateKey]),
        TextColor3 = ActiveTheme.Accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = holder
    })

    local track = Utils.Create("TextButton", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 31),
        BackgroundColor3 = ActiveTheme.BgPrimary,
        Text = "",
        AutoButtonColor = false,
        Parent = holder
    })
    Utils.Corner(track, 4)

    local initAlpha = math.clamp((State[stateKey] - minVal) / (maxVal - minVal), 0, 1)
    local fill = Utils.Create("Frame", {
        Size = UDim2.new(initAlpha, 0, 1, 0),
        BackgroundColor3 = ActiveTheme.Accent,
        BorderSizePixel = 0,
        Parent = track
    })
    Utils.Corner(fill, 4)

    local dragging = false
    local function updateFromX(inputX)
        local rel = math.clamp((inputX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local raw = minVal + (maxVal - minVal) * rel
        if decimals and decimals > 0 then
            local mult = 10 ^ decimals
            raw = math.floor(raw * mult + 0.5) / mult
        else
            raw = math.floor(raw + 0.5)
        end
        State[stateKey] = raw
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valLbl.Text = string.format(fmt, raw)
        if onChanged then
            onChanged(raw)
        end
    end

    CleanupManager:AddConnection(track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end))

    CleanupManager:AddConnection(Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))

    CleanupManager:AddConnection(Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

function UIControls.CreateButton(section, langKey, colorOverride, order, onClick)
    local btn = Utils.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = colorOverride or ActiveTheme.BgCard,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = colorOverride and Color3.fromRGB(255, 255, 255) or ActiveTheme.AccentAlt,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        LayoutOrder = order or 1,
        Parent = section
    })
    Utils.Corner(btn, 8)
    Utils.Stroke(btn, colorOverride or ActiveTheme.Accent, 1, 0.35)
    GeoLangAPI:BindText(btn, langKey)

    CleanupManager:AddConnection(btn.MouseButton1Click:Connect(function()
        if onClick then
            onClick()
        end
    end))
    return btn
end

function UIControls.CreateDropdown(section, langKey, optionsList, getSelectedLabel, order, onSelect)
    local wrapper = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = ActiveTheme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
        Parent = section
    })
    Utils.Corner(wrapper, 8)

    local topHeader = Utils.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        Parent = wrapper
    })

    local titleLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(0.55, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = GeoLangAPI:T(langKey),
        TextColor3 = ActiveTheme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topHeader
    })
    GeoLangAPI:BindText(titleLbl, langKey)

    local selectedLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(0.45, -12, 1, 0),
        Position = UDim2.new(0.55, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = getSelectedLabel() .. " ▼",
        TextColor3 = ActiveTheme.Accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = topHeader
    })

    local listFrame = Utils.Create("ScrollingFrame", {
        Size = UDim2.new(1, -16, 0, 130),
        Position = UDim2.new(0, 8, 0, 38),
        BackgroundColor3 = ActiveTheme.BgPrimary,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = ActiveTheme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = wrapper
    })
    Utils.Corner(listFrame, 6)
    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = listFrame
    })
    Utils.Create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        Parent = listFrame
    })

    local function rebuildOptions(items)
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        for idx, opt in ipairs(items) do
            local labelText = type(opt) == "table" and opt.Label or tostring(opt)
            local optBtn = Utils.Create("TextButton", {
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundColor3 = ActiveTheme.BgSecondary,
                Text = "  " .. labelText,
                TextColor3 = ActiveTheme.TextPrimary,
                TextSize = 11,
                Font = Enum.Font.GothamSemibold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = idx,
                Parent = listFrame
            })
            Utils.Corner(optBtn, 5)
            CleanupManager:AddConnection(optBtn.MouseButton1Click:Connect(function()
                listFrame.Visible = false
                if onSelect then
                    onSelect(opt)
                end
                selectedLbl.Text = getSelectedLabel() .. " ▼"
            end))
        end
    end

    rebuildOptions(optionsList)

    CleanupManager:AddConnection(topHeader.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
    end))

    return {
        Rebuild = rebuildOptions,
        RefreshLabel = function()
            selectedLbl.Text = getSelectedLabel() .. " ▼"
        end
    }
end

-- ============================================================================
-- 7. BUILD ALL 6 TABS & FEATURE CONTROLLERS
-- ============================================================================
local PageMain     = CreateTab("Main",     "🛡️", "TabMain",     1)
local PageMovement = CreateTab("Movement", "⚡", "TabMovement", 2)
local PageCombat   = CreateTab("Combat",   "🎯", "TabCombat",   3)
local PageVisuals  = CreateTab("Visuals",  "👁️", "TabVisuals",  4)
local PageTeleport = CreateTab("Teleport", "🌀", "TabTeleport", 5)
local PageSettings = CreateTab("Settings", "⚙️", "TabSettings", 6)

-- ----------------------------------------------------------------------------
-- TAB 1: MAIN & CHARACTER DEFENSE + EMOTE REPLICATOR
-- ----------------------------------------------------------------------------
local SecDefense = UIControls.CreateSection(PageMain, "SecDefense", 1)
UIControls.CreateToggle(SecDefense, "AntiAFK", "AntiAFK", 1)
UIControls.CreateToggle(SecDefense, "AntiRagdoll", "AntiRagdoll", 2)
UIControls.CreateToggle(SecDefense, "AntiFling", "AntiFling", 3)
UIControls.CreateToggle(SecDefense, "AntiVoid", "AntiVoid", 4)
UIControls.CreateToggle(SecDefense, "AutoHeal", "AutoHeal", 5)

-- Anti-AFK Listener
CleanupManager:AddConnection(LocalPlayer.Idled:Connect(function()
    if CleanupManager.Alive and State.AntiAFK then
        pcall(function()
            Services.VirtualUser:CaptureController()
            Services.VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

-- Emote Replicator Section
local SecEmote = UIControls.CreateSection(PageMain, "SecEmote", 2)
local EmoteCatalog = {
    { Label = "Wave", Id = "rbxassetid://507770239" },
    { Label = "Dance 1", Id = "rbxassetid://507771019" },
    { Label = "Dance 2", Id = "rbxassetid://507776043" },
    { Label = "Dance 3", Id = "rbxassetid://507777268" },
    { Label = "Laugh", Id = "rbxassetid://507770818" },
    { Label = "Cheer", Id = "rbxassetid://507770677" },
    { Label = "Point", Id = "rbxassetid://507770453" }
}
local ActiveEmoteTrack = nil

local function StopCurrentEmote()
    if ActiveEmoteTrack then
        pcall(function()
            ActiveEmoteTrack:Stop()
            ActiveEmoteTrack:Destroy()
        end)
        ActiveEmoteTrack = nil
    end
end

local function PlaySelectedEmote()
    StopCurrentEmote()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local emoteId = "rbxassetid://507770239"
    for _, item in ipairs(EmoteCatalog) do
        if item.Label == State.SelectedEmote then
            emoteId = item.Id
            break
        end
    end

    pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = emoteId
        local animator = hum:FindFirstChildOfClass("Animator") or hum
        local track = animator:LoadAnimation(anim)
        track.Looped = true
        track:Play()
        ActiveEmoteTrack = track
    end)
end

UIControls.CreateDropdown(SecEmote, "SecEmote", EmoteCatalog, function()
    return State.SelectedEmote
end, 1, function(opt)
    State.SelectedEmote = opt.Label
end)

UIControls.CreateButton(SecEmote, "PlayEmote", nil, 2, function()
    PlaySelectedEmote()
    Notify("Emote Replicator", "Playing: " .. State.SelectedEmote, 2)
end)

UIControls.CreateButton(SecEmote, "StopEmote", Color3.fromRGB(127, 29, 29), 3, function()
    StopCurrentEmote()
end)

-- ----------------------------------------------------------------------------
-- TAB 2: MOVEMENT (UNLIMITED WALKSPEED, JUMPPOWER, FLYSPEED, FLY, NOCLIP, INF JUMP)
-- ----------------------------------------------------------------------------
local SecSpeed = UIControls.CreateSection(PageMovement, "SecSpeed", 1)

local WalkToggleUI = UIControls.CreateToggle(SecSpeed, "EnableWalkSpeed", "WalkSpeedEnabled", 1, function(enabled)
    if not enabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end)
    end
end)

local WalkInputUI = UIControls.CreateUnlimitedNumberInput(
    SecSpeed,
    "WalkSpeedInput",
    "WalkSpeedValue",
    { 16, 50, 120, 350, 1000, 5000 },
    32,
    2,
    function(val)
        if State.WalkSpeedEnabled then
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = val end
            end)
        end
    end
)

local JumpToggleUI = UIControls.CreateToggle(SecSpeed, "EnableJumpPower", "JumpPowerEnabled", 3, function(enabled)
    if not enabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = 50
            end
        end)
    end
end)

local JumpInputUI = UIControls.CreateUnlimitedNumberInput(
    SecSpeed,
    "JumpPowerInput",
    "JumpPowerValue",
    { 50, 100, 250, 600, 1500, 5000 },
    75,
    4,
    function(val)
        if State.JumpPowerEnabled then
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.UseJumpPower = true
                    hum.JumpPower = val
                end
            end)
        end
    end
)

local SecFlight = UIControls.CreateSection(PageMovement, "SecFlight", 2)

-- Smooth 6-DOF Fly Controller (BodyGyro + BodyVelocity / CFrame Hybrid)
local FlyController = {
    Active = false,
    BodyGyro = nil,
    BodyVel = nil
}

function FlyController:Stop()
    self.Active = false
    if self.BodyGyro then
        pcall(function() self.BodyGyro:Destroy() end)
        self.BodyGyro = nil
    end
    if self.BodyVel then
        pcall(function() self.BodyVel:Destroy() end)
        self.BodyVel = nil
    end
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end)
end

function FlyController:Start()
    self:Stop()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    self.Active = true
    hum.PlatformStand = true

    local bg = Instance.new("BodyGyro")
    bg.Name = "BimSakSin_FlyGyro"
    bg.P = 9e4
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    self.BodyGyro = bg
    CleanupManager:AddInstance(bg)

    local bv = Instance.new("BodyVelocity")
    bv.Name = "BimSakSin_FlyVel"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    self.BodyVel = bv
    CleanupManager:AddInstance(bv)
end

CleanupManager:OnUnload(function()
    FlyController:Stop()
end)

local FlyToggleUI = UIControls.CreateToggle(SecFlight, "EnableFly", "FlyEnabled", 1, function(enabled)
    if enabled then
        FlyController:Start()
    else
        FlyController:Stop()
    end
end)

local FlyInputUI = UIControls.CreateUnlimitedNumberInput(
    SecFlight,
    "FlySpeedInput",
    "FlySpeedValue",
    { 60, 150, 400, 1000, 3000, 10000 },
    120,
    2
)

local NoclipToggleUI = UIControls.CreateToggle(SecFlight, "EnableNoclip", "NoclipEnabled", 3, function(enabled)
    if not enabled then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end)
    end
end)

local InfJumpToggleUI = UIControls.CreateToggle(SecFlight, "EnableInfJump", "InfiniteJumpEnabled", 4)

-- Infinite Jump Handler
CleanupManager:AddConnection(Services.UserInputService.JumpRequest:Connect(function()
    if CleanupManager.Alive and State.InfiniteJumpEnabled then
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end))

UIControls.CreateButton(SecFlight, "ResetPhysics", Color3.fromRGB(51, 65, 85), 5, function()
    State.WalkSpeedEnabled = false
    State.WalkSpeedValue = 16
    State.JumpPowerEnabled = false
    State.JumpPowerValue = 50
    State.FlyEnabled = false
    State.FlySpeedValue = 120
    State.NoclipEnabled = false
    State.InfiniteJumpEnabled = false

    FlyController:Stop()
    WalkToggleUI.Refresh()
    WalkInputUI.SetValue(16)
    JumpToggleUI.Refresh()
    JumpInputUI.SetValue(50)
    FlyToggleUI.Refresh()
    FlyInputUI.SetValue(120)
    NoclipToggleUI.Refresh()
    InfJumpToggleUI.Refresh()

    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
        end
    end)
    Notify("Movement Physics", "Restored to default WalkSpeed (16) & JumpPower (50)", 2.5)
end)

-- ----------------------------------------------------------------------------
-- TAB 3: COMBAT (AIMBOT + FOV CIRCLE)
-- ----------------------------------------------------------------------------
local SecAimbot = UIControls.CreateSection(PageCombat, "SecAimbot", 1)
UIControls.CreateToggle(SecAimbot, "EnableAimbot", "AimbotEnabled", 1)
UIControls.CreateToggle(SecAimbot, "ShowFOV", "AimbotFOVVisible", 2)
UIControls.CreateSlider(SecAimbot, "AimFOV", "AimbotFOV", 30, 600, 0, 3)
UIControls.CreateSlider(SecAimbot, "AimSmooth", "AimbotSmoothness", 0.05, 1.0, 2, 4)
UIControls.CreateDropdown(SecAimbot, "Aimbot Target", { "Head", "HumanoidRootPart", "UpperTorso" }, function()
    return State.AimbotTargetPart
end, 5, function(opt)
    State.AimbotTargetPart = opt
end)
UIControls.CreateToggle(SecAimbot, "TeamCheck", "AimbotTeamCheck", 6)
UIControls.CreateToggle(SecAimbot, "WallCheck", "AimbotWallCheck", 7)

-- FOV Circle Overlay (Drawing API with UI Stroke fallback)
local FOVCircleDrawing = nil
if Env.HasDrawing then
    pcall(function()
        local circle = Drawing.new("Circle")
        circle.Thickness = 1.6
        circle.NumSides = 64
        circle.Radius = State.AimbotFOV
        circle.Filled = false
        circle.Color = ActiveTheme.Accent
        circle.Transparency = 0.85
        circle.Visible = false
        FOVCircleDrawing = circle
        CleanupManager:AddDrawing(circle)
    end)
end

local function IsSameTeam(plr)
    if not LocalPlayer.Team or not plr.Team then
        return false
    end
    return LocalPlayer.Team == plr.Team
end

local function IsTargetVisible(targetPart, targetChar)
    if not State.AimbotWallCheck then
        return true
    end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, targetChar }
    local result = Services.Workspace:Raycast(origin, direction, params)
    return result == nil
end

local function GetClosestAimbotTarget()
    local bestPart = nil
    local shortestDist = State.AimbotFOV
    local mouseLoc = Services.UserInputService:GetMouseLocation()

    for _, plr in ipairs(Services.Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if not (State.AimbotTeamCheck and IsSameTeam(plr)) then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local part = plr.Character:FindFirstChild(State.AimbotTargetPart) or plr.Character:FindFirstChild("Head")
                if hum and hum.Health > 0 and part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
                        if dist < shortestDist and IsTargetVisible(part, plr.Character) then
                            shortestDist = dist
                            bestPart = part
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

-- ----------------------------------------------------------------------------
-- TAB 4: VISUALS (ESP SUITE: BOX, NAME, HEALTH BAR, TRACERS, 3D CHAMS)
-- ----------------------------------------------------------------------------
local SecESP = UIControls.CreateSection(PageVisuals, "SecESP", 1)
UIControls.CreateToggle(SecESP, "EnableESP", "ESPEnabled", 1)
UIControls.CreateToggle(SecESP, "BoxESP", "ESPBox", 2)
UIControls.CreateToggle(SecESP, "NameESP", "ESPName", 3)
UIControls.CreateToggle(SecESP, "HealthESP", "ESPHealth", 4)
UIControls.CreateToggle(SecESP, "TracerESP", "ESPTracers", 5)
UIControls.CreateToggle(SecESP, "ChamsESP", "ESPChams", 6)
UIControls.CreateToggle(SecESP, "TeamCheck", "ESPTeamCheck", 7)
UIControls.CreateSlider(SecESP, "ESPDist", "ESPMaxDistance", 250, 10000, 0, 8)

local ESPRegistry = {}

local function RemovePlayerESP(plr)
    local entry = ESPRegistry[plr]
    if not entry then return end
    pcall(function()
        if entry.Box then entry.Box:Remove() end
        if entry.Name then entry.Name:Remove() end
        if entry.HealthBg then entry.HealthBg:Remove() end
        if entry.HealthBar then entry.HealthBar:Remove() end
        if entry.Tracer then entry.Tracer:Remove() end
        if entry.Highlight and entry.Highlight.Parent then entry.Highlight:Destroy() end
    end)
    ESPRegistry[plr] = nil
end

local function EnsurePlayerESP(plr)
    if ESPRegistry[plr] then
        return ESPRegistry[plr]
    end
    local entry = {}
    if Env.HasDrawing then
        pcall(function()
            local box = Drawing.new("Square")
            box.Thickness = 1.4
            box.Filled = false
            box.Color = ActiveTheme.Accent
            box.Visible = false
            entry.Box = box

            local nameTxt = Drawing.new("Text")
            nameTxt.Size = 13
            nameTxt.Center = true
            nameTxt.Outline = true
            nameTxt.Color = Color3.fromRGB(255, 255, 255)
            nameTxt.Visible = false
            entry.Name = nameTxt

            local hpBg = Drawing.new("Line")
            hpBg.Thickness = 4
            hpBg.Color = Color3.fromRGB(15, 15, 20)
            hpBg.Visible = false
            entry.HealthBg = hpBg

            local hpBar = Drawing.new("Line")
            hpBar.Thickness = 2.4
            hpBar.Color = Color3.fromRGB(34, 197, 94)
            hpBar.Visible = false
            entry.HealthBar = hpBar

            local tracer = Drawing.new("Line")
            tracer.Thickness = 1.2
            tracer.Color = ActiveTheme.Accent
            tracer.Visible = false
            entry.Tracer = tracer
        end)
    end
    ESPRegistry[plr] = entry
    return entry
end

CleanupManager:AddConnection(Services.Players.PlayerRemoving:Connect(function(plr)
    RemovePlayerESP(plr)
end))

CleanupManager:OnUnload(function()
    for plr, _ in pairs(ESPRegistry) do
        RemovePlayerESP(plr)
    end
end)

-- ----------------------------------------------------------------------------
-- TAB 5: TELEPORTATION (PLAYER TP, SPECTATE, SAVED WAYPOINTS, CTRL+CLICK TP)
-- ----------------------------------------------------------------------------
local SecTPPlayer = UIControls.CreateSection(PageTeleport, "SecTPPlayer", 1)
local SelectedTPTarget = ""
local SpectatingPlayer = false

local function GetOtherPlayerNames()
    local list = {}
    for _, plr in ipairs(Services.Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.Name)
        end
    end
    if #list == 0 then
        table.insert(list, "No Other Players")
    end
    if SelectedTPTarget == "" or SelectedTPTarget == "No Other Players" then
        SelectedTPTarget = list[1]
    end
    return list
end

local PlayerDropdownUI = UIControls.CreateDropdown(SecTPPlayer, "Select Player", GetOtherPlayerNames(), function()
    return SelectedTPTarget
end, 1, function(opt)
    SelectedTPTarget = opt
end)

UIControls.CreateButton(SecTPPlayer, "RefreshPlayers", nil, 2, function()
    local names = GetOtherPlayerNames()
    PlayerDropdownUI.Rebuild(names)
    PlayerDropdownUI.RefreshLabel()
    Notify("Teleport", "Player list refreshed (" .. tostring(#names) .. ")", 2)
end)

UIControls.CreateButton(SecTPPlayer, "TPToPlayer", nil, 3, function()
    local target = Services.Players:FindFirstChild(SelectedTPTarget)
    local targetHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if targetHRP and myHRP then
        myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 2, 3)
        Notify("Teleport", "Teleported to " .. target.Name, 2.5)
    else
        Notify("Teleport", "Target player character not found", 2.5)
    end
end)

UIControls.CreateButton(SecTPPlayer, "SpectatePlayer", Color3.fromRGB(30, 58, 138), 4, function()
    SpectatingPlayer = not SpectatingPlayer
    if SpectatingPlayer then
        local target = Services.Players:FindFirstChild(SelectedTPTarget)
        local targetHum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if targetHum then
            Camera.CameraSubject = targetHum
            Notify("Spectate", "Watching " .. target.Name .. " (Click again to stop)", 3)
        else
            SpectatingPlayer = false
        end
    else
        local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if myHum then
            Camera.CameraSubject = myHum
        end
        Notify("Spectate", "Returned camera to your character", 2)
    end
end)

local SecTPWaypoints = UIControls.CreateSection(PageTeleport, "SecTPWaypoints", 2)
local SavedWaypointCFrame = nil

UIControls.CreateButton(SecTPWaypoints, "SaveWaypoint", nil, 1, function()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then
        SavedWaypointCFrame = myHRP.CFrame
        local pos = myHRP.Position
        Notify("Waypoint Saved", string.format("X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z), 2.5)
    end
end)

UIControls.CreateButton(SecTPWaypoints, "LoadWaypoint", nil, 2, function()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if SavedWaypointCFrame and myHRP then
        myHRP.CFrame = SavedWaypointCFrame
        Notify("Waypoint", "Teleported to saved coordinates", 2.5)
    else
        Notify("Waypoint", "No saved waypoint found yet", 2.5)
    end
end)

UIControls.CreateToggle(SecTPWaypoints, "CtrlClickTP", "CtrlClickTP", 3)

-- Ctrl + Left-Click Teleport Handler
CleanupManager:AddConnection(Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not CleanupManager.Alive or not State.CtrlClickTP then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local ctrlDown = Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or Services.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        if ctrlDown then
            local mouse = LocalPlayer:GetMouse()
            local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if mouse and mouse.Hit and myHRP then
                myHRP.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3.2, 0))
            end
        end
    end
end))

-- ----------------------------------------------------------------------------
-- TAB 6: SETTINGS (16 LANGUAGES, LIVE IP/GEO CARD, THEME, JSON CONFIG, UNLOAD)
-- ----------------------------------------------------------------------------
local SecLangGeo = UIControls.CreateSection(PageSettings, "SecLangGeo", 1)

-- Live Geolocation & IP Card inside Settings
local GeoDetailCard = Utils.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 68),
    BackgroundColor3 = ActiveTheme.BgCard,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = SecLangGeo
})
Utils.Corner(GeoDetailCard, 8)
Utils.Stroke(GeoDetailCard, ActiveTheme.Accent, 1, 0.45)

local GeoCardTitle = Utils.Create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 20),
    Position = UDim2.new(0, 10, 0, 6),
    BackgroundTransparency = 1,
    Text = "🌐 Real-Time Geolocation & IP Telemetry",
    TextColor3 = ActiveTheme.AccentAlt,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = GeoDetailCard
})

local GeoCardLine1 = Utils.Create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18),
    Position = UDim2.new(0, 10, 0, 27),
    BackgroundTransparency = 1,
    Text = "IP: Detecting... | Region: Syncing...",
    TextColor3 = ActiveTheme.TextPrimary,
    TextSize = 11,
    Font = Enum.Font.GothamSemibold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = GeoDetailCard
})

local GeoCardLine2 = Utils.Create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16),
    Position = UDim2.new(0, 10, 0, 46),
    BackgroundTransparency = 1,
    Text = "ISP: Detecting... | Active Language: EN",
    TextColor3 = ActiveTheme.TextMuted,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = GeoDetailCard
})

local function UpdateGeoUI()
    local g = GeoLangAPI.GeoData
    local maskedIP = GeoLangAPI:FormatIPDisplay()
    local locText = string.format("%s, %s (%s)", g.City, g.Country, g.CountryCode)
    GeoHeaderLabel.Text = string.format("%s • %s", g.CountryCode, maskedIP)
    GeoCardLine1.Text = string.format("IP: %s  |  Location: %s", maskedIP, locText)
    GeoCardLine2.Text = string.format("ISP: %s  |  Active Lang: %s", g.ISP, GeoLangAPI.CurrentLang:upper())
end

table.insert(GeoLangAPI.OnGeoUpdated, UpdateGeoUI)

-- 16-Language Selector Dropdown
local LangDropdownUI = UIControls.CreateDropdown(
    SecLangGeo,
    "SelectLanguage",
    GeoLangAPI.LanguageNames,
    function()
        for _, item in ipairs(GeoLangAPI.LanguageNames) do
            if item.Code == State.Language then
                return item.Label
            end
        end
        return GeoLangAPI.CurrentLang:upper()
    end,
    2,
    function(opt)
        State.Language = opt.Code
        GeoLangAPI:SetLanguage(opt.Code)
        UpdateGeoUI()
        Notify("Language Updated", "Active language: " .. opt.Label, 2.5)
    end
)

UIControls.CreateButton(SecLangGeo, "AutoDetectLang", nil, 3, function()
    State.Language = "auto"
    GeoLangAPI:SetLanguage("auto")
    LangDropdownUI.RefreshLabel()
    UpdateGeoUI()
    Notify("GeoLangAPI", "Language synced to region (" .. GeoLangAPI.CurrentLang:upper() .. ")", 2.5)
end)

UIControls.CreateToggle(SecLangGeo, "MaskIPToggle", "MaskIP", 4, function()
    UpdateGeoUI()
end)

UIControls.CreateButton(SecLangGeo, "RefreshGeo", nil, 5, function()
    GeoLangAPI:FetchAsync()
    Notify("GeoLangAPI", "Refreshing real-time IP & location...", 2)
end)

-- Theme & Config Persistence Section
local SecTheme = UIControls.CreateSection(PageSettings, "SecTheme", 2)

local function ApplyThemePreset(presetName)
    local t = Themes[presetName]
    if not t then return end
    ActiveTheme = t
    State.AccentPreset = presetName

    MainWindow.BackgroundColor3 = t.BgPrimary
    MainStroke.Color = t.Accent
    TopBar.BackgroundColor3 = t.BgSecondary
    Sidebar.BackgroundColor3 = t.BgSecondary
    SkullVisual.Stroke.Color = t.Accent
    SkullVisual.EyeLeft.Color = t.Accent
    SkullVisual.EyeRight.Color = t.Accent
    SkullVisual.Crown.Color = t.Accent
    VersionBadge.BackgroundColor3 = t.BgCard
    VersionStroke.Color = t.Accent
    VersionLabel.TextColor3 = t.Accent
    RestorePill.BackgroundColor3 = t.BgSecondary
    RestorePill.TextColor3 = t.Accent

    if FOVCircleDrawing then
        pcall(function() FOVCircleDrawing.Color = t.Accent end)
    end
    if ActiveTabName then
        SelectTab(ActiveTabName)
    end
end

UIControls.CreateDropdown(
    SecTheme,
    "3D Skull Theme",
    { "RoyalGold", "CrimsonSkull", "CyberCyan", "EmeraldVenom", "PhantomViolet" },
    function()
        return State.AccentPreset
    end,
    1,
    function(opt)
        ApplyThemePreset(opt)
        Notify("Theme Updated", "Applied luxury theme: " .. opt, 2)
    end
)

UIControls.CreateSlider(SecTheme, "Window Transparency", "WindowOpacity", 0, 0.45, 2, 2, function(val)
    MainWindow.BackgroundTransparency = val
end)

UIControls.CreateButton(SecTheme, "SaveConfig", nil, 3, function()
    local ok, err = ConfigManager:Save()
    if ok then
        Notify("Config Saved", "Saved to " .. ConfigManager.FilePath, 2.5)
    else
        Notify("Config Info", tostring(err or "Saved in session memory"), 2.5)
    end
end)

UIControls.CreateButton(SecTheme, "LoadConfig", nil, 4, function()
    if ConfigManager:Load() then
        ApplyThemePreset(State.AccentPreset)
        MainWindow.BackgroundTransparency = State.WindowOpacity
        GeoLangAPI:SetLanguage(State.Language)
        UpdateGeoUI()
        Notify("Config Loaded", "Configuration restored from JSON", 2.5)
    else
        Notify("Config", "No saved JSON config found", 2.5)
    end
end)

UIControls.CreateButton(SecTheme, "ResetConfig", Color3.fromRGB(71, 85, 105), 5, function()
    ConfigManager:Reset()
    ApplyThemePreset(State.AccentPreset)
    MainWindow.BackgroundTransparency = State.WindowOpacity
    GeoLangAPI:SetLanguage("auto")
    UpdateGeoUI()
    Notify("Config Reset", "All settings restored to factory defaults", 2.5)
end)

-- System Lifecycle & Full Unload Button
local SecSystem = UIControls.CreateSection(PageSettings, "SecSystem", 3)
UIControls.CreateButton(SecSystem, "UnloadHub", Color3.fromRGB(185, 28, 28), 1, function()
    CleanupManager:Unload()
end)

-- Toggle GUI visibility via RightShift keybind
CleanupManager:AddConnection(Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not CleanupManager.Alive then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        local newState = not MainWindow.Visible
        MainWindow.Visible = newState
        RestorePill.Visible = not newState
    end
end))

-- ============================================================================
-- 8. OPTIMIZED RENDER & PHYSICS LOOPS (SKULL 3D, BADGE SHIMMER, GEO, COMBAT, ESP)
-- ============================================================================
local RenderClock = 0
local LastSafePosition = nil

-- RenderStepped Loop: 3D Skull Animation, Verified Badge Shimmer, Geo Pulse, Aimbot, ESP
CleanupManager:AddConnection(Services.RunService.RenderStepped:Connect(function(dt)
    if not CleanupManager.Alive then return end
    RenderClock = RenderClock + dt

    -- 1. Luxury 3D HD Skull Smooth Orbital & Levitation Render Loop
    if MainWindow.Visible and SkullVisual and SkullVisual.Rig then
        local yaw = math.sin(RenderClock * 1.45) * 0.42
        local pitch = math.cos(RenderClock * 1.1) * 0.12
        local bobY = math.sin(RenderClock * 2.2) * 0.06
        local rotCF = CFrame.new(0, bobY, 0) * CFrame.Angles(pitch, yaw, 0)

        for part, baseCF in pairs(SkullVisual.BaseParts) do
            if part and part.Parent then
                part.CFrame = rotCF * baseCF
            end
        end

        -- Subtle eye socket pulse
        local pulse = 0.72 + 0.28 * math.sin(RenderClock * 3.4)
        SkullVisual.EyeLeft.Color = ActiveTheme.Accent:Lerp(ActiveTheme.AccentAlt, pulse)
        SkullVisual.EyeRight.Color = ActiveTheme.Accent:Lerp(ActiveTheme.AccentAlt, pulse)
    end

    -- 2. Animated Blue Verified Badge Specular Shimmer & Geo Status Pulse
    if MainWindow.Visible and VerifiedVisual and VerifiedVisual.Shimmer then
        local sweep = ((RenderClock * 0.75) % 2) - 1
        VerifiedVisual.Shimmer.Offset = Vector2.new(sweep, 0)

        local status = GeoLangAPI.GeoData.Status
        if status == "Live" then
            local alpha = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(RenderClock * 4))
            GeoPulseDot.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
            GeoPulseDot.BackgroundTransparency = alpha
        elseif status == "Syncing" then
            GeoPulseDot.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
            GeoPulseDot.BackgroundTransparency = 0.1
        else
            GeoPulseDot.BackgroundColor3 = Color3.fromRGB(248, 113, 113)
            GeoPulseDot.BackgroundTransparency = 0.15
        end
    end

    -- 3. Aimbot FOV Circle & Smooth Camera Lock
    local mouseLoc = Services.UserInputService:GetMouseLocation()
    if FOVCircleDrawing then
        FOVCircleDrawing.Position = mouseLoc
        FOVCircleDrawing.Radius = State.AimbotFOV
        FOVCircleDrawing.Visible = (State.AimbotEnabled and State.AimbotFOVVisible)
    end

    if State.AimbotEnabled and Services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local targetPart = GetClosestAimbotTarget()
        if targetPart then
            local goalCF = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            local alpha = math.clamp(State.AimbotSmoothness, 0.02, 1)
            Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
        end
    end

    -- 4. ESP Rendering Loop
    for _, plr in ipairs(Services.Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            local shouldShow = State.ESPEnabled
                and char ~= nil
                and hrp ~= nil
                and hum ~= nil
                and hum.Health > 0
                and not (State.ESPTeamCheck and IsSameTeam(plr))

            if shouldShow then
                local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
                if dist <= State.ESPMaxDistance then
                    local entry = EnsurePlayerESP(plr)

                    -- 3D Highlight Chams
                    if State.ESPChams then
                        if not entry.Highlight or not entry.Highlight.Parent then
                            local hl = Instance.new("Highlight")
                            hl.Name = "BimSakSin_Chams"
                            hl.FillColor = ActiveTheme.Accent
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = 0.65
                            hl.OutlineTransparency = 0.15
                            hl.Adornee = char
                            hl.Parent = char
                            entry.Highlight = hl
                        end
                    elseif entry.Highlight then
                        pcall(function() entry.Highlight:Destroy() end)
                        entry.Highlight = nil
                    end

                    -- 2D Screen Projections
                    local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen and Env.HasDrawing then
                        local topPos = Camera:WorldToViewportPoint((head and head.Position or hrp.Position) + Vector3.new(0, 1.1, 0))
                        local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.6, 0))
                        local boxH = math.max(math.abs(botPos.Y - topPos.Y), 14)
                        local boxW = boxH * 0.58
                        local boxX = rootPos.X - boxW * 0.5
                        local boxY = topPos.Y

                        if entry.Box then
                            entry.Box.Visible = State.ESPBox
                            entry.Box.Size = Vector2.new(boxW, boxH)
                            entry.Box.Position = Vector2.new(boxX, boxY)
                            entry.Box.Color = ActiveTheme.Accent
                        end

                        if entry.Name then
                            entry.Name.Visible = State.ESPName
                            entry.Name.Position = Vector2.new(rootPos.X, boxY - 16)
                            entry.Name.Text = string.format("%s [%.0fm]", plr.DisplayName, dist)
                        end

                        if entry.HealthBg and entry.HealthBar then
                            local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            local barX = boxX - 5
                            entry.HealthBg.Visible = State.ESPHealth
                            entry.HealthBg.From = Vector2.new(barX, boxY + boxH)
                            entry.HealthBg.To = Vector2.new(barX, boxY)

                            entry.HealthBar.Visible = State.ESPHealth
                            entry.HealthBar.From = Vector2.new(barX, boxY + boxH)
                            entry.HealthBar.To = Vector2.new(barX, boxY + boxH - (boxH * hpRatio))
                            entry.HealthBar.Color = Color3.fromRGB(239, 68, 68):Lerp(Color3.fromRGB(34, 197, 94), hpRatio)
                        end

                        if entry.Tracer then
                            entry.Tracer.Visible = State.ESPTracers
                            entry.Tracer.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                            entry.Tracer.To = Vector2.new(rootPos.X, botPos.Y)
                            entry.Tracer.Color = ActiveTheme.Accent
                        end
                    else
                        if entry.Box then entry.Box.Visible = false end
                        if entry.Name then entry.Name.Visible = false end
                        if entry.HealthBg then entry.HealthBg.Visible = false end
                        if entry.HealthBar then entry.HealthBar.Visible = false end
                        if entry.Tracer then entry.Tracer.Visible = false end
                    end
                else
                    RemovePlayerESP(plr)
                end
            else
                RemovePlayerESP(plr)
            end
        end
    end
end))

-- Heartbeat Loop: Unlimited Movement Physics, 6-DOF Fly, Noclip & Character Defense
CleanupManager:AddConnection(Services.RunService.Heartbeat:Connect(function()
    if not CleanupManager.Alive then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- 1. Enforce Unlimited WalkSpeed & JumpPower
    if State.WalkSpeedEnabled and hum.WalkSpeed ~= State.WalkSpeedValue then
        hum.WalkSpeed = State.WalkSpeedValue
    end
    if State.JumpPowerEnabled then
        hum.UseJumpPower = true
        if hum.JumpPower ~= State.JumpPowerValue then
            hum.JumpPower = State.JumpPowerValue
        end
    end

    -- 2. Smooth 6-DOF Fly Velocity & Camera Orientation
    if State.FlyEnabled then
        if not FlyController.Active or not FlyController.BodyVel or not FlyController.BodyVel.Parent then
            FlyController:Start()
        end
        if FlyController.BodyGyro and FlyController.BodyVel then
            local moveDir = Vector3.zero
            local camCF = Camera.CFrame
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + camCF.LookVector
            end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - camCF.LookVector
            end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - camCF.RightVector
            end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + camCF.RightVector
            end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit * State.FlySpeedValue
            end

            FlyController.BodyGyro.CFrame = camCF
            FlyController.BodyVel.Velocity = moveDir
        end
    elseif FlyController.Active then
        FlyController:Stop()
    end

    -- 3. Noclip Collision Bypass
    if State.NoclipEnabled then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- 4. Character Defense Suite
    if State.AntiRagdoll then
        if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if not State.FlyEnabled then
            hum.PlatformStand = false
        end
    end

    if State.AntiFling then
        if hrp.AssemblyAngularVelocity.Magnitude > 50 then
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        if not State.FlyEnabled and hrp.AssemblyLinearVelocity.Magnitude > math.max(State.WalkSpeedValue * 2.5, 220) then
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end

    if State.AntiVoid then
        if hrp.Position.Y > -35 then
            LastSafePosition = hrp.CFrame
        elseif LastSafePosition then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = LastSafePosition + Vector3.new(0, 6, 0)
        end
    end

    if State.AutoHeal and hum.Health > 0 and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
end))

-- Re-bind Fly & Physics on Character Respawn
CleanupManager:AddConnection(LocalPlayer.CharacterAdded:Connect(function()
    if not CleanupManager.Alive then return end
    task.wait(0.35)
    if State.FlyEnabled then
        FlyController:Start()
    end
end))

-- ============================================================================
-- 9. INITIALIZE DEFAULT TAB, LANGUAGE & LIVE GEOLOCATION SYNC
-- ============================================================================
SelectTab("Main")
GeoLangAPI:SetLanguage(State.Language)
GeoLangAPI:FetchAsync()
Notify("BimSakSin Hub v3.0", "3D HD Skull Edition loaded • Press RightShift to toggle", 4)
