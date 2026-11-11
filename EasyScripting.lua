--[[
    Easy Scripting v0.5
    A compact Luau project workspace for personal projects and experiences
    you own or are explicitly allowed to test.

    Features
      - Projects home page and Execute page
      - Create, rename, delete, open, and locally save projects
      - GitHub-like project file/folder tree
      - Code editor with a mobile newline button
      - Syntax check in a separate, movable Console window
      - Tools menu with custom, reopenable Dex / RemoteSpy / FreeCam windows
      - Dex is intentionally limited to Workspace.EasyScriptingTestObjects
      - RemoteSpy is intentionally limited to
        ReplicatedStorage.EasyScriptingRemotes (incoming OnClientEvent only)
      - FreeCam moves the camera only; it does not move the character

    Notes
      - Project data is stored with executor file APIs when available.
      - Run Script means syntax validation only. Use Execute for code you wrote
        and are authorized to run.
      - Executor APIs differ. File APIs and loadstring may be unavailable.
      - This is a prototype; test it only in an experience you own or have
        permission to inspect.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then
    warn("Easy Scripting: LocalPlayer is not available.")
    return
end

local APP_NAME = "EasyScripting"
local GUI_NAME = "EasyScriptingGui"
local DATA_FOLDER = "EasyScripting"
local DATA_FILE = DATA_FOLDER .. "/projects.json"

local C = {
    bg = Color3.fromRGB(18, 20, 27),
    panel = Color3.fromRGB(25, 28, 37),
    panel2 = Color3.fromRGB(33, 37, 49),
    hover = Color3.fromRGB(45, 51, 66),
    border = Color3.fromRGB(58, 65, 82),
    text = Color3.fromRGB(237, 240, 247),
    muted = Color3.fromRGB(151, 160, 179),
    accent = Color3.fromRGB(105, 145, 255),
    green = Color3.fromRGB(89, 205, 139),
    red = Color3.fromRGB(244, 103, 112),
    yellow = Color3.fromRGB(242, 190, 91),
    blue = Color3.fromRGB(107, 177, 255),
}

local function new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end

local function stroke(object, color, transparency)
    new("UIStroke", {
        Color = color or C.border,
        Thickness = 1,
        Transparency = transparency or 0,
    }, object)
end

local function label(parent, text, size, position, textSize, color, font)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Size = size,
        Position = position,
        Text = text or "",
        TextColor3 = color or C.text,
        TextSize = textSize or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
    }, parent)
end

local function button(parent, text, size, position, callback, background)
    local object = new("TextButton", {
        Size = size,
        Position = position,
        BackgroundColor3 = background or C.panel2,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = C.text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = true,
    }, parent)
    corner(object, 7)
    object.Activated:Connect(function()
        if callback then
            callback()
        end
    end)
    return object
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPosition = target.Position
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

local function setTextColor(object, color)
    if object and object.Parent then
        object.TextColor3 = color
    end
end

local function trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function byteSize(text)
    local bytes = #(text or "")
    if bytes < 1024 then return tostring(bytes) .. " B" end
    if bytes < 1024 * 1024 then return string.format("%.1f KB", bytes / 1024) end
    return string.format("%.2f MB", bytes / (1024 * 1024))
end

local function safeCall(fn, ...)
    local args = table.pack(...)
    return pcall(function()
        return fn(table.unpack(args, 1, args.n))
    end)
end

-- GUI parent selection. This only chooses where the UI is displayed.
local guiParent
local parentOk, parentValue = pcall(function()
    if type(gethui) == "function" then
        return gethui()
    end
    return game:GetService("CoreGui")
end)
if parentOk and parentValue then
    guiParent = parentValue
else
    guiParent = player:WaitForChild("PlayerGui")
end

pcall(function()
    local old = guiParent:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

local screenGui = new("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 900,
}, guiParent)

local touch = UserInputService.TouchEnabled
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local minWidth = touch and 300 or 370
local maxWidth = touch and 440 or 620
local width = math.clamp(viewport.X - (touch and 18 or 40), minWidth, maxWidth)
local minHeight = touch and 300 or 350
local maxHeight = touch and 460 or 500
local height = math.clamp(viewport.Y - (touch and 90 or 80), minHeight, maxHeight)

local main = new("Frame", {
    Name = "MainWindow",
    Size = UDim2.fromOffset(width, height),
    Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, screenGui)
corner(main, 12)
stroke(main)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 43),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
label(header, "  Easy Scripting", UDim2.new(1, -150, 1, 0), UDim2.fromOffset(7, 0), 15, C.text, Enum.Font.GothamBold)
local headerContext = label(header, "HOME", UDim2.fromOffset(105, 20), UDim2.new(1, -145, 0, 11), 9, C.muted)
headerContext.TextXAlignment = Enum.TextXAlignment.Right
local closeMain = button(header, "×", UDim2.fromOffset(30, 28), UDim2.new(1, -36, 0, 7), function()
    screenGui:Destroy()
end)
closeMain.TextSize = 18
makeDraggable(header, main)

local body = new("Frame", {
    Position = UDim2.fromOffset(0, 43),
    Size = UDim2.new(1, 0, 1, -43),
    BackgroundTransparency = 1,
}, main)

-- Project data ---------------------------------------------------------------
local projects = {}
local currentProject
local selectedFilePath
local fileStorageAvailable = type(readfile) == "function" and type(writefile) == "function"

local function ensureStorageFolder()
    if type(isfolder) == "function" then
        local ok, exists = safeCall(isfolder, DATA_FOLDER)
        if ok and exists then return end
    end
    if type(makefolder) == "function" then
        safeCall(makefolder, DATA_FOLDER)
    end
end

local function getFile(project, path)
    if not project or type(project.files) ~= "table" then return nil end
    for _, item in ipairs(project.files) do
        if item.path == path then return item end
    end
    return nil
end

local function normalizePath(path)
    path = tostring(path or ""):gsub("\\", "/")
    path = path:gsub("^/+", ""):gsub("/+$", "")
    if path == "" or path:find("..", 1, true) or path:find("//", 1, true) then
        return nil
    end
    return path
end

local function ensureProject(project)
    if type(project.files) ~= "table" then project.files = {} end
    if type(project.folders) ~= "table" then project.folders = {} end
    if #project.files == 0 then
        table.insert(project.files, {path = "main.lua", code = "", autoExecute = false})
    end
    for _, file in ipairs(project.files) do
        if type(file.code) ~= "string" then file.code = "" end
        if type(file.autoExecute) ~= "boolean" then file.autoExecute = false end
    end
    if not getFile(project, project.activeFile or "") then
        project.activeFile = project.files[1].path
    end
end

local function saveProjects()
    if not fileStorageAvailable then
        return false, "Executor file APIs are unavailable; projects will last only until this session ends."
    end
    ensureStorageFolder()
    local encodeOk, encoded = pcall(function()
        return HttpService:JSONEncode(projects)
    end)
    if not encodeOk then
        return false, "Could not encode project data: " .. tostring(encoded)
    end
    local writeOk, writeError = safeCall(writefile, DATA_FILE, encoded)
    if not writeOk then
        return false, "Could not write project data: " .. tostring(writeError)
    end
    return true, "Saved."
end

local function loadProjects()
    if not fileStorageAvailable then return end
    ensureStorageFolder()
    local exists = false
    if type(isfile) == "function" then
        local ok, result = safeCall(isfile, DATA_FILE)
        exists = ok and result == true
    else
        local ok = safeCall(readfile, DATA_FILE)
        exists = ok
    end
    if not exists then return end

    local readOk, raw = safeCall(readfile, DATA_FILE)
    if not readOk or type(raw) ~= "string" then return end
    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not decodeOk or type(decoded) ~= "table" then
        warn("Easy Scripting: saved project data is invalid JSON.")
        return
    end

    for _, saved in ipairs(decoded) do
        if type(saved) == "table" and type(saved.name) == "string" then
            local p = {
                id = tostring(saved.id or (os.time() .. "_" .. math.random(1000, 9999))),
                name = saved.name,
                files = {},
                folders = type(saved.folders) == "table" and saved.folders or {},
                activeFile = type(saved.activeFile) == "string" and saved.activeFile or "main.lua",
                updated = tonumber(saved.updated) or os.time(),
            }
            if type(saved.files) == "table" then
                for _, f in ipairs(saved.files) do
                    if type(f) == "table" and type(f.path) == "string" then
                        table.insert(p.files, {
                            path = f.path,
                            code = type(f.code) == "string" and f.code or "",
                            autoExecute = f.autoExecute == true,
                        })
                    end
                end
            end
            if #p.files == 0 then
                table.insert(p.files, {path = "main.lua", code = type(saved.code) == "string" and saved.code or "", autoExecute = false})
            end
            ensureProject(p)
            table.insert(projects, p)
        end
    end
end

local function projectBytes(project)
    ensureProject(project)
    local total = 0
    for _, file in ipairs(project.files) do
        total += #file.path + #file.code
    end
    for _, folder in ipairs(project.folders) do total += #tostring(folder) end
    return byteSize(total)
end

-- Console --------------------------------------------------------------------
local consoleEntries = {}
local consoleWindow
local consoleList
local consoleSummary
local editorBox
local editorStatus

local function extractLine(message)
    if type(message) ~= "string" then return nil end
    return tonumber(message:match(":(%d+):") or message:match("line%s+(%d+)") or message:match("Line%s+(%d+)"))
end

local function jumpToLine(line)
    if not editorBox or not line or line < 1 then return end
    local source = editorBox.Text or ""
    local cursor = 1
    for _ = 1, line - 1 do
        local nextLine = string.find(source, "\n", cursor, true)
        if not nextLine then cursor = #source + 1 break end
        cursor = nextLine + 1
    end
    local lineEnd = string.find(source, "\n", cursor, true) or (#source + 1)
    editorBox:CaptureFocus()
    editorBox.SelectionStart = cursor
    editorBox.CursorPosition = math.max(cursor, lineEnd)
end

local function renderConsole()
    if not consoleList then return end
    for _, child in ipairs(consoleList:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
    end

    local errors, warnings = 0, 0
    for _, entry in ipairs(consoleEntries) do
        if entry.kind == "Error" then errors += 1 end
        if entry.kind == "Warning" then warnings += 1 end
    end
    if consoleSummary then
        consoleSummary.Text = string.format("%d errors  ·  %d warnings  ·  %d messages", errors, warnings, #consoleEntries)
    end

    for index, entry in ipairs(consoleEntries) do
        local color = C.blue
        local tag = "INFO"
        if entry.kind == "Error" then color, tag = C.red, "ERROR" end
        if entry.kind == "Warning" then color, tag = C.yellow, "WARN" end
        if entry.kind == "Success" then color, tag = C.green, "OK" end
        local rowHeight = entry.line and 55 or 38
        local row = new("TextButton", {
            Size = UDim2.new(1, -6, 0, rowHeight),
            BackgroundColor3 = C.panel2,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = entry.line ~= nil,
            LayoutOrder = index,
        }, consoleList)
        corner(row, 6)
        label(row, tag, UDim2.fromOffset(48, 16), UDim2.fromOffset(8, 3), 9, color, Enum.Font.GothamBold)
        local timeLabel = label(row, entry.time, UDim2.fromOffset(55, 16), UDim2.new(1, -63, 0, 3), 9, C.muted)
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right
        local messageLabel = label(row, entry.message, UDim2.new(1, -16, 0, entry.line and 18 or 20), UDim2.fromOffset(8, 20), 10, C.text)
        messageLabel.TextWrapped = true
        messageLabel.TextYAlignment = Enum.TextYAlignment.Top
        if entry.line then
            local lineLabel = label(row, "Click to go to line " .. tostring(entry.line), UDim2.new(1, -16, 0, 14), UDim2.fromOffset(8, 39), 9, C.accent)
            if entry.line then
                row.Activated:Connect(function() jumpToLine(entry.line) end)
            end
        end
    end
    local layout = consoleList:FindFirstChildOfClass("UIListLayout")
    if layout then consoleList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 6) end
end

local function log(kind, message, line)
    table.insert(consoleEntries, {
        kind = kind,
        message = tostring(message),
        line = line,
        time = os.date("%H:%M:%S"),
    })
    if #consoleEntries > 250 then table.remove(consoleEntries, 1) end
    renderConsole()
end

local function openConsole()
    if consoleWindow then
        consoleWindow.Visible = true
        renderConsole()
        return
    end
    local w = math.min(430, width - 24)
    local h = math.min(300, height - 80)
    consoleWindow = new("Frame", {
        Name = "ConsoleWindow",
        Size = UDim2.fromOffset(w, h),
        Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        ZIndex = 30,
    }, screenGui)
    corner(consoleWindow, 10)
    stroke(consoleWindow)
    local bar = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 31}, consoleWindow)
    corner(bar, 10)
    label(bar, "  Console", UDim2.new(1, -120, 1, 0), UDim2.fromOffset(6, 0), 13, C.text, Enum.Font.GothamBold).ZIndex = 32
    local clear = button(bar, "Clear", UDim2.fromOffset(48, 24), UDim2.new(1, -88, 0, 7), function()
        consoleEntries = {}
        renderConsole()
    end)
    clear.ZIndex = 32
    local close = button(bar, "×", UDim2.fromOffset(26, 24), UDim2.new(1, -32, 0, 7), function()
        consoleWindow.Visible = false
    end)
    close.TextSize = 17
    close.ZIndex = 32

    consoleSummary = label(consoleWindow, "0 errors  ·  0 warnings  ·  0 messages", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 40), 9, C.muted)
    consoleSummary.ZIndex = 31
    consoleList = new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 64),
        Size = UDim2.new(1, -16, 1, -72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 31,
    }, consoleWindow)
    local layout = new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, consoleList)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if consoleList then consoleList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 6) end
    end)
    makeDraggable(bar, consoleWindow)
    renderConsole()
end

-- Tool windows ---------------------------------------------------------------
local function toolWindow(name, title, w, h)
    local frame = new("Frame", {
        Name = name,
        Size = UDim2.fromOffset(w, h),
        Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        ZIndex = 40,
    }, screenGui)
    corner(frame, 10)
    stroke(frame)
    local bar = new("Frame", {Size = UDim2.new(1, 0, 0, 37), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 41}, frame)
    corner(bar, 10)
    label(bar, "  " .. title, UDim2.new(1, -48, 1, 0), UDim2.fromOffset(5, 0), 12, C.text, Enum.Font.GothamBold).ZIndex = 42
    local close = button(bar, "×", UDim2.fromOffset(27, 25), UDim2.new(1, -33, 0, 6), function()
        frame.Visible = false
    end)
    close.TextSize = 17
    close.ZIndex = 42
    local content = new("Frame", {
        Position = UDim2.fromOffset(8, 43),
        Size = UDim2.new(1, -16, 1, -51),
        BackgroundTransparency = 1,
        ZIndex = 41,
    }, frame)
    makeDraggable(bar, frame)
    return frame, content
end

-- Dex: read-only view of the project's own test folder only.
local dexWindow
local function openDex()
    if dexWindow then dexWindow.Visible = true return end
    local w = math.min(440, width - 12)
    local h = math.min(330, height - 55)
    local content
    dexWindow, content = toolWindow("DexWindow", "Dex Explorer · test folder only", w, h)

    local testFolder = workspace:FindFirstChild("EasyScriptingTestObjects")
    local refresh = button(content, "Refresh", UDim2.fromOffset(64, 24), UDim2.new(1, -64, 0, 0), nil)
    refresh.ZIndex = 43
    local tree = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 30),
        Size = UDim2.new(0.58, -5, 1, -30),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 42,
    }, content)
    corner(tree, 7)
    local details = new("TextLabel", {
        Position = UDim2.new(0.58, 5, 0, 30),
        Size = UDim2.new(0.42, -5, 1, -30),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Text = "Select an object.",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.Code,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 42,
    }, content)
    corner(details, 7)
    local treeLayout = new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, tree)
    treeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tree.CanvasSize = UDim2.fromOffset(0, treeLayout.AbsoluteContentSize.Y + 6)
    end)

    local selected
    local expanded = {}
    local function describe(object)
        if not object then details.Text = "No object selected." return end
        local lines = {
            "Name: " .. object.Name,
            "Class: " .. object.ClassName,
            "Parent: " .. (object.Parent and object.Parent.Name or "nil"),
            "Children: " .. tostring(#object:GetChildren()),
        }
        if object:IsA("BasePart") then
            local p = object.Position
            local s = object.Size
            lines[#lines + 1] = string.format("Position: %.2f, %.2f, %.2f", p.X, p.Y, p.Z)
            lines[#lines + 1] = string.format("Size: %.2f, %.2f, %.2f", s.X, s.Y, s.Z)
        elseif object:IsA("ValueBase") then
            lines[#lines + 1] = "Value: " .. tostring(object.Value)
        end
        details.Text = table.concat(lines, "\n\n")
    end

    local function drawTree()
        for _, child in ipairs(tree:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
        end
        testFolder = workspace:FindFirstChild("EasyScriptingTestObjects")
        if not testFolder then
            local note = label(tree, "Create Workspace.EasyScriptingTestObjects to inspect your own test objects.", UDim2.new(1, -8, 0, 60), UDim2.fromOffset(4, 4), 10, C.muted)
            note.TextWrapped = true
            note.TextYAlignment = Enum.TextYAlignment.Top
            return
        end
        local order = 0
        local function addNode(object, depth)
            order += 1
            local children = object:GetChildren()
            table.sort(children, function(a, b) return a.Name:lower() < b.Name:lower() end)
            local prefix = #children > 0 and (expanded[object] and "▼ " or "▶ ") or "• "
            local row = button(tree, string.rep("  ", math.min(depth, 5)) .. prefix .. object.Name .. "  [" .. object.ClassName .. "]",
                UDim2.new(1, -6, 0, 24), UDim2.new(), function()
                    selected = object
                    if #children > 0 then expanded[object] = not expanded[object] end
                    describe(object)
                    drawTree()
                end, object == selected and C.hover or C.panel2)
            row.LayoutOrder = order
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 9
            row.Font = Enum.Font.Code
            if expanded[object] then
                for _, child in ipairs(children) do addNode(child, depth + 1) end
            end
        end
        addNode(testFolder, 0)
    end
    refresh.Activated:Connect(function() drawTree() end)
    drawTree()
end

-- RemoteSpy: incoming events only, from a dedicated test folder.
local remoteWindow
local remoteConnectionList = {}
local remoteActive = false
local function disconnectRemoteListeners()
    remoteActive = false
    for _, connection in ipairs(remoteConnectionList) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(remoteConnectionList)
end

local function openRemoteSpy()
    if remoteWindow then remoteWindow.Visible = true return end
    local w = math.min(440, width - 12)
    local h = math.min(330, height - 55)
    local content
    remoteWindow, content = toolWindow("RemoteSpyWindow", "RemoteSpy · own test remotes", w, h)
    local status = label(content, "Stopped · test remotes only", UDim2.new(1, -135, 0, 25), UDim2.fromOffset(0, 0), 9, C.muted)
    local output = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 1, -34),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.fromOffset(0, 0),
    }, content)
    corner(output, 7)
    local layout = new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, output)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        output.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 6)
    end)
    local entries = {}

    local function render()
        for _, child in ipairs(output:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
        end
        for index, entry in ipairs(entries) do
            local line = label(output, "[" .. entry.time .. "] " .. entry.name .. "\n" .. entry.args,
                UDim2.new(1, -8, 0, 44), UDim2.new(), 10, C.text, Enum.Font.Code)
            line.BackgroundColor3 = C.panel2
            line.BackgroundTransparency = 0
            line.TextWrapped = true
            line.LayoutOrder = index
            corner(line, 5)
        end
    end

    local function formatArguments(...)
        local args = table.pack(...)
        local parts = {}
        for index = 1, math.min(args.n, 8) do
            local value = args[index]
            local valueType = typeof(value)
            local representation
            if valueType == "Instance" then
                representation = value:GetFullName()
            elseif valueType == "string" then
                representation = string.format("%q", string.sub(value, 1, 100))
            else
                representation = tostring(value)
            end
            table.insert(parts, valueType .. ": " .. representation)
        end
        if args.n > 8 then table.insert(parts, "…") end
        return #parts == 0 and "(no arguments)" or table.concat(parts, " | ")
    end

    local startStop
    startStop = button(content, "Start", UDim2.fromOffset(60, 25), UDim2.new(1, -128, 0, 0), function()
        if remoteActive then
            disconnectRemoteListeners()
            status.Text = "Stopped"
            startStop.Text = "Start"
            return
        end
        disconnectRemoteListeners()
        local folder = ReplicatedStorage:FindFirstChild("EasyScriptingRemotes")
        if not folder then
            status.Text = "Create ReplicatedStorage.EasyScriptingRemotes first"
            return
        end
        remoteActive = true
        local count = 0
        for _, item in ipairs(folder:GetDescendants()) do
            if item:IsA("RemoteEvent") then
                count += 1
                local connection = item.OnClientEvent:Connect(function(...)
                    if not remoteActive then return end
                    table.insert(entries, {
                        time = os.date("%H:%M:%S"),
                        name = item.Name,
                        args = formatArguments(...),
                    })
                    if #entries > 100 then table.remove(entries, 1) end
                    render()
                end)
                table.insert(remoteConnectionList, connection)
            end
        end
        status.Text = "Listening to " .. tostring(count) .. " RemoteEvent(s)"
        startStop.Text = "Stop"
    end, C.green)
    local clear = button(content, "Clear", UDim2.fromOffset(55, 25), UDim2.new(1, -62, 0, 0), function()
        entries = {}
        render()
    end)
    startStop.ZIndex = 45
    clear.ZIndex = 45
    remoteWindow:GetPropertyChangedSignal("Visible"):Connect(function()
        if not remoteWindow.Visible then
            disconnectRemoteListeners()
            startStop.Text = "Start"
            status.Text = "Stopped"
        end
    end)
end

-- FreeCam: camera movement only; no character root-part movement.
local freeCamWindow
local freeCamEnabled = false
local freeCamStatus
local freeCamToggle
local freeCamSpeed = 28
local freeCamKeys = {}
local freeCamConnections = {}
local freeCamControls
local oldCameraType
local oldCameraSubject
local oldMouseBehavior
local oldMouseIconEnabled
local yaw, pitch = 0, 0
local looking = false

local function disconnectFreeCam()
    for _, connection in ipairs(freeCamConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(freeCamConnections)
end

local function stopFreeCam()
    if not freeCamEnabled then return end
    freeCamEnabled = false
    table.clear(freeCamKeys)
    looking = false
    disconnectFreeCam()
    if freeCamControls then
        pcall(function() freeCamControls:Enable() end)
        freeCamControls = nil
    end
    local currentCamera = workspace.CurrentCamera
    if currentCamera then
        pcall(function()
            currentCamera.CameraType = oldCameraType or Enum.CameraType.Custom
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            currentCamera.CameraSubject = oldCameraSubject or humanoid
        end)
    end
    pcall(function()
        UserInputService.MouseBehavior = oldMouseBehavior or Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = oldMouseIconEnabled ~= false
    end)
    if freeCamStatus then freeCamStatus.Text = "OFF · camera restored; character was not moved" end
    if freeCamToggle then freeCamToggle.Text = "Start FreeCam" end
end

local function startFreeCam()
    local currentCamera = workspace.CurrentCamera
    if not currentCamera or freeCamEnabled then return end
    oldCameraType = currentCamera.CameraType
    oldCameraSubject = currentCamera.CameraSubject
    oldMouseBehavior = UserInputService.MouseBehavior
    oldMouseIconEnabled = UserInputService.MouseIconEnabled

    -- Disable default player controls when the standard PlayerModule is available.
    local controlsOk, controls = pcall(function()
        local scripts = player:FindFirstChild("PlayerScripts")
        local moduleScript = scripts and scripts:FindFirstChild("PlayerModule")
        if not moduleScript then return nil end
        local module = require(moduleScript)
        return module:GetControls()
    end)
    if controlsOk and controls then
        freeCamControls = controls
        pcall(function() freeCamControls:Disable() end)
    end

    local look = currentCamera.CFrame.LookVector
    yaw = math.atan2(-look.X, -look.Z)
    pitch = math.asin(math.clamp(look.Y, -1, 1))
    freeCamEnabled = true
    currentCamera.CameraType = Enum.CameraType.Scriptable

    table.insert(freeCamConnections, UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            looking = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            UserInputService.MouseIconEnabled = false
            return
        end
        if processed or UserInputService:GetFocusedTextBox() then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S
            or key == Enum.KeyCode.D or key == Enum.KeyCode.Q or key == Enum.KeyCode.E
            or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
            freeCamKeys[key] = true
        end
    end))

    table.insert(freeCamConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            looking = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
        freeCamKeys[input.KeyCode] = nil
    end))

    table.insert(freeCamConnections, UserInputService.InputChanged:Connect(function(input)
        if freeCamEnabled and looking and input.UserInputType == Enum.UserInputType.MouseMovement then
            yaw -= input.Delta.X * 0.0025
            pitch = math.clamp(pitch - input.Delta.Y * 0.0025, math.rad(-85), math.rad(85))
        end
    end))

    table.insert(freeCamConnections, RunService.RenderStepped:Connect(function(dt)
        if not freeCamEnabled then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local x = (freeCamKeys[Enum.KeyCode.D] and 1 or 0) - (freeCamKeys[Enum.KeyCode.A] and 1 or 0)
        local y = (freeCamKeys[Enum.KeyCode.E] and 1 or 0) - (freeCamKeys[Enum.KeyCode.Q] and 1 or 0)
        local z = (freeCamKeys[Enum.KeyCode.W] and 1 or 0) - (freeCamKeys[Enum.KeyCode.S] and 1 or 0)
        local rotation = CFrame.fromOrientation(pitch, yaw, 0)
        local movement = rotation:VectorToWorldSpace(Vector3.new(x, y, -z))
        local position = cam.CFrame.Position
        if movement.Magnitude > 0 then
            local speed = freeCamSpeed
            if freeCamKeys[Enum.KeyCode.LeftShift] or freeCamKeys[Enum.KeyCode.RightShift] then speed *= 2.5 end
            position += movement.Unit * speed * dt
        end
        cam.CFrame = CFrame.new(position) * rotation
    end))

    if freeCamStatus then freeCamStatus.Text = "ON · WASD move · Q/E down/up · hold RMB to look · Shift faster" end
    if freeCamToggle then freeCamToggle.Text = "Stop FreeCam" end
end

local function openFreeCam()
    if freeCamWindow then freeCamWindow.Visible = true return end
    local w = math.min(380, width - 20)
    local h = touch and 250 or 190
    local content
    freeCamWindow, content = toolWindow("FreeCamWindow", "FreeCam · camera only", w, h)
    freeCamStatus = label(content, "OFF · character stays at its current position", UDim2.new(1, 0, 0, 38), UDim2.fromOffset(0, 0), 10, C.muted)
    freeCamStatus.TextWrapped = true

    label(content, "Speed", UDim2.fromOffset(45, 26), UDim2.fromOffset(0, 44), 10, C.text)
    local speedBox = new("TextBox", {
        Size = UDim2.fromOffset(70, 27),
        Position = UDim2.fromOffset(50, 43),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        Text = tostring(freeCamSpeed),
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
    }, content)
    corner(speedBox, 6)
    speedBox.FocusLost:Connect(function()
        local value = tonumber(speedBox.Text)
        if value then freeCamSpeed = math.clamp(value, 4, 150) end
        speedBox.Text = tostring(freeCamSpeed)
    end)

    if touch then
        label(content, "Touch movement", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 76), 9, C.muted)
        local function holdButton(text, key, x, y)
            local hold = button(content, text, UDim2.fromOffset(40, 24), UDim2.fromOffset(x, y), nil)
            hold.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    freeCamKeys[key] = true
                end
            end)
            hold.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    freeCamKeys[key] = nil
                end
            end)
        end
        holdButton("W", Enum.KeyCode.W, 44, 96)
        holdButton("A", Enum.KeyCode.A, 0, 122)
        holdButton("S", Enum.KeyCode.S, 44, 122)
        holdButton("D", Enum.KeyCode.D, 88, 122)
        holdButton("UP", Enum.KeyCode.E, 140, 96)
        holdButton("DOWN", Enum.KeyCode.Q, 140, 122)
        button(content, "↶", UDim2.fromOffset(36, 24), UDim2.fromOffset(194, 96), function() yaw += math.rad(15) end)
        button(content, "↷", UDim2.fromOffset(36, 24), UDim2.fromOffset(194, 122), function() yaw -= math.rad(15) end)
    end

    freeCamToggle = button(content, "Start FreeCam", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 1, -34), function()
        if freeCamEnabled then stopFreeCam() else startFreeCam() end
    end, C.accent)
    freeCamWindow:GetPropertyChangedSignal("Visible"):Connect(function()
        if not freeCamWindow.Visible then stopFreeCam() end
    end)
end

-- Main pages -----------------------------------------------------------------
local toolsMenu
local refreshProjects
local showProjects
local projectsPage = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, body)
local executePage = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, body)
local editorPage = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, body)

local projectsTab = button(projectsPage, "Projects", UDim2.fromOffset(112, 32), UDim2.fromOffset(12, 8), nil, C.hover)
local executeTab = button(projectsPage, "Execute", UDim2.fromOffset(112, 32), UDim2.new(1, -124, 0, 8), nil)

label(projectsPage, "Saved projects", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(14, 47), 12, C.muted, Enum.Font.GothamMedium)
local projectList = new("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 73),
    Size = UDim2.new(1, -24, 1, -130),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 0),
}, projectsPage)
local projectLayout = new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, projectList)
projectLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    projectList.CanvasSize = UDim2.fromOffset(0, projectLayout.AbsoluteContentSize.Y + 8)
end)

local editorToolbar = new("Frame", {Size = UDim2.new(1, -18, 0, 38), Position = UDim2.fromOffset(9, 5), BackgroundTransparency = 1}, editorPage)
local editorSurface = new("Frame", {
    Position = UDim2.fromOffset(9, 49),
    Size = UDim2.new(1, -18, 1, -78),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, editorPage)
corner(editorSurface, 8)
stroke(editorSurface, C.border, 0.55)

local treeWidth = touch and 91 or 116
local filePanel = new("Frame", {
    Position = UDim2.fromOffset(6, 6),
    Size = UDim2.new(0, treeWidth, 1, -12),
    BackgroundColor3 = C.panel2,
    BorderSizePixel = 0,
}, editorSurface)
corner(filePanel, 6)
label(filePanel, "FILES", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(5, 2), 9, C.muted, Enum.Font.GothamBold)
local addFileButton = button(filePanel, "+ File", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 22), nil)
addFileButton.TextSize = 9
local addFolderButton = button(filePanel, "+ Folder", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 47), nil)
addFolderButton.TextSize = 9
local deleteFileButton = button(filePanel, "Delete", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 72), nil)
deleteFileButton.TextSize = 9
local fileTree = new("ScrollingFrame", {
    Position = UDim2.fromOffset(4, 100),
    Size = UDim2.new(1, -8, 1, -104),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.fromOffset(0, 0),
}, filePanel)
local fileTreeLayout = new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, fileTree)
fileTreeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    fileTree.CanvasSize = UDim2.fromOffset(0, fileTreeLayout.AbsoluteContentSize.Y + 5)
end)

local codePanel = new("Frame", {
    Position = UDim2.fromOffset(treeWidth + 12, 0),
    Size = UDim2.new(1, -(treeWidth + 18), 1, 0),
    BackgroundTransparency = 1,
}, editorSurface)
local activeFileLabel = label(codePanel, "main.lua", UDim2.new(1, -42, 0, 25), UDim2.fromOffset(3, 3), 10, C.muted, Enum.Font.GothamBold)
local newlineButton = button(codePanel, "↵", UDim2.fromOffset(32, 23), UDim2.new(1, -35, 0, 4), nil)
newlineButton.TextSize = 14
editorBox = new("TextBox", {
    Position = UDim2.fromOffset(3, 31),
    Size = UDim2.new(1, -6, 1, -35),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "-- Write your Luau code here...",
    PlaceholderColor3 = C.muted,
    TextColor3 = C.text,
    TextSize = touch and 11 or 12,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = false,
    MultiLine = true,
    ClearTextOnFocus = false,
}, codePanel)
editorStatus = label(editorPage, "Ready", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 1, -23), 9, C.muted)

-- Editor toolbar buttons are visible only when a project is open.
local compact = touch or width < 440
local backW = compact and 27 or 34
local toolsW = compact and 51 or 75
local checkW = compact and 61 or 87
local saveW = compact and 42 or 55
local consoleW = compact and 53 or 66
local gap = 3
local x = 0
button(editorToolbar, "←", UDim2.fromOffset(backW, 30), UDim2.fromOffset(x, 4), function()
    if currentProject then
        local active = getFile(currentProject, selectedFilePath or currentProject.activeFile)
        if active then active.code = editorBox.Text end
        currentProject.activeFile = selectedFilePath or currentProject.activeFile
        saveProjects()
    end
    editorPage.Visible = false
    projectsPage.Visible = true
    headerContext.Text = "HOME"
    if toolsMenu then toolsMenu.Visible = false end
    refreshProjects()
end)
x += backW + gap
local toolsButton
local checkButton
local saveButton
local consoleButton

toolsButton = button(editorToolbar, "Tools", UDim2.fromOffset(toolsW, 30), UDim2.fromOffset(x, 4), function()
    if toolsMenu then toolsMenu.Visible = not toolsMenu.Visible end
end)
x += toolsW + gap
checkButton = button(editorToolbar, compact and "Run" or "Run Script", UDim2.fromOffset(checkW, 30), UDim2.fromOffset(x, 4), function()
    if not currentProject then return end
    local file = getFile(currentProject, selectedFilePath)
    if file then file.code = editorBox.Text end
    local source = editorBox.Text or ""
    if source:gsub("%s", "") == "" then
        log("Warning", "The current file is empty.")
        editorStatus.Text = "Empty file"
        setTextColor(editorStatus, C.yellow)
        openConsole()
        return
    end
    if type(loadstring) ~= "function" then
        log("Error", "loadstring is unavailable; this environment cannot compile-check the code.")
        editorStatus.Text = "Syntax check unavailable"
        setTextColor(editorStatus, C.red)
        openConsole()
        return
    end
    local callOk, compiled, compileError = pcall(loadstring, source, "@" .. (selectedFilePath or "main.lua"))
    if callOk and type(compiled) == "function" then
        log("Success", "No syntax errors detected. The script was not executed.")
        editorStatus.Text = "Syntax check passed · not executed"
        setTextColor(editorStatus, C.green)
    else
        local message = tostring(callOk and compileError or compiled)
        log("Error", message, extractLine(message))
        editorStatus.Text = "Syntax check failed"
        setTextColor(editorStatus, C.red)
    end
    openConsole()
end, C.panel2)
x += checkW + gap
saveButton = button(editorToolbar, "Save", UDim2.fromOffset(saveW, 30), UDim2.fromOffset(x, 4), function()
    if not currentProject then return end
    local file = getFile(currentProject, selectedFilePath)
    if file then file.code = editorBox.Text end
    currentProject.activeFile = selectedFilePath or currentProject.activeFile
    currentProject.updated = os.time()
    local ok, message = saveProjects()
    if ok then
        editorStatus.Text = "Saved · " .. projectBytes(currentProject)
        setTextColor(editorStatus, C.green)
        log("Success", "Project saved.")
    else
        editorStatus.Text = "Not saved to disk"
        setTextColor(editorStatus, C.yellow)
        log("Warning", message)
    end
end)
x += saveW + gap
consoleButton = button(editorToolbar, "Console", UDim2.fromOffset(consoleW, 30), UDim2.fromOffset(x, 4), openConsole)
if compact then
    checkButton.TextSize = 10
    toolsButton.TextSize = 10
    saveButton.TextSize = 10
    consoleButton.TextSize = 9
end

-- File tree / project editor --------------------------------------------------
local expandedFolders = {}
local function pathSegments(path)
    local result = {}
    for segment in tostring(path):gmatch("[^/]+") do table.insert(result, segment) end
    return result
end

local function makeTreeRows(project)
    local folders = {}
    local filesByPath = {}
    for _, folder in ipairs(project.folders) do
        local path = normalizePath(folder)
        if path then folders[path] = true end
    end
    for _, file in ipairs(project.files) do
        local parts = pathSegments(file.path)
        local current = ""
        for index = 1, #parts - 1 do
            current = current == "" and parts[index] or current .. "/" .. parts[index]
            folders[current] = true
        end
        filesByPath[file.path] = file
    end
    local rows = {}
    for path in pairs(folders) do
        local parts = pathSegments(path)
        local parentPath = ""
        if #parts > 1 then parentPath = table.concat(parts, "/", 1, #parts - 1) end
        table.insert(rows, {path = path, name = parts[#parts], parent = parentPath, depth = #parts - 1, folder = true})
    end
    for path, file in pairs(filesByPath) do
        local parts = pathSegments(path)
        local parentPath = ""
        if #parts > 1 then parentPath = table.concat(parts, "/", 1, #parts - 1) end
        table.insert(rows, {path = path, name = parts[#parts], parent = parentPath, depth = #parts - 1, folder = false, file = file})
    end
    table.sort(rows, function(a, b) return a.path:lower() < b.path:lower() end)
    return rows
end

local function saveCurrentEditor()
    if not currentProject then return end
    local file = getFile(currentProject, selectedFilePath or currentProject.activeFile)
    if file then file.code = editorBox.Text end
    currentProject.activeFile = selectedFilePath or currentProject.activeFile
    currentProject.updated = os.time()
end

local function renderTree()
    if not currentProject then return end
    for _, child in ipairs(fileTree:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
    end
    local rows = makeTreeRows(currentProject)
    local order = 0
    for _, item in ipairs(rows) do
        local hidden = false
        local parentPath = item.parent
        while parentPath and parentPath ~= "" do
            if expandedFolders[parentPath] == false then hidden = true break end
            local parts = pathSegments(parentPath)
            table.remove(parts, #parts)
            parentPath = table.concat(parts, "/")
        end
        if not hidden then
            order += 1
            local prefix = item.folder and (expandedFolders[item.path] == false and "▸ " or "▾ ") or "  "
            local text = string.rep("  ", math.min(item.depth, 4)) .. prefix .. item.name
            local active = not item.folder and selectedFilePath == item.path
            local row = button(fileTree, text, UDim2.new(1, -3, 0, 22), UDim2.new(), function()
                if item.folder then
                    expandedFolders[item.path] = expandedFolders[item.path] == false
                    renderTree()
                    return
                end
                saveCurrentEditor()
                selectedFilePath = item.path
                currentProject.activeFile = item.path
                editorBox.Text = item.file.code or ""
                activeFileLabel.Text = item.path
                editorStatus.Text = "Opened " .. item.path
                setTextColor(editorStatus, C.muted)
                saveProjects()
                renderTree()
            end, active and C.hover or C.panel2)
            row.LayoutOrder = order
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextSize = 9
            row.Font = item.folder and Enum.Font.GothamBold or Enum.Font.Code
            if active then row.TextColor3 = C.accent end
        end
    end
    fileTree.CanvasSize = UDim2.fromOffset(0, fileTreeLayout.AbsoluteContentSize.Y + 5)
end

local function showInputDialog(title, placeholder, confirmText, callback)
    local overlay = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 80,
    }, main)
    local dialogWidth = math.min(330, width - 30)
    local dialog = new("Frame", {
        Size = UDim2.fromOffset(dialogWidth, 150),
        Position = UDim2.new(0.5, -dialogWidth / 2, 0.5, -75),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ZIndex = 81,
    }, overlay)
    corner(dialog, 9)
    stroke(dialog)
    label(dialog, title, UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 8), 13, C.text, Enum.Font.GothamBold).ZIndex = 82
    local input = new("TextBox", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.fromOffset(10, 40),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = C.muted,
        TextColor3 = C.text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        ZIndex = 82,
    }, dialog)
    corner(input, 6)
    local cancel = button(dialog, "Cancel", UDim2.fromOffset(76, 29), UDim2.new(1, -164, 1, -38), function() overlay:Destroy() end)
    cancel.ZIndex = 82
    local confirm = button(dialog, confirmText or "Create", UDim2.fromOffset(78, 29), UDim2.new(1, -86, 1, -38), function()
        local value = trim(input.Text)
        if value == "" then
            input.PlaceholderText = "A name is required"
            return
        end
        local ok, message = callback(value)
        if ok then
            overlay:Destroy()
        else
            input.Text = value
            input.PlaceholderText = message or "Invalid name"
        end
    end, C.accent)
    confirm.ZIndex = 82
    input:CaptureFocus()
end

local function createProjectCard(project, order)
    local card = new("Frame", {
        Size = UDim2.new(1, -6, 0, 72),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, projectList)
    corner(card, 8)
    stroke(card, C.border, 0.55)
    label(card, project.name, UDim2.new(1, -170, 0, 24), UDim2.fromOffset(10, 8), 12, C.text, Enum.Font.GothamBold)
    label(card, "Luau · " .. projectBytes(project) .. " · " .. tostring(#project.files) .. " files", UDim2.new(1, -170, 0, 18), UDim2.fromOffset(10, 36), 9, C.muted)

    button(card, "Open", UDim2.fromOffset(49, 27), UDim2.new(1, -158, 0.5, -13), function()
        ensureProject(project)
        currentProject = project
        selectedFilePath = project.activeFile
        local file = getFile(project, selectedFilePath)
        editorBox.Text = file and file.code or ""
        activeFileLabel.Text = selectedFilePath or "main.lua"
        headerContext.Text = project.name
        projectsPage.Visible = false
        executePage.Visible = false
        editorPage.Visible = true
        editorStatus.Text = "Project opened"
        setTextColor(editorStatus, C.green)
        consoleEntries = {}
        log("Info", "Opened project " .. project.name)
        renderTree()
    end, C.accent)

    button(card, "Rename", UDim2.fromOffset(54, 27), UDim2.new(1, -103, 0.5, -13), function()
        showInputDialog("Rename project", project.name, "Rename", function(value)
            local oldName = project.name
            project.name = value
            project.updated = os.time()
            local ok, message = saveProjects()
            refreshProjects()
            log(ok and "Success" or "Warning", ok and ("Renamed " .. oldName .. " to " .. value) or message)
            return true
        end)
    end)

    button(card, "×", UDim2.fromOffset(28, 27), UDim2.new(1, -39, 0.5, -13), function()
        local removedName = project.name
        for index, item in ipairs(projects) do
            if item.id == project.id then table.remove(projects, index) break end
        end
        saveProjects()
        refreshProjects()
        log("Info", "Deleted project " .. removedName)
    end, C.panel2)
end

refreshProjects = function()
    for _, child in ipairs(projectList:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
    end
    for index, project in ipairs(projects) do
        ensureProject(project)
        createProjectCard(project, index)
    end
    if #projects == 0 then
        local empty = new("Frame", {Size = UDim2.new(1, -6, 0, 76), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = 1}, projectList)
        corner(empty, 8)
        label(empty, "No projects yet", UDim2.new(1, -18, 0, 24), UDim2.fromOffset(10, 12), 13, C.text, Enum.Font.GothamBold)
        label(empty, "Press Add Project to create one.", UDim2.new(1, -18, 0, 20), UDim2.fromOffset(10, 39), 10, C.muted)
    end
end

local addProject = button(projectsPage, "+ Add Project", UDim2.new(1, -24, 0, 37), UDim2.new(0, 12, 1, -47), function()
    showInputDialog("Create project", "My project", "Create", function(value)
        table.insert(projects, {
            id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)),
            name = value,
            files = {{path = "main.lua", code = "-- " .. value .. "\n\n", autoExecute = false}},
            folders = {},
            activeFile = "main.lua",
            updated = os.time(),
        })
        local ok, message = saveProjects()
        refreshProjects()
        log(ok and "Success" or "Warning", ok and ("Created project " .. value) or message)
        return true
    end)
end, C.accent)

addFileButton.Activated:Connect(function()
    if not currentProject then return end
    showInputDialog("Add file", "folder/example.lua or main.lua", "Add", function(value)
        local path = normalizePath(value)
        if not path or not path:match("%.[%w_%-]+$") then return false, "Use a file name such as module.lua" end
        if getFile(currentProject, path) then return false, "That file already exists" end
        saveCurrentEditor()
        local file = {path = path, code = "", autoExecute = false}
        table.insert(currentProject.files, file)
        selectedFilePath = path
        currentProject.activeFile = path
        editorBox.Text = ""
        activeFileLabel.Text = path
        saveProjects()
        renderTree()
        return true
    end)
end)

addFolderButton.Activated:Connect(function()
    if not currentProject then return end
    showInputDialog("Add folder", "folder or folder/subfolder", "Add", function(value)
        local path = normalizePath(value)
        if not path then return false, "Invalid folder path" end
        for _, existing in ipairs(currentProject.folders) do
            if existing == path then return false, "That folder already exists" end
        end
        saveCurrentEditor()
        table.insert(currentProject.folders, path)
        saveProjects()
        renderTree()
        return true
    end)
end)

deleteFileButton.Activated:Connect(function()
    if not currentProject then return end
    if #currentProject.files <= 1 then
        log("Warning", "A project must contain at least one file.")
        openConsole()
        return
    end
    local oldPath = selectedFilePath
    for index, file in ipairs(currentProject.files) do
        if file.path == oldPath then table.remove(currentProject.files, index) break end
    end
    local first = currentProject.files[1]
    selectedFilePath = first.path
    currentProject.activeFile = first.path
    editorBox.Text = first.code or ""
    activeFileLabel.Text = first.path
    saveProjects()
    renderTree()
    log("Info", "Deleted " .. tostring(oldPath))
end)

-- Execute page ---------------------------------------------------------------
button(executePage, "← Projects", UDim2.fromOffset(82, 27), UDim2.fromOffset(12, 7), function()
    showProjects()
end, C.panel2)
label(executePage, "Execute", UDim2.new(1, -110, 0, 24), UDim2.fromOffset(102, 8), 14, C.text, Enum.Font.GothamBold)
local executeInfo = label(executePage,
    "Run your own code or code you have permission to test. Auto Execute is off by default.",
    UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 38), 9, C.muted)
executeInfo.TextWrapped = true
local executeList = new("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 72),
    Size = UDim2.new(1, -24, 1, -124),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 0),
}, executePage)
local executeLayout = new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, executeList)
executeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    executeList.CanvasSize = UDim2.fromOffset(0, executeLayout.AbsoluteContentSize.Y + 6)
end)

local function executeFile(project, file, openOutput)
    if not project or not file then return end
    local source = file.code or ""
    if trim(source) == "" then
        log("Warning", project.name .. "/" .. file.path .. " is empty.")
        if openOutput then openConsole() end
        return
    end
    if type(loadstring) ~= "function" then
        log("Error", "loadstring is unavailable in this executor.")
        if openOutput then openConsole() end
        return
    end
    local compileOk, chunk, compileError = pcall(loadstring, source, "@" .. project.name .. "/" .. file.path)
    if not compileOk or type(chunk) ~= "function" then
        local message = tostring(compileOk and compileError or chunk)
        log("Error", project.name .. "/" .. file.path .. ": " .. message, extractLine(message))
        if openOutput then openConsole() end
        return
    end
    log("Info", "Running " .. project.name .. "/" .. file.path)
    task.spawn(function()
        local runOk, runError = pcall(chunk)
        if runOk then
            log("Success", "Finished " .. project.name .. "/" .. file.path)
        else
            local message = tostring(runError)
            log("Error", message, extractLine(message))
        end
    end)
    if openOutput then openConsole() end
end

local function refreshExecute()
    for _, child in ipairs(executeList:GetChildren()) do
        if child:IsA("GuiObject") and not child:IsA("UIListLayout") then child:Destroy() end
    end
    local order = 0
    for _, project in ipairs(projects) do
        ensureProject(project)
        for _, file in ipairs(project.files) do
            order += 1
            local row = new("Frame", {
                Size = UDim2.new(1, -5, 0, 58),
                BackgroundColor3 = C.panel,
                BorderSizePixel = 0,
                LayoutOrder = order,
            }, executeList)
            corner(row, 7)
            label(row, project.name .. "/" .. file.path, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(8, 5), 9, C.text, Enum.Font.GothamMedium)
            label(row, byteSize(#file.code), UDim2.new(1, -150, 0, 17), UDim2.fromOffset(8, 31), 9, C.muted)
            button(row, "Run", UDim2.fromOffset(43, 25), UDim2.new(1, -95, 0, 5), function()
                executeFile(project, file, true)
            end, C.accent).TextSize = 10
            button(row, file.autoExecute and "Auto ON" or "Auto OFF", UDim2.fromOffset(76, 25), UDim2.new(1, -84, 0, 31), function()
                file.autoExecute = not file.autoExecute
                saveProjects()
                refreshExecute()
            end, file.autoExecute and C.green or C.panel2).TextSize = 9
        end
    end
    if order == 0 then
        local empty = new("Frame", {Size = UDim2.new(1, -5, 0, 74), BackgroundColor3 = C.panel, BorderSizePixel = 0}, executeList)
        corner(empty, 7)
        label(empty, "No files yet", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 10), 12, C.text, Enum.Font.GothamBold)
        label(empty, "Create a project and add a .lua file.", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 36), 9, C.muted)
    end
end

button(executePage, "Run Auto Execute Files", UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -44), function()
    local count = 0
    for _, project in ipairs(projects) do
        ensureProject(project)
        for _, file in ipairs(project.files) do
            if file.autoExecute then
                count += 1
                executeFile(project, file, false)
            end
        end
    end
    if count == 0 then log("Info", "No files are marked Auto Execute.") end
    openConsole()
end, C.accent)

-- Tools dropdown -------------------------------------------------------------
toolsMenu = new("Frame", {
    Name = "ToolsMenu",
    Size = UDim2.fromOffset(160, 129),
    Position = UDim2.fromOffset(38, 43),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
}, editorPage)
corner(toolsMenu, 8)
stroke(toolsMenu)
label(toolsMenu, "Tools", UDim2.new(1, -12, 0, 20), UDim2.fromOffset(8, 3), 11, C.text, Enum.Font.GothamBold).ZIndex = 21
local dexButton = button(toolsMenu, "Dex", UDim2.new(1, -12, 0, 27), UDim2.fromOffset(6, 26), function()
    toolsMenu.Visible = false
    openDex()
end)
dexButton.ZIndex = 21
local remoteButton = button(toolsMenu, "RemoteSpy", UDim2.new(1, -12, 0, 27), UDim2.fromOffset(6, 57), function()
    toolsMenu.Visible = false
    openRemoteSpy()
end)
remoteButton.ZIndex = 21
local freeCamButton = button(toolsMenu, "FreeCam", UDim2.new(1, -12, 0, 27), UDim2.fromOffset(6, 88), function()
    toolsMenu.Visible = false
    openFreeCam()
end)
freeCamButton.ZIndex = 21

-- Mobile newline support ------------------------------------------------------
local lastCursor = 1
local lastSelection = 1
local function rememberCaret()
    if editorBox.CursorPosition and editorBox.CursorPosition >= 1 then lastCursor = editorBox.CursorPosition end
    if editorBox.SelectionStart and editorBox.SelectionStart >= 1 then lastSelection = editorBox.SelectionStart end
end
editorBox:GetPropertyChangedSignal("CursorPosition"):Connect(rememberCaret)
editorBox:GetPropertyChangedSignal("SelectionStart"):Connect(rememberCaret)
editorBox.Focused:Connect(rememberCaret)

local function insertNewline()
    local source = editorBox.Text or ""
    local cursor = editorBox.CursorPosition
    local selection = editorBox.SelectionStart
    if not cursor or cursor < 1 then cursor = lastCursor end
    if not selection or selection < 1 then selection = cursor end
    cursor = math.clamp(cursor or (#source + 1), 1, #source + 1)
    selection = math.clamp(selection or cursor, 1, #source + 1)
    local first = math.min(cursor, selection)
    local last = math.max(cursor, selection)
    editorBox.Text = string.sub(source, 1, first - 1) .. "\n" .. string.sub(source, last)
    local newCursor = first + 1
    lastCursor, lastSelection = newCursor, newCursor
    editorBox.CursorPosition = newCursor
    editorBox.SelectionStart = newCursor
    editorBox:CaptureFocus()
end

newlineButton.Activated:Connect(insertNewline)
if touch then
    local function refocusEditor()
        task.defer(function()
            if editorBox and editorBox.Parent and editorPage.Visible then editorBox:CaptureFocus() end
        end)
    end
    pcall(function()
        editorBox.ReturnPressedFromOnScreenKeyboard:Connect(refocusEditor)
    end)
    editorBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then refocusEditor() end
    end)
end

-- Page navigation and startup -------------------------------------------------
showProjects = function()
    projectsPage.Visible = true
    executePage.Visible = false
    editorPage.Visible = false
    headerContext.Text = "HOME"
    refreshProjects()
end

local function showExecute()
    projectsPage.Visible = false
    executePage.Visible = true
    editorPage.Visible = false
    headerContext.Text = "EXECUTE"
    refreshExecute()
end

-- Reconnect top-level home tabs with the named navigation functions.
projectsTab.Activated:Connect(showProjects)
executeTab.Activated:Connect(showExecute)

loadProjects()
refreshProjects()
refreshExecute()

if not fileStorageAvailable then
    log("Warning", "readfile/writefile are unavailable. Projects will not persist after this session.")
else
    log("Info", "Project storage initialized at " .. DATA_FILE)
end

-- Auto Execute is opt-in per file. Only use it for code you wrote or are
-- explicitly authorized to run. It is intentionally disabled for new files.
task.defer(function()
    task.wait(1)
    for _, project in ipairs(projects) do
        ensureProject(project)
        for _, file in ipairs(project.files) do
            if file.autoExecute then
                executeFile(project, file, false)
            end
        end
    end
end)

screenGui.Destroying:Connect(function()
    stopFreeCam()
    disconnectRemoteListeners()
end)

print("Easy Scripting v0.5 loaded.")
