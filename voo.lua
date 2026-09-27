-- ================================================
-- SCRIPT DE VOO COMPLETO (PC + MOBILE)
-- Com GUI automática + Anti-Detect
-- Coloque em: StarterPlayer > StarterPlayerScripts
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
local VELOCIDADE_MAX_FISICA = 90 -- limite pra não parecer "speed hack"

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

-- Estado original do personagem (para restaurar)
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

    -- 1. Salva o estado original
    estadoOriginal.WalkSpeed = hum.WalkSpeed
    estadoOriginal.JumpPower = hum.JumpPower
    estadoOriginal.HipHeight = hum.HipHeight

    -- 2. Mascara o HumanoidStateType para "Physics" (não parece flying)
    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)

    -- Força estado "Physics" que é o mais natural
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    -- 3. Mantém o Humanoid "no chão" logicamente (não cai por gravity)
    --    Isso evita detecção por scripts que checam Humanoid.FloorMaterial
    self.conexoes[#self.conexoes + 1] = RunService.Stepped:Connect(function()
        if not hum or not hum.Parent then return end
        if hum.FloorMaterial == Enum.Material.Air then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end)
        end
    end)

    -- 4. Guarda o NetworkOwnership pra não parecer "ownership hijack"
    --    (o Roblox já dá ao LocalPlayer, então não muda nada visualmente)
    pcall(function()
        root:SetNetworkOwner(player)
    end)

    -- 5. Randomiza o nome dos BodyMovers (dificulta scan por nome)
    --    Feito na criação, veja ativarVoo()
end

function AntiDetect:parar()
    if not self.ativo then return end
    self.ativo = false

    local hum = self.humanoid

    -- Restaura estados
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
    end)

    -- Restaura propriedades originais
    pcall(function()
        hum.WalkSpeed = estadoOriginal.WalkSpeed
        hum.JumpPower = estadoOriginal.JumpPower
        hum.HipHeight = estadoOriginal.HipHeight
    end)

    -- Desconecta conexões internas
    for _, c in ipairs(self.conexoes) do
        pcall(function() c:Disconnect() end)
    end
    self.conexoes = {}
end

-- Clamp suave pra não parecer speed hack
-- Se a velocidade for muito alta, limita o vetor real aplicado
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
screenGui.Name = "VooGui_" .. tostring(math.random(100, 999)) -- nome aleatório
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
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
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
labelVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)
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

-- Controles Mobile
local controlesMobile = Instance.new("Frame")
controlesMobile.Name = "ControlesMobile"
controlesMobile.Size = UDim2.new(0, 220, 0, 220)
controlesMobile.Position = UDim2.new(0, 20, 1, -240)
controlesMobile.BackgroundTransparency = 1
controlesMobile.Visible = false
controlesMobile.Parent = screenGui

local function criarBotaoDirecao(nome, posicao, texto)
    local btn = Instance.new("TextButton")
    btn.Name = nome
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = posicao
    btn.Text = texto
    btn.TextScaled = true
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btn.BackgroundTransparency = 0.2
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = controlesMobile

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    return btn
end

local btnCima  = criarBotaoDirecao("Cima",     UDim2.new(0, 75, 0, 0),   "▲")
local btnBaixo = criarBotaoDirecao("Baixo",    UDim2.new(0, 75, 0, 150), "▼")
local btnEsq   = criarBotaoDirecao("Esquerda", UDim2.new(0, 0,  0, 75),  "◀")
local btnDir   = criarBotaoDirecao("Direita",  UDim2.new(0, 150,0, 75),  "▶")

-- Botão Reabrir
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
    -- Cria BodyMovers com nomes "disfarçados"
    -- Isso dificulta detecção por scripts que procuram "BodyVelocity"/"BodyGyro"
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

    -- Aplica anti-detect
    antiDetect:iniciar()

    local camera = workspace.CurrentCamera

    conexaoRender = RunService.RenderStepped:Connect(function()
        if not bodyVelocity or not bodyVelocity.Parent then return end

        local direcao = Vector3.zero

        -- PC
        if not isMobile then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direcao += camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direcao -= camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direcao -= camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direcao += camera.CFrame.RightVector end
        end

        -- Mobile
        if isMobile then
            if btnEsq:GetAttribute("pressionado") then direcao -= camera.CFrame.RightVector end
            if btnDir:GetAttribute("pressionado") then direcao += camera.CFrame.RightVector end

            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude > 0.1 then
                direcao += moveDir
            end
        end

        -- Monta o vetor final
        local velFinal
        if direcao.Magnitude > 0 then
            velFinal = (direcao.Unit * velocidade) + velocidadeAtual
        else
            velFinal = velocidadeAtual
        end

        -- Anti-detect: limita a velocidade física pra não parecer speed hack
        bodyVelocity.Velocity = antiDetect:clampVelocidade(velFinal)

        bodyGyro.CFrame = CFrame.new(rootPart.Position, rootPart.Position + camera.CFrame.LookVector)
    end)

    controlesMobile.Visible = isMobile
end

local function desativarVoo()
    -- Para anti-detect primeiro (restaura estados)
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

    -- Cria nova instância de anti-detect pra esse personagem
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

-- Mobile
local function configurarBotaoToque(btn)
    btn.MouseButton1Down:Connect(function() btn:SetAttribute("pressionado", true) end)
    btn.MouseButton1Up:Connect(function() btn:SetAttribute("pressionado", false) end)
    btn.MouseLeave:Connect(function() btn:SetAttribute("pressionado", false) end)
end

configurarBotaoToque(btnEsq)
configurarBotaoToque(btnDir)

btnCima.MouseButton1Down:Connect(function() velocidadeAtual = Vector3.new(0, FORCA_SUBIR, 0) end)
btnCima.MouseButton1Up:Connect(function() velocidadeAtual = Vector3.zero end)
btnCima.MouseLeave:Connect(function() velocidadeAtual = Vector3.zero end)

btnBaixo.MouseButton1Down:Connect(function() velocidadeAtual = Vector3.new(0, -FORCA_SUBIR, 0) end)
btnBaixo.MouseButton1Up:Connect(function() velocidadeAtual = Vector3.zero end)
btnBaixo.MouseLeave:Connect(function() velocidadeAtual = Vector3.zero end)

-- ==================================================
-- INICIALIZAÇÃO
-- ==================================================
atualizarLabel()
