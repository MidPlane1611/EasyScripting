--[[
    Easy Scripting v1.0
    Built from the user's original, working v0.1 source.

    Main features:
      * Original large desktop window size (up to 860 x 620)
      * Projects: create, open, rename, delete, legacy v0.1 migration
      * File/folder tree for each project; multiple Luau files
      * Execute page: run selected saved files and mark Auto Execute files
      * Run Script button performs syntax compilation only
      * Separate movable Console with line-aware errors
      * Tools menu: scoped Dex Explorer, scoped RemoteSpy, camera-only FreeCam
      * Mobile newline button and touch-friendly controls
      * Executor file persistence when readfile/writefile are available

    SAFETY / SCOPE:
      * Dex Explorer only displays Workspace.EasyScriptingTestObjects.
      * RemoteSpy only listens to incoming RemoteEvents under
        ReplicatedStorage.EasyScriptingRemotes.
      * These folders are intended for projects you own or are allowed to test.
      * FreeCam moves only the camera; it never moves the character's root part.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("Easy Scripting: LocalPlayer is unavailable.")
    return
end

local ROOT_FOLDER = "EasyScripting"
local DATA_FILE = ROOT_FOLDER .. "/projects.json"
local GUI_NAME = "EasyScriptingGui"
local VERSION = "v1.0"

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
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
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

local logConsole

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
        Active = true,
        Selectable = true,
    }, parent)
    addCorner(button, 8)
    button.Activated:Connect(function()
        if callback then
            local ok, err = pcall(callback)
            if not ok then
                warn("Easy Scripting button error: " .. tostring(err))
                if logConsole then
                    logConsole("Error", "Button error: " .. tostring(err))
                end
            end
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

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function formatBytes(bytes)
    if bytes < 1024 then
        return tostring(bytes) .. " B"
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    end
    return string.format("%.2f MB", bytes / (1024 * 1024))
end

local function normalizePath(path)
    path = tostring(path or ""):gsub("\\", "/")
    path = path:gsub("^/+", ""):gsub("/+$", "")
    if path == "" or path:find("..", 1, true) or path:find("//", 1, true) then
        return nil
    end
    return path
end

local function splitPath(path)
    local parts = {}
    for part in string.gmatch(path or "", "[^/]+") do
        table.insert(parts, part)
    end
    return parts
end

local function parentPath(path)
    local position = string.match(path or "", "^.*()/")
    if position then
        return string.sub(path, 1, position - 1)
    end
    return ""
end

local function leafName(path)
    local parts = splitPath(path)
    return parts[#parts] or path
end

-- GUI parent: gethui is used only when the executor exposes it.
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
local touchDevice = UserInputService.TouchEnabled
local windowWidth = math.max(300, math.min(860, viewport.X - 24))
local windowHeight = math.max(340, math.min(620, viewport.Y - 40))
local compact = touchDevice or windowWidth < 520

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
local headerTitle = createLabel(header, "  Easy Scripting " .. VERSION, UDim2.new(1, -190, 1, 0), UDim2.fromOffset(8, 0), 16, COLORS.Text, Enum.Font.GothamBold)
local headerSubtitle = createLabel(header, "HOME", UDim2.fromOffset(150, 20), UDim2.new(1, -194, 0, 13), 10, COLORS.Muted)
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

-- Local project storage. If Delta's file APIs are absent, the current session still works.
local fileStorageAvailable = type(readfile) == "function" and type(writefile) == "function"
local function ensureFolder()
    if type(isfolder) == "function" then
        local ok, exists = pcall(isfolder, ROOT_FOLDER)
        if ok and exists then
            return
        end
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
local editorBox = nil
local editorStatus = nil
local editorFileLabel = nil
local projectsPage = nil
local executePage = nil
local editorPage = nil
local toolsPanel = nil
local renderProjects
local renderExecutePage
local renderFileTree
local stopFreeCam
local expandedFolders = { [""] = true }
local selectedTreePath = "main.lua"
local selectedTreeIsFolder = false

local function getProjectFile(project, path)
    if not project or type(project.files) ~= "table" then
        return nil
    end
    for _, file in ipairs(project.files) do
        if file.path == path then
            return file
        end
    end
    return nil
end

local function ensureProjectStructure(project)
    if type(project.files) ~= "table" then
        project.files = {}
    end
    if type(project.folders) ~= "table" then
        project.folders = {}
    end

    -- Migrate v0.1 projects (which only had project.code) without losing code.
    if #project.files == 0 then
        table.insert(project.files, {
            path = "main.lua",
            code = type(project.code) == "string" and project.code or "",
            autoExecute = false,
        })
    end
    if type(project.activeFile) ~= "string" or not getProjectFile(project, project.activeFile) then
        project.activeFile = project.files[1].path
    end
    local active = getProjectFile(project, project.activeFile)
    project.code = active and active.code or (project.code or "")
end

local function getProjectSize(project)
    ensureProjectStructure(project)
    local bytes = 0
    for _, file in ipairs(project.files) do
        bytes = bytes + #(file.path or "") + #(file.code or "")
    end
    for _, folder in ipairs(project.folders) do
        bytes = bytes + #tostring(folder)
    end
    return formatBytes(bytes)
end

local function saveData()
    if not fileStorageAvailable then
        return false, "Delta file APIs are unavailable. Projects will remain available until this session ends."
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
        warn("Easy Scripting: could not read saved projects: " .. tostring(raw))
        return
    end
    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode or type(decoded) ~= "table" then
        warn("Easy Scripting: saved project data is invalid JSON.")
        return
    end

    for _, item in ipairs(decoded) do
        if type(item) == "table" and type(item.name) == "string" then
            local project = {
                id = tostring(item.id or (os.time() .. "_" .. tostring(math.random(1000, 9999)))),
                name = item.name,
                code = type(item.code) == "string" and item.code or "",
                files = type(item.files) == "table" and item.files or {},
                folders = type(item.folders) == "table" and item.folders or {},
                activeFile = type(item.activeFile) == "string" and item.activeFile or "main.lua",
                updated = tonumber(item.updated) or os.time(),
            }
            -- Sanitize loaded file entries and migrate old entries.
            local safeFiles = {}
            for _, file in ipairs(project.files) do
                if type(file) == "table" and type(file.path) == "string" and type(file.code) == "string" then
                    local safePath = normalizePath(file.path)
                    if safePath then
                        table.insert(safeFiles, {
                            path = safePath,
                            code = file.code,
                            autoExecute = file.autoExecute == true,
                        })
                    end
                end
            end
            project.files = safeFiles
            local safeFolders = {}
            for _, folder in ipairs(project.folders) do
                local safePath = normalizePath(folder)
                if safePath then
                    table.insert(safeFolders, safePath)
                end
            end
            project.folders = safeFolders
            ensureProjectStructure(project)
            table.insert(projects, project)
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
        return false, "loadstring is unavailable; syntax checking cannot run in this environment.", nil
    end
    local callOk, compiled, compileError = pcall(compiler, source, "@EasyScriptingProject")
    if not callOk then
        local message = tostring(compiled)
        return false, message, getLineNumber(message)
    end
    if not compiled then
        local message = tostring(compileError or "Unknown Luau syntax error.")
        return false, message, getLineNumber(message)
    end
    return true, "No syntax errors detected. This check does not execute the code.", nil
end

local function addConsoleEntry(kind, message, line)
    table.insert(consoleEntries, {
        kind = kind,
        message = tostring(message),
        line = line,
        time = os.date("%H:%M:%S"),
    })
    while #consoleEntries > 200 do
        table.remove(consoleEntries, 1)
    end
end

local function jumpToLine(line)
    if not editorBox or not line or line < 1 then
        return
    end
    local source = editorBox.Text or ""
    local position = 1
    for _ = 1, line - 1 do
        local newline = string.find(source, "\n", position, true)
        if not newline then
            position = #source + 1
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
        if entry.kind == "Error" then
            errors = errors + 1
        elseif entry.kind == "Warning" then
            warnings = warnings + 1
        end
    end
    if consoleCountLabel then
        consoleCountLabel.Text = string.format("%d errors  ·  %d warnings  ·  %d messages", errors, warnings, #consoleEntries)
    end

    for index, entry in ipairs(consoleEntries) do
        local color = COLORS.Blue
        local tag = "INFO"
        if entry.kind == "Error" then
            color = COLORS.Red
            tag = "ERROR"
        elseif entry.kind == "Warning" then
            color = COLORS.Yellow
            tag = "WARN"
        elseif entry.kind == "Success" then
            color = COLORS.Green
            tag = "OK"
        end

        local rowHeight = entry.line and 58 or 44
        local row = make("TextButton", {
            Name = "ConsoleEntry" .. tostring(index),
            Size = UDim2.new(1, -8, 0, rowHeight),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            AutoButtonColor = entry.line ~= nil,
            Text = "",
            LayoutOrder = index,
            Active = true,
        }, consoleList)
        addCorner(row, 7)
        createLabel(row, tag, UDim2.fromOffset(54, 18), UDim2.fromOffset(9, 3), 9, color, Enum.Font.GothamBold)
        createLabel(row, entry.time, UDim2.fromOffset(64, 18), UDim2.new(1, -72, 0, 3), 9, COLORS.Muted)
        local messageLabel = createLabel(row, entry.message, UDim2.new(1, -18, 0, entry.line and 24 or 21), UDim2.fromOffset(9, 22), 10, COLORS.Text)
        messageLabel.TextWrapped = true
        messageLabel.TextYAlignment = Enum.TextYAlignment.Top
        if entry.line then
            createLabel(row, "Tap to jump to line " .. tostring(entry.line), UDim2.new(1, -18, 0, 14), UDim2.fromOffset(9, 42), 9, COLORS.Accent)
            row.Activated:Connect(function()
                jumpToLine(entry.line)
            end)
        end
    end
    local layout = consoleList:FindFirstChildOfClass("UIListLayout")
    if layout then
        consoleList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end
end

logConsole = function(kind, message, line)
    addConsoleEntry(kind, message, line)
    renderConsole()
end

local function openConsole()
    if consoleWindow then
        consoleWindow.Visible = true
        renderConsole()
        return
    end

    local width = math.max(260, math.min(520, windowWidth - 24))
    local height = math.min(340, math.max(220, windowHeight - 100))
    consoleWindow = make("Frame", {
        Name = "ConsoleWindow",
        Size = UDim2.fromOffset(width, height),
        Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        ZIndex = 40,
    }, screenGui)
    addCorner(consoleWindow, 10)
    addStroke(consoleWindow, COLORS.Border)

    local consoleHeader = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 41,
    }, consoleWindow)
    addCorner(consoleHeader, 10)
    local title = createLabel(consoleHeader, "  Console", UDim2.new(1, -170, 1, 0), UDim2.fromOffset(8, 0), 14, COLORS.Text, Enum.Font.GothamBold)
    title.ZIndex = 42
    local clearButton = createButton(consoleHeader, "Clear", UDim2.fromOffset(54, 26), UDim2.new(1, -98, 0, 8), function()
        consoleEntries = {}
        renderConsole()
    end)
    clearButton.ZIndex = 42
    local closeConsole = createButton(consoleHeader, "×", UDim2.fromOffset(30, 26), UDim2.new(1, -36, 0, 8), function()
        consoleWindow.Visible = false
    end)
    closeConsole.TextSize = 18
    closeConsole.ZIndex = 42

    consoleCountLabel = createLabel(consoleWindow, "0 errors  ·  0 warnings  ·  0 messages", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 44), 10, COLORS.Muted)
    consoleCountLabel.ZIndex = 41
    consoleList = make("ScrollingFrame", {
        Name = "Messages",
        Position = UDim2.fromOffset(10, 70),
        Size = UDim2.new(1, -20, 1, -80),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 41,
    }, consoleWindow)
    local layout = make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, consoleList)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if consoleList then
            consoleList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
        end
    end)
    makeDraggable(consoleHeader, consoleWindow)
    renderConsole()
end

-- Pages and navigation.
projectsPage = make("Frame", {
    Name = "ProjectsPage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
}, body)

executePage = make("Frame", {
    Name = "ExecutePage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
}, body)

editorPage = make("Frame", {
    Name = "EditorPage",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
}, body)

local mainToolbar = make("Frame", {
    Size = UDim2.new(1, -24, 0, 44),
    Position = UDim2.fromOffset(12, 8),
    BackgroundTransparency = 1,
}, projectsPage)

local function showProjectsPage()
    projectsPage.Visible = true
    executePage.Visible = false
    editorPage.Visible = false
    headerSubtitle.Text = "HOME"
    if renderProjects then renderProjects() end
end

local function showExecutePage()
    projectsPage.Visible = false
    executePage.Visible = true
    editorPage.Visible = false
    headerSubtitle.Text = "EXECUTE"
    if renderExecutePage then renderExecutePage() end
end

createButton(mainToolbar, "▣  Projects", UDim2.fromOffset(125, 34), UDim2.fromOffset(0, 4), showProjectsPage, COLORS.Panel2)
createButton(mainToolbar, "▶  Execute", UDim2.fromOffset(138, 34), UDim2.new(1, -138, 0, 4), showExecutePage, COLORS.Panel2)

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
local projectLayout = make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, projectList)
projectLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    projectList.CanvasSize = UDim2.fromOffset(0, projectLayout.AbsoluteContentSize.Y + 8)
end)

local function syncEditorToFile(project, source)
    if not project then return nil end
    ensureProjectStructure(project)
    local file = getProjectFile(project, project.activeFile)
    if not file then
        file = {path = project.activeFile or "main.lua", code = "", autoExecute = false}
        table.insert(project.files, file)
    end
    if source ~= nil then
        file.code = source
    end
    project.code = file.code or ""
    project.updated = os.time()
    return file
end

local function updateProjectCardMeta(project, label)
    if label then
        label.Text = "Luau project  ·  " .. getProjectSize(project) .. "  ·  " .. tostring(#project.files) .. " file(s)"
    end
end

local function showTextPopup(titleText, initialText, confirmText, onConfirm)
    local overlay = make("Frame", {
        Name = "InputOverlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.38,
        BorderSizePixel = 0,
        ZIndex = 80,
    }, window)
    local popupWidth = math.min(360, windowWidth - 30)
    local popupHeight = 194
    local popup = make("Frame", {
        Size = UDim2.fromOffset(popupWidth, popupHeight),
        Position = UDim2.new(0.5, -popupWidth / 2, 0.5, -popupHeight / 2),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 81,
    }, overlay)
    addCorner(popup, 10)
    addStroke(popup, COLORS.Border)
    local title = createLabel(popup, titleText, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(14, 10), 15, COLORS.Text, Enum.Font.GothamBold)
    title.ZIndex = 82
    local input = make("TextBox", {
        Size = UDim2.new(1, -28, 0, 40),
        Position = UDim2.fromOffset(14, 55),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        Text = initialText or "",
        PlaceholderText = "Enter a name",
        PlaceholderColor3 = COLORS.Muted,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        ZIndex = 82,
    }, popup)
    addCorner(input, 7)
    local message = createLabel(popup, "", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 99), 10, COLORS.Red)
    message.ZIndex = 82

    local cancelButton = createButton(popup, "Cancel", UDim2.fromOffset(88, 32), UDim2.new(1, -190, 1, -44), function()
        overlay:Destroy()
    end)
    cancelButton.ZIndex = 82
    local confirmButton = createButton(popup, confirmText or "Confirm", UDim2.fromOffset(88, 32), UDim2.new(1, -102, 1, -44), function()
        local value = trim(input.Text)
        if value == "" then
            message.Text = "Name cannot be empty."
            return
        end
        local ok, err = onConfirm(value)
        if ok then
            overlay:Destroy()
        else
            message.Text = tostring(err or "Could not complete this action.")
        end
    end, COLORS.Accent)
    confirmButton.ZIndex = 82
    -- Do not auto-focus: on phones this can hide the Create button behind the keyboard.
    return overlay, input
end

local function createProject(name)
    name = trim(name)
    if name == "" then name = "My project" end
    local newCode = "-- " .. name .. "\n\n"
    local project = {
        id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)),
        name = name,
        code = newCode,
        files = {{path = "main.lua", code = newCode, autoExecute = false}},
        folders = {},
        activeFile = "main.lua",
        updated = os.time(),
    }
    table.insert(projects, project)
    local saved, message = saveData()
    if renderProjects then renderProjects() end
    logConsole(saved and "Success" or "Warning", saved and ("Created project: " .. name) or ("Created project for this session. " .. message))
end

local function showCreateProjectPopup()
    showTextPopup("Create project", "My project", "Create", function(value)
        createProject(value)
        return true
    end)
end

local function showRenameProjectPopup(project)
    showTextPopup("Rename project", project.name, "Rename", function(value)
        local oldName = project.name
        project.name = value
        project.updated = os.time()
        local saved, message = saveData()
        if renderProjects then renderProjects() end
        logConsole(saved and "Success" or "Warning", saved and ("Renamed " .. oldName .. " to " .. value) or ("Renamed for this session. " .. message))
        return true
    end)
end

local function openProject(project)
    currentProject = project
    ensureProjectStructure(project)
    local file = getProjectFile(project, project.activeFile)
    editorBox.Text = file and file.code or ""
    selectedTreePath = project.activeFile or "main.lua"
    selectedTreeIsFolder = false
    if editorFileLabel then editorFileLabel.Text = project.activeFile end
    headerSubtitle.Text = project.name
    projectsPage.Visible = false
    executePage.Visible = false
    editorPage.Visible = true
    editorStatus.Text = "Project opened · " .. tostring(#project.files) .. " file(s)"
    editorStatus.TextColor3 = COLORS.Green
    consoleEntries = {}
    logConsole("Info", "Opened project: " .. project.name)
    if renderFileTree then renderFileTree() end
end

renderProjects = function()
    for _, child in ipairs(projectList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    for index, project in ipairs(projects) do
        ensureProjectStructure(project)
        local card = make("Frame", {
            Name = "ProjectCard_" .. tostring(project.id),
            Size = UDim2.new(1, -8, 0, 104),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = index,
        }, projectList)
        addCorner(card, 9)
        addStroke(card, COLORS.Border, 0.45)

        local nameLabel = createLabel(card, project.name, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(14, 7), 14, COLORS.Text, Enum.Font.GothamBold)
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        local metaLabel = createLabel(card, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(14, 31), 10, COLORS.Muted)
        updateProjectCardMeta(project, metaLabel)

        -- Actions are deliberately placed on their own row at the LEFT of the card.
        -- This avoids right-edge clipping on narrow screens and makes all buttons visible.
        local openButton = createButton(card, "Open Project", UDim2.fromOffset(compact and 104 or 126, 30), UDim2.fromOffset(12, 64), function()
            openProject(project)
        end, COLORS.Accent)
        openButton.TextSize = compact and 10 or 11

        local renameX = compact and 124 or 148
        local renameButton = createButton(card, "Rename", UDim2.fromOffset(compact and 76 or 88, 30), UDim2.fromOffset(renameX, 64), function()
            showRenameProjectPopup(project)
        end, COLORS.Panel2)
        renameButton.TextSize = 10

        local deleteX = renameX + (compact and 82 or 94)
        local deleteButton = createButton(card, "Delete", UDim2.fromOffset(compact and 68 or 78, 30), UDim2.fromOffset(deleteX, 64), function()
            local projectName = project.name
            if currentProject == project then
                currentProject = nil
            end
            for projectIndex, existing in ipairs(projects) do
                if existing.id == project.id then
                    table.remove(projects, projectIndex)
                    break
                end
            end
            local saved, message = saveData()
            renderProjects()
            if renderExecutePage then renderExecutePage() end
            logConsole(saved and "Success" or "Warning", saved and ("Deleted project: " .. projectName) or ("Deleted for this session. " .. message))
        end, Color3.fromRGB(105, 47, 57))
        deleteButton.TextSize = 10
    end

    if #projects == 0 then
        local empty = make("Frame", {
            Size = UDim2.new(1, -8, 0, 104),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, projectList)
        addCorner(empty, 9)
        createLabel(empty, "No projects yet", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(12, 20), 14, COLORS.Text, Enum.Font.GothamBold)
        createLabel(empty, "Press Add Project to create your first project.", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 49), 11, COLORS.Muted)
    end
end

local addProjectButton = createButton(projectsPage, "+  Add Project", UDim2.new(1, -24, 0, 42), UDim2.new(0, 12, 1, -50), showCreateProjectPopup, COLORS.Accent)

-- Execute page: saved files can be run manually; Auto Execute toggles are saved per file.
createButton(executePage, "▣  Projects", UDim2.fromOffset(125, 34), UDim2.fromOffset(12, 8), showProjectsPage, COLORS.Panel2)
createLabel(executePage, "Execute saved files", UDim2.new(1, -164, 0, 24), UDim2.fromOffset(148, 8), 14, COLORS.Text, Enum.Font.GothamBold)
local executeDescription = createLabel(executePage,
    "Run files you wrote or are authorized to test. Auto Execute files run when Easy Scripting loads.",
    UDim2.new(1, -164, 0, 34), UDim2.fromOffset(148, 32), 9, COLORS.Muted)
executeDescription.TextWrapped = true

local executeList = make("ScrollingFrame", {
    Name = "ExecuteList",
    Position = UDim2.fromOffset(12, 76),
    Size = UDim2.new(1, -24, 1, -132),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    CanvasSize = UDim2.fromOffset(0, 0),
}, executePage)
local executeLayout = make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, executeList)
executeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    executeList.CanvasSize = UDim2.fromOffset(0, executeLayout.AbsoluteContentSize.Y + 8)
end)

local function executeProjectFile(project, file, openOutput)
    if not project or not file then return false end
    local source = file.code or ""
    if trim(source) == "" then
        logConsole("Warning", project.name .. "/" .. file.path .. " is empty.")
        if openOutput then openConsole() end
        return false
    end
    if type(loadstring) ~= "function" then
        logConsole("Error", "loadstring is unavailable; this environment cannot execute saved files.")
        if openOutput then openConsole() end
        return false
    end

    local compileOk, chunk, compileError = pcall(loadstring, source, "@" .. project.name .. "/" .. file.path)
    if not compileOk or type(chunk) ~= "function" then
        local message = tostring(compileOk and compileError or chunk)
        logConsole("Error", project.name .. "/" .. file.path .. ": " .. message, getLineNumber(message))
        if openOutput then openConsole() end
        return false
    end

    logConsole("Info", "Starting " .. project.name .. "/" .. file.path)
    task.spawn(function()
        local runtimeOk, runtimeError = pcall(chunk)
        if runtimeOk then
            logConsole("Success", "Finished " .. project.name .. "/" .. file.path)
        else
            local message = tostring(runtimeError)
            logConsole("Error", project.name .. "/" .. file.path .. ": " .. message, getLineNumber(message))
        end
    end)
    if openOutput then openConsole() end
    return true
end

renderExecutePage = function()
    for _, child in ipairs(executeList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local order = 0
    for _, project in ipairs(projects) do
        ensureProjectStructure(project)
        for _, file in ipairs(project.files) do
            order = order + 1
            local row = make("Frame", {
                Name = "ExecuteFileRow",
                Size = UDim2.new(1, -8, 0, 70),
                BackgroundColor3 = COLORS.Panel,
                BorderSizePixel = 0,
                LayoutOrder = order,
            }, executeList)
            addCorner(row, 8)
            addStroke(row, COLORS.Border, 0.5)
            local fileLabel = createLabel(row, project.name .. " / " .. file.path, UDim2.new(1, -210, 0, 24), UDim2.fromOffset(11, 7), 10, COLORS.Text, Enum.Font.GothamMedium)
            fileLabel.TextTruncate = Enum.TextTruncate.AtEnd
            createLabel(row, formatBytes(#(file.code or "")), UDim2.fromOffset(100, 18), UDim2.fromOffset(11, 34), 9, COLORS.Muted)

            local runButton = createButton(row, "Run", UDim2.fromOffset(58, 28), UDim2.new(1, -194, 0, 10), function()
                executeProjectFile(project, file, true)
            end, COLORS.Accent)
            runButton.TextSize = 10

            local autoButton = createButton(row, file.autoExecute and "Auto: ON" or "Auto: OFF", UDim2.fromOffset(92, 28), UDim2.new(1, -128, 0, 10), function()
                file.autoExecute = not file.autoExecute
                local saved, message = saveData()
                renderExecutePage()
                logConsole(saved and "Success" or "Warning", saved and (file.path .. " Auto Execute: " .. (file.autoExecute and "ON" or "OFF")) or message)
            end, file.autoExecute and COLORS.Green or COLORS.Panel2)
            autoButton.TextSize = 9
        end
    end

    if order == 0 then
        local empty = make("Frame", {
            Size = UDim2.new(1, -8, 0, 90),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, executeList)
        addCorner(empty, 8)
        createLabel(empty, "No project files", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(12, 14), 13, COLORS.Text, Enum.Font.GothamBold)
        createLabel(empty, "Create a project and add a Luau file first.", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 44), 10, COLORS.Muted)
    end
end

local runAutoFilesButton = createButton(executePage, "Run Auto Execute Files", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -48), function()
    local count = 0
    for _, project in ipairs(projects) do
        ensureProjectStructure(project)
        for _, file in ipairs(project.files) do
            if file.autoExecute then
                count = count + 1
                executeProjectFile(project, file, false)
            end
        end
    end
    if count == 0 then
        logConsole("Info", "No files are marked Auto Execute.")
    end
    openConsole()
end, COLORS.Accent)
runAutoFilesButton.TextSize = 11

-- Editor toolbar. These buttons only exist while a project is open.
local editorToolbar = make("Frame", {
    Size = UDim2.new(1, -20, 0, 42),
    Position = UDim2.fromOffset(10, 7),
    BackgroundTransparency = 1,
}, editorPage)

local toolbarBackWidth = compact and 34 or 38
local toolbarToolsWidth = compact and 62 or 82
local toolbarRunWidth = compact and 76 or 112
local toolbarSaveWidth = compact and 54 or 66
local toolbarConsoleWidth = compact and 70 or 82
local gap = compact and 4 or 7
local xBack = 0
local xTools = xBack + toolbarBackWidth + gap
local xRun = xTools + toolbarToolsWidth + gap
local xSave = xRun + toolbarRunWidth + gap
local xConsole = xSave + toolbarSaveWidth + gap

createButton(editorToolbar, "←", UDim2.fromOffset(toolbarBackWidth, 32), UDim2.fromOffset(xBack, 4), function()
    if currentProject then
        syncEditorToFile(currentProject, editorBox.Text)
        saveData()
    end
    if toolsPanel then toolsPanel.Visible = false end
    editorPage.Visible = false
    projectsPage.Visible = true
    headerSubtitle.Text = "HOME"
    renderProjects()
end, COLORS.Panel2).TextSize = 18

local toolsButton = createButton(editorToolbar, "Tools ▾", UDim2.fromOffset(toolbarToolsWidth, 32), UDim2.fromOffset(xTools, 4), function()
    if toolsPanel then
        toolsPanel.Visible = not toolsPanel.Visible
    end
end)
toolsButton.TextSize = compact and 10 or 12

local runCheckButton = createButton(editorToolbar, compact and "Check" or "Run Script", UDim2.fromOffset(toolbarRunWidth, 32), UDim2.fromOffset(xRun, 4), function()
    if not currentProject then return end
    syncEditorToFile(currentProject, editorBox.Text)
    local activePath = currentProject.activeFile or "main.lua"
    local ok, message, line = validateCode(editorBox.Text)
    if ok then
        logConsole("Success", activePath .. ": " .. message)
        editorStatus.Text = "Syntax check passed · code not executed"
        editorStatus.TextColor3 = COLORS.Green
    else
        logConsole("Error", activePath .. ": " .. message, line)
        editorStatus.Text = line and ("Syntax error on line " .. tostring(line)) or "Syntax check failed"
        editorStatus.TextColor3 = COLORS.Red
    end
    openConsole()
end, COLORS.Panel2)
runCheckButton.TextSize = compact and 10 or 12

createButton(editorToolbar, "Save", UDim2.fromOffset(toolbarSaveWidth, 32), UDim2.fromOffset(xSave, 4), function()
    if not currentProject then return end
    syncEditorToFile(currentProject, editorBox.Text)
    local saved, message = saveData()
    if saved then
        editorStatus.Text = "Saved · " .. getProjectSize(currentProject)
        editorStatus.TextColor3 = COLORS.Green
        logConsole("Success", "Saved " .. currentProject.name .. "/" .. currentProject.activeFile)
    else
        editorStatus.Text = "Session copy updated"
        editorStatus.TextColor3 = COLORS.Yellow
        logConsole("Warning", message)
    end
end, COLORS.Panel2).TextSize = compact and 10 or 12

createButton(editorToolbar, "Console", UDim2.fromOffset(toolbarConsoleWidth, 32), UDim2.fromOffset(xConsole, 4), openConsole, COLORS.Panel2).TextSize = compact and 10 or 12

local editorSurface = make("Frame", {
    Position = UDim2.fromOffset(10, 56),
    Size = UDim2.new(1, -20, 1, -91),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
}, editorPage)
addCorner(editorSurface, 8)
addStroke(editorSurface, COLORS.Border, 0.5)

local treePanelWidth = compact and 106 or 164
local treePanel = make("Frame", {
    Name = "ProjectFileTree",
    Position = UDim2.fromOffset(7, 7),
    Size = UDim2.new(0, treePanelWidth, 1, -14),
    BackgroundColor3 = COLORS.Panel2,
    BorderSizePixel = 0,
}, editorSurface)
addCorner(treePanel, 7)
createLabel(treePanel, "FILES", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(6, 4), 9, COLORS.Muted, Enum.Font.GothamBold)

local newFileButton = createButton(treePanel, "+ File", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 27), nil, COLORS.PanelHover)
newFileButton.TextSize = 9
local newFolderButton = createButton(treePanel, "+ Folder", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 54), nil, COLORS.PanelHover)
newFolderButton.TextSize = 9
local deleteTreeButton = createButton(treePanel, "Delete", UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 81), nil, Color3.fromRGB(105, 47, 57))
deleteTreeButton.TextSize = 9

local treeList = make("ScrollingFrame", {
    Name = "FileTreeList",
    Position = UDim2.fromOffset(4, 111),
    Size = UDim2.new(1, -8, 1, -115),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.fromOffset(0, 0),
}, treePanel)
local fileTreeLayout = make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, treeList)
fileTreeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    treeList.CanvasSize = UDim2.fromOffset(0, fileTreeLayout.AbsoluteContentSize.Y + 6)
end)

local codePanel = make("Frame", {
    Name = "CodePanel",
    Position = UDim2.fromOffset(treePanelWidth + 14, 0),
    Size = UDim2.new(1, -(treePanelWidth + 21), 1, 0),
    BackgroundTransparency = 1,
}, editorSurface)
editorFileLabel = createLabel(codePanel, "main.lua", UDim2.new(1, -48, 0, 25), UDim2.fromOffset(3, 5), 10, COLORS.Muted, Enum.Font.GothamBold)
local newlineButton = createButton(codePanel, "↵", UDim2.fromOffset(34, 24), UDim2.new(1, -37, 0, 5), nil, COLORS.Panel2)
newlineButton.TextSize = 15

editorBox = make("TextBox", {
    Name = "CodeEditor",
    Position = UDim2.fromOffset(3, 32),
    Size = UDim2.new(1, -6, 1, -38),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "-- Start writing Luau code here...",
    PlaceholderColor3 = COLORS.Muted,
    TextColor3 = COLORS.Text,
    TextSize = compact and 11 or 13,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = false,
    MultiLine = true,
    ClearTextOnFocus = false,
}, codePanel)

editorStatus = createLabel(editorPage, "Ready", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 1, -27), 10, COLORS.Muted)

-- Remember caret before the mobile keyboard dismisses the TextBox.
local lastEditorCursor = 1
local lastEditorSelection = 1
local function rememberCaret()
    if editorBox.CursorPosition and editorBox.CursorPosition >= 1 then
        lastEditorCursor = editorBox.CursorPosition
    end
    if editorBox.SelectionStart and editorBox.SelectionStart >= 1 then
        lastEditorSelection = editorBox.SelectionStart
    end
end
editorBox:GetPropertyChangedSignal("CursorPosition"):Connect(rememberCaret)
editorBox:GetPropertyChangedSignal("SelectionStart"):Connect(rememberCaret)
editorBox.Focused:Connect(rememberCaret)

local function insertEditorNewline()
    local source = editorBox.Text or ""
    local cursor = editorBox.CursorPosition
    local selection = editorBox.SelectionStart
    if not cursor or cursor < 1 then cursor = lastEditorCursor end
    if not selection or selection < 1 then selection = lastEditorSelection end
    if not cursor or cursor < 1 then cursor = #source + 1 end
    if not selection or selection < 1 then selection = cursor end

    local first = math.clamp(math.min(cursor, selection), 1, #source + 1)
    local last = math.clamp(math.max(cursor, selection), 1, #source + 1)
    local updated = string.sub(source, 1, first - 1) .. "\n" .. string.sub(source, last)
    editorBox.Text = updated
    local newPosition = first + 1
    lastEditorCursor = newPosition
    lastEditorSelection = newPosition
    editorBox.CursorPosition = newPosition
    editorBox.SelectionStart = newPosition
    task.defer(function()
        if editorBox and editorBox.Parent and editorPage.Visible then
            editorBox:CaptureFocus()
        end
    end)
end

newlineButton.Activated:Connect(function()
    rememberCaret()
    insertEditorNewline()
end)

if touchDevice then
    local ok, signal = pcall(function()
        return editorBox.ReturnPressedFromOnScreenKeyboard
    end)
    if ok and signal then
        signal:Connect(function()
            task.defer(function()
                if editorBox and editorBox.Parent and editorPage.Visible then
                    editorBox:CaptureFocus()
                end
            end)
        end)
    end
end

-- File tree. Folder entries are generated from both explicit folders and file paths.

local function buildTreeMap(project)
    ensureProjectStructure(project)
    local folders = { [""] = true }
    local files = {}
    for _, folder in ipairs(project.folders) do
        local clean = normalizePath(folder)
        if clean then
            folders[clean] = true
            local parent = parentPath(clean)
            while parent ~= "" do
                folders[parent] = true
                parent = parentPath(parent)
            end
        end
    end
    for _, file in ipairs(project.files) do
        files[file.path] = file
        local parent = parentPath(file.path)
        while parent ~= "" do
            folders[parent] = true
            parent = parentPath(parent)
        end
    end

    local children = {}
    local function addChild(parent, entry)
        children[parent] = children[parent] or {}
        table.insert(children[parent], entry)
    end
    for folder in pairs(folders) do
        if folder ~= "" then
            addChild(parentPath(folder), {path = folder, name = leafName(folder), isFolder = true})
        end
    end
    for path, file in pairs(files) do
        addChild(parentPath(path), {path = path, name = leafName(path), isFolder = false, file = file})
    end
    for _, entries in pairs(children) do
        table.sort(entries, function(a, b)
            if a.isFolder ~= b.isFolder then return a.isFolder end
            return a.name:lower() < b.name:lower()
        end)
    end
    return children
end

renderFileTree = function()
    if not currentProject then return end
    for _, child in ipairs(treeList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    local children = buildTreeMap(currentProject)
    local order = 0
    local function addRows(parent, depth)
        for _, entry in ipairs(children[parent] or {}) do
            order = order + 1
            local selected = selectedTreePath == entry.path and selectedTreeIsFolder == entry.isFolder
            local prefix = entry.isFolder and (expandedFolders[entry.path] == false and "▸ " or "▾ ") or "  "
            local rowText = string.rep("  ", math.min(depth, 5)) .. prefix .. entry.name
            local row = make("TextButton", {
                Name = entry.isFolder and "FolderRow" or "FileRow",
                Size = UDim2.new(1, -3, 0, 24),
                BackgroundColor3 = selected and COLORS.PanelHover or COLORS.Panel2,
                BorderSizePixel = 0,
                Text = rowText,
                TextColor3 = selected and COLORS.Accent or COLORS.Text,
                TextSize = 9,
                Font = entry.isFolder and Enum.Font.GothamBold or Enum.Font.Code,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = true,
                LayoutOrder = order,
            }, treeList)
            addCorner(row, 4)
            row.Activated:Connect(function()
                selectedTreePath = entry.path
                selectedTreeIsFolder = entry.isFolder
                if entry.isFolder then
                    expandedFolders[entry.path] = expandedFolders[entry.path] == false
                else
                    syncEditorToFile(currentProject, editorBox.Text)
                    currentProject.activeFile = entry.path
                    editorBox.Text = entry.file.code or ""
                    editorFileLabel.Text = entry.path
                    currentProject.updated = os.time()
                    saveData()
                end
                renderFileTree()
            end)
            if entry.isFolder and expandedFolders[entry.path] ~= false then
                addRows(entry.path, depth + 1)
            end
        end
    end
    addRows("", 0)
end

local function showPathPopup(title, initialText, confirmText, onConfirm)
    showTextPopup(title, initialText or "", confirmText or "Create", function(value)
        return onConfirm(value)
    end)
end

newFileButton.Activated:Connect(function()
    if not currentProject then return end
    local initial = selectedTreeIsFolder and (selectedTreePath .. "/new.lua") or "new.lua"
    showPathPopup("Add file", initial, "Create", function(value)
        local path = normalizePath(value)
        if not path then return false, "Invalid file path." end
        if not path:match("%.[%w_%-]+$") then path = path .. ".lua" end
        if getProjectFile(currentProject, path) then return false, "A file with this path already exists." end
        syncEditorToFile(currentProject, editorBox.Text)
        table.insert(currentProject.files, {path = path, code = "", autoExecute = false})
        currentProject.activeFile = path
        editorBox.Text = ""
        editorFileLabel.Text = path
        selectedTreePath = path
        selectedTreeIsFolder = false
        saveData()
        renderFileTree()
        if renderProjects then renderProjects() end
        return true
    end)
end)

newFolderButton.Activated:Connect(function()
    if not currentProject then return end
    local initial = selectedTreeIsFolder and (selectedTreePath .. "/NewFolder") or "NewFolder"
    showPathPopup("Add folder", initial, "Create", function(value)
        local path = normalizePath(value)
        if not path then return false, "Invalid folder path." end
        for _, folder in ipairs(currentProject.folders) do
            if folder == path then return false, "This folder already exists." end
        end
        table.insert(currentProject.folders, path)
        selectedTreePath = path
        selectedTreeIsFolder = true
        expandedFolders[path] = true
        saveData()
        renderFileTree()
        return true
    end)
end)

deleteTreeButton.Activated:Connect(function()
    if not currentProject then return end
    syncEditorToFile(currentProject, editorBox.Text)
    local target = selectedTreePath
    if selectedTreeIsFolder then
        local prefix = target .. "/"
        for index = #currentProject.files, 1, -1 do
            local path = currentProject.files[index].path
            if path == target or string.sub(path, 1, #prefix) == prefix then
                table.remove(currentProject.files, index)
            end
        end
        for index = #currentProject.folders, 1, -1 do
            local folder = currentProject.folders[index]
            if folder == target or string.sub(folder, 1, #prefix) == prefix then
                table.remove(currentProject.folders, index)
            end
        end
        logConsole("Info", "Deleted folder: " .. target)
    else
        if #currentProject.files <= 1 then
            logConsole("Warning", "A project must contain at least one file.")
            openConsole()
            return
        end
        for index, file in ipairs(currentProject.files) do
            if file.path == target then
                table.remove(currentProject.files, index)
                break
            end
        end
        logConsole("Info", "Deleted file: " .. target)
    end

    if #currentProject.files == 0 then
        table.insert(currentProject.files, {path = "main.lua", code = "", autoExecute = false})
        currentProject.folders = {}
    end
    currentProject.activeFile = currentProject.files[1].path
    editorBox.Text = currentProject.files[1].code or ""
    editorFileLabel.Text = currentProject.activeFile
    selectedTreePath = currentProject.activeFile
    selectedTreeIsFolder = false
    saveData()
    renderFileTree()
    if renderProjects then renderProjects() end
end)

-- Tools menu: only the three tools requested (Dex, RemoteSpy, FreeCam).
toolsPanel = make("Frame", {
    Name = "ToolsPanel",
    Size = UDim2.fromOffset(compact and 190 or 220, 152),
    Position = UDim2.fromOffset(48, 48),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
}, editorPage)
addCorner(toolsPanel, 9)
addStroke(toolsPanel, COLORS.Border)
createLabel(toolsPanel, "Tools", UDim2.new(1, -18, 0, 24), UDim2.fromOffset(10, 4), 13, COLORS.Text, Enum.Font.GothamBold).ZIndex = 21

local toolDexButton = createButton(toolsPanel, "Dex Explorer", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 32), nil, COLORS.Panel2)
toolDexButton.ZIndex = 21
local toolRemoteButton = createButton(toolsPanel, "RemoteSpy", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 67), nil, COLORS.Panel2)
toolRemoteButton.ZIndex = 21
local toolFreeCamButton = createButton(toolsPanel, "FreeCam", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 102), nil, COLORS.Panel2)
toolFreeCamButton.ZIndex = 21

local function raiseZIndex(root, value)
    if root:IsA("GuiObject") then root.ZIndex = value end
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("GuiObject") then raiseZIndex(child, value + 1) end
    end
end

local function makeToolWindow(name, titleText, width, height, onClose)
    local frame = make("Frame", {
        Name = name,
        Size = UDim2.fromOffset(width, height),
        Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 50,
    }, screenGui)
    addCorner(frame, 10)
    addStroke(frame, COLORS.Border)
    local bar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 51,
    }, frame)
    addCorner(bar, 10)
    local title = createLabel(bar, "  " .. titleText, UDim2.new(1, -48, 1, 0), UDim2.fromOffset(6, 0), 13, COLORS.Text, Enum.Font.GothamBold)
    title.ZIndex = 52
    local close = createButton(bar, "×", UDim2.fromOffset(28, 26), UDim2.new(1, -34, 0, 6), onClose)
    close.TextSize = 18
    close.ZIndex = 52
    local content = make("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(8, 44),
        Size = UDim2.new(1, -16, 1, -52),
        BackgroundTransparency = 1,
        ZIndex = 51,
    }, frame)
    makeDraggable(bar, frame)
    return frame, content
end

local function objectPath(object)
    local names = {}
    local current = object
    while current and current ~= game do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return "game." .. table.concat(names, ".")
end

-- Dex reads only the explicitly designated folder in the user's own test place.
local dexWindow = nil
local function openDex()
    if dexWindow then
        dexWindow.Visible = true
        return
    end

    local width = math.max(280, math.min(520, windowWidth - 30))
    local height = math.max(230, math.min(390, windowHeight - 80))
    local selectedObject = nil
    local expanded = {}
    local treeList
    local detailLabel
    local renderDexTree

    dexWindow = nil
    local frame, content = makeToolWindow("DexExplorerWindow", "Dex Explorer · test folder", width, height, function()
        frame.Visible = false
    end)
    dexWindow = frame

    local refreshButton = createButton(content, "Refresh", UDim2.fromOffset(72, 26), UDim2.new(1, -72, 0, 0), function()
        renderDexTree()
    end)
    refreshButton.ZIndex = 53

    treeList = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 32),
        Size = UDim2.new(0.56, -5, 1, -32),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 52,
    }, content)
    addCorner(treeList, 7)
    local treeLayout = make("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, treeList)
    treeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        treeList.CanvasSize = UDim2.fromOffset(0, treeLayout.AbsoluteContentSize.Y + 6)
    end)

    local detailPanel = make("Frame", {
        Position = UDim2.new(0.56, 5, 0, 32),
        Size = UDim2.new(0.44, -5, 1, -32),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 52,
    }, content)
    addCorner(detailPanel, 7)
    detailLabel = createLabel(detailPanel, "Select an object.", UDim2.new(1, -14, 1, -14), UDim2.fromOffset(7, 7), 10, COLORS.Text, Enum.Font.Code)
    detailLabel.TextWrapped = true
    detailLabel.TextYAlignment = Enum.TextYAlignment.Top
    detailLabel.ZIndex = 53

    local function updateDetails(object)
        if not object then
            detailLabel.Text = "Create this folder in your own test place:\n\nWorkspace\n└─ EasyScriptingTestObjects\n\nPlace Parts and Models inside it, then press Refresh."
            return
        end
        local lines = {
            "Name: " .. object.Name,
            "Class: " .. object.ClassName,
            "Parent: " .. (object.Parent and object.Parent.Name or "nil"),
            "Path: " .. objectPath(object),
            "Children: " .. tostring(#object:GetChildren()),
        }
        if object:IsA("BasePart") then
            local position = object.Position
            local size = object.Size
            table.insert(lines, string.format("Position: %.2f, %.2f, %.2f", position.X, position.Y, position.Z))
            table.insert(lines, string.format("Size: %.2f, %.2f, %.2f", size.X, size.Y, size.Z))
        elseif object:IsA("ValueBase") then
            table.insert(lines, "Value: " .. tostring(object.Value))
        end
        detailLabel.Text = table.concat(lines, "\n\n")
    end

    renderDexTree = function()
        for _, child in ipairs(treeList:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        local root = workspace:FindFirstChild("EasyScriptingTestObjects")
        if not root then
            selectedObject = nil
            updateDetails(nil)
            local note = createLabel(treeList, "Test folder not found", UDim2.new(1, -12, 0, 40), UDim2.fromOffset(6, 5), 10, COLORS.Yellow)
            note.ZIndex = 54
            return
        end
        if not selectedObject or not selectedObject:IsDescendantOf(root) then
            selectedObject = root
        end
        local order = 0
        local function addNode(object, depth)
            order = order + 1
            local children = object:GetChildren()
            table.sort(children, function(a, b)
                if a.ClassName == b.ClassName then return a.Name:lower() < b.Name:lower() end
                return a.ClassName < b.ClassName
            end)
            local isExpanded = expanded[object] ~= false
            local prefix = #children > 0 and (isExpanded and "▾ " or "▸ ") or "• "
            local row = make("TextButton", {
                Size = UDim2.new(1, -5, 0, 24),
                BackgroundColor3 = selectedObject == object and COLORS.PanelHover or COLORS.Panel2,
                BorderSizePixel = 0,
                Text = string.rep("  ", math.min(depth, 5)) .. prefix .. object.Name .. " [" .. object.ClassName .. "]",
                TextColor3 = COLORS.Text,
                TextSize = 9,
                Font = Enum.Font.Code,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = order,
                AutoButtonColor = true,
                ZIndex = 54,
            }, treeList)
            addCorner(row, 4)
            row.Activated:Connect(function()
                selectedObject = object
                if #children > 0 then expanded[object] = not isExpanded end
                updateDetails(object)
                renderDexTree()
            end)
            if isExpanded then
                for _, child in ipairs(children) do
                    addNode(child, depth + 1)
                end
            end
        end
        expanded[root] = expanded[root] ~= false
        addNode(root, 0)
        updateDetails(selectedObject)
    end

    renderDexTree()
    raiseZIndex(dexWindow, 50)
end

-- RemoteSpy listens only to incoming RemoteEvents in the designated test folder.
local remoteSpyWindow = nil
local function openRemoteSpy()
    if remoteSpyWindow then
        remoteSpyWindow.Visible = true
        return
    end

    local width = math.max(280, math.min(520, windowWidth - 30))
    local height = math.max(230, math.min(390, windowHeight - 80))
    local frame, content
    local entries = {}
    local eventConnections = {}
    local folderConnection = nil
    local active = false
    local list
    local status
    local renderEntries
    local stopConnections
    frame, content = makeToolWindow("RemoteSpyWindow", "RemoteSpy · own test remotes", width, height, function()
        frame.Visible = false
        if stopConnections then
            stopConnections()
        end
        if status then status.Text = "Stopped" end
    end)
    remoteSpyWindow = frame

    status = createLabel(content, "Stopped · ReplicatedStorage/EasyScriptingRemotes", UDim2.new(1, -150, 0, 24), UDim2.fromOffset(0, 0), 9, COLORS.Muted)
    status.ZIndex = 53
    local startButton = createButton(content, "Start", UDim2.fromOffset(64, 26), UDim2.new(1, -136, 0, 0), nil, COLORS.Green)
    startButton.ZIndex = 53
    local clearButton = createButton(content, "Clear", UDim2.fromOffset(60, 26), UDim2.new(1, -66, 0, 0), function()
        entries = {}
        renderEntries()
    end)
    clearButton.ZIndex = 53

    local help = createLabel(content,
        "Incoming messages only. Add test RemoteEvents to ReplicatedStorage/EasyScriptingRemotes in your own place.",
        UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 30), 9, COLORS.Muted)
    help.TextWrapped = true
    help.ZIndex = 53

    list = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 68),
        Size = UDim2.new(1, 0, 1, -68),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 52,
    }, content)
    addCorner(list, 7)
    local listLayout = make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 6)
    end)

    renderEntries = function()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        for index, entry in ipairs(entries) do
            local text = string.format("[%s] %s\n%s", entry.time, entry.name, entry.args)
            local row = createLabel(list, text, UDim2.new(1, -8, 0, 48), UDim2.new(), 9, COLORS.Text, Enum.Font.Code)
            row.BackgroundColor3 = COLORS.Panel2
            row.BackgroundTransparency = 0
            row.TextWrapped = true
            row.TextYAlignment = Enum.TextYAlignment.Center
            row.LayoutOrder = index
            row.ZIndex = 54
            addCorner(row, 5)
        end
    end

    local function formatArgument(value)
        local valueType = typeof(value)
        if valueType == "Instance" then
            return objectPath(value)
        elseif valueType == "string" then
            return string.format("%q", string.sub(value, 1, 100))
        end
        return tostring(value)
    end

    local function formatArgument(value)
        local valueType = typeof(value)
        if valueType == "Instance" then
            return objectPath(value)
        elseif valueType == "string" then
            return string.format("%q", string.sub(value, 1, 100))
        end
        return tostring(value)
    end

    local attachRemote
    stopConnections = function()
        active = false
        for _, item in ipairs(eventConnections) do
            pcall(function() item.connection:Disconnect() end)
        end
        eventConnections = {}
        if folderConnection then
            pcall(function() folderConnection:Disconnect() end)
            folderConnection = nil
        end
        if startButton and startButton.Parent then startButton.Text = "Start" end
    end

    attachRemote = function(remote)
        if not active or not remote:IsA("RemoteEvent") then return end
        for _, item in ipairs(eventConnections) do
            if item.remote == remote then return end
        end
        local connection = remote.OnClientEvent:Connect(function(...)
            if not active then return end
            local arguments = table.pack(...)
            local parts = {}
            for i = 1, math.min(arguments.n, 8) do
                table.insert(parts, formatArgument(arguments[i]))
            end
            if arguments.n > 8 then table.insert(parts, "...") end
            table.insert(entries, {
                time = os.date("%H:%M:%S"),
                name = remote.Name,
                args = #parts > 0 and table.concat(parts, " | ") or "(no arguments)",
            })
            while #entries > 100 do table.remove(entries, 1) end
            renderEntries()
        end)
        table.insert(eventConnections, {connection = connection, remote = remote})
    end

    local function startMonitoring()
        stopConnections()
        local root = ReplicatedStorage:FindFirstChild("EasyScriptingRemotes")
        if not root then
            status.Text = "Folder missing · create EasyScriptingRemotes in ReplicatedStorage"
            logConsole("Warning", "RemoteSpy needs ReplicatedStorage.EasyScriptingRemotes in your own test place.")
            return
        end
        active = true
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("RemoteEvent") then
                attachRemote(descendant)
            end
        end
        folderConnection = root.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("RemoteEvent") then attachRemote(descendant) end
        end)
        status.Text = "Listening · " .. tostring(#eventConnections) .. " RemoteEvent(s)"
        startButton.Text = "Stop"
    end

    startButton.Activated:Connect(function()
        if active then
            stopConnections()
            status.Text = "Stopped"
            startButton.Text = "Start"
        else
            startMonitoring()
        end
    end)
    renderEntries()
    raiseZIndex(remoteSpyWindow, 50)
end

-- FreeCam only moves CurrentCamera. The local character is never repositioned.
local freeCamWindow = nil
local freeCamStatus = nil
local freeCamToggle = nil
local freeCam = {
    enabled = false,
    speed = 32,
    keys = {},
    mouseLook = false,
    yaw = 0,
    pitch = 0,
    renderConnection = nil,
    beganConnection = nil,
    endedConnection = nil,
    changedConnection = nil,
    controls = nil,
    oldCameraType = nil,
    oldCameraSubject = nil,
    oldMouseBehavior = nil,
    oldMouseIconEnabled = nil,
}

local function getPlayerControls()
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local moduleScript = scripts and scripts:FindFirstChild("PlayerModule")
    if not moduleScript then return nil end
    local ok, module = pcall(require, moduleScript)
    if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then return nil end
    local controlOk, controls = pcall(function() return module:GetControls() end)
    return controlOk and controls or nil
end

stopFreeCam = function()
    if not freeCam.enabled then return end
    freeCam.enabled = false
    freeCam.keys = {}
    freeCam.mouseLook = false
    for _, key in ipairs({"renderConnection", "beganConnection", "endedConnection", "changedConnection"}) do
        local connection = freeCam[key]
        if connection then pcall(function() connection:Disconnect() end); freeCam[key] = nil end
    end
    if freeCam.controls then
        pcall(function() freeCam.controls:Enable() end)
        freeCam.controls = nil
    end
    local camera = workspace.CurrentCamera
    if camera then
        pcall(function()
            camera.CameraType = freeCam.oldCameraType or Enum.CameraType.Custom
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if freeCam.oldCameraSubject and freeCam.oldCameraSubject.Parent then
                camera.CameraSubject = freeCam.oldCameraSubject
            else
                camera.CameraSubject = humanoid
            end
        end)
    end
    pcall(function()
        UserInputService.MouseBehavior = freeCam.oldMouseBehavior or Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = freeCam.oldMouseIconEnabled ~= false
    end)
    if freeCamStatus then freeCamStatus.Text = "FreeCam OFF · character remains in place" end
    if freeCamToggle then freeCamToggle.Text = "Start FreeCam" end
end

local function startFreeCam()
    if freeCam.enabled then return end
    local camera = workspace.CurrentCamera
    if not camera then
        logConsole("Error", "CurrentCamera is unavailable.")
        return
    end

    freeCam.oldCameraType = camera.CameraType
    freeCam.oldCameraSubject = camera.CameraSubject
    freeCam.oldMouseBehavior = UserInputService.MouseBehavior
    freeCam.oldMouseIconEnabled = UserInputService.MouseIconEnabled
    freeCam.controls = getPlayerControls()
    if freeCam.controls then
        pcall(function() freeCam.controls:Disable() end)
    else
        logConsole("Warning", "Could not access PlayerModule controls. FreeCam moves only the camera; check character input separately in your test place.")
    end

    local look = camera.CFrame.LookVector
    freeCam.yaw = math.atan2(-look.X, -look.Z)
    freeCam.pitch = math.asin(math.clamp(look.Y, -1, 1))
    freeCam.keys = {}
    freeCam.enabled = true
    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true

    freeCam.beganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freeCam.mouseLook = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            UserInputService.MouseIconEnabled = false
            return
        end
        if gameProcessed or UserInputService:GetFocusedTextBox() then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S
            or key == Enum.KeyCode.D or key == Enum.KeyCode.Q or key == Enum.KeyCode.E
            or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
            freeCam.keys[key] = true
        end
    end)

    freeCam.endedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freeCam.mouseLook = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
        freeCam.keys[input.KeyCode] = nil
    end)

    freeCam.changedConnection = UserInputService.InputChanged:Connect(function(input)
        if freeCam.enabled and freeCam.mouseLook and input.UserInputType == Enum.UserInputType.MouseMovement then
            local sensitivity = 0.0025
            freeCam.yaw = freeCam.yaw - input.Delta.X * sensitivity
            freeCam.pitch = math.clamp(freeCam.pitch - input.Delta.Y * sensitivity, math.rad(-85), math.rad(85))
        end
    end)

    freeCam.renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not freeCam.enabled then return end
        local activeCamera = workspace.CurrentCamera
        if not activeCamera then return end
        local x = (freeCam.keys[Enum.KeyCode.D] and 1 or 0) - (freeCam.keys[Enum.KeyCode.A] and 1 or 0)
        local y = (freeCam.keys[Enum.KeyCode.E] and 1 or 0) - (freeCam.keys[Enum.KeyCode.Q] and 1 or 0)
        local z = (freeCam.keys[Enum.KeyCode.W] and 1 or 0) - (freeCam.keys[Enum.KeyCode.S] and 1 or 0)
        local rotation = CFrame.fromOrientation(freeCam.pitch, freeCam.yaw, 0)
        local direction = rotation:VectorToWorldSpace(Vector3.new(x, y, -z))
        local position = activeCamera.CFrame.Position
        if direction.Magnitude > 0 then
            local speed = freeCam.speed
            if freeCam.keys[Enum.KeyCode.LeftShift] or freeCam.keys[Enum.KeyCode.RightShift] then
                speed = speed * 2.5
            end
            position = position + direction.Unit * speed * deltaTime
        end
        activeCamera.CFrame = CFrame.new(position) * rotation
    end)

    if freeCamStatus then freeCamStatus.Text = "ON · WASD move · Q/E down/up · hold RMB to look · Shift faster" end
    if freeCamToggle then freeCamToggle.Text = "Stop FreeCam" end
end

local function openFreeCam()
    if freeCamWindow then
        freeCamWindow.Visible = true
        return
    end
    local width = math.max(285, math.min(410, windowWidth - 30))
    local height = compact and 250 or 210
    local frame, content
    frame, content = makeToolWindow("FreeCamWindow", "FreeCam · camera only", width, height, function()
        stopFreeCam()
        frame.Visible = false
    end)
    freeCamWindow = frame
    freeCamStatus = createLabel(content, "FreeCam OFF · character remains in place", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 0), 10, COLORS.Muted)
    freeCamStatus.TextWrapped = true
    freeCamStatus.ZIndex = 53

    createLabel(content, "Speed", UDim2.fromOffset(50, 25), UDim2.fromOffset(0, 42), 10, COLORS.Text).ZIndex = 53
    local speedBox = make("TextBox", {
        Size = UDim2.fromOffset(70, 27),
        Position = UDim2.fromOffset(54, 41),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        Text = tostring(freeCam.speed),
        TextColor3 = COLORS.Text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        ZIndex = 53,
    }, content)
    addCorner(speedBox, 6)
    speedBox.FocusLost:Connect(function()
        local value = tonumber(speedBox.Text)
        if value then freeCam.speed = math.clamp(value, 4, 200) end
        speedBox.Text = tostring(freeCam.speed)
    end)

    if touchDevice then
        createLabel(content, "Hold a direction button to move the camera", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 74), 9, COLORS.Muted).ZIndex = 53
        local function holdButton(text, keyCode, x, y)
            local button = make("TextButton", {
                Size = UDim2.fromOffset(42, 25),
                Position = UDim2.fromOffset(x, y),
                BackgroundColor3 = COLORS.Panel2,
                BorderSizePixel = 0,
                Text = text,
                TextColor3 = COLORS.Text,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                ZIndex = 54,
            }, content)
            addCorner(button, 6)
            button.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    freeCam.keys[keyCode] = true
                end
            end)
            button.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    freeCam.keys[keyCode] = nil
                end
            end)
        end
        holdButton("W", Enum.KeyCode.W, 48, 96)
        holdButton("A", Enum.KeyCode.A, 2, 124)
        holdButton("S", Enum.KeyCode.S, 48, 124)
        holdButton("D", Enum.KeyCode.D, 94, 124)
        holdButton("UP", Enum.KeyCode.E, 148, 96)
        holdButton("DOWN", Enum.KeyCode.Q, 148, 124)
        createButton(content, "↶", UDim2.fromOffset(40, 25), UDim2.fromOffset(198, 96), function()
            freeCam.yaw = freeCam.yaw + math.rad(15)
        end).ZIndex = 54
        createButton(content, "↷", UDim2.fromOffset(40, 25), UDim2.fromOffset(198, 124), function()
            freeCam.yaw = freeCam.yaw - math.rad(15)
        end).ZIndex = 54
    end

    freeCamToggle = createButton(content, "Start FreeCam", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 1, -36), function()
        if freeCam.enabled then stopFreeCam() else startFreeCam() end
    end, COLORS.Accent)
    freeCamToggle.ZIndex = 53
    raiseZIndex(freeCamWindow, 50)
end

-- Connect the Tools menu after all tool-opening functions exist.
toolDexButton.Activated:Connect(function()
    toolsPanel.Visible = false
    openDex()
end)
toolRemoteButton.Activated:Connect(function()
    toolsPanel.Visible = false
    openRemoteSpy()
end)
toolFreeCamButton.Activated:Connect(function()
    toolsPanel.Visible = false
    openFreeCam()
end)

-- Initial load and render.
loadData()
renderProjects()
renderExecutePage()

if not fileStorageAvailable then
    logConsole("Warning", "readfile/writefile are unavailable. Projects work for this session only; persistent saving requires executor file APIs.")
else
    logConsole("Info", "Project storage ready: " .. DATA_FILE)
end

-- Run Script checks syntax only; actual execution is available from the Execute page.
local startupAutoCount = 0
task.defer(function()
    task.wait(0.75)
    for _, project in ipairs(projects) do
        ensureProjectStructure(project)
        for _, file in ipairs(project.files) do
            if file.autoExecute then
                startupAutoCount = startupAutoCount + 1
                executeProjectFile(project, file, false)
            end
        end
    end
    if startupAutoCount > 0 then
        logConsole("Info", "Auto Execute started " .. tostring(startupAutoCount) .. " saved file(s).")
    end
end)

screenGui.Destroying:Connect(function()
    if stopFreeCam then
        pcall(stopFreeCam)
    end
end)

print("Easy Scripting " .. VERSION .. " loaded.")
