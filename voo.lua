-- ================================================
-- FLY COMPLETO (PC + MOBILE)
-- PC: Espaço sobe / Shift desce / WASD move
-- Mobile: Botões ↑↓ para subir/descer + joystick para mover
-- Com GUI, velocidade, mover, minimizar e fechar
-- ================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ============ CONFIGURAÇÕES ============
local VELOCIDADE_MIN = 30
local VELOCIDADE_MAX = 300
local VELOCIDADE_INICIAL = 120
local PASSO_VELOCIDADE = 10
local VELOCIDADE_MAX_FISICA = 250

local COR_FUNDO = Color3.fromRGB(35, 35, 40)
local COR_BOTAO = Color3.fromRGB(60, 60, 70)
local COR_OK = Color3.fromRGB(0, 170, 0)
local COR_OFF = Color3.fromRGB(170, 0, 0)
local COR_FECHAR = Color3.fromRGB(200, 50, 50)
local COR_MINIMIZAR = Color3.fromRGB(200, 160, 0)
local COR_MOVER = Color3.fromRGB(70, 130, 200)
local COR_MOVER_ATIVO = Color3.fromRGB(0, 170, 0)

-- ============ ESTADO ============
local voando = false
local velocidade = VELOCIDADE_INICIAL
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
    estadoOriginal.WalkSpeed = hum.WalkSpeed
    estadoOriginal.JumpPower = hum.JumpPower
    estadoOriginal.HipHeight = hum.HipHeight
    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    pcall(function()
        self.rootPart:SetNetworkOwner(player)
    end)
end

function AntiDetect:parar()
    if not self.ativo then return end
    self.ativo = false
    local hum = self.humanoid
    for _, c in ipairs(self.conexoes) do
        pcall(function() c:Disconnect() end)
    end
    self.conexoes = {}
    if not hum or not hum.Parent then return end
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
screenGui.Name = "FlyGui_" .. tostring(math.random(100, 999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 260, 0, 210)
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

-- Botão VOAR
local botaoVoo = criarBotao("BotaoVoo", "✈ Voar: OFF",
    UDim2.new(1, -130, 0, 45), UDim2.new(0, 10, 0, 10), COR_OFF, container)

-- Botão MINIMIZAR
local botaoMinimizar = criarBotao("BotaoMinimizar", "—",
    UDim2.new(0, 30, 0, 20), UDim2.new(1, -100, 0, 5), COR_MINIMIZAR, container)

-- Botão MOVER
local botaoMover = criarBotao("BotaoMover", "✥",
    UDim2.new(0, 30, 0, 20), UDim2.new(1, -65, 0, 5), COR_MOVER, container)

-- Botão FECHAR
local botaoFechar = criarBotao("BotaoFechar", "✖",
    UDim2.new(0, 30, 0, 20), UDim2.new(1, -30, 0, 5), COR_FECHAR, container)

-- Botão MENOS
local botaoMenos = criarBotao("BotaoMenos", "-",
    UDim2.new(0, 60, 0, 50), UDim2.new(0, 15, 0, 70), COR_BOTAO, container)

-- Label VELOCIDADE
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

-- Título VELOCIDADE
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

-- Botão MAIS
local botaoMais = criarBotao("BotaoMais", "+",
    UDim2.new(0, 60, 0, 50), UDim2.new(1, -75, 0, 70), COR_BOTAO, container)

-- Dica de uso
local labelDica = Instance.new("TextLabel")
labelDica.Name = "LabelDica"
labelDica.Size = UDim2.new(1, -20, 0, 18)
labelDica.Position = UDim2.new(0, 10, 0, 185)
labelDica.BackgroundTransparency = 1
labelDica.TextColor3 = Color3.fromRGB(140, 140, 150)
labelDica.Text = "Espaço = subir | Shift = descer"
labelDica.TextScaled = true
labelDica.Font = Enum.Font.Gotham
labelDica.Parent = container

-- Botão Reabrir
local botaoReabrir = criarBotao("BotaoReabrir", "✈ Abrir Fly",
    UDim2.new(0, 120, 0, 40), UDim2.new(0, 20, 0.05, 0),
    Color3.fromRGB(0, 120, 200), screenGui)
botaoReabrir.Visible = false
botaoReabrir.TextScaled = false
botaoReabrir.TextSize = 16

-- ==================================================
-- BOTÕES MOBILE (↑ ↓) - aparecem só no mobile
-- ==================================================

local controlesMobile = Instance.new("Frame")
controlesMobile.Name = "ControlesMobile"
controlesMobile.AnchorPoint = Vector2.new(1, 1)
controlesMobile.Position = UDim2.new(1, -30, 1, -30)
controlesMobile.Size = UDim2.new(0, 90, 0, 180)
controlesMobile.BackgroundTransparency = 1
controlesMobile.Visible = false
controlesMobile.Parent = screenGui

local function criarBotaoMobile(nome, texto, posicao)
    local btn = Instance.new("TextButton")
    btn.Name = nome
    btn.Text = texto
    btn.Size = UDim2.new(0, 80, 0, 80)
    btn.Position = posicao
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.5
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
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

local btnSubir = criarBotaoMobile("Subir", "↑", UDim2.new(0, 5, 0, 0))
local btnDescer = criarBotaoMobile("Descer", "↓", UDim2.new(0, 5, 0, 100))

-- Configura os botões para detectar toque
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
    -- Suporte extra para touch
    btn.TouchLongPress:Connect(function() end)
    btn.TouchTap:Connect(function() end)
end

configurarToque(btnSubir)
configurarToque(btnDescer)

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
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false

    local camera = workspace.CurrentCamera

    conexaoRender = RunService.RenderStepped:Connect(function()
        if not bodyVelocity or not bodyVelocity.Parent then return end

        local direcao = Vector3.zero

        if not isMobile then
            -- PC: WASD move horizontal (sem afetar Y)
            local camCF = camera.CFrame
            local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
            local rightFlat = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direcao += lookFlat
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direcao -= lookFlat
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direcao -= rightFlat
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direcao += rightFlat
            end

            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                direcao += Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                direcao -= Vector3.new(0, 1, 0)
            end
        else
            -- Mobile: joystick horizontal + botões ↑↓
            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude > 0.1 then
                local camCF = camera.CFrame
                local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
                local rightFlat = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

                direcao += lookFlat * moveDir.Z
                direcao += rightFlat * moveDir.X
            end

            -- Botões ↑↓
            if btnSubir:GetAttribute("pressionado") then
                direcao += Vector3.new(0, 1, 0)
            end
            if btnDescer:GetAttribute("pressionado") then
                direcao -= Vector3.new(0, 1, 0)
            end
        end

        if direcao.Magnitude > 0.1 then
            bodyVelocity.Velocity = antiDetect:clampVelocidade(direcao.Unit * velocidade)
        else
            bodyVelocity.Velocity = Vector3.zero
        end

        bodyGyro.CFrame = CFrame.new(rootPart.Position, rootPart.Position + camera.CFrame.LookVector)
    end)

    -- Mostra os botões ↑↓ no mobile
    if isMobile then
        controlesMobile.Visible = true
    end
end

local function desativarVoo()
    if antiDetect then
        antiDetect:parar()
    end

    if conexaoRender then
        conexaoRender:Disconnect()
        conexaoRender = nil
    end

    if bodyVelocity then
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.MaxForce = Vector3.zero
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    if bodyGyro then
        bodyGyro.MaxTorque = Vector3.zero
        bodyGyro:Destroy()
        bodyGyro = nil
    end

    if rootPart then
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end

    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)

        task.wait(0.05)

        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        task.wait(0.05)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end

    -- Esconde os botões mobile
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
        botaoVoo.Text = "✈ Voar: OFF"
        botaoVoo.BackgroundColor3 = COR_OFF
    end
end

if player.Character then
    configurarPersonagem(player.Character)
end
player.CharacterAdded:Connect(configurarPersonagem)

-- ==================================================
-- BOTÃO DE VOAR
-- ==================================================

botaoVoo.MouseButton1Click:Connect(function()
    if not rootPart then return end
    voando = not voando
    if voando then
        ativarVoo()
        botaoVoo.Text = "✈ Voar: ON"
        botaoVoo.BackgroundColor3 = COR_OK
    else
        desativarVoo()
        botaoVoo.Text = "✈ Voar: OFF"
        botaoVoo.BackgroundColor3 = COR_OFF
    end
end)

-- ==================================================
-- BOTÕES DE VELOCIDADE
-- ==================================================

botaoMais.MouseButton1Click:Connect(function()
    velocidade = math.min(velocidade + PASSO_VELOCIDADE, VELOCIDADE_MAX)
    atualizarLabel()
end)

botaoMenos.MouseButton1Click:Connect(function()
    velocidade = math.max(velocidade - PASSO_VELOCIDADE, VELOCIDADE_MIN)
    atualizarLabel()
end)

-- ==================================================
-- MINIMIZAR / FECHAR / REABRIR
-- ==================================================

local function esconderElementos(visivel)
    botaoVoo.Visible = visivel
    botaoMais.Visible = visivel
    botaoMenos.Visible = visivel
    labelVelocidade.Visible = visivel
    labelTitulo.Visible = visivel
    labelDica.Visible = visivel
end

botaoMinimizar.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    if minimizado then
        esconderElementos(false)
        botaoMinimizar.Text = "+"
        container.Size = UDim2.new(0, 130, 0, 30)
    else
        esconderElementos(true)
        botaoMinimizar.Text = "—"
        container.Size = UDim2.new(0, 260, 0, 210)
    end
end)

botaoFechar.MouseButton1Click:Connect(function()
    if voando then
        voando = false
        desativarVoo()
        botaoVoo.Text = "✈ Voar: OFF"
        botaoVoo.BackgroundColor3 = COR_OFF
    end
    container.Visible = false
    botaoReabrir.Visible = true
end)

botaoReabrir.MouseButton1Click:Connect(function()
    container.Visible = true
    botaoReabrir.Visible = false
    if minimizado then
        minimizado = false
        esconderElementos(true)
        botaoMinimizar.Text = "—"
        container.Size = UDim2.new(0, 260, 0, 210)
    end
end)

-- ==================================================
-- SISTEMA DE ARRASTAR
-- ==================================================

local movendo = false
local arrastando = false
local inicioToque = Vector2.new(0, 0)
local posicaoInicial = UDim2.new(0, 0, 0, 0)

local function toqueDentro(input)
    local pos = input.Position
    local guiPos = container.AbsolutePosition
    local guiSize = container.AbsoluteSize
    return pos.X >= guiPos.X and pos.X <= guiPos.X + guiSize.X
        and pos.Y >= guiPos.Y and pos.Y <= guiPos.Y + guiSize.Y
end

botaoMover.MouseButton1Click:Connect(function()
    movendo = not movendo
    if movendo then
        botaoMover.Text = "🔒"
        botaoMover.BackgroundColor3 = COR_MOVER_ATIVO
    else
        botaoMover.Text = "✥"
        botaoMover.BackgroundColor3 = COR_MOVER
    end
end)

UserInputService.InputBegan:Connect(function(input, processado)
    if processado then return end
    if not movendo then return end
    if not toqueDentro(input) then return end

    local guiObjects = player.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
    for _, obj in ipairs(guiObjects) do
        if obj:IsA("TextButton") then return end
    end

    arrastando = true
    inicioToque = Vector2.new(input.Position.X, input.Position.Y)
    posicaoInicial = container.Position
end)

UserInputService.InputChanged:Connect(function(input, processado)
    if processado then return end
    if not arrastando then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local delta = Vector2.new(input.Position.X, input.Position.Y) - inicioToque
    container.Position = UDim2.new(
        posicaoInicial.X.Scale, posicaoInicial.X.Offset + delta.X,
        posicaoInicial.Y.Scale, posicaoInicial.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        arrastando = false
    end
end)

-- ==================================================
-- INICIALIZAÇÃO
-- ==================================================
atualizarLabel()
