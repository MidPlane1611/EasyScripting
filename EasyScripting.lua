--[[
    Easy Scripting v1.4
    Built from the user's original, working v0.1 source.

    Main features:
      * Original large desktop window size (up to 860 x 620)
      * Projects: create, open, rename, delete, legacy v0.1 migration
      * File/folder tree with create, rename, and delete actions
      * Supported project files: .lua, .luau, .json, .txt, .md
      * JSON validation; Luau syntax validation and script execution
      * Execute page only lists .lua and .luau files
      * Run Script button performs syntax compilation only
      * Separate movable Console with line-aware errors
      * Tools menu: full client-visible Dex Explorer, instrumented RemoteSpy, camera-only FreeCam
      * Expanding code editor with horizontal and vertical scrolling
      * ASCII-only file/folder labels and mobile Enter button
      * Mobile touch-friendly controls
      * Executor file persistence when readfile/writefile are available

    SAFETY / SCOPE:
      * Dex displays the client-visible game hierarchy, with a read-only Properties panel and Explorer-style class/name sorting.
      * Script source viewing obeys Roblox client source-access restrictions; RegisterSource
        is available for source text supplied by your own authorized development setup.
      * RemoteSpy records instrumented outgoing calls and incoming RemoteEvents in the dedicated test folder.
      * FreeCam moves only the camera; it never moves the character's root part.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
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
local VERSION = "v1.4"

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

local SUPPORTED_FILE_TYPES = {
    lua = true,
    luau = true,
    json = true,
    txt = true,
    md = true,
}

local function getFileExtension(path)
    local name = leafName(path or "")
    local extension = name:match("%.([%w_%-]+)$")
    return extension and extension:lower() or ""
end

local function isSupportedFile(path)
    return SUPPORTED_FILE_TYPES[getFileExtension(path)] == true
end

local function isScriptFile(path)
    local extension = getFileExtension(path)
    return extension == "lua" or extension == "luau"
end

local function ensureParentFolders(project, path)
    local parent = parentPath(path)
    while parent ~= "" do
        local found = false
        for _, folder in ipairs(project.folders) do
            if folder == parent then
                found = true
                break
            end
        end
        if not found then
            table.insert(project.folders, parent)
        end
        parent = parentPath(parent)
    end
end

local function pathTaken(project, path, ignoreFilePath, ignoreFolderPath)
    for _, file in ipairs(project.files or {}) do
        if file.path == path and file.path ~= ignoreFilePath then
            return true
        end
        if file.path ~= ignoreFilePath and string.sub(path, 1, #file.path + 1) == file.path .. "/" then
            return true -- A file cannot also be used as a parent directory.
        end
        local parent = parentPath(file.path)
        while parent ~= "" do
            if parent == path and parent ~= ignoreFolderPath then
                return true
            end
            parent = parentPath(parent)
        end
    end
    for _, folder in ipairs(project.folders or {}) do
        if folder == path and folder ~= ignoreFolderPath then
            return true
        end
        if folder ~= ignoreFolderPath and string.sub(folder, 1, #path + 1) == path .. "/" then
            return true -- This folder already exists implicitly as a parent.
        end
    end
    return false
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
local closeButton = createButton(header, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -42, 0, 8), function()
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
local editorViewport = nil
local editorStatus = nil
local editorFileLabel = nil
local runCheckButton = nil
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

local function refreshEditorFileHeader(path)
    if editorFileLabel then
        editorFileLabel.Text = path or ""
    end
    if path then
        local extension = getFileExtension(path)
        if editorBox then
            if extension == "json" then
                editorBox.PlaceholderText = '{"key": "value"}'
            elseif extension == "txt" then
                editorBox.PlaceholderText = "Write text here..."
            elseif extension == "md" then
                editorBox.PlaceholderText = "# Project notes"
            else
                editorBox.PlaceholderText = "-- Start writing Luau code here..."
            end
        end
        if runCheckButton then
            if isScriptFile(path) then
                runCheckButton.Text = compact and "Check" or "Run Script"
            else
                runCheckButton.Text = compact and "Valid." or "Validate"
            end
        end
    end
end

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
                            autoExecute = file.autoExecute == true and isScriptFile(safePath),
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

local function validateProjectFile(file, source)
    if not file then
        return false, "No file is selected.", nil
    end
    local extension = getFileExtension(file.path)
    if extension == "lua" or extension == "luau" then
        return validateCode(source)
    elseif extension == "json" then
        if type(source) ~= "string" or trim(source) == "" then
            return false, "The JSON file is empty.", nil
        end
        local ok, result = pcall(function()
            return HttpService:JSONDecode(source)
        end)
        if not ok then
            return false, "Invalid JSON: " .. tostring(result), nil
        end
        return true, "Valid JSON. The file was not executed.", nil
    elseif extension == "txt" or extension == "md" then
        return true, "No syntax check is required for ." .. extension .. " files.", nil
    end
    return false, "Unsupported file type. Use .lua, .luau, .json, .txt, or .md.", nil
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
        consoleCountLabel.Text = string.format("%d errors  -  %d warnings  -  %d messages", errors, warnings, #consoleEntries)
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
    local closeConsole = createButton(consoleHeader, "X", UDim2.fromOffset(30, 26), UDim2.new(1, -36, 0, 8), function()
        consoleWindow.Visible = false
    end)
    closeConsole.TextSize = 18
    closeConsole.ZIndex = 42

    consoleCountLabel = createLabel(consoleWindow, "0 errors | 0 warnings | 0 messages", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 44), 10, COLORS.Muted)
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

createButton(mainToolbar, "Projects", UDim2.fromOffset(125, 34), UDim2.fromOffset(0, 4), showProjectsPage, COLORS.Panel2)
createButton(mainToolbar, "Execute", UDim2.fromOffset(138, 34), UDim2.new(1, -138, 0, 4), showExecutePage, COLORS.Panel2)

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
        label.Text = "Roblox project  -  " .. getProjectSize(project) .. "  -  " .. tostring(#project.files) .. " file(s)"
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
    if editorViewport then editorViewport.CanvasPosition = Vector2.new(0, 0) end
    selectedTreePath = project.activeFile or "main.lua"
    selectedTreeIsFolder = false
    refreshEditorFileHeader(project.activeFile)
    headerSubtitle.Text = project.name
    projectsPage.Visible = false
    executePage.Visible = false
    editorPage.Visible = true
    editorStatus.Text = "Project opened - " .. tostring(#project.files) .. " file(s)"
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
createButton(executePage, "Projects", UDim2.fromOffset(125, 34), UDim2.fromOffset(12, 8), showProjectsPage, COLORS.Panel2)
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
    if not isScriptFile(file.path) then
        logConsole("Warning", "Only .lua and .luau files can be executed: " .. tostring(file.path))
        if openOutput then openConsole() end
        return false
    end
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
            if isScriptFile(file.path) then
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
            else
                file.autoExecute = false
            end
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
        createLabel(empty, "No script files", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(12, 14), 13, COLORS.Text, Enum.Font.GothamBold)
        createLabel(empty, "Add a .lua or .luau file to a project to run it.", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 44), 10, COLORS.Muted)
    end
end

local runAutoFilesButton = createButton(executePage, "Run Auto Execute Files", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -48), function()
    local count = 0
    for _, project in ipairs(projects) do
        ensureProjectStructure(project)
        for _, file in ipairs(project.files) do
            if file.autoExecute and isScriptFile(file.path) then
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

createButton(editorToolbar, "Back", UDim2.fromOffset(toolbarBackWidth, 32), UDim2.fromOffset(xBack, 4), function()
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

local toolsButton = createButton(editorToolbar, "Tools", UDim2.fromOffset(toolbarToolsWidth, 32), UDim2.fromOffset(xTools, 4), function()
    if toolsPanel then
        toolsPanel.Visible = not toolsPanel.Visible
    end
end)
toolsButton.TextSize = compact and 10 or 12

runCheckButton = createButton(editorToolbar, compact and "Check" or "Run Script", UDim2.fromOffset(toolbarRunWidth, 32), UDim2.fromOffset(xRun, 4), function()
    if not currentProject then return end
    syncEditorToFile(currentProject, editorBox.Text)
    local activePath = currentProject.activeFile or "main.lua"
    local activeFile = getProjectFile(currentProject, activePath)
    local ok, message, line = validateProjectFile(activeFile, editorBox.Text)
    if ok then
        logConsole("Success", activePath .. ": " .. message)
        if isScriptFile(activePath) then
            editorStatus.Text = "Syntax check passed - code not executed"
        else
            editorStatus.Text = message
        end
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
        editorStatus.Text = "Saved - " .. getProjectSize(currentProject)
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

local actionScrollHeight = compact and 82 or 108
local fileActionsScroll = make("ScrollingFrame", {
    Name = "FileActionsScroll",
    Position = UDim2.fromOffset(4, 27),
    Size = UDim2.new(1, -8, 0, actionScrollHeight),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.fromOffset(0, 0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, treePanel)
local fileActionsLayout = make("UIListLayout", {
    Padding = UDim.new(0, 3),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, fileActionsScroll)
fileActionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    fileActionsScroll.CanvasSize = UDim2.fromOffset(0, fileActionsLayout.AbsoluteContentSize.Y + 4)
end)

local newFileButton = createButton(fileActionsScroll, "+ File", UDim2.new(1, -4, 0, 24), UDim2.new(), nil, COLORS.PanelHover)
newFileButton.TextSize = 9
newFileButton.LayoutOrder = 1
local newFolderButton = createButton(fileActionsScroll, "+ Folder", UDim2.new(1, -4, 0, 24), UDim2.new(), nil, COLORS.PanelHover)
newFolderButton.TextSize = 9
newFolderButton.LayoutOrder = 2
local renameTreeButton = createButton(fileActionsScroll, "Rename", UDim2.new(1, -4, 0, 24), UDim2.new(), nil, COLORS.PanelHover)
renameTreeButton.TextSize = 9
renameTreeButton.LayoutOrder = 3
local deleteTreeButton = createButton(fileActionsScroll, "Delete", UDim2.new(1, -4, 0, 24), UDim2.new(), nil, Color3.fromRGB(105, 47, 57))
deleteTreeButton.TextSize = 9
deleteTreeButton.LayoutOrder = 4

local treeListTop = 27 + actionScrollHeight + 5
local treeList = make("ScrollingFrame", {
    Name = "FileTreeList",
    Position = UDim2.fromOffset(4, treeListTop),
    Size = UDim2.new(1, -8, 1, -(treeListTop + 4)),
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
editorFileLabel = createLabel(codePanel, "main.lua", UDim2.new(1, -58, 0, 25), UDim2.fromOffset(3, 5), 10, COLORS.Muted, Enum.Font.GothamBold)
local newlineButton = createButton(codePanel, "Enter", UDim2.fromOffset(48, 24), UDim2.new(1, -51, 0, 5), nil, COLORS.Panel2)
newlineButton.TextSize = 10

-- The viewport stays inside the editor panel. The TextBox itself grows to the
-- measured size of the code, so both axes can be scrolled without wrapping lines.
editorViewport = make("ScrollingFrame", {
    Name = "CodeViewport",
    Position = UDim2.fromOffset(3, 32),
    Size = UDim2.new(1, -6, 1, -38),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ScrollBarThickness = compact and 5 or 7,
    ScrollBarImageColor3 = COLORS.Muted,
    ScrollingDirection = Enum.ScrollingDirection.XY,
    CanvasSize = UDim2.fromOffset(0, 0),
    Active = true,
}, codePanel)
addCorner(editorViewport, 6)

editorBox = make("TextBox", {
    Name = "CodeEditor",
    Position = UDim2.fromOffset(8, 6),
    Size = UDim2.fromOffset(320, 220),
    BackgroundTransparency = 1,
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
    Active = true,
}, editorViewport)

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

local function measureEditorCanvas()
    if not editorBox or not editorBox.Parent or not editorViewport then
        return
    end

    local visible = editorViewport.AbsoluteSize
    if visible.X <= 0 or visible.Y <= 0 then
        return
    end

    local source = editorBox.Text or ""
    local lineCount = 0
    local longestLine = ""
    for line in (source .. "\n"):gmatch("(.-)\n") do
        lineCount = lineCount + 1
        if #line > #longestLine then
            longestLine = line
        end
    end
    if lineCount == 0 then
        lineCount = 1
    end

    local textSize = editorBox.TextSize
    local font = editorBox.Font
    local widthBounds = TextService:GetTextSize(longestLine ~= "" and longestLine or " ", textSize, font, Vector2.new(100000, 100000))
    local lineBounds = TextService:GetTextSize("Ag", textSize, font, Vector2.new(100000, 100000))

    local editorWidth = math.max(visible.X - 16, math.ceil(widthBounds.X + 28))
    local editorHeight = math.max(visible.Y - 12, math.ceil(lineCount * lineBounds.Y + 18))

    editorBox.Size = UDim2.fromOffset(editorWidth, editorHeight)
    editorViewport.CanvasSize = UDim2.fromOffset(editorWidth + 16, editorHeight + 12)
end

local function keepEditorCaretVisible()
    if not editorBox or not editorViewport or not editorBox.Parent then
        return
    end

    local cursor = editorBox.CursorPosition
    if not cursor or cursor < 1 then
        return
    end

    local source = editorBox.Text or ""
    cursor = math.clamp(cursor, 1, #source + 1)
    local beforeCaret = string.sub(source, 1, cursor - 1)
    local lineNumber = 1
    for _ in beforeCaret:gmatch("\n") do
        lineNumber = lineNumber + 1
    end
    local lastBreak = 0
    local searchFrom = 1
    while true do
        local found = string.find(beforeCaret, "\n", searchFrom, true)
        if not found then
            break
        end
        lastBreak = found
        searchFrom = found + 1
    end
    local linePrefix = string.sub(beforeCaret, lastBreak + 1)
    local prefixBounds = TextService:GetTextSize(
        linePrefix ~= "" and linePrefix or " ",
        editorBox.TextSize,
        editorBox.Font,
        Vector2.new(100000, 100000)
    )
    local lineBounds = TextService:GetTextSize("Ag", editorBox.TextSize, editorBox.Font, Vector2.new(100000, 100000))
    local lineHeight = math.max(1, lineBounds.Y)
    local caretX = 8 + (linePrefix == "" and 0 or prefixBounds.X)
    local caretY = 6 + (lineNumber - 1) * lineHeight
    local view = editorViewport.AbsoluteSize
    local current = editorViewport.CanvasPosition
    local margin = 16
    local nextX = current.X
    local nextY = current.Y

    if caretX < current.X + margin then
        nextX = math.max(0, caretX - margin)
    elseif caretX + charWidth > current.X + view.X - margin then
        nextX = caretX + charWidth - view.X + margin
    end
    if caretY < current.Y + margin then
        nextY = math.max(0, caretY - margin)
    elseif caretY + lineHeight > current.Y + view.Y - margin then
        nextY = caretY + lineHeight - view.Y + margin
    end

    editorViewport.CanvasPosition = Vector2.new(math.max(0, nextX), math.max(0, nextY))
end

editorBox:GetPropertyChangedSignal("Text"):Connect(function()
    -- Keep the active buffer up to date immediately, even before the user presses Save.
    if currentProject then
        syncEditorToFile(currentProject, editorBox.Text)
    end
    measureEditorCanvas()
    task.defer(keepEditorCaretVisible)
end)

-- Do not auto-scroll on mouse focus: Roblox may briefly report a temporary caret
-- position when a TextBox first receives focus. Follow caret movement from keys instead.
UserInputService.InputBegan:Connect(function(input)
    if not editorBox or not editorBox:IsFocused() then
        return
    end
    local key = input.KeyCode
    if key == Enum.KeyCode.Left or key == Enum.KeyCode.Right
        or key == Enum.KeyCode.Up or key == Enum.KeyCode.Down
        or key == Enum.KeyCode.Home or key == Enum.KeyCode.End
        or key == Enum.KeyCode.PageUp or key == Enum.KeyCode.PageDown then
        task.defer(keepEditorCaretVisible)
    end
end)

editorViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    measureEditorCanvas()
end)
task.defer(measureEditorCanvas)

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
            local prefix
            if entry.isFolder then
                prefix = expandedFolders[entry.path] == false and "DIR+ " or "DIR- "
            else
                prefix = "FILE "
            end
            local rowText = string.rep("  ", math.min(depth, 4)) .. prefix .. entry.name
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
                    refreshEditorFileHeader(entry.path)
                    editorViewport.CanvasPosition = Vector2.new(0, 0)
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

local function currentCreationBase()
    if selectedTreeIsFolder then
        return selectedTreePath
    end
    return parentPath(selectedTreePath)
end

local function appendToBase(base, name)
    if base == "" then return name end
    return base .. "/" .. name
end

newFileButton.Activated:Connect(function()
    if not currentProject then return end
    local initial = appendToBase(currentCreationBase(), "new.lua")
    showPathPopup("Add file", initial, "Create", function(value)
        local path = normalizePath(value)
        if not path then return false, "Invalid file path." end
        if not path:match("%.[%w_%-]+$") then path = path .. ".lua" end
        if not isSupportedFile(path) then
            return false, "Supported types: .lua, .luau, .json, .txt, .md"
        end
        if pathTaken(currentProject, path) then
            return false, "A file or folder with this path already exists."
        end
        syncEditorToFile(currentProject, editorBox.Text)
        ensureParentFolders(currentProject, path)
        table.insert(currentProject.files, {
            path = path,
            code = "",
            autoExecute = false,
        })
        currentProject.activeFile = path
        editorBox.Text = ""
        refreshEditorFileHeader(path)
        editorViewport.CanvasPosition = Vector2.new(0, 0)
        selectedTreePath = path
        selectedTreeIsFolder = false
        currentProject.updated = os.time()
        saveData()
        renderFileTree()
        if renderProjects then renderProjects() end
        if renderExecutePage then renderExecutePage() end
        return true
    end)
end)

newFolderButton.Activated:Connect(function()
    if not currentProject then return end
    local initial = appendToBase(currentCreationBase(), "NewFolder")
    showPathPopup("Add folder", initial, "Create", function(value)
        local path = normalizePath(value)
        if not path then return false, "Invalid folder path." end
        if pathTaken(currentProject, path) then
            return false, "A file or folder with this path already exists."
        end
        syncEditorToFile(currentProject, editorBox.Text)
        ensureParentFolders(currentProject, path)
        table.insert(currentProject.folders, path)
        selectedTreePath = path
        selectedTreeIsFolder = true
        expandedFolders[path] = true
        currentProject.updated = os.time()
        saveData()
        renderFileTree()
        if renderProjects then renderProjects() end
        return true
    end)
end)

renameTreeButton.Activated:Connect(function()
    if not currentProject then return end
    if not selectedTreePath or selectedTreePath == "" then
        logConsole("Warning", "Select a file or folder to rename.")
        openConsole()
        return
    end

    syncEditorToFile(currentProject, editorBox.Text)
    local oldPath = selectedTreePath
    local isFolder = selectedTreeIsFolder
    local initial = oldPath
    showPathPopup(isFolder and "Rename folder" or "Rename file", initial, "Rename", function(value)
        local newPath = normalizePath(value)
        if not newPath then return false, "Invalid path." end
        if newPath == oldPath then return true end

        if isFolder then
            local oldPrefix = oldPath .. "/"
            if string.sub(newPath, 1, #oldPrefix) == oldPrefix then
                return false, "A folder cannot be moved inside itself."
            end
            if pathTaken(currentProject, newPath, nil, oldPath) then
                return false, "A file or folder with this path already exists."
            end

            local mappedFiles = {}
            for _, file in ipairs(currentProject.files) do
                local isInside = file.path == oldPath or string.sub(file.path, 1, #oldPrefix) == oldPrefix
                if isInside then
                    local suffix = file.path == oldPath and "" or string.sub(file.path, #oldPath + 2)
                    local mapped = suffix == "" and newPath or (newPath .. "/" .. suffix)
                    if not isSupportedFile(mapped) then
                        return false, "Folder contains an unsupported file type: " .. mapped
                    end
                    if mappedFiles[mapped] then
                        return false, "Rename would create duplicate file paths."
                    end
                    mappedFiles[mapped] = true
                end
            end
            for _, file in ipairs(currentProject.files) do
                local inside = file.path == oldPath or string.sub(file.path, 1, #oldPrefix) == oldPrefix
                if not inside and mappedFiles[file.path] then
                    return false, "Rename would overwrite an existing file."
                end
            end
            for _, folder in ipairs(currentProject.folders) do
                local inside = folder == oldPath or string.sub(folder, 1, #oldPrefix) == oldPrefix
                if not inside and (folder == newPath or string.sub(folder, 1, #newPath + 1) == newPath .. "/") then
                    return false, "Rename would overlap an existing folder."
                end
            end

            local activePath = currentProject.activeFile
            if activePath == oldPath then
                currentProject.activeFile = newPath
            elseif string.sub(activePath or "", 1, #oldPrefix) == oldPrefix then
                currentProject.activeFile = newPath .. string.sub(activePath, #oldPath + 1)
            end
            for _, file in ipairs(currentProject.files) do
                if file.path == oldPath then
                    file.path = newPath
                elseif string.sub(file.path, 1, #oldPrefix) == oldPrefix then
                    file.path = newPath .. string.sub(file.path, #oldPath + 1)
                end
            end
            if currentProject.activeFile then
                refreshEditorFileHeader(currentProject.activeFile)
            end
            for index, folder in ipairs(currentProject.folders) do
                if folder == oldPath then
                    currentProject.folders[index] = newPath
                elseif string.sub(folder, 1, #oldPrefix) == oldPrefix then
                    currentProject.folders[index] = newPath .. string.sub(folder, #oldPath + 1)
                end
            end
            local movedExpanded = {}
            for path, expanded in pairs(expandedFolders) do
                if path == oldPath then
                    movedExpanded[newPath] = expanded
                elseif string.sub(path, 1, #oldPrefix) == oldPrefix then
                    movedExpanded[newPath .. string.sub(path, #oldPath + 1)] = expanded
                else
                    movedExpanded[path] = expanded
                end
            end
            expandedFolders = movedExpanded
            ensureParentFolders(currentProject, newPath)
        else
            local oldExtension = getFileExtension(oldPath)
            if not newPath:match("%.[%w_%-]+$") then
                newPath = newPath .. "." .. oldExtension
            end
            if not isSupportedFile(newPath) then
                return false, "Supported types: .lua, .luau, .json, .txt, .md"
            end
            if pathTaken(currentProject, newPath, oldPath) then
                return false, "A file or folder with this path already exists."
            end
            local file = getProjectFile(currentProject, oldPath)
            if not file then return false, "The selected file no longer exists." end
            file.path = newPath
            if not isScriptFile(newPath) then
                file.autoExecute = false
            end
            if currentProject.activeFile == oldPath then
                currentProject.activeFile = newPath
                refreshEditorFileHeader(newPath)
            end
            ensureParentFolders(currentProject, newPath)
        end

        selectedTreePath = newPath
        currentProject.updated = os.time()
        saveData()
        renderFileTree()
        if renderProjects then renderProjects() end
        if renderExecutePage then renderExecutePage() end
        logConsole("Success", "Renamed " .. oldPath .. " to " .. newPath)
        return true
    end)
end)

deleteTreeButton.Activated:Connect(function()
    if not currentProject then return end
    if not selectedTreePath or selectedTreePath == "" then
        logConsole("Warning", "Select a file or folder to delete.")
        openConsole()
        return
    end

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
        logConsole("Info", "Deleted folder and its contents: " .. target)
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
        currentProject.activeFile = "main.lua"
    elseif selectedTreeIsFolder then
        local activeFile = getProjectFile(currentProject, currentProject.activeFile)
        if not activeFile then
            currentProject.activeFile = currentProject.files[1].path
        end
    elseif currentProject.activeFile == target then
        currentProject.activeFile = currentProject.files[1].path
    end

    local activeFile = getProjectFile(currentProject, currentProject.activeFile)
    editorBox.Text = activeFile and activeFile.code or ""
    refreshEditorFileHeader(currentProject.activeFile)
    editorViewport.CanvasPosition = Vector2.new(0, 0)
    selectedTreePath = currentProject.activeFile
    selectedTreeIsFolder = false
    currentProject.updated = os.time()
    saveData()
    renderFileTree()
    if renderProjects then renderProjects() end
    if renderExecutePage then renderExecutePage() end
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
    local close = createButton(bar, "X", UDim2.fromOffset(28, 26), UDim2.new(1, -34, 0, 6), function()
        if onClose then
            onClose()
        else
            frame.Visible = false
        end
    end)
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

-- Dex: full client-visible Explorer + Properties + source viewer.
local dexWindow = nil
local scriptViewerWindows = {}
local registeredScriptSources = setmetatable({}, {__mode = "k"})

local function getSharedEnvironment()
    local sharedEnvironment = nil
    pcall(function()
        if type(getgenv) == "function" then
            sharedEnvironment = getgenv()
        else
            sharedEnvironment = _G
        end
    end)
    return sharedEnvironment
end

local dexAPI = {}
function dexAPI.RegisterSource(scriptObject, sourceText)
    if typeof(scriptObject) ~= "Instance" then
        return false, "The first argument must be an Instance."
    end
    if type(sourceText) ~= "string" then
        return false, "The source must be a string."
    end
    local className = scriptObject.ClassName
    if className ~= "Script" and className ~= "LocalScript" and className ~= "ModuleScript" then
        return false, "Only Script, LocalScript, and ModuleScript are supported."
    end
    registeredScriptSources[scriptObject] = sourceText
    return true
end

local sharedEnvironment = getSharedEnvironment()
if sharedEnvironment then
    pcall(function()
        sharedEnvironment.EasyScriptingDex = dexAPI
    end)
end

-- Approximation of Roblox ReflectionMetadataClass.ExplorerOrder for common classes.
-- Original Dex sorts by ExplorerOrder first, then by Instance name, then ClassName.
-- Classes absent from this table use the metadata default and fall back to name sorting.
local DEX_CLASS_ORDER = {
    TerrainRegion = 0,
    Clothing = 0,
    BackpackItem = 0,
    Sound = 1,
    Team = 1,
    Hat = 3,
    Smoke = 3,
    Sparkles = 3,
    Explosion = 3,
    ForceField = 3,
    SpawnLocation = 3,
    NetworkClient = 3,
    NetworkServer = 3,
    NetworkReplicator = 3,
    Script = 3,
    Tool = 3,
    PointLight = 3,
    SpotLight = 3,
    BoolValue = 3,
    IntValue = 3,
    NumberValue = 3,
    StringValue = 3,
    ObjectValue = 3,
    Vector3Value = 3,
    CFrameValue = 3,
    Color3Value = 3,
    BrickColorValue = 3,
    BindableFunction = 4,
    RemoteFunction = 4,
    LocalScript = 4,
    BindableEvent = 5,
    RemoteEvent = 5,
    ModuleScript = 5,
    Model = 10,
    Part = 11,
    TrussPart = 12,
    WedgePart = 12,
    CornerWedgePart = 12,
    PlayerGui = 13,
    ScreenGui = 14,
    BillboardGui = 14,
    SurfaceGui = 14,
    JointInstance = 20,
    Weld = 20,
    HttpService = 101,
}

local function getDexClassOrder(object)
    local order = DEX_CLASS_ORDER[object.ClassName]
    if order ~= nil then
        return order
    end
    return 2147483647
end

local function safeChildren(object)
    local ok, children = pcall(function()
        return object:GetChildren()
    end)
    if ok and type(children) == "table" then
        table.sort(children, function(a, b)
            local aOrder = getDexClassOrder(a)
            local bOrder = getDexClassOrder(b)
            if aOrder ~= bOrder then
                return aOrder < bOrder
            end
            local aName = tostring(a.Name)
            local bName = tostring(b.Name)
            if aName ~= bName then
                return aName < bName
            end
            return a.ClassName < b.ClassName
        end)
        return children
    end
    return {}
end

local function classBadge(className)
    local badges = {
        Workspace = {"WS", Color3.fromRGB(73, 153, 105)},
        Folder = {"FD", Color3.fromRGB(211, 166, 74)},
        Model = {"MD", Color3.fromRGB(95, 145, 205)},
        Part = {"PT", Color3.fromRGB(125, 137, 157)},
        MeshPart = {"MP", Color3.fromRGB(125, 137, 157)},
        Script = {"SC", Color3.fromRGB(225, 164, 75)},
        LocalScript = {"LS", Color3.fromRGB(225, 164, 75)},
        ModuleScript = {"MS", Color3.fromRGB(225, 164, 75)},
        RemoteEvent = {"RE", Color3.fromRGB(206, 126, 75)},
        RemoteFunction = {"RF", Color3.fromRGB(206, 126, 75)},
        BindableEvent = {"BE", Color3.fromRGB(160, 125, 205)},
        BindableFunction = {"BF", Color3.fromRGB(160, 125, 205)},
        ScreenGui = {"UI", Color3.fromRGB(91, 157, 205)},
        Player = {"PL", Color3.fromRGB(93, 170, 145)},
        Camera = {"CM", Color3.fromRGB(120, 150, 190)},
        Humanoid = {"HM", Color3.fromRGB(93, 170, 145)},
        Sound = {"AU", Color3.fromRGB(154, 128, 207)},
    }
    if badges[className] then
        return badges[className][1], badges[className][2]
    end
    if className:find("Value") then
        return "VL", Color3.fromRGB(143, 170, 105)
    end
    if className:find("Service") then
        return "SV", Color3.fromRGB(80, 145, 175)
    end
    return string.sub(className, 1, 2):upper(), COLORS.Muted
end

local function createDexIcon(parent, className, position, zIndex)
    local code, color = classBadge(className)
    local root = make("Frame", {
        Size = UDim2.fromOffset(19, 19),
        Position = position,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = zIndex or 55,
    }, parent)

    local function shape(size, offset, fill, radius, rotation)
        local item = make("Frame", {
            Size = size,
            Position = offset,
            BackgroundColor3 = fill,
            BorderSizePixel = 0,
            Rotation = rotation or 0,
            ZIndex = (zIndex or 55) + 1,
        }, root)
        if radius then addCorner(item, radius) end
        return item
    end

    if className == "Folder" then
        shape(UDim2.fromOffset(9, 4), UDim2.fromOffset(2, 3), color, 2)
        shape(UDim2.fromOffset(15, 10), UDim2.fromOffset(2, 6), color, 2)
    elseif className == "Script" or className == "LocalScript" or className == "ModuleScript" then
        local paper = shape(UDim2.fromOffset(12, 16), UDim2.fromOffset(4, 1), Color3.fromRGB(218, 224, 232), 2)
        paper.ZIndex = (zIndex or 55) + 1
        local stripeColor = className == "LocalScript" and Color3.fromRGB(80, 172, 134)
            or (className == "ModuleScript" and Color3.fromRGB(106, 143, 216) or Color3.fromRGB(218, 157, 67))
        shape(UDim2.fromOffset(2, 16), UDim2.fromOffset(4, 1), stripeColor, 1)
        shape(UDim2.fromOffset(7, 1), UDim2.fromOffset(7, 6), Color3.fromRGB(88, 99, 115), 1)
        shape(UDim2.fromOffset(7, 1), UDim2.fromOffset(7, 9), Color3.fromRGB(88, 99, 115), 1)
        shape(UDim2.fromOffset(5, 1), UDim2.fromOffset(7, 12), Color3.fromRGB(88, 99, 115), 1)
    elseif className == "RemoteEvent" or className == "RemoteFunction" or className == "BindableEvent" or className == "BindableFunction" then
        shape(UDim2.fromOffset(13, 13), UDim2.fromOffset(3, 3), color, 7)
        shape(UDim2.fromOffset(7, 3), UDim2.fromOffset(6, 8), COLORS.Background, 2)
    elseif className == "Model" then
        shape(UDim2.fromOffset(8, 8), UDim2.fromOffset(2, 5), color, 2)
        shape(UDim2.fromOffset(8, 8), UDim2.fromOffset(8, 2), color, 2)
    elseif className == "Part" or className == "MeshPart" or className:find("Part") then
        shape(UDim2.fromOffset(12, 12), UDim2.fromOffset(3, 3), color, 2, 0)
        shape(UDim2.fromOffset(6, 1), UDim2.fromOffset(6, 8), COLORS.Background, 1)
    elseif className:find("Service") or className == "Workspace" or className == "Players" or className == "Lighting" then
        shape(UDim2.fromOffset(14, 5), UDim2.fromOffset(2, 3), color, 2)
        shape(UDim2.fromOffset(14, 5), UDim2.fromOffset(2, 10), color, 2)
    else
        local tile = shape(UDim2.fromOffset(16, 16), UDim2.fromOffset(1, 1), color, 4)
        local label = createLabel(tile, code, UDim2.fromScale(1, 1), UDim2.new(), 7, Color3.new(1, 1, 1), Enum.Font.GothamBold)
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.ZIndex = (zIndex or 55) + 2
    end
    return root
end

local function formatPropertyValue(value)
    local valueType = typeof(value)
    if valueType == "Instance" then
        return value.Name .. " [" .. value.ClassName .. "]"
    elseif valueType == "Color3" then
        return string.format("R:%d G:%d B:%d", math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
    elseif valueType == "Vector3" then
        return string.format("%.3f, %.3f, %.3f", value.X, value.Y, value.Z)
    elseif valueType == "Vector2" then
        return string.format("%.3f, %.3f", value.X, value.Y)
    elseif valueType == "EnumItem" then
        return tostring(value):gsub("^Enum%.", "")
    elseif valueType == "string" then
        return value == "" and '""' or value
    end
    return tostring(value)
end

local function openScriptNotepad(scriptObject)
    local sourceText = registeredScriptSources[scriptObject]
    local sourceNote = nil
    if type(sourceText) ~= "string" then
        local ok, result = pcall(function()
            return scriptObject.Source
        end)
        if ok and type(result) == "string" then
            sourceText = result
        else
            sourceNote = "Roblox does not expose this Script.Source to the client.\n\nFor a script you own, provide its source to the viewer from your authorized development setup with:\n\ngetgenv().EasyScriptingDex.RegisterSource(scriptInstance, [[\n-- your source code\n]])\n\nThe viewer does not bypass Roblox source-access restrictions."
            sourceText = sourceNote
        end
    end

    local width = math.max(300, math.min(820, viewport.X - 36))
    local height = math.max(240, math.min(600, viewport.Y - 50))
    local frame, content
    frame, content = makeToolWindow("DexNotepad_" .. tostring(#scriptViewerWindows + 1), "Notepad - " .. scriptObject.Name, width, height, function()
        frame.Visible = false
    end)
    table.insert(scriptViewerWindows, frame)

    local pathLabel = createLabel(content, objectPath(scriptObject), UDim2.new(1, -4, 0, 22), UDim2.fromOffset(0, 0), 9, COLORS.Muted, Enum.Font.Code)
    pathLabel.ZIndex = 53

    local scroll = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 27),
        Size = UDim2.new(1, 0, 1, -27),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 7,
        ScrollBarImageColor3 = COLORS.Muted,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 52,
    }, content)
    addCorner(scroll, 7)

    local noteBox = make("TextBox", {
        Name = "SourceText",
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(600, 300),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextEditable = false,
        Text = sourceText,
        TextColor3 = sourceNote and COLORS.Yellow or COLORS.Text,
        TextSize = 12,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        ZIndex = 53,
    }, scroll)

    local maxLineWidth = 500
    local lineCount = 1
    for line in (sourceText .. "\n"):gmatch("(.-)\n") do
        lineCount = lineCount + 1
        local ok, measured = pcall(function()
            return TextService:GetTextSize(line, 12, Enum.Font.Code, Vector2.new(100000, 30))
        end)
        if ok then
            maxLineWidth = math.max(maxLineWidth, measured.X)
        end
    end
    local contentWidth = math.max(scroll.AbsoluteSize.X - 16, maxLineWidth + 22)
    local contentHeight = math.max(scroll.AbsoluteSize.Y - 16, lineCount * 17 + 20)
    noteBox.Size = UDim2.fromOffset(contentWidth, contentHeight)
    scroll.CanvasSize = UDim2.fromOffset(contentWidth + 16, contentHeight + 16)
    raiseZIndex(frame, 60)
end

local function openDex()
    if dexWindow then
        dexWindow.Visible = true
        raiseZIndex(dexWindow, 50)
        return
    end

    local width = math.max(300, math.min(940, viewport.X - 28))
    local height = math.max(260, math.min(650, viewport.Y - 36))
    local selectedObject = game
    local expanded = {[game] = true}
    local clickTimes = setmetatable({}, {__mode = "k"})
    local frame, content
    local treeList
    local propertiesList
    local renderTree
    local updateProperties
    local searchBox

    frame, content = makeToolWindow("DexExplorerWindow", "Dex Explorer", width, height, function()
        frame.Visible = false
    end)
    dexWindow = frame

    local toolbar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 53,
    }, content)
    local searchWrap = make("Frame", {
        Size = UDim2.new(1, -86, 1, 0),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        ZIndex = 53,
    }, toolbar)
    addCorner(searchWrap, 6)
    searchBox = make("TextBox", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.fromOffset(7, 0),
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        PlaceholderText = "Search all client-visible objects...",
        Text = "",
        TextColor3 = COLORS.Text,
        PlaceholderColor3 = COLORS.Muted,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 54,
    }, searchWrap)
    local refresh = createButton(toolbar, "Refresh", UDim2.fromOffset(78, 30), UDim2.new(1, -78, 0, 0), function()
        renderTree()
        updateProperties(selectedObject)
    end, COLORS.Panel2)
    refresh.ZIndex = 54

    local dividerX = width < 520 and 0.53 or 0.55
    treeList = make("ScrollingFrame", {
        Name = "ExplorerTree",
        Position = UDim2.fromOffset(0, 38),
        Size = UDim2.new(dividerX, -5, 1, -38),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 7,
        ScrollBarImageColor3 = COLORS.Muted,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 52,
    }, content)
    addCorner(treeList, 7)
    local treeLayout = make("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder}, treeList)
    treeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        treeList.CanvasSize = UDim2.fromOffset(0, treeLayout.AbsoluteContentSize.Y + 8)
    end)

    local propertiesPanel = make("Frame", {
        Position = UDim2.new(dividerX, 5, 0, 38),
        Size = UDim2.new(1 - dividerX, -5, 1, -38),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 52,
    }, content)
    addCorner(propertiesPanel, 7)
    local propertiesTitle = createLabel(propertiesPanel, "  Properties", UDim2.new(1, -12, 0, 25), UDim2.fromOffset(6, 1), 11, COLORS.Text, Enum.Font.GothamBold)
    propertiesTitle.ZIndex = 54
    propertiesList = make("ScrollingFrame", {
        Position = UDim2.fromOffset(4, 28),
        Size = UDim2.new(1, -8, 1, -32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = COLORS.Muted,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 53,
    }, propertiesPanel)
    local propertiesLayout = make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, propertiesList)
    propertiesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        propertiesList.CanvasSize = UDim2.fromOffset(0, propertiesLayout.AbsoluteContentSize.Y + 8)
    end)

    local function clearGuiRows(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
                child:Destroy()
            end
        end
    end

    local function addPropertyCategory(title, order)
        local label = createLabel(propertiesList, title:upper(), UDim2.new(1, -8, 0, 22), UDim2.new(), 9, COLORS.Blue, Enum.Font.GothamBold)
        label.LayoutOrder = order
        label.ZIndex = 55
        local line = make("Frame", {
            Size = UDim2.new(1, -8, 0, 1),
            BackgroundColor3 = COLORS.Border,
            BorderSizePixel = 0,
            LayoutOrder = order + 1,
            ZIndex = 54,
        }, propertiesList)
        return order + 2
    end

    local function addPropertyRow(name, value, order)
        local row = make("Frame", {
            Size = UDim2.new(1, -8, 0, 27),
            BackgroundColor3 = order % 2 == 0 and COLORS.Panel2 or COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 54,
        }, propertiesList)
        local keyLabel = createLabel(row, name, UDim2.new(0.43, -4, 1, 0), UDim2.fromOffset(6, 0), 9, COLORS.Muted)
        keyLabel.ZIndex = 55
        local valueLabel = createLabel(row, tostring(value), UDim2.new(0.57, -8, 1, 0), UDim2.new(0.43, 0, 0, 0), 9, COLORS.Text, Enum.Font.Code)
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valueLabel.ZIndex = 55
        return order + 1
    end

    updateProperties = function(object)
        clearGuiRows(propertiesList)
        local order = 1
        if not object then
            order = addPropertyCategory("Selection", order)
            addPropertyRow("Object", "Nothing selected", order)
            return
        end
        propertiesTitle.Text = "  Properties - " .. object.Name
        order = addPropertyCategory("Instance", order)
        order = addPropertyRow("Name", object.Name, order)
        order = addPropertyRow("ClassName", object.ClassName, order)
        order = addPropertyRow("Parent", object.Parent and object.Parent.Name or "nil", order)
        order = addPropertyRow("Path", objectPath(object), order)
        local archivableOk, archivable = pcall(function() return object.Archivable end)
        if archivableOk then order = addPropertyRow("Archivable", tostring(archivable), order) end
        order = addPropertyRow("Children", tostring(#safeChildren(object)), order)

        if object:IsA("BasePart") then
            order = addPropertyCategory("Transform", order + 1)
            order = addPropertyRow("Position", formatPropertyValue(object.Position), order)
            order = addPropertyRow("Orientation", formatPropertyValue(object.Orientation), order)
            order = addPropertyRow("Size", formatPropertyValue(object.Size), order)
            order = addPropertyCategory("Appearance", order + 1)
            order = addPropertyRow("Color", formatPropertyValue(object.Color), order)
            order = addPropertyRow("Material", formatPropertyValue(object.Material), order)
            order = addPropertyRow("Transparency", formatPropertyValue(object.Transparency), order)
            order = addPropertyRow("Reflectance", formatPropertyValue(object.Reflectance), order)
            order = addPropertyCategory("Behavior", order + 1)
            order = addPropertyRow("Anchored", tostring(object.Anchored), order)
            order = addPropertyRow("CanCollide", tostring(object.CanCollide), order)
            order = addPropertyRow("CanTouch", tostring(object.CanTouch), order)
            order = addPropertyRow("CanQuery", tostring(object.CanQuery), order)
        elseif object:IsA("ValueBase") then
            order = addPropertyCategory("Value", order + 1)
            order = addPropertyRow("Value", formatPropertyValue(object.Value), order)
        elseif object:IsA("Humanoid") then
            order = addPropertyCategory("Humanoid", order + 1)
            order = addPropertyRow("DisplayName", object.DisplayName, order)
            order = addPropertyRow("Health", tostring(object.Health), order)
            order = addPropertyRow("MaxHealth", tostring(object.MaxHealth), order)
            order = addPropertyRow("WalkSpeed", tostring(object.WalkSpeed), order)
            order = addPropertyRow("JumpPower", tostring(object.JumpPower), order)
            order = addPropertyRow("RigType", tostring(object.RigType), order)
        elseif object:IsA("GuiObject") then
            order = addPropertyCategory("Gui", order + 1)
            order = addPropertyRow("Visible", tostring(object.Visible), order)
            order = addPropertyRow("Position", formatPropertyValue(object.Position), order)
            order = addPropertyRow("Size", formatPropertyValue(object.Size), order)
            order = addPropertyRow("AnchorPoint", formatPropertyValue(object.AnchorPoint), order)
            order = addPropertyRow("BackgroundColor3", formatPropertyValue(object.BackgroundColor3), order)
            order = addPropertyRow("BackgroundTransparency", tostring(object.BackgroundTransparency), order)
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                order = addPropertyRow("Text", object.Text, order)
                order = addPropertyRow("TextSize", tostring(object.TextSize), order)
            end
        elseif object:IsA("Sound") then
            order = addPropertyCategory("Sound", order + 1)
            order = addPropertyRow("SoundId", object.SoundId, order)
            order = addPropertyRow("Volume", tostring(object.Volume), order)
            order = addPropertyRow("PlaybackSpeed", tostring(object.PlaybackSpeed), order)
            order = addPropertyRow("Playing", tostring(object.Playing), order)
        end

        local attributesOk, attributes = pcall(function() return object:GetAttributes() end)
        if attributesOk and next(attributes) then
            order = addPropertyCategory("Attributes", order + 1)
            local names = {}
            for attributeName in pairs(attributes) do table.insert(names, attributeName) end
            table.sort(names)
            for _, attributeName in ipairs(names) do
                order = addPropertyRow(attributeName, formatPropertyValue(attributes[attributeName]), order)
            end
        end
        local tagsOk, tags = pcall(function()
            return game:GetService("CollectionService"):GetTags(object)
        end)
        if tagsOk and #tags > 0 then
            table.sort(tags)
            order = addPropertyCategory("Tags", order + 1)
            order = addPropertyRow("CollectionService", table.concat(tags, ", "), order)
        end
    end

    local function addTreeRow(object, depth, order, searchablePath)
        local children = safeChildren(object)
        local isExpanded = expanded[object] == true
        local indent = math.min(depth * 13, 150)
        local row = make("Frame", {
            Size = UDim2.new(1, -5, 0, 24),
            BackgroundColor3 = selectedObject == object and COLORS.PanelHover or COLORS.Panel,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 54,
        }, treeList)
        local expander = createButton(row, #children > 0 and (isExpanded and "v" or ">") or " ", UDim2.fromOffset(15, 22), UDim2.fromOffset(indent, 1), function()
            if #children > 0 then
                expanded[object] = not isExpanded
                renderTree()
            end
        end, COLORS.Panel)
        expander.TextSize = 10
        expander.ZIndex = 56

        createDexIcon(row, object.ClassName, UDim2.fromOffset(indent + 16, 2), 55)

        local rowText = searchablePath or object.Name
        local selectButton = make("TextButton", {
            Size = UDim2.new(1, -(indent + 40), 1, 0),
            Position = UDim2.fromOffset(indent + 39, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = rowText .. (searchablePath and ("  [" .. object.ClassName .. "]") or ""),
            TextColor3 = COLORS.Text,
            TextSize = 9,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = true,
            ZIndex = 55,
        }, row)
        selectButton.Activated:Connect(function()
            local now = os.clock()
            local lastTap = clickTimes[object] or 0
            local doubleTap = now - lastTap <= 0.38
            clickTimes[object] = now
            selectedObject = object
            updateProperties(object)
            renderTree()
            if doubleTap and (object.ClassName == "Script" or object.ClassName == "LocalScript" or object.ClassName == "ModuleScript") then
                openScriptNotepad(object)
            end
        end)
        if not searchablePath and isExpanded then
            for _, child in ipairs(children) do
                order = order + 1
                if order > 3500 then break end
                order = addTreeRow(child, depth + 1, order, nil)
            end
        end
        return order
    end

    renderTree = function()
        clearGuiRows(treeList)
        local query = string.lower(searchBox.Text or "")
        local order = 0
        if query ~= "" then
            local ok, descendants = pcall(function() return game:GetDescendants() end)
            local matches = {}
            if ok then
                for _, object in ipairs(descendants) do
                    local name = string.lower(object.Name)
                    if string.find(name, query, 1, true) then
                        table.insert(matches, object)
                        if #matches >= 1200 then break end
                    end
                end
            end
            table.sort(matches, function(a, b) return objectPath(a):lower() < objectPath(b):lower() end)
            for _, object in ipairs(matches) do
                order = order + 1
                addTreeRow(object, 0, order, objectPath(object))
            end
            if #matches == 0 then
                local empty = createLabel(treeList, "No matching objects", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 4), 10, COLORS.Muted)
                empty.LayoutOrder = 1
                empty.ZIndex = 55
            end
        else
            order = addTreeRow(game, 0, 1, nil)
        end
        updateProperties(selectedObject)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(renderTree)
    renderTree()
    raiseZIndex(dexWindow, 50)
end

-- RemoteSpy is an explicit instrumentation API for remotes in projects the user owns or may test.
-- It does not hook or intercept arbitrary remote calls in other experiences.
local remoteSpyWindow = nil
local remoteSpyAPI = nil
local remoteSpyState = {
    recording = false,
    groups = {},
    groupOrder = {},
    selectedKey = nil,
    activeDirection = "Outgoing",
    maxGroups = 100,
    maxHistory = 250,
}

local function safeSerialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    local valueType = typeof(value)
    if valueType == "string" then
        local safe = value:gsub("\n", "\\n")
        if #safe > 180 then safe = string.sub(safe, 1, 177) .. "..." end
        return string.format("%q", safe), "string"
    elseif valueType == "Instance" then
        return objectPath(value), "Instance<" .. value.ClassName .. ">"
    elseif valueType == "table" then
        if seen[value] then return "<cycle>", "table" end
        if depth >= 2 then return "{...}", "table" end
        seen[value] = true
        local parts = {}
        local count = 0
        for key, item in pairs(value) do
            count = count + 1
            if count > 10 then
                table.insert(parts, "...")
                break
            end
            local keyText = type(key) == "string" and key or ("[" .. tostring(key) .. "]")
            local itemText = safeSerialize(item, depth + 1, seen)
            table.insert(parts, tostring(keyText) .. " = " .. tostring(itemText))
        end
        seen[value] = nil
        return "{" .. table.concat(parts, ", ") .. "}", "table"
    elseif valueType == "function" then
        return "<function>", "function"
    elseif valueType == "thread" then
        return "<thread>", "thread"
    end
    local ok, textValue = pcall(tostring, value)
    return ok and textValue or "<unavailable>", valueType
end

local function captureCallSource()
    local debugLibrary = debug
    if type(debugLibrary) == "table" and type(debugLibrary.info) == "function" then
        local ok, source, line = pcall(debugLibrary.info, 3, "sl")
        if ok and source then
            return tostring(source) .. (line and (":" .. tostring(line)) or "")
        end
    end
    return "Not available (instrumented wrapper)"
end

local function packArguments(...)
    local packed = table.pack(...)
    local result = {}
    for index = 1, packed.n do
        local valueText, valueType = safeSerialize(packed[index])
        table.insert(result, {
            index = index,
            valueType = valueType,
            value = valueText,
        })
    end
    return result
end

local function remoteGroupKey(direction, remote, method)
    return direction .. "|" .. objectPath(remote) .. "|" .. method
end

local function recordRemoteCall(direction, remote, method, args, results, source)
    if not remoteSpyState.recording then return end
    local key = remoteGroupKey(direction, remote, method)
    local group = remoteSpyState.groups[key]
    if not group then
        group = {
            key = key,
            direction = direction,
            remote = remote,
            name = remote.Name,
            path = objectPath(remote),
            method = method,
            count = 0,
            history = {},
        }
        remoteSpyState.groups[key] = group
        table.insert(remoteSpyState.groupOrder, key)
        while #remoteSpyState.groupOrder > remoteSpyState.maxGroups do
            local removedKey = table.remove(remoteSpyState.groupOrder, 1)
            remoteSpyState.groups[removedKey] = nil
        end
    end
    group.count = group.count + 1
    local resultItems = results and packArguments(table.unpack(results, 1, results.n or #results)) or {}
    local entry = {
        time = os.date("%H:%M:%S"),
        timestamp = os.time(),
        args = args or {},
        results = resultItems,
        source = source or "Not available",
        activation = group.count,
    }
    table.insert(group.history, entry)
    while #group.history > remoteSpyState.maxHistory do
        table.remove(group.history, 1)
    end
    if remoteSpyState.onChanged then
        pcall(remoteSpyState.onChanged)
    end
end

local function publishRemoteSpyAPI()
    remoteSpyAPI = {
        -- Use these wrappers instead of direct calls in your own test scripts.
        FireServer = function(remote, ...)
            assert(typeof(remote) == "Instance" and remote:IsA("RemoteEvent"), "FireServer expects a RemoteEvent")
            recordRemoteCall("Outgoing", remote, "FireServer", packArguments(...), nil, captureCallSource())
            return remote:FireServer(...)
        end,
        InvokeServer = function(remote, ...)
            assert(typeof(remote) == "Instance" and remote:IsA("RemoteFunction"), "InvokeServer expects a RemoteFunction")
            local rawArguments = table.pack(...)
            local args = packArguments(table.unpack(rawArguments, 1, rawArguments.n))
            local callResults = table.pack(pcall(function()
                return remote:InvokeServer(table.unpack(rawArguments, 1, rawArguments.n))
            end))
            if not callResults[1] then
                recordRemoteCall("Outgoing", remote, "InvokeServer", args, nil, captureCallSource())
                error(callResults[2], 0)
            end
            local returned = {n = callResults.n - 1}
            for index = 2, callResults.n do returned[index - 1] = callResults[index] end
            recordRemoteCall("Outgoing", remote, "InvokeServer", args, returned, captureCallSource())
            return table.unpack(returned, 1, returned.n)
        end,
        ObserveIncoming = function(remote)
            assert(typeof(remote) == "Instance" and remote:IsA("RemoteEvent"), "ObserveIncoming expects a RemoteEvent")
            return remote.OnClientEvent:Connect(function(...)
                recordRemoteCall("Incoming", remote, "OnClientEvent", packArguments(...), nil, "Server -> client")
            end)
        end,
        ConnectIncoming = function(remote, callback)
            assert(typeof(remote) == "Instance" and remote:IsA("RemoteEvent"), "ConnectIncoming expects a RemoteEvent")
            assert(type(callback) == "function", "ConnectIncoming expects a callback")
            return remote.OnClientEvent:Connect(function(...)
                recordRemoteCall("Incoming", remote, "OnClientEvent", packArguments(...), nil, "Server -> client")
                callback(...)
            end)
        end,
        BindClientInvoke = function(remote, callback)
            assert(typeof(remote) == "Instance" and remote:IsA("RemoteFunction"), "BindClientInvoke expects a RemoteFunction")
            assert(type(callback) == "function", "BindClientInvoke expects a callback")
            remote.OnClientInvoke = function(...)
                local args = packArguments(...)
                local returned = table.pack(callback(...))
                recordRemoteCall("Incoming", remote, "OnClientInvoke", args, returned, "Server -> client")
                return table.unpack(returned, 1, returned.n)
            end
        end,
        Record = function(direction, remote, method, ...)
            assert(direction == "Outgoing" or direction == "Incoming", "Direction must be Outgoing or Incoming")
            assert(typeof(remote) == "Instance", "Record expects a Remote Instance")
            recordRemoteCall(direction, remote, method or "Manual", packArguments(...), nil, "Manual record")
        end,
        GetStatus = function()
            return remoteSpyState.recording and "Recording" or "Stopped"
        end,
    }
    local environment = getSharedEnvironment()
    if environment then
        pcall(function() environment.EasyScriptingRemoteSpy = remoteSpyAPI end)
    end
end

local function openRemoteSpy()
    if remoteSpyWindow then
        remoteSpyWindow.Visible = true
        raiseZIndex(remoteSpyWindow, 50)
        return
    end

    local width = math.max(300, math.min(940, viewport.X - 28))
    local height = math.max(260, math.min(650, viewport.Y - 36))
    local frame, content
    local leftList
    local rightList
    local statusLabel
    local startButton
    local clearButton
    local searchBox
    local renderLeft
    local renderRight
    local automaticIncomingConnections = {}
    local automaticFolderConnection = nil
    local automaticallyWatched = setmetatable({}, {__mode = "k"})

    local function stopAutomaticIncomingWatch()
        for _, connection in ipairs(automaticIncomingConnections) do
            pcall(function() connection:Disconnect() end)
        end
        automaticIncomingConnections = {}
        automaticallyWatched = setmetatable({}, {__mode = "k"})
        if automaticFolderConnection then
            pcall(function() automaticFolderConnection:Disconnect() end)
            automaticFolderConnection = nil
        end
    end

    local function watchOwnTestRemoteFolder()
        stopAutomaticIncomingWatch()
        local root = ReplicatedStorage:FindFirstChild("EasyScriptingRemotes")
        if not root then
            return 0, false
        end

        local watchedCount = 0
        local function attach(remote)
            if not remote:IsA("RemoteEvent") or automaticallyWatched[remote] then
                return
            end
            automaticallyWatched[remote] = true
            local connection = remote.OnClientEvent:Connect(function(...)
                if remoteSpyState.recording then
                    recordRemoteCall(
                        "Incoming",
                        remote,
                        "OnClientEvent",
                        packArguments(...),
                        nil,
                        "Server -> client (test folder)"
                    )
                end
            end)
            table.insert(automaticIncomingConnections, connection)
            watchedCount = watchedCount + 1
        end

        for _, descendant in ipairs(root:GetDescendants()) do
            attach(descendant)
        end
        automaticFolderConnection = root.DescendantAdded:Connect(attach)
        return watchedCount, true
    end

    frame, content = makeToolWindow("RemoteSpyWindow", "RemoteSpy", width, height, function()
        remoteSpyState.recording = false
        stopAutomaticIncomingWatch()
        if statusLabel then statusLabel.Text = "Stopped" end
        if startButton then startButton.Text = "Start" end
        frame.Visible = false
    end)
    remoteSpyWindow = frame

    local toolbar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 53,
    }, content)
    local compactToolbar = width < 520
    local searchWidth = compactToolbar and 58 or 170
    local apiWidth = compactToolbar and 34 or 42
    local clearWidth = compactToolbar and 44 or 56
    local startWidth = compactToolbar and 48 or 58
    local apiRight = searchWidth + 4
    local clearRight = apiRight + apiWidth + 4
    local startRight = clearRight + clearWidth + 4
    local toolbarRightWidth = startRight + startWidth
    statusLabel = createLabel(toolbar, "Stopped | test remotes only", UDim2.new(1, -(toolbarRightWidth + 8), 1, 0), UDim2.fromOffset(0, 0), 9, COLORS.Muted)
    statusLabel.ZIndex = 54
    startButton = createButton(toolbar, "Start", UDim2.fromOffset(startWidth, 30), UDim2.new(1, -toolbarRightWidth, 0, 0), function()
        if remoteSpyState.recording then
            remoteSpyState.recording = false
            stopAutomaticIncomingWatch()
            startButton.Text = "Start"
            statusLabel.Text = "Stopped"
        else
            remoteSpyState.recording = true
            local watchedCount, folderFound = watchOwnTestRemoteFolder()
            startButton.Text = "Stop"
            if folderFound then
                statusLabel.Text = "Recording | watching " .. tostring(watchedCount) .. " test RemoteEvent(s)"
            else
                statusLabel.Text = "Recording wrappers | test folder not found"
            end
        end
    end, COLORS.Green)
    startButton.ZIndex = 54
    clearButton = createButton(toolbar, "Clear", UDim2.fromOffset(clearWidth, 30), UDim2.new(1, -clearRight - clearWidth, 0, 0), function()
        remoteSpyState.groups = {}
        remoteSpyState.groupOrder = {}
        remoteSpyState.selectedKey = nil
        renderLeft()
        renderRight()
    end, COLORS.Panel2)
    clearButton.ZIndex = 54
    local helpButton = createButton(toolbar, "API", UDim2.fromOffset(apiWidth, 30), UDim2.new(1, -apiRight - apiWidth, 0, 0), function()
        logConsole("Info", "RemoteSpy test workflow: place your own test RemoteEvents under ReplicatedStorage.EasyScriptingRemotes, press Start to observe incoming events, and route outgoing calls through getgenv().EasyScriptingRemoteSpy.FireServer(remote, ...) or InvokeServer(remote, ...). For incoming callbacks use ConnectIncoming(remote, callback). This does not intercept ordinary calls in unrelated scripts or other experiences.")
    end, COLORS.Panel2)
    helpButton.ZIndex = 54
    local searchWrap = make("Frame", {
        Size = UDim2.fromOffset(searchWidth, 30),
        Position = UDim2.new(1, -searchWidth, 0, 0),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        ZIndex = 53,
    }, toolbar)
    addCorner(searchWrap, 6)
    searchBox = make("TextBox", {
        Size = UDim2.new(1, -8, 1, 0),
        Position = UDim2.fromOffset(5, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Find remotes...",
        ClearTextOnFocus = false,
        TextColor3 = COLORS.Text,
        PlaceholderColor3 = COLORS.Muted,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        ZIndex = 54,
    }, searchWrap)

    local split = width < 520 and 0.45 or 0.40
    local leftPanel = make("Frame", {
        Position = UDim2.fromOffset(0, 38),
        Size = UDim2.new(split, -5, 1, -38),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 52,
    }, content)
    addCorner(leftPanel, 7)
    local rightPanel = make("Frame", {
        Position = UDim2.new(split, 5, 0, 38),
        Size = UDim2.new(1 - split, -5, 1, -38),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 52,
    }, content)
    addCorner(rightPanel, 7)

    local tabs = make("Frame", {
        Size = UDim2.new(1, -10, 0, 30),
        Position = UDim2.fromOffset(5, 5),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        ZIndex = 53,
    }, leftPanel)
    addCorner(tabs, 6)
    local outgoingTab = createButton(tabs, "Outgoing", UDim2.new(0.5, -2, 1, 0), UDim2.fromOffset(0, 0), function()
        remoteSpyState.activeDirection = "Outgoing"
        renderLeft()
        renderRight()
    end, COLORS.Accent)
    outgoingTab.ZIndex = 54
    local incomingTab = createButton(tabs, "Incoming", UDim2.new(0.5, -2, 1, 0), UDim2.new(0.5, 2, 0, 0), function()
        remoteSpyState.activeDirection = "Incoming"
        renderLeft()
        renderRight()
    end, COLORS.Panel2)
    incomingTab.ZIndex = 54

    leftList = make("ScrollingFrame", {
        Position = UDim2.fromOffset(5, 40),
        Size = UDim2.new(1, -10, 1, -45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 7,
        ScrollBarImageColor3 = COLORS.Muted,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 53,
    }, leftPanel)
    local leftLayout = make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, leftList)
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        leftList.CanvasSize = UDim2.fromOffset(0, leftLayout.AbsoluteContentSize.Y + 8)
    end)

    local detailsTitle = createLabel(rightPanel, "  Call history", UDim2.new(1, -10, 0, 29), UDim2.fromOffset(5, 3), 11, COLORS.Text, Enum.Font.GothamBold)
    detailsTitle.ZIndex = 54
    rightList = make("ScrollingFrame", {
        Position = UDim2.fromOffset(5, 34),
        Size = UDim2.new(1, -10, 1, -39),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 7,
        ScrollBarImageColor3 = COLORS.Muted,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 53,
    }, rightPanel)
    local rightLayout = make("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, rightList)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        rightList.CanvasSize = UDim2.fromOffset(0, rightLayout.AbsoluteContentSize.Y + 8)
    end)

    local function clearList(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
        end
    end

    renderRight = function()
        clearList(rightList)
        local selected = remoteSpyState.selectedKey and remoteSpyState.groups[remoteSpyState.selectedKey]
        if not selected or selected.direction ~= remoteSpyState.activeDirection then
            detailsTitle.Text = "  Call history"
            local empty = createLabel(rightList, "Select a Remote on the left to inspect its calls.\n\nUse the EasyScriptingRemoteSpy API from your own test scripts to record outgoing and incoming calls.", UDim2.new(1, -14, 0, 90), UDim2.fromOffset(7, 8), 10, COLORS.Muted)
            empty.TextWrapped = true
            empty.TextYAlignment = Enum.TextYAlignment.Top
            empty.LayoutOrder = 1
            empty.ZIndex = 55
            return
        end
        detailsTitle.Text = "  " .. selected.name .. "  (x" .. tostring(selected.count) .. ")"
        for index, entry in ipairs(selected.history) do
            local lines = {
                "#" .. tostring(entry.activation) .. "    Time: " .. entry.time,
                "Method: " .. selected.method,
                "Source: " .. entry.source,
                "Arguments:",
            }
            if #entry.args == 0 then
                table.insert(lines, "  (no arguments)")
            else
                for _, arg in ipairs(entry.args) do
                    table.insert(lines, "  " .. tostring(arg.index) .. ". [" .. arg.valueType .. "] " .. arg.value)
                end
            end
            if #entry.results > 0 then
                table.insert(lines, "Returns:")
                for _, result in ipairs(entry.results) do
                    table.insert(lines, "  " .. tostring(result.index) .. ". [" .. result.valueType .. "] " .. result.value)
                end
            end
            local text = table.concat(lines, "\n")
            local lineCount = 0
            local charsPerLine = math.max(18, math.floor((rightList.AbsoluteSize.X - 34) / 6))
            for _, line in ipairs(lines) do
                lineCount = lineCount + math.max(1, math.ceil(#line / charsPerLine))
            end
            local cardHeight = math.max(102, 17 * lineCount + 22)
            local card = make("Frame", {
                Size = UDim2.new(1, -8, 0, cardHeight),
                BackgroundColor3 = COLORS.Panel2,
                BorderSizePixel = 0,
                LayoutOrder = index,
                ZIndex = 54,
            }, rightList)
            addCorner(card, 7)
            local cardText = createLabel(card, text, UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 6), 9, COLORS.Text, Enum.Font.Code)
            cardText.TextWrapped = true
            cardText.TextYAlignment = Enum.TextYAlignment.Top
            cardText.ZIndex = 55
        end
        rightList.CanvasPosition = Vector2.new(0, math.max(0, rightLayout.AbsoluteContentSize.Y - rightList.AbsoluteSize.Y))
    end

    renderLeft = function()
        clearList(leftList)
        outgoingTab.BackgroundColor3 = remoteSpyState.activeDirection == "Outgoing" and COLORS.Accent or COLORS.Panel2
        incomingTab.BackgroundColor3 = remoteSpyState.activeDirection == "Incoming" and COLORS.Accent or COLORS.Panel2
        local query = string.lower(searchBox.Text or "")
        local visibleGroups = {}
        for _, key in ipairs(remoteSpyState.groupOrder) do
            local group = remoteSpyState.groups[key]
            if group and group.direction == remoteSpyState.activeDirection then
                local searchable = string.lower(group.name .. " " .. group.path .. " " .. group.method)
                if query == "" or string.find(searchable, query, 1, true) then
                    table.insert(visibleGroups, group)
                end
            end
        end
        table.sort(visibleGroups, function(a, b)
            if a.count == b.count then return a.name:lower() < b.name:lower() end
            return a.count > b.count
        end)
        for index, group in ipairs(visibleGroups) do
            local row = make("TextButton", {
                Size = UDim2.new(1, -4, 0, 42),
                BackgroundColor3 = remoteSpyState.selectedKey == group.key and COLORS.PanelHover or COLORS.Panel2,
                BorderSizePixel = 0,
                Text = "",
                LayoutOrder = index,
                AutoButtonColor = true,
                ZIndex = 54,
            }, leftList)
            addCorner(row, 6)
            local badge = make("Frame", {
                Size = UDim2.fromOffset(24, 24),
                Position = UDim2.fromOffset(7, 9),
                BackgroundColor3 = group.direction == "Outgoing" and Color3.fromRGB(191, 123, 66) or Color3.fromRGB(79, 143, 190),
                BorderSizePixel = 0,
                ZIndex = 55,
            }, row)
            addCorner(badge, 5)
            local badgeLabel = createLabel(badge, group.remote:IsA("RemoteFunction") and "RF" or "RE", UDim2.fromScale(1, 1), UDim2.new(), 8, Color3.new(1, 1, 1), Enum.Font.GothamBold)
            badgeLabel.TextXAlignment = Enum.TextXAlignment.Center
            badgeLabel.ZIndex = 56
            local nameLabel = createLabel(row, group.name, UDim2.new(1, -88, 0, 18), UDim2.fromOffset(38, 4), 9, COLORS.Text, Enum.Font.GothamMedium)
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.ZIndex = 55
            local methodLabel = createLabel(row, group.method, UDim2.new(1, -88, 0, 15), UDim2.fromOffset(38, 22), 8, COLORS.Muted)
            methodLabel.TextTruncate = Enum.TextTruncate.AtEnd
            methodLabel.ZIndex = 55
            local countLabel = createLabel(row, "x" .. tostring(group.count), UDim2.fromOffset(43, 28), UDim2.new(1, -48, 0, 7), 10, COLORS.Text, Enum.Font.GothamBold)
            countLabel.TextXAlignment = Enum.TextXAlignment.Right
            countLabel.ZIndex = 55
            row.Activated:Connect(function()
                remoteSpyState.selectedKey = group.key
                renderLeft()
                renderRight()
            end)
        end
        if #visibleGroups == 0 then
            local empty = createLabel(leftList, "No recorded calls.\n\nIncoming: add your own RemoteEvents to ReplicatedStorage.EasyScriptingRemotes and press Start.\nOutgoing: use the EasyScriptingRemoteSpy API wrapper in your own test code.", UDim2.new(1, -14, 0, 112), UDim2.fromOffset(7, 8), 9, COLORS.Muted)
            empty.TextWrapped = true
            empty.TextYAlignment = Enum.TextYAlignment.Top
            empty.LayoutOrder = 1
            empty.ZIndex = 55
        end
    end

    remoteSpyState.onChanged = function()
        renderLeft()
        renderRight()
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        renderLeft()
    end)
    remoteSpyAPI = nil
    publishRemoteSpyAPI()
    renderLeft()
    renderRight()
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
    if freeCamStatus then freeCamStatus.Text = "FreeCam OFF - character remains in place" end
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

    if freeCamStatus then freeCamStatus.Text = "ON - WASD move - Q/E down/up - hold RMB to look - Shift faster" end
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
    frame, content = makeToolWindow("FreeCamWindow", "FreeCam - camera only", width, height, function()
        stopFreeCam()
        frame.Visible = false
    end)
    freeCamWindow = frame
    freeCamStatus = createLabel(content, "FreeCam OFF - character remains in place", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 0), 10, COLORS.Muted)
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
        createButton(content, "Yaw +", UDim2.fromOffset(50, 25), UDim2.fromOffset(190, 96), function()
            freeCam.yaw = freeCam.yaw + math.rad(15)
        end).ZIndex = 54
        createButton(content, "Yaw -", UDim2.fromOffset(50, 25), UDim2.fromOffset(190, 124), function()
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
            if file.autoExecute and isScriptFile(file.path) then
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
    if sharedEnvironment then
        pcall(function()
            if sharedEnvironment.EasyScriptingDex == dexAPI then
                sharedEnvironment.EasyScriptingDex = nil
            end
            if remoteSpyAPI and sharedEnvironment.EasyScriptingRemoteSpy == remoteSpyAPI then
                sharedEnvironment.EasyScriptingRemoteSpy = nil
            end
        end)
    end
end)

print("Easy Scripting " .. VERSION .. " loaded.")
