local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("Easy Scripting: LocalPlayer is unavailable."); return end
local ROOT_FOLDER = "EasyScripting"
local DATA_FILE = ROOT_FOLDER .. "/projects.json"
local GUI_NAME = "EasyScriptingGui"
local VERSION = "v1.6"
local COLORS = {
    Background=Color3.fromRGB(18,20,27), Panel=Color3.fromRGB(25,28,37), Panel2=Color3.fromRGB(32,36,47),
    PanelHover=Color3.fromRGB(43,48,62), Border=Color3.fromRGB(57,63,79), Text=Color3.fromRGB(235,238,245),
    Muted=Color3.fromRGB(151,160,179), Accent=Color3.fromRGB(105,145,255), Green=Color3.fromRGB(89,205,139),
    Red=Color3.fromRGB(244,103,112), Yellow=Color3.fromRGB(242,190,91), Blue=Color3.fromRGB(107,177,255),
}
local Settings = {
    THEMES = {
    Default = {
        Background=Color3.fromRGB(18,20,27), Panel=Color3.fromRGB(25,28,37),
        Panel2=Color3.fromRGB(32,36,47), PanelHover=Color3.fromRGB(43,48,62),
        Border=Color3.fromRGB(57,63,79), Text=Color3.fromRGB(235,238,245),
        Muted=Color3.fromRGB(151,160,179), Accent=Color3.fromRGB(105,145,255),
        Green=Color3.fromRGB(89,205,139), Red=Color3.fromRGB(244,103,112),
        Yellow=Color3.fromRGB(242,190,91), Blue=Color3.fromRGB(107,177,255),
    },
    Midnight = {
        Background=Color3.fromRGB(10,11,16), Panel=Color3.fromRGB(16,18,26),
        Panel2=Color3.fromRGB(22,25,36), PanelHover=Color3.fromRGB(34,38,54),
        Border=Color3.fromRGB(44,49,68), Text=Color3.fromRGB(228,232,245),
        Muted=Color3.fromRGB(126,136,158), Accent=Color3.fromRGB(130,120,255),
        Green=Color3.fromRGB(100,220,150), Red=Color3.fromRGB(240,110,130),
        Yellow=Color3.fromRGB(240,200,110), Blue=Color3.fromRGB(120,180,255),
    },
    Nord = {
        Background=Color3.fromRGB(24,28,35), Panel=Color3.fromRGB(31,37,46),
        Panel2=Color3.fromRGB(40,48,60), PanelHover=Color3.fromRGB(52,62,78),
        Border=Color3.fromRGB(70,82,100), Text=Color3.fromRGB(220,228,240),
        Muted=Color3.fromRGB(140,152,172), Accent=Color3.fromRGB(120,180,220),
        Green=Color3.fromRGB(160,200,150), Red=Color3.fromRGB(210,130,140),
        Yellow=Color3.fromRGB(220,200,140), Blue=Color3.fromRGB(140,190,220),
    },
    Solarized = {
        Background=Color3.fromRGB(0,43,54), Panel=Color3.fromRGB(7,54,66),
        Panel2=Color3.fromRGB(20,68,82), PanelHover=Color3.fromRGB(38,84,98),
        Border=Color3.fromRGB(88,110,117), Text=Color3.fromRGB(253,246,227),
        Muted=Color3.fromRGB(147,161,161), Accent=Color3.fromRGB(38,139,210),
        Green=Color3.fromRGB(133,153,0), Red=Color3.fromRGB(220,50,47),
        Yellow=Color3.fromRGB(181,137,0), Blue=Color3.fromRGB(101,123,131),
    },
    Light = {
        Background=Color3.fromRGB(238,241,246), Panel=Color3.fromRGB(250,252,255),
        Panel2=Color3.fromRGB(226,232,240), PanelHover=Color3.fromRGB(206,214,226),
        Border=Color3.fromRGB(180,188,200), Text=Color3.fromRGB(30,34,44),
        Muted=Color3.fromRGB(96,105,120), Accent=Color3.fromRGB(60,110,220),
        Green=Color3.fromRGB(45,150,90), Red=Color3.fromRGB(200,60,70),
        Yellow=Color3.fromRGB(190,150,30), Blue=Color3.fromRGB(60,130,200),
    },
    },
    SETTINGS_FILE = ROOT_FOLDER .. "/settings.json",
    AppSettings = { theme="Default", autoSave=false, userName="You", deviceMode="auto" },
}
Settings.loadSettings = function()
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, Settings.SETTINGS_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local okDec, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if okDec and type(data) == "table" then
        if type(data.theme) == "string" and Settings.THEMES[data.theme] then
            Settings.AppSettings.theme = data.theme
        end
        Settings.AppSettings.autoSave = data.autoSave == true
        if type(data.userName) == "string" and data.userName ~= "" then
            Settings.AppSettings.userName = data.userName
        end
        if data.deviceMode == "auto" or data.deviceMode == "phone" or data.deviceMode == "pc" then
            Settings.AppSettings.deviceMode = data.deviceMode
        end
    end
end
Settings.saveSettings = function()
    if type(writefile) ~= "function" then return end
    if type(makefolder) == "function" then pcall(makefolder, ROOT_FOLDER) end
    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(Settings.AppSettings) end)
    if okEnc then pcall(writefile, Settings.SETTINGS_FILE, encoded) end
end
Settings.loadSettings()
do
    local selectedTheme = Settings.THEMES[Settings.AppSettings.theme] or Settings.THEMES.Default
    for key, value in pairs(selectedTheme) do COLORS[key] = value end
end
local function make(c,p,parent) local o=Instance.new(c); for k,v in pairs(p or {}) do o[k]=v end; if parent then o.Parent=parent end; return o end
local function addCorner(o,r) make("UICorner",{CornerRadius=UDim.new(0,r or 8)},o) end
local function addStroke(o,c,t) make("UIStroke",{Color=c or COLORS.Border,Thickness=1,Transparency=t or 0},o) end
local function createLabel(parent,text,size,pos,tsize,color,font)
    return make("TextLabel",{BackgroundTransparency=1,Size=size,Position=pos,Text=text or "",TextColor3=color or COLORS.Text,
        TextSize=tsize or 14,Font=font or Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=false},parent)
end
local logConsole
local function createButton(parent,text,size,pos,cb,accent)
    local b=make("TextButton",{Size=size,Position=pos,BackgroundColor3=accent or COLORS.Panel2,BorderSizePixel=0,Text=text,
        TextColor3=COLORS.Text,TextSize=13,Font=Enum.Font.GothamMedium,AutoButtonColor=true,Active=true,Selectable=true},parent)
    addCorner(b,8)
    b.Activated:Connect(function() if cb then local ok,err=pcall(cb); if not ok then warn("Easy Scripting button error: "..tostring(err)); if logConsole then logConsole("Error","Button error: "..tostring(err)) end end end end)
    return b
end
local function makeDraggable(handle,target)
    local dragging,dragInput,dragStart,startPosition=false,nil,nil,nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPosition=target.Position; dragInput=input
        end
    end)
    handle.InputEnded:Connect(function(input) if input==dragInput then dragging=false; dragInput=nil end end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local d=input.Position-dragStart
            target.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,startPosition.Y.Scale,startPosition.Y.Offset+d.Y)
        end
    end)
end
local function trim(v) return tostring(v or ""):gsub("^%s+",""):gsub("%s+$","") end
local function formatBytes(b)
    if b<1024 then return tostring(b).." B" elseif b<1024*1024 then return string.format("%.1f KB",b/1024) end
    return string.format("%.2f MB",b/(1024*1024))
end
local function normalizePath(p)
    p=tostring(p or ""):gsub("\\","/"):gsub("^/+",""):gsub("/+$","")
    if p=="" or p:find("..",1,true) or p:find("//",1,true) then return nil end
    return p
end
local function splitPath(p) local t={}; for part in string.gmatch(p or "","[^/]+") do table.insert(t,part) end; return t end
local function parentPath(p) local i=string.match(p or "","^.*()/"); if i then return string.sub(p,1,i-1) end; return "" end
local function leafName(p) local t=splitPath(p); return t[#t] or p end
local SUPPORTED_FILE_TYPES={lua=true,luau=true,json=true,txt=true,md=true}
local function getFileExtension(p) local n=leafName(p or ""); local e=n:match("%.([%w_%-]+)$"); return e and e:lower() or "" end
local function isSupportedFile(p) return SUPPORTED_FILE_TYPES[getFileExtension(p)]==true end
local function isScriptFile(p) local e=getFileExtension(p); return e=="lua" or e=="luau" end
local function ensureParentFolders(project,path)
    local parent=parentPath(path)
    while parent~="" do
        local found=false
        for _,folder in ipairs(project.folders) do if folder==parent then found=true; break end end
        if not found then table.insert(project.folders,parent) end
        parent=parentPath(parent)
    end
end
local function pathTaken(project,path,igF,igD)
    for _,file in ipairs(project.files or {}) do
        if file.path==path and file.path~=igF then return true end
        if file.path~=igF and string.sub(path,1,#file.path+1)==file.path.."/" then return true end
        local parent=parentPath(file.path)
        while parent~="" do if parent==path and parent~=igD then return true end; parent=parentPath(parent) end
    end
    for _,folder in ipairs(project.folders or {}) do
        if folder==path and folder~=igD then return true end
        if folder~=igD and string.sub(folder,1,#path+1)==path.."/" then return true end
    end
    return false
end
local guiParent
local parentOk,parentResult=pcall(function() if type(gethui)=="function" then return gethui() end; return game:GetService("CoreGui") end)
guiParent=(parentOk and parentResult) or LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    local old=guiParent:FindFirstChild(GUI_NAME); if old then old:Destroy() end
    local oldF=guiParent:FindFirstChild(GUI_NAME.."_Floating"); if oldF then oldF:Destroy() end
end)
local screenGui=make("ScreenGui",{Name=GUI_NAME,ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999},guiParent)
local TOGGLE_KEY=Enum.KeyCode.F2
local floatingGui=make("ScreenGui",{Name=GUI_NAME.."_Floating",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=1000},guiParent)
local floatingButton=make("TextButton",{Name="EasyScriptingRestore",Size=UDim2.fromOffset(140,34),Position=UDim2.new(1,-152,0,16),
    BackgroundColor3=COLORS.Accent,BorderSizePixel=0,Text="Easy Scripting",TextColor3=COLORS.Text,TextSize=13,Font=Enum.Font.GothamBold,Visible=false,ZIndex=1},floatingGui)
addCorner(floatingButton,8); addStroke(floatingButton,COLORS.Border); makeDraggable(floatingButton,floatingButton)
local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
local touchDevice=UserInputService.TouchEnabled
Settings.isPhoneLike = false
if Settings.AppSettings.deviceMode == "phone" then
    Settings.isPhoneLike = true
elseif Settings.AppSettings.deviceMode == "pc" then
    Settings.isPhoneLike = false
else
    Settings.isPhoneLike = touchDevice and not UserInputService.KeyboardEnabled
end
local windowWidth=math.max(300,math.min(860,viewport.X-24))
local windowHeight=math.max(340,math.min(620,viewport.Y-40))
if Settings.isPhoneLike then
    windowWidth = math.max(280, math.min(500, viewport.X - 16))
    windowHeight = math.max(300, math.min(480, math.floor(viewport.Y * 0.65)))
end
local compact
if Settings.AppSettings.deviceMode == "phone" then
    compact = true
elseif Settings.AppSettings.deviceMode == "pc" then
    compact = false
else
    compact = touchDevice or windowWidth < 520
end
local window=make("Frame",{Name="MainWindow",Size=UDim2.fromOffset(windowWidth,windowHeight),
    Position=UDim2.new(0.5,-windowWidth/2,0.5,-windowHeight/2),BackgroundColor3=COLORS.Background,BorderSizePixel=0,ClipsDescendants=true,Active=true},screenGui)
addCorner(window,12); addStroke(window,COLORS.Border)
local header=make("Frame",{Size=UDim2.new(1,0,0,52),BackgroundColor3=COLORS.Panel,BorderSizePixel=0},window)
local headerTitle=createLabel(header,"  Easy Scripting "..VERSION,UDim2.new(1,-160,0,28),UDim2.fromOffset(8,2),16,COLORS.Text,Enum.Font.GothamBold)
local headerSubtitle=createLabel(header,"HOME",UDim2.fromOffset(200,16),UDim2.fromOffset(12,32),10,COLORS.Muted)
headerSubtitle.TextXAlignment=Enum.TextXAlignment.Left
local toggleEasyScripting
local minimizeButton=createButton(header,"–",UDim2.fromOffset(30,30),UDim2.new(1,-72,0,11),function() if toggleEasyScripting then toggleEasyScripting() end end,COLORS.Panel2)
minimizeButton.TextSize=22
local closeButton=createButton(header,"X",UDim2.fromOffset(30,30),UDim2.new(1,-40,0,11),function() screenGui:Destroy() end,COLORS.Panel2)
closeButton.TextSize=20
local isHidden=false
function toggleEasyScripting()
    isHidden=not isHidden
    screenGui.Enabled=not isHidden
    floatingButton.Visible=isHidden
end
floatingButton.Activated:Connect(toggleEasyScripting)
Settings.getColorKey = function(color)
    for key, value in pairs(COLORS) do
        if typeof(value) == "Color3" and value == color then
            return key
        end
    end
    return nil
end
Settings.applyThemeToGui = function(rootGui, newTheme)
    if not rootGui or not newTheme then return end
    local function walk(object)
        if object:IsA("GuiObject") then
            local backgroundKey = Settings.getColorKey(object.BackgroundColor3)
            if backgroundKey and newTheme[backgroundKey] then
                object.BackgroundColor3 = newTheme[backgroundKey]
            end
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                local textKey = Settings.getColorKey(object.TextColor3)
                if textKey and newTheme[textKey] then
                    object.TextColor3 = newTheme[textKey]
                end
                if object:IsA("TextBox") then
                    local placeholderKey = Settings.getColorKey(object.PlaceholderColor3)
                    if placeholderKey and newTheme[placeholderKey] then
                        object.PlaceholderColor3 = newTheme[placeholderKey]
                    end
                end
            end
            if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                local imageKey = Settings.getColorKey(object.ImageColor3)
                if imageKey and newTheme[imageKey] then
                    object.ImageColor3 = newTheme[imageKey]
                end
            end
        elseif object:IsA("UIStroke") then
            local strokeKey = Settings.getColorKey(object.Color)
            if strokeKey and newTheme[strokeKey] then
                object.Color = newTheme[strokeKey]
            end
        end
        for _, child in ipairs(object:GetChildren()) do
            walk(child)
        end
    end
    walk(rootGui)
end
Settings.applyThemeToAll = function(newThemeName)
    local newTheme = Settings.THEMES[newThemeName]
    if not newTheme then return end
    Settings.applyThemeToGui(screenGui, newTheme)
    Settings.applyThemeToGui(floatingGui, newTheme)
    for key, value in pairs(newTheme) do
        COLORS[key] = value
    end
end
UserInputService.InputBegan:Connect(function(input,processed) if processed then return end; if input.KeyCode==TOGGLE_KEY then toggleEasyScripting() end end)
local body=make("Frame",{Name="Body",Position=UDim2.fromOffset(0,52),Size=UDim2.new(1,0,1,-52),BackgroundTransparency=1},window)
local fileStorageAvailable=type(readfile)=="function" and type(writefile)=="function"
local function ensureFolder()
    if type(isfolder)=="function" then local ok,ex=pcall(isfolder,ROOT_FOLDER); if ok and ex then return end end
    if type(makefolder)=="function" then pcall(makefolder,ROOT_FOLDER) end
end
Settings.getMaxToolSize = function()
    local vx = viewport.X
    local vy = viewport.Y
    if not vx or not vy or vx <= 0 or vy <= 0 then
        vx, vy = 1280, 720
    end
    local margin = Settings.isPhoneLike and 8 or 20
    return math.max(200, vx - margin * 2), math.max(200, vy - margin * 2)
end
local projects={}
local currentProject=nil
local consoleEntries={}
local consoleWindow=nil
local consoleList=nil
local consoleCountLabel=nil
local editorBox=nil
local editorViewport=nil
local editorStatus=nil
Settings.ProjectNavigation = {
    currentViewDir = "",
    viewingFile = false,
}
local BigCode = {
    mode=false,
    fullText="",
    chunks={},
    chunkStartLines={},
    chunkOffsets={},
    chunkHeights={},
    chunkWidths={},
    virtualSlots={},
    virtualGutterSlots={},
    slotChunkIndices={},
    slotGutterCache={},
    focusedEditor=nil,
    focusedChunkIndex=nil,
    rebuilding=false,
    pendingRechunk=false,
    selectAll=false,
    totalLines=1,
    totalHeight=0,
    poolSize=15,
}
local editorFileLabel=nil
local runCheckButton=nil
local projectsPage=nil
local executePage=nil
local editorPage=nil
local toolsPanel=nil
local renderProjects
local renderExecutePage
local renderFileTree
local stopFreeCam
local expandedFolders={[""]=true}
local lastTreeClickPath=nil
local lastTreeClickIsFolder=nil
local lastTreeClickTime=0
local selectedTreePath="main.lua"
local selectedTreeIsFolder=false
local updatePathBar
local renameSelectedPath
local deleteSelectedTree
local createNewFile
local createNewFolder
local openAIChat
Settings.openReplayWindow=nil
Settings.openReplayHistory=nil
Settings.openReplayCodeViewer=nil
Settings.replayStopAndSave=nil
Settings.replayStart=nil
Settings.Replay = {
    recording = false,
    startTime = 0,
    queue = {},
    lastEventTime = 0,
    maxEvents = 50000,
    maxMinutes = 60,
    updateInterval = 0.5,
    stopKeyName = "F8",
    lastPosTime = 0,
    lastCFrame = nil,
    connectionHeartbeat = nil,
    connectionStateChanged = nil,
    connectionCharAdded = nil,
    connectionInput = nil,
    hookInstalled = false,
    hookOriginal = nil,
    hookMetatable = nil,
    window = nil,
    content = nil,
    statusLabel = nil,
    remoteHookCount = 0,
    renderUI = nil,
    recBar = nil,
    recTimeLabel = nil,
    recDotPulse = nil,
    warned90 = false,
    hookSupported = nil,
    hookMissingInfo = nil,
    history = {},
    historyWindow = nil,
    codeViewerWindow = nil,
    generating = false,
    viewMode = "list",
    remoteBlacklist = {},
    recordMode = "all",
}
Settings.ExecuteControl = {
    running = false,
    killFlag = false,
    connections = {},
    stopBtn = nil,
    snapshot = nil,
    activeChunkName = nil,
}
Settings.ProjectModules = {
    cache = {},        -- [resolvedPath] = module return value
    stack = {},        -- array of paths for cyclic detection
    preloadEnabled = true,
    lastPreloadReport = nil,
}
Settings.Replay.recBar=make("Frame",{
    Name="ReplayRecBar",
    Size=UDim2.fromOffset(280,36),
    Position=UDim2.new(0.5,-140,0,14),
    BackgroundColor3=Color3.fromRGB(34,18,20),
    BorderSizePixel=0,
    Visible=false,
    ZIndex=2000,
    Active=true,
},floatingGui)
addCorner(Settings.Replay.recBar,10)
addStroke(Settings.Replay.recBar,COLORS.Red,0)
makeDraggable(Settings.Replay.recBar,Settings.Replay.recBar)
Settings.Replay.recDot=make("Frame",{
    Name="RecDot",
    Size=UDim2.fromOffset(10,10),
    Position=UDim2.fromOffset(12,13),
    BackgroundColor3=COLORS.Red,
    BorderSizePixel=0,
    ZIndex=2001,
},Settings.Replay.recBar)
addCorner(Settings.Replay.recDot,5)
Settings.Replay.recDotPulse=game:GetService("TweenService"):Create(
    Settings.Replay.recDot,
    TweenInfo.new(0.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
    {BackgroundTransparency=0.7}
)
createLabel(Settings.Replay.recBar,"REC",UDim2.fromOffset(42,36),UDim2.fromOffset(28,0),11,COLORS.Red,Enum.Font.GothamBold).ZIndex=2001
Settings.Replay.recTimeLabel=createLabel(Settings.Replay.recBar,"00:00",UDim2.fromOffset(90,36),UDim2.fromOffset(72,0),13,COLORS.Text,Enum.Font.Code)
Settings.Replay.recTimeLabel.ZIndex=2001
Settings.Replay.recStopBtn=createButton(Settings.Replay.recBar,"Stop",UDim2.fromOffset(80,26),UDim2.new(1,-88,0,5),function()
    if Settings.Replay.recording and Settings.replayStopAndSave then Settings.replayStopAndSave() end
end,COLORS.Red)
Settings.Replay.recStopBtn.ZIndex=2001
Settings.Replay.recStopBtn.TextSize=11
Settings.ExecuteControl.stopBtn = make("Frame", {
    Name = "StopExecuteBar",
    Size = UDim2.fromOffset(220, 36),
    Position = UDim2.new(0, 16, 0, 16),
    BackgroundColor3 = Color3.fromRGB(58, 28, 28),
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 2100,
    Active = true,
}, floatingGui)
addCorner(Settings.ExecuteControl.stopBtn, 10)
addStroke(Settings.ExecuteControl.stopBtn, COLORS.Red, 0)
makeDraggable(Settings.ExecuteControl.stopBtn, Settings.ExecuteControl.stopBtn)
createLabel(Settings.ExecuteControl.stopBtn, "Execute running", UDim2.new(1, -100, 1, 0), UDim2.fromOffset(12, 0), 11, COLORS.Red, Enum.Font.GothamBold).ZIndex = 2101
Settings.ExecuteControl.stopActionButton = createButton(Settings.ExecuteControl.stopBtn, "Stop Execute", UDim2.fromOffset(92, 26), UDim2.new(1, -98, 0, 5), function()
    if Settings.executeStop then Settings.executeStop() end
end, COLORS.Red)
Settings.ExecuteControl.stopActionButton.ZIndex = 2101
Settings.ExecuteControl.stopActionButton.TextSize = 11
local function refreshEditorFileHeader(path)
    if editorFileLabel then editorFileLabel.Text=path or "Select a file" end
    if editorBox then
        editorBox.TextEditable=path~=nil and path~=""
        if not path or path=="" then
            editorBox.PlaceholderText="Select a file from the project tree..."
        else
            local ext=getFileExtension(path)
            if ext=="json" then editorBox.PlaceholderText='{"key": "value"}'
            elseif ext=="txt" then editorBox.PlaceholderText="Write text here..."
            elseif ext=="md" then editorBox.PlaceholderText="# Project notes"
            else editorBox.PlaceholderText="-- Start writing Luau code here..." end
        end
    end
    if path and runCheckButton then
        if isScriptFile(path) then runCheckButton.Text="Run"
        else runCheckButton.Text="Check" end
    end
end
local function getProjectFile(project,path)
    if not project or type(project.files)~="table" then return nil end
    for _,f in ipairs(project.files) do if f.path==path then return f end end
    return nil
end
local function ensureProjectStructure(project)
    if type(project.files)~="table" then project.files={} end
    if type(project.folders)~="table" then project.folders={} end
    if #project.files==0 then table.insert(project.files,{path="main.lua",code=type(project.code)=="string" and project.code or "",autoExecute=false}) end
    if type(project.activeFile)~="string" or not getProjectFile(project,project.activeFile) then project.activeFile=project.files[1].path end
    if type(project.mainFile)~="string" or not getProjectFile(project,project.mainFile) then project.mainFile=project.files[1].path end
    local a=getProjectFile(project,project.activeFile); project.code=a and a.code or (project.code or "")
end
local function getProjectSize(project)
    ensureProjectStructure(project)
    local bytes=0
    for _,f in ipairs(project.files) do bytes=bytes+#(f.path or "")+#(f.code or "") end
    for _,f in ipairs(project.folders) do bytes=bytes+#tostring(f) end
    return formatBytes(bytes)
end
local function saveData()
    if not fileStorageAvailable then return false,"File APIs are unavailable. Projects stay in this session." end
    ensureFolder()
    local okE,enc=pcall(function() return HttpService:JSONEncode(projects) end)
    if not okE then return false,"Encode failed: "..tostring(enc) end
    local okW,err=pcall(function() writefile(DATA_FILE,enc) end)
    if not okW then return false,"Save failed: "..tostring(err) end
    return true,"Saved."
end
local function loadData()
    if not fileStorageAvailable then return end
    ensureFolder()
    local exists=false
    if type(isfile)=="function" then local ok,r=pcall(isfile,DATA_FILE); exists=ok and r==true else exists=pcall(readfile,DATA_FILE) end
    if not exists then return end
    local okR,raw=pcall(readfile,DATA_FILE)
    if not okR then warn("Easy Scripting: read failed: "..tostring(raw)); return end
    local okD,dec=pcall(function() return HttpService:JSONDecode(raw) end)
    if not okD or type(dec)~="table" then warn("Easy Scripting: invalid JSON."); return end
    for _,item in ipairs(dec) do
        if type(item)=="table" and type(item.name)=="string" then
            local p={id=tostring(item.id or (os.time().."_"..tostring(math.random(1000,9999)))),name=item.name,
                code=type(item.code)=="string" and item.code or "",files=type(item.files)=="table" and item.files or {},
                folders=type(item.folders)=="table" and item.folders or {},
                activeFile=type(item.activeFile)=="string" and item.activeFile or "main.lua",
                mainFile=type(item.mainFile)=="string" and item.mainFile or "main.lua",updated=tonumber(item.updated) or os.time()}
            local sf={}
            for _,f in ipairs(p.files) do
                if type(f)=="table" and type(f.path)=="string" and type(f.code)=="string" then
                    local sp=normalizePath(f.path)
                    if sp then table.insert(sf,{path=sp,code=f.code,autoExecute=f.autoExecute==true and isScriptFile(sp)}) end
                end
            end
            p.files=sf
            local sfo={}
            for _,f in ipairs(p.folders) do local sp=normalizePath(f); if sp then table.insert(sfo,sp) end end
            p.folders=sfo
            ensureProjectStructure(p)
            table.insert(projects,p)
        end
    end
end
local function getLineNumber(msg)
    if type(msg)~="string" then return nil end
    local l=msg:match(":(%d+):") or msg:match("line%s+(%d+)") or msg:match("Line%s+(%d+)")
    return tonumber(l)
end
local function validateCode(src)
    if type(src)~="string" or src:gsub("%s","")=="" then return false,"Empty script.",nil end
    if type(loadstring)~="function" then return false,"loadstring unavailable.",nil end
    local ok,c,err=pcall(loadstring,src,"@EasyScriptingProject")
    if not ok then local m=tostring(c); return false,m,getLineNumber(m) end
    if not c then local m=tostring(err or "Unknown Luau error."); return false,m,getLineNumber(m) end
    return true,"No syntax errors. Not executed.",nil
end
local function validateProjectFile(file,src)
    if not file then return false,"No file selected.",nil end
    local ext=getFileExtension(file.path)
    if ext=="lua" or ext=="luau" then return validateCode(src)
    elseif ext=="json" then
        if type(src)~="string" or trim(src)=="" then return false,"Empty JSON.",nil end
        local ok,r=pcall(function() return HttpService:JSONDecode(src) end)
        if not ok then return false,"Invalid JSON: "..tostring(r),nil end
        return true,"Valid JSON. Not executed.",nil
    elseif ext=="txt" or ext=="md" then return true,"No check needed for ."..ext,nil end
    return false,"Unsupported. Use .lua/.luau/.json/.txt/.md",nil
end
local function addConsoleEntry(kind,msg,line)
    table.insert(consoleEntries,{kind=kind,message=tostring(msg),line=line,time=os.date("%H:%M:%S")})
    while #consoleEntries>200 do table.remove(consoleEntries,1) end
end
local function jumpToLine(line)
    if not line or line<1 then return end
    if BigCode and BigCode.mode and BigCode.focusLine then
        BigCode.focusLine(line)
        return
    end
    if not editorBox then return end
    local src=editorBox.Text or ""; local pos=1
    for _=1,line-1 do local nl=string.find(src,"\n",pos,true); if not nl then pos=#src+1; break end; pos=nl+1 end
    editorBox:CaptureFocus(); editorBox.CursorPosition=pos; editorBox.SelectionStart=pos
end
local function renderConsole()
    if not consoleList then return end
    for _,c in ipairs(consoleList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local errs,warns=0,0
    for _,e in ipairs(consoleEntries) do if e.kind=="Error" then errs=errs+1 elseif e.kind=="Warning" then warns=warns+1 end end
    if consoleCountLabel then consoleCountLabel.Text=string.format("%d errors  -  %d warnings  -  %d messages",errs,warns,#consoleEntries) end
    for i,e in ipairs(consoleEntries) do
        local col,tag=COLORS.Blue,"INFO"
        if e.kind=="Error" then col,tag=COLORS.Red,"ERROR"
        elseif e.kind=="Warning" then col,tag=COLORS.Yellow,"WARN"
        elseif e.kind=="Success" then col,tag=COLORS.Green,"OK" end
        local isMultiLine = (type(e.message) == "string" and (e.message:find("\n") ~= nil))
        local rh = isMultiLine and 0 or (e.line and 58 or 44)
        local row=make("TextButton",{Name="ConsoleEntry"..tostring(i),Size=UDim2.new(1,-8,0,rh),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,
            AutoButtonColor=e.line~=nil,Text="",LayoutOrder=i,Active=true},consoleList)
        if isMultiLine then
            row.AutomaticSize = Enum.AutomaticSize.Y
        end
        addCorner(row,7)
        createLabel(row,tag,UDim2.fromOffset(54,18),UDim2.fromOffset(9,3),9,col,Enum.Font.GothamBold)
        local timeLabel = createLabel(row,e.time,UDim2.fromOffset(64,18),UDim2.new(1,-72,0,3),9,COLORS.Muted)
        if e.kind == "Error" then
            timeLabel.Position = UDim2.new(1,-134,0,3)
        end
        local ml=createLabel(row,e.message,UDim2.new(1,-18,0,isMultiLine and 0 or (e.line and 24 or 21)),UDim2.fromOffset(9,22),10,COLORS.Text)
        if isMultiLine then
            ml.AutomaticSize = Enum.AutomaticSize.Y
            make("UIPadding", { PaddingBottom = UDim.new(0, 8) }, row)
        end
        ml.TextWrapped=true; ml.TextYAlignment=Enum.TextYAlignment.Top
        if e.line then
            createLabel(row,"Tap to jump to line "..tostring(e.line),UDim2.new(1,-18,0,14),UDim2.fromOffset(9,42),9,COLORS.Accent)
            row.Activated:Connect(function() jumpToLine(e.line) end)
        end
        if e.kind == "Error" then
            local copyErrorBtn
            copyErrorBtn = make("TextButton",{
                Size = UDim2.fromOffset(58,18),
                Position = UDim2.new(1,-66,0,3),
                BackgroundColor3 = COLORS.Panel,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                Text = "Copy",
                TextColor3 = COLORS.Muted,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                AutoButtonColor = true,
                ZIndex = 2,
            }, row)
            addCorner(copyErrorBtn, 4)
            copyErrorBtn.MouseButton1Click:Connect(function()
                if type(setclipboard) ~= "function" then
                    copyErrorBtn.Text = "No cb"
                    task.delay(1, function() if copyErrorBtn.Parent then copyErrorBtn.Text = "Copy" end end)
                    return
                end
                local fullText = tostring(e.message or "")
                if e.line then
                    fullText = fullText .. "\n(line " .. tostring(e.line) .. ")"
                end
                local ok = pcall(setclipboard, fullText)
                copyErrorBtn.Text = ok and "Copied!" or "Fail"
                task.delay(1, function() if copyErrorBtn.Parent then copyErrorBtn.Text = "Copy" end end)
            end)
        end
    end
    local lay=consoleList:FindFirstChildOfClass("UIListLayout")
    if lay then consoleList.CanvasSize=UDim2.fromOffset(0,lay.AbsoluteContentSize.Y+8) end
end
logConsole=function(kind,msg,line) addConsoleEntry(kind,msg,line); renderConsole() end
local function openConsole()
    if consoleWindow then consoleWindow.Visible=true; renderConsole(); return end
    local maxW, maxH = Settings.getMaxToolSize()
    local w = math.max(260, math.min(520, maxW))
    local h = math.max(220, math.min(340, maxH - 20))
    consoleWindow=make("Frame",{Name="ConsoleWindow",Size=UDim2.fromOffset(w,h),Position=UDim2.new(0.5,-w/2,0.5,-h/2),
        BackgroundColor3=COLORS.Background,BorderSizePixel=0,ZIndex=40,Active=true},screenGui)
    Settings.registerModalWindow(consoleWindow)
    addCorner(consoleWindow,10); addStroke(consoleWindow,COLORS.Border)
    local ch=make("Frame",{Size=UDim2.new(1,0,0,42),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=41},consoleWindow)
    addCorner(ch,10)
    local t=createLabel(ch,"  Console",UDim2.new(1,-170,1,0),UDim2.fromOffset(8,0),14,COLORS.Text,Enum.Font.GothamBold); t.ZIndex=42
    local clr=createButton(ch,"Clear",UDim2.fromOffset(54,26),UDim2.new(1,-98,0,8),function() consoleEntries={}; renderConsole() end); clr.ZIndex=42
    local cls=createButton(ch,"X",UDim2.fromOffset(30,26),UDim2.new(1,-36,0,8),function() consoleWindow.Visible=false end)
    cls.TextSize=18; cls.ZIndex=42
    consoleCountLabel=createLabel(consoleWindow,"0 errors | 0 warnings | 0 messages",UDim2.new(1,-24,0,22),UDim2.fromOffset(12,44),10,COLORS.Muted); consoleCountLabel.ZIndex=41
    consoleList=make("ScrollingFrame",{Name="Messages",Position=UDim2.fromOffset(10,70),Size=UDim2.new(1,-20,1,-80),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.fromOffset(0,0),ZIndex=41},consoleWindow)
    local lay=make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},consoleList)
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() if consoleList then consoleList.CanvasSize=UDim2.fromOffset(0,lay.AbsoluteContentSize.Y+8) end end)
    renderConsole()
end
projectsPage=make("Frame",{Name="ProjectsPage",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},body)
executePage=make("Frame",{Name="ExecutePage",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false},body)
editorPage=make("Frame",{Name="EditorPage",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false},body)
Settings.modalWindows={}
Settings.globalInputBlocker=make("TextButton",{Name="GlobalInputBlocker",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,Text="",AutoButtonColor=false,Active=true,Visible=false,ZIndex=39},editorPage)
Settings.registerModalWindow=function(win)
    if not win then return end
    if Settings.modalWindows[win] then return end
    Settings.modalWindows[win]=true
    local function update()
        local any=false
        for w in pairs(Settings.modalWindows) do
            if w and w.Parent and w.Visible then any=true; break end
        end
        Settings.globalInputBlocker.Visible=any
    end
    win:GetPropertyChangedSignal("Visible"):Connect(update)
    win.AncestryChanged:Connect(update)
    update()
end
local mainToolbar=make("Frame",{Size=UDim2.new(1,-24,0,44),Position=UDim2.fromOffset(12,8),BackgroundTransparency=1},projectsPage)
Settings.page = nil
local function showProjectsPage()
    projectsPage.Visible=true; executePage.Visible=false; editorPage.Visible=false
    if Settings.page then Settings.page.Visible=false end
    headerSubtitle.Text="HOME"; if renderProjects then renderProjects() end
end
local function showExecutePage()
    projectsPage.Visible=false; executePage.Visible=true; editorPage.Visible=false
    if Settings.page then Settings.page.Visible=false end
    headerSubtitle.Text="EXECUTE"; if renderExecutePage then renderExecutePage() end
end
Settings.toolbarWidth = math.max(1, windowWidth - 24)
if Settings.toolbarWidth < 390 then
    Settings.compactButtonWidth = math.floor((Settings.toolbarWidth - 12) / 3)
    Settings.projectButtonWidth, Settings.settingsButtonWidth, Settings.executeButtonWidth = Settings.compactButtonWidth, Settings.compactButtonWidth, Settings.compactButtonWidth
    Settings.projectButtonX, Settings.settingsButtonX, Settings.executeButtonX = 0, Settings.compactButtonWidth + 6, (Settings.compactButtonWidth + 6) * 2
else
    Settings.projectButtonWidth, Settings.settingsButtonWidth, Settings.executeButtonWidth = 120, 110, 120
    Settings.projectButtonX, Settings.settingsButtonX, Settings.executeButtonX = 0, 126, Settings.toolbarWidth - Settings.executeButtonWidth
end
createButton(mainToolbar,"Projects",UDim2.fromOffset(Settings.projectButtonWidth,34),UDim2.fromOffset(Settings.projectButtonX,4),showProjectsPage,COLORS.Panel2)
createButton(mainToolbar,"Settings",UDim2.fromOffset(Settings.settingsButtonWidth,34),UDim2.fromOffset(Settings.settingsButtonX,4),function()
    if Settings.showSettingsPage then Settings.showSettingsPage() end
end,COLORS.Panel2)
createButton(mainToolbar,"Execute",UDim2.fromOffset(Settings.executeButtonWidth,34),UDim2.fromOffset(Settings.executeButtonX,4),showExecutePage,COLORS.Panel2)
Settings.page = make("Frame",{Name="SettingsPage",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false},body)
Settings.showSettingsPage = function()
    projectsPage.Visible=false
    executePage.Visible=false
    editorPage.Visible=false
    Settings.page.Visible=true
    headerSubtitle.Text="SETTINGS"
    for _, child in ipairs(Settings.page:GetChildren()) do
        child:Destroy()
    end

    local settingsScroll = make("ScrollingFrame", {
        Name = "SettingsScroll",
        Size = UDim2.new(1, 0, 1, -50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = COLORS.Muted,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
    }, Settings.page)

    local settingsCanvas = make("Frame", {
        Name = "SettingsCanvas",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, settingsScroll)

    make("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
    }, settingsCanvas)

    make("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, settingsCanvas)

    local settingsCardOrder = 0
    local function makeSettingsCard(titleText, height)
        settingsCardOrder = settingsCardOrder + 1
        local card = make("Frame", {
            Size = UDim2.new(1, 0, 0, height),
            LayoutOrder = settingsCardOrder,
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
        }, settingsCanvas)
        addCorner(card, 8)
        addStroke(card, COLORS.Border, 0.5)
        createLabel(card, titleText, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 6), 13, COLORS.Text, Enum.Font.GothamBold)
        return card
    end

    -- === Theme Card ===
    local themeCard = makeSettingsCard("Theme", 80)
    local themeList = make("Frame", {
        Size = UDim2.new(1, -20, 0, 36),
        Position = UDim2.fromOffset(10, 36),
        BackgroundTransparency = 1,
    }, themeCard)
    local themeOrder = {"Default","Midnight","Nord","Solarized","Light"}
    local themeButtonWidth = math.floor((windowWidth - 24 - 28 - 4*6) / #themeOrder)
    for index, themeName in ipairs(themeOrder) do
        local isActive = Settings.AppSettings.theme == themeName
        local button = createButton(themeList, themeName, UDim2.fromOffset(themeButtonWidth, 36),
            UDim2.fromOffset((index-1)*(themeButtonWidth+6), 0), function()
                Settings.AppSettings.theme = themeName
                Settings.saveSettings()
                Settings.applyThemeToAll(themeName)
                Settings.showSettingsPage()
            end, isActive and COLORS.Accent or COLORS.Panel2)
        button.TextSize = 10
    end

    -- === Auto Save Card ===
    local autoCard = makeSettingsCard("Auto Save", 110)
    local autoDesc = createLabel(autoCard,
        "When enabled, the Save button becomes Auto: ON and the current file saves automatically while you type.",
        UDim2.new(1,-20,0,32), UDim2.fromOffset(10,30),10,COLORS.Muted)
    autoDesc.TextWrapped = true
    autoDesc.TextYAlignment = Enum.TextYAlignment.Top

    local toggleButton = createButton(autoCard,
        Settings.AppSettings.autoSave and "Auto Save: ON" or "Auto Save: OFF",
        UDim2.fromOffset(180,36), UDim2.fromOffset(10,66), function()
            Settings.AppSettings.autoSave = not Settings.AppSettings.autoSave
            Settings.saveSettings()
            if Settings.updateSaveButtonVisibility then Settings.updateSaveButtonVisibility() end
            Settings.showSettingsPage()
        end, Settings.AppSettings.autoSave and COLORS.Green or COLORS.Panel2)
    toggleButton.TextSize = 11

    -- === Your Name Card ===
    local nameCard = makeSettingsCard("Your Name", 100)
    createLabel(nameCard, "This name is displayed above your messages in AI Chat.", UDim2.new(1,-20,0,20), UDim2.fromOffset(10,30), 10, COLORS.Muted)

    local nameBox = make("TextBox",{
        Size=UDim2.new(1,-20,0,36),
        Position=UDim2.fromOffset(10,56),
        BackgroundColor3=COLORS.Panel2,
        BorderSizePixel=0,
        Text=Settings.AppSettings.userName or "You",
        PlaceholderText="You",
        PlaceholderColor3=COLORS.Muted,
        TextColor3=COLORS.Text,
        TextSize=12,
        Font=Enum.Font.Gotham,
        ClearTextOnFocus=false,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=54,
    },nameCard)
    addCorner(nameBox,6)

    nameBox.FocusLost:Connect(function()
        local v = trim(nameBox.Text)
        if v == "" then v = "You" end
        Settings.AppSettings.userName = v
        Settings.saveSettings()
        nameBox.Text = v
    end)

    -- === Device Mode Card ===
    local deviceCard = makeSettingsCard("Device Mode", 110)
    local deviceNote = createLabel(deviceCard,
        "Choose UI size. Phone mode = smaller window. Applies after script restart.",
        UDim2.new(1,-20,0,28), UDim2.fromOffset(10,30),10,COLORS.Muted)
    deviceNote.TextWrapped = true
    deviceNote.TextYAlignment = Enum.TextYAlignment.Top

    local deviceModes = { "auto", "phone", "pc" }
    local deviceLabels = { auto = "Auto", phone = "Phone", pc = "PC" }
    local deviceBtnWidth = math.floor((windowWidth - 24 - 28 - 4*6) / 3)
    for index, mode in ipairs(deviceModes) do
        local isActive = (Settings.AppSettings.deviceMode or "auto") == mode
        local btn = createButton(deviceCard, deviceLabels[mode], UDim2.fromOffset(deviceBtnWidth, 36),
            UDim2.fromOffset(10 + (index-1)*(deviceBtnWidth+6), 64), function()
                Settings.AppSettings.deviceMode = mode
                Settings.saveSettings()
                Settings.showSettingsPage()
            end, isActive and COLORS.Accent or COLORS.Panel2)
        btn.TextSize = 11
    end

    -- Back Button (anchored to Settings.page, not the scroll)
    createButton(Settings.page,"Back",UDim2.new(1,-24,0,36),UDim2.new(0,12,1,-44),function()
        showProjectsPage()
    end,COLORS.Panel2).TextSize = 11
end
createLabel(projectsPage,"Saved projects",UDim2.new(1,-24,0,24),UDim2.fromOffset(14,55),13,COLORS.Muted,Enum.Font.GothamMedium)
local projectList=make("ScrollingFrame",{Name="ProjectList",Position=UDim2.fromOffset(12,82),Size=UDim2.new(1,-24,1,-145),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.fromOffset(0,0)},projectsPage)
local projectLayout=make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},projectList)
projectLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() projectList.CanvasSize=UDim2.fromOffset(0,projectLayout.AbsoluteContentSize.Y+8) end)
local function syncEditorToFile(project,src)
    if not project then return nil end
    ensureProjectStructure(project)
    local file=getProjectFile(project,project.activeFile)
    if not file then file={path=project.activeFile or "main.lua",code="",autoExecute=false}; table.insert(project.files,file) end
    if src~=nil then
        file.code=src
    end
    project.code=file.code or ""; project.updated=os.time()
    return file
end
Settings.autoSavePending = false
Settings.autoSaveDelay = 1.5
Settings.autoSaveToken = 0
Settings.debouncedAutoSave = function()
    if not Settings.AppSettings.autoSave or not currentProject then return end
    Settings.autoSavePending = true
    Settings.autoSaveToken = Settings.autoSaveToken + 1
    local requestToken = Settings.autoSaveToken
    local targetProject = currentProject
    task.delay(Settings.autoSaveDelay,function()
        if requestToken ~= Settings.autoSaveToken then return end
        Settings.autoSavePending = false
        if not Settings.AppSettings.autoSave or currentProject ~= targetProject then return end
        local source
        if BigCode.mode and BigCode.getSource then
            source = BigCode.getSource()
        elseif editorBox then
            source = editorBox.Text
        end
        if source ~= nil then
            syncEditorToFile(targetProject,source)
        end
        local saved = saveData()
        if saved and editorStatus then
            editorStatus.Text = "Auto-saved - " .. getProjectSize(targetProject)
            editorStatus.TextColor3 = COLORS.Green
        elseif editorStatus then
            editorStatus.Text = "Auto-save: session only"
            editorStatus.TextColor3 = COLORS.Yellow
        end
    end)
end
BigCode.syncCurrentFile = function()
    if not currentProject then return nil end
    local source = BigCode.mode and BigCode.getSource() or (editorBox and editorBox.Text or "")
    return syncEditorToFile(currentProject, source)
end
local function updateProjectCardMeta(project,l)
    if l then l.Text="Roblox project  -  "..getProjectSize(project).."  -  "..tostring(#project.files).." file(s)" end
end
local function showTextPopup(titleText,initialText,confirmText,onConfirm)
    local overlay=make("Frame",{Name="InputOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.38,BorderSizePixel=0,ZIndex=80,Active=true},window)
    local pw=math.min(360,windowWidth-30); local ph=194
    local popup=make("Frame",{Size=UDim2.fromOffset(pw,ph),Position=UDim2.new(0.5,-pw/2,0.5,-ph/2),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=81,Active=true},overlay)
    addCorner(popup,10); addStroke(popup,COLORS.Border)
    local title=createLabel(popup,titleText,UDim2.new(1,-24,0,28),UDim2.fromOffset(14,10),15,COLORS.Text,Enum.Font.GothamBold); title.ZIndex=82
    local input=make("TextBox",{Size=UDim2.new(1,-28,0,40),Position=UDim2.fromOffset(14,55),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,
        Text=initialText or "",PlaceholderText="Enter a name",PlaceholderColor3=COLORS.Muted,TextColor3=COLORS.Text,TextSize=13,Font=Enum.Font.Gotham,
        ClearTextOnFocus=false,ZIndex=82},popup)
    addCorner(input,7)
    local msg=createLabel(popup,"",UDim2.new(1,-28,0,18),UDim2.fromOffset(14,99),10,COLORS.Red); msg.ZIndex=82
    local cancel=createButton(popup,"Cancel",UDim2.fromOffset(88,32),UDim2.new(1,-190,1,-44),function() overlay:Destroy() end); cancel.ZIndex=82
    local confirm=createButton(popup,confirmText or "Confirm",UDim2.fromOffset(88,32),UDim2.new(1,-102,1,-44),function()
        local v=trim(input.Text)
        if v=="" then msg.Text="Name cannot be empty."; return end
        local ok,err=onConfirm(v)
        if ok then overlay:Destroy() else msg.Text=tostring(err or "Failed.") end
    end,COLORS.Accent); confirm.ZIndex=82
    return overlay,input
end
local function createProject(name)
    name=trim(name); if name=="" then name="My project" end
    local nc="-- "..name.."\n\n"
    local p={id=tostring(os.time()).."_"..tostring(math.random(1000,9999)),name=name,code=nc,
        files={{path="main.lua",code=nc,autoExecute=false}},folders={},activeFile="main.lua",mainFile="main.lua",updated=os.time()}
    table.insert(projects,p)
    local s,m=saveData()
    if renderProjects then renderProjects() end
    logConsole(s and "Success" or "Warning",s and ("Created project: "..name) or ("Session only. "..m))
end
local function showCreateProjectPopup()
    showTextPopup("Create project","My project","Create",function(v) createProject(v); return true end)
end
local function showRenameProjectPopup(project)
    showTextPopup("Rename project",project.name,"Rename",function(v)
        local old=project.name; project.name=v; project.updated=os.time()
        local s,m=saveData()
        if renderProjects then renderProjects() end
        logConsole(s and "Success" or "Warning",s and ("Renamed "..old.." to "..v) or ("Session only. "..m))
        return true
    end)
end
local function openProject(project)
    if currentProject and (BigCode.mode or (editorBox and editorBox.TextEditable)) then
        BigCode.syncCurrentFile()
        saveData()
    end
    if BigCode.clearMode then BigCode.clearMode() end
    currentProject=project
    ensureProjectStructure(project)
    editorBox.TextEditable=false
    editorBox.Text=""
    editorBox.PlaceholderText="Select a file from the project tree..."
    if editorViewport then editorViewport.CanvasPosition=Vector2.new(0,0) end
    selectedTreePath=""
    selectedTreeIsFolder=true
    Settings.ProjectNavigation.currentViewDir = ""
    Settings.ProjectNavigation.viewingFile = false
    refreshEditorFileHeader(nil)
    if updatePathBar then updatePathBar() end
    headerSubtitle.Text=project.name
    projectsPage.Visible=false; executePage.Visible=false; editorPage.Visible=true

    -- Tree view: show only the project tree across the editor surface.
    if Settings.ProjectNavigation.treePanel then
        Settings.ProjectNavigation.treePanel.Visible = true
        Settings.ProjectNavigation.treePanel.Position = UDim2.fromOffset(7, 7)
        Settings.ProjectNavigation.treePanel.Size = UDim2.new(1, -14, 1, -14)
    end
    if Settings.ProjectNavigation.codePanel then
        Settings.ProjectNavigation.codePanel.Visible = false
        Settings.ProjectNavigation.codePanel.Position = UDim2.fromOffset(Settings.ProjectNavigation.treePanelWidth + 14, 0)
        Settings.ProjectNavigation.codePanel.Size = UDim2.new(1, -(Settings.ProjectNavigation.treePanelWidth + 21), 1, 0)
    end
    if editorViewport then editorViewport.Visible = false end
    if Settings.ProjectNavigation.gutterBg then Settings.ProjectNavigation.gutterBg.Visible = false end
    if Settings.ProjectNavigation.newlineButton then Settings.ProjectNavigation.newlineButton.Visible = false end
    if Settings.ProjectNavigation.pasteButton then Settings.ProjectNavigation.pasteButton.Visible = false end
    if editorFileLabel then editorFileLabel.Visible = false end
    if Settings.ProjectNavigation.editorMenu then Settings.ProjectNavigation.editorMenu.Visible = false end
    if toolsPanel then toolsPanel.Visible = false end
    if Settings.ProjectNavigation.backButton then
        Settings.ProjectNavigation.backButton.Text = "←"
        Settings.ProjectNavigation.backButton.Size = UDim2.fromOffset(34, 30)
        Settings.ProjectNavigation.backButton.TextSize = 18
    end
    if Settings.ProjectNavigation.treeToggleButton then
        Settings.ProjectNavigation.treeToggleButton.Visible = true
        Settings.ProjectNavigation.treeToggleButton.Active = false
        Settings.ProjectNavigation.treeToggleButton.AutoButtonColor = false
        Settings.ProjectNavigation.treeToggleButton.TextColor3 = COLORS.Muted
    end
    editorBox.Visible = false
    editorBox.TextEditable = false

    editorStatus.Text="Project opened"; editorStatus.TextColor3=COLORS.Green
    consoleEntries={}
    logConsole("Info","Opened project: "..project.name)
    if renderFileTree then renderFileTree() end
end
renderProjects=function()
    for _,c in ipairs(projectList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    for i,project in ipairs(projects) do
        ensureProjectStructure(project)
        local card=make("Frame",{Name="ProjectCard_"..tostring(project.id),Size=UDim2.new(1,-8,0,104),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,LayoutOrder=i},projectList)
        addCorner(card,9); addStroke(card,COLORS.Border,0.45)
        local nl=createLabel(card,project.name,UDim2.new(1,-24,0,24),UDim2.fromOffset(14,7),14,COLORS.Text,Enum.Font.GothamBold); nl.TextTruncate=Enum.TextTruncate.AtEnd
        local ml=createLabel(card,"",UDim2.new(1,-24,0,18),UDim2.fromOffset(14,31),10,COLORS.Muted)
        updateProjectCardMeta(project,ml)
        local ob=createButton(card,"Open Project",UDim2.fromOffset(compact and 104 or 126,30),UDim2.fromOffset(12,64),function() openProject(project) end,COLORS.Accent)
        ob.TextSize=compact and 10 or 11
        local rx=compact and 124 or 148
        local rb=createButton(card,"Rename",UDim2.fromOffset(compact and 76 or 88,30),UDim2.fromOffset(rx,64),function() showRenameProjectPopup(project) end,COLORS.Panel2); rb.TextSize=10
        local dx=rx+(compact and 82 or 94)
        local db=createButton(card,"Delete",UDim2.fromOffset(compact and 68 or 78,30),UDim2.fromOffset(dx,64),function()
            local pn=project.name
            if currentProject==project then currentProject=nil end
            for pi,ex in ipairs(projects) do if ex.id==project.id then table.remove(projects,pi); break end end
            local s,m=saveData(); renderProjects(); if renderExecutePage then renderExecutePage() end
            logConsole(s and "Success" or "Warning",s and ("Deleted: "..pn) or ("Session only. "..m))
        end,Color3.fromRGB(105,47,57)); db.TextSize=10
    end
    if #projects==0 then
        local empty=make("Frame",{Size=UDim2.new(1,-8,0,104),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,LayoutOrder=1},projectList)
        addCorner(empty,9)
        createLabel(empty,"No projects yet",UDim2.new(1,-20,0,26),UDim2.fromOffset(12,20),14,COLORS.Text,Enum.Font.GothamBold)
        createLabel(empty,"Press Add Project to create your first project.",UDim2.new(1,-20,0,22),UDim2.fromOffset(12,49),11,COLORS.Muted)
    end
end
local addProjectButton=createButton(projectsPage,"+  Add Project",UDim2.new(1,-24,0,42),UDim2.new(0,12,1,-50),showCreateProjectPopup,COLORS.Accent)
createButton(executePage,"Projects",UDim2.fromOffset(125,34),UDim2.fromOffset(12,8),showProjectsPage,COLORS.Panel2)
createLabel(executePage,"Execute saved files",UDim2.new(1,-164,0,24),UDim2.fromOffset(148,8),14,COLORS.Text,Enum.Font.GothamBold)
local exDesc=createLabel(executePage,"Run files you wrote or are authorized to test. Auto Execute files run when Easy Scripting loads.",UDim2.new(1,-164,0,34),UDim2.fromOffset(148,32),9,COLORS.Muted)
exDesc.TextWrapped=true
local executeList=make("ScrollingFrame",{Name="ExecuteList",Position=UDim2.fromOffset(12,76),Size=UDim2.new(1,-24,1,-132),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.fromOffset(0,0)},executePage)
local executeLayout=make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},executeList)
executeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() executeList.CanvasSize=UDim2.fromOffset(0,executeLayout.AbsoluteContentSize.Y+8) end)
Settings.resolveModulePath = function(fromPath, requestedPath, project)
    local cleaned = tostring(requestedPath or ""):gsub("\\", "/")
    if cleaned == "" then return nil, "empty path" end
    local basePath
    if cleaned:sub(1, 1) == "/" then
        basePath = cleaned:sub(2)
    else
        local dir = parentPath(fromPath or "")
        basePath = (dir ~= "" and (dir .. "/" .. cleaned) or cleaned)
    end
    local parts = {}
    for part in basePath:gmatch("[^/]+") do
        if part == ".." then
            if #parts > 0 then table.remove(parts) end
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end
    local resolved = table.concat(parts, "/")
    if resolved == "" then return nil, "resolved to empty path" end
    if not resolved:match("%.[%w_%-]+$") then
        if getProjectFile(project, resolved .. ".lua") then
            resolved = resolved .. ".lua"
        elseif getProjectFile(project, resolved .. ".luau") then
            resolved = resolved .. ".luau"
        end
    end
    if not getProjectFile(project, resolved) then
        return nil, "module not found: " .. resolved
    end
    return resolved
end
Settings.scanRequires = function(source)
    source = tostring(source or "")
    source = source:gsub("%-%-%[%[.-%]%]", "")
    source = source:gsub("%-%-[^\n]*", "")
    local found = {}
    local seen = {}
    for path in source:gmatch([[require%s*%(%s*["']([^"']+)["']%s*%)]]) do
        if not seen[path] then
            seen[path] = true
            table.insert(found, path)
        end
    end
    return found
end
Settings.discoverAllDependencies = function(project, entryPath)
    local discovered = {}
    local seen = {}
    local queue = { entryPath }
    local warnings = {}
    local queueIndex = 1
    while queueIndex <= #queue do
        local current = queue[queueIndex]
        queueIndex = queueIndex + 1
        if not seen[current] then
            seen[current] = true
            local file = getProjectFile(project, current)
            if file then
                local reqs = Settings.scanRequires(file.code or "")
                for _, reqPath in ipairs(reqs) do
                    local resolved, err = Settings.resolveModulePath(current, reqPath, project)
                    if resolved then
                        if not seen[resolved] then
                            table.insert(discovered, resolved)
                            table.insert(queue, resolved)
                        end
                    else
                        table.insert(warnings, current .. " requires '" .. reqPath .. "': " .. tostring(err))
                    end
                end
            end
        end
    end
    return discovered, warnings
end
Settings.buildRequire = function(baseSandbox, project, fromPath)
    local cache = Settings.ProjectModules.cache
    local stack = Settings.ProjectModules.stack
    local realRequire = (type(getgenv) == "function" and pcall(getgenv) and getgenv().require) or require
    local function requireImpl(target)
        if typeof(target) == "Instance" then
            if type(realRequire) ~= "function" then
                error("require: Instance require unavailable", 2)
            end
            return realRequire(target)
        end
        if type(target) ~= "string" then
            error("require: expected string path or Instance, got " .. type(target), 2)
        end
        local resolved, err = Settings.resolveModulePath(fromPath, target, project)
        if not resolved then
            error("require: " .. tostring(err), 2)
        end
        if cache[resolved] ~= nil then
            return cache[resolved]
        end
        for _, path in ipairs(stack) do
            if path == resolved then
                error("require: circular dependency: " .. resolved, 2)
            end
        end
        local file = getProjectFile(project, resolved)
        if not file then
            error("require: file disappeared: " .. resolved, 2)
        end
        local src = file.code or ""
        local loader, parseErr = loadstring("return function(...)\n" .. src .. "\nend", "@" .. resolved)
        if not loader then
            error("require: syntax error in " .. resolved .. ": " .. tostring(parseErr), 2)
        end
        local modEnv = setmetatable({}, { __index = baseSandbox })
        modEnv.require = Settings.buildRequire(modEnv, project, resolved)
        if type(setfenv) == "function" then
            pcall(function() setfenv(loader, modEnv) end)
        end
        table.insert(stack, resolved)
        local okCompile, moduleFn = pcall(loader)
        if not okCompile then
            table.remove(stack)
            error("require: compile failed for " .. resolved .. ": " .. tostring(moduleFn), 2)
        end
        local okRun, result = pcall(moduleFn)
        table.remove(stack)
        if not okRun then
            error("require: error in " .. resolved .. ": " .. tostring(result), 2)
        end
        cache[resolved] = result
        return result
    end
    return requireImpl
end
Settings.preloadModules = function(project, entryPath, sandbox)
    local PM = Settings.ProjectModules
    if not PM.preloadEnabled then
        return { total = 0, failed = 0, skipped = true }
    end
    local discovered, scanWarnings = Settings.discoverAllDependencies(project, entryPath)
    local failed = 0
    local loaded = 0
    local failMessages = {}
    for _, modPath in ipairs(discovered) do
        if PM.cache[modPath] == nil then
            local ok, err = pcall(sandbox.require, "/" .. modPath)
            if ok then
                loaded = loaded + 1
            else
                failed = failed + 1
                table.insert(failMessages, modPath .. ": " .. tostring(err))
            end
        end
    end
    if #failMessages > 0 then
        logConsole("Warning", "Preload failed for " .. tostring(#failMessages) .. " module(s):\n" .. table.concat(failMessages, "\n"))
    end
    for _, warning in ipairs(scanWarnings) do
        logConsole("Warning", "Scan: " .. warning)
    end
    PM.lastPreloadReport = {
        total = #discovered,
        loaded = loaded,
        failed = failed,
        warnings = #scanWarnings,
    }
    if #discovered > 0 then
        local msg = "Preloaded " .. tostring(loaded) .. " module(s)"
        if failed > 0 then msg = msg .. " (" .. tostring(failed) .. " failed)" end
        if #scanWarnings > 0 then msg = msg .. " (" .. tostring(#scanWarnings) .. " scan warnings)" end
        logConsole(failed > 0 and "Warning" or "Info", msg)
    end
    return PM.lastPreloadReport
end
Settings.executeSnapshotState = function()
    local EC = Settings.ExecuteControl
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    EC.snapshot = {
        cframe = root and root.CFrame or nil,
        walkSpeed = hum and hum.WalkSpeed or nil,
        jumpPower = hum and hum.JumpPower or nil,
        jumpHeight = hum and hum.JumpHeight or nil,
        hipHeight = hum and hum.HipHeight or nil,
        cameraType = cam and cam.CameraType or nil,
        cameraSubject = cam and cam.CameraSubject or nil,
    }
end
Settings.executeRestoreState = function()
    local EC = Settings.ExecuteControl
    local snap = EC.snapshot
    if not snap then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    if hum then
        if snap.walkSpeed ~= nil then pcall(function() hum.WalkSpeed = snap.walkSpeed end) end
        if snap.jumpPower ~= nil then pcall(function() hum.JumpPower = snap.jumpPower end) end
        if snap.jumpHeight ~= nil then pcall(function() hum.JumpHeight = snap.jumpHeight end) end
        if snap.hipHeight ~= nil then pcall(function() hum.HipHeight = snap.hipHeight end) end
        pcall(function() hum:Move(Vector3.zero, false) end)
    end
    if root and snap.cframe then pcall(function() root.CFrame = snap.cframe end) end
    if cam then
        if snap.cameraType ~= nil then pcall(function() cam.CameraType = snap.cameraType end) end
        if snap.cameraSubject ~= nil then pcall(function() cam.CameraSubject = snap.cameraSubject end) end
    end
    EC.snapshot = nil
end
Settings.executeBuildSandbox = function()
    local EC = Settings.ExecuteControl
    local baseEnv = (type(getfenv) == "function" and pcall(getfenv, 0) and getfenv(0)) or _G
    local sandbox = setmetatable({}, { __index = baseEnv })
    local taskWrapper = {}
    for k, v in pairs(baseEnv.task or task) do taskWrapper[k] = v end
    taskWrapper.wait = function(t)
        if EC.killFlag then error("Easy Scripting: execution stopped", 0) end
        return baseEnv.task.wait(t)
    end
    taskWrapper.spawn = function(fn, ...)
        if EC.killFlag then return end
        local args = table.pack(...)
        return baseEnv.task.spawn(function()
            if EC.killFlag then return end
            return fn(table.unpack(args, 1, args.n))
        end)
    end
    taskWrapper.defer = function(fn, ...)
        if EC.killFlag then return end
        local args = table.pack(...)
        return baseEnv.task.defer(function()
            if EC.killFlag then return end
            return fn(table.unpack(args, 1, args.n))
        end)
    end
    taskWrapper.delay = function(t, fn, ...)
        local args = table.pack(...)
        return baseEnv.task.delay(t, function()
            if EC.killFlag then return end
            return fn(table.unpack(args, 1, args.n))
        end)
    end
    sandbox.task = taskWrapper
    sandbox.wait = taskWrapper.wait
    sandbox.spawn = taskWrapper.spawn
    sandbox.delay = taskWrapper.delay
    local rs = game:GetService("RunService")
    local function wrapSignal(signal)
        return setmetatable({}, {
            __index = function(_, key)
                if key == "Connect" or key == "connect" then
                    return function(_, fn)
                        if EC.killFlag then return { Disconnect = function() end } end
                        local conn = signal:Connect(function(...)
                            if EC.killFlag then return end
                            return fn(...)
                        end)
                        table.insert(EC.connections, conn)
                        return conn
                    end
                end
                return signal[key]
            end,
        })
    end
    sandbox.RunService = setmetatable({
        Heartbeat = wrapSignal(rs.Heartbeat),
        RenderStepped = wrapSignal(rs.RenderStepped),
        Stepped = wrapSignal(rs.Stepped),
    }, { __index = rs })
    return sandbox
end
Settings.executeStopInternal = function(reason, skipRestore)
    local EC = Settings.ExecuteControl
    if not EC.running and not EC.killFlag then return end
    EC.killFlag = true
    for _, conn in ipairs(EC.connections) do
        pcall(function() conn:Disconnect() end)
    end
    EC.connections = {}
    if not skipRestore then
        Settings.executeRestoreState()
    end
    EC.running = false
    EC.activeChunkName = nil
    if EC.stopBtn then EC.stopBtn.Visible = false end
    if screenGui then screenGui.Enabled = true end
    if floatingButton then floatingButton.Visible = false end
    logConsole("Info", "Execute stopped" .. (reason and (": " .. tostring(reason)) or ""))
    if renderExecutePage then renderExecutePage() end
end
Settings.executeStop = function() Settings.executeStopInternal("user") end
local function executeProjectFile(project, file, openOutput, mode)
    mode = mode or "test"
    if not project or not file then return false end
    if not isScriptFile(file.path) then
        logConsole("Warning", "Only .lua/.luau execute: " .. tostring(file.path))
        if openOutput then openConsole() end
        return false
    end
    local src = file.code or ""
    if trim(src) == "" then
        logConsole("Warning", project.name .. "/" .. file.path .. " is empty.")
        if openOutput then openConsole() end
        return false
    end
    if type(loadstring) ~= "function" then
        logConsole("Error", "loadstring unavailable.")
        if openOutput then openConsole() end
        return false
    end
    if mode == "run" then
        local EC = Settings.ExecuteControl
        if EC.running then
            logConsole("Warning", "Another execution is already running. Stop it first.")
            if openOutput then openConsole() end
            return false
        end
        local ok, chunk, err = pcall(loadstring, src, "@" .. project.name .. "/" .. file.path)
        if not ok or type(chunk) ~= "function" then
            local message = tostring(ok and err or chunk)
            logConsole("Error", project.name .. "/" .. file.path .. ": " .. message, getLineNumber(message))
            if openOutput then openConsole() end
            return false
        end
        EC.running = true
        EC.killFlag = false
        EC.activeChunkName = project.name .. "/" .. file.path
        if screenGui then screenGui.Enabled = false end
        if floatingButton then floatingButton.Visible = false end
        logConsole("Info", "Running project: " .. project.name)
        task.spawn(function()
            local runOk, runError = pcall(chunk)
            EC.running = false
            EC.activeChunkName = nil
            if screenGui then screenGui.Enabled = true end
            if runOk then
                logConsole("Success", project.name .. " was successfully executed")
            else
                local message = tostring(runError)
                logConsole("Error", project.name .. " execution failed:\n" .. message, getLineNumber(message))
            end
            if renderExecutePage then renderExecutePage() end
        end)
        if openOutput then openConsole() end
        return true
    end
    local EC = Settings.ExecuteControl
    if EC.running then
        logConsole("Warning", "Another execution is already running. Stop it first.")
        if openOutput then openConsole() end
        return false
    end
    local ok, chunk, err = pcall(loadstring, src, "@" .. project.name .. "/" .. file.path)
    if not ok or type(chunk) ~= "function" then
        local message = tostring(ok and err or chunk)
        logConsole("Error", project.name .. "/" .. file.path .. ": " .. message, getLineNumber(message))
        if openOutput then openConsole() end
        return false
    end
    EC.running = true
    EC.killFlag = false
    EC.connections = {}
    EC.activeChunkName = project.name .. "/" .. file.path
    Settings.executeSnapshotState()
    local sandbox = Settings.executeBuildSandbox()
    Settings.ProjectModules.cache = {}
    Settings.ProjectModules.stack = {}
    sandbox.require = Settings.buildRequire(sandbox, project, file.path)
    sandbox._project = project
    sandbox._currentFile = file.path
    local sandboxApplied = false
    if type(setfenv) == "function" then
        local okSet = pcall(function() setfenv(chunk, sandbox) end)
        sandboxApplied = okSet
    end
    if not sandboxApplied then
        logConsole("Warning", "Sandbox unavailable — require() inside project files will not work. Script runs in global environment.")
    else
        logConsole("Info", "Sandbox mode — sandbox active, require() available.")
        local report = Settings.preloadModules(project, file.path, sandbox)
        if report and report.total and report.total > 0 then
            logConsole("Info", "Dependency graph resolved: " .. tostring(report.total) .. " module(s) discovered.")
        end
    end
    if screenGui then screenGui.Enabled = false end
    if floatingButton then floatingButton.Visible = false end
    if EC.stopBtn then EC.stopBtn.Visible = true end
    logConsole("Info", "Sandbox started: " .. project.name)
    task.spawn(function()
        local runOk, runError = pcall(chunk)
        if runOk then
            logConsole("Success", project.name .. " was successfully executed (sandbox)")
        else
            local message = tostring(runError)
            if not message:find("Easy Scripting: execution stopped", 1, true) then
                logConsole("Error", project.name .. " execution failed (sandbox):\n" .. message, getLineNumber(message))
            end
        end
        -- Авто-стоп убран (по прошлой спеке)
    end)
    if openOutput then openConsole() end
    return true
end
renderExecutePage=function()
    for _,c in ipairs(executeList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local order=0
    for _,project in ipairs(projects) do
        ensureProjectStructure(project)
        local mainFile=getProjectFile(project,project.mainFile)
        if mainFile and isScriptFile(mainFile.path) then
            order=order+1
            local row=make("Frame",{Name="ExecuteFileRow",Size=UDim2.new(1,-8,0,70),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,LayoutOrder=order},executeList)
            addCorner(row,8); addStroke(row,COLORS.Border,0.5)
            local fl=createLabel(row,"⭐ "..project.name,UDim2.new(1,-210,0,24),UDim2.fromOffset(11,7),10,COLORS.Text,Enum.Font.GothamMedium); fl.TextTruncate=Enum.TextTruncate.AtEnd
            createLabel(row,formatBytes(#(mainFile.code or "")),UDim2.fromOffset(100,18),UDim2.fromOffset(11,34),9,COLORS.Muted)
            local rb=createButton(row,"Run",UDim2.fromOffset(58,28),UDim2.new(1,-194,0,10),function() executeProjectFile(project,mainFile,true,"run") end,COLORS.Accent); rb.TextSize=10
            local ab=createButton(row,mainFile.autoExecute and "Auto: ON" or "Auto: OFF",UDim2.fromOffset(92,28),UDim2.new(1,-128,0,10),function()
                mainFile.autoExecute=not mainFile.autoExecute
                local s,m=saveData(); renderExecutePage()
                logConsole(s and "Success" or "Warning",s and (mainFile.path.." Auto: "..(mainFile.autoExecute and "ON" or "OFF")) or m)
            end,mainFile.autoExecute and COLORS.Green or COLORS.Panel2); ab.TextSize=9
        end
        for _,file in ipairs(project.files) do
            if file.path~=project.mainFile then file.autoExecute=false end
        end
    end
    if order==0 then
        local empty=make("Frame",{Size=UDim2.new(1,-8,0,90),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,LayoutOrder=1},executeList)
        addCorner(empty,8)
        createLabel(empty,"No main files",UDim2.new(1,-20,0,25),UDim2.fromOffset(12,14),13,COLORS.Text,Enum.Font.GothamBold)
        createLabel(empty,"Set a main file via Editor → Set as Main.",UDim2.new(1,-20,0,20),UDim2.fromOffset(12,44),10,COLORS.Muted)
    end
end
local runAutoFilesButton=createButton(executePage,"Run Auto Execute Files",UDim2.new(1,-24,0,40),UDim2.new(0,12,1,-48),function()
    if Settings.ExecuteControl.running then
        logConsole("Warning","Execute already running. Stop it first.")
        openConsole()
        return
    end
    local count=0
    for _,project in ipairs(projects) do
        ensureProjectStructure(project)
        local mainFile=getProjectFile(project,project.mainFile)
        if mainFile and isScriptFile(mainFile.path) and mainFile.autoExecute then
            count=count+1
            executeProjectFile(project,mainFile,false,"run")
        end
    end
    if count==0 then logConsole("Info","No main files marked Auto Execute.") end
    openConsole()
end,COLORS.Accent); runAutoFilesButton.TextSize=11
local navBar=make("Frame",{Name="EditorNavBar",Size=UDim2.new(1,-20,0,36),Position=UDim2.fromOffset(10,5),BackgroundTransparency=1},editorPage)
local actionBar=make("ScrollingFrame",{Name="EditorActionBar",Size=UDim2.new(1,-20,0,36),Position=UDim2.fromOffset(10,44),BackgroundTransparency=1,ScrollBarThickness=4,ScrollBarImageColor3=COLORS.Muted,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.fromOffset(0,0),BorderSizePixel=0,Active=true},editorPage)
Settings.actionBarContent=make("Frame",{Name="EditorActionBarContent",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1},actionBar)
local pathBarUpdating=false
local pathBarParts={inputOriginalText=""}
local pathBar=make("Frame",{Name="PathBar",Size=UDim2.new(1,-222,1,0),Position=UDim2.fromOffset(88,0),
    BackgroundColor3=COLORS.Panel2,BorderSizePixel=0},navBar)
addCorner(pathBar,7); addStroke(pathBar,COLORS.Border,0.5)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center},pathBar)
make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},pathBar)
pathBarParts.prefixLabel=make("TextLabel",{Size=UDim2.new(0,0,1,0),BackgroundTransparency=1,Text="",
    TextColor3=COLORS.Muted,TextSize=compact and 9 or 11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=1},pathBar)
pathBarParts.input=make("TextBox",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",
    PlaceholderText="file.lua",PlaceholderColor3=COLORS.Muted,TextColor3=COLORS.Text,
    TextSize=compact and 9 or 11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false,LayoutOrder=2},pathBar)
pathBarParts.updateSize=function()
    local prefixLabel=pathBarParts.prefixLabel
    local input=pathBarParts.input
    if not prefixLabel or not input then return end
    local w=0
    if prefixLabel.Text~="" then
        w=TextService:GetTextSize(prefixLabel.Text,prefixLabel.TextSize,prefixLabel.Font,Vector2.new(100000,100000)).X
    end
    prefixLabel.Size=UDim2.new(0,w,1,0)
    input.Size=UDim2.new(1,-w,1,0)
end
pathBarParts.prefixLabel:GetPropertyChangedSignal("Text"):Connect(pathBarParts.updateSize)
Settings.ProjectNavigation.backButton=createButton(navBar,"←",UDim2.fromOffset(34,30),UDim2.fromOffset(0,3),function()
    -- The arrow always returns to the Home projects page.
    if currentProject and (BigCode.mode or editorBox.TextEditable) then
        BigCode.syncCurrentFile()
        saveData()
    end
    if Settings.ProjectNavigation.viewingFile then
        if BigCode.clearMode then BigCode.clearMode() end
        Settings.ProjectNavigation.viewingFile = false
        editorBox.TextEditable = false
        editorBox.Visible = false
    end
    if Settings.ProjectNavigation.editorMenu then Settings.ProjectNavigation.editorMenu.Visible = false end
    if toolsPanel then toolsPanel.Visible = false end
    if Settings.ProjectNavigation.treeToggleButton then
        Settings.ProjectNavigation.treeToggleButton.Active = false
        Settings.ProjectNavigation.treeToggleButton.AutoButtonColor = false
        Settings.ProjectNavigation.treeToggleButton.TextColor3 = COLORS.Muted
    end
    editorPage.Visible=false
    projectsPage.Visible=true
    headerSubtitle.Text="HOME"
    renderProjects()
end,COLORS.Panel2)
Settings.ProjectNavigation.backButton.TextSize=18
Settings.ProjectNavigation.treeToggleButton=createButton(navBar,"Tree",UDim2.fromOffset(48,30),UDim2.fromOffset(38,3),function()
    local nav = Settings.ProjectNavigation
    if not nav.viewingFile then return end

    -- Save the current file, then switch from the editor to the full-screen tree.
    if currentProject and (BigCode.mode or editorBox.TextEditable) then
        BigCode.syncCurrentFile()
        saveData()
    end
    if BigCode.clearMode then BigCode.clearMode() end
    nav.viewingFile = false
    editorBox.TextEditable = false
    editorBox.Visible = false

    if nav.treePanel then
        nav.treePanel.Visible = true
        nav.treePanel.Position = UDim2.fromOffset(7, 7)
        nav.treePanel.Size = UDim2.new(1, -14, 1, -14)
    end
    if nav.codePanel then
        nav.codePanel.Visible = false
        nav.codePanel.Position = UDim2.fromOffset(nav.treePanelWidth + 14, 0)
        nav.codePanel.Size = UDim2.new(1, -(nav.treePanelWidth + 21), 1, 0)
    end
    if editorViewport then editorViewport.Visible = false end
    if nav.gutterBg then nav.gutterBg.Visible = false end
    if nav.newlineButton then nav.newlineButton.Visible = false end
    if nav.pasteButton then nav.pasteButton.Visible = false end
    if editorFileLabel then editorFileLabel.Visible = false end
    if nav.editorMenu then nav.editorMenu.Visible = false end
    if toolsPanel then toolsPanel.Visible = false end

    if nav.backButton then
        nav.backButton.Text = "←"
        nav.backButton.Size = UDim2.fromOffset(34, 30)
        nav.backButton.TextSize = 18
    end
    nav.treeToggleButton.Active = false
    nav.treeToggleButton.AutoButtonColor = false
    nav.treeToggleButton.TextColor3 = COLORS.Muted
    if updatePathBar then updatePathBar() end
    if renderFileTree then renderFileTree() end
    editorStatus.Text = "Project tree"
    editorStatus.TextColor3 = COLORS.Muted
end,COLORS.Panel2)
Settings.ProjectNavigation.treeToggleButton.TextSize=compact and 9 or 10
Settings.ProjectNavigation.treeToggleButton.Visible = true
Settings.ProjectNavigation.treeToggleButton.Active = false
Settings.ProjectNavigation.treeToggleButton.AutoButtonColor = false
Settings.ProjectNavigation.treeToggleButton.TextColor3 = COLORS.Muted
local pathCommitButton
local pathCancelButton
pathCommitButton=createButton(navBar,"Save",UDim2.fromOffset(58,30),UDim2.new(1,-120,0,3),function()
    -- Always save the current editor source first.
    if currentProject then
        local textToSave
        if BigCode.mode then
            textToSave = BigCode.getSource()
            syncEditorToFile(currentProject, textToSave)
        elseif editorBox.TextEditable then
            textToSave = editorBox.Text
            syncEditorToFile(currentProject, textToSave)
        end
        local saved, message = saveData()
        if saved then
            editorStatus.Text = "Saved - " .. getProjectSize(currentProject)
            editorStatus.TextColor3 = COLORS.Green
            logConsole("Success", "Saved " .. currentProject.name)
        else
            editorStatus.Text = "Session copy updated"
            editorStatus.TextColor3 = COLORS.Yellow
            logConsole("Warning", message)
        end
    end

    -- If the path was edited, also rename the selected item.
    if pathBarParts.input.Text ~= pathBarParts.inputOriginalText then
        if selectedTreePath=="" then
            pathBarUpdating=true
            pathBarParts.input.Text=pathBarParts.inputOriginalText
            pathBarUpdating=false
            pathCommitButton.Text="Save"
            pathCancelButton.Visible=false
            return
        end
        if not currentProject or not renameSelectedPath then return end
        local typedSuffix=trim(pathBarParts.input.Text)
        local prefixText=pathBarParts.prefixLabel.Text
        local projectPrefix=currentProject.name.." / "
        local folderPart=""
        if string.sub(prefixText,1,#projectPrefix)==projectPrefix then
            folderPart=string.sub(prefixText,#projectPrefix+1)
            folderPart=folderPart:gsub("%s*/%s*$","")
        end
        local typedPath=typedSuffix
        if folderPart~="" then typedPath=folderPart.."/"..typedSuffix end
        typedPath=typedPath:gsub("%s*/%s*","/")
        local ok,err=renameSelectedPath(typedPath)
        if not ok then
            editorStatus.Text="Rename failed: "..tostring(err or "Invalid path")
            editorStatus.TextColor3=COLORS.Red
            logConsole("Error","Path Bar rename failed: "..tostring(err or "Invalid path"))
        else
            if updatePathBar then updatePathBar() end
        end
    end
    pathCommitButton.Text = "Save"
    pathCancelButton.Visible = false
end,COLORS.Green)
pathCommitButton.TextSize=compact and 8 or 10
pathCommitButton.Visible=true
pathCancelButton=createButton(navBar,"Cancel",UDim2.fromOffset(54,30),UDim2.new(1,-58,0,3),function()
    pathBarUpdating=true
    pathBarParts.input.Text=pathBarParts.inputOriginalText
    pathBarUpdating=false
    pathCommitButton.Text="Save"
    pathCancelButton.Visible=false
end,COLORS.Panel2)
pathCancelButton.TextSize=compact and 8 or 10
pathCancelButton.Visible=false
pathBarParts.input:GetPropertyChangedSignal("Text"):Connect(function()
    if pathBarUpdating then return end
    local changed=pathBarParts.input.Text~=pathBarParts.inputOriginalText
    if changed then
        pathCommitButton.Text = "Commit"
        pathCancelButton.Visible = true
    else
        pathCommitButton.Text = "Save"
        pathCancelButton.Visible = false
    end
end)
Settings.actionBarBtnWidth=88
Settings.actionBarBtnGap=4
Settings.actionBarBtnCount=7
Settings.actionBarContentWidth=4+Settings.actionBarBtnCount*Settings.actionBarBtnWidth+(Settings.actionBarBtnCount-1)*Settings.actionBarBtnGap+4
local function actionButton(text,index,callback,color)
    local x=4+index*(Settings.actionBarBtnWidth+Settings.actionBarBtnGap)
    local button=createButton(Settings.actionBarContent,text,UDim2.fromOffset(Settings.actionBarBtnWidth,28),UDim2.fromOffset(x,4),callback,color or COLORS.Panel2)
    button.TextSize=compact and 8 or 10
    return button
end
Settings.actionBarContent.Size=UDim2.fromOffset(Settings.actionBarContentWidth,32)
actionBar.CanvasSize=UDim2.fromOffset(Settings.actionBarContentWidth,0)
Settings.saveActionButton = nil
Settings.updateSaveButtonVisibility = function()
    local saveActionButton = Settings.saveActionButton
    if not saveActionButton then return end
    if Settings.AppSettings.autoSave then
        saveActionButton.Text = "Auto: ON"
        saveActionButton.BackgroundColor3 = COLORS.Green
        saveActionButton.Active = false
        saveActionButton.AutoButtonColor = false
        saveActionButton.Selectable = false
    else
        saveActionButton.Text = "Save"
        saveActionButton.BackgroundColor3 = COLORS.Panel2
        saveActionButton.Active = true
        saveActionButton.AutoButtonColor = true
        saveActionButton.Selectable = true
    end
end
local editorMenuButton=actionButton("Editor",0,function()
    if not Settings.ProjectNavigation.editorMenu then return end
    Settings.ProjectNavigation.editorMenu.Visible=not Settings.ProjectNavigation.editorMenu.Visible
    if Settings.ProjectNavigation.editorMenu.Visible then
        for _, btn in ipairs(Settings.ProjectNavigation.editorMenu:GetChildren()) do
            if btn:IsA("TextButton") and btn.Text == "Create New" then
                btn.Visible = not Settings.ProjectNavigation.viewingFile
            end
        end
    end
end,COLORS.Accent)
actionButton("AI Chat",1,function()
    if openAIChat then openAIChat() end
end,COLORS.Accent)
actionButton("Tools",2,function()
    if toolsPanel then toolsPanel.Visible=not toolsPanel.Visible end
    if Settings.ProjectNavigation.editorMenu then Settings.ProjectNavigation.editorMenu.Visible=false end
end)
runCheckButton=actionButton("Run",3,function()
    if not currentProject or (not editorBox.TextEditable and not BigCode.mode) then
        logConsole("Warning","Open a file before running a check.")
        openConsole()
        return
    end
    local sourceToRun = BigCode.getSource and BigCode.getSource() or (editorBox.Text or "")
    syncEditorToFile(currentProject,sourceToRun)
    local activePath=currentProject.activeFile or "main.lua"
    local activeFile=getProjectFile(currentProject,activePath)
    local ok,msg,line=validateProjectFile(activeFile,sourceToRun)
    if ok then
        logConsole("Success",activePath..": "..msg)
        editorStatus.Text=isScriptFile(activePath) and "Syntax check passed - not executed" or msg
        editorStatus.TextColor3=COLORS.Green
    else
        logConsole("Error",activePath..": "..msg,line)
        editorStatus.Text=line and ("Syntax error on line "..tostring(line)) or "Syntax check failed"
        editorStatus.TextColor3=COLORS.Red
    end
    openConsole()
end)
actionButton("Console",4,openConsole)
actionButton("Replay",5,function()
    if Settings.openReplayWindow then Settings.openReplayWindow() end
end,COLORS.Accent)
actionButton("Sandbox",6,function()
    if not currentProject then
        logConsole("Warning","Open a project first.")
        openConsole()
        return
    end
    local mainFile=getProjectFile(currentProject,currentProject.mainFile)
    if not mainFile then
        logConsole("Warning","Main file not found in project.")
        openConsole()
        return
    end
    executeProjectFile(currentProject,mainFile,true,"test")
end,COLORS.Accent)
local editorSurface=make("Frame",{Position=UDim2.fromOffset(10,84),Size=UDim2.new(1,-20,1,-119),BackgroundColor3=COLORS.Panel,BorderSizePixel=0},editorPage)
addCorner(editorSurface,8); addStroke(editorSurface,COLORS.Border,0.5)
Settings.ProjectNavigation.treePanelWidth=compact and 106 or 164
Settings.ProjectNavigation.treePanel=make("Frame",{Name="ProjectFileTree",Position=UDim2.fromOffset(7,7),Size=UDim2.new(0,Settings.ProjectNavigation.treePanelWidth,1,-14),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0},editorSurface)
addCorner(Settings.ProjectNavigation.treePanel,7)
createLabel(Settings.ProjectNavigation.treePanel,"FILES",UDim2.new(1,-10,0,20),UDim2.fromOffset(6,4),9,COLORS.Muted,Enum.Font.GothamBold)
local treeListTop=27
local treeList=make("ScrollingFrame",{Name="FileTreeList",Position=UDim2.fromOffset(4,treeListTop),Size=UDim2.new(1,-8,1,-(treeListTop+4)),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0)},Settings.ProjectNavigation.treePanel)
local fileTreeLayout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},treeList)
fileTreeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() treeList.CanvasSize=UDim2.fromOffset(0,fileTreeLayout.AbsoluteContentSize.Y+6) end)
Settings.ProjectNavigation.codePanel=make("Frame",{Name="CodePanel",Position=UDim2.fromOffset(Settings.ProjectNavigation.treePanelWidth+14,0),Size=UDim2.new(1,-(Settings.ProjectNavigation.treePanelWidth+21),1,0),BackgroundTransparency=1},editorSurface)
editorFileLabel=createLabel(Settings.ProjectNavigation.codePanel,"Select a file",UDim2.new(1,-268,0,25),UDim2.fromOffset(3,5),10,COLORS.Muted,Enum.Font.GothamBold)
Settings.ProjectNavigation.newlineButton=createButton(Settings.ProjectNavigation.codePanel,"Enter",UDim2.fromOffset(48,24),UDim2.new(1,-51,0,5),nil,COLORS.Panel2); Settings.ProjectNavigation.newlineButton.TextSize=10
local gutterWidth=34
Settings.ProjectNavigation.gutterBg=make("Frame",{Name="LineNumberGutter",Position=UDim2.fromOffset(3,32),Size=UDim2.new(0,gutterWidth,1,-38),
    BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,ClipsDescendants=true},Settings.ProjectNavigation.codePanel)
addCorner(Settings.ProjectNavigation.gutterBg,6)
local gutterLabel=make("TextLabel",{Name="LineNumbers",Position=UDim2.fromOffset(0,6),Size=UDim2.fromOffset(gutterWidth,220),
    BackgroundTransparency=1,BorderSizePixel=0,Text="1",TextColor3=COLORS.Muted,TextSize=compact and 11 or 13,
    Font=Enum.Font.Code,LineHeight=1.3,TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=false},Settings.ProjectNavigation.gutterBg)
editorViewport=make("ScrollingFrame",{Name="CodeViewport",Position=UDim2.fromOffset(gutterWidth+3,32),Size=UDim2.new(1,-(gutterWidth+6),1,-38),BackgroundColor3=COLORS.Panel,
    BorderSizePixel=0,ClipsDescendants=true,ScrollBarThickness=compact and 5 or 7,ScrollBarImageColor3=COLORS.Muted,
    ScrollingDirection=Enum.ScrollingDirection.XY,CanvasSize=UDim2.fromOffset(0,0),Active=true},Settings.ProjectNavigation.codePanel)
addCorner(editorViewport,6)
editorBox=make("TextBox",{Name="CodeEditor",Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(320,220),BackgroundTransparency=1,BorderSizePixel=0,
    Text="",PlaceholderText="-- Start writing Luau code here...",PlaceholderColor3=COLORS.Muted,TextColor3=COLORS.Text,
    TextSize=compact and 11 or 13,Font=Enum.Font.Code,LineHeight=1.3,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=false,MultiLine=true,ClearTextOnFocus=false,Active=true},editorViewport)
editorStatus=createLabel(editorPage,"Ready",UDim2.new(1,-24,0,22),UDim2.new(0,12,1,-27),10,COLORS.Muted)
local lastEditorCursor=1; local lastEditorSelection=1
local function rememberCaret()
    if editorBox.CursorPosition and editorBox.CursorPosition>=1 then lastEditorCursor=editorBox.CursorPosition end
    if editorBox.SelectionStart and editorBox.SelectionStart>=1 then lastEditorSelection=editorBox.SelectionStart end
end
editorBox:GetPropertyChangedSignal("CursorPosition"):Connect(rememberCaret)
editorBox:GetPropertyChangedSignal("SelectionStart"):Connect(rememberCaret)
editorBox.Focused:Connect(rememberCaret)
local function measureEditorCanvas()
    if BigCode.mode and editorBox and not editorBox.Visible then return end
    if not editorBox or not editorBox.Parent or not editorViewport then return end
    local visibleSize = editorViewport.AbsoluteSize
    if visibleSize.X <= 0 or visibleSize.Y <= 0 then return end
    local source = editorBox.Text or ""
    local textSize = editorBox.TextSize
    local font = editorBox.Font
    local lineSample = TextService:GetTextSize("Ag", textSize, font, Vector2.new(100000, 100000))
    local lineHeight = math.max(textSize + 2, lineSample.Y * 1.3)
    local lineCount = 0
    local maximumLineWidth = 0
    for line in (source .. "\n"):gmatch("(.-)\n") do
        lineCount = lineCount + 1
        local measuredLine = line
        if measuredLine == "" then measuredLine = " " end
        local measuredBounds = TextService:GetTextSize(
            measuredLine, textSize, font, Vector2.new(100000, 100000)
        )
        maximumLineWidth = math.max(maximumLineWidth, measuredBounds.X)
    end
    if lineCount == 0 then lineCount = 1 end
    local editorWidth = math.max(visibleSize.X - 16, math.ceil(maximumLineWidth + 28))
    local editorHeight = math.max(
        visibleSize.Y - 12,
        math.ceil(lineCount * lineHeight + 24)
    )
    editorBox.Size = UDim2.fromOffset(editorWidth, editorHeight)
    editorViewport.CanvasSize = UDim2.fromOffset(editorWidth + 16, editorHeight + 12)
    local lineNumbers = {}
    local firstLine = 1
    for index = 1, lineCount do
        lineNumbers[index] = tostring(firstLine + index - 1)
    end
    gutterLabel.Text = table.concat(lineNumbers, "\n")
    gutterLabel.Size = UDim2.fromOffset(gutterWidth, editorHeight)
end
local function keepEditorCaretVisible()
    if BigCode.mode and editorBox and not editorBox.Visible then return end
    if not editorBox or not editorViewport or not editorBox.Parent then return end
    local cur=editorBox.CursorPosition; if not cur or cur<1 then return end
    local src=editorBox.Text or ""; cur=math.clamp(cur,1,#src+1)
    local bc=string.sub(src,1,cur-1)
    local ln=1; for _ in bc:gmatch("\n") do ln=ln+1 end
    local lastB=0; local sf=1
    while true do local f=string.find(bc,"\n",sf,true); if not f then break end; lastB=f; sf=f+1 end
    local lp=string.sub(bc,lastB+1)
    local pb=TextService:GetTextSize(lp~="" and lp or " ",editorBox.TextSize,editorBox.Font,Vector2.new(100000,100000))
    local lb=TextService:GetTextSize("Ag",editorBox.TextSize,editorBox.Font,Vector2.new(100000,100000))
    local lh=math.max(1,lb.Y*1.3); local cx=8+(lp=="" and 0 or pb.X); local cy=6+(ln-1)*lh
    local view=editorViewport.AbsoluteSize; local current=editorViewport.CanvasPosition
    local margin=16; local nx=current.X; local ny=current.Y; local cw=7
    if cx<current.X+margin then nx=math.max(0,cx-margin) elseif cx+cw>current.X+view.X-margin then nx=cx+cw-view.X+margin end
    if cy<current.Y+margin then ny=math.max(0,cy-margin) elseif cy+lh>current.Y+view.Y-margin then ny=cy+lh-view.Y+margin end
    editorViewport.CanvasPosition=Vector2.new(math.max(0,nx),math.max(0,ny))
end
local function remeasureEditorAfterTextChange()
    task.defer(measureEditorCanvas)
    task.delay(0.05, measureEditorCanvas)
    task.delay(0.15, measureEditorCanvas)
    task.delay(0.30, measureEditorCanvas)
    task.delay(0.50, measureEditorCanvas)
    task.delay(0.75, measureEditorCanvas)
    task.delay(1.0, measureEditorCanvas)
end
BigCode.shouldUsePreview = function(source)
    source = tostring(source or "")
    local _, newlineCount = source:gsub("\n", "")
    local lineCount = newlineCount + 1
    return #source > 30000 or lineCount > 1200
end
BigCode.splitChunks = function(source)
    source = tostring(source or "")
    local chunks = {}
    local startLines = {}
    local maxChunkBytes = 4000
    local maxChunkLines = 80
    local startPos = 1
    local currentLine = 1
    while startPos <= #source do
        local limit = math.min(startPos + maxChunkBytes - 1, #source)
        local endPos = limit
        local segment = string.sub(source, startPos, limit)
        local newlinePos = nil
        local scanPos = 1
        local newlineCount = 0
        while true do
            local found = string.find(segment, "\n", scanPos, true)
            if not found then break end
            newlineCount = newlineCount + 1
            if newlineCount >= (maxChunkLines - 1) then
                newlinePos = found
                break
            end
            scanPos = found + 1
        end
        if newlinePos then
            endPos = startPos + newlinePos - 1
        elseif limit < #source then
            local boundary = segment:match(".*()\n")
            if not boundary then
                boundary = segment:match(".*()%s")
            end
            if boundary then
                endPos = startPos + boundary - 1
            end
        end
        while endPos > startPos and endPos < #source do
            local nextByte = source:byte(endPos + 1)
            if nextByte and nextByte >= 128 and nextByte <= 191 then
                endPos = endPos - 1
            else
                break
            end
        end
        if endPos < startPos then endPos = limit end
        local chunk = string.sub(source, startPos, endPos)
        table.insert(chunks, chunk)
        table.insert(startLines, currentLine)
        local _, chunkNewlines = chunk:gsub("\n", "")
        currentLine = currentLine + chunkNewlines
        startPos = endPos + 1
    end
    if #chunks == 0 then
        chunks[1] = ""
        startLines[1] = 1
    end
    return chunks, startLines
end
BigCode.recalculateLineStarts = function()
    local nextLine = 1
    for index, chunk in ipairs(BigCode.chunks) do
        BigCode.chunkStartLines[index] = nextLine
        local _, newlineCount = tostring(chunk or ""):gsub("\n", "")
        nextLine = nextLine + newlineCount
    end
    local fullText = table.concat(BigCode.chunks)
    local _, newlineCount = fullText:gsub("\n", "")
    BigCode.totalLines = newlineCount + 1
    BigCode.fullText = fullText
end
BigCode.harvestVirtualSlots = function()
    for slotIndex, slot in ipairs(BigCode.virtualSlots or {}) do
        local globalIndex = BigCode.slotChunkIndices[slotIndex]
        if globalIndex and BigCode.chunks[globalIndex] ~= nil and slot and slot.Parent then
            BigCode.chunks[globalIndex] = slot.Text or ""
        end
    end
end
BigCode.getSource = function()
    if not BigCode.mode then
        return editorBox and editorBox.Text or ""
    end
    BigCode.harvestVirtualSlots()
    BigCode.recalculateLineStarts()
    return BigCode.fullText
end
BigCode.createVirtualPool = function()
    if #BigCode.virtualSlots > 0 then return end
    for slotIndex = 1, BigCode.poolSize do
        local slot = Instance.new("TextBox")
        slot.Name = "BigCodeVirtualSlot_" .. tostring(slotIndex)
        slot.BackgroundTransparency = 1
        slot.BorderSizePixel = 0
        slot.Position = UDim2.fromOffset(8, 6)
        slot.Size = UDim2.fromOffset(320, 220)
        slot.AutomaticSize = Enum.AutomaticSize.None
        slot.Text = ""
        slot.TextColor3 = COLORS.Text
        slot.TextSize = editorBox.TextSize
        slot.Font = Enum.Font.Code
        slot.LineHeight = 1.3
        slot.TextXAlignment = Enum.TextXAlignment.Left
        slot.TextYAlignment = Enum.TextYAlignment.Top
        slot.TextWrapped = false
        slot.TextScaled = false
        slot.TextTruncate = Enum.TextTruncate.None
        slot.MaxVisibleGraphemes = -1
        slot.RichText = false
        slot.MultiLine = true
        slot.ClearTextOnFocus = false
        slot.TextEditable = true
        slot.Active = true
        slot.Visible = false
        slot.ZIndex = editorBox.ZIndex
        slot.Parent = editorViewport
        BigCode.virtualSlots[slotIndex] = slot
        BigCode.slotChunkIndices[slotIndex] = nil
        local numberLabel = Instance.new("TextLabel")
        numberLabel.Name = "BigCodeVirtualGutter_" .. tostring(slotIndex)
        numberLabel.BackgroundTransparency = 1
        numberLabel.BorderSizePixel = 0
        numberLabel.Position = UDim2.fromOffset(0, 6)
        numberLabel.Size = UDim2.fromOffset(gutterWidth, 220)
        numberLabel.Font = Enum.Font.Code
        numberLabel.TextSize = gutterLabel.TextSize
        numberLabel.TextColor3 = COLORS.Muted
        numberLabel.TextXAlignment = Enum.TextXAlignment.Right
        numberLabel.TextYAlignment = Enum.TextYAlignment.Top
        numberLabel.TextWrapped = false
        numberLabel.TextScaled = false
        numberLabel.LineHeight = 1.3
        numberLabel.Text = ""
        numberLabel.Visible = false
        numberLabel.ZIndex = gutterLabel.ZIndex
        numberLabel.Parent = Settings.ProjectNavigation.gutterBg
        BigCode.virtualGutterSlots[slotIndex] = numberLabel
        slot:GetPropertyChangedSignal("Text"):Connect(function()
            if not BigCode.mode or BigCode.rebuilding then return end
            local globalIndex = BigCode.slotChunkIndices[slotIndex]
            if not globalIndex or not BigCode.chunks[globalIndex] then return end
            if BigCode.selectAll then
                local replacementText = slot.Text or ""
                BigCode.selectAll = false
                local currentX = editorViewport.CanvasPosition.X
                BigCode.render(replacementText)
                local lastIndex = #BigCode.chunks
                local lastOffset = BigCode.chunkOffsets[lastIndex] or 6
                local lastHeight = BigCode.chunkHeights[lastIndex] or 24
                local targetY = math.max(0, lastOffset + lastHeight - editorViewport.AbsoluteSize.Y + 16)
                editorViewport.CanvasPosition = Vector2.new(currentX, targetY)
                BigCode.updateVirtualScroll()
                for poolIndex = 1, #BigCode.virtualSlots do
                    if BigCode.slotChunkIndices[poolIndex] == lastIndex then
                        local endBox = BigCode.virtualSlots[poolIndex]
                        local endPosition = #(endBox.Text or "") + 1
                        endBox.CursorPosition = endPosition
                        endBox.SelectionStart = endPosition
                        endBox:CaptureFocus()
                        BigCode.focusedEditor = endBox
                        BigCode.focusedChunkIndex = lastIndex
                        break
                    end
                end
                if currentProject then syncEditorToFile(currentProject, BigCode.fullText) end
                Settings.debouncedAutoSave()
                return
            end
            BigCode.chunks[globalIndex] = slot.Text or ""
            local _, newlineCount = (slot.Text or ""):gsub("\n", "")
            if #(slot.Text or "") > 4000 or newlineCount + 1 > 80 then
                BigCode.queueRechunk(slotIndex, globalIndex)
            else
                BigCode.refreshLayout(true, globalIndex)
            end
            Settings.debouncedAutoSave()
        end)
        slot.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if BigCode.selectAll then BigCode.selectAll = false end
            end
        end)
        slot.Focused:Connect(function()
            if not BigCode.mode then return end
            if BigCode.selectAll and BigCode.focusedEditor ~= slot then
                BigCode.selectAll = false
            end
            BigCode.focusedEditor = slot
            BigCode.focusedChunkIndex = BigCode.slotChunkIndices[slotIndex]
        end)
        slot.FocusLost:Connect(function()
            if not BigCode.mode or BigCode.rebuilding or BigCode.focusedEditor ~= slot then return end
            local globalIndex = BigCode.slotChunkIndices[slotIndex]
            if globalIndex then
                BigCode.chunks[globalIndex] = slot.Text or ""
                BigCode.recalculateLineStarts()
                if currentProject then
                    syncEditorToFile(currentProject, BigCode.fullText)
                end
            end
            if BigCode.focusedEditor == slot then
                BigCode.focusedEditor = nil
                BigCode.focusedChunkIndex = nil
            end
        end)
    end
end
BigCode.updateVirtualScroll = function()
    if not BigCode.mode or not editorViewport or #BigCode.virtualSlots == 0 then return end
    local scrollY = editorViewport.CanvasPosition.Y
    local viewportHeight = editorViewport.AbsoluteSize.Y
    local viewportBottom = scrollY + viewportHeight
    local chunks = BigCode.chunks
    local chunkCount = #chunks
    if chunkCount == 0 then
        for slotIndex, slot in ipairs(BigCode.virtualSlots) do
            slot.Visible = false
            BigCode.virtualGutterSlots[slotIndex].Visible = false
            BigCode.slotChunkIndices[slotIndex] = nil
        end
        return
    end
    local low, high = 1, chunkCount
    local firstVisible = chunkCount
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local bottom = (BigCode.chunkOffsets[mid] or 0) + (BigCode.chunkHeights[mid] or 0)
        if bottom > scrollY then
            firstVisible = mid
            high = mid - 1
        else
            low = mid + 1
        end
    end
    local lastVisible = firstVisible
    while lastVisible < chunkCount do
        if (BigCode.chunkOffsets[lastVisible + 1] or math.huge) >= viewportBottom then break end
        lastVisible = lastVisible + 1
    end
    while lastVisible < chunkCount and
        (BigCode.chunkOffsets[lastVisible] or 0) + (BigCode.chunkHeights[lastVisible] or 0) < viewportBottom do
        lastVisible = lastVisible + 1
    end
    local wantedIndices = {}
    local wantedSet = {}
    local firstWanted = math.max(1, firstVisible - 2)
    local lastWanted = math.min(chunkCount, math.max(lastVisible + 2, firstVisible))
    for globalIndex = firstWanted, lastWanted do
        if #wantedIndices >= #BigCode.virtualSlots then break end
        wantedIndices[#wantedIndices + 1] = globalIndex
        wantedSet[globalIndex] = true
    end
    local assignedSlot = {}
    local usedSlots = {}
    for slotIndex = 1, #BigCode.virtualSlots do
        local globalIndex = BigCode.slotChunkIndices[slotIndex]
        if globalIndex and wantedSet[globalIndex] then
            assignedSlot[globalIndex] = slotIndex
            usedSlots[slotIndex] = true
        end
    end
    BigCode.rebuilding = true
    for slotIndex, slot in ipairs(BigCode.virtualSlots) do
        local oldIndex = BigCode.slotChunkIndices[slotIndex]
        if oldIndex and not wantedSet[oldIndex] then
            if BigCode.findOverlay and BigCode.findOverlay.Parent == slot then
                BigCode.findOverlay.Visible = false
                BigCode.findOverlay.Parent = editorViewport
            end
            if BigCode.chunks[oldIndex] ~= nil then
                BigCode.chunks[oldIndex] = slot.Text or BigCode.chunks[oldIndex]
            end
            if slot:IsFocused() then
                slot:ReleaseFocus()
            end
            if BigCode.focusedEditor == slot then
                BigCode.focusedEditor = nil
                BigCode.focusedChunkIndex = nil
            end
            BigCode.slotChunkIndices[slotIndex] = nil
            slot.Visible = false
            BigCode.virtualGutterSlots[slotIndex].Visible = false
        end
    end
    for _, globalIndex in ipairs(wantedIndices) do
        if not assignedSlot[globalIndex] then
            local freeSlot
            for slotIndex = 1, #BigCode.virtualSlots do
                if not usedSlots[slotIndex] then
                    freeSlot = slotIndex
                    break
                end
            end
            if not freeSlot then break end
            local slot = BigCode.virtualSlots[freeSlot]
            slot.Text = chunks[globalIndex] or ""
            slot.CursorPosition = 1
            slot.SelectionStart = 1
            if BigCode.selectAll then
                slot.CursorPosition = #(slot.Text or "") + 1
                slot.SelectionStart = 1
            end
            BigCode.slotChunkIndices[freeSlot] = globalIndex
            assignedSlot[globalIndex] = freeSlot
            usedSlots[freeSlot] = true
        end
    end
    for slotIndex, slot in ipairs(BigCode.virtualSlots) do
        local globalIndex = BigCode.slotChunkIndices[slotIndex]
        local numberLabel = BigCode.virtualGutterSlots[slotIndex]
        if globalIndex and wantedSet[globalIndex] then
            local offset = BigCode.chunkOffsets[globalIndex] or 6
            local height = BigCode.chunkHeights[globalIndex] or 24
            local width = BigCode.chunkWidths[globalIndex] or math.max(100, editorViewport.AbsoluteSize.X - 16)
            slot.Position = UDim2.fromOffset(8, offset)
            slot.Size = UDim2.fromOffset(width, height)
            slot.Visible = true
            slot.TextEditable = true
            if BigCode.selectAll then
                slot.SelectionStart = 1
                slot.CursorPosition = #(slot.Text or "") + 1
            end
            local lineCount = select(2, (chunks[globalIndex] or ""):gsub("\n", "")) + 1
            local startLine = BigCode.chunkStartLines[globalIndex] or 1
            local cache = BigCode.slotGutterCache[slotIndex]
            if not cache or cache.chunkIndex ~= globalIndex or cache.startLine ~= startLine
                or cache.lineCount ~= lineCount then
                local numberLines = table.create(lineCount)
                for lineIndex = 1, lineCount do
                    numberLines[lineIndex] = tostring(startLine + lineIndex - 1)
                end
                numberLabel.Text = table.concat(numberLines, "\n")
                BigCode.slotGutterCache[slotIndex] = {
                    chunkIndex = globalIndex,
                    startLine = startLine,
                    lineCount = lineCount,
                }
            end
            numberLabel.Size = UDim2.fromOffset(gutterWidth, height)
            numberLabel.Position = UDim2.fromOffset(0, offset - scrollY)
            numberLabel.Visible = true
        else
            slot.Visible = false
            numberLabel.Visible = false
        end
    end
    BigCode.rebuilding = false
end
BigCode.refreshLayout = function(skipHarvest, changedIndex)
    if not BigCode.mode or BigCode.rebuilding then return end
    local view = editorViewport.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then return end
    if not skipHarvest then BigCode.harvestVirtualSlots() end
    BigCode.recalculateLineStarts()
    local textSize = editorBox.TextSize
    local sample = TextService:GetTextSize("Ag", textSize, Enum.Font.Code, Vector2.new(100000, 100000))
    local lineHeight = math.max(textSize + 2, sample.Y * 1.3)
    local maxWidth = math.max(100, view.X - 16)
    local yOffset = 6
    BigCode.chunkOffsets = {}
    for globalIndex, chunk in ipairs(BigCode.chunks) do
        local lineCount = select(2, (chunk or ""):gsub("\n", "")) + 1
        local chunkWidth = BigCode.chunkWidths[globalIndex]
        local chunkHeight = BigCode.chunkHeights[globalIndex]
        if not changedIndex or changedIndex == globalIndex or not chunkWidth or not chunkHeight then
            local longestLine = ""
            for line in ((chunk or "") .. "\n"):gmatch("(.-)\n") do
                if #line > #longestLine then longestLine = line end
            end
            local bounds = TextService:GetTextSize(
                longestLine ~= "" and longestLine or " ", textSize, Enum.Font.Code,
                Vector2.new(100000, 100000)
            )
            chunkWidth = math.max(view.X - 16, math.ceil(bounds.X + 24))
            chunkHeight = math.max(lineHeight, math.ceil(lineCount * lineHeight + 8))
            BigCode.chunkWidths[globalIndex] = chunkWidth
            BigCode.chunkHeights[globalIndex] = chunkHeight
        end
        BigCode.chunkOffsets[globalIndex] = yOffset
        yOffset = yOffset + chunkHeight
        maxWidth = math.max(maxWidth, chunkWidth)
    end
    BigCode.totalHeight = yOffset + 6
    editorViewport.CanvasSize = UDim2.fromOffset(
        maxWidth + 16,
        math.max(view.Y, BigCode.totalHeight)
    )
    BigCode.updateVirtualScroll()
end
BigCode.queueRechunk = function(slotIndex, globalIndex)
    if BigCode.pendingRechunk then return end
    BigCode.pendingRechunk = true
    task.defer(function()
        BigCode.pendingRechunk = false
        if not BigCode.mode then return end
        local slot = BigCode.virtualSlots[slotIndex]
        if not slot or BigCode.chunks[globalIndex] == nil then return end
        local slotStillMapped = BigCode.slotChunkIndices[slotIndex] == globalIndex
        local prefixBytes = 0
        for index = 1, globalIndex - 1 do
            prefixBytes = prefixBytes + #(BigCode.chunks[index] or "")
        end
        local cursor = slotStillMapped and slot.CursorPosition or nil
        if not cursor or cursor < 1 then cursor = #(BigCode.chunks[globalIndex] or "") + 1 end
        local absoluteCursor = prefixBytes + cursor - 1
        local source = BigCode.getSource()
        local oldCanvas = editorViewport.CanvasPosition
        local newChunks, newStarts = BigCode.splitChunks(source)
        BigCode.rebuilding = true
        BigCode.chunks = newChunks
        BigCode.chunkStartLines = newStarts
        BigCode.chunkOffsets = {}
        BigCode.chunkHeights = {}
        BigCode.chunkWidths = {}
        BigCode.slotGutterCache = {}
        BigCode.slotChunkIndices = {}
        for index, virtualSlot in ipairs(BigCode.virtualSlots) do
            if virtualSlot:IsFocused() then virtualSlot:ReleaseFocus() end
            virtualSlot.Text = ""
            virtualSlot.Visible = false
            BigCode.virtualGutterSlots[index].Text = ""
            BigCode.virtualGutterSlots[index].Visible = false
        end
        BigCode.focusedEditor = nil
        BigCode.focusedChunkIndex = nil
        BigCode.rebuilding = false
        BigCode.refreshLayout(true)
        local targetIndex = #BigCode.chunks
        local byteStart = 0
        for index, chunk in ipairs(BigCode.chunks) do
            local byteEnd = byteStart + #chunk
            if absoluteCursor <= byteEnd or index == #BigCode.chunks then
                targetIndex = index
                break
            end
            byteStart = byteEnd
        end
        local targetOffset = BigCode.chunkOffsets[targetIndex] or 6
        editorViewport.CanvasPosition = Vector2.new(oldCanvas.X, math.max(0, targetOffset - 12))
        BigCode.updateVirtualScroll()
        byteStart = 0
        for index = 1, targetIndex - 1 do
            byteStart = byteStart + #(BigCode.chunks[index] or "")
        end
        for index, virtualSlot in ipairs(BigCode.virtualSlots) do
            if BigCode.slotChunkIndices[index] == targetIndex then
                local localCursor = math.clamp(absoluteCursor - byteStart + 1, 1, #(virtualSlot.Text or "") + 1)
                virtualSlot.CursorPosition = localCursor
                virtualSlot.SelectionStart = localCursor
                virtualSlot:CaptureFocus()
                BigCode.focusedEditor = virtualSlot
                BigCode.focusedChunkIndex = targetIndex
                break
            end
        end
        if currentProject then syncEditorToFile(currentProject, BigCode.fullText) end
    end)
end
BigCode.render = function(fullText, restoreCanvasPosition, preferredChunkIndex)
    fullText = tostring(fullText or "")
    BigCode.rebuilding = true
    BigCode.mode = true
    BigCode.selectAll = false
    BigCode.fullText = fullText
    BigCode.chunks, BigCode.chunkStartLines = BigCode.splitChunks(fullText)
    BigCode.chunkOffsets = {}
    BigCode.chunkHeights = {}
    BigCode.chunkWidths = {}
    BigCode.slotGutterCache = {}
    BigCode.focusedEditor = nil
    BigCode.focusedChunkIndex = nil
    BigCode.createVirtualPool()
    local keepSlots = {}
    for _, slot in ipairs(BigCode.virtualSlots) do keepSlots[slot] = true end
    for _, child in ipairs(editorViewport:GetChildren()) do
        if child ~= editorBox and not keepSlots[child] then
            child:Destroy()
        end
    end
    local keepGutters = {}
    for _, label in ipairs(BigCode.virtualGutterSlots) do keepGutters[label] = true end
    for _, child in ipairs(Settings.ProjectNavigation.gutterBg:GetChildren()) do
        if child ~= gutterLabel and not keepGutters[child] then
            child:Destroy()
        end
    end
    for slotIndex, slot in ipairs(BigCode.virtualSlots) do
        if slot:IsFocused() then slot:ReleaseFocus() end
        slot.Text = ""
        slot.Visible = false
        BigCode.virtualGutterSlots[slotIndex].Text = ""
        BigCode.virtualGutterSlots[slotIndex].Visible = false
        BigCode.slotChunkIndices[slotIndex] = nil
    end
    editorBox.Visible = false
    editorBox.TextEditable = false
    editorBox.Position = UDim2.fromOffset(8, 6)
    editorBox.Size = UDim2.fromOffset(0, 0)
    gutterLabel.Visible = false
    gutterLabel.Text = ""
    BigCode.rebuilding = false
    BigCode.refreshLayout(true)
    local targetY = 0
    if preferredChunkIndex then
        targetY = math.max(0, (BigCode.chunkOffsets[preferredChunkIndex] or 6) - 12)
    elseif restoreCanvasPosition then
        targetY = math.max(0, restoreCanvasPosition.Y)
    end
    local targetX = restoreCanvasPosition and restoreCanvasPosition.X or 0
    editorViewport.CanvasPosition = Vector2.new(targetX, targetY)
    BigCode.updateVirtualScroll()
end
BigCode.clearMode = function()
    if BigCode.mode then BigCode.getSource() end
    BigCode.mode = false
    BigCode.selectAll = false
    BigCode.fullText = ""
    BigCode.chunks = {}
    BigCode.chunkStartLines = {}
    BigCode.chunkOffsets = {}
    BigCode.chunkHeights = {}
    BigCode.chunkWidths = {}
    BigCode.totalLines = 1
    BigCode.totalHeight = 0
    BigCode.pendingRechunk = false
    BigCode.focusedEditor = nil
    BigCode.focusedChunkIndex = nil
    BigCode.slotChunkIndices = {}
    BigCode.slotGutterCache = {}
    for _, slot in ipairs(BigCode.virtualSlots or {}) do
        if slot and slot.Parent then slot:Destroy() end
    end
    for _, label in ipairs(BigCode.virtualGutterSlots or {}) do
        if label and label.Parent then label:Destroy() end
    end
    BigCode.virtualSlots = {}
    BigCode.virtualGutterSlots = {}
    if editorViewport then
        for _, child in ipairs(editorViewport:GetChildren()) do
            if child ~= editorBox then child:Destroy() end
        end
        editorViewport.CanvasSize = UDim2.fromOffset(0, 0)
        editorViewport.CanvasPosition = Vector2.new(0, 0)
    end
    for _, child in ipairs(Settings.ProjectNavigation.gutterBg:GetChildren()) do
        if child ~= gutterLabel then child:Destroy() end
    end
    if gutterLabel then
        gutterLabel.Visible = true
        gutterLabel.Text = "1"
        gutterLabel.Position = UDim2.fromOffset(0, 6)
        gutterLabel.Size = UDim2.fromOffset(gutterWidth, 220)
    end
    if editorBox then
        editorBox.Visible = true
        editorBox.TextEditable = true
        editorBox.Position = UDim2.fromOffset(8, 6)
        editorBox.Size = UDim2.fromOffset(320, 220)
    end
    if measureEditorCanvas then task.defer(measureEditorCanvas) end
end
BigCode.focusChunkAt = function(globalIndex, cursorPosition)
    if not BigCode.mode or not BigCode.chunks[globalIndex] then return false end
    local offset = BigCode.chunkOffsets[globalIndex] or 6
    local current = editorViewport.CanvasPosition
    local viewHeight = editorViewport.AbsoluteSize.Y
    local height = BigCode.chunkHeights[globalIndex] or 24
    if offset < current.Y or offset + height > current.Y + viewHeight then
        editorViewport.CanvasPosition = Vector2.new(current.X, math.max(0, offset - 12))
    end
    BigCode.updateVirtualScroll()
    for slotIndex = 1, #BigCode.virtualSlots do
        if BigCode.slotChunkIndices[slotIndex] == globalIndex then
            local box = BigCode.virtualSlots[slotIndex]
            local position = math.clamp(cursorPosition or 1, 1, #(box.Text or "") + 1)
            box:CaptureFocus()
            box.CursorPosition = position
            box.SelectionStart = position
            BigCode.focusedEditor = box
            BigCode.focusedChunkIndex = globalIndex
            return true
        end
    end
    return false
end
BigCode.focusLine = function(targetLine)
    if not BigCode.mode then return false end
    targetLine = math.max(1, math.floor(tonumber(targetLine) or 1))
    BigCode.getSource()
    BigCode.refreshLayout(true)
    local selectedIndex = #BigCode.chunks
    local localLine = 1
    for globalIndex, chunk in ipairs(BigCode.chunks) do
        local startLine = BigCode.chunkStartLines[globalIndex] or 1
        local lineCount = select(2, (chunk or ""):gsub("\n", "")) + 1
        if targetLine >= startLine and targetLine <= startLine + lineCount - 1 then
            selectedIndex = globalIndex
            localLine = targetLine - startLine + 1
            break
        end
    end
    local lineHeight = math.max(editorBox.TextSize + 2,
        TextService:GetTextSize("Ag", editorBox.TextSize, Enum.Font.Code, Vector2.new(100000, 100000)).Y * 1.3)
    local targetY = (BigCode.chunkOffsets[selectedIndex] or 6) + (localLine - 1) * lineHeight
    local current = editorViewport.CanvasPosition
    editorViewport.CanvasPosition = Vector2.new(current.X, math.max(0, targetY - 12))
    BigCode.updateVirtualScroll()
    local box
    for slotIndex = 1, #BigCode.virtualSlots do
        if BigCode.slotChunkIndices[slotIndex] == selectedIndex then
            box = BigCode.virtualSlots[slotIndex]
            break
        end
    end
    if not box then return false end
    local position = 1
    for _ = 1, localLine - 1 do
        local newline = string.find(box.Text or "", "\n", position, true)
        if not newline then position = #(box.Text or "") + 1; break end
        position = newline + 1
    end
    box:CaptureFocus()
    box.CursorPosition = position
    box.SelectionStart = position
    BigCode.focusedEditor = box
    BigCode.focusedChunkIndex = selectedIndex
    return true
end
editorViewport:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if BigCode.mode then
        BigCode.updateVirtualScroll()
    else
        gutterLabel.Position = UDim2.fromOffset(0, 6 - editorViewport.CanvasPosition.Y)
    end
end)
do
    local isSwitchingToBigCode = false
    local function switchToBigCode(fullText, textLength)
        if isSwitchingToBigCode then return end
        isSwitchingToBigCode = true
        local ok, err = pcall(function()
            BigCode.render(fullText)
            editorBox.Text = ""
            editorBox.Visible = false
            editorBox.TextEditable = false
            if currentProject then
                syncEditorToFile(currentProject, fullText)
            end
            editorStatus.Text = "Auto-switched to BigCode (" .. tostring(textLength) .. " chars)"
            editorStatus.TextColor3 = COLORS.Green
            logConsole(
                "Info",
                "Auto-switched to BigCode because text length is " .. tostring(textLength) .. " chars"
            )
        end)
        task.defer(function()
            isSwitchingToBigCode = false
        end)
        if not ok then
            isSwitchingToBigCode = false
            warn("Easy Scripting BigCode auto-switch failed: " .. tostring(err))
            editorStatus.Text = "BigCode switch failed - see console"
            editorStatus.TextColor3 = COLORS.Red
            logConsole("Error", "BigCode auto-switch failed: " .. tostring(err))
        end
    end
    editorBox:GetPropertyChangedSignal("Text"):Connect(function()
        if isSwitchingToBigCode then return end
        local currentText = editorBox.Text or ""
        local textLength = #currentText
        if BigCode.mode then
            if editorBox.Visible then
                editorBox.Visible = false
                editorBox.TextEditable = false
            end
            return
        end
        if BigCode.shouldUsePreview(currentText) then
            switchToBigCode(currentText, textLength)
            Settings.debouncedAutoSave()
            return
        end
        if currentProject and editorBox.TextEditable then
            syncEditorToFile(currentProject, currentText)
        end
        Settings.debouncedAutoSave()
        remeasureEditorAfterTextChange()
        task.defer(keepEditorCaretVisible)
        if textLength >= 28000 and textLength <= 30000 then
            editorStatus.Text = "Text getting long (" .. textLength .. " chars). Switches to BigCode at 30k."
            editorStatus.TextColor3 = COLORS.Yellow
        end
    end)
end
pcall(function()
    editorBox:GetPropertyChangedSignal("TextBounds"):Connect(function()
        measureEditorCanvas()
    end)
end)
UserInputService.InputBegan:Connect(function(input)
    local k=input.KeyCode
    local controlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
    local navigationSelectionKey = k == Enum.KeyCode.Left or k == Enum.KeyCode.Right
        or k == Enum.KeyCode.Up or k == Enum.KeyCode.Down or k == Enum.KeyCode.Home
        or k == Enum.KeyCode.End
    if BigCode.selectAll and navigationSelectionKey then
        BigCode.selectAll = false
    end
    if BigCode.mode and controlDown and BigCode.focusedEditor
        and BigCode.focusedEditor.Parent and BigCode.focusedEditor:IsFocused() then
        if k == Enum.KeyCode.A then
            BigCode.selectAll = true
            for slotIndex, slot in ipairs(BigCode.virtualSlots) do
                if slot.Visible then
                    slot.SelectionStart = 1
                    slot.CursorPosition = #(slot.Text or "") + 1
                end
            end
            return
        elseif (k == Enum.KeyCode.C or k == Enum.KeyCode.X) and BigCode.selectAll then
            local completeSelection = BigCode.getSource()
            if type(setclipboard) == "function" then
                task.defer(function()
                    pcall(setclipboard, completeSelection)
                end)
            end
            return
        end
    end
    local navigationKey = k==Enum.KeyCode.Left or k==Enum.KeyCode.Right or k==Enum.KeyCode.Up
        or k==Enum.KeyCode.Down or k==Enum.KeyCode.Home or k==Enum.KeyCode.End
        or k==Enum.KeyCode.PageUp or k==Enum.KeyCode.PageDown
    if not navigationKey then return end
    if BigCode.mode and BigCode.focusedEditor and BigCode.focusedEditor.Parent
        and BigCode.focusedEditor:IsFocused() then
        task.defer(function()
            local box=BigCode.focusedEditor
            local index=BigCode.focusedChunkIndex
            if not box or not box.Parent or not box:IsFocused() then return end
            local cursor=box.CursorPosition
            if not cursor or cursor<1 then return end
            local text = box.Text or ""
            if index and k == Enum.KeyCode.Left and cursor <= 1 and index > 1 then
                local previousText = BigCode.chunks[index - 1] or ""
                BigCode.focusChunkAt(index - 1, #previousText + 1)
                return
            elseif index and k == Enum.KeyCode.Right and cursor >= #text + 1 and index < #BigCode.chunks then
                BigCode.focusChunkAt(index + 1, 1)
                return
            end
            local prefix=string.sub(text,1,cursor-1)
            local line=1
            for _ in prefix:gmatch("\n") do line=line+1 end
            local lastBreak=0
            local scan=1
            while true do
                local found=string.find(prefix,"\n",scan,true)
                if not found then break end
                lastBreak=found
                scan=found+1
            end
            local lastLine=string.sub(prefix,lastBreak+1)
            local width=TextService:GetTextSize(lastLine~="" and lastLine or " ",box.TextSize,box.Font,Vector2.new(100000,100000)).X
            local lineHeight=math.max(box.TextSize+2,TextService:GetTextSize("Ag",box.TextSize,box.Font,Vector2.new(100000,100000)).Y*1.3)
            local canvas=editorViewport.CanvasPosition
            local boxTop=box.AbsolutePosition.Y-editorViewport.AbsolutePosition.Y+canvas.Y
            local x=8+width
            local y=boxTop+(line-1)*lineHeight
            local view=editorViewport.AbsoluteSize
            local nx=canvas.X
            local ny=canvas.Y
            if x<nx+16 then nx=math.max(0,x-16) elseif x>nx+view.X-16 then nx=x-view.X+16 end
            if y<ny+12 then ny=math.max(0,y-12) elseif y+lineHeight>ny+view.Y-12 then ny=y+lineHeight-view.Y+12 end
            editorViewport.CanvasPosition=Vector2.new(math.max(0,nx),math.max(0,ny))
        end)
        return
    end
    if not editorBox or not editorBox:IsFocused() then return end
    if navigationKey then task.defer(keepEditorCaretVisible) end
end)
editorViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if BigCode.mode then
        BigCode.refreshLayout()
    else
        measureEditorCanvas()
    end
end)
task.defer(measureEditorCanvas)
local function insertEditorNewline()
    local targetBox = editorBox
    if BigCode.mode and BigCode.focusedEditor and BigCode.focusedEditor.Parent then
        targetBox = BigCode.focusedEditor
    end
    if not targetBox then return end
    local src=targetBox.Text or ""
    local cur=targetBox.CursorPosition
    local sel=targetBox.SelectionStart
    if targetBox==editorBox then
        if not cur or cur<1 then cur=lastEditorCursor end
        if not sel or sel<1 then sel=lastEditorSelection end
    end
    if not cur or cur<1 then cur=#src+1 end
    if not sel or sel<1 then sel=cur end
    local first=math.clamp(math.min(cur,sel),1,#src+1)
    local last=math.clamp(math.max(cur,sel),1,#src+1)
    local updated=string.sub(src,1,first-1).."\n"..string.sub(src,last)
    targetBox.Text=updated
    local np=first+1
    targetBox.CursorPosition=np
    targetBox.SelectionStart=np
    if targetBox==editorBox then
        lastEditorCursor=np
        lastEditorSelection=np
    end
    task.defer(function()
        if targetBox and targetBox.Parent and editorPage.Visible then targetBox:CaptureFocus() end
    end)
end
Settings.ProjectNavigation.newlineButton.Activated:Connect(function() rememberCaret(); insertEditorNewline() end)
do
Settings.ProjectNavigation.pasteButton=createButton(Settings.ProjectNavigation.codePanel,"Paste",UDim2.fromOffset(48,24),UDim2.new(1,-104,0,5),nil,COLORS.Accent)
Settings.ProjectNavigation.pasteButton.TextSize=10

local function simulateCtrlV()
    -- Способ 1: keypress/keyrelease (если поддерживает executor)
    if type(keypress) == "function" and type(keyrelease) == "function" then
        local success = pcall(function()
            keypress(0x11) -- LeftControl
            task.wait(0.05)
            keypress(0x56) -- V
            task.wait(0.05)
            keyrelease(0x56)
            keyrelease(0x11)
        end)
        if success then return true end
    end
    
    -- Способ 2: VirtualInputManager (CoreScript service, часто есть в executor'ах)
    local ok_vim, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok_vim and vim and type(vim.SendKeyEvent) == "function" then
        local success = pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            vim:SendKeyEvent(true, Enum.KeyCode.V, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, Enum.KeyCode.V, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end)
        if success then return true end
    end
    
    return false
end

Settings.ProjectNavigation.pasteButton.Activated:Connect(function()
    local targetBox = editorBox
    if BigCode.mode and BigCode.focusedEditor and BigCode.focusedEditor.Parent then
        targetBox = BigCode.focusedEditor
    end
    
    if not targetBox then return end

    -- 1. Принудительно ставим фокус в редактор
    targetBox:CaptureFocus()
    
    -- 2. Ждём мгновение для регистрации фокуса, затем имитируем Ctrl+V
    task.delay(0.1, function()
        if not targetBox:IsFocused() then return end
        
        local simulated = simulateCtrlV()
        
        if not simulated then
            -- Если executor не поддерживает эмуляцию клавиш — фоллбек на ручную вставку
            if logConsole then
                logConsole("Info", "Editor focused. Press Ctrl+V (or your executor's paste shortcut) to insert.")
            end
            if editorStatus then
                editorStatus.Text = "Editor focused. Press Ctrl+V."
                editorStatus.TextColor3 = COLORS.Yellow
            end
        else
            if editorStatus then
                editorStatus.Text = "Ctrl+V simulated"
                editorStatus.TextColor3 = COLORS.Green
            end
        end
    end)
end)
end
if touchDevice then
    local ok,sig=pcall(function() return editorBox.ReturnPressedFromOnScreenKeyboard end)
    if ok and sig then sig:Connect(function() task.defer(function() if editorBox and editorBox.Parent and editorPage.Visible then editorBox:CaptureFocus() end end) end) end
end
local function buildTreeMap(project)
    ensureProjectStructure(project)
    local folders={[""]=true}; local files={}
    for _,folder in ipairs(project.folders) do
        local clean=normalizePath(folder)
        if clean then
            folders[clean]=true
            local parent=parentPath(clean)
            while parent~="" do folders[parent]=true; parent=parentPath(parent) end
        end
    end
    for _,file in ipairs(project.files) do
        files[file.path]=file
        local parent=parentPath(file.path)
        while parent~="" do folders[parent]=true; parent=parentPath(parent) end
    end
    local children={}
    local function addChild(parent,entry) children[parent]=children[parent] or {}; table.insert(children[parent],entry) end
    for folder in pairs(folders) do if folder~="" then addChild(parentPath(folder),{path=folder,name=leafName(folder),isFolder=true}) end end
    for path,file in pairs(files) do addChild(parentPath(path),{path=path,name=leafName(path),isFolder=false,file=file}) end
    for _,entries in pairs(children) do
        table.sort(entries,function(a,b)
            if a.isFolder~=b.isFolder then return a.isFolder end
            return a.name:lower()<b.name:lower()
        end)
    end
    return children
end
BigCode.updateAutoExecuteMenuButton=function()
    local button=BigCode.autoExecuteMenuButton
    if not button then return end
    local file=nil
    if currentProject and selectedTreePath~="" and not selectedTreeIsFolder then
        file=getProjectFile(currentProject,selectedTreePath)
    end
    if file and isScriptFile(file.path) then
        button.Text=file.autoExecute and "Auto Execute: ON" or "Auto Execute: OFF"
        button.BackgroundColor3=file.autoExecute and COLORS.Green or COLORS.Panel2
    else
        button.Text="Auto Execute: N/A"
        button.BackgroundColor3=COLORS.Panel2
    end
end
renderFileTree=function()
    if not currentProject then return end
    if Settings.ProjectNavigation.treeToggleButton then
        Settings.ProjectNavigation.treeToggleButton.Text = "Tree"
        Settings.ProjectNavigation.treeToggleButton.Visible = true
        Settings.ProjectNavigation.treeToggleButton.Active = Settings.ProjectNavigation.viewingFile == true
        Settings.ProjectNavigation.treeToggleButton.AutoButtonColor = Settings.ProjectNavigation.viewingFile == true
        Settings.ProjectNavigation.treeToggleButton.TextColor3 = Settings.ProjectNavigation.viewingFile and COLORS.Accent or COLORS.Muted
    end
    for _,child in ipairs(treeList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    local children=buildTreeMap(currentProject)
    local order=0

    -- Parent directory navigation.
    if Settings.ProjectNavigation.currentViewDir ~= "" then
        order = order + 1
        local backRow = make("TextButton", {
            Name = "BackRow",
            Size = UDim2.new(1,-3,0,24),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = true,
            LayoutOrder = order,
        }, treeList)
        addCorner(backRow, 4)
        createLabel(backRow, "🔙  ..", UDim2.new(1,-12,1,0), UDim2.fromOffset(6,0), 9, COLORS.Muted, Enum.Font.GothamBold)
        backRow.Activated:Connect(function()
            Settings.ProjectNavigation.currentViewDir = parentPath(Settings.ProjectNavigation.currentViewDir)
            selectedTreePath = ""
            selectedTreeIsFolder = true
            lastTreeClickPath = nil
            if updatePathBar then updatePathBar() end
            renderFileTree()
        end)
    end

    -- Only show direct children of the current directory.
    for _,entry in ipairs(children[Settings.ProjectNavigation.currentViewDir] or {}) do
        order = order + 1
        local selected = selectedTreePath == entry.path and selectedTreeIsFolder == entry.isFolder
        local row = make("TextButton", {
            Name = entry.isFolder and "FolderRow" or "FileRow",
            Size = UDim2.new(1,-3,0,24),
            BackgroundColor3 = selected and COLORS.PanelHover or COLORS.Panel2,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = true,
            LayoutOrder = order,
        }, treeList)
        addCorner(row, 4)

        local iconText = "📄"
        if entry.isFolder then
            iconText = "📁"
        elseif currentProject and currentProject.mainFile == entry.path then
            iconText = "⭐"
        else
            local ext = getFileExtension(entry.path)
            if ext == "lua" or ext == "luau" then
                iconText = "📜"
            elseif ext == "json" then
                iconText = "📋"
            elseif ext == "md" then
                iconText = "📝"
            elseif ext == "txt" then
                iconText = "📃"
            end
        end
        local entryLabel = createLabel(row, iconText .. "  " .. entry.name, UDim2.new(1,-12,1,0),
            UDim2.fromOffset(6,0), 9, selected and COLORS.Accent or COLORS.Text,
            entry.isFolder and Enum.Font.GothamBold or Enum.Font.Code)
        entryLabel.TextTruncate = Enum.TextTruncate.AtEnd

        row.Activated:Connect(function()
            local now = os.clock()
            local doubleClick = lastTreeClickPath == entry.path
                and lastTreeClickIsFolder == entry.isFolder
                and now - lastTreeClickTime <= 0.38
            lastTreeClickPath = entry.path
            lastTreeClickIsFolder = entry.isFolder
            lastTreeClickTime = now

            selectedTreePath = entry.path
            selectedTreeIsFolder = entry.isFolder
            BigCode.updateAutoExecuteMenuButton()
            if updatePathBar then updatePathBar() end

            if doubleClick then
                lastTreeClickPath = nil
                if entry.isFolder then
                    Settings.ProjectNavigation.currentViewDir = entry.path
                    selectedTreePath = ""
                    selectedTreeIsFolder = true
                    if updatePathBar then updatePathBar() end
                    renderFileTree()
                    return
                end

                -- Open the selected file in a full-screen editor view.
                if currentProject and (BigCode.mode or editorBox.TextEditable) then
                    BigCode.syncCurrentFile()
                    saveData()
                end
                if BigCode.clearMode then BigCode.clearMode() end
                currentProject.activeFile = entry.path
                Settings.ProjectNavigation.viewingFile = true
                if Settings.ProjectNavigation.editorMenu then Settings.ProjectNavigation.editorMenu.Visible = false end
                if toolsPanel then toolsPanel.Visible = false end
                refreshEditorFileHeader(entry.path)
                local currentFile = getProjectFile(currentProject, entry.path)
                local fileSource = currentFile and currentFile.code or entry.file.code or ""

                if Settings.ProjectNavigation.codePanel then
                    Settings.ProjectNavigation.codePanel.Visible = true
                    Settings.ProjectNavigation.codePanel.Position = UDim2.fromOffset(7, 0)
                    Settings.ProjectNavigation.codePanel.Size = UDim2.new(1, -14, 1, 0)
                end
                if Settings.ProjectNavigation.treePanel then Settings.ProjectNavigation.treePanel.Visible = false end
                if editorViewport then
                    editorViewport.Visible = true
                    editorViewport.CanvasPosition = Vector2.new(0,0)
                end
                if Settings.ProjectNavigation.gutterBg then Settings.ProjectNavigation.gutterBg.Visible = true end
                if Settings.ProjectNavigation.newlineButton then Settings.ProjectNavigation.newlineButton.Visible = true end
                if Settings.ProjectNavigation.pasteButton then Settings.ProjectNavigation.pasteButton.Visible = true end
                if editorFileLabel then editorFileLabel.Visible = true end
                if Settings.ProjectNavigation.backButton then
                    Settings.ProjectNavigation.backButton.Text = "←"
                    Settings.ProjectNavigation.backButton.Size = UDim2.fromOffset(34, 30)
                    Settings.ProjectNavigation.backButton.TextSize = 18
                end
                if Settings.ProjectNavigation.treeToggleButton then
                    Settings.ProjectNavigation.treeToggleButton.Visible = true
                    Settings.ProjectNavigation.treeToggleButton.Active = true
                    Settings.ProjectNavigation.treeToggleButton.AutoButtonColor = true
                    Settings.ProjectNavigation.treeToggleButton.TextColor3 = COLORS.Accent
                end

                if BigCode.shouldUsePreview(fileSource) then
                    BigCode.render(fileSource)
                else
                    editorBox.Visible = true
                    editorBox.TextEditable = true
                    editorBox.Text = fileSource
                    task.defer(measureEditorCanvas)
                end
                currentProject.updated = os.time()
                saveData()
                if updatePathBar then updatePathBar() end
                editorStatus.Text = "Editing: " .. entry.path
                editorStatus.TextColor3 = COLORS.Green
                return
            end

            renderFileTree()
        end)
    end
    BigCode.updateAutoExecuteMenuButton()
end

Settings.ProjectNavigation.showCreateItemPopup = function()
    if not currentProject then return end
    local overlay = make("Frame", {
        Name = "InputOverlay",
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = Color3.fromRGB(0,0,0),
        BackgroundTransparency = 0.38,
        BorderSizePixel = 0,
        ZIndex = 80,
        Active = true,
    }, window)
    local pw = math.min(360,windowWidth-30)
    local ph = 210
    local popup = make("Frame", {
        Size = UDim2.fromOffset(pw,ph),
        Position = UDim2.new(0.5,-pw/2,0.5,-ph/2),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 81,
        Active = true,
    }, overlay)
    addCorner(popup,10)
    addStroke(popup,COLORS.Border)
    local title = createLabel(popup,"Create New",UDim2.new(1,-24,0,28),UDim2.fromOffset(14,10),15,COLORS.Text,Enum.Font.GothamBold)
    title.ZIndex = 82

    -- Read-only current project path
    local prefix = currentProject.name .. " / " .. (Settings.ProjectNavigation.currentViewDir ~= "" and Settings.ProjectNavigation.currentViewDir .. " / " or "")
    local pathDisplay = make("TextLabel", {
        Size = UDim2.new(1,-28,0,28),
        Position = UDim2.fromOffset(14,45),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        Text = prefix,
        TextColor3 = COLORS.Muted,
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 82,
    }, popup)
    addCorner(pathDisplay,6)
    make("UIPadding", {PaddingLeft = UDim.new(0,6)}, pathDisplay)

    -- New path portion, entered on its own line
    local input = make("TextBox", {
        Size = UDim2.new(1,-28,0,34),
        Position = UDim2.fromOffset(14,80),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "e.g. Folder/File.lua (no spaces)",
        PlaceholderColor3 = COLORS.Muted,
        TextColor3 = COLORS.Text,
        TextSize = 12,
        Font = Enum.Font.Code,
        ClearTextOnFocus = false,
        ZIndex = 83,
    }, popup)
    addCorner(input,7)

    local message = createLabel(popup,"",UDim2.new(1,-28,0,18),UDim2.fromOffset(14,122),10,COLORS.Red)
    message.ZIndex = 82
    local cancel = createButton(popup,"Cancel",UDim2.fromOffset(88,32),UDim2.new(1,-190,1,-44),function()
        overlay:Destroy()
    end,COLORS.Panel2)
    cancel.ZIndex = 82
    local confirm = createButton(popup,"Create",UDim2.fromOffset(88,32),UDim2.new(1,-102,1,-44),function()
        local value = trim(input.Text)
        if value == "" then message.Text = "Path cannot be empty."; return end

        -- Disallow whitespace in file and folder paths.
        if value:find("%s") then
            message.Text = "Spaces are not allowed. Use _ or -"
            return
        end

        local fullPath = Settings.ProjectNavigation.currentViewDir ~= "" and (Settings.ProjectNavigation.currentViewDir .. "/" .. value) or value
        local normalized = normalizePath(fullPath)
        if not normalized then message.Text = "Invalid path."; return end

        local isFile = getFileExtension(normalized) ~= ""
        if isFile and not isSupportedFile(normalized) then
            message.Text = "Unsupported file type."
            return
        end

        -- If the requested folder already exists, navigate into it instead of failing.
        if pathTaken(currentProject,normalized) then
            if not isFile then
                local isExistingFolder = false
                for _, folder in ipairs(currentProject.folders or {}) do
                    if folder == normalized then
                        isExistingFolder = true
                        break
                    end
                end
                if isExistingFolder then
                    Settings.ProjectNavigation.currentViewDir = normalized
                    selectedTreePath = ""
                    selectedTreeIsFolder = true
                    lastTreeClickPath = nil
                    if updatePathBar then updatePathBar() end
                    renderFileTree()
                    overlay:Destroy()
                    return
                end
            end
            message.Text = "Path already exists."
            return
        end

        -- Create New is available only in the tree view, so no editor buffer needs syncing here.
        ensureParentFolders(currentProject,normalized)
        if isFile then
            table.insert(currentProject.files,{path=normalized,code="",autoExecute=false})
        else
            table.insert(currentProject.folders,normalized)
        end
        selectedTreePath = ""
        selectedTreeIsFolder = true
        currentProject.updated = os.time()
        saveData()
        overlay:Destroy()
        renderFileTree()
        if updatePathBar then updatePathBar() end
        if renderProjects then renderProjects() end
        if renderExecutePage then renderExecutePage() end
        logConsole("Success", "Created " .. (isFile and "file: " or "folder: ") .. normalized)
    end,COLORS.Accent)
    confirm.ZIndex = 82
    input:CaptureFocus()
end

local function showPathPopup(title,initialText,confirmText,onConfirm)
    showTextPopup(title,initialText or "",confirmText or "Create",function(value)
        return onConfirm(value)
    end)
end
local function currentCreationBase()
    if selectedTreePath=="" then return "" end
    if selectedTreeIsFolder then return selectedTreePath end
    return parentPath(selectedTreePath)
end
local function appendToBase(base,name)
    if base=="" then return name end
    return base.."/"..name
end
local function showConfirmPopup(parent,titleText,message,onConfirm)
    local targetParent=parent or window
    local overlay=make("Frame",{Name="ConfirmOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),
        BackgroundTransparency=0.38,BorderSizePixel=0,ZIndex=100,Active=true},targetParent)
    local popupWidth=math.min(360,math.max(260,(targetParent.AbsoluteSize.X or 360)-24))
    local popupHeight=154
    local popup=make("Frame",{Size=UDim2.fromOffset(popupWidth,popupHeight),
        Position=UDim2.new(0.5,-popupWidth/2,0.5,-popupHeight/2),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=101,Active=true},overlay)
    addCorner(popup,10)
    addStroke(popup,COLORS.Border)
    local title=createLabel(popup,titleText,UDim2.new(1,-24,0,26),UDim2.fromOffset(12,8),14,COLORS.Text,Enum.Font.GothamBold)
    title.ZIndex=102
    local messageLabel=createLabel(popup,message,UDim2.new(1,-24,0,48),UDim2.fromOffset(12,39),11,COLORS.Muted)
    messageLabel.TextWrapped=true
    messageLabel.TextYAlignment=Enum.TextYAlignment.Top
    messageLabel.ZIndex=102
    local cancel=createButton(popup,"Cancel",UDim2.fromOffset(86,30),UDim2.new(1,-184,1,-40),function()
        overlay:Destroy()
    end,COLORS.Panel2)
    cancel.ZIndex=102
    local confirm=createButton(popup,"Delete",UDim2.fromOffset(86,30),UDim2.new(1,-92,1,-40),function()
        overlay:Destroy()
        if onConfirm then onConfirm() end
    end,Color3.fromRGB(105,47,57))
    confirm.ZIndex=102
    return overlay
end
createNewFile=function()
    if not currentProject then return end
    local initial=appendToBase(currentCreationBase(),"new.lua")
    showPathPopup("Add file",initial,"Create",function(value)
        local path=normalizePath(value)
        if not path then return false,"Invalid file path." end
        if not path:match("%.[%w_%-]+$") then path=path..".lua" end
        if not isSupportedFile(path) then return false,"Supported: .lua/.luau/.json/.txt/.md" end
        if pathTaken(currentProject,path) then return false,"Path exists." end
        if BigCode.mode or editorBox.TextEditable then
            BigCode.syncCurrentFile()
        end
        if BigCode.clearMode then BigCode.clearMode() end
        ensureParentFolders(currentProject,path)
        local newFile={path=path,code="",autoExecute=false}
        table.insert(currentProject.files,newFile)
        currentProject.activeFile=path
        editorBox.TextEditable=true
        editorBox.Text=""
        refreshEditorFileHeader(path)
        editorViewport.CanvasPosition=Vector2.new(0,0)
        selectedTreePath=path
        selectedTreeIsFolder=false
        currentProject.updated=os.time()
        saveData()
        renderFileTree()
        if updatePathBar then updatePathBar() end
        if renderProjects then renderProjects() end
        if renderExecutePage then renderExecutePage() end
        return true
    end)
end
createNewFolder=function()
    if not currentProject then return end
    local initial=appendToBase(currentCreationBase(),"NewFolder")
    showPathPopup("Add folder",initial,"Create",function(value)
        local path=normalizePath(value)
        if not path then return false,"Invalid folder path." end
        if pathTaken(currentProject,path) then return false,"Path exists." end
        if BigCode.mode or editorBox.TextEditable then BigCode.syncCurrentFile() end
        ensureParentFolders(currentProject,path)
        table.insert(currentProject.folders,path)
        selectedTreePath=path
        selectedTreeIsFolder=true
        expandedFolders[path]=true
        currentProject.updated=os.time()
        saveData()
        renderFileTree()
        if updatePathBar then updatePathBar() end
        if renderProjects then renderProjects() end
        return true
    end)
end
renameSelectedPath=function(requestedPath)
    if not currentProject then return false,"No project is open." end
    if selectedTreePath=="" then return true end
    local oldPath=selectedTreePath
    local isFolder=selectedTreeIsFolder
    local newPath=normalizePath(requestedPath)
    if not newPath then return false,"Invalid path." end
    if newPath==oldPath then return true end
    if BigCode.mode or editorBox.TextEditable then BigCode.syncCurrentFile() end
    if isFolder then
        local oldPrefix=oldPath.."/"
        if string.sub(newPath,1,#oldPrefix)==oldPrefix then return false,"Cannot move inside itself." end
        if pathTaken(currentProject,newPath,nil,oldPath) then return false,"Path exists." end
        local mappedFiles={}
        for _,file in ipairs(currentProject.files) do
            local inside=file.path==oldPath or string.sub(file.path,1,#oldPrefix)==oldPrefix
            if inside then
                local suffix=file.path==oldPath and "" or string.sub(file.path,#oldPath+2)
                local mapped=suffix=="" and newPath or (newPath.."/"..suffix)
                if not isSupportedFile(mapped) then return false,"Folder contains unsupported: "..mapped end
                if mappedFiles[mapped] then return false,"Duplicate path." end
                mappedFiles[mapped]=true
            end
        end
        for _,file in ipairs(currentProject.files) do
            local inside=file.path==oldPath or string.sub(file.path,1,#oldPrefix)==oldPrefix
            if not inside and mappedFiles[file.path] then return false,"Overwrites existing file." end
        end
        for _,folder in ipairs(currentProject.folders) do
            local inside=folder==oldPath or string.sub(folder,1,#oldPrefix)==oldPrefix
            if not inside and (folder==newPath or string.sub(folder,1,#newPath+1)==newPath.."/") then
                return false,"Overlaps folder."
            end
        end
        local activePath=currentProject.activeFile
        if activePath==oldPath then currentProject.activeFile=newPath
        elseif string.sub(activePath or "",1,#oldPrefix)==oldPrefix then
            currentProject.activeFile=newPath..string.sub(activePath,#oldPath+1)
        end
        for _,file in ipairs(currentProject.files) do
            if file.path==oldPath then file.path=newPath
            elseif string.sub(file.path,1,#oldPrefix)==oldPrefix then
                file.path=newPath..string.sub(file.path,#oldPath+1)
            end
        end
        for i,folder in ipairs(currentProject.folders) do
            if folder==oldPath then currentProject.folders[i]=newPath
            elseif string.sub(folder,1,#oldPrefix)==oldPrefix then
                currentProject.folders[i]=newPath..string.sub(folder,#oldPath+1)
            end
        end
        local movedExpanded={}
        for path,expanded in pairs(expandedFolders) do
            if path==oldPath then movedExpanded[newPath]=expanded
            elseif string.sub(path,1,#oldPrefix)==oldPrefix then
                movedExpanded[newPath..string.sub(path,#oldPath+1)]=expanded
            else
                movedExpanded[path]=expanded
            end
        end
        expandedFolders=movedExpanded
        ensureParentFolders(currentProject,newPath)
    else
        local oldExtension=getFileExtension(oldPath)
        if not newPath:match("%.[%w_%-]+$") then newPath=newPath.."."..oldExtension end
        if not isSupportedFile(newPath) then return false,"Supported: .lua/.luau/.json/.txt/.md" end
        if pathTaken(currentProject,newPath,oldPath) then return false,"Path exists." end
        local file=getProjectFile(currentProject,oldPath)
        if not file then return false,"File gone." end
        file.path=newPath
        if not isScriptFile(newPath) then file.autoExecute=false end
        if currentProject.activeFile==oldPath then currentProject.activeFile=newPath end
        ensureParentFolders(currentProject,newPath)
    end
    selectedTreePath=newPath
    currentProject.updated=os.time()
    saveData()
    renderFileTree()
    if updatePathBar then updatePathBar() end
    if renderProjects then renderProjects() end
    if renderExecutePage then renderExecutePage() end
    if currentProject.activeFile then refreshEditorFileHeader(currentProject.activeFile) end
    logConsole("Success","Renamed "..oldPath.." to "..newPath)
    return true
end
deleteSelectedTree=function()
    if not currentProject then return false,"No project is open." end
    if not selectedTreePath or selectedTreePath=="" then return false,"Select a file or folder first." end
    if BigCode.mode or editorBox.TextEditable then
        BigCode.syncCurrentFile()
    end
    local target=selectedTreePath
    local deletingFolder=selectedTreeIsFolder
    if not deletingFolder and #currentProject.files<=1 then
        logConsole("Warning","Project needs at least 1 file.")
        return false,"Project needs at least 1 file."
    end
    if BigCode.clearMode then BigCode.clearMode() end
    if deletingFolder then
        local prefix=target.."/"
        for i=#currentProject.files,1,-1 do
            local filePath=currentProject.files[i].path
            if filePath==target or string.sub(filePath,1,#prefix)==prefix then
                table.remove(currentProject.files,i)
            end
        end
        for i=#currentProject.folders,1,-1 do
            local folderPath=currentProject.folders[i]
            if folderPath==target or string.sub(folderPath,1,#prefix)==prefix then
                table.remove(currentProject.folders,i)
            end
        end
        logConsole("Info","Deleted folder: "..target)
    else
        if #currentProject.files<=1 then
            logConsole("Warning","Project needs at least 1 file.")
            return false,"Project needs at least 1 file."
        end
        for i,file in ipairs(currentProject.files) do
            if file.path==target then table.remove(currentProject.files,i); break end
        end
        logConsole("Info","Deleted file: "..target)
    end
    if #currentProject.files==0 then
        table.insert(currentProject.files,{path="main.lua",code="",autoExecute=false})
        currentProject.folders={}
        currentProject.activeFile="main.lua"
    elseif deletingFolder then
        local activeFile=getProjectFile(currentProject,currentProject.activeFile)
        if not activeFile then currentProject.activeFile=currentProject.files[1].path end
    elseif currentProject.activeFile==target then
        currentProject.activeFile=currentProject.files[1].path
    end
    local activeFile=getProjectFile(currentProject,currentProject.activeFile)
    refreshEditorFileHeader(currentProject.activeFile)
    local activeSource=activeFile and activeFile.code or ""
    if BigCode.shouldUsePreview(activeSource) then
        BigCode.render(activeSource)
    else
        editorBox.Visible=true
        editorBox.TextEditable=true
        editorBox.Text=activeSource
        task.defer(measureEditorCanvas)
    end
    editorViewport.CanvasPosition=Vector2.new(0,0)
    selectedTreePath=currentProject.activeFile
    selectedTreeIsFolder=false
    currentProject.updated=os.time()
    saveData()
    renderFileTree()
    if updatePathBar then updatePathBar() end
    if renderProjects then renderProjects() end
    if renderExecutePage then renderExecutePage() end
    return true
end
updatePathBar=function()
    if not currentProject or not pathBar then return end
    local displayText=currentProject.name
    local displayPath=selectedTreePath
    if displayPath=="" and not Settings.ProjectNavigation.viewingFile then displayPath=Settings.ProjectNavigation.currentViewDir end
    if displayPath~="" then displayText=displayText.." / "..displayPath end
    pathBarUpdating=true
    local lastSlash=0
    local scan=1
    while true do
        local found=string.find(displayText,"/",scan,true)
        if not found then break end
        lastSlash=found
        scan=found+1
    end
    if lastSlash>0 then
        pathBarParts.prefixLabel.Text=string.sub(displayText,1,lastSlash)
        pathBarParts.input.Text=trim(string.sub(displayText,lastSlash+1))
    else
        pathBarParts.prefixLabel.Text=""
        pathBarParts.input.Text=displayText
    end
    pathBarParts.inputOriginalText=pathBarParts.input.Text
    pathBarParts.updateSize()
    pathBarUpdating=false
    pathCommitButton.Text="Save"
    pathCommitButton.Visible=true
    pathCancelButton.Visible=false
end
Settings.ProjectNavigation.editorMenu=make("Frame",{Name="EditorDropdown",Size=UDim2.fromOffset(compact and 142 or 164,130),
    Position=UDim2.fromOffset(10,82),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,Visible=false,ZIndex=30,Active=true},editorPage)
addCorner(Settings.ProjectNavigation.editorMenu,8)
addStroke(Settings.ProjectNavigation.editorMenu,COLORS.Border)
createLabel(Settings.ProjectNavigation.editorMenu,"Editor",UDim2.new(1,-16,0,22),UDim2.fromOffset(8,3),11,COLORS.Text,Enum.Font.GothamBold).ZIndex=31
local createNewMenuButton=createButton(Settings.ProjectNavigation.editorMenu,"Create New",UDim2.new(1,-12,0,27),UDim2.fromOffset(6,28),function()
    Settings.ProjectNavigation.editorMenu.Visible=false
    if Settings.ProjectNavigation.showCreateItemPopup then Settings.ProjectNavigation.showCreateItemPopup() end
end,COLORS.Accent)
createNewMenuButton.Name = "CreateNewButton"
createNewMenuButton.ZIndex=31
do
local setMainMenuButton=createButton(Settings.ProjectNavigation.editorMenu,"Set as Main",UDim2.new(1,-12,0,27),UDim2.fromOffset(6,59),function()
    Settings.ProjectNavigation.editorMenu.Visible=false
    if not currentProject then return end
    if not selectedTreePath or selectedTreePath=="" then
        logConsole("Warning","Select a file first.")
        openConsole()
        return
    end
    if selectedTreeIsFolder then
        logConsole("Warning","Folders cannot be set as Main. Select a file.")
        openConsole()
        return
    end
    currentProject.mainFile=selectedTreePath
    currentProject.updated=os.time()
    saveData()
    renderFileTree()
    logConsole("Success","Main file set to: " .. selectedTreePath)
end,COLORS.Accent)
setMainMenuButton.ZIndex=31
end
local deleteMenuButton=createButton(Settings.ProjectNavigation.editorMenu,"Delete",UDim2.new(1,-12,0,27),UDim2.fromOffset(6,90),function()
    Settings.ProjectNavigation.editorMenu.Visible=false
    if not selectedTreePath or selectedTreePath=="" then
        logConsole("Warning","Select a file or folder first.")
        openConsole()
        return
    end
    local target=selectedTreePath
    showConfirmPopup(window,"Confirm Delete","Delete "..target.."? This cannot be undone.",function()
        local ok,err=deleteSelectedTree()
        if not ok and err then
            editorStatus.Text=tostring(err)
            editorStatus.TextColor3=COLORS.Red
        end
    end)
end,Color3.fromRGB(105,47,57))
deleteMenuButton.ZIndex=31
toolsPanel=make("Frame",{Name="ToolsPanel",Size=UDim2.fromOffset(compact and 190 or 220,187),Position=UDim2.fromOffset(48,48),
    BackgroundColor3=COLORS.Panel,BorderSizePixel=0,Visible=false,ZIndex=20,Active=true},editorPage)
addCorner(toolsPanel,9); addStroke(toolsPanel,COLORS.Border)
createLabel(toolsPanel,"Tools",UDim2.new(1,-18,0,24),UDim2.fromOffset(10,4),13,COLORS.Text,Enum.Font.GothamBold).ZIndex=21
local toolDexButton=createButton(toolsPanel,"Dex Explorer",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,32),nil,COLORS.Panel2); toolDexButton.ZIndex=21
local toolRemoteButton=createButton(toolsPanel,"RemoteSpy",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,67),nil,COLORS.Panel2); toolRemoteButton.ZIndex=21
local toolFreeCamButton=createButton(toolsPanel,"FreeCam",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,102),nil,COLORS.Panel2); toolFreeCamButton.ZIndex=21
findMatches = {}
findCurrentIndex = 1
do
    local findPopup = nil
    local findStatusLabel = nil
    local findOverlay = nil
    local queryForSelection = ""
    BigCode.findOverlay = nil
    local function placeFindOverlay(targetBox, startPos, matchLength, query)
        if not findOverlay or not findOverlay.Parent then return end
        if not targetBox or not targetBox.Parent then return end
        local text = targetBox.Text or ""
        local safeStart = math.max(1, tonumber(startPos) or 1)
        local prefix = string.sub(text, 1, safeStart - 1)
        local lineNum = select(2, prefix:gsub("\n", "")) + 1
        local lastBreak = 0
        local scan = 1
        while true do
            local found = string.find(prefix, "\n", scan, true)
            if not found then break end
            lastBreak = found
            scan = found + 1
        end
        local linePrefix = string.sub(prefix, lastBreak + 1)
        local textSize = targetBox.TextSize
        local font = targetBox.Font
        local lineHeight = math.max(textSize + 2,
            TextService:GetTextSize("Ag", textSize, font, Vector2.new(100000, 100000)).Y * 1.3)
        local charWidth = TextService:GetTextSize(
            linePrefix ~= "" and linePrefix or " ", textSize, font, Vector2.new(100000, 100000)
        ).X
        local matchText = string.sub(text, safeStart, safeStart + math.max(0, matchLength or 0) - 1)
        local matchWidth = TextService:GetTextSize(
            matchText ~= "" and matchText or (query or " "), textSize, font, Vector2.new(100000, 100000)
        ).X
        findOverlay.Parent = targetBox
        findOverlay.Position = UDim2.fromOffset(charWidth, (lineNum - 1) * lineHeight)
        findOverlay.Size = UDim2.fromOffset(math.max(2, matchWidth), lineHeight)
        findOverlay.ZIndex = targetBox.ZIndex + 1
        findOverlay.Visible = true
    end
    local function findVirtualSlot(globalIndex)
        for slotIndex, mappedIndex in ipairs(BigCode.slotChunkIndices or {}) do
            if mappedIndex == globalIndex then
                local slot = BigCode.virtualSlots[slotIndex]
                if slot and slot.Parent and slot.Visible then
                    return slot
                end
            end
        end
        return nil
    end
    local function updateFindStatus()
        if findStatusLabel and findStatusLabel.Parent then
            if #findMatches == 0 then
                findStatusLabel.Text = "0/0"
            else
                findStatusLabel.Text = tostring(findCurrentIndex) .. "/" .. tostring(#findMatches)
            end
        end
    end
    local function scrollToMatch(index)
        local match = findMatches[index]
        if not match then
            updateFindStatus()
            return false
        end
        findCurrentIndex = index
        updateFindStatus()
        local selectionQuery = queryForSelection
        if BigCode.mode and match.chunkIndex then
            BigCode.getSource()
            BigCode.refreshLayout(true)
            local chunkIndex = match.chunkIndex
            local chunk = BigCode.chunks[chunkIndex] or ""
            local foundPos = match.startPos
            local prefix = string.sub(chunk, 1, math.max(0, foundPos - 1))
            local precedingLines = select(2, prefix:gsub("\n", ""))
            local linePrefix = prefix:match("([^\n]*)$") or ""
            local lineMetrics = TextService:GetTextSize(
                "Ag", editorBox.TextSize, Enum.Font.Code, Vector2.new(100000, 100000)
            )
            local lineHeight = math.max(editorBox.TextSize + 2, lineMetrics.Y * 1.3)
            local lineWidth = TextService:GetTextSize(
                linePrefix ~= "" and linePrefix or " ", editorBox.TextSize, Enum.Font.Code,
                Vector2.new(100000, 100000)
            ).X
            local targetY = (BigCode.chunkOffsets[chunkIndex] or 6) + precedingLines * lineHeight
            editorViewport.CanvasPosition = Vector2.new(
                math.max(0, lineWidth - 16),
                math.max(0, targetY - 20)
            )
            BigCode.updateVirtualScroll()
            task.defer(function()
                if not BigCode.mode then return end
                BigCode.updateVirtualScroll()
                local slot = findVirtualSlot(chunkIndex)
                if not slot then
                    task.defer(function()
                        if not BigCode.mode then return end
                        BigCode.updateVirtualScroll()
                        slot = findVirtualSlot(chunkIndex)
                        if not slot then
                            logConsole("Warning", "Found text, but its editor slot is not available.")
                            return
                        end
                        placeFindOverlay(slot, foundPos, #selectionQuery, selectionQuery)
                    end)
                    return
                end
                placeFindOverlay(slot, foundPos, #selectionQuery, selectionQuery)
            end)
            return true
        end
        local source = editorBox.Text or ""
        local foundPos = match.startPos
        local prefix = string.sub(source, 1, math.max(0, foundPos - 1))
        local precedingLines = select(2, prefix:gsub("\n", ""))
        local linePrefix = prefix:match("([^\n]*)$") or ""
        local metrics = TextService:GetTextSize(
            "Ag", editorBox.TextSize, editorBox.Font, Vector2.new(100000, 100000)
        )
        local lineHeight = math.max(editorBox.TextSize + 2, metrics.Y * 1.3)
        local lineWidth = TextService:GetTextSize(
            linePrefix ~= "" and linePrefix or " ", editorBox.TextSize, editorBox.Font,
            Vector2.new(100000, 100000)
        ).X
        local targetY = 6 + precedingLines * lineHeight
        editorViewport.CanvasPosition = Vector2.new(
            math.max(0, lineWidth - 16),
            math.max(0, targetY - 20)
        )
        placeFindOverlay(editorBox, foundPos, #selectionQuery, selectionQuery)
        return true
    end
    local function performSearch(query)
        query = tostring(query or "")
        findMatches = {}
        findCurrentIndex = 1
        queryForSelection = query
        updateFindStatus()
        if query == "" then return end
        if BigCode.mode then
            BigCode.getSource()
            BigCode.refreshLayout(true)
            for chunkIndex, chunk in ipairs(BigCode.chunks) do
                local searchFrom = 1
                while searchFrom <= #chunk do
                    local foundPos = string.find(chunk, query, searchFrom, true)
                    if not foundPos then break end
                    table.insert(findMatches, {
                        chunkIndex = chunkIndex,
                        startPos = foundPos,
                    })
                    searchFrom = foundPos + 1
                end
            end
        else
            local source = editorBox.Text or ""
            local searchFrom = 1
            while searchFrom <= #source do
                local foundPos = string.find(source, query, searchFrom, true)
                if not foundPos then break end
                table.insert(findMatches, {startPos = foundPos})
                searchFrom = foundPos + 1
            end
        end
        if #findMatches == 0 then
            updateFindStatus()
            logConsole("Warning", "Not found: " .. query)
            return
        end
        findCurrentIndex = 1
        updateFindStatus()
        scrollToMatch(findCurrentIndex)
    end
    local function openFindPopup()
        if findPopup and findPopup.Parent then
            findPopup:Destroy()
        end
        findMatches = {}
        findCurrentIndex = 1
        if not findOverlay or not findOverlay.Parent then
            findOverlay = make("Frame", {
                Name = "FindOverlay",
                Size = UDim2.fromOffset(0, 0),
                BackgroundColor3 = Color3.fromRGB(50, 100, 200),
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Visible = false,
                Active = false,
                Selectable = false,
                ZIndex = 60,
            }, editorViewport)
        end
        BigCode.findOverlay = findOverlay
        findPopup = make("Frame", {
            Name = "FindPopup",
            Size = UDim2.fromOffset(300, 110),
            Position = UDim2.new(1, -310, 0, 125),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            Active = true,
            Visible = true,
            ZIndex = 90,
        }, editorPage)
        addCorner(findPopup, 8)
        addStroke(findPopup, COLORS.Border)
        local findInput = make("TextBox", {
            Name = "FindInput",
            Size = UDim2.fromOffset(150, 28),
            Position = UDim2.fromOffset(8, 10),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Find...",
            PlaceholderColor3 = COLORS.Muted,
            TextColor3 = COLORS.Text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 91,
        }, findPopup)
        addCorner(findInput, 6)
        local findButton = createButton(findPopup, "Find", UDim2.fromOffset(58, 28), UDim2.fromOffset(166, 10), function()
            performSearch(findInput.Text)
        end, COLORS.Accent)
        findButton.ZIndex = 91
        local closeButton = createButton(findPopup, "X", UDim2.fromOffset(28, 28), UDim2.fromOffset(264, 10), function()
            if findOverlay then findOverlay.Visible = false end
            if findPopup then
                findPopup:Destroy()
                findPopup = nil
                findStatusLabel = nil
            end
        end, COLORS.Panel2)
        closeButton.ZIndex = 91
        closeButton.TextSize = 15
        local previousButton = createButton(findPopup, "<", UDim2.fromOffset(48, 26), UDim2.fromOffset(8, 54), function()
            if #findMatches == 0 then return end
            findCurrentIndex = ((findCurrentIndex - 2) % #findMatches) + 1
            scrollToMatch(findCurrentIndex)
        end, COLORS.Panel2)
        previousButton.ZIndex = 91
        findStatusLabel = createLabel(findPopup, "0/0", UDim2.fromOffset(174, 26), UDim2.fromOffset(62, 54), 10, COLORS.Muted)
        findStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
        findStatusLabel.ZIndex = 91
        local nextButton = createButton(findPopup, ">", UDim2.fromOffset(48, 26), UDim2.fromOffset(244, 54), function()
            if #findMatches == 0 then return end
            findCurrentIndex = (findCurrentIndex % #findMatches) + 1
            scrollToMatch(findCurrentIndex)
        end, COLORS.Panel2)
        nextButton.ZIndex = 91
        findInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                performSearch(findInput.Text)
            end
        end)
        task.defer(function()
            if findInput and findInput.Parent then
                findInput:CaptureFocus()
            end
        end)
    end
    local toolFindButton = createButton(toolsPanel, "Find", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 137), function()
        toolsPanel.Visible = false
        openFindPopup()
    end, COLORS.Panel2)
    toolFindButton.ZIndex = 21
end
Settings.Replay.replayGetRoot = function()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end
Settings.REPLAY_HISTORY_FILE = ROOT_FOLDER .. "/replay_history.json"
Settings.replaySaveHistory = function()
    if not fileStorageAvailable then return end
    ensureFolder()
    local historyToSave = {}
    for _, entry in ipairs(Settings.Replay.history) do
        local savedEntry = {}
        for key, value in pairs(entry) do
            if key ~= "_cachedCode" then
                savedEntry[key] = value
            end
        end
        table.insert(historyToSave, savedEntry)
    end
    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(historyToSave) end)
    if okEnc then pcall(writefile, Settings.REPLAY_HISTORY_FILE, encoded) end
end
Settings.replayLoadHistory = function()
    if not fileStorageAvailable then return end
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, Settings.REPLAY_HISTORY_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local okDec, dec = pcall(function() return HttpService:JSONDecode(raw) end)
    if okDec and type(dec) == "table" then
        Settings.Replay.history = dec
    end
end
Settings.Replay.replayCanHookRemote = function()
    local missing = {}
    if type(hookmetamethod) ~= "function" then table.insert(missing, "hookmetamethod") end
    if type(getrawmetatable) ~= "function" then table.insert(missing, "getrawmetatable") end
    if type(setreadonly) ~= "function" then table.insert(missing, "setreadonly") end
    if type(getnamecallmethod) ~= "function" then table.insert(missing, "getnamecallmethod") end
    if type(newcclosure) ~= "function" then table.insert(missing, "newcclosure") end
    if #missing == 0 then return true, nil end
    return false, table.concat(missing, ", ")
end
Settings.Replay.replaySerializeValue = function(v, depth)
    depth = depth or 0
    if depth > 3 then return "nil --[[ too deep ]]" end
    local t = typeof(v)
    if t == "number" then
        if v ~= v then return "0/0" end
        if v == math.huge then return "math.huge" end
        if v == -math.huge then return "-math.huge" end
        return tostring(v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "string" then return string.format("%q", v)
    elseif t == "Vector3" then return string.format("Vector3.new(%f,%f,%f)", v.X, v.Y, v.Z)
    elseif t == "Vector2" then return string.format("Vector2.new(%f,%f)", v.X, v.Y)
    elseif t == "CFrame" then return string.format("CFrame.new(%f,%f,%f)", v.Position.X, v.Position.Y, v.Position.Z)
    elseif t == "Color3" then return string.format("Color3.fromRGB(%d,%d,%d)", math.floor(v.R*255+0.5), math.floor(v.G*255+0.5), math.floor(v.B*255+0.5))
    elseif t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            if #parts >= 50 then break end
            local keyStr = type(k) == "string" and string.format("[%q]", k) or ("[" .. tostring(k) .. "]")
            table.insert(parts, keyStr .. "=" .. Settings.Replay.replaySerializeValue(val, depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil --[[ SKIPPED: " .. t .. " ]]"
end
Settings.Replay.replayPush = function(waitTime, kind, codeLine, tx, ty, tz)
    local Replay = Settings.Replay
    table.insert(Replay.queue, {wait = waitTime, kind = kind, code = codeLine, targetX = tx, targetY = ty, targetZ = tz})
end
Settings.Replay.replayGenerateCode = function(queueOverride, durationOverride)
    local Replay = Settings.Replay
    local queue = queueOverride or Replay.queue
    local lines = {}
    local now = durationOverride or (Replay.startTime > 0 and (os.clock() - Replay.startTime) or 0)
    table.insert(lines, "-- Replay generated code")
    table.insert(lines, "-- Events: " .. tostring(#queue))
    table.insert(lines, "-- Duration: " .. string.format("%.1f", now) .. " sec")
    table.insert(lines, "")
    table.insert(lines, "local Players = game:GetService(\"Players\")")
    table.insert(lines, "local LocalPlayer = Players.LocalPlayer")
    table.insert(lines, "local camera = workspace.CurrentCamera")
    table.insert(lines, "")
    table.insert(lines, "local function getRoot()")
    table.insert(lines, "    local char = LocalPlayer.Character")
    table.insert(lines, "    if not char then return nil end")
    table.insert(lines, "    return char:FindFirstChild(\"HumanoidRootPart\")")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local function getHum()")
    table.insert(lines, "    local char = LocalPlayer.Character")
    table.insert(lines, "    if not char then return nil end")
    table.insert(lines, "    return char:FindFirstChildOfClass(\"Humanoid\")")
    table.insert(lines, "end")
    table.insert(lines, "local hum = getHum()")
    table.insert(lines, "")
    local firstPos = nil
    for _, item in ipairs(queue) do
        if (item.kind == "pos" or item.kind == "walk" or item.kind == "jump") and item.targetX then
            firstPos = item
            break
        end
    end
    if firstPos then
        table.insert(lines, string.format([[ do
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(%.3f, %.3f, %.3f)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end]], firstPos.targetX, firstPos.targetY, firstPos.targetZ))
        table.insert(lines, "")
    end
    local prevWasPos = false
    local i = 1
    while i <= #queue do
        local item = queue[i]
        if item.kind == "walk" and item.targetX then
            local startIndex = i
            local totalTime = item.wait or 0
            local lastWalk = item
            local j = i + 1
            while j <= #queue and queue[j].kind == "walk" and queue[j].targetX do
                totalTime = totalTime + (queue[j].wait or 0)
                lastWalk = queue[j]
                j = j + 1
            end
            local dist = 0
            local previousPoint = queue[startIndex - 1]
            if previousPoint and previousPoint.targetX then
                dist = math.sqrt(
                    (lastWalk.targetX - previousPoint.targetX)^2
                    + (lastWalk.targetY - previousPoint.targetY)^2
                    + (lastWalk.targetZ - previousPoint.targetZ)^2
                )
            end
            table.insert(lines, string.format("hum:MoveTo(Vector3.new(%.1f, %.1f, %.1f))", lastWalk.targetX, lastWalk.targetY, lastWalk.targetZ))
            table.insert(lines, string.format("task.wait(%.2f)", math.max(totalTime, 0.05)))
            prevWasPos = true
            i = j
        elseif item.kind == "jump" and item.targetX then
            if not prevWasPos and item.wait > 0.01 then
                table.insert(lines, string.format("task.wait(%.2f)", item.wait))
            end
            local nextWait = 0.3
            if queue[i + 1] then nextWait = queue[i + 1].wait end
            nextWait = math.max(nextWait, 0.15)
            table.insert(lines, string.format("do local h = getHum(); if h then h:MoveTo(Vector3.new(%.1f, %.1f, %.1f)); if h.FloorMaterial ~= Enum.Material.Air then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end", item.targetX, item.targetY, item.targetZ))
            table.insert(lines, string.format("task.wait(%.2f)", nextWait))
            prevWasPos = true
            i = i + 1
        elseif item.kind == "pos" and item.targetX then
            if not prevWasPos and item.wait > 0.01 then
                table.insert(lines, string.format("task.wait(%.2f)", item.wait))
            end
            local nextWait = 0.3
            if queue[i + 1] then nextWait = queue[i + 1].wait end
            nextWait = math.max(nextWait, 0.1)
            table.insert(lines, string.format("do local h = getHum(); if h then h:MoveTo(Vector3.new(%.1f, %.1f, %.1f)); if h.FloorMaterial ~= Enum.Material.Air then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end", item.targetX, item.targetY, item.targetZ))
            table.insert(lines, string.format("task.wait(%.2f)", nextWait))
            prevWasPos = true
            i = i + 1
        else
            if not prevWasPos and item.wait > 0.01 then
                table.insert(lines, string.format("task.wait(%.2f)", item.wait))
            end
            if item.code and item.code ~= "" then
                table.insert(lines, item.code)
            end
            prevWasPos = false
            i = i + 1
        end
    end
    table.insert(lines, "")
    table.insert(lines, "-- Cleanup after replay")
    table.insert(lines, "do local hum = getHum(); if hum then hum.Jump = false; hum:Move(Vector3.zero, false) end end")
    return table.concat(lines, "\n")
end
Settings.replayStopAndSave = function()
    local Replay = Settings.Replay
    if not Replay.recording then return end
    Replay.recording = false
    if Replay.connectionHeartbeat then Replay.connectionHeartbeat:Disconnect(); Replay.connectionHeartbeat = nil end
    if Replay.connectionStateChanged then Replay.connectionStateChanged:Disconnect(); Replay.connectionStateChanged = nil end
    if Replay.connectionCharAdded then Replay.connectionCharAdded:Disconnect(); Replay.connectionCharAdded = nil end
    if Replay.connectionInput then Replay.connectionInput:Disconnect(); Replay.connectionInput = nil end
    if Replay.hookInstalled and Replay.hookOriginal and Replay.hookMetatable and type(setreadonly) == "function" then
        pcall(function()
            setreadonly(Replay.hookMetatable, false)
            Replay.hookMetatable.__namecall = Replay.hookOriginal
            setreadonly(Replay.hookMetatable, true)
        end)
    end
    Replay.hookInstalled = false
    Replay.hookOriginal = nil
    Replay.hookMetatable = nil
    if Replay.recBar then Replay.recBar.Visible = false end
    if Replay.recDotPulse then Replay.recDotPulse:Cancel() end
    Replay.generating = true
    if Replay.renderUI then Replay.renderUI() end
    task.spawn(function()
        task.wait(0.15)
        local queueSnapshot = Replay.queue
        local queueSize = 0
        local sizeOk, sizeEnc = pcall(function() return HttpService:JSONEncode(queueSnapshot) end)
        if sizeOk and type(sizeEnc) == "string" then queueSize = #sizeEnc end
        local entry = {
            name = "Replay " .. os.date("%Y-%m-%d %H:%M:%S"),
            queue = queueSnapshot,
            codeSize = queueSize,
            timestamp = os.time(),
            events = #queueSnapshot,
            duration = (Replay.startTime > 0 and (os.clock() - Replay.startTime) or 0),
        }
        table.insert(Replay.history, 1, entry)
        Settings.replaySaveHistory()
        logConsole("Success", "Replay saved: " .. entry.name .. " (" .. entry.events .. " events, " .. tostring(entry.codeSize) .. " bytes)")

        Replay.generating = false
        Replay.viewMode = "list"
        if Replay.renderUI then Replay.renderUI() end
        if Settings.openReplayCodeViewer then Settings.openReplayCodeViewer(entry) end
    end)
end
Settings.replayStart = function()
    local Replay = Settings.Replay
    if Replay.recording then return end
    Replay.queue = {}
    Replay.warned90 = false
    Replay.recording = true
    Replay.startTime = os.clock()
    Replay.lastEventTime = os.clock()
    Replay.lastPosTime = 0
    Replay.lastCFrame = nil
    Replay.remoteHookCount = 0
    if Replay.recBar then
        Replay.recBar.Visible = true
        if Replay.recTimeLabel then Replay.recTimeLabel.Text = "00:00" end
        if Replay.recDotPulse then Replay.recDotPulse:Play() end
    end
    local stopKey = nil
    if Replay.stopKeyName and Replay.stopKeyName ~= "" then
        local ok, kc = pcall(function() return Enum.KeyCode[string.upper(Replay.stopKeyName)] end)
        if ok then stopKey = kc end
    end
    if Replay.connectionInput then Replay.connectionInput:Disconnect() end
    Replay.connectionInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if Replay.recording and stopKey and input.KeyCode == stopKey then
            Settings.replayStopAndSave()
        end
    end)
    Replay.connectionHeartbeat = RunService.Heartbeat:Connect(function()
        if not Replay.recording then return end
        local now = os.clock() - Replay.startTime
        if now > Replay.maxMinutes * 60 then
            Settings.replayStopAndSave()
            return
        end
        if Replay.recordMode ~= "events" then
            local root = Replay.replayGetRoot()
            if root then
                local cf = root.CFrame
                local shouldRecord = false
                if not Replay.lastCFrame then
                    shouldRecord = true
                else
                    local dPos = (cf.Position - Replay.lastCFrame.Position).Magnitude
                    local dRot = (cf.LookVector - Replay.lastCFrame.LookVector).Magnitude
                    if dPos > 0.5 or dRot > 0.1 then shouldRecord = true end
                end
                if shouldRecord and (now - Replay.lastPosTime >= Replay.updateInterval) then
                    local dt = os.clock() - Replay.lastEventTime
                    Replay.lastEventTime = os.clock()
                    local rx = math.floor(cf.Position.X * 10 + 0.5) / 10
                    local ry = math.floor(cf.Position.Y * 10 + 0.5) / 10
                    local rz = math.floor(cf.Position.Z * 10 + 0.5) / 10
                    local hum = root and root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
                    local onGround = hum and hum.FloorMaterial ~= Enum.Material.Air
                    local kind = onGround and "walk" or "jump"
                    local line = ""
                    Replay.replayPush(dt, kind, line, rx, ry, rz)
                    Replay.lastCFrame = cf
                    Replay.lastPosTime = now
                end
            end
        end
        local mins = math.floor(now / 60)
        local secs = math.floor(now % 60)
        if Replay.recTimeLabel then
            Replay.recTimeLabel.Text = string.format("%02d:%02d", mins, secs)
        end
        if Replay.statusLabel and Replay.statusLabel.Parent then
            Replay.statusLabel.Text = string.format("Recording... %02d:%02d | %d events", mins, secs, #Replay.queue)
            Replay.statusLabel.TextColor3 = COLORS.Yellow
        end
    end)
    local function bindHum(hum)
        if Replay.recordMode == "events" then return end
        if Replay.connectionStateChanged then Replay.connectionStateChanged:Disconnect() end
        Replay.connectionStateChanged = hum.StateChanged:Connect(function(_, newState)
            if not Replay.recording then return end
            if newState ~= Enum.HumanoidStateType.Jumping then return end
            local dt1 = os.clock() - Replay.lastEventTime
            Replay.lastEventTime = os.clock()
            local root = Replay.replayGetRoot()
            if root then
                local rx = math.floor(root.CFrame.Position.X * 10 + 0.5) / 10
                local ry = math.floor(root.CFrame.Position.Y * 10 + 0.5) / 10
                local rz = math.floor(root.CFrame.Position.Z * 10 + 0.5) / 10
                Replay.replayPush(dt1, "jump", "", rx, ry, rz)
            else
                local jumpLine = "do local hum = getHum(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end"
                Replay.replayPush(dt1, "jump", jumpLine)
            end
        end)
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then bindHum(hum) end
    Replay.connectionCharAdded = LocalPlayer.CharacterAdded:Connect(function(newChar)
        local newHum = newChar:WaitForChild("Humanoid", 5)
        if newHum then bindHum(newHum) end
    end)
    pcall(function()
        if not Replay.hookSupported then return end
        if type(hookmetamethod) ~= "function" or type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function" or type(getnamecallmethod) ~= "function" or type(newcclosure) ~= "function" then return end
        local mt = getrawmetatable(game)
        if not mt then return end
        local oldNamecall = mt.__namecall
        local wrapped = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if Replay.recording and method == "FireServer" and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
                if Replay.recordMode == "movement" then
                    return oldNamecall(self, ...)
                end
                if Replay.remoteBlacklist and #Replay.remoteBlacklist > 0 then
                    for _, name in ipairs(Replay.remoteBlacklist) do
                        if self.Name:lower() == tostring(name):lower() then
                            return oldNamecall(self, ...)
                        end
                    end
                end
                local now = os.clock()
                local dt1 = now - Replay.lastEventTime
                Replay.lastEventTime = now
                local argsList = {...}
                local serialized = {}
                local hasSkipped = false
                for _, a in ipairs(argsList) do
                    local valueText = Replay.replaySerializeValue(a)
                    if valueText:find("SKIPPED") then hasSkipped = true end
                    table.insert(serialized, valueText)
                end
                local path = "game"
                local cur = self
                while cur and cur ~= game do
                    path = cur.Name .. (path == "game" and "" or ("." .. path))
                    cur = cur.Parent
                end
                path = "game." .. path:gsub("^" .. self.Name .. "%.?", "")
                if cur == game then
                    local comment = hasSkipped and " --[[ some args skipped ]]" or ""
                    local line = string.format("do local ok, target = pcall(function() return %s end); if ok and target then pcall(function() target:FireServer(unpack(%s)) end) end end%s",
                        tostring(path), "{" .. table.concat(serialized, ",") .. "}", comment)
                    if Replay.recordMode ~= "events" then
                        local root = Replay.replayGetRoot()
                        if root then
                            local rx = math.floor(root.CFrame.Position.X * 10 + 0.5) / 10
                            local ry = math.floor(root.CFrame.Position.Y * 10 + 0.5) / 10
                            local rz = math.floor(root.CFrame.Position.Z * 10 + 0.5) / 10
                            Replay.replayPush(dt1, "walk", "", rx, ry, rz)
                            local dt2 = 0.03
                            Replay.lastEventTime = Replay.lastEventTime + dt2
                            Replay.replayPush(dt2, "remote", line)
                        else
                            Replay.replayPush(dt1, "remote", line)
                        end
                    else
                        Replay.replayPush(dt1, "remote", line)
                    end
                    Replay.remoteHookCount = Replay.remoteHookCount + 1
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, false)
        mt.__namecall = wrapped
        setreadonly(mt, true)
        Replay.hookOriginal = oldNamecall
        Replay.hookMetatable = mt
        Replay.hookInstalled = true
    end)
end
local function raiseZIndex(root,value)
    if root:IsA("GuiObject") then root.ZIndex=value end
    for _,child in ipairs(root:GetChildren()) do if child:IsA("GuiObject") then raiseZIndex(child,value+1) end end
end
local function makeToolWindow(name,titleText,width,height,onClose)
    local maxW, maxH = Settings.getMaxToolSize()
    width = math.min(width, maxW)
    height = math.min(height, maxH)
    local frame=make("Frame",{Name=name,Size=UDim2.fromOffset(width,height),Position=UDim2.new(0.5,-width/2,0.5,-height/2),
        BackgroundColor3=COLORS.Background,BorderSizePixel=0,Visible=true,ZIndex=50,Active=true},screenGui)
    addCorner(frame,10); addStroke(frame,COLORS.Border)
    local bar=make("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=51},frame)
    addCorner(bar,10)
    local title=createLabel(bar,"  "..titleText,UDim2.new(1,-48,1,0),UDim2.fromOffset(6,0),13,COLORS.Text,Enum.Font.GothamBold); title.ZIndex=52
    local close=createButton(bar,"X",UDim2.fromOffset(28,26),UDim2.new(1,-34,0,6),function() if onClose then onClose() else frame.Visible=false end end)
    close.TextSize=18; close.ZIndex=52
    local content=make("Frame",{Name="Content",Position=UDim2.fromOffset(8,44),Size=UDim2.new(1,-16,1,-52),BackgroundTransparency=1,ZIndex=51},frame)
    return frame,content
end
Settings.openReplayCodeViewer = function(entry)
    if not entry then return end
    local Replay = Settings.Replay
    if Replay.codeViewerWindow and Replay.codeViewerWindow.Parent then
        Replay.codeViewerWindow:Destroy()
    end
    local maxW, maxH = Settings.getMaxToolSize()
    local vw = math.max(300, math.min(720, maxW))
    local vh = math.max(240, math.min(500, maxH - 20))
    local frame = make("Frame", {Name="ReplayCodeViewer", Size=UDim2.fromOffset(vw,vh), Position=UDim2.new(0.5,-vw/2,0.5,-vh/2), BackgroundColor3=COLORS.Background, BorderSizePixel=0, ZIndex=3000, Active=true, ClipsDescendants=true}, screenGui)
    addCorner(frame, 10)
    addStroke(frame, COLORS.Border)
    Settings.registerModalWindow(frame)
    Replay.codeViewerWindow = frame
    local header = make("Frame", {Size=UDim2.new(1,0,0,40), BackgroundColor3=COLORS.Panel, BorderSizePixel=0, ZIndex=3001}, frame)
    addCorner(header, 10)
    createLabel(header, "  Replay Code: "..tostring(entry.name), UDim2.new(1,-80,1,0), UDim2.fromOffset(8,0), 12, COLORS.Text, Enum.Font.GothamBold).ZIndex=3002
    local closeBtn = createButton(header, "X", UDim2.fromOffset(28,26), UDim2.new(1,-34,0,7), function()
        if frame and frame.Parent then frame:Destroy() end
        Replay.codeViewerWindow = nil
        if Replay.viewMode == "list" and Replay.renderUI then Replay.renderUI() end
    end, COLORS.Panel2)
    closeBtn.ZIndex=3002
    closeBtn.TextSize=16
    local codeStr = entry.code
    if not codeStr or codeStr == "" then
        if entry._cachedCode then
            codeStr = entry._cachedCode
        elseif entry.queue then
            local genOk, genCode = pcall(function()
                return Settings.Replay.replayGenerateCode(entry.queue, entry.duration)
            end)
            if genOk and type(genCode) == "string" then
                codeStr = genCode
                entry._cachedCode = genCode
            end
        end
    end
    codeStr = codeStr or ""
    local infoSize = #codeStr
    local sizeColor = COLORS.Muted
    if infoSize > 500000 then sizeColor = COLORS.Red
    elseif infoSize > 200000 then sizeColor = COLORS.Yellow end
    createLabel(frame, "Events: "..tostring(entry.events or 0).." | Duration: "..string.format("%.1f", entry.duration or 0).."s | "..os.date("%Y-%m-%d %H:%M", entry.timestamp or 0), UDim2.new(1,-140,0,18), UDim2.fromOffset(8,44), 9, COLORS.Muted).ZIndex=3001
    local sizeInfoLbl = createLabel(frame, "Size: "..formatBytes(infoSize), UDim2.new(0, 140, 0, 18), UDim2.new(1, -148, 0, 44), 9, sizeColor, Enum.Font.GothamBold)
    sizeInfoLbl.TextXAlignment = Enum.TextXAlignment.Right
    sizeInfoLbl.ZIndex = 3001
    local copyBtn
    copyBtn = createButton(frame, "Copy Code", UDim2.fromOffset(110,26), UDim2.new(1,-118,0,68), function()
        if type(setclipboard) ~= "function" then
            copyBtn.Text = "No clipboard"
            task.delay(1, function() if copyBtn and copyBtn.Parent then copyBtn.Text = "Copy Code" end end)
            return
        end
        local ok = pcall(setclipboard, codeStr)
        copyBtn.Text = ok and "Copied!" or "Copy failed"
        task.delay(1, function() if copyBtn and copyBtn.Parent then copyBtn.Text = "Copy Code" end end)
    end, COLORS.Accent)
    copyBtn.ZIndex=3001
    copyBtn.TextSize=10
    local scroll = make("ScrollingFrame", {Position=UDim2.fromOffset(8,100), Size=UDim2.new(1,-16,1,-108), BackgroundColor3=COLORS.Panel, BorderSizePixel=0, ScrollBarThickness=7, CanvasSize=UDim2.fromOffset(0,0), ZIndex=3001}, frame)
    addCorner(scroll, 7)
    local maxChars = 30000
    local displayStr = codeStr
    if #codeStr > maxChars then
        displayStr = string.sub(codeStr, 1, maxChars) .. "\n\n--[[ TRUNCATED: "..#codeStr.." total chars. Click 'Copy Code' to get the rest. ]]"
    end
    local codeLbl = make("TextLabel", {
        Size = UDim2.fromOffset(2000, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        Text = displayStr,
        TextColor3 = COLORS.Text,
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        ZIndex = 3001
    }, scroll)
    task.defer(function()
        if scroll and scroll.Parent and codeLbl and codeLbl.Parent then
            scroll.CanvasSize = UDim2.fromOffset(2000 + 16, codeLbl.AbsoluteSize.Y + 16)
        end
    end)
    raiseZIndex(frame, 100)
end
Settings.openReplayHistory = function()
    local Replay = Settings.Replay
    if Replay.historyWindow and Replay.historyWindow.Parent then
        Replay.historyWindow.Visible = true
        return
    end
    local maxW, maxH = Settings.getMaxToolSize()
    local w = math.max(280, math.min(460, maxW))
    local h = math.max(280, math.min(340, maxH))
    local frame, content
    frame, content = makeToolWindow("ReplayHistoryWindow", "Replay - All Recordings", w, h, function()
        frame.Visible = false
    end)
    Replay.historyWindow = frame
    Settings.registerModalWindow(frame)
    local function render()
        for _, child in ipairs(content:GetChildren()) do child:Destroy() end
        if #Replay.history == 0 then
            createLabel(content, "No replays saved yet.", UDim2.new(1,0,0,30), UDim2.fromOffset(4,4), 11, COLORS.Muted).ZIndex=55
            return
        end
        local list = make("ScrollingFrame", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.fromOffset(0,0), ZIndex=55}, content)
        local layout = make("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, list)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
        end)
        for i, entry in ipairs(Replay.history) do
            local row = make("Frame", {Size=UDim2.new(1,-8,0,56), BackgroundColor3=COLORS.Panel, BorderSizePixel=0, LayoutOrder=i, ZIndex=55}, list)
            addCorner(row, 6)
            addStroke(row, COLORS.Border, 0.5)
            createLabel(row, tostring(entry.name or "?"), UDim2.new(1,-16,0,20), UDim2.fromOffset(8,4), 10, COLORS.Text, Enum.Font.GothamBold).ZIndex=56
            createLabel(row, "Events: "..tostring(entry.events or 0).." | "..string.format("%.1f", entry.duration or 0).."s | "..os.date("%H:%M %d.%m", entry.timestamp or 0), UDim2.new(1,-16,0,16), UDim2.fromOffset(8,26), 9, COLORS.Muted).ZIndex=56
            local viewBtn = createButton(row, "View", UDim2.fromOffset(60,24), UDim2.new(1,-134,0,16), function()
                Settings.openReplayCodeViewer(entry)
            end, COLORS.Accent)
            viewBtn.ZIndex=56
            viewBtn.TextSize=10
            local delBtn = createButton(row, "Delete", UDim2.fromOffset(64,24), UDim2.new(1,-70,0,16), function()
                for index, savedEntry in ipairs(Replay.history) do
                    if savedEntry == entry then
                        table.remove(Replay.history, index)
                        break
                    end
                end
                Settings.replaySaveHistory()
                render()
            end, Color3.fromRGB(105,47,57))
            delBtn.ZIndex=56
            delBtn.TextSize=10
        end
    end
    render()
    raiseZIndex(frame, 50)
end
Settings.openReplayWindow = function()
    local Replay = Settings.Replay
    local hookOK, hookMissing = Replay.replayCanHookRemote()
    Replay.hookSupported = hookOK
    Replay.hookMissingInfo = hookMissing
    if not hookOK then
        logConsole("Warning", "Replay: hookmetamethod unavailable ("..tostring(hookMissing).."). RemoteEvent recording disabled.")
        if Replay.recordMode == "all" or Replay.recordMode == "events" then
            Replay.recordMode = "movement"
        end
    end
    if Replay.window and Replay.window.Parent then
        Replay.window.Visible = true
        Replay.viewMode = "list"
        if Replay.renderUI then Replay.renderUI() end
        return
    end
    local maxW, maxH = Settings.getMaxToolSize()
    local w = math.max(280, math.min(500, maxW))
    local h = math.max(300, math.min(420, maxH))
    local frame, content
    frame, content = makeToolWindow("ReplayWindow", "Replay", w, h, function()
        if Replay.recording then Settings.replayStopAndSave() end
        frame.Visible = false
    end)
    Replay.window = frame
    Replay.content = content
    Replay.viewMode = "list"
    Settings.registerModalWindow(frame)
    local function createSettingRow(parent, labelText, defaultValue, y)
        createLabel(parent, labelText, UDim2.new(0.55, -8, 0, 20), UDim2.fromOffset(4, y), 10, COLORS.Text).ZIndex = 55
        local box = make("TextBox", {
            Size = UDim2.new(0.45, -8, 0, 24),
            Position = UDim2.new(0.55, 4, 0, y - 2),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            Text = defaultValue,
            TextColor3 = COLORS.Text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            ZIndex = 55,
        }, parent)
        addCorner(box, 6)
        return box
    end
    local function renderList()
        local header = make("Frame", {Size=UDim2.new(1, 0, 0, 36), BackgroundTransparency=1, ZIndex=55}, content)
        local newBtn = createButton(header, "+ New Recording", UDim2.new(0.4, -4, 1, 0), UDim2.new(0, 0, 0, 0), function()
            Replay.viewMode = "record"
            Replay.renderUI()
        end, COLORS.Accent)
        newBtn.TextSize = 11
        newBtn.ZIndex = 55
        if Replay.hookSupported then
            local blacklistBtn = createButton(header, "Blacklist ("..#Replay.remoteBlacklist..")", UDim2.new(0.32, -4, 1, 0), UDim2.new(0.4, 0, 0, 0), function()
                Replay.viewMode = "blacklist"
                Replay.renderUI()
            end, #Replay.remoteBlacklist > 0 and COLORS.Yellow or COLORS.Panel2)
            blacklistBtn.TextSize = 10
            blacklistBtn.ZIndex = 55
        end
        local totalSize = 0
        for _, e in ipairs(Replay.history) do
            local s = e.codeSize or #(e.code or "")
            if s == 0 and e.queue then
                local okS, enc = pcall(function() return HttpService:JSONEncode(e.queue) end)
                if okS then s = #enc end
            end
            totalSize = totalSize + s
        end
        local countLabel = createLabel(header, "Saved: "..#Replay.history.."\n"..formatBytes(totalSize), UDim2.new(0.28, -4, 1, 0), UDim2.new(0.72, 4, 0, 0), 9, COLORS.Muted)
        countLabel.TextXAlignment = Enum.TextXAlignment.Right
        countLabel.ZIndex = 55
        if not Replay.hookSupported then
            local warnFrame = make("Frame", {Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 42), BackgroundColor3 = Color3.fromRGB(58, 28, 28), BorderSizePixel = 0, ZIndex = 55}, content)
            addCorner(warnFrame, 6)
            addStroke(warnFrame, COLORS.Red, 0.4)
            local warnText = createLabel(warnFrame, "WARNING: RemoteEvent recording unavailable (missing: "..tostring(Replay.hookMissingInfo).."). Movement works.", UDim2.new(1, -8, 1, 0), UDim2.fromOffset(4, 0), 9, COLORS.Yellow)
            warnText.TextWrapped = true
            warnText.TextYAlignment = Enum.TextYAlignment.Center
            warnText.ZIndex = 56
        end
        local listTop = Replay.hookSupported and 46 or 92
        if #Replay.history == 0 then
            createLabel(content, "No replays yet.\nClick + New Recording to start.", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(4, listTop + 20), 11, COLORS.Muted).ZIndex=55
            return
        end
        local list = make("ScrollingFrame", {Position=UDim2.fromOffset(0, listTop), Size=UDim2.new(1, 0, 1, -listTop), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.fromOffset(0,0), ZIndex=55}, content)
        local layout = make("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, list)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
        end)
        for i, entry in ipairs(Replay.history) do
            local row = make("Frame", {Size=UDim2.new(1,-8,0,56), BackgroundColor3=COLORS.Panel, BorderSizePixel=0, LayoutOrder=i, ZIndex=55}, list)
            addCorner(row, 6)
            addStroke(row, COLORS.Border, 0.5)
            local codeSize = entry.codeSize or #(entry.code or "")
            if codeSize == 0 and entry.queue then
                local okSize, encoded = pcall(function() return HttpService:JSONEncode(entry.queue) end)
                if okSize then codeSize = #encoded end
            end
            local sizeColor = COLORS.Muted
            if codeSize > 500000 then sizeColor = COLORS.Red
            elseif codeSize > 200000 then sizeColor = COLORS.Yellow end
            createLabel(row, tostring(entry.name or "?"), UDim2.new(1,-150,0,20), UDim2.fromOffset(8,4), 10, COLORS.Text, Enum.Font.GothamBold).ZIndex=56
            createLabel(row, "Events: "..tostring(entry.events or 0).." | "..string.format("%.1f", entry.duration or 0).."s | "..os.date("%H:%M %d.%m", entry.timestamp or 0), UDim2.new(1,-150,0,16), UDim2.fromOffset(8,26), 9, COLORS.Muted).ZIndex=56
            local sizeLbl = createLabel(row, formatBytes(codeSize), UDim2.new(0, 70, 0, 14), UDim2.new(1, -78, 0, 26), 9, sizeColor, Enum.Font.GothamBold)
            sizeLbl.TextXAlignment = Enum.TextXAlignment.Right
            sizeLbl.ZIndex = 56
            local viewBtn = createButton(row, "View", UDim2.fromOffset(60,24), UDim2.new(1,-134,0,16), function()
                Settings.openReplayCodeViewer(entry)
            end, COLORS.Accent)
            viewBtn.ZIndex=56
            viewBtn.TextSize=10
            local delBtn = createButton(row, "Delete", UDim2.fromOffset(64,24), UDim2.new(1,-70,0,16), function()
                for index, savedEntry in ipairs(Replay.history) do
                    if savedEntry == entry then
                        table.remove(Replay.history, index)
                        break
                    end
                end
                Settings.replaySaveHistory()
                Replay.renderUI()
            end, Color3.fromRGB(105,47,57))
            delBtn.ZIndex=56
            delBtn.TextSize=10
        end
    end
    local function renderRecordSettings()
        local backBtn = createButton(content, "← Back to list", UDim2.new(0, 130, 0, 26), UDim2.fromOffset(0, 0), function()
            Replay.viewMode = "list"
            Replay.renderUI()
        end, COLORS.Panel2)
        backBtn.TextSize = 10
        backBtn.ZIndex = 55
        createLabel(content, "New Recording Settings", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(4, 36), 12, COLORS.Text, Enum.Font.GothamBold).ZIndex = 55
        local stopKeyBox = createSettingRow(content, "Stop key:", Replay.stopKeyName or "F8", 68)
        local maxTimeBox = createSettingRow(content, "Max time (min):", tostring(Replay.maxMinutes), 98)
        local updateBox = createSettingRow(content, "Update interval (0.1-3s):", tostring(Replay.updateInterval), 128)
        local modeNames = {
            all = "Mode: Movement + FireEvents",
            events = "Mode: FireEvents ONLY",
            movement = "Mode: Movement ONLY",
        }
        local modeColors = {
            all = COLORS.Panel2,
            events = COLORS.Accent,
            movement = COLORS.Green,
        }
        local currentMode = Replay.recordMode or "all"
        if not modeNames[currentMode] then
            currentMode = "all"
            Replay.recordMode = "all"
        end
        if not Replay.hookSupported then
            currentMode = "movement"
            Replay.recordMode = "movement"
            local staticLabel = createLabel(content, "Mode: Movement ONLY", UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 158), 11, COLORS.Text, Enum.Font.GothamBold)
            staticLabel.TextXAlignment = Enum.TextXAlignment.Center
            staticLabel.BackgroundColor3 = COLORS.Green
            staticLabel.BackgroundTransparency = 0.5
            staticLabel.ZIndex = 55
            addCorner(staticLabel, 8)
            local hint = createLabel(content, "FireEvent hook unavailable — only movement recording. Reason: " .. tostring(Replay.hookMissingInfo or "unknown"), UDim2.new(1, -8, 0, 32), UDim2.fromOffset(4, 190), 9, COLORS.Muted)
            hint.TextWrapped = true
            hint.TextYAlignment = Enum.TextYAlignment.Top
            hint.ZIndex = 55
        else
            local modeBtn = createButton(content, modeNames[currentMode], UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 158), function()
                if Replay.recordMode == "all" then
                    Replay.recordMode = "events"
                elseif Replay.recordMode == "events" then
                    Replay.recordMode = "movement"
                else
                    Replay.recordMode = "all"
                end
                Replay.renderUI()
            end, modeColors[currentMode])
            modeBtn.TextSize = 11
            modeBtn.ZIndex = 55
        end
        if Replay.hookSupported then
            createLabel(content, "Blacklist: "..#Replay.remoteBlacklist.." remote(s) ignored. Edit in List screen.", UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 192), 9, COLORS.Muted).ZIndex = 55
        end
        local startY = Replay.hookSupported and 214 or 232
        local startBtn = createButton(content, "Start Recording", UDim2.new(1, -8, 0, 40), UDim2.new(0, 4, 0, startY), function()
            local kcName = trim(stopKeyBox.Text)
            if kcName ~= "" then
                local ok, kc = pcall(function() return Enum.KeyCode[string.upper(kcName)] end)
                if not ok or kc == nil then
                    Replay.statusLabel = createLabel(content, "Invalid key: " .. kcName, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(4, 260), 9, COLORS.Red)
                    return
                end
                Replay.stopKeyName = string.upper(kcName)
            else
                Replay.stopKeyName = "F8"
            end
            Replay.maxMinutes = math.max(1, tonumber(maxTimeBox.Text) or 60)
            Replay.updateInterval = math.clamp(tonumber(updateBox.Text) or 0.5, 0.1, 3)
            Settings.replayStart()
            Replay.renderUI()
        end, COLORS.Accent)
        startBtn.TextSize = 12
        startBtn.ZIndex = 55
        local statusY = Replay.hookSupported and 258 or 276
        Replay.statusLabel = createLabel(content, "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(4, statusY), 9, COLORS.Muted)
        Replay.statusLabel.ZIndex = 55
    end
    local function renderRecording()
        Replay.statusLabel = createLabel(content, "Recording started...", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(4, 40), 13, COLORS.Yellow)
        Replay.statusLabel.TextXAlignment = Enum.TextXAlignment.Center
        Replay.statusLabel.ZIndex = 55
        local stopBtn = createButton(content, "Stop & Save", UDim2.new(0.5, -4, 0, 44), UDim2.new(0, 4, 0, 90), function()
            Settings.replayStopAndSave()
        end, COLORS.Red)
        stopBtn.TextSize = 13
        stopBtn.ZIndex = 55
        createLabel(content, "Press " .. tostring(Replay.stopKeyName) .. " or click button to stop.", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(4, 145), 9, COLORS.Muted).ZIndex = 55
    end
    local function renderGenerating()
        local genLabel = createLabel(content, "Generating code...", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(4, 100), 13, COLORS.Yellow)
        genLabel.TextXAlignment = Enum.TextXAlignment.Center
        genLabel.TextYAlignment = Enum.TextYAlignment.Center
        genLabel.ZIndex = 55
    end
    local function renderBlacklist()
        local backBtn = createButton(content, "Back to list", UDim2.new(0, 130, 0, 26), UDim2.fromOffset(0, 0), function()
            Replay.viewMode = "list"
            Replay.renderUI()
        end, COLORS.Panel2)
        backBtn.TextSize = 10
        backBtn.ZIndex = 55
        createLabel(content, "FireEvent Blacklist ("..#Replay.remoteBlacklist..")", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(4, 36), 12, COLORS.Text, Enum.Font.GothamBold).ZIndex = 55
        createLabel(content, "Remotes with these names will NOT be recorded. Match is case-insensitive.", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(4, 58), 9, COLORS.Muted).ZIndex = 55
        local inputBox = make("TextBox", {
            Size = UDim2.new(0.7, -4, 0, 28),
            Position = UDim2.fromOffset(4, 80),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Remote name (e.g. MouseMove)",
            PlaceholderColor3 = COLORS.Muted,
            TextColor3 = COLORS.Text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            ZIndex = 55,
        }, content)
        addCorner(inputBox, 6)
        local addBtn = createButton(content, "Add", UDim2.new(0.28, -4, 0, 28), UDim2.new(0.72, 0, 0, 80), function()
            local name = trim(inputBox.Text)
            if name == "" then return end
            for _, existingName in ipairs(Replay.remoteBlacklist) do
                if tostring(existingName):lower() == name:lower() then return end
            end
            table.insert(Replay.remoteBlacklist, name)
            inputBox.Text = ""
            Replay.renderUI()
        end, COLORS.Accent)
        addBtn.TextSize = 11
        addBtn.ZIndex = 55
        if #Replay.remoteBlacklist == 0 then
            createLabel(content, "No ignored remotes yet.\nType a remote name above and press Add.", UDim2.new(1, 0, 0, 50), UDim2.fromOffset(4, 120), 10, COLORS.Muted).ZIndex = 55
            return
        end
        local list = make("ScrollingFrame", {Position=UDim2.fromOffset(4, 120), Size=UDim2.new(1, -8, 1, -124), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.fromOffset(0,0), ZIndex=55}, content)
        local layout = make("UIListLayout", {Padding=UDim.new(0, 4), SortOrder=Enum.SortOrder.LayoutOrder}, list)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
        end)
        for i, name in ipairs(Replay.remoteBlacklist) do
            local row = make("Frame", {Size=UDim2.new(1, -8, 0, 30), BackgroundColor3=COLORS.Panel, BorderSizePixel=0, LayoutOrder=i, ZIndex=55}, list)
            addCorner(row, 6)
            addStroke(row, COLORS.Border, 0.5)
            createLabel(row, tostring(name), UDim2.new(1, -50, 1, 0), UDim2.fromOffset(10, 0), 11, COLORS.Text, Enum.Font.Code).ZIndex = 56
            local delBtn = createButton(row, "X", UDim2.fromOffset(28, 24), UDim2.new(1, -34, 0, 3), function()
                table.remove(Replay.remoteBlacklist, i)
                Replay.renderUI()
            end, Color3.fromRGB(105, 47, 57))
            delBtn.TextSize = 12
            delBtn.ZIndex = 56
        end
    end
    Replay.renderUI = function()
        if not Replay.content or not Replay.content.Parent then return end
        for _, child in ipairs(Replay.content:GetChildren()) do child:Destroy() end
        if Replay.generating then renderGenerating()
        elseif Replay.recording then renderRecording()
        elseif Replay.viewMode == "record" then renderRecordSettings()
        elseif Replay.viewMode == "blacklist" then renderBlacklist()
        else renderList() end
    end
    Replay.renderUI()
    raiseZIndex(frame, 50)
end
local AI_PROVIDERS = {
    {
        id = "pollinations",
        name = "Pollinations",
        url = "https://gen.pollinations.ai/v1/chat/completions",
        keyRequired = false,
        defaultModel = "openai",
        cooldownSeconds = 31,
        models = {
            { id = "openai", label = "OpenAI (via Pollinations)" },
        },
    },
    {
        id = "groq",
        name = "Groq",
        url = "https://api.groq.com/openai/v1/chat/completions",
        keyRequired = true,
        defaultModel = "openai/gpt-oss-120b",
        cooldownSeconds = 0,
        dynamicModels = true,
        models = {},
    },
    {
        id = "nvidia",
        name = "NVIDIA NIM",
        url = "https://integrate.api.nvidia.com/v1/chat/completions",
        keyRequired = true,
        defaultModel = "nvidia/nemotron-3-super-120b-a12b",
        cooldownSeconds = 0,
        models = {
            { id = "nvidia/nemotron-3-super-120b-a12b", label = "Nemotron 3 Super 120B" },
            { id = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning", label = "Nemotron 3 Nano (fast)" },
            { id = "deepseek-ai/deepseek-v4.1-flash", label = "DeepSeek V4.1 Flash" },
            { id = "z-ai/glm-5.3-flash", label = "GLM 5.3 Flash" },
            { id = "moonshotai/kimi-k3", label = "Kimi K3" },
            { id = "meta/llama-4-maverick-17b-128e-instruct", label = "Llama 4 Maverick" },
            { id = "openai/gpt-oss-120b", label = "GPT-OSS 120B" },
        },
    },
}
local AI_KEYS_FILE = ROOT_FOLDER .. "/ai_keys.json"
local AI_CHATS_FILE = ROOT_FOLDER .. "/ai_chats.json"
local function loadAIKeys()
    if type(readfile) ~= "function" then return {} end
    local ok, raw = pcall(readfile, AI_KEYS_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return {} end
    local okDec, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okDec or type(data) ~= "table" then return {} end
    local keys = {}
    for id, value in pairs(data) do
        if type(id) == "string" and type(value) == "string" then keys[id] = value end
    end
    return keys
end
local function saveAIKey(providerId, key)
    if type(writefile) ~= "function" then return false end
    ensureFolder()
    local all = loadAIKeys()
    all[tostring(providerId)] = tostring(key or "")
    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(all) end)
    if not okEnc then return false end
    return pcall(writefile, AI_KEYS_FILE, encoded)
end
local function loadAIChats()
    if type(readfile) ~= "function" then return {} end
    local ok, raw = pcall(readfile, AI_CHATS_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return {} end
    local okDec, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if okDec and type(data) == "table" then return data end
    return {}
end
local function saveAIChat(chatKey, history)
    if type(writefile) ~= "function" then return false end
    ensureFolder()
    local all = loadAIChats()
    all[chatKey] = { history = history, updated = os.time() }
    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(all) end)
    if not okEnc then return false end
    return pcall(writefile, AI_CHATS_FILE, encoded)
end
local function deleteAIChat(chatKey)
    if type(writefile) ~= "function" then return false end
    ensureFolder()
    local all = loadAIChats()
    if all[chatKey] then
        all[chatKey] = nil
        local okEnc, encoded = pcall(function() return HttpService:JSONEncode(all) end)
        if not okEnc then return false end
        return pcall(writefile, AI_CHATS_FILE, encoded)
    end
    return true
end
local function chatKeyFor(providerId, modelId)
    return tostring(providerId) .. ":" .. tostring(modelId)
end
openAIChat = function()
    local existing = editorPage:FindFirstChild("AIChatWindow")
    if existing then
        existing.Visible = true
        existing.ZIndex = 80
        return
    end
    local aiKeys = loadAIKeys()
    local maxW, maxH = Settings.getMaxToolSize()
    local chatW = math.min(compact and 340 or 560, maxW)
    local chatH = math.min(compact and 500 or 560, maxH)
    local chatWidth = UDim2.fromOffset(chatW, chatH)
    local frame = make("Frame", {
        Name = "AIChatWindow",
        Size = chatWidth,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 80,
        ClipsDescendants = true,
        Active = true,
    }, editorPage)
    addCorner(frame, 10)
    addStroke(frame, COLORS.Border)
    Settings.registerModalWindow(frame)
    local header = make("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 81,
    }, frame)
    addCorner(header, 10)
    local backButton = createButton(header, "←", UDim2.fromOffset(30, 28), UDim2.fromOffset(6, 6), nil, COLORS.Panel2)
    backButton.ZIndex = 82
    backButton.TextSize = 18
    backButton.Visible = false
    local titleLabel = createLabel(header, "  AI Chat — Choose service", UDim2.new(1, -82, 1, 0), UDim2.fromOffset(40, 0), 13, COLORS.Text, Enum.Font.GothamBold)
    titleLabel.ZIndex = 82
    local closeButton = createButton(header, "X", UDim2.fromOffset(28, 28), UDim2.new(1, -34, 0, 6), function()
        frame.Visible = false
    end, COLORS.Panel2)
    closeButton.ZIndex = 82
    closeButton.TextSize = 17
    local contentArea = make("Frame", {
        Position = UDim2.fromOffset(8, 48),
        Size = UDim2.new(1, -16, 1, -56),
        BackgroundTransparency = 1,
        ZIndex = 81,
    }, frame)
    local state = {
        mode = "services",
        provider = nil,
        model = nil,
        aiHistory = {},
        sessionHistories = {},
        busy = false,
        cooldownUntil = 0,
        http = (function()
            local h = nil
            pcall(function() h = request or http_request or (syn and syn.request) end)
            return h
        end)(),
        chatKey = nil,
        aiBubbles = {},
    }
    local sendButton, inputBox, statusLabel, messageList, listLayout
    local renderServices, renderModels, renderChat, sendAIMessage, openKeysEditor, addMessage
    local requestAI, regenerateLastResponse
    local function clearContent()
        for _, child in ipairs(contentArea:GetChildren()) do child:Destroy() end
        sendButton, inputBox, statusLabel, messageList, listLayout = nil, nil, nil, nil, nil
    end
    local function updateSendButton()
        if not sendButton or not sendButton.Parent then return end
        if state.busy then
            sendButton.Text = "Sending..."
            sendButton.Active = false
            sendButton.AutoButtonColor = false
            sendButton.BackgroundColor3 = COLORS.Panel2
            return
        end
        local remaining = state.cooldownUntil - os.clock()
        if remaining > 0 then
            sendButton.Text = "Wait " .. tostring(math.ceil(remaining)) .. "s"
            sendButton.Active = false
            sendButton.AutoButtonColor = false
            sendButton.BackgroundColor3 = COLORS.Panel2
        else
            sendButton.Text = "Send"
            sendButton.Active = true
            sendButton.AutoButtonColor = true
            sendButton.BackgroundColor3 = COLORS.Accent
        end
    end
    task.spawn(function()
        while frame.Parent do
            if frame.Visible and state.mode == "chat" then updateSendButton() end
            task.wait(0.15)
        end
    end)
    local function callProvider(provider, modelId, messages)
        if provider.keyRequired and (not aiKeys[provider.id] or aiKeys[provider.id] == "") then
            return nil, "NO_KEY"
        end
        if type(state.http) ~= "function" then return nil, "HTTP_UNAVAILABLE" end
        local headers = { ["Content-Type"] = "application/json" }
        local providerKey = aiKeys[provider.id]
        if provider.keyRequired or (type(providerKey) == "string" and providerKey ~= "") then
            headers["Authorization"] = "Bearer " .. providerKey
        end
        local bodyOk, body = pcall(function()
            return HttpService:JSONEncode({ model = modelId, messages = messages })
        end)
        if not bodyOk then return nil, "ENCODE_FAILED" end
        local ok, response = pcall(function()
            return state.http({ Url = provider.url, Method = "POST", Headers = headers, Body = body })
        end)
        if not ok or type(response) ~= "table" then return nil, "REQUEST_FAILED" end
        local st = tonumber(response.StatusCode or response.Status)
        if st == 401 or st == 403 then return nil, "UNAUTHORIZED" end
        if st == 429 then return nil, "RATE_LIMITED" end
        if st and st >= 500 then return nil, "SERVER_ERROR" end
        if st and st >= 400 then return nil, "HTTP_" .. tostring(st) end
        if type(response.Body) ~= "string" or response.Body == "" then return nil, "EMPTY_BODY" end
        local pOk, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if not pOk or type(data) ~= "table" then return nil, "PARSE_FAILED" end
        if type(data.choices) ~= "table" or not data.choices[1] or type(data.choices[1].message) ~= "table" then
            return nil, "NO_CHOICES"
        end
        local content = data.choices[1].message.content
        if type(content) ~= "string" or trim(content) == "" then return nil, "EMPTY_CONTENT" end
        return content, nil
    end
    local GROQ_MODELS_CACHE_FILE = ROOT_FOLDER .. "/groq_models.json"
    local groqModelsLastFetch = 0
    local function loadGroqModelsCache()
        if type(readfile) ~= "function" then return nil end
        local ok, raw = pcall(readfile, GROQ_MODELS_CACHE_FILE)
        if not ok or type(raw) ~= "string" or raw == "" then return nil end
        local okDec, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if okDec and type(data) == "table" and type(data.models) == "table" then
            return data
        end
        return nil
    end
    local function saveGroqModelsCache(models)
        if type(writefile) ~= "function" then return end
        ensureFolder()
        local payload = { models = models, updated = os.time() }
        local okEnc, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
        if okEnc then pcall(writefile, GROQ_MODELS_CACHE_FILE, encoded) end
    end
    local function fetchGroqModels(forceRefresh)
        local cache = loadGroqModelsCache()
        local now = os.time()
        if not forceRefresh and cache and cache.models and (now - (tonumber(cache.updated) or 0) < 86400) then
            return cache.models, nil
        end
        local key = aiKeys["groq"]
        if not key or key == "" then
            return nil, "NO_KEY"
        end
        if type(state.http) ~= "function" then
            return nil, "HTTP_UNAVAILABLE"
        end
        local ok, response = pcall(function()
            return state.http({
                Url = "https://api.groq.com/openai/v1/models",
                Method = "GET",
                Headers = { ["Authorization"] = "Bearer " .. key },
            })
        end)
        if not ok or type(response) ~= "table" then
            return cache and cache.models or nil, "REQUEST_FAILED"
        end
        local st = tonumber(response.StatusCode or response.Status)
        if st == 401 or st == 403 then
            return cache and cache.models or nil, "UNAUTHORIZED"
        end
        if st and st >= 400 then
            return cache and cache.models or nil, "HTTP_" .. tostring(st)
        end
        if type(response.Body) ~= "string" or response.Body == "" then
            return cache and cache.models or nil, "EMPTY_BODY"
        end
        local pOk, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if not pOk or type(data) ~= "table" or type(data.data) ~= "table" then
            return cache and cache.models or nil, "PARSE_FAILED"
        end
        local list = {}
        for _, item in ipairs(data.data) do
            local id = item.id
            if type(id) == "string" then
                local lower = string.lower(id)
                if not string.find(lower, "whisper", 1, true)
                    and not string.find(lower, "tts", 1, true)
                    and not string.find(lower, "embed", 1, true) then
                    table.insert(list, { id = id, label = id })
                end
            end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        saveGroqModelsCache(list)
        groqModelsLastFetch = now
        return list, nil
    end
    local function makeScrollingList(parent, padding)
        local list = make("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 5,
            ScrollBarImageColor3 = COLORS.Muted,
            CanvasSize = UDim2.fromOffset(0, 0),
            ZIndex = 82,
        }, parent)
        local layout = make("UIListLayout", {
            Padding = UDim.new(0, padding or 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, list)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if list.Parent then list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8) end
        end)
        return list
    end
    renderServices = function()
        state.mode = "services"
        backButton.Visible = false
        titleLabel.Text = "  AI Chat — Choose service"
        clearContent()
        local list = makeScrollingList(contentArea, 8)
        list.Size = UDim2.new(1, 0, 1, -44)
        for i, provider in ipairs(AI_PROVIDERS) do
            local selectedProvider = provider
            local hasKey = not selectedProvider.keyRequired or (aiKeys[selectedProvider.id] and aiKeys[selectedProvider.id] ~= "")
            local row = make("TextButton", {
                Size = UDim2.new(1, -8, 0, 60),
                BackgroundColor3 = COLORS.Panel,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = true,
                LayoutOrder = i,
                ZIndex = 82,
            }, list)
            addCorner(row, 8)
            addStroke(row, COLORS.Border, 0.5)
            local nameLabel = createLabel(row, selectedProvider.name, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 6), 13, COLORS.Text, Enum.Font.GothamBold)
            nameLabel.ZIndex = 83
            local sub = selectedProvider.keyRequired and (hasKey and "API key: saved" or "API key: missing — click Keys") or "No key required"
            local modelCountText = selectedProvider.dynamicModels and "Dynamic model list" or (tostring(#selectedProvider.models) .. " model(s)")
            local subLabel = createLabel(row, sub .. "  •  " .. modelCountText, UDim2.new(1, -20, 0, 18), UDim2.fromOffset(12, 32), 9, hasKey and COLORS.Muted or COLORS.Yellow)
            subLabel.ZIndex = 83
            row.Activated:Connect(function()
                state.provider = selectedProvider
                renderModels()
            end)
        end
        local keysBtn = createButton(contentArea, "Manage API Keys", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -36), openKeysEditor, COLORS.Panel2)
        keysBtn.ZIndex = 82
    end
    renderModels = function()
        state.mode = "models"
        backButton.Visible = true
        titleLabel.Text = "  " .. state.provider.name .. " — Choose model"
        clearContent()
        local list = makeScrollingList(contentArea, 6)
        local modelsToShow = state.provider.models
        local errorNotice = nil
        if state.provider.dynamicModels then
            local loaded, err = fetchGroqModels(false)
            if loaded and #loaded > 0 then
                modelsToShow = loaded
            else
                modelsToShow = { { id = state.provider.defaultModel, label = state.provider.defaultModel } }
                if err then errorNotice = "Models load failed: " .. tostring(err) end
            end
            list.Size = UDim2.new(1, 0, 1, -38)
        end
        if errorNotice then
            local notice = createLabel(contentArea, errorNotice, UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, -20), 9, COLORS.Yellow)
            notice.ZIndex = 82
        end
        local chats = loadAIChats()
        for i, model in ipairs(modelsToShow) do
            local selectedModel = model
            local key = chatKeyFor(state.provider.id, selectedModel.id)
            local selectedKey = key
            local saved = state.sessionHistories[selectedKey] and { history = state.sessionHistories[selectedKey] } or chats[selectedKey]
            local sub = selectedModel.id
            if saved and type(saved.history) == "table" then
                local count = 0
                for _, msg in ipairs(saved.history) do
                    if type(msg) == "table" and msg.role == "user" then count = count + 1 end
                end
                sub = sub .. "  •  " .. tostring(count) .. " msg(s)"
            end
            local row = make("TextButton", {
                Size = UDim2.new(1, -8, 0, 52),
                BackgroundColor3 = COLORS.Panel,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = true,
                LayoutOrder = i,
                ZIndex = 82,
            }, list)
            addCorner(row, 8)
            addStroke(row, COLORS.Border, 0.5)
            local modelLabel = createLabel(row, selectedModel.label or selectedModel.id, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 5), 12, COLORS.Text, Enum.Font.GothamBold)
            modelLabel.ZIndex = 83
            local cooldownSeconds = tonumber(state.provider.cooldownSeconds) or 0
            local cooldownText = cooldownSeconds > 0
                and ("  •  " .. tostring(cooldownSeconds) .. "s cooldown")
                or "  •  no cooldown"
            local subLabel = createLabel(row, sub .. cooldownText, UDim2.new(1, -20, 0, 16), UDim2.fromOffset(12, 28), 9, COLORS.Muted)
            subLabel.ZIndex = 83
            row.Activated:Connect(function()
                state.model = selectedModel
                state.chatKey = selectedKey
                local history = state.sessionHistories[selectedKey]
                local latestStored = loadAIChats()[selectedKey]
                if not history and latestStored and type(latestStored.history) == "table" then history = latestStored.history end
                if type(history) == "table" then
                    state.aiHistory = history
                else
                    state.aiHistory = {
                        { role = "system", content = "You are a helpful Luau scripting assistant inside a Roblox executor. Give concise code examples when asked." },
                    }
                end
                state.sessionHistories[selectedKey] = state.aiHistory
                renderChat()
            end)
        end
        if state.provider.dynamicModels then
            local refreshBtn = createButton(contentArea, "Refresh models", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 1, -30), function()
                if type(writefile) == "function" then
                    pcall(function() writefile(GROQ_MODELS_CACHE_FILE, "") end)
                end
                renderModels()
            end, COLORS.Panel2)
            refreshBtn.ZIndex = 82
            refreshBtn.TextSize = 10
        end
    end
    renderChat = function()
        state.mode = "chat"
        backButton.Visible = true
        titleLabel.Text = "  " .. state.provider.name .. " · " .. (state.model.label or state.model.id)
        clearContent()
        messageList = make("ScrollingFrame", {
            Name = "Messages",
            Size = UDim2.new(1, 0, 1, -150),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            ScrollBarThickness = 5,
            ScrollBarImageColor3 = COLORS.Muted,
            CanvasSize = UDim2.fromOffset(0, 0),
            ZIndex = 81,
        }, contentArea)
        addCorner(messageList, 7)
        listLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, messageList)
        make("UIPadding", {
            PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
        }, messageList)
        inputBox = make("TextBox", {
            Name = "AIInput",
            Position = UDim2.new(0, 0, 1, -128),
            Size = UDim2.new(1, -76, 0, 60),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            MultiLine = true,
            TextWrapped = true,
            Text = "",
            PlaceholderText = "Ask about Luau scripting...",
            PlaceholderColor3 = COLORS.Muted,
            TextColor3 = COLORS.Text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 82,
        }, contentArea)
        addCorner(inputBox, 7)
        sendButton = createButton(contentArea, "Send", UDim2.fromOffset(68, 60), UDim2.new(1, -68, 1, -128), function()
            sendAIMessage(inputBox.Text)
        end, COLORS.Accent)
        sendButton.ZIndex = 83
        sendButton.TextSize = 11
        statusLabel = createLabel(contentArea, "Ready", UDim2.new(1, -180, 0, 18), UDim2.new(0, 0, 1, -64), 10, COLORS.Muted)
        statusLabel.ZIndex = 82
        local clearBtn = createButton(contentArea, "New chat", UDim2.fromOffset(80, 18), UDim2.new(1, -168, 1, -64), function()
            if state.busy then return end
            state.aiBubbles = {}
            state.aiHistory = {
                { role = "system", content = "You are a helpful Luau scripting assistant inside a Roblox executor. Give concise code examples when asked." },
            }
            state.sessionHistories[state.chatKey] = state.aiHistory
            deleteAIChat(state.chatKey)
            if messageList then
                for _, child in ipairs(messageList:GetChildren()) do
                    if child:IsA("GuiObject") then child:Destroy() end
                end
            end
            addMessage("AI", "New chat started. Ask me anything about Luau scripting.")
            if statusLabel then
                statusLabel.Text = "Ready"
                statusLabel.TextColor3 = COLORS.Muted
            end
        end, COLORS.Panel2)
        clearBtn.ZIndex = 82
        clearBtn.TextSize = 9
        local keysBtn = createButton(contentArea, "Keys", UDim2.fromOffset(50, 18), UDim2.new(1, -84, 1, -64), openKeysEditor, COLORS.Panel2)
        keysBtn.ZIndex = 82
        keysBtn.TextSize = 9
        local function updateCanvas()
            if not messageList or not messageList.Parent or not listLayout then return end
            messageList.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 16)
            messageList.CanvasPosition = Vector2.new(0, math.max(0, listLayout.AbsoluteContentSize.Y - messageList.AbsoluteWindowSize.Y + 16))
        end
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        local function parseMessageSegments(message)
            local segments = {}
            local pos = 1
            while true do
                local startFence = string.find(message, "```", pos, true)
                if not startFence then
                    if pos <= #message then
                        table.insert(segments, { type = "text", text = string.sub(message, pos) })
                    end
                    break
                end
                if startFence > pos then
                    table.insert(segments, { type = "text", text = string.sub(message, pos, startFence - 1) })
                end
                local closeFence = string.find(message, "```", startFence + 3, true)
                if not closeFence then
                    table.insert(segments, { type = "code", text = string.sub(message, startFence + 3), lang = "" })
                    break
                end
                local inner = string.sub(message, startFence + 3, closeFence - 1)
                local lang = ""
                local firstNewline = string.find(inner, "\n", 1, true)
                if firstNewline then
                    local firstLine = string.sub(inner, 1, firstNewline - 1)
                    local clean = firstLine:gsub("^%s+", ""):gsub("%s+$", "")
                    if #clean < 20 and clean:match("^[%w_%+%-]*$") then
                        lang = clean
                        inner = string.sub(inner, firstNewline + 1)
                    end
                end
                inner = inner:gsub("\n$", "")
                table.insert(segments, { type = "code", text = inner, lang = lang })
                pos = closeFence + 3
            end
            if #segments == 0 then
                table.insert(segments, { type = "text", text = message })
            end
            return segments
        end
        addMessage = function(speaker, message, kind)
            if not messageList or not messageList.Parent then return end
            message = tostring(message or "")
            local isError = kind == "error"
            local isAI = speaker == "AI"
            local bgColor
            if isError then
                bgColor = COLORS.Red
            elseif isAI then
                bgColor = COLORS.Blue
            else
                bgColor = Color3.fromRGB(55, 95, 175)
            end
            local bgTransparency = isError and 0.78 or 0.55
            local row = make("Frame", {
                Size = UDim2.new(1, -2, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = bgColor,
                BackgroundTransparency = bgTransparency,
                BorderSizePixel = 0,
                LayoutOrder = #messageList:GetChildren(),
                ZIndex = 82,
            }, messageList)
            addCorner(row, 6)
            local inner = make("Frame", {
                Size = UDim2.new(1, -16, 0, 0),
                Position = UDim2.fromOffset(8, 5),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 83,
            }, row)
            make("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, inner)
            local headerText
            if isError then
                headerText = "Error"
            elseif isAI then
                headerText = "AI"
            else
                headerText = Settings.AppSettings.userName or "You"
            end
            make("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Text = headerText,
                TextColor3 = isError and COLORS.Red or Color3.fromRGB(200, 220, 255),
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                ZIndex = 83,
            }, inner)
            local order = 2
            local function addTextSegment(segmentText)
                if segmentText == "" then return end
                local lbl = createLabel(inner,
                    segmentText,
                    UDim2.new(1, 0, 0, 0), UDim2.new(),
                    12, isError and COLORS.Red or COLORS.Text, Enum.Font.Gotham
                )
                lbl.TextWrapped = true
                lbl.TextYAlignment = Enum.TextYAlignment.Top
                lbl.AutomaticSize = Enum.AutomaticSize.Y
                lbl.LayoutOrder = order
                lbl.ZIndex = 83
                order = order + 1
            end
            local function addCodeSegment(code, lang)
                local codeFrame = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = COLORS.Panel2,
                    BackgroundTransparency = 0.15,
                    BorderSizePixel = 0,
                    LayoutOrder = order,
                    ZIndex = 83,
                }, inner)
                addCorner(codeFrame, 4)
                make("UIListLayout", {
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, codeFrame)
                make("UIPadding", {
                    PaddingTop = UDim.new(0, 6),
                    PaddingBottom = UDim.new(0, 6),
                    PaddingLeft = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, 8),
                }, codeFrame)
                local header = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    ZIndex = 84,
                }, codeFrame)
                createLabel(header, lang ~= "" and lang:upper() or "CODE", UDim2.new(1, -60, 1, 0), UDim2.new(), 9, COLORS.Muted, Enum.Font.GothamBold).ZIndex = 84
                local copyCodeBtn = make("TextButton", {
                    Size = UDim2.fromOffset(52, 16),
                    Position = UDim2.new(1, -52, 0, 1),
                    BackgroundColor3 = COLORS.Panel,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    Text = "Copy",
                    TextColor3 = COLORS.Muted,
                    TextSize = 9,
                    Font = Enum.Font.Gotham,
                    AutoButtonColor = true,
                    ZIndex = 84,
                }, header)
                addCorner(copyCodeBtn, 4)
                copyCodeBtn.Activated:Connect(function()
                    if type(setclipboard) ~= "function" then
                        copyCodeBtn.Text = "No cb"
                        task.delay(1, function() if copyCodeBtn.Parent then copyCodeBtn.Text = "Copy" end end)
                        return
                    end
                    local ok = pcall(setclipboard, code)
                    copyCodeBtn.Text = ok and "Copied!" or "Fail"
                    task.delay(1, function() if copyCodeBtn.Parent then copyCodeBtn.Text = "Copy" end end)
                end)
                make("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = code,
                    TextColor3 = COLORS.Text,
                    TextSize = 11,
                    Font = Enum.Font.Code,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = 2,
                    ZIndex = 84,
                }, codeFrame)
                order = order + 1
            end
            if isAI and not isError then
                local segments = parseMessageSegments(message)
                for _, seg in ipairs(segments) do
                    if seg.type == "text" then
                        addTextSegment(seg.text)
                    elseif seg.type == "code" then
                        addCodeSegment(seg.text, seg.lang)
                    end
                end
            else
                addTextSegment(message)
            end
            if not isError then
                local btnRow = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    LayoutOrder = order,
                    ZIndex = 83,
                }, inner)
                make("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, btnRow)
                local copyBtnText = isAI and "Copy all" or "Copy"
                local copyBtn = make("TextButton", {
                    Size = UDim2.fromOffset(isAI and 56 or 56, 18),
                    BackgroundColor3 = COLORS.Panel2,
                    BackgroundTransparency = 0.25,
                    BorderSizePixel = 0,
                    Text = copyBtnText,
                    TextColor3 = COLORS.Text,
                    TextSize = 9,
                    Font = Enum.Font.Gotham,
                    AutoButtonColor = true,
                    LayoutOrder = 1,
                    ZIndex = 84,
                }, btnRow)
                addCorner(copyBtn, 4)
                copyBtn.Activated:Connect(function()
                    if type(setclipboard) ~= "function" then
                        copyBtn.Text = "No cb"
                        task.delay(1, function() if copyBtn.Parent then copyBtn.Text = copyBtnText end end)
                        return
                    end
                    local ok = pcall(setclipboard, message)
                    copyBtn.Text = ok and "Copied!" or "Fail"
                    task.delay(1, function() if copyBtn.Parent then copyBtn.Text = copyBtnText end end)
                end)
                if isAI then
                    row:SetAttribute("IsAIBubble", true)
                    local regenBtn = make("TextButton", {
                        Size = UDim2.fromOffset(74, 18),
                        BackgroundColor3 = COLORS.Panel2,
                        BackgroundTransparency = 0.25,
                        BorderSizePixel = 0,
                        Text = "Regenerate",
                        TextColor3 = COLORS.Text,
                        TextSize = 9,
                        Font = Enum.Font.Gotham,
                        AutoButtonColor = true,
                        Visible = false,
                        LayoutOrder = 2,
                        ZIndex = 84,
                    }, btnRow)
                    addCorner(regenBtn, 4)
                    regenBtn.Activated:Connect(function()
                        if regenerateLastResponse then regenerateLastResponse() end
                    end)
                    for _, bubble in ipairs(state.aiBubbles or {}) do
                        if bubble.regenBtn and bubble.regenBtn.Parent then bubble.regenBtn.Visible = false end
                    end
                    regenBtn.Visible = true
                    state.aiBubbles = state.aiBubbles or {}
                    table.insert(state.aiBubbles, { row = row, regenBtn = regenBtn })
                end
            end
            make("UIPadding", { PaddingBottom = UDim.new(0, 5) }, row)
            task.defer(updateCanvas)
        end
        state.aiBubbles = {}
        local restored = 0
        for _, msg in ipairs(state.aiHistory) do
            if type(msg) == "table" and type(msg.content) == "string" then
                if msg.role == "user" then
                    addMessage("You", msg.content)
                    restored = restored + 1
                elseif msg.role == "assistant" then
                    addMessage("AI", msg.content)
                    restored = restored + 1
                end
            end
        end
        if restored == 0 then addMessage("AI", "Hi! Ask me anything about Luau scripting.") end
        updateSendButton()
    end
    requestAI = function()
        if type(state.http) ~= "function" then
            if statusLabel and statusLabel.Parent then
                statusLabel.Text = "Error: HTTP недоступен"
                statusLabel.TextColor3 = COLORS.Red
            end
            addMessage("AI", "HTTP недоступен в этом исполнителе.", "error")
            return
        end
        statusLabel.Text = "Thinking..."
        statusLabel.TextColor3 = COLORS.Yellow
        state.busy = true
        updateSendButton()
        local requestProvider = state.provider
        local requestModel = state.model.id
        local requestChatKey = state.chatKey
        local requestHistory = state.aiHistory
        task.spawn(function()
            local reply, err = callProvider(requestProvider, requestModel, requestHistory)
            if reply then
                table.insert(requestHistory, { role = "assistant", content = reply })
                state.sessionHistories[requestChatKey] = requestHistory
                local saved = saveAIChat(requestChatKey, requestHistory)
                if state.mode == "chat" and state.chatKey == requestChatKey and statusLabel and statusLabel.Parent then
                    addMessage("AI", reply)
                    statusLabel.Text = saved and "Ready" or "Ready (session only)"
                    statusLabel.TextColor3 = COLORS.Muted
                end
                local cd = tonumber(requestProvider.cooldownSeconds) or 0
                state.cooldownUntil = os.clock() + cd
            else
                local friendly = tostring(err)
                if err == "NO_KEY" then
                    friendly = "Нет API-ключа для " .. requestProvider.name .. ". Нажми Keys."
                elseif err == "RATE_LIMITED" then
                    friendly = "Лимит запросов. Подожди ~30 секунд."
                elseif err == "UNAUTHORIZED" then
                    friendly = "Неверный API-ключ для " .. requestProvider.name .. "."
                elseif err == "HTTP_UNAVAILABLE" then
                    friendly = "HTTP недоступен в этом исполнителе."
                elseif err == "REQUEST_FAILED" then
                    friendly = "Не удалось выполнить HTTP-запрос."
                elseif err == "SERVER_ERROR" then
                    friendly = "Сервер провайдера временно недоступен."
                end
                if state.mode == "chat" and state.chatKey == requestChatKey and statusLabel and statusLabel.Parent then
                    statusLabel.Text = "Error"
                    statusLabel.TextColor3 = COLORS.Red
                    addMessage("AI", friendly, "error")
                end
            end
            state.busy = false
            updateSendButton()
        end)
    end
    sendAIMessage = function(userText)
        userText = trim(userText)
        if userText == "" or state.busy or state.mode ~= "chat" then return end
        if state.cooldownUntil - os.clock() > 0 then return end
        table.insert(state.aiHistory, { role = "user", content = userText })
        addMessage("You", userText)
        if inputBox then inputBox.Text = "" end
        requestAI()
    end
    regenerateLastResponse = function()
        if state.busy or state.mode ~= "chat" then return end
        if state.cooldownUntil - os.clock() > 0 then return end
        local lastIdx = nil
        for i = #state.aiHistory, 1, -1 do
            if state.aiHistory[i].role == "assistant" then
                lastIdx = i
                break
            end
        end
        if not lastIdx then
            if statusLabel and statusLabel.Parent then
                statusLabel.Text = "Nothing to regenerate"
                statusLabel.TextColor3 = COLORS.Yellow
            end
            return
        end
        table.remove(state.aiHistory, lastIdx)
        local bubble = table.remove(state.aiBubbles or {})
        if bubble and bubble.row and bubble.row.Parent then
            bubble.row:Destroy()
        end
        if #(state.aiBubbles or {}) > 0 then
            local previous = state.aiBubbles[#state.aiBubbles]
            if previous.regenBtn and previous.regenBtn.Parent then
                previous.regenBtn.Visible = true
            end
        end
        if state.chatKey then
            state.sessionHistories[state.chatKey] = state.aiHistory
            saveAIChat(state.chatKey, state.aiHistory)
        end
        requestAI()
    end
    openKeysEditor = function()
        local overlay = make("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            ZIndex = 200,
            Active = true,
        }, frame)
        local maxW, maxH = Settings.getMaxToolSize()
        local pw = math.min(340, math.max(260, frame.AbsoluteSize.X - 24))
        local providerKeyCount = 0
        for _, provider in ipairs(AI_PROVIDERS) do
            if provider.keyRequired or provider.id == "pollinations" then
                providerKeyCount = providerKeyCount + 1
            end
        end
        local ph = math.min(maxH, math.max(190, 112 + providerKeyCount * 36))
        local popup = make("Frame", {
            Size = UDim2.fromOffset(pw, ph),
            Position = UDim2.new(0.5, -pw / 2, 0.5, -ph / 2),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            ZIndex = 201,
            Active = true,
        }, overlay)
        addCorner(popup, 10)
        addStroke(popup, COLORS.Border)
        local popupTitle = createLabel(popup, "API Keys", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 8), 14, COLORS.Text, Enum.Font.GothamBold)
        popupTitle.ZIndex = 202
        local y = 42
        for _, provider in ipairs(AI_PROVIDERS) do
            local selectedProvider = provider
            if selectedProvider.keyRequired or selectedProvider.id == "pollinations" then
                local providerLabel = createLabel(popup, selectedProvider.name, UDim2.fromOffset(100, 24), UDim2.fromOffset(12, y), 11, COLORS.Muted)
                providerLabel.ZIndex = 202
                local box = make("TextBox", {
                    Size = UDim2.new(1, -140, 0, 28),
                    Position = UDim2.fromOffset(110, y),
                    BackgroundColor3 = COLORS.Panel2,
                    BorderSizePixel = 0,
                    Text = aiKeys[selectedProvider.id] or "",
                    PlaceholderText = "paste key here",
                    PlaceholderColor3 = COLORS.Muted,
                    TextColor3 = COLORS.Text,
                    TextSize = 10,
                    Font = Enum.Font.Gotham,
                    ClearTextOnFocus = false,
                    ZIndex = 202,
                }, popup)
                addCorner(box, 6)
                box.FocusLost:Connect(function()
                    aiKeys[selectedProvider.id] = trim(box.Text)
                    saveAIKey(selectedProvider.id, aiKeys[selectedProvider.id])
                end)
                y = y + 36
            end
        end
        local note = createLabel(popup, "Pollinations: optional key for higher limits. Groq/NVIDIA: key required.", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, y), 9, COLORS.Muted)
        note.ZIndex = 202
        local closeKeysButton = createButton(popup, "Close", UDim2.fromOffset(80, 30), UDim2.new(1, -92, 1, -40), function()
            overlay:Destroy()
            if state.mode == "services" then
                renderServices()
            elseif state.mode == "models" then
                renderModels()
            end
        end, COLORS.Panel2)
        closeKeysButton.ZIndex = 202
    end
    backButton.Activated:Connect(function()
        if state.busy then return end
        if state.mode == "chat" then
            renderModels()
        elseif state.mode == "models" then
            state.provider = nil
            renderServices()
        end
    end)
    renderServices()
end
local function objectPath(object)
    local names={}; local current=object
    while current and current~=game do table.insert(names,1,current.Name); current=current.Parent end
    return "game."..table.concat(names,".")
end
local dexWindow=nil
DexAutoRefresh = {Attach=nil, Detach=nil, SelectPartAttach=nil, SelectPartDetach=nil, PreviewDetach=nil}
local scriptViewerWindows={}
local registeredScriptSources=setmetatable({},{__mode="k"})
local function getSharedEnvironment()
    local env=nil
    pcall(function() if type(getgenv)=="function" then env=getgenv() else env=_G end end)
    return env
end
local dexAPI={}
function dexAPI.RegisterSource(scriptObject,sourceText)
    if typeof(scriptObject)~="Instance" then return false,"First arg must be Instance." end
    if type(sourceText)~="string" then return false,"Source must be string." end
    local cn=scriptObject.ClassName
    if cn~="Script" and cn~="LocalScript" and cn~="ModuleScript" then return false,"Only Script/LocalScript/ModuleScript." end
    registeredScriptSources[scriptObject]=sourceText
    return true
end
local sharedEnvironment=getSharedEnvironment()
if sharedEnvironment then pcall(function() sharedEnvironment.EasyScriptingDex=dexAPI end) end
local DEX_CLASS_ORDER={
    Terrain=0,
    Workspace=1,Players=2,Lighting=3,ReplicatedFirst=4,ReplicatedStorage=5,ServerScriptService=6,ServerStorage=7,
    StarterGui=8,StarterPack=9,StarterPlayer=10,
    Script=20,LocalScript=20,ModuleScript=20,
    BoolValue=25,IntValue=25,NumberValue=25,StringValue=25,ObjectValue=25,Vector3Value=25,CFrameValue=25,
    Color3Value=25,BrickColorValue=25,NumberSequenceValue=25,ColorSequenceValue=25,RayValue=25,
    RemoteEvent=30,RemoteFunction=30,UnreliableRemoteEvent=30,BindableEvent=31,BindableFunction=31,
    Sound=35,SoundGroup=35,
    Folder=40,Configuration=40,Model=42,
    Part=50,MeshPart=50,UnionOperation=50,NegateOperation=50,WedgePart=50,CornerWedgePart=50,TrussPart=50,
    SpawnLocation=51,Seat=51,VehicleSeat=51,
    Weld=60,WeldConstraint=60,Motor6D=60,HingeConstraint=60,
    ScreenGui=70,SurfaceGui=70,BillboardGui=70,Frame=71,TextLabel=71,TextButton=71,TextBox=71,ImageLabel=71,ImageButton=71,ScrollingFrame=71,
    Player=80,Humanoid=81,Camera=82,
}
local function getDexClassOrder(object)
    local o=DEX_CLASS_ORDER[object.ClassName]
    if o~=nil then return o end
    return 2147483647
end
local function safeChildren(object)
    local ok,children=pcall(function() return object:GetChildren() end)
    if ok and type(children)=="table" then
        table.sort(children,function(a,b)
            local ao=getDexClassOrder(a); local bo=getDexClassOrder(b)
            if ao~=bo then return ao<bo end
            local an=tostring(a.Name); local bn=tostring(b.Name)
            if an~=bn then return an<bn end
            return a.ClassName<b.ClassName
        end)
        return children
    end
    return {}
end
local function classBadge(className)
    local badges={
        Workspace={"WS",Color3.fromRGB(73,153,105)},Folder={"FD",Color3.fromRGB(211,166,74)},
        Model={"MD",Color3.fromRGB(95,145,205)},Part={"PT",Color3.fromRGB(125,137,157)},
        MeshPart={"MP",Color3.fromRGB(125,137,157)},Script={"SC",Color3.fromRGB(225,164,75)},
        LocalScript={"LS",Color3.fromRGB(225,164,75)},ModuleScript={"MS",Color3.fromRGB(225,164,75)},
        RemoteEvent={"RE",Color3.fromRGB(206,126,75)},RemoteFunction={"RF",Color3.fromRGB(206,126,75)},
        BindableEvent={"BE",Color3.fromRGB(160,125,205)},BindableFunction={"BF",Color3.fromRGB(160,125,205)},
        ScreenGui={"UI",Color3.fromRGB(91,157,205)},Player={"PL",Color3.fromRGB(93,170,145)},
        Camera={"CM",Color3.fromRGB(120,150,190)},Humanoid={"HM",Color3.fromRGB(93,170,145)},
        Sound={"AU",Color3.fromRGB(154,128,207)},
    }
    if badges[className] then return badges[className][1],badges[className][2] end
    if className:find("Value") then return "VL",Color3.fromRGB(143,170,105) end
    if className:find("Service") then return "SV",Color3.fromRGB(80,145,175) end
    return string.sub(className,1,2):upper(),COLORS.Muted
end
local DEX_ICON_SHEET_ID = ""
local ICON_CELL = 32
local DEX_ICON_MAP = {
    Folder = {0, 0}, Workspace = {1, 0}, Model = {2, 0}, Part = {3, 0},
    MeshPart = {4, 0}, Script = {5, 0}, LocalScript = {6, 0}, ModuleScript = {7, 0},
    RemoteEvent = {8, 0}, RemoteFunction = {9, 0}, BindableEvent = {10, 0}, BindableFunction = {11, 0},
    ScreenGui = {12, 0}, Frame = {13, 0}, TextLabel = {14, 0}, TextButton = {15, 0},
    TextBox = {0, 1}, ImageLabel = {1, 1}, ImageButton = {2, 1}, ScrollingFrame = {3, 1},
    Sound = {4, 1}, Humanoid = {5, 1}, Player = {6, 1}, Camera = {7, 1},
    Lighting = {8, 1}, ReplicatedStorage = {9, 1}, ServerStorage = {10, 1}, ServerScriptService = {11, 1},
    StarterGui = {12, 1}, StarterPack = {13, 1}, StarterPlayer = {14, 1}, Teams = {15, 1},
    Terrain = {0, 2}, Configuration = {1, 2}, SpawnLocation = {2, 2}, Seat = {3, 2},
    VehicleSeat = {4, 2}, TrussPart = {5, 2}, WedgePart = {6, 2}, UnionOperation = {7, 2},
}
local function createDexIcon(parent,className,position,zIndex)
    local baseZ=zIndex or 55
    local root=make("Frame",{Size=UDim2.fromOffset(19,19),Position=position,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=baseZ},parent)
    local coords = DEX_ICON_MAP[className]
    if coords and DEX_ICON_SHEET_ID ~= "" then
        make("ImageLabel",{
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(19, 19),
            Position = UDim2.fromOffset(0, 0),
            Image = DEX_ICON_SHEET_ID,
            ImageRectOffset = Vector2.new(coords[1] * ICON_CELL, coords[2] * ICON_CELL),
            ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL),
            ZIndex = baseZ + 1
        }, root)
        return root
    end
    local code,color=classBadge(className)
    local function shape(size,offset,fill,radius,transparency)
        local item=make("Frame",{Size=size,Position=offset,BackgroundColor3=fill,BackgroundTransparency=transparency or 0,BorderSizePixel=0,ZIndex=baseZ+1},root)
        if radius then addCorner(item,radius) end
        return item
    end
    local function bg(fill) return shape(UDim2.fromOffset(17,17),UDim2.fromOffset(1,1),fill or Color3.fromRGB(32,36,47),4) end
    local function miniLabel(target,text,size,pos,tsize,tcolor)
        local l=createLabel(target,text,size,pos,tsize,tcolor,Enum.Font.GothamBold)
        l.TextXAlignment=Enum.TextXAlignment.Center
        l.TextYAlignment=Enum.TextYAlignment.Center
        l.ZIndex=baseZ+3
        return l
    end
    if className=="Folder" then
        bg()
        shape(UDim2.fromOffset(9,4),UDim2.fromOffset(2,3),color,2)
        shape(UDim2.fromOffset(15,10),UDim2.fromOffset(2,6),color,2)
        shape(UDim2.fromOffset(15,3),UDim2.fromOffset(2,6),Color3.fromRGB(0,0,0),2,0.75)
    elseif className=="Script" or className=="LocalScript" or className=="ModuleScript" then
        local stripe=className=="LocalScript" and Color3.fromRGB(89,205,139)
                    or className=="ModuleScript" and Color3.fromRGB(107,177,255)
                    or Color3.fromRGB(242,190,91)
        shape(UDim2.fromOffset(13,16),UDim2.fromOffset(3,1),Color3.fromRGB(236,240,246),2)
        shape(UDim2.fromOffset(2,16),UDim2.fromOffset(3,1),stripe,1)
        shape(UDim2.fromOffset(7,1),UDim2.fromOffset(7,5),Color3.fromRGB(120,130,145),1)
        shape(UDim2.fromOffset(7,1),UDim2.fromOffset(7,8),Color3.fromRGB(120,130,145),1)
        shape(UDim2.fromOffset(5,1),UDim2.fromOffset(7,11),Color3.fromRGB(120,130,145),1)
        shape(UDim2.fromOffset(7,1),UDim2.fromOffset(7,14),Color3.fromRGB(120,130,145),1)
    elseif className=="RemoteEvent" or className=="RemoteFunction" or className=="UnreliableRemoteEvent"
        or className=="BindableEvent" or className=="BindableFunction" then
        bg()
        shape(UDim2.fromOffset(13,13),UDim2.fromOffset(3,3),color,7,0.7)
        shape(UDim2.fromOffset(9,9),UDim2.fromOffset(5,5),color,5,0.35)
        shape(UDim2.fromOffset(5,5),UDim2.fromOffset(7,7),color,3)
    elseif className=="Model" then
        bg()
        shape(UDim2.fromOffset(5,5),UDim2.fromOffset(3,4),color,1)
        shape(UDim2.fromOffset(5,5),UDim2.fromOffset(9,4),color,1)
        shape(UDim2.fromOffset(5,5),UDim2.fromOffset(3,10),color,1)
        shape(UDim2.fromOffset(5,5),UDim2.fromOffset(9,10),color,1)
    elseif className:find("Part") or className=="UnionOperation" or className=="SpawnLocation"
        or className=="Seat" or className=="VehicleSeat" or className=="TrussPart" then
        bg()
        shape(UDim2.fromOffset(11,11),UDim2.fromOffset(4,4),color,2)
        shape(UDim2.fromOffset(9,3),UDim2.fromOffset(5,4),Color3.fromRGB(255,255,255),1,0.55)
        shape(UDim2.fromOffset(9,3),UDim2.fromOffset(5,12),Color3.fromRGB(0,0,0),1,0.5)
    elseif className=="ScreenGui" or className=="SurfaceGui" or className=="BillboardGui" then
        bg(color)
        shape(UDim2.fromOffset(11,8),UDim2.fromOffset(4,4),Color3.fromRGB(240,244,250),1)
        shape(UDim2.fromOffset(2,2),UDim2.fromOffset(5,5),COLORS.Accent,1)
        shape(UDim2.fromOffset(5,1),UDim2.fromOffset(5,8),COLORS.Muted,1)
    elseif className:find("Service") or className=="Workspace" or className=="Players" or className=="Lighting" then
        bg()
        shape(UDim2.fromOffset(11,3),UDim2.fromOffset(4,3),color,1)
        shape(UDim2.fromOffset(11,3),UDim2.fromOffset(4,8),color,1)
        shape(UDim2.fromOffset(11,3),UDim2.fromOffset(4,13),color,1)
    elseif className=="Player" or className=="Humanoid" then
        bg()
        shape(UDim2.fromOffset(6,6),UDim2.fromOffset(6,2),color,3)
        shape(UDim2.fromOffset(10,8),UDim2.fromOffset(4,9),color,2)
    elseif className:find("Value") then
        bg()
        shape(UDim2.fromOffset(13,13),UDim2.fromOffset(3,3),color,6)
        miniLabel(root,"V",UDim2.fromOffset(13,13),UDim2.fromOffset(3,3),8,Color3.new(1,1,1))
    else
        local tile=shape(UDim2.fromOffset(17,17),UDim2.fromOffset(1,1),color,4)
        miniLabel(tile,code,UDim2.fromScale(1,1),UDim2.new(),8,Color3.new(1,1,1))
    end
    return root
end
local function formatPropertyValue(value)
    local vt=typeof(value)
    if vt=="Instance" then return value.Name.." ["..value.ClassName.."]"
    elseif vt=="Color3" then return string.format("R:%d G:%d B:%d",math.floor(value.R*255+0.5),math.floor(value.G*255+0.5),math.floor(value.B*255+0.5))
    elseif vt=="Vector3" then return string.format("%.3f, %.3f, %.3f",value.X,value.Y,value.Z)
    elseif vt=="Vector2" then return string.format("%.3f, %.3f",value.X,value.Y)
    elseif vt=="UDim2" then return string.format("%.3f, %.3f, %d, %d",value.X.Scale,value.Y.Scale,value.X.Offset,value.Y.Offset)
    elseif vt=="UDim" then return string.format("%.3f, %d",value.Scale,value.Offset)
    elseif vt=="CFrame" then return string.format("%.3f, %.3f, %.3f",value.Position.X,value.Position.Y,value.Position.Z)
    elseif vt=="EnumItem" then return tostring(value):gsub("^Enum%.","")
    elseif vt=="string" then return value=="" and '""' or value end
    return tostring(value)
end
local function openScriptNotepad(scriptObject)
    local sourceText=nil
    local sourceNote=nil
    local resultKind="unsupported"
    local diagnostics={}
    local globalResolvers={
        decompile=function() return decompile end,
        getscriptbytecode=function() return getscriptbytecode end,
        getscriptclosure=function() return getscriptclosure end,
    }
    local function resolveExecutorFunction(name)
        local fn=nil
        local resolver=globalResolvers[name]
        if resolver then
            local ok,value=pcall(resolver)
            if ok and type(value)=="function" then
                return value
            end
        end
        pcall(function()
            if type(getfenv)=="function" then
                local currentEnvironment=getfenv(0)
                if currentEnvironment then fn=currentEnvironment[name] end
            end
        end)
        if type(fn)=="function" then return fn end
        fn=nil
        pcall(function()
            if sharedEnvironment then fn=sharedEnvironment[name] end
        end)
        if type(fn)=="function" then return fn end
        return nil
    end
    local decompileFunction=resolveExecutorFunction("decompile")
    if decompileFunction then
        local ok,result=pcall(decompileFunction,scriptObject)
        if ok and type(result)=="string" then
            sourceText=result
            resultKind="decompiled"
        else
            table.insert(diagnostics,ok and "decompile: результат не является строкой" or ("decompile: "..tostring(result)))
        end
    else
        table.insert(diagnostics,"decompile: функция недоступна")
    end
    if not sourceText then
        local bytecodeFunction=resolveExecutorFunction("getscriptbytecode")
        if bytecodeFunction then
            local ok,bytecode=pcall(bytecodeFunction,scriptObject)
            local bytecodeType=nil
            if ok and bytecode~=nil then
                pcall(function() bytecodeType=typeof(bytecode) end)
                bytecodeType=bytecodeType or type(bytecode)
                local byteCount=nil
                if type(bytecode)=="string" then
                    byteCount=#bytecode
                elseif bytecodeType=="buffer" then
                    pcall(function()
                        if type(buffer)=="table" and type(buffer.len)=="function" then
                            byteCount=buffer.len(bytecode)
                        end
                    end)
                end
                local lines={
                    "Байткод скрипта успешно получен через getscriptbytecode.",
                    "Тип результата: "..tostring(bytecodeType),
                }
                if byteCount then
                    table.insert(lines,"Размер: "..tostring(byteCount).." байт.")
                end
                table.insert(lines,"")
                table.insert(lines,"Байткод нельзя прочитать как обычный исходный код. Для его чтения нужен внешний декомпилятор байткода: встроенного декомпилятора в Easy Scripting нет.")
                table.insert(lines,"")
                table.insert(lines,"При необходимости байткод можно сохранить в файл через writefile (если исполнитель поддерживает эту функцию) или вывести в консоль через print.")
                table.insert(lines,"")
                table.insert(lines,"Easy Scripting только обнаружил и получил байткод; автоматическое сохранение или вывод в консоль не выполняются.")
                sourceText=table.concat(lines,"\n")
                sourceNote=sourceText
                resultKind="bytecode"
            else
                table.insert(diagnostics,ok and "getscriptbytecode: функция вернула nil" or ("getscriptbytecode: "..tostring(bytecode)))
            end
        else
            table.insert(diagnostics,"getscriptbytecode: функция недоступна")
        end
    end
    if not sourceText then
        local closureFunction=resolveExecutorFunction("getscriptclosure")
        if closureFunction then
            local ok,closure=pcall(closureFunction,scriptObject)
            if ok and type(closure)=="function" then
                local lines={
                    "getscriptclosure успешно вернул замыкание скрипта.",
                    "Тип результата: function",
                    "Объект: "..tostring(closure),
                }
                local debugLibrary=nil
                pcall(function() debugLibrary=debug end)
                if type(debugLibrary)=="table" then
                    if type(debugLibrary.info)=="function" then
                        local infoOk,sourceInfo,nameInfo=pcall(debugLibrary.info,closure,"sn")
                        if infoOk then
                            if sourceInfo~=nil then table.insert(lines,"debug.info source: "..tostring(sourceInfo)) end
                            if nameInfo~=nil then table.insert(lines,"debug.info name: "..tostring(nameInfo)) end
                        end
                    end
                    if type(debugLibrary.getinfo)=="function" then
                        local infoOk,info=pcall(debugLibrary.getinfo,closure)
                        if infoOk and type(info)=="table" then
                            if info.what~=nil then table.insert(lines,"debug.getinfo what: "..tostring(info.what)) end
                            if info.source~=nil then table.insert(lines,"debug.getinfo source: "..tostring(info.source)) end
                            if info.short_src~=nil then table.insert(lines,"debug.getinfo short_src: "..tostring(info.short_src)) end
                            if info.name~=nil then table.insert(lines,"debug.getinfo name: "..tostring(info.name)) end
                            if info.linedefined~=nil then table.insert(lines,"debug.getinfo linedefined: "..tostring(info.linedefined)) end
                        end
                    end
                end
                table.insert(lines,"")
                table.insert(lines,"Этот метод вернул замыкание, а не исходный текст скрипта. Замыкание не запускалось.")
                sourceText=table.concat(lines,"\n")
                sourceNote=sourceText
                resultKind="closure"
            else
                table.insert(diagnostics,ok and "getscriptclosure: результат не является функцией" or ("getscriptclosure: "..tostring(closure)))
            end
        else
            table.insert(diagnostics,"getscriptclosure: функция недоступна")
        end
    end
    if not sourceText then
        local registeredSource=registeredScriptSources[scriptObject]
        if type(registeredSource)=="string" then
            sourceText=registeredSource
            resultKind="registered"
        end
    end
    if not sourceText then
        sourceText="Ваш исполнитель не поддерживает декомпиляцию скриптов. Попробуйте использовать другой исполнитель (например, Delta или Synapse)."
        if #diagnostics>0 then
            sourceText=sourceText.."\n\nРезультаты проверки:\n- "..table.concat(diagnostics,"\n- ")
        end
        sourceNote=sourceText
        resultKind="unsupported"
    end
    local maxW, maxH = Settings.getMaxToolSize()
    local w = math.max(280, math.min(820, maxW))
    local h = math.max(220, math.min(600, maxH))
    local frame,content
    frame,content=makeToolWindow("DexNotepad_"..tostring(#scriptViewerWindows+1),"Notepad - "..scriptObject.Name,w,h,function() frame.Visible=false end)
    table.insert(scriptViewerWindows,frame)
    Settings.registerModalWindow(frame)
    local pathLabel=createLabel(content,objectPath(scriptObject),UDim2.new(1,-4,0,22),UDim2.fromOffset(0,0),9,COLORS.Muted,Enum.Font.Code); pathLabel.ZIndex=53
    local scroll=make("ScrollingFrame",{Position=UDim2.fromOffset(0,57),Size=UDim2.new(1,0,1,-57),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,
        ScrollBarThickness=7,ScrollBarImageColor3=COLORS.Muted,ScrollingDirection=Enum.ScrollingDirection.XY,CanvasSize=UDim2.fromOffset(0,0),ZIndex=52},content)
    addCorner(scroll,7)
    local noteBox=make("TextBox",{Name="SourceText",Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(600,300),BackgroundTransparency=1,BorderSizePixel=0,
        ClearTextOnFocus=false,MultiLine=true,TextEditable=true,Text=sourceText,TextColor3=sourceNote and COLORS.Yellow or COLORS.Text,
        TextSize=12,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=false,ZIndex=53},scroll)
    local function updateNotepadCanvas()
        local currentText=noteBox.Text or ""
        local maxW=500
        local lineCount=0
        for line in (currentText.."\n"):gmatch("(.-)\n") do
            lineCount=lineCount+1
            local ok,m=pcall(function() return TextService:GetTextSize(line,12,Enum.Font.Code,Vector2.new(100000,30)) end)
            if ok then maxW=math.max(maxW,m.X) end
        end
        local cw=math.max(scroll.AbsoluteSize.X-16,maxW+22)
        local ch=math.max(scroll.AbsoluteSize.Y-16,lineCount*17+20)
        noteBox.Size=UDim2.fromOffset(cw,ch)
        scroll.CanvasSize=UDim2.fromOffset(cw+16,ch+16)
    end
    noteBox:GetPropertyChangedSignal("Text"):Connect(updateNotepadCanvas)
    task.defer(updateNotepadCanvas)
    local toolbar=make("Frame",{
        Size=UDim2.new(1,0,0,28),
        Position=UDim2.fromOffset(0,27),
        BackgroundColor3=COLORS.Panel2,
        BorderSizePixel=0,
        ZIndex=54,
        Active=true,
    },content)
    addCorner(toolbar,4)
    local saveScriptBtn=createButton(toolbar,"Save to script",UDim2.fromOffset(110,22),UDim2.fromOffset(4,3),function()
        if not scriptObject then return end
        local newSource=noteBox.Text or ""
        local writeOK=false
        local writeErr=nil
        local okSet,errSet=pcall(function() scriptObject.Source=newSource end)
        if okSet then
            writeOK=true
        else
            writeErr=errSet
        end
        if not writeOK and type(setreadonly)=="function" then
            local readonlyChanged=false
            pcall(function()
                setreadonly(scriptObject,false)
                readonlyChanged=true
            end)
            local retryOK,retryErr=pcall(function() scriptObject.Source=newSource end)
            if readonlyChanged then
                pcall(function() setreadonly(scriptObject,true) end)
            end
            if retryOK then
                writeOK=true
            else
                writeErr=retryErr
            end
        end
        if writeOK then
            registeredScriptSources[scriptObject]=newSource
            logConsole("Success","Source updated: "..tostring(scriptObject.Name))
        else
            logConsole("Error","Cannot write Source in this executor: "..tostring(writeErr))
            if type(setclipboard)=="function" then
                local copyOK=pcall(setclipboard,newSource)
                if copyOK then logConsole("Info","Source copied to clipboard instead.") end
            end
            openConsole()
        end
    end,COLORS.Accent)
    saveScriptBtn.ZIndex=55
    saveScriptBtn.TextSize=10
    local copyScriptBtn
    copyScriptBtn=createButton(toolbar,"Copy",UDim2.fromOffset(60,22),UDim2.fromOffset(120,3),function()
        if type(setclipboard)~="function" then
            copyScriptBtn.Text="No cb"
            task.delay(1,function() if copyScriptBtn.Parent then copyScriptBtn.Text="Copy" end end)
            return
        end
        local ok=pcall(setclipboard,noteBox.Text or "")
        copyScriptBtn.Text=ok and "Copied!" or "Fail"
        task.delay(1,function() if copyScriptBtn.Parent then copyScriptBtn.Text="Copy" end end)
    end,COLORS.Panel2)
    copyScriptBtn.ZIndex=55
    copyScriptBtn.TextSize=10
    local reloadBtn=createButton(toolbar,"Reload",UDim2.fromOffset(60,22),UDim2.fromOffset(186,3),function()
        local ok,err=pcall(function()
            local newSrc=scriptObject.Source
            if type(newSrc)=="string" then
                noteBox.Text=newSrc
                noteBox.TextColor3=COLORS.Text
            end
        end)
        if not ok then
            logConsole("Warning","Cannot read Source: "..tostring(err))
            openConsole()
        end
    end,COLORS.Panel2)
    reloadBtn.ZIndex=55
    reloadBtn.TextSize=10
    raiseZIndex(frame,60)
end
local function openDex()
    if dexWindow then
        dexWindow.Visible=true
        raiseZIndex(dexWindow,50)
        if DexAutoRefresh.Attach then DexAutoRefresh.Attach() end
        if DexAutoRefresh.SelectPartAttach then DexAutoRefresh.SelectPartAttach() end
        return
    end
    local maxW, maxH = Settings.getMaxToolSize()
    local width = math.max(280, math.min(940, maxW))
    local height = math.max(240, math.min(650, maxH))
    local selectedObject=game; local expanded={[game]=true}; local clickTimes=setmetatable({},{__mode="k"})
    local frame,content; local treeList,propertiesList,renderTree,updateProperties,searchBox
    local locateSelectedObject
    local selectPartAttach, selectPartDetach
    frame,content=makeToolWindow("DexExplorerWindow","Dex Explorer",width,height,function()
        frame.Visible=false
        if DexAutoRefresh.Detach then DexAutoRefresh.Detach() end
        if DexAutoRefresh.PreviewDetach then DexAutoRefresh.PreviewDetach() end
    end)
    dexWindow=frame
    Settings.registerModalWindow(dexWindow)
    local toolbar=make("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,ZIndex=53},content)
    local searchWrap=make("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,ZIndex=53},toolbar)
    addCorner(searchWrap,6)
    searchBox=make("TextBox",{Size=UDim2.new(1,-12,1,0),Position=UDim2.fromOffset(7,0),BackgroundTransparency=1,ClearTextOnFocus=false,
        PlaceholderText="Search name or class...",Text="",TextColor3=COLORS.Text,PlaceholderColor3=COLORS.Muted,TextSize=10,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=54},searchWrap)
    local dividerX=width<520 and 0.53 or 0.55
    treeList=make("ScrollingFrame",{Name="ExplorerTree",Position=UDim2.fromOffset(0,36),Size=UDim2.new(dividerX,-5,1,-76),BackgroundColor3=COLORS.Panel,
        BorderSizePixel=0,ScrollBarThickness=7,ScrollBarImageColor3=COLORS.Muted,CanvasSize=UDim2.fromOffset(0,0),ZIndex=52},content)
    addCorner(treeList,7)
    local propertiesPanel=make("Frame",{Position=UDim2.new(dividerX,5,0,36),Size=UDim2.new(1-dividerX,-5,1,-76),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=52},content)
    addCorner(propertiesPanel,7)
    local dexSmallUI = width < 520
    local preview3DWindow = nil
    local preview3DCamera = nil
    local preview3DConnection = nil
    local preview3DEndConnection = nil
    local preview3DRotState = {
        active = false, yaw = 0, pitch = 0.3, dist = 10,
        center = Vector3.new(0, 0, 0), lastX = 0, lastY = 0, dragInput = nil,
    }
    local function updatePreviewCamera()
        if not preview3DCamera then return end
        local p = preview3DRotState.pitch
        local y = preview3DRotState.yaw
        local d = preview3DRotState.dist
        local c = preview3DRotState.center
        local offset = Vector3.new(
            d * math.cos(p) * math.sin(y),
            d * math.sin(p),
            d * math.cos(p) * math.cos(y)
        )
        preview3DCamera.CFrame = CFrame.new(c + offset, c)
    end
    local function closePreview3D()
        preview3DRotState.active = false
        preview3DRotState.dragInput = nil
        if preview3DConnection then
            preview3DConnection:Disconnect()
            preview3DConnection = nil
        end
        if preview3DEndConnection then
            preview3DEndConnection:Disconnect()
            preview3DEndConnection = nil
        end
        if preview3DWindow and preview3DWindow.Parent then
            preview3DWindow:Destroy()
        end
        preview3DWindow = nil
        preview3DCamera = nil
    end
    DexAutoRefresh.PreviewDetach = closePreview3D
    local function open3DPreview()
        if not selectedObject then
            logConsole("Warning", "Select an object first.")
            openConsole()
            return
        end
        if selectedObject == game or selectedObject == workspace then
            logConsole("Info", "Select a Model or BasePart instead of the game/workspace root.")
            openConsole()
            return
        end
        local function hasGeometry(obj)
            if obj:IsA("Folder") then return false end
            if obj:IsA("BasePart") then return true end
            local ok, descendants = pcall(function() return obj:GetDescendants() end)
            if not ok or type(descendants) ~= "table" then return false end
            for _, descendant in ipairs(descendants) do
                if descendant:IsA("BasePart") then return true end
            end
            return false
        end
        local geometryOk, geometryFound = pcall(hasGeometry, selectedObject)
        if not geometryOk or not geometryFound then
            logConsole("Info", "No visible geometry to preview (Script/Folder/etc).")
            openConsole()
            return
        end
        closePreview3D()
        local maxW, maxH = Settings.getMaxToolSize()
        local winW = math.max(220, math.min(560, maxW))
        local winH = math.max(200, math.min(460, maxH - 40))
        preview3DWindow = make("Frame", {
            Name = "Preview3D",
            Size = UDim2.fromOffset(winW, winH),
            Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2),
            BackgroundColor3 = COLORS.Background,
            BorderSizePixel = 0,
            ZIndex = 200,
            Active = true,
        }, frame)
        addCorner(preview3DWindow, 10)
        addStroke(preview3DWindow, COLORS.Border)
        local pHeader = make("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            ZIndex = 201,
        }, preview3DWindow)
        addCorner(pHeader, 10)
        local pTitle = createLabel(
            pHeader,
            "  3D: " .. selectedObject.Name .. " (" .. selectedObject.ClassName .. ")",
            UDim2.new(1, -80, 1, 0), UDim2.fromOffset(6, 0),
            11, COLORS.Text, Enum.Font.GothamBold
        )
        pTitle.TextTruncate = Enum.TextTruncate.AtEnd
        pTitle.ZIndex = 202
        local pClose = createButton(pHeader, "X", UDim2.fromOffset(26, 24), UDim2.new(1, -30, 0, 4), function()
            closePreview3D()
        end, COLORS.Panel2)
        pClose.ZIndex = 202
        pClose.TextSize = 16
        local viewport3D = make("ViewportFrame", {
            Size = UDim2.new(1, -12, 1, -62),
            Position = UDim2.fromOffset(6, 36),
            BackgroundColor3 = Color3.fromRGB(28, 32, 42),
            BorderSizePixel = 0,
            Ambient = Color3.fromRGB(180, 180, 180),
            LightColor = Color3.fromRGB(255, 255, 255),
            LightDirection = Vector3.new(-1, -1, -0.5),
            Active = true,
            ZIndex = 201,
        }, preview3DWindow)
        addCorner(viewport3D, 6)
        local hint = createLabel(
            preview3DWindow,
            "Drag to rotate | Scroll to zoom",
            UDim2.new(1, -12, 0, 18), UDim2.new(0, 6, 1, -22),
            9, COLORS.Muted
        )
        hint.ZIndex = 202
        local cloneOk, clone = pcall(function() return selectedObject:Clone() end)
        if not cloneOk or not clone then
            pTitle.Text = "  3D: failed to clone"
            logConsole("Warning", "Could not clone selected object for 3D preview.")
            return
        end
        local worldOk, worldModel = pcall(function() return Instance.new("WorldModel") end)
        if not worldOk or not worldModel then
            clone:Destroy()
            pTitle.Text = "  3D: preview unavailable"
            return
        end
        worldModel.Parent = viewport3D
        local packModel = Instance.new("Model")
        packModel.Name = "PreviewModel"
        clone.Parent = packModel
        local function configurePart(part)
            pcall(function() part.Anchored = true end)
            pcall(function() part.CanCollide = false end)
            pcall(function() part.CanTouch = false end)
            pcall(function() part.CanQuery = false end)
        end
        if clone:IsA("BasePart") then configurePart(clone) end
        for _, descendant in ipairs(packModel:GetDescendants()) do
            if descendant:IsA("LuaSourceContainer") then
                descendant:Destroy()
            elseif descendant:IsA("BasePart") then
                configurePart(descendant)
            end
        end
        packModel.Parent = worldModel
        local okBox, boxCF, boxSize = pcall(function() return packModel:GetBoundingBox() end)
        if not okBox or typeof(boxCF) ~= "CFrame" or typeof(boxSize) ~= "Vector3" then
            packModel:Destroy()
            pTitle.Text = "  3D: no geometry found"
            logConsole("Info", "The selected object has no cloneable BasePart geometry.")
            return
        end
        local pivotOk = pcall(function()
            packModel:PivotTo(packModel:GetPivot() + (-boxCF.Position))
        end)
        if pivotOk then
            local recenterOk, recenterCF, recenterSize = pcall(function() return packModel:GetBoundingBox() end)
            if recenterOk and typeof(recenterCF) == "CFrame" and typeof(recenterSize) == "Vector3" then
                boxCF, boxSize = recenterCF, recenterSize
            end
        end
        local maxDim = math.max(boxSize.X, boxSize.Y, boxSize.Z, 0.1)
        preview3DRotState.center = boxCF.Position
        preview3DRotState.dist = math.clamp(maxDim * 2.2, 1, 200)
        preview3DRotState.yaw = math.rad(30)
        preview3DRotState.pitch = math.rad(20)
        preview3DCamera = Instance.new("Camera")
        preview3DCamera.FieldOfView = 50
        preview3DCamera.Parent = viewport3D
        viewport3D.CurrentCamera = preview3DCamera
        updatePreviewCamera()
        viewport3D.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                preview3DRotState.active = true
                preview3DRotState.dragInput = input
                preview3DRotState.lastX = input.Position.X
                preview3DRotState.lastY = input.Position.Y
            end
        end)
        viewport3D.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input == preview3DRotState.dragInput then
                preview3DRotState.active = false
                preview3DRotState.dragInput = nil
            end
        end)
        preview3DConnection = UserInputService.InputChanged:Connect(function(input)
            if not preview3DWindow or not preview3DWindow.Parent then return end
            local isMouseDrag = input.UserInputType == Enum.UserInputType.MouseMovement
            local isTouchDrag = input.UserInputType == Enum.UserInputType.Touch
                and input == preview3DRotState.dragInput
            if preview3DRotState.active and (isMouseDrag or isTouchDrag) then
                local dx = input.Position.X - preview3DRotState.lastX
                local dy = input.Position.Y - preview3DRotState.lastY
                preview3DRotState.lastX = input.Position.X
                preview3DRotState.lastY = input.Position.Y
                preview3DRotState.yaw = preview3DRotState.yaw - dx * 0.01
                preview3DRotState.pitch = math.clamp(
                    preview3DRotState.pitch + dy * 0.01,
                    math.rad(-85), math.rad(85)
                )
                updatePreviewCamera()
            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                local mousePos = UserInputService:GetMouseLocation()
                local vpPos = viewport3D.AbsolutePosition
                local vpSize = viewport3D.AbsoluteSize
                if mousePos.X >= vpPos.X and mousePos.X <= vpPos.X + vpSize.X
                    and mousePos.Y >= vpPos.Y and mousePos.Y <= vpPos.Y + vpSize.Y then
                    preview3DRotState.dist = math.clamp(
                        preview3DRotState.dist * (1 - input.Position.Z * 0.15),
                        0.5, 200
                    )
                    updatePreviewCamera()
                end
            end
        end)
        preview3DEndConnection = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input == preview3DRotState.dragInput then
                preview3DRotState.active = false
                preview3DRotState.dragInput = nil
            end
        end)
        logConsole("Info", "3D preview opened for " .. selectedObject.Name)
    end
    local propertiesTitle=createLabel(propertiesPanel, dexSmallUI and "  P" or "  Properties", UDim2.new(1,-48,0,25), UDim2.fromOffset(6,1), 11, COLORS.Text, Enum.Font.GothamBold)
    propertiesTitle.ZIndex=54
    local function has3DGeometry(object)
        if not object then return false end
        local okFolder, isFolder = pcall(function() return object:IsA("Folder") end)
        if okFolder and isFolder then return false end
        local okPart, isPart = pcall(function() return object:IsA("BasePart") end)
        if okPart and isPart then return true end
        local okDescendants, descendants = pcall(function() return object:GetDescendants() end)
        if okDescendants and type(descendants) == "table" then
            for _, descendant in ipairs(descendants) do
                if descendant:IsA("BasePart") then return true end
            end
        end
        return false
    end
    local preview3DButton = createButton(propertiesPanel, "3D", UDim2.fromOffset(26, 20), UDim2.new(1, -30, 0, 3), open3DPreview, COLORS.Panel2)
    preview3DButton.TextSize = 10
    preview3DButton.ZIndex = 54
    preview3DButton.Visible = false
    local function showDexInputPopup(titleText, initialText, onConfirm, allowEmpty)
        local overlay = make("Frame", {
            Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 150, Active = true,
        }, frame)
        local pw = math.min(340, math.max(240, frame.AbsoluteSize.X - 30))
        local ph = 170
        local popup = make("Frame", {
            Size = UDim2.fromOffset(pw, ph), Position = UDim2.new(0.5, -pw/2, 0.5, -ph/2),
            BackgroundColor3 = COLORS.Panel, BorderSizePixel = 0, ZIndex = 151, Active = true,
        }, overlay)
        addCorner(popup, 10); addStroke(popup, COLORS.Border)
        local tt = createLabel(popup, titleText, UDim2.new(1,-24,0,26), UDim2.fromOffset(12,8), 14, COLORS.Text, Enum.Font.GothamBold); tt.ZIndex=152
        local input = make("TextBox", {
            Size = UDim2.new(1,-28,0,36), Position = UDim2.fromOffset(14,42),
            BackgroundColor3 = COLORS.Panel2, BorderSizePixel = 0,
            Text = initialText or "", PlaceholderText = "New value", PlaceholderColor3 = COLORS.Muted,
            TextColor3 = COLORS.Text, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, ZIndex = 152,
        }, popup)
        addCorner(input, 6)
        local errLabel = createLabel(popup, "", UDim2.new(1,-28,0,16), UDim2.fromOffset(14,80), 9, COLORS.Red); errLabel.ZIndex=152
        local cancel = createButton(popup, "Cancel", UDim2.fromOffset(80,30), UDim2.new(1,-180,1,-40), function() overlay:Destroy() end, COLORS.Panel2); cancel.ZIndex=152
        local confirm = createButton(popup, "OK", UDim2.fromOffset(80,30), UDim2.new(1,-92,1,-40), function()
            local v = trim(input.Text or "")
            if v == "" and not allowEmpty then errLabel.Text = "Value cannot be empty."; return end
            local ok, err = onConfirm(v)
            if ok then overlay:Destroy() else errLabel.Text = tostring(err or "Failed.") end
        end, COLORS.Accent); confirm.ZIndex=152
        task.defer(function() if input and input.Parent then input:CaptureFocus() end end)
    end
    local function showDexConfirmPopup(titleText, message, onConfirm)
        local overlay = make("Frame", {
            Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 150, Active = true,
        }, frame)
        local pw = math.min(340, math.max(240, frame.AbsoluteSize.X - 30))
        local ph = 150
        local popup = make("Frame", {
            Size = UDim2.fromOffset(pw, ph), Position = UDim2.new(0.5, -pw/2, 0.5, -ph/2),
            BackgroundColor3 = COLORS.Panel, BorderSizePixel = 0, ZIndex = 151, Active = true,
        }, overlay)
        addCorner(popup, 10); addStroke(popup, COLORS.Border)
        local tt = createLabel(popup, titleText, UDim2.new(1,-24,0,26), UDim2.fromOffset(12,8), 14, COLORS.Text, Enum.Font.GothamBold); tt.ZIndex=152
        local msg = createLabel(popup, message, UDim2.new(1,-24,0,50), UDim2.fromOffset(12,38), 11, COLORS.Muted)
        msg.TextWrapped = true; msg.TextYAlignment = Enum.TextYAlignment.Top; msg.ZIndex=152
        local cancel = createButton(popup, "Cancel", UDim2.fromOffset(80,30), UDim2.new(1,-180,1,-40), function() overlay:Destroy() end, COLORS.Panel2); cancel.ZIndex=152
        local confirm = createButton(popup, "Delete", UDim2.fromOffset(80,30), UDim2.new(1,-92,1,-40), function()
            overlay:Destroy()
            if onConfirm then onConfirm() end
        end, Color3.fromRGB(105,47,57)); confirm.ZIndex=152
    end
    local dexFooter = make("Frame", {
        Name = "DexFooter",
        Position = UDim2.new(0, 0, 1, -38),
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 53,
    }, content)
    addCorner(dexFooter, 6)
    addStroke(dexFooter, COLORS.Border, 0.5)
    local footerScroll = make("ScrollingFrame", {
        Name = "FooterScroll",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLORS.Muted,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 54,
        Active = true,
    }, dexFooter)
    local footerBtnW = 72
    local footerBtnH = 26
    local footerBtnY = 4
    local numButtons = 8
    local footerContentWidth = 6 + numButtons * footerBtnW + (numButtons - 1) * 4 + 6
    local footerContent = make("Frame", {
        Name = "FooterContent",
        Size = UDim2.fromOffset(footerContentWidth, 34),
        BackgroundTransparency = 1,
        ZIndex = 54,
    }, footerScroll)
    footerScroll.CanvasSize = UDim2.fromOffset(footerContentWidth, 0)
    local dexClipboard = nil
    local function footerBtnPos(i)
        return UDim2.fromOffset(6 + (i - 1) * (footerBtnW + 4), footerBtnY)
    end
    local renamePropButton = createButton(footerContent, "Rename", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(1), function()
        if not selectedObject then return end
        if selectedObject == game then
            logConsole("Warning", "Cannot rename game root.")
            openConsole()
            return
        end
        local target = selectedObject
        showDexInputPopup("Rename " .. target.ClassName, target.Name, function(newName)
            local ok, err = pcall(function() target.Name = newName end)
            if not ok then return false, tostring(err) end
            updateProperties(target)
            renderTree()
            logConsole("Success", "Renamed to: " .. tostring(newName))
            return true
        end)
    end, COLORS.Accent)
    renamePropButton.TextSize = 10
    renamePropButton.ZIndex = 55
    local deletePropButton = createButton(footerContent, "Delete", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(2), function()
        if not selectedObject then return end
        if selectedObject == game or selectedObject.Parent == game then
            logConsole("Warning", "Cannot delete services (game or its direct children).")
            openConsole()
            return
        end
        local target = selectedObject
        showDexConfirmPopup("Confirm delete", "Delete '" .. tostring(target.Name) .. "' (" .. target.ClassName .. ") on the client? This cannot be undone.", function()
            local ok, err = pcall(function() target:Destroy() end)
            if not ok then
                logConsole("Error", "Delete failed: " .. tostring(err))
                openConsole()
                return
            end
            selectedObject = game
            updateProperties(selectedObject)
            renderTree()
            logConsole("Success", "Deleted: " .. tostring(target.Name))
        end)
    end, Color3.fromRGB(105, 47, 57))
    deletePropButton.TextSize = 10
    deletePropButton.ZIndex = 55
    local copyPropButton
    copyPropButton = createButton(footerContent, "Copy", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(3), function()
        if not selectedObject then return end
        if type(setclipboard) ~= "function" then
            copyPropButton.Text = "No cb"
            task.delay(1, function() if copyPropButton and copyPropButton.Parent then copyPropButton.Text = "Copy" end end)
            return
        end
        local ok = pcall(setclipboard, objectPath(selectedObject))
        copyPropButton.Text = ok and "Copied!" or "Fail"
        task.delay(1, function() if copyPropButton and copyPropButton.Parent then copyPropButton.Text = "Copy" end end)
    end, COLORS.Panel2)
    copyPropButton.TextSize = 10
    copyPropButton.ZIndex = 55
    local locateButton = createButton(footerContent, "Locate", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(4), function()
        if not selectedObject then return end
        local current = selectedObject
        while current and current ~= game do
            if current.Parent then expanded[current.Parent] = true end
            current = current.Parent
        end
        expanded[game] = true
        searchBox.Text = ""
        renderTree()
        if locateSelectedObject then locateSelectedObject() end
    end, COLORS.Panel2)
    locateButton.TextSize = 10
    locateButton.ZIndex = 55
    local selectPartActive = false
    local selectPartConnection = nil
    local selectionBox = nil
    local selectPartButton = nil
    local function ensureSelectionBox()
        if selectionBox and selectionBox.Parent then return end
        selectionBox = Instance.new("SelectionBox")
        selectionBox.Color3 = COLORS.Accent
        selectionBox.LineThickness = 0.05
        selectionBox.SurfaceTransparency = 1
        selectionBox.Adornee = nil
        selectionBox.Visible = false
        selectionBox.Parent = workspace
    end
    local function isPointOverDexGui(pos)
        if not screenGui.Enabled then return false end
        for _, gui in ipairs(screenGui:GetDescendants()) do
            if gui:IsA("GuiObject") and gui.Visible then
                local ancestorsVisible = true
                local ancestor = gui.Parent
                while ancestor and ancestor ~= screenGui do
                    if ancestor:IsA("GuiObject") and not ancestor.Visible then
                        ancestorsVisible = false
                        break
                    end
                    ancestor = ancestor.Parent
                end
                if ancestorsVisible and ancestor == screenGui then
                    local guiPos = gui.AbsolutePosition
                    local guiSize = gui.AbsoluteSize
                    if pos.X >= guiPos.X and pos.X <= guiPos.X + guiSize.X
                        and pos.Y >= guiPos.Y and pos.Y <= guiPos.Y + guiSize.Y then
                        return true
                    end
                end
            end
        end
        return false
    end
    local function handleSelectPartInput(input, gameProcessed)
        if not selectPartActive or gameProcessed then return end
        local inputType = input.UserInputType
        if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then return end
        local pos
        if inputType == Enum.UserInputType.Touch then
            pos = Vector2.new(input.Position.X, input.Position.Y)
        else
            pos = UserInputService:GetMouseLocation()
        end
        if isPointOverDexGui(pos) then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local ray = cam:ScreenPointToRay(pos.X, pos.Y)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)
        if result and result.Instance then
            local target = result.Instance
            searchBox.Text = ""
            local parent = target.Parent
            while parent and parent ~= game do
                expanded[parent] = true
                parent = parent.Parent
            end
            expanded[game] = true
            selectedObject = target
            renderTree()
            updateProperties(target)
            if locateSelectedObject then locateSelectedObject() end
            if selectionBox then
                if target:IsA("BasePart") then
                    selectionBox.Adornee = target
                    selectionBox.Visible = true
                else
                    selectionBox.Adornee = nil
                    selectionBox.Visible = false
                end
            end
        end
    end
    local function attachSelectPartInput()
        ensureSelectionBox()
        if selectPartConnection then return end
        selectPartConnection = UserInputService.InputBegan:Connect(handleSelectPartInput)
    end
    local function detachSelectPartInput()
        selectPartActive = false
        if selectPartButton and selectPartButton.Parent then
            selectPartButton.Text = "Select"
            selectPartButton.BackgroundColor3 = COLORS.Panel2
        end
        if selectPartConnection then
            selectPartConnection:Disconnect()
            selectPartConnection = nil
        end
        if selectionBox then
            selectionBox:Destroy()
            selectionBox = nil
        end
    end
    local cutPropButton = createButton(footerContent, "Cut", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(5), function()
        if not selectedObject or selectedObject == game then return end
        dexClipboard = selectedObject
        logConsole("Info", "Cut: " .. selectedObject.Name)
    end, COLORS.Panel2)
    cutPropButton.TextSize = 10
    cutPropButton.ZIndex = 55
    local pastePropButton = createButton(footerContent, "Paste", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(6), function()
        if not dexClipboard then
            logConsole("Warning", "Nothing to paste.")
            return
        end
        if not selectedObject then
            logConsole("Warning", "Select a container to paste into.")
            return
        end
        local ok, err = pcall(function()
            dexClipboard.Parent = selectedObject
        end)
        if ok then
            logConsole("Success", "Pasted: " .. dexClipboard.Name)
            dexClipboard = nil
            renderTree()
        else
            logConsole("Error", "Paste failed: " .. tostring(err))
            openConsole()
        end
    end, COLORS.Accent)
    pastePropButton.TextSize = 10
    pastePropButton.ZIndex = 55
    local parentPropButton = createButton(footerContent, "Parent", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(7), function()
        if not selectedObject or selectedObject == game then return end
        local p = selectedObject.Parent
        if not p then return end
        expanded[p] = true
        selectedObject = p
        updateProperties(selectedObject)
        renderTree()
        if locateSelectedObject then locateSelectedObject() end
    end, COLORS.Panel2)
    parentPropButton.TextSize = 10
    parentPropButton.ZIndex = 55
    selectPartButton = createButton(footerContent, "Select", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(8), function()
        selectPartActive = not selectPartActive
        selectPartButton.Text = selectPartActive and "Cancel" or "Select"
        selectPartButton.BackgroundColor3 = selectPartActive and COLORS.Red or COLORS.Panel2
        if selectPartActive then
            ensureSelectionBox()
        elseif selectionBox then
            selectionBox.Adornee = nil
            selectionBox.Visible = false
        end
    end, COLORS.Panel2)
    selectPartButton.TextSize = 10
    selectPartButton.ZIndex = 55
    selectPartAttach = attachSelectPartInput
    selectPartDetach = detachSelectPartInput
    DexAutoRefresh.SelectPartAttach = selectPartAttach
    DexAutoRefresh.SelectPartDetach = selectPartDetach
    selectPartAttach()
    propertiesList=make("ScrollingFrame",{Position=UDim2.fromOffset(4,28),Size=UDim2.new(1,-8,1,-32),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=6,ScrollBarImageColor3=COLORS.Muted,CanvasSize=UDim2.fromOffset(0,0),ZIndex=53},propertiesPanel)
    local propertiesLayout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},propertiesList)
    propertiesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() propertiesList.CanvasSize=UDim2.fromOffset(0,propertiesLayout.AbsoluteContentSize.Y+8) end)
    local function clearGuiRows(container)
        for _,c in ipairs(container:GetChildren()) do
            if c:IsA("GuiObject") and not c:IsA("UIListLayout") then c:Destroy() end
        end
    end
    local function addPropertyCategory(title,order)
        local l=createLabel(propertiesList,title:upper(),UDim2.new(1,-8,0,22),UDim2.new(),9,COLORS.Blue,Enum.Font.GothamBold)
        l.LayoutOrder=order; l.ZIndex=55
        make("Frame",{Size=UDim2.new(1,-8,0,1),BackgroundColor3=COLORS.Border,BorderSizePixel=0,LayoutOrder=order+1,ZIndex=54},propertiesList)
        return order+2
    end
    local function parsePropertyInput(rawText,currentValue)
        rawText=trim(rawText)
        local valueType=typeof(currentValue)
        if valueType=="number" then
            local numberValue=tonumber(rawText)
            if numberValue==nil then return nil,"Not a number" end
            return numberValue
        elseif valueType=="boolean" then
            local lower=rawText:lower()
            if lower=="true" then return true end
            if lower=="false" then return false end
            return nil,"Use true or false"
        elseif valueType=="string" then
            return rawText
        elseif valueType=="Vector3" then
            local x,y,z=rawText:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
            x,y,z=tonumber(x),tonumber(y),tonumber(z)
            if x==nil or y==nil or z==nil then return nil,"Format: x, y, z" end
            return Vector3.new(x,y,z)
        elseif valueType=="Vector2" then
            local x,y=rawText:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)")
            x,y=tonumber(x),tonumber(y)
            if x==nil or y==nil then return nil,"Format: x, y" end
            return Vector2.new(x,y)
        elseif valueType=="Color3" then
            local r,g,b=rawText:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
            if not r then r,g,b=rawText:match("R:(%d+)%s*G:(%d+)%s*B:(%d+)") end
            r,g,b=tonumber(r),tonumber(g),tonumber(b)
            if r==nil or g==nil or b==nil then return nil,"Format: R, G, B (0-255)" end
            if r<0 or r>255 or g<0 or g>255 or b<0 or b>255 then
                return nil,"RGB values must be between 0 and 255"
            end
            return Color3.fromRGB(r,g,b)
        elseif valueType=="UDim2" then
            local sx,sy,ox,oy=rawText:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
            sx,sy,ox,oy=tonumber(sx),tonumber(sy),tonumber(ox),tonumber(oy)
            if sx==nil or sy==nil or ox==nil or oy==nil then
                return nil,"Format: scaleX, scaleY, offsetX, offsetY"
            end
            return UDim2.new(sx,ox,sy,oy)
        elseif valueType=="UDim" then
            local scale,offset=rawText:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)")
            scale,offset=tonumber(scale),tonumber(offset)
            if scale==nil or offset==nil then return nil,"Format: scale, offset" end
            return UDim.new(scale,offset)
        elseif valueType=="CFrame" then
            local x,y,z=rawText:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
            x,y,z=tonumber(x),tonumber(y),tonumber(z)
            if x==nil or y==nil or z==nil then return nil,"Format: x, y, z (position only)" end
            return CFrame.new(x,y,z)
        elseif valueType=="EnumItem" then
            local enumName=rawText:gsub("^Enum%.","")
            local enumType,enumValue=enumName:match("^([%w_]+)%.([%w_]+)$")
            if not enumType then
                local okType,currentEnumType=pcall(function() return currentValue.EnumType.Name end)
                if okType and type(currentEnumType)=="string" and enumName:match("^[%w_]+$") then
                    enumType,enumValue=currentEnumType,enumName
                end
            end
            if enumType and enumValue then
                local okEnum,result=pcall(function() return Enum[enumType][enumValue] end)
                if okEnum and result~=nil then return result end
            end
            return nil,"Format: Enum.EnumType.Item"
        end
        return nil,"Unsupported type: "..tostring(valueType)
    end
    local function addPropertyRow(name,value,order)
        local baseColor=order%2==0 and COLORS.Panel2 or COLORS.Panel
        local row=make("TextButton",{
            Size=UDim2.new(1,-8,0,27),
            BackgroundColor3=baseColor,
            BackgroundTransparency=0,
            BorderSizePixel=0,
            Text="",
            AutoButtonColor=true,
            LayoutOrder=order,
            ZIndex=54,
        },propertiesList)
        row.MouseEnter:Connect(function() row.BackgroundColor3=COLORS.PanelHover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3=baseColor end)
        local keyLabel=createLabel(row,name,UDim2.new(0.43,-4,1,0),UDim2.fromOffset(6,0),9,COLORS.Muted)
        keyLabel.ZIndex=55
        local valueLabel=createLabel(row,tostring(value),UDim2.new(0.57,-8,1,0),UDim2.new(0.43,0,0,0),9,COLORS.Text,Enum.Font.Code)
        valueLabel.TextTruncate=Enum.TextTruncate.AtEnd
        valueLabel.ZIndex=55
        row.Activated:Connect(function()
            local targetObject=selectedObject
            if not targetObject then return end
            local currentValue=nil
            local isAttribute=false
            local readOK,readValue=pcall(function() return targetObject[name] end)
            if readOK and readValue~=nil then
                currentValue=readValue
            else
                local attrOK,attributes=pcall(function() return targetObject:GetAttributes() end)
                if attrOK and type(attributes)=="table" and attributes[name]~=nil then
                    currentValue=attributes[name]
                    isAttribute=true
                else
                    logConsole("Warning","Property "..tostring(name).." is not readable.")
                    openConsole()
                    return
                end
            end
            local initialValue=typeof(currentValue)=="string" and currentValue or formatPropertyValue(currentValue)
            showDexInputPopup("Edit "..name.." ("..typeof(currentValue)..")",initialValue,function(newText)
                local parsed,parseError=parsePropertyInput(newText,currentValue)
                if parsed==nil then return false,parseError or "Invalid value" end
                local writeOK,writeError=pcall(function()
                    if isAttribute then
                        targetObject:SetAttribute(name,parsed)
                    else
                        targetObject[name]=parsed
                    end
                end)
                if not writeOK then return false,"Cannot set: "..tostring(writeError) end
                if selectedObject==targetObject then updateProperties(targetObject) end
                return true
            end,typeof(currentValue)=="string")
        end)
        return order+1
    end
    updateProperties=function(object)
        clearGuiRows(propertiesList)
        local order=1
        if not object then
            if preview3DButton then preview3DButton.Visible = false end
            order=addPropertyCategory("Selection",order); addPropertyRow("Object","Nothing selected",order); return
        end
        propertiesTitle.Text = dexSmallUI and "  P" or "  Properties"
        if preview3DButton then
            preview3DButton.Visible = has3DGeometry(object)
        end
        order=addPropertyCategory("Instance",order)
        order=addPropertyRow("Name",object.Name,order)
        order=addPropertyRow("ClassName",object.ClassName,order)
        order=addPropertyRow("Parent",object.Parent and object.Parent.Name or "nil",order)
        order=addPropertyRow("Path",objectPath(object),order)
        local okA,arch=pcall(function() return object.Archivable end)
        if okA then order=addPropertyRow("Archivable",tostring(arch),order) end
        order=addPropertyRow("Children",tostring(#safeChildren(object)),order)
        if object:IsA("BasePart") then
            order=addPropertyCategory("Transform",order+1)
            order=addPropertyRow("Position",formatPropertyValue(object.Position),order)
            order=addPropertyRow("Orientation",formatPropertyValue(object.Orientation),order)
            order=addPropertyRow("Size",formatPropertyValue(object.Size),order)
            order=addPropertyCategory("Appearance",order+1)
            order=addPropertyRow("Color",formatPropertyValue(object.Color),order)
            order=addPropertyRow("Material",formatPropertyValue(object.Material),order)
            order=addPropertyRow("Transparency",formatPropertyValue(object.Transparency),order)
            order=addPropertyRow("Reflectance",formatPropertyValue(object.Reflectance),order)
            order=addPropertyCategory("Behavior",order+1)
            order=addPropertyRow("Anchored",tostring(object.Anchored),order)
            order=addPropertyRow("CanCollide",tostring(object.CanCollide),order)
            order=addPropertyRow("CanTouch",tostring(object.CanTouch),order)
            order=addPropertyRow("CanQuery",tostring(object.CanQuery),order)
        elseif object:IsA("ValueBase") then
            order=addPropertyCategory("Value",order+1)
            order=addPropertyRow("Value",formatPropertyValue(object.Value),order)
        elseif object:IsA("Humanoid") then
            order=addPropertyCategory("Humanoid",order+1)
            order=addPropertyRow("DisplayName",object.DisplayName,order)
            order=addPropertyRow("Health",tostring(object.Health),order)
            order=addPropertyRow("MaxHealth",tostring(object.MaxHealth),order)
            order=addPropertyRow("WalkSpeed",tostring(object.WalkSpeed),order)
            order=addPropertyRow("JumpPower",tostring(object.JumpPower),order)
            order=addPropertyRow("RigType",tostring(object.RigType),order)
        elseif object:IsA("GuiObject") then
            order=addPropertyCategory("Gui",order+1)
            order=addPropertyRow("Visible",tostring(object.Visible),order)
            order=addPropertyRow("Position",formatPropertyValue(object.Position),order)
            order=addPropertyRow("Size",formatPropertyValue(object.Size),order)
            order=addPropertyRow("AnchorPoint",formatPropertyValue(object.AnchorPoint),order)
            order=addPropertyRow("BackgroundColor3",formatPropertyValue(object.BackgroundColor3),order)
            order=addPropertyRow("BackgroundTransparency",tostring(object.BackgroundTransparency),order)
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                order=addPropertyRow("Text",object.Text,order)
                order=addPropertyRow("TextSize",tostring(object.TextSize),order)
            end
        elseif object:IsA("Sound") then
            order=addPropertyCategory("Sound",order+1)
            order=addPropertyRow("SoundId",object.SoundId,order)
            order=addPropertyRow("Volume",tostring(object.Volume),order)
            order=addPropertyRow("PlaybackSpeed",tostring(object.PlaybackSpeed),order)
            order=addPropertyRow("Playing",tostring(object.Playing),order)
        end
        local okAt,attrs=pcall(function() return object:GetAttributes() end)
        if okAt and next(attrs) then
            order=addPropertyCategory("Attributes",order+1)
            local names={}; for n in pairs(attrs) do table.insert(names,n) end; table.sort(names)
            for _,n in ipairs(names) do order=addPropertyRow(n,formatPropertyValue(attrs[n]),order) end
        end
        local okT,tags=pcall(function() return CollectionService:GetTags(object) end)
        if okT and #tags>0 then
            table.sort(tags); order=addPropertyCategory("Tags",order+1)
            order=addPropertyRow("CollectionService",table.concat(tags,", "),order)
        end
    end
    local flatList = {}
    local virtualSlots = {}
    local ROW_HEIGHT = 24
    local emptyState = createLabel(treeList,"",UDim2.new(1,-12,0,30),UDim2.fromOffset(6,4),10,COLORS.Muted)
    emptyState.ZIndex=55
    emptyState.Visible=false
    local function buildFlatList()
        flatList = {}
        local function appendObject(object,depth)
            local isExpanded=expanded[object]==true
            local children={}
            if isExpanded then
                children=safeChildren(object)
            else
                local ok,c=pcall(function() return object:GetChildren() end)
                children=ok and c or {}
            end
            table.insert(flatList,{
                object=object,
                depth=depth,
                isExpanded=isExpanded,
                hasChildren=#children>0,
                searchablePath=nil,
            })
            if isExpanded then
                for _,child in ipairs(children) do
                    appendObject(child,depth+1)
                end
            end
        end
        appendObject(game,0)
        treeList.CanvasSize=UDim2.fromOffset(0,#flatList*ROW_HEIGHT)
    end
    local function refreshSlotIcon(slot,className)
        if slot.IconClass==className then return end
        for _,child in ipairs(slot.IconHolder:GetChildren()) do
            child:Destroy()
        end
        createDexIcon(slot.IconHolder,className,UDim2.fromOffset(0,2),55)
        slot.IconClass=className
    end
    local function updateVisibleRows()
        if not treeList or not treeList.Parent then return end
        local scrollY=math.max(0,treeList.CanvasPosition.Y)
        local firstIndex=math.floor(scrollY/ROW_HEIGHT)+1
        local visibleCount=0
        for slotIndex,slot in ipairs(virtualSlots) do
            local itemIndex=firstIndex+slotIndex-1
            local item=flatList[itemIndex]
            if item and item.object and (item.object==game or item.object.Parent) then
                local object=item.object
                local indent=item.depth*13
                slot.Object=object
                slot.frame.Visible=true
                slot.frame.Position=UDim2.fromOffset(0,(itemIndex-1)*ROW_HEIGHT)
                slot.frame.BackgroundColor3=(selectedObject==object) and COLORS.PanelHover or COLORS.Panel
                slot.Expander.Visible=(item.hasChildren==true) and (item.searchablePath==nil)
                slot.Expander.Text=item.hasChildren and (item.isExpanded and "v" or ">") or " "
                slot.Expander.Position=UDim2.fromOffset(indent,1)
                slot.IconHolder.Position=UDim2.fromOffset(indent+16,2)
                refreshSlotIcon(slot,object.ClassName)
                slot.SelectButton.Position=UDim2.fromOffset(indent+39,0)
                slot.SelectButton.Size=UDim2.new(1,-(indent+40),1,0)
                slot.SelectButton.Text=(item.searchablePath or object.Name)
                    ..(item.searchablePath and ("  ["..object.ClassName.."]") or "")
                visibleCount=visibleCount+1
            else
                slot.Object=nil
                slot.frame.Visible=false
            end
        end
        emptyState.Visible=(#flatList==0)
    end
    local viewportHeight=treeList.AbsoluteSize.Y
    if viewportHeight<=0 then
        viewportHeight=math.max(24,height-124)
    end
    local virtualSlotCount=math.ceil(viewportHeight/ROW_HEIGHT)+5
    for slotIndex=1,virtualSlotCount do
        local slot={Object=nil,IconClass=nil}
        slot.frame=make("Frame",{
            Name="VirtualDexRow"..slotIndex,
            Size=UDim2.new(1,-5,0,ROW_HEIGHT),
            Position=UDim2.fromOffset(0,0),
            BackgroundColor3=COLORS.Panel,
            BorderSizePixel=0,
            Visible=false,
            ZIndex=54,
        },treeList)
        slot.Expander=createButton(slot.frame," ",UDim2.fromOffset(15,22),UDim2.fromOffset(0,1),function()
            local object=slot.Object
            if not object then return end
            local children=safeChildren(object)
            if #children>0 then
                expanded[object]=not (expanded[object]==true)
                renderTree()
            end
        end,COLORS.Panel)
        slot.Expander.TextSize=10
        slot.Expander.ZIndex=56
        slot.IconHolder=make("Frame",{
            Size=UDim2.fromOffset(19,19),
            Position=UDim2.fromOffset(16,2),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ZIndex=55,
        },slot.frame)
        slot.SelectButton=make("TextButton",{
            Size=UDim2.new(1,-40,1,0),
            Position=UDim2.fromOffset(39,0),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            Text="",
            TextColor3=COLORS.Text,
            TextSize=9,
            Font=Enum.Font.Code,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,
            AutoButtonColor=true,
            ZIndex=55,
        },slot.frame)
        slot.SelectButton.Activated:Connect(function()
            local object=slot.Object
            if not object then return end
            local now=os.clock()
            local lastTap=clickTimes[object] or 0
            local doubleTap=now-lastTap<=0.38
            clickTimes[object]=now
            selectedObject=object
            updateProperties(object)
            updateVisibleRows()
            if doubleTap and (object.ClassName=="Script" or object.ClassName=="LocalScript" or object.ClassName=="ModuleScript") then
                openScriptNotepad(object)
            end
        end)
        table.insert(virtualSlots,slot)
    end
    renderTree=function()
        flatList={}
        local query=string.lower(searchBox.Text or "")
        local function passesQuery(object)
            if query=="" then return true end
            local n=string.lower(tostring(object.Name or ""))
            local c=string.lower(tostring(object.ClassName or ""))
            return string.find(n,query,1,true)~=nil or string.find(c,query,1,true)~=nil
        end
        if query=="" then
            buildFlatList()
            emptyState.Text=""
        else
            local matches={}
            local matchesSet={}
            local ok,desc=pcall(function() return game:GetDescendants() end)
            if ok and type(desc)=="table" then
                for _,object in ipairs(desc) do
                    if passesQuery(object) then
                        table.insert(matches,object)
                        matchesSet[object]=true
                        if #matches>=1200 then break end
                    end
                end
            end
            local visibleSet={[game]=true}
            local autoExpand={[game]=true}
            for _,match in ipairs(matches) do
                visibleSet[match]=true
                local parent=match.Parent
                while parent and parent~=game do
                    visibleSet[parent]=true
                    autoExpand[parent]=true
                    parent=parent.Parent
                end
            end
            local function appendVisible(object,depth)
                local userExpanded = expanded[object]
                local autoOpen = autoExpand[object] == true
                local isExpanded
                if userExpanded == nil then
                    isExpanded = autoOpen
                else
                    isExpanded = userExpanded
                end
                local children=safeChildren(object)
                local visibleChildren={}
                for _,child in ipairs(children) do
                    if visibleSet[child] then
                        table.insert(visibleChildren,child)
                    end
                end
                table.insert(flatList,{
                    object=object,
                    depth=depth,
                    isExpanded=isExpanded,
                    hasChildren=#visibleChildren>0,
                    searchablePath=nil,
                    isMatch=matchesSet[object]==true,
                })
                if isExpanded then
                    for _,child in ipairs(visibleChildren) do
                        appendVisible(child,depth+1)
                    end
                end
            end
            if #matches>0 then
                appendVisible(game,0)
                emptyState.Text=""
            else
                emptyState.Text="No matching objects"
                treeList.CanvasPosition=Vector2.new(0,0)
            end
        end
        treeList.CanvasSize=UDim2.fromOffset(0,#flatList*ROW_HEIGHT)
        updateVisibleRows()
        updateProperties(selectedObject)
    end
    locateSelectedObject=function()
        local targetIndex=nil
        for index,entry in ipairs(flatList) do
            if entry.object==selectedObject then
                targetIndex=index
                break
            end
        end
        if targetIndex then
            local targetY=(targetIndex-1)*ROW_HEIGHT
            local viewportHeight=treeList.AbsoluteSize.Y
            treeList.CanvasPosition=Vector2.new(
                0,
                math.max(0,targetY-viewportHeight/2+ROW_HEIGHT/2)
            )
            updateVisibleRows()
        end
    end
    treeList:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleRows)
    searchBox:GetPropertyChangedSignal("Text"):Connect(renderTree)
    renderTree()
    local updatePending = false
    local conn1=nil
    local conn2=nil
    local function requestDexUpdate()
        if updatePending then return end
        updatePending=true
        task.delay(0.5,function()
            updatePending=false
            if dexWindow and dexWindow.Visible then
                renderTree()
            end
        end)
    end
    DexAutoRefresh.Detach=function()
        if conn1 then conn1:Disconnect(); conn1=nil end
        if conn2 then conn2:Disconnect(); conn2=nil end
    end
    DexAutoRefresh.Attach=function()
        if not conn1 then conn1=game.DescendantAdded:Connect(requestDexUpdate) end
        if not conn2 then conn2=game.DescendantRemoving:Connect(requestDexUpdate) end
    end
    DexAutoRefresh.Attach()
    raiseZIndex(dexWindow,50)
end
local function openRemoteSpy()
    local cobaltUrl="https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau"
    task.spawn(function()
        local success,err=pcall(function()
            local source=game:HttpGet(cobaltUrl)
            local func=loadstring(source)
            if func then
                func()
                task.wait(1)
                local parentGui=(gethui and gethui()) or game:GetService("CoreGui")
                for _,gui in ipairs(parentGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Name~="EasyScriptingGui" and gui.Name~=GUI_NAME.."_Floating" then gui.DisplayOrder=9999 end
                end
                if LocalPlayer then
                    for _,gui in ipairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Name~="EasyScriptingGui" and gui.Name~=GUI_NAME.."_Floating" then gui.DisplayOrder=9999 end
                    end
                end
            else warn("[RemoteSpy] Cobalt compile failed.") end
        end)
        if not success then warn("[RemoteSpy] Load failed: "..tostring(err)) end
    end)
end
local freeCamWindow=nil; local freeCamStatus=nil; local freeCamToggle=nil
local freeCam={enabled=false,speed=32,keys={},mouseLook=false,yaw=0,pitch=0,renderConnection=nil,beganConnection=nil,endedConnection=nil,changedConnection=nil,controls=nil,oldCameraType=nil,oldCameraSubject=nil,oldMouseBehavior=nil,oldMouseIconEnabled=nil}
local function getPlayerControls()
    local scripts=LocalPlayer:FindFirstChild("PlayerScripts")
    local mod=scripts and scripts:FindFirstChild("PlayerModule")
    if not mod then return nil end
    local ok,m=pcall(require,mod)
    if not ok or type(m)~="table" or type(m.GetControls)~="function" then return nil end
    local cOk,c=pcall(function() return m:GetControls() end)
    return cOk and c or nil
end
stopFreeCam=function()
    if not freeCam.enabled then return end
    freeCam.enabled=false; freeCam.keys={}; freeCam.mouseLook=false
    for _,k in ipairs({"renderConnection","beganConnection","endedConnection","changedConnection"}) do
        local c=freeCam[k]; if c then pcall(function() c:Disconnect() end); freeCam[k]=nil end
    end
    local camera=workspace.CurrentCamera
    local restoreType=freeCam.oldCameraType
    if restoreType==nil or restoreType==Enum.CameraType.Scriptable then
        restoreType=Enum.CameraType.Custom
    end
    local savedSubject=freeCam.oldCameraSubject
    local savedControls=freeCam.controls
    freeCam.oldCameraType=nil
    freeCam.oldCameraSubject=nil
    freeCam.controls=nil
    freeCam.oldMouseBehavior=nil
    freeCam.oldMouseIconEnabled=nil
    if camera then pcall(function() camera.CameraType=Enum.CameraType.Scriptable end) end
    task.wait(0.08)
    if camera then
        pcall(function()
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if savedSubject and savedSubject.Parent then
                camera.CameraSubject=savedSubject
            elseif hum then
                camera.CameraSubject=hum
            end
        end)
        task.wait(0.05)
        pcall(function() camera.CameraType=restoreType end)
    end
    if savedControls then pcall(function() savedControls:Enable() end) end
    pcall(function()
        UserInputService.MouseBehavior=Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled=true
    end)
    pcall(function()
        local oldMode=LocalPlayer.CameraMode
        LocalPlayer.CameraMode=Enum.CameraMode.LockFirstPerson
        task.wait(0.05)
        LocalPlayer.CameraMode=oldMode
    end)
    if freeCamStatus then freeCamStatus.Text="FreeCam OFF - character remains in place" end
    if freeCamToggle then freeCamToggle.Text="Start FreeCam" end
end
local function startFreeCam()
    if freeCam.enabled then return end
    local camera=workspace.CurrentCamera
    if not camera then logConsole("Error","CurrentCamera unavailable."); return end
    freeCam.oldCameraType=camera.CameraType; freeCam.oldCameraSubject=camera.CameraSubject
    freeCam.oldMouseBehavior=UserInputService.MouseBehavior; freeCam.oldMouseIconEnabled=UserInputService.MouseIconEnabled
    freeCam.controls=getPlayerControls()
    if freeCam.controls then pcall(function() freeCam.controls:Disable() end)
    else logConsole("Warning","PlayerModule controls inaccessible.") end
    local psScripts=LocalPlayer:FindFirstChild("PlayerScripts")
    local psMod=psScripts and psScripts:FindFirstChild("PlayerModule")
    if psMod then
        pcall(function()
            local m=require(psMod)
            if m and type(m.GetCameras)=="function" then
                local cams=m:GetCameras()
                if cams and type(cams.Disable)=="function" then cams:Disable() end
            end
        end)
    end
    local look=camera.CFrame.LookVector
    freeCam.yaw=math.atan2(-look.X,-look.Z); freeCam.pitch=math.asin(math.clamp(look.Y,-1,1))
    freeCam.keys={}; freeCam.enabled=true
    camera.CameraType=Enum.CameraType.Scriptable
    UserInputService.MouseBehavior=Enum.MouseBehavior.Default; UserInputService.MouseIconEnabled=true
    freeCam.beganConnection=UserInputService.InputBegan:Connect(function(input,gp)
        if input.UserInputType==Enum.UserInputType.MouseButton2 then
            freeCam.mouseLook=true; UserInputService.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition; UserInputService.MouseIconEnabled=false; return
        end
        if gp or UserInputService:GetFocusedTextBox() then return end
        local k=input.KeyCode
        if k==Enum.KeyCode.W or k==Enum.KeyCode.A or k==Enum.KeyCode.S or k==Enum.KeyCode.D
            or k==Enum.KeyCode.Q or k==Enum.KeyCode.E or k==Enum.KeyCode.LeftShift or k==Enum.KeyCode.RightShift then freeCam.keys[k]=true end
    end)
    freeCam.endedConnection=UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton2 then
            freeCam.mouseLook=false; UserInputService.MouseBehavior=Enum.MouseBehavior.Default; UserInputService.MouseIconEnabled=true
        end
        freeCam.keys[input.KeyCode]=nil
    end)
    freeCam.changedConnection=UserInputService.InputChanged:Connect(function(input)
        if freeCam.enabled and freeCam.mouseLook and input.UserInputType==Enum.UserInputType.MouseMovement then
            local sens=0.0025
            freeCam.yaw=freeCam.yaw-input.Delta.X*sens
            freeCam.pitch=math.clamp(freeCam.pitch-input.Delta.Y*sens,math.rad(-85),math.rad(85))
        end
    end)
    freeCam.renderConnection=RunService.RenderStepped:Connect(function(dt)
        if not freeCam.enabled then return end
        local ac=workspace.CurrentCamera; if not ac then return end
        local x=(freeCam.keys[Enum.KeyCode.D] and 1 or 0)-(freeCam.keys[Enum.KeyCode.A] and 1 or 0)
        local y=(freeCam.keys[Enum.KeyCode.E] and 1 or 0)-(freeCam.keys[Enum.KeyCode.Q] and 1 or 0)
        local z=(freeCam.keys[Enum.KeyCode.W] and 1 or 0)-(freeCam.keys[Enum.KeyCode.S] and 1 or 0)
        local rot=CFrame.fromOrientation(freeCam.pitch,freeCam.yaw,0)
        local dir=rot:VectorToWorldSpace(Vector3.new(x,y,-z))
        local pos=ac.CFrame.Position
        if dir.Magnitude>0 then
            local sp=freeCam.speed
            if freeCam.keys[Enum.KeyCode.LeftShift] or freeCam.keys[Enum.KeyCode.RightShift] then sp=sp*2.5 end
            pos=pos+dir.Unit*sp*dt
        end
        ac.CFrame=CFrame.new(pos)*rot
    end)
    if freeCamStatus then freeCamStatus.Text="ON - WASD move - Q/E down/up - hold RMB to look - Shift faster" end
    if freeCamToggle then freeCamToggle.Text="Stop FreeCam" end
end
local function openFreeCam()
    if freeCamWindow then freeCamWindow.Visible=true; return end
    local maxW, maxH = Settings.getMaxToolSize()
    local w = math.max(260, math.min(410, maxW))
    local h = math.max(210, math.min(compact and 280 or 240, maxH))
    local frame,content; frame,content=makeToolWindow("FreeCamWindow","FreeCam - camera only",w,h,function() stopFreeCam(); frame.Visible=false end)
    freeCamWindow=frame
    Settings.registerModalWindow(freeCamWindow)
    freeCamStatus=createLabel(content,"FreeCam OFF - character remains in place",UDim2.new(1,0,0,36),UDim2.fromOffset(0,0),10,COLORS.Muted)
    freeCamStatus.TextWrapped=true; freeCamStatus.ZIndex=53
    createLabel(content,"Speed",UDim2.fromOffset(50,25),UDim2.fromOffset(0,42),10,COLORS.Text).ZIndex=53
    local speedBox=make("TextBox",{Size=UDim2.fromOffset(70,27),Position=UDim2.fromOffset(54,41),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,
        Text=tostring(freeCam.speed),TextColor3=COLORS.Text,TextSize=11,Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=53},content)
    addCorner(speedBox,6)
    speedBox.FocusLost:Connect(function()
        local v=tonumber(speedBox.Text); if v then freeCam.speed=math.clamp(v,4,200) end
        speedBox.Text=tostring(freeCam.speed)
    end)
    if touchDevice then
        createLabel(content,"Hold a direction button to move the camera",UDim2.new(1,0,0,18),UDim2.fromOffset(0,74),9,COLORS.Muted).ZIndex=53
        local function holdButton(text,keyCode,x,y)
            local b=make("TextButton",{Size=UDim2.fromOffset(42,25),Position=UDim2.fromOffset(x,y),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,
                Text=text,TextColor3=COLORS.Text,TextSize=10,Font=Enum.Font.GothamBold,ZIndex=54},content)
            addCorner(b,6)
            b.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then freeCam.keys[keyCode]=true end end)
            b.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then freeCam.keys[keyCode]=nil end end)
        end
        holdButton("W",Enum.KeyCode.W,48,96); holdButton("A",Enum.KeyCode.A,2,124)
        holdButton("S",Enum.KeyCode.S,48,124); holdButton("D",Enum.KeyCode.D,94,124)
        holdButton("UP",Enum.KeyCode.E,148,96); holdButton("DOWN",Enum.KeyCode.Q,148,124)
        createButton(content,"Yaw +",UDim2.fromOffset(50,25),UDim2.fromOffset(190,96),function() freeCam.yaw=freeCam.yaw+math.rad(15) end).ZIndex=54
        createButton(content,"Yaw -",UDim2.fromOffset(50,25),UDim2.fromOffset(190,124),function() freeCam.yaw=freeCam.yaw-math.rad(15) end).ZIndex=54
    end
    freeCamToggle=createButton(content,"Start FreeCam",UDim2.new(1,0,0,34),UDim2.new(0,0,1,-36),function()
        if freeCam.enabled then stopFreeCam() else startFreeCam() end
    end,COLORS.Accent)
    freeCamToggle.ZIndex=53
    raiseZIndex(freeCamWindow,50)
end
toolDexButton.Activated:Connect(function() toolsPanel.Visible=false; openDex() end)
toolRemoteButton.Activated:Connect(function() toolsPanel.Visible=false; openRemoteSpy() end)
toolFreeCamButton.Activated:Connect(function() toolsPanel.Visible=false; openFreeCam() end)
loadData(); renderProjects(); renderExecutePage()
if not fileStorageAvailable then
    logConsole("Warning","readfile/writefile unavailable. Session-only projects.")
else logConsole("Info","Project storage: "..DATA_FILE) end
screenGui.Destroying:Connect(function()
    if Settings.Replay.recording then pcall(function() Settings.replayStopAndSave() end) end
    if Settings.Replay.recBar and Settings.Replay.recBar.Parent then pcall(function() Settings.Replay.recBar:Destroy() end) end
    if DexAutoRefresh.Detach then pcall(DexAutoRefresh.Detach) end
    if DexAutoRefresh.SelectPartDetach then pcall(DexAutoRefresh.SelectPartDetach) end
    if DexAutoRefresh.PreviewDetach then pcall(DexAutoRefresh.PreviewDetach) end
    if stopFreeCam then pcall(stopFreeCam) end
    if floatingGui then pcall(function() floatingGui:Destroy() end) end
    if sharedEnvironment then
        pcall(function()
            if sharedEnvironment.EasyScriptingDex==dexAPI then sharedEnvironment.EasyScriptingDex=nil end
        end)
    end
end)
if Settings.updateSaveButtonVisibility then Settings.updateSaveButtonVisibility() end
task.defer(function() Settings.replayLoadHistory() end)

print("Easy Scripting "..VERSION.." loaded.")

-- [ОТЧЁТ]
-- 1. showCreateItemPopup: высота окна увеличена до 210 — да
-- 2. pathDisplay на всю ширину (1,-28) с TextTruncate — да
-- 3. input на всю ширину (1,-28), позиция Y=80 — да
-- 4. Старая логика updateInputPos / prefixWidth удалена — да
-- 5. Сообщение msg/message сдвинуто на Y=122 — да
-- 6. Кнопки Cancel/Create и логика создания сохранены — да
