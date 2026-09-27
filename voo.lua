-- ================================================
-- SCRIPT DE VOO COMPLETO (PC + MOBILE)
-- Com GUI automática + Anti-Detect
-- 2 botões mobile: ↑ subir / ↓ descer
-- ================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ============ CONFIGURAÇÕES ============
local VELOCIDADE_MIN = 10
local VELOCIDADE_MAX = 200
local VELOCIDADE_INICIAL = 50
local PASSO_VELOCIDADE = 10
local FORCA_SUBIR = 50
local VELOCIDADE_MAX_FISICA = 90

local COR_FUNDO = Color3.fromRGB(35, 35, 40)
local COR_BOTAO = Color3.fromRGB(60, 60, 70)
local COR_OK = Color3.fromRGB(0, 170, 0)
local COR_OFF = Color3.fromRGB(170, 0, 0)
local COR_FECHAR = Color3.fromRGB(200, 50, 50)
local COR_MINIMIZAR = Color3.fromRGB(200, 160, 0)

-- ============ ESTADO ============
local voando = false
local velocidade = VELOCIDADE_INICIAL
local velocidadeAtual = Vector3.zero
local bodyVelocity, bodyGyro
local conexaoRender
local character, humanoid, rootPart
local minimizado = false

local estadoOriginal = {
    WalkSpeed = 16,
    JumpPower = 50,
    HipHeight = 2,
}

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==================================================
-- ANTI-DETECT
-- ==================================================

local AntiDetect = {}
AntiDetect.__index = AntiDetect

function AntiDetect.new(humanoid, rootPart)
    local self = setmetatable({}, AntiDetect)
    self.humanoid = humanoid
    self.rootPart = rootPart
    self.ativo = false
    self.conexoes = {}
    self.nomeAleatorio = "Force" .. tostring(math.random(1000, 9999))
    return self
end

function AntiDetect:iniciar()
    if self.ativo then return end
    self.ativo = true

    local hum = self.humanoid
    local root = self.rootPart

    estadoOriginal.WalkSpeed = hum.WalkSpeed
    estadoOriginal.JumpPower = hum.JumpPower
    estadoOriginal.HipHeight = hum.HipHeight

    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    self.conexoes[#self.conexoes + 1] = RunService.Stepped:Connect(function()
        if not hum or not hum.Parent then return end
        if hum.FloorMaterial == Enum.Material.Air then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end)
        end
    end)

    pcall(function()
        root:SetNetworkOwner(player)
    end)
end

function AntiDetect:parar()
    if not self.ativo then return end
    self.ativo = false

    local hum = self.humanoid

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
    end)

    pcall(function()
        hum.WalkSpeed = estadoOriginal.WalkSpeed
        hum.JumpPower = estadoOriginal.JumpPower
        hum.HipHeight = estadoOriginal.HipHeight
    end)

    for _, c in ipairs(self.conexoes) do
        pcall(function() c:Disconnect() end)
    end
    self.conexoes = {}
end

function AntiDetect:clampVelocidade(vec)
    local mag = vec.Magnitude
    if mag > VELOCIDADE_MAX_FISICA then
        return vec.Unit * VELOCIDADE_MAX_FISICA
    end
    return vec
end

-- ==================================================
-- CRIAÇÃO DA GUI
-- ==================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VooGui_" .. tostring(math.random(100, 999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 260, 0, 230)
container.Position = UDim2.new(0, 20, 0.3, 0)
container.BackgroundColor3 = COR_FUNDO
container.BackgroundTransparency = 0.1
container.BorderSizePixel = 0
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 12)
containerCorner.Parent = container

local containerStroke = Instance.new("UIStroke")
containerStroke.Color = Color3.fromRGB(80, 80, 90)
containerStroke.Thickness = 1.5
containerStroke.Parent = container

local function criarBotao(nome, texto, tamanho, posicao, corFundo, parent)
    local btn = Instance.new("TextButton")
    btn.Name = nome
    btn.Text = texto
    btn.Size = tamanho
    btn.Position = posicao
    btn.BackgroundColor3 = corFundo or COR_BOTAO
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local botaoVoo = criarBotao("BotaoVoo", "Voar: OFF",
    UDim2.new(1, -90, 0, 45), UDim2.new(0, 10, 0, 10), COR_OFF, container)

local botaoMinimizar = criarBotao("BotaoMinimizar", "—",
    UDim2.new(0, 30, 0, 20), UDim2.new(1, -65, 0, 5), COR_MINIMIZAR, container)

local botaoFechar = criarBotao("BotaoFechar", "✖",
    UDim2.new(0, 30, 0, 20), UDim2.new(1, -30, 0, 5), COR_FECHAR, container)

local botaoMenos = criarBotao("BotaoMenos", "-",
    UDim2.new(0, 60, 0, 50), UDim2.new(0, 15, 0, 70), COR_BOTAO, container)

local labelVelocidade = Instance.new("TextLabel")
labelVelocidade.Name = "LabelVelocidade"
labelVelocidade.Size = UDim2.new(0, 90, 0, 50)
labelVelocidade.Position = UDim2.new(0.5, -45, 0, 70)
labelVelocidade.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
labelVelocidade.TextColor3 = Color3.new(1, 1, 1)
labelVelocidade.Text = tostring(velocidade)
labelVelocidade.TextScaled = true
labelVelocidade.Font = Enum.Font.GothamBold
labelVelocidade.BorderSizePixel = 0
labelVelocidade.Parent = container

local labelCorner = Instance.new("UICorner")
labelCorner.CornerRadius = UDim.new(0, 8)
labelCorner.Parent = labelVelocidade

local labelStroke = Instance.new("UIStroke")
labelStroke.Color = Color3.fromRGB(100, 100, 110)
labelStroke.Thickness = 1
labelStroke.Parent = labelVelocidade

local labelTitulo = Instance.new("TextLabel")
labelTitulo.Name = "LabelTitulo"
labelTitulo.Size = UDim2.new(1, -20, 0, 20)
labelTitulo.Position = UDim2.new(0, 10, 0, 125)
labelTitulo.BackgroundTransparency = 1
labelTitulo.TextColor3 = Color3.fromRGB(180, 180, 190)
labelTitulo.Text = "VELOCIDADE"
labelTitulo.TextScaled = true
labelTitulo.Font = Enum.Font.Gotham
labelTitulo.Parent = container

local botaoMais = criarBotao("BotaoMais", "+",
    UDim2.new(0, 60, 0, 50), UDim2.new(1, -75, 0, 70), COR_BOTAO, container)

-- ==================================================
-- CONTROLES MOBILE (2 botões: ↑ e ↓ ao lado do pulo)
-- ==================================================

local controlesMobile = Instance.new("Frame")
controlesMobile.Name = "ControlesMobile"
controlesMobile.AnchorPoint = Vector2.new(1, 1)
controlesMobile.Position = UDim2.new(1, -120, 1, -30)
controlesMobile.Size = UDim2.new(0, 120, 0, 200)
controlesMobile.BackgroundTransparency = 1
controlesMobile.Visible = false
controlesMobile.Parent = screenGui

-- Função pra criar botão redondo (estilo touch do Roblox)
local function criarBotaoMobile(nome, texto, posicao, tamanho)
    local btn = Instance.new("TextButton")
    btn.Name = nome
    btn.Text = texto
    btn.Size = tamanho
    btn.Position = posicao
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.5
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = controlesMobile

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = btn

    return btn
end

-- Botão SUBIR (↑) — em cima
local btnSubir = criarBotaoMobile("Subir", "↑",
    UDim2.new(0, 0, 0, 0),
    UDim2.new(0, 80, 0, 80))

-- Botão DESCER (↓) — embaixo
local btnDescer = criarBotaoMobile("Descer", "↓",
    UDim2.new(0, 0, 0, 110),
    UDim2.new(0, 80, 0, 80))

-- Botão Reabrir (fora do container)
local botaoReabrir = criarBotao("BotaoReabrir", "☰ Abrir Voo",
    UDim2.new(0, 130, 0, 45), UDim2.new(0, 20, 0.05, 0),
    Color3.fromRGB(0, 120, 200), screenGui)
botaoReabrir.Visible = false
botaoReabrir.TextScaled = false
botaoReabrir.TextSize = 16

-- ==================================================
-- FUNÇÕES DE VOO
-- ==================================================

local antiDetect

local function atualizarLabel()
    labelVelocidade.Text = tostring(velocidade)
end

local function ativarVoo()
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = antiDetect.nomeAleatorio .. "_BV"
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = rootPart

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = antiDetect.nomeAleatorio .. "_BG"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 10000
    bodyGyro.D = 500
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart

    antiDetect:iniciar()

    local camera = workspace.CurrentCamera

    conexaoRender = RunService.RenderStepped:Connect(function()
        if not bodyVelocity or not bodyVelocity.Parent then return end

        local direcao = Vector3.zero

        -- PC: WASD
        if not isMobile then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direcao += camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direcao -= camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direcao -= camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direcao += camera.CFrame.RightVector end
        end

        -- Mobile: só usa o joystick nativo para mover horizontalmente
        if isMobile then
            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude > 0.1 then
                direcao += moveDir
            end
        end

        local velFinal
        if direcao.Magnitude > 0 then
            velFinal = (direcao.Unit * velocidade) + velocidadeAtual
        else
            velFinal = velocidadeAtual
        end

        bodyVelocity.Velocity = antiDetect:clampVelocidade(velFinal)
        bodyGyro.CFrame = CFrame.new(rootPart.Position, rootPart.Position + camera.CFrame.LookVector)
    end)

    controlesMobile.Visible = isMobile
end

local function desativarVoo()
    if antiDetect then
        antiDetect:parar()
    end

    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    if conexaoRender then conexaoRender:Disconnect() end
    velocidadeAtual = Vector3.zero
    controlesMobile.Visible = false
end

-- ==================================================
-- PERSONAGEM
-- ==================================================

local function configurarPersonagem(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")

    antiDetect = AntiDetect.new(humanoid, rootPart)

    if voando then
        voando = false
        desativarVoo()
        botaoVoo.Text = "Voar: OFF"
        botaoVoo.BackgroundColor3 = COR_OFF
    end
end

if player.Character then
    configurarPersonagem(player.Character)
end
player.CharacterAdded:Connect(configurarPersonagem)

-- ==================================================
-- CONEXÕES DOS BOTÕES
-- ==================================================

botaoVoo.MouseButton1Click:Connect(function()
    if not rootPart then return end
    voando = not voando
    if voando then
        ativarVoo()
        botaoVoo.Text = "Voar: ON"
        botaoVoo.BackgroundColor3 = COR_OK
    else
        desativarVoo()
        botaoVoo.Text = "Voar: OFF"
        botaoVoo.BackgroundColor3 = COR_OFF
    end
end)

botaoMais.MouseButton1Click:Connect(function()
    velocidade = math.min(velocidade + PASSO_VELOCIDADE, VELOCIDADE_MAX)
    atualizarLabel()
end)

botaoMenos.MouseButton1Click:Connect(function()
    velocidade = math.max(velocidade - PASSO_VELOCIDADE, VELOCIDADE_MIN)
    atualizarLabel()
end)

local function esconderElementos(visivel)
    botaoVoo.Visible = visivel
    botaoMais.Visible = visivel
    botaoMenos.Visible = visivel
    labelVelocidade.Visible = visivel
    labelTitulo.Visible = visivel
end

botaoMinimizar.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    if minimizado then
        esconderElementos(false)
        botaoMinimizar.Text = "+"
        container.Size = UDim2.new(0, 70, 0, 30)
    else
        esconderElementos(true)
        botaoMinimizar.Text = "—"
        container.Size = UDim2.new(0, 260, 0, 230)
    end
end)

botaoFechar.MouseButton1Click:Connect(function()
    if voando then
        voando = false
        desativarVoo()
        botaoVoo.Text = "Voar: OFF"
        botaoVoo.BackgroundColor3 = COR_OFF
    end
    container.Visible = false
    controlesMobile.Visible = false
    botaoReabrir.Visible = true
end)

botaoReabrir.MouseButton1Click:Connect(function()
    container.Visible = true
    botaoReabrir.Visible = false
    if minimizado then
        minimizado = false
        esconderElementos(true)
        botaoMinimizar.Text = "—"
        container.Size = UDim2.new(0, 260, 0, 230)
    end
end)

-- ==================================================
-- BOTÕES MOBILE: SUBIR / DESCER
-- ==================================================

local function configurarToque(btn)
    btn.MouseButton1Down:Connect(function()
        btn:SetAttribute("pressionado", true)
    end)
    btn.MouseButton1Up:Connect(function()
        btn:SetAttribute("pressionado", false)
    end)
    btn.MouseLeave:Connect(function()
        btn:SetAttribute("pressionado", false)
    end)
    btn.TouchTap:Connect(function() end)
end

configurarToque(btnSubir)
configurarToque(btnDescer)

-- Loop de atualização dos botões mobile
RunService.RenderStepped:Connect(function()
    if not voando then
        velocidadeAtual = Vector3.zero
        return
    end

    if btnSubir:GetAttribute("pressionado") then
        velocidadeAtual = Vector3.new(0, FORCA_SUBIR, 0)
    elseif btnDescer:GetAttribute("pressionado") then
        velocidadeAtual = Vector3.new(0, -FORCA_SUBIR, 0)
    else
        velocidadeAtual = Vector3.zero
    end
end)

-- ==================================================
-- INICIALIZAÇÃO
-- ==================================================
atualizarLabel()
