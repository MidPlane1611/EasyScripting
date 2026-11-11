--[[
    Easy Scripting - v0.1
    Starter GUI for Roblox executor environments (for projects you own or are
    authorized to test).

    Included in this first build:
      * Projects menu (create, open, delete)
      * Local project saving when the executor provides file functions
      * Luau syntax compilation check (does NOT execute project code)
      * Separate, movable Console with line-aware error messages
      * Basic code templates in Tools

    Not included yet: Dex Explorer, RemoteSpy, or project-code execution.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("Easy Scripting: LocalPlayer is unavailable.")
    return
end

local ROOT_FOLDER = "EasyScripting"
local DATA_FILE = ROOT_FOLDER .. "/projects.json"
local GUI_NAME = "EasyScriptingGui"

local COLORS = {
    Background = Color3.fromRGB(18, 20, 27),
    Panel = Color3.fromRGB(25, 28, 37),
    Panel2 = Color3.fromRGB(32, 36, 47),
    PanelHover = Color3.fromRGB(43, 48, 62),
    Border = Color3.fromRGB(57, 63, 79),
    Text = Color3.fromRGB(235, 238, 245),
    Muted = Color3.fromRGB(151, 160, 179),
    Accent = Color3.fromRGB(105, 145, 255),
    Green = Color3.fromRGB(89, 205, 139),
    Red = Color3.fromRGB(244, 103, 112),
    Yellow = Color3.fromRGB(242, 190, 91),
    Blue = Color3.fromRGB(107, 177, 255),
}

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function addCorner(object, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end

local function addStroke(object, color, transparency)
    make("UIStroke", {
        Color = color or COLORS.Border,
        Thickness = 1,
        Transparency = transparency or 0,
    }, object)
end

local function createLabel(parent, text, size, position, textSize, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Size = size,
        Position = position,
        Text = text or "",
        TextColor3 = color or COLORS.Text,
        TextSize = textSize or 14,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
    }, parent)
end

local function createButton(parent, text, size, position, callback, accent)
    local button = make("TextButton", {
        Size = size,
        Position = position,
        BackgroundColor3 = accent or COLORS.Panel2,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = true,
    }, parent)
    addCorner(button, 8)
    button.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)
    return button
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = target.Position
            dragInput = input
        end
    end)

    handle.InputEnded:Connect(function(input)
        if input == dragInput then
            dragging = false
            dragInput = nil
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

-- Use the executor's hidden GUI container when available; otherwise use CoreGui.
local guiParent
local parentOk, parentResult = pcall(function()
    if type(gethui) == "function" then
        return gethui()
    end
    return game:GetService("CoreGui")
end)

if parentOk and parentResult then
    guiParent = parentResult
else
    guiParent = LocalPlayer:WaitForChild("PlayerGui")
end

pcall(function()
    local oldGui = guiParent:FindFirstChild(GUI_NAME)
    if oldGui then
        oldGui:Destroy()
    end
end)

local screenGui = make("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
}, guiParent)

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local windowWidth = math.max(360, math.min(860, viewport.X - 36))
local windowHeight = math.max(420, math.min(620, viewport.Y - 50))

local window = make("Frame", {
    Name = "MainWindow",
    Size = UDim2.fromOffset(windowWidth, windowHeight),
    Position = UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2),
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, screenGui)
addCorner(window, 12)
addStroke(window, COLORS.Border)

local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
}, window)

local headerTitle = createLabel(header, "  Easy Scripting", UDim2.new(1, -110, 1, 0), UDim2.fromOffset(8, 0), 16, COLORS.Text, Enum.Font.GothamBold)
local headerSubtitle = createLabel(header, "HOME", UDim2.fromOffset(150, 20), UDim2.new(1, -150, 0, 13), 10, COLORS.Muted)
headerSubtitle.TextXAlignment = Enum.TextXAlignment.Right
local closeButton = createButton(header, "×", UDim2.fromOffset(34, 30), UDim2.new(1, -42, 0, 8), function()
    screenGui:Destroy()
end, COLORS.Panel2)
closeButton.TextSize = 20
makeDraggable(header, window)

local body = make("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(0, 46),
    Size = UDim2.new(1, 0, 1, -46),
    BackgroundTransparency = 1,
}, window)

-- Executor-backed file storage. If these functions are missing, projects remain in memory.
local fileStorageAvailable = type(readfile) == "function" and type(writefile) == "function"

local function ensureFolder()
    if type(isfolder) == "function" and isfolder(ROOT_FOLDER) then
        return
    end
    if type(makefolder) == "function" then
        pcall(makefolder, ROOT_FOLDER)
    end
end

local projects = {}
local currentProject = nil
local consoleEntries = {}
local consoleWindow = nil
local consoleList = nil
local consoleCountLabel = nil
local toolsPanel = nil
local editorBox = nil
local editorStatus = nil
local projectsPage = nil
local editorPage = nil

local function projectSize(code)
    local bytes = #(code or "")
    if bytes < 1024 then
        return tostring(bytes) .. " B"
    end
    if bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    end
    return string.format("%.2f MB", bytes / (1024 * 1024))
end

local function saveData()
    if not fileStorageAvailable then
        return false, "Executor file functions are unavailable; projects are stored for this session only."
    end

    ensureFolder()
    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(projects)
    end)
    if not okEncode then
        return false, "Could not encode project data: " .. tostring(encoded)
    end

    local okWrite, writeError = pcall(function()
        writefile(DATA_FILE, encoded)
    end)
    if not okWrite then
        return false, "Could not save projects: " .. tostring(writeError)
    end
    return true, "Projects saved."
end

local function loadData()
    if not fileStorageAvailable then
        return
    end

    ensureFolder()
    local exists = false
    if type(isfile) == "function" then
        local ok, result = pcall(isfile, DATA_FILE)
        exists = ok and result == true
    else
        local ok = pcall(readfile, DATA_FILE)
        exists = ok
    end

    if not exists then
        return
    end

    local okRead, raw = pcall(readfile, DATA_FILE)
    if not okRead then
        return
    end

    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode or type(decoded) ~= "table" then
        warn("Easy Scripting: saved project data could not be read.")
        return
    end

    for _, item in ipairs(decoded) do
        if type(item) == "table" and type(item.name) == "string" and type(item.code) == "string" then
            table.insert(projects, {
                id = tostring(item.id or (os.time() .. "_" .. tostring(math.random(1000, 9999)))),
                name = item.name,
                code = item.code,
                updated = tonumber(item.updated) or os.time(),
            })
        end
    end
end

local function getLineNumber(message)
    if type(message) ~= "string" then
        return nil
    end
    local line = message:match(":(%d+):")
        or message:match("line%s+(%d+)")
        or message:match("Line%s+(%d+)")
    return tonumber(line)
end

local function validateCode(source)
    if type(source) ~= "string" or source:gsub("%s", "") == "" then
        return false, "The script is empty.", nil
    end

    local compiler = loadstring
    if type(compiler) ~= "function" then
        return false, "loadstring is unavailable in this executor. Syntax checking cannot run.", nil
    end

    -- Compile only. The returned function is intentionally NOT executed in v0.1.
    local callOk, compiled, compileError = pcall(compiler, source, "@EasyScriptingProject")
    if not callOk then
        return false, tostring(compiled), getLineNumber(tostring(compiled))
    end
    if not compiled then
        local message = tostring(compileError or "Unknown Luau syntax error.")
        return false, message, getLineNumber(message)
    end

    return true, "No syntax errors detected. Project code was not executed.", nil
end

local function addConsoleEntry(kind, message, line)
    table.insert(consoleEntries, {
        kind = kind,
        message = tostring(message),
        line = line,
        time = os.date("%H:%M:%S"),
    })
end

local function jumpToLine(line)
    if not editorBox or not line or line < 1 then
        return
    end

    local text = editorBox.Text or ""
    local position = 1
    for _ = 1, line - 1 do
        local newline = string.find(text, "\n", position, true)
        if not newline then
            position = #text + 1
            break
        end
        position = newline + 1
    end

    editorBox:CaptureFocus()
    editorBox.CursorPosition = position
    editorBox.SelectionStart = position
end

local function renderConsole()
    if not consoleList then
        return
    end

    for _, child in ipairs(consoleList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local errors = 0
    local warnings = 0
    for _, entry in ipairs(consoleEntries) do
        if entry.kind == "Error" then errors += 1 end
        if entry.kind == "Warning" then warnings += 1 end
    end

    if consoleCountLabel then
        consoleCountLabel.Text = string.format("%d errors  ·  %d warnings  ·  %d messages", errors, warnings, #consoleEntries)
    end

    for index, entry in ipairs(consoleEntries) do
        local color = COLORS.Blue
        local icon = "INFO"
        if entry.kind == "Error" then
            color = COLORS.Red
            icon = "ERROR"
        elseif entry.kind == "Warning" then
            color = COLORS.Yellow
            icon = "WARN"
        elseif entry.kind == "Success" then
            color = COLORS.Green
            icon = "OK"
        end

        local rowHeight = entry.line and 58 or 42
        local row = make("TextButton", {
            Name = "ConsoleEntry" .. index,
            Size = UDim2.new(1, -8, 0, rowHeight),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            AutoButtonColor = entry.line ~= nil,
            Text = "",
            LayoutOrder = index,
        }, consoleList)
        addCorner(row, 7)

        createLabel(row, icon, UDim2.fromOffset(54, 20), UDim2.fromOffset(10, 5), 10, color, Enum.Font.GothamBold)
        createLabel(row, entry.time, UDim2.fromOffset(62, 20), UDim2.new(1, -72, 0, 5), 10, COLORS.Muted)
        local messageLabel = createLabel(row, entry.message, UDim2.new(1, -20, 0, entry.line and 17 or 20), UDim2.fromOffset(10, 25), 11, COLORS.Text)
        messageLabel.TextWrapped = true
        messageLabel.TextYAlignment = Enum.TextYAlignment.Top
        if entry.line then
            local lineLabel = createLabel(row, "Jump to line " .. tostring(entry.line), UDim2.new(1, -20, 0, 17), UDim2.fromOffset(10, 40), 10, COLORS.Accent)
            lineLabel.TextYAlignment = Enum.TextYAlignment.Center
            row.MouseButton1Click:Connect(function()
                jumpToLine(entry.line)
            end)
        end
    end

    local layout = consoleList:FindFirstChildOfClass("UIListLayout")
    if layout then
        consoleList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end
end

local function logConsole(kind, message, line)
    addConsoleEntry(kind, message, line)
    renderConsole()
end

local function openConsole()
    if consoleWindow then
        consoleWindow.Visible = true
        consoleWindow.ZIndex = 20
        renderConsole()
        return
    end

    consoleWindow = make("Frame", {
        Name = "ConsoleWindow",
        Size = UDim2.new(0, math.min(520, windowWidth - 24), 0, 310),
        Position = UDim2.new(0.5, -math.min(520, windowWidth - 24) / 2, 0.5, -155),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, screenGui)
    addCorner(consoleWindow, 10)
    addStroke(consoleWindow, COLORS.Border)

    local consoleHeader = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 21,
    }, consoleWindow)
    addCorner(consoleHeader, 10)
    createLabel(consoleHeader, "  Console", UDim2.new(1, -180, 1, 0), UDim2.fromOffset(8, 0), 14, COLORS.Text, Enum.Font.GothamBold).ZIndex = 22

    consoleCountLabel = createLabel(consoleWindow, "0 errors  ·  0 warnings  ·  0 messages", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 44), 10, COLORS.Muted)
    consoleCountLabel.ZIndex = 21

    local clearButton = createButton(consoleHeader, "Clear", UDim2.fromOffset(54, 26), UDim2.new(1, -100, 0, 8), function()
        consoleEntries = {}
        renderConsole()
    end)
    clearButton.ZIndex = 22
    local closeConsole = createButton(consoleHeader, "×", UDim2.fromOffset(30, 26), UDim2.new(1, -38, 0, 8), function()
        consoleWindow.Visible = false
    end)
    closeConsole.ZIndex = 22
    closeConsole.TextSize = 18

    consoleList = make("ScrollingFrame", {
        Name = "Messages",
        Position = UDim2.fromOffset(10, 70),
        Size = UDim2.new(1, -20, 1, -80),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 21,
    }, consoleWindow)
    local consoleLayout = make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, consoleList)
    consoleLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if consoleList then
            consoleList.CanvasSize = UDim2.fromOffset(0, consoleLayout.AbsoluteContentSize.Y + 8)
        end
    end)
    makeDraggable(consoleHeader, consoleWindow)
    renderConsole()
end

-- Main page: project list.
projectsPage = make("Frame", {
    Name = "ProjectsPage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
}, body)

local mainToolbar = make("Frame", {
    Size = UDim2.new(1, -24, 0, 44),
    Position = UDim2.fromOffset(12, 8),
    BackgroundTransparency = 1,
}, projectsPage)

createButton(mainToolbar, "▣  Projects", UDim2.fromOffset(125, 34), UDim2.fromOffset(0, 4), function()
    -- Already on the Projects page; this button is intentionally a navigation marker.
end, COLORS.Panel2)

local projectsRunButton = createButton(mainToolbar, "▶  Run Projects", UDim2.fromOffset(138, 34), UDim2.new(1, -138, 0, 4), function()
    consoleEntries = {}
    if #projects == 0 then
        logConsole("Info", "There are no saved projects yet.")
    else
        for _, project in ipairs(projects) do
            local ok, message, line = validateCode(project.code)
            if ok then
                logConsole("Success", project.name .. ": syntax check passed.")
            else
                logConsole("Error", project.name .. ": " .. message, line)
            end
        end
    end
    openConsole()
end, COLORS.Panel2)

createLabel(projectsPage, "Saved projects", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(14, 55), 13, COLORS.Muted, Enum.Font.GothamMedium)

local projectList = make("ScrollingFrame", {
    Name = "ProjectList",
    Position = UDim2.fromOffset(12, 82),
    Size = UDim2.new(1, -24, 1, -145),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    CanvasSize = UDim2.fromOffset(0, 0),
}, projectsPage)
local projectLayout = make("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, projectList)
projectLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    projectList.CanvasSize = UDim2.fromOffset(0, projectLayout.AbsoluteContentSize.Y + 8)
end)

local function renderProjects()
    for _, child in ipairs(projectList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for index, project in ipairs(projects) do
        local card = make("Frame", {
            Name = "ProjectCard_" .. tostring(project.id),
            Size = UDim2.new(1, -8, 0, 76),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = index,
        }, projectList)
        addCorner(card, 9)
        addStroke(card, COLORS.Border, 0.45)

        createLabel(card, project.name, UDim2.new(1, -190, 0, 25), UDim2.fromOffset(14, 9), 14, COLORS.Text, Enum.Font.GothamBold)
        createLabel(card, "Luau project  ·  " .. projectSize(project.code), UDim2.new(1, -190, 0, 20), UDim2.fromOffset(14, 38), 10, COLORS.Muted)

        createButton(card, "Open", UDim2.fromOffset(62, 30), UDim2.new(1, -140, 0.5, -15), function()
            currentProject = project
            editorBox.Text = project.code or ""
            headerSubtitle.Text = project.name
            projectsPage.Visible = false
            editorPage.Visible = true
            editorStatus.Text = "Saved project loaded"
            consoleEntries = {}
            logConsole("Info", "Opened project: " .. project.name)
        end, COLORS.Accent)

        createButton(card, "Delete", UDim2.fromOffset(62, 30), UDim2.new(1, -70, 0.5, -15), function()
            for projectIndex, existing in ipairs(projects) do
                if existing.id == project.id then
                    table.remove(projects, projectIndex)
                    break
                end
            end
            local saved, message = saveData()
            renderProjects()
            logConsole(saved and "Success" or "Warning", saved and ("Deleted project: " .. project.name) or message)
        end, COLORS.Panel2)
    end

    if #projects == 0 then
        local empty = make("Frame", {
            Size = UDim2.new(1, -8, 0, 100),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, projectList)
        addCorner(empty, 9)
        createLabel(empty, "No projects yet", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(12, 20), 14, COLORS.Text, Enum.Font.GothamBold)
        createLabel(empty, "Select Add Project to create your first project.", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 49), 11, COLORS.Muted)
    end
end

local addProjectButton = createButton(projectsPage, "+  Add Project", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -50), nil, COLORS.Accent)

-- Project creation dialog.
local function showCreateProjectPopup()
    local overlay = make("Frame", {
        Name = "CreateProjectOverlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.38,
        BorderSizePixel = 0,
        ZIndex = 30,
    }, window)

    local popup = make("Frame", {
        Size = UDim2.fromOffset(340, 190),
        Position = UDim2.new(0.5, -170, 0.5, -95),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 31,
    }, overlay)
    addCorner(popup, 10)
    addStroke(popup, COLORS.Border)

    createLabel(popup, "Create a project", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(14, 12), 15, COLORS.Text, Enum.Font.GothamBold).ZIndex = 32
    createLabel(popup, "Project name", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(14, 48), 11, COLORS.Muted).ZIndex = 32

    local nameBox = make("TextBox", {
        Size = UDim2.new(1, -28, 0, 38),
        Position = UDim2.fromOffset(14, 70),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "My Roblox Project",
        PlaceholderColor3 = COLORS.Muted,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        ZIndex = 32,
    }, popup)
    addCorner(nameBox, 7)

    local cancelButton = createButton(popup, "Cancel", UDim2.fromOffset(92, 32), UDim2.new(1, -206, 1, -45), function()
        overlay:Destroy()
    end)
    cancelButton.ZIndex = 32

    local createButtonObject = createButton(popup, "Create", UDim2.fromOffset(92, 32), UDim2.new(1, -106, 1, -45), function()
        local name = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then
            nameBox.PlaceholderText = "Please enter a project name"
            return
        end

        local newProject = {
            id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)),
            name = name,
            code = "-- " .. name .. "\n\n",
            updated = os.time(),
        }
        table.insert(projects, newProject)
        saveData()
        overlay:Destroy()
        renderProjects()
        logConsole("Success", "Created project: " .. name)
    end, COLORS.Accent)
    createButtonObject.ZIndex = 32
    nameBox:CaptureFocus()
end

addProjectButton.MouseButton1Click:Connect(showCreateProjectPopup)

-- Editor page: the editor toolbar is only visible while a project is open.
editorPage = make("Frame", {
    Name = "EditorPage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
}, body)

local editorToolbar = make("Frame", {
    Size = UDim2.new(1, -20, 0, 42),
    Position = UDim2.fromOffset(10, 7),
    BackgroundTransparency = 1,
}, editorPage)

createButton(editorToolbar, "←", UDim2.fromOffset(36, 32), UDim2.fromOffset(0, 4), function()
    if currentProject and editorBox then
        currentProject.code = editorBox.Text
        currentProject.updated = os.time()
        saveData()
    end
    editorPage.Visible = false
    projectsPage.Visible = true
    headerSubtitle.Text = "HOME"
    renderProjects()
end, COLORS.Panel2).TextSize = 18

local toolsButton = createButton(editorToolbar, "Tools ▾", UDim2.fromOffset(88, 32), UDim2.fromOffset(44, 4), function()
    if toolsPanel then
        toolsPanel.Visible = not toolsPanel.Visible
    end
end)

createButton(editorToolbar, "▶  Run Script", UDim2.fromOffset(118, 32), UDim2.fromOffset(140, 4), function()
    if not currentProject then return end
    local ok, message, line = validateCode(editorBox.Text)
    if ok then
        logConsole("Success", message)
        editorStatus.Text = "Syntax check passed · code not executed"
        editorStatus.TextColor3 = COLORS.Green
    else
        logConsole("Error", message, line)
        editorStatus.Text = line and ("Syntax error on line " .. line) or "Syntax check failed"
        editorStatus.TextColor3 = COLORS.Red
    end
    openConsole()
end, COLORS.Panel2)

createButton(editorToolbar, "Save", UDim2.fromOffset(66, 32), UDim2.new(1, -150, 0, 4), function()
    if not currentProject then return end
    currentProject.code = editorBox.Text
    currentProject.updated = os.time()
    local saved, message = saveData()
    if saved then
        editorStatus.Text = "Saved · " .. projectSize(currentProject.code)
        editorStatus.TextColor3 = COLORS.Green
        logConsole("Success", "Saved project: " .. currentProject.name)
    else
        editorStatus.Text = "Session copy updated · file saving unavailable"
        editorStatus.TextColor3 = COLORS.Yellow
        logConsole("Warning", message)
    end
end, COLORS.Panel2)

createButton(editorToolbar, "Console", UDim2.fromOffset(76, 32), UDim2.new(1, -78, 0, 4), openConsole, COLORS.Panel2)

local editorSurface = make("Frame", {
    Position = UDim2.fromOffset(10, 56),
    Size = UDim2.new(1, -20, 1, -91),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
}, editorPage)
addCorner(editorSurface, 8)
addStroke(editorSurface, COLORS.Border, 0.5)

createLabel(editorSurface, "MAIN.LUA", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(12, 5), 10, COLORS.Muted, Enum.Font.GothamBold)
editorBox = make("TextBox", {
    Name = "CodeEditor",
    Position = UDim2.fromOffset(12, 32),
    Size = UDim2.new(1, -24, 1, -42),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "-- Start writing Luau code here...",
    PlaceholderColor3 = COLORS.Muted,
    TextColor3 = COLORS.Text,
    TextSize = 13,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = false,
    MultiLine = true,
    ClearTextOnFocus = false,
}, editorSurface)

editorStatus = createLabel(editorPage, "Ready", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 1, -27), 10, COLORS.Muted)

-- Tools dropdown with safe, ordinary Luau templates for projects you own.
toolsPanel = make("Frame", {
    Name = "ToolsPanel",
    Size = UDim2.fromOffset(250, 300),
    Position = UDim2.fromOffset(54, 48),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 15,
}, editorPage)
addCorner(toolsPanel, 9)
addStroke(toolsPanel, COLORS.Border)
createLabel(toolsPanel, "Code helpers", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 5), 13, COLORS.Text, Enum.Font.GothamBold).ZIndex = 16

local helperScroll = make("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 36),
    Size = UDim2.new(1, -16, 1, -44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 0),
    ZIndex = 16,
}, toolsPanel)
local helperLayout = make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, helperScroll)
helperLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    helperScroll.CanvasSize = UDim2.fromOffset(0, helperLayout.AbsoluteContentSize.Y + 4)
end)

local function insertSnippet(snippet)
    local current = editorBox.Text or ""
    local separator = current == "" and "" or "\n\n"
    editorBox.Text = current .. separator .. snippet
    editorBox.CursorPosition = #editorBox.Text + 1
    editorBox:CaptureFocus()
    toolsPanel.Visible = false
    editorStatus.Text = "Template inserted · remember to edit placeholder names"
    editorStatus.TextColor3 = COLORS.Muted
end

local helpers = {
    { "Variable", "local variableName = nil" },
    { "Local player", "local Players = game:GetService(\"Players\")\nlocal player = Players.LocalPlayer" },
    { "Character / Humanoid", "local player = game:GetService(\"Players\").LocalPlayer\nlocal character = player.Character or player.CharacterAdded:Wait()\nlocal humanoid = character:WaitForChild(\"Humanoid\")" },
    { "Movement (MoveTo)", "local player = game:GetService(\"Players\").LocalPlayer\nlocal character = player.Character or player.CharacterAdded:Wait()\nlocal humanoid = character:WaitForChild(\"Humanoid\")\nhumanoid:MoveTo(Vector3.new(0, 0, 0))" },
    { "Object coordinates", "local target = workspace:WaitForChild(\"Part\")\nlocal position = target.Position\nprint(\"Position:\", position)" },
    { "Parent change listener", "local target = workspace:WaitForChild(\"Part\")\ntarget:GetPropertyChangedSignal(\"Parent\"):Connect(function()\n    print(\"New Parent:\", target.Parent)\nend)" },
    { "RemoteEvent listener (own game)", "local remoteEvent = game:GetService(\"ReplicatedStorage\"):WaitForChild(\"RemoteEvent\")\nremoteEvent.OnClientEvent:Connect(function(...)\n    print(\"RemoteEvent received:\", ...)\nend)" },
}

for index, helper in ipairs(helpers) do
    local helperButton = createButton(helperScroll, helper[1], UDim2.new(1, -4, 0, 34), UDim2.new(), function()
        insertSnippet(helper[2])
    end, COLORS.Panel2)
    helperButton.LayoutOrder = index
    helperButton.ZIndex = 17
end

local plannedLabel = createLabel(toolsPanel, "Dex Explorer / RemoteSpy: planned", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 1, -21), 9, COLORS.Muted)
plannedLabel.ZIndex = 17

-- Load saved projects and show the main page.
loadData()
renderProjects()

if not fileStorageAvailable then
    logConsole("Warning", "This executor does not expose readfile/writefile. Projects will only persist during this session.")
else
    logConsole("Info", "Project storage is ready: " .. DATA_FILE)
end

print("Easy Scripting v0.1 loaded.")
