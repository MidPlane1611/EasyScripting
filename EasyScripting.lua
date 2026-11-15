--[[ Easy Scripting v1.6 (Dex+) — navigation, line numbers and AI chat
  * Projects/files/folders + editor + console
  * Dex Explorer: extended class order, type filters, name+class search, Locate, detailed icons
  * Floating toggle (F2 / [-] button) hides GUI while scripts/RemoteSpy/FreeCam keep running
  * RemoteSpy uses Cobalt loader; FreeCam is camera-only
]]

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

-- Floating toggle
local TOGGLE_KEY=Enum.KeyCode.F2
local floatingGui=make("ScreenGui",{Name=GUI_NAME.."_Floating",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=1000},guiParent)
local floatingButton=make("TextButton",{Name="EasyScriptingRestore",Size=UDim2.fromOffset(140,34),Position=UDim2.new(1,-152,0,16),
    BackgroundColor3=COLORS.Accent,BorderSizePixel=0,Text="Easy Scripting",TextColor3=COLORS.Text,TextSize=13,Font=Enum.Font.GothamBold,Visible=false,ZIndex=1},floatingGui)
addCorner(floatingButton,8); addStroke(floatingButton,COLORS.Border); makeDraggable(floatingButton,floatingButton)

local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
local touchDevice=UserInputService.TouchEnabled
local windowWidth=math.max(300,math.min(860,viewport.X-24))
local windowHeight=math.max(340,math.min(620,viewport.Y-40))
local compact=touchDevice or windowWidth<520

local window=make("Frame",{Name="MainWindow",Size=UDim2.fromOffset(windowWidth,windowHeight),
    Position=UDim2.new(0.5,-windowWidth/2,0.5,-windowHeight/2),BackgroundColor3=COLORS.Background,BorderSizePixel=0,ClipsDescendants=true},screenGui)
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
UserInputService.InputBegan:Connect(function(input,processed) if processed then return end; if input.KeyCode==TOGGLE_KEY then toggleEasyScripting() end end)

local body=make("Frame",{Name="Body",Position=UDim2.fromOffset(0,52),Size=UDim2.new(1,0,1,-52),BackgroundTransparency=1},window)

local fileStorageAvailable=type(readfile)=="function" and type(writefile)=="function"
local function ensureFolder()
    if type(isfolder)=="function" then local ok,ex=pcall(isfolder,ROOT_FOLDER); if ok and ex then return end end
    if type(makefolder)=="function" then pcall(makefolder,ROOT_FOLDER) end
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

-- Large-code editor state. Kept in one table to stay below Luau's local-variable limit.
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
local setTreeVisibility

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
                activeFile=type(item.activeFile)=="string" and item.activeFile or "main.lua",updated=tonumber(item.updated) or os.time()}
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
        local rh=e.line and 58 or 44
        local row=make("TextButton",{Name="ConsoleEntry"..tostring(i),Size=UDim2.new(1,-8,0,rh),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,
            AutoButtonColor=e.line~=nil,Text="",LayoutOrder=i,Active=true},consoleList)
        addCorner(row,7)
        createLabel(row,tag,UDim2.fromOffset(54,18),UDim2.fromOffset(9,3),9,col,Enum.Font.GothamBold)
        createLabel(row,e.time,UDim2.fromOffset(64,18),UDim2.new(1,-72,0,3),9,COLORS.Muted)
        local ml=createLabel(row,e.message,UDim2.new(1,-18,0,e.line and 24 or 21),UDim2.fromOffset(9,22),10,COLORS.Text)
        ml.TextWrapped=true; ml.TextYAlignment=Enum.TextYAlignment.Top
        if e.line then
            createLabel(row,"Tap to jump to line "..tostring(e.line),UDim2.new(1,-18,0,14),UDim2.fromOffset(9,42),9,COLORS.Accent)
            row.Activated:Connect(function() jumpToLine(e.line) end)
        end
    end
    local lay=consoleList:FindFirstChildOfClass("UIListLayout")
    if lay then consoleList.CanvasSize=UDim2.fromOffset(0,lay.AbsoluteContentSize.Y+8) end
end
logConsole=function(kind,msg,line) addConsoleEntry(kind,msg,line); renderConsole() end
local function openConsole()
    if consoleWindow then consoleWindow.Visible=true; renderConsole(); return end
    local w=math.max(260,math.min(520,windowWidth-24))
    local h=math.min(340,math.max(220,windowHeight-100))
    consoleWindow=make("Frame",{Name="ConsoleWindow",Size=UDim2.fromOffset(w,h),Position=UDim2.new(0.5,-w/2,0.5,-h/2),
        BackgroundColor3=COLORS.Background,BorderSizePixel=0,ZIndex=40},screenGui)
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
local mainToolbar=make("Frame",{Size=UDim2.new(1,-24,0,44),Position=UDim2.fromOffset(12,8),BackgroundTransparency=1},projectsPage)
local function showProjectsPage()
    projectsPage.Visible=true; executePage.Visible=false; editorPage.Visible=false
    headerSubtitle.Text="HOME"; if renderProjects then renderProjects() end
end
local function showExecutePage()
    projectsPage.Visible=false; executePage.Visible=true; editorPage.Visible=false
    headerSubtitle.Text="EXECUTE"; if renderExecutePage then renderExecutePage() end
end
createButton(mainToolbar,"Projects",UDim2.fromOffset(125,34),UDim2.fromOffset(0,4),showProjectsPage,COLORS.Panel2)
createButton(mainToolbar,"Execute",UDim2.fromOffset(138,34),UDim2.new(1,-138,0,4),showExecutePage,COLORS.Panel2)
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
BigCode.syncCurrentFile = function()
    if not currentProject then return nil end
    local source = BigCode.mode and BigCode.getSource() or (editorBox and editorBox.Text or "")
    return syncEditorToFile(currentProject, source)
end

local function updateProjectCardMeta(project,l)
    if l then l.Text="Roblox project  -  "..getProjectSize(project).."  -  "..tostring(#project.files).." file(s)" end
end
local function showTextPopup(titleText,initialText,confirmText,onConfirm)
    local overlay=make("Frame",{Name="InputOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.38,BorderSizePixel=0,ZIndex=80},window)
    local pw=math.min(360,windowWidth-30); local ph=194
    local popup=make("Frame",{Size=UDim2.fromOffset(pw,ph),Position=UDim2.new(0.5,-pw/2,0.5,-ph/2),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=81},overlay)
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
        files={{path="main.lua",code=nc,autoExecute=false}},folders={},activeFile="main.lua",updated=os.time()}
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
    refreshEditorFileHeader(nil)
    if updatePathBar then updatePathBar() end
    headerSubtitle.Text=project.name
    projectsPage.Visible=false; executePage.Visible=false; editorPage.Visible=true
    editorStatus.Text="Project opened - "..tostring(#project.files).." file(s)"; editorStatus.TextColor3=COLORS.Green
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

local function executeProjectFile(project,file,openOutput)
    if not project or not file then return false end
    if not isScriptFile(file.path) then logConsole("Warning","Only .lua/.luau execute: "..tostring(file.path)); if openOutput then openConsole() end; return false end
    local src=file.code or ""
    if trim(src)=="" then logConsole("Warning",project.name.."/"..file.path.." is empty."); if openOutput then openConsole() end; return false end
    if type(loadstring)~="function" then logConsole("Error","loadstring unavailable."); if openOutput then openConsole() end; return false end
    local ok,chunk,err=pcall(loadstring,src,"@"..project.name.."/"..file.path)
    if not ok or type(chunk)~="function" then
        local m=tostring(ok and err or chunk)
        logConsole("Error",project.name.."/"..file.path..": "..m,getLineNumber(m))
        if openOutput then openConsole() end
        return false
    end
    logConsole("Info","Starting "..project.name.."/"..file.path)
    task.spawn(function()
        local ro,re=pcall(chunk)
        if ro then logConsole("Success","Finished "..project.name.."/"..file.path)
        else local m=tostring(re); logConsole("Error",project.name.."/"..file.path..": "..m,getLineNumber(m)) end
    end)
    if openOutput then openConsole() end
    return true
end
renderExecutePage=function()
    for _,c in ipairs(executeList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local order=0
    for _,project in ipairs(projects) do
        ensureProjectStructure(project)
        for _,file in ipairs(project.files) do
            if isScriptFile(file.path) then
                order=order+1
                local row=make("Frame",{Name="ExecuteFileRow",Size=UDim2.new(1,-8,0,70),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,LayoutOrder=order},executeList)
                addCorner(row,8); addStroke(row,COLORS.Border,0.5)
                local fl=createLabel(row,project.name.." / "..file.path,UDim2.new(1,-210,0,24),UDim2.fromOffset(11,7),10,COLORS.Text,Enum.Font.GothamMedium); fl.TextTruncate=Enum.TextTruncate.AtEnd
                createLabel(row,formatBytes(#(file.code or "")),UDim2.fromOffset(100,18),UDim2.fromOffset(11,34),9,COLORS.Muted)
                local rb=createButton(row,"Run",UDim2.fromOffset(58,28),UDim2.new(1,-194,0,10),function() executeProjectFile(project,file,true) end,COLORS.Accent); rb.TextSize=10
                local ab=createButton(row,file.autoExecute and "Auto: ON" or "Auto: OFF",UDim2.fromOffset(92,28),UDim2.new(1,-128,0,10),function()
                    file.autoExecute=not file.autoExecute
                    local s,m=saveData(); renderExecutePage()
                    logConsole(s and "Success" or "Warning",s and (file.path.." Auto: "..(file.autoExecute and "ON" or "OFF")) or m)
                end,file.autoExecute and COLORS.Green or COLORS.Panel2); ab.TextSize=9
            else file.autoExecute=false end
        end
    end
    if order==0 then
        local empty=make("Frame",{Size=UDim2.new(1,-8,0,90),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,LayoutOrder=1},executeList)
        addCorner(empty,8)
        createLabel(empty,"No script files",UDim2.new(1,-20,0,25),UDim2.fromOffset(12,14),13,COLORS.Text,Enum.Font.GothamBold)
        createLabel(empty,"Add a .lua or .luau file to run it.",UDim2.new(1,-20,0,20),UDim2.fromOffset(12,44),10,COLORS.Muted)
    end
end
local runAutoFilesButton=createButton(executePage,"Run Auto Execute Files",UDim2.new(1,-24,0,40),UDim2.new(0,12,1,-48),function()
    local count=0
    for _,project in ipairs(projects) do
        ensureProjectStructure(project)
        for _,file in ipairs(project.files) do
            if file.autoExecute and isScriptFile(file.path) then count=count+1; executeProjectFile(project,file,false) end
        end
    end
    if count==0 then logConsole("Info","No files marked Auto Execute.") end
    openConsole()
end,COLORS.Accent); runAutoFilesButton.TextSize=11
-- Editor navigation bar (row 1) and action bar (row 2).
local navBar=make("Frame",{Name="EditorNavBar",Size=UDim2.new(1,-20,0,36),Position=UDim2.fromOffset(10,5),BackgroundTransparency=1},editorPage)
local actionBar=make("Frame",{Name="EditorActionBar",Size=UDim2.new(1,-20,0,36),Position=UDim2.fromOffset(10,44),BackgroundTransparency=1},editorPage)

local isTreeOpen=true
local pathBarUpdating=false
local pathBarOriginalText=""
local pathBar=make("TextBox",{Name="PathBar",Size=UDim2.new(1,-222,1,0),Position=UDim2.fromOffset(88,0),
    BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,Text="",PlaceholderText="Project / folder / file.lua",PlaceholderColor3=COLORS.Muted,
    TextColor3=COLORS.Text,TextSize=compact and 9 or 11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false,TextTruncate=Enum.TextTruncate.AtEnd},navBar)
addCorner(pathBar,7); addStroke(pathBar,COLORS.Border,0.5)
local backButton=createButton(navBar,"←",UDim2.fromOffset(34,30),UDim2.fromOffset(0,3),function()
    if currentProject and (BigCode.mode or editorBox.TextEditable) then
        BigCode.syncCurrentFile()
        saveData()
    end
    if toolsPanel then toolsPanel.Visible=false end
    editorPage.Visible=false; projectsPage.Visible=true; headerSubtitle.Text="HOME"; renderProjects()
end,COLORS.Panel2)
backButton.TextSize=18
local treeToggleButton=createButton(navBar,"Tree",UDim2.fromOffset(48,30),UDim2.fromOffset(38,3),function()
    if setTreeVisibility then setTreeVisibility(not isTreeOpen) end
end,COLORS.Panel2)
treeToggleButton.TextSize=compact and 9 or 10
local pathCommitButton
local pathCancelButton
pathCommitButton=createButton(navBar,"Commit",UDim2.fromOffset(58,30),UDim2.new(1,-120,0,3),function()
    if selectedTreePath=="" then
        pathBarUpdating=true
        pathBar.Text=pathBarOriginalText
        pathBarUpdating=false
        pathCommitButton.Visible=false
        pathCancelButton.Visible=false
        return
    end
    if not currentProject or not renameSelectedPath then return end
    local typedPath=trim(pathBar.Text)
    local projectPrefix=currentProject.name.." / "
    if string.sub(typedPath,1,#projectPrefix)==projectPrefix then
        typedPath=string.sub(typedPath,#projectPrefix+1)
    end
    typedPath=typedPath:gsub("%s*/%s*","/")
    local ok,err=renameSelectedPath(typedPath)
    if not ok then
        editorStatus.Text="Rename failed: "..tostring(err or "Invalid path")
        editorStatus.TextColor3=COLORS.Red
        logConsole("Error","Path Bar rename failed: "..tostring(err or "Invalid path"))
    else
        if updatePathBar then updatePathBar() end
    end
end,COLORS.Green)
pathCommitButton.TextSize=compact and 8 or 10
pathCommitButton.Visible=false
pathCancelButton=createButton(navBar,"Cancel",UDim2.fromOffset(54,30),UDim2.new(1,-58,0,3),function()
    pathBarUpdating=true
    pathBar.Text=pathBarOriginalText
    pathBarUpdating=false
    pathCommitButton.Visible=false
    pathCancelButton.Visible=false
end,COLORS.Panel2)
pathCancelButton.TextSize=compact and 8 or 10
pathCancelButton.Visible=false
pathBar:GetPropertyChangedSignal("Text"):Connect(function()
    if pathBarUpdating then return end
    local changed=pathBar.Text~=pathBarOriginalText
    pathCommitButton.Visible=changed
    pathCancelButton.Visible=changed
end)

local function actionButton(text,index,callback,color)
    local button=createButton(actionBar,text,UDim2.new(1/6,-4,1,0),UDim2.new(index/6,0,0,0),callback,color or COLORS.Panel2)
    button.TextSize=compact and 8 or 10
    return button
end
local editorMenu
local editorMenuButton=actionButton("Editor",0,function()
    if editorMenu then editorMenu.Visible=not editorMenu.Visible end
end,COLORS.Accent)
actionButton("AI Chat",1,function()
    if openAIChat then openAIChat() end
end,COLORS.Accent)
actionButton("Tools",2,function()
    if toolsPanel then toolsPanel.Visible=not toolsPanel.Visible end
    if editorMenu then editorMenu.Visible=false end
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
actionButton("Save",4,function()
    if not currentProject then return end

    local textToSave
    if BigCode.mode then
        textToSave=BigCode.getSource()
        syncEditorToFile(currentProject,textToSave)
    elseif editorBox.TextEditable then
        textToSave=editorBox.Text
        syncEditorToFile(currentProject,textToSave)
    end

    local saved,message=saveData()
    if saved then
        editorStatus.Text="Saved - "..getProjectSize(currentProject)
        editorStatus.TextColor3=COLORS.Green
        logConsole("Success","Saved "..currentProject.name.."/"..tostring(currentProject.activeFile or ""))
    else
        editorStatus.Text="Session copy updated"
        editorStatus.TextColor3=COLORS.Yellow
        logConsole("Warning",message)
    end

    -- Return to the full preview after saving, or to the normal editor if it now fits.
    if BigCode.mode and textToSave then
        if BigCode.shouldUsePreview(textToSave) then
            local restorePosition = editorViewport.CanvasPosition
            BigCode.render(textToSave, restorePosition)
        else
            BigCode.clearMode()
            editorBox.Visible=true
            editorBox.TextEditable=true
            editorBox.Text=textToSave
            task.defer(measureEditorCanvas)
        end
    end
end)
actionButton("Console",5,openConsole)

local editorSurface=make("Frame",{Position=UDim2.fromOffset(10,84),Size=UDim2.new(1,-20,1,-119),BackgroundColor3=COLORS.Panel,BorderSizePixel=0},editorPage)
addCorner(editorSurface,8); addStroke(editorSurface,COLORS.Border,0.5)
local treePanelWidth=compact and 106 or 164
local treePanel=make("Frame",{Name="ProjectFileTree",Position=UDim2.fromOffset(7,7),Size=UDim2.new(0,treePanelWidth,1,-14),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0},editorSurface)
addCorner(treePanel,7)
createLabel(treePanel,"FILES",UDim2.new(1,-10,0,20),UDim2.fromOffset(6,4),9,COLORS.Muted,Enum.Font.GothamBold)
local treeListTop=27
local treeList=make("ScrollingFrame",{Name="FileTreeList",Position=UDim2.fromOffset(4,treeListTop),Size=UDim2.new(1,-8,1,-(treeListTop+4)),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0)},treePanel)
local fileTreeLayout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},treeList)
fileTreeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() treeList.CanvasSize=UDim2.fromOffset(0,fileTreeLayout.AbsoluteContentSize.Y+6) end)
local codePanel=make("Frame",{Name="CodePanel",Position=UDim2.fromOffset(treePanelWidth+14,0),Size=UDim2.new(1,-(treePanelWidth+21),1,0),BackgroundTransparency=1},editorSurface)
editorFileLabel=createLabel(codePanel,"Select a file",UDim2.new(1,-268,0,25),UDim2.fromOffset(3,5),10,COLORS.Muted,Enum.Font.GothamBold)
local newlineButton=createButton(codePanel,"Enter",UDim2.fromOffset(48,24),UDim2.new(1,-51,0,5),nil,COLORS.Panel2); newlineButton.TextSize=10
local gutterWidth=34
local gutterBg=make("Frame",{Name="LineNumberGutter",Position=UDim2.fromOffset(3,32),Size=UDim2.new(0,gutterWidth,1,-38),
    BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,ClipsDescendants=true},codePanel)
addCorner(gutterBg,6)
local gutterLabel=make("TextLabel",{Name="LineNumbers",Position=UDim2.fromOffset(0,6),Size=UDim2.fromOffset(gutterWidth,220),
    BackgroundTransparency=1,BorderSizePixel=0,Text="1",TextColor3=COLORS.Muted,TextSize=compact and 11 or 13,
    Font=Enum.Font.Code,LineHeight=1.3,TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=false},gutterBg)
editorViewport=make("ScrollingFrame",{Name="CodeViewport",Position=UDim2.fromOffset(gutterWidth+3,32),Size=UDim2.new(1,-(gutterWidth+6),1,-38),BackgroundColor3=COLORS.Panel,
    BorderSizePixel=0,ClipsDescendants=true,ScrollBarThickness=compact and 5 or 7,ScrollBarImageColor3=COLORS.Muted,
    ScrollingDirection=Enum.ScrollingDirection.XY,CanvasSize=UDim2.fromOffset(0,0),Active=true},codePanel)
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

    -- Measure each line explicitly. TextBounds is not used as the sole source
    -- of truth because it can lag behind large TextBox updates in some executors.
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

-- Split source into small display-safe chunks.
-- 4,000 bytes is intentionally far below the TextBox/TextLabel visual cutoff
-- observed in some executor UI implementations. Newlines and whitespace are
-- preserved, and table.concat(chunks) always reconstructs the original source.
-- The TextBox visual limit can be reached by either character count or line count.
BigCode.shouldUsePreview = function(source)
    source = tostring(source or "")
    local _, newlineCount = source:gsub("\n", "")
    local lineCount = newlineCount + 1
    return #source > 30000 or lineCount > 1200
end

-- Split by BOTH byte count and line count. This prevents a short file containing
-- thousands of tiny lines from overflowing one TextLabel's visual line capacity.
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

        -- Prefer a newline boundary when this block would exceed its line budget.
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
            -- Otherwise end at the last newline, then whitespace, to avoid
            -- splitting ordinary source lines more often than necessary.
            local boundary = segment:match(".*()\n")
            if not boundary then
                boundary = segment:match(".*()%s")
            end
            if boundary then
                endPos = startPos + boundary - 1
            end
        end

        -- Never cut in the middle of a UTF-8 code point.
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

-- BigCode virtualized editor ---------------------------------------------------
-- The complete source always lives in BigCode.chunks. Only a fixed pool of
-- TextBoxes is parented to the viewport; scrolling reassigns those boxes to the
-- chunks intersecting the visible region.
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
        numberLabel.Parent = gutterBg
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
                return
            end

            BigCode.chunks[globalIndex] = slot.Text or ""
            local _, newlineCount = (slot.Text or ""):gsub("\n", "")
            if #(slot.Text or "") > 4000 or newlineCount + 1 > 80 then
                BigCode.queueRechunk(slotIndex, globalIndex)
            else
                BigCode.refreshLayout(true, globalIndex)
            end
        end)

        slot.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if BigCode.findOverlay then BigCode.findOverlay.Visible = false end
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

    -- Find the first chunk whose bottom edge reaches the current scroll offset.
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

    -- Keep a small overscan around the visible area. The pool remains fixed at
    -- 15 TextBoxes regardless of the total number of chunks in the document.
    local wantedIndices = {}
    local wantedSet = {}
    local firstWanted = math.max(1, firstVisible - 2)
    local lastWanted = math.min(chunkCount, math.max(lastVisible + 2, firstVisible))
    for globalIndex = firstWanted, lastWanted do
        if #wantedIndices >= #BigCode.virtualSlots then break end
        wantedIndices[#wantedIndices + 1] = globalIndex
        wantedSet[globalIndex] = true
    end

    -- Preserve current slot assignments when possible, especially the slot
    -- that currently owns keyboard focus, to avoid moving the caret on scroll.
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

        -- Text edits affect only one chunk. Re-measure that chunk while reusing
        -- cached dimensions for the rest; a viewport resize/re-render measures all.
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

-- The pool is reused during scrolling; render only replaces the backing source.
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
    for _, child in ipairs(gutterBg:GetChildren()) do
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
    for _, child in ipairs(gutterBg:GetChildren()) do
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
    -- Guard Text changes caused by moving oversized content out of the TextBox.
    local isSwitchingToBigCode = false

    local function switchToBigCode(fullText, textLength)
        if isSwitchingToBigCode then return end
        isSwitchingToBigCode = true

        local ok, err = pcall(function()
            -- BigCode.render stores/splits the complete source and hides the TextBox.
            BigCode.render(fullText)

            -- Clear the hidden TextBox so the oversized source exists only in BigCode.
            -- The guard prevents this assignment from recursively entering this handler.
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

        -- Keep the guard active through the next task step in case the Text change
        -- notification caused by clearing editorBox.Text is deferred by the executor.
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

        -- IMPORTANT: check the visual TextBox limit before returning for BigCode.mode.
        -- This also handles pasting a large replacement while an individual BigCode
        -- chunk is open in the editable TextBox.
        if BigCode.mode then
            -- BigCode uses its own set of small editable TextBoxes. The legacy
            -- single editorBox is hidden and must not overwrite those chunks.
            if editorBox.Visible then
                editorBox.Visible = false
                editorBox.TextEditable = false
            end
            return
        end

        -- Normal editor: move the entire source into BigCode as soon as TextBox's
        -- visual rendering limit is crossed. The Text property may still contain it.
        if BigCode.shouldUsePreview(currentText) then
            switchToBigCode(currentText, textLength)
            return
        end

        if currentProject and editorBox.TextEditable then
            syncEditorToFile(currentProject, currentText)
        end

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
newlineButton.Activated:Connect(function() rememberCaret(); insertEditorNewline() end)

do
local pasteButton=createButton(codePanel,"Paste",UDim2.fromOffset(48,24),UDim2.new(1,-104,0,5),nil,COLORS.Accent)
pasteButton.TextSize=10
pasteButton.Activated:Connect(function()
    if type(getclipboard) ~= "function" then
        logConsole("Error", "getclipboard() is unavailable.")
        openConsole()
        return
    end
    if not currentProject then
        logConsole("Error", "Open a project before pasting.")
        openConsole()
        return
    end

    local ok, clipText = pcall(getclipboard)
    if not ok or type(clipText) ~= "string" then
        logConsole("Error", "Failed to read clipboard text.")
        openConsole()
        return
    end

    if BigCode.mode and BigCode.focusedEditor and BigCode.focusedEditor.Parent then
        local targetBox = BigCode.focusedEditor
        local source = targetBox.Text or ""
        local cursor = targetBox.CursorPosition
        local selection = targetBox.SelectionStart
        if not cursor or cursor < 1 then cursor = #source + 1 end
        if not selection or selection < 1 then selection = cursor end
        local first = math.clamp(math.min(cursor, selection), 1, #source + 1)
        local last = math.clamp(math.max(cursor, selection), 1, #source + 1)
        targetBox.Text = string.sub(source, 1, first - 1) .. clipText .. string.sub(source, last)
        local newCursor = first + #clipText
        targetBox.CursorPosition = newCursor
        targetBox.SelectionStart = newCursor
        local complete = BigCode.getSource()
        syncEditorToFile(currentProject, complete)
        if targetBox and targetBox.Parent and targetBox.Visible then
            targetBox:CaptureFocus()
        end
        editorStatus.Text = "Pasted into BigCode"
        editorStatus.TextColor3 = COLORS.Green
    elseif BigCode.shouldUsePreview(clipText) then
        BigCode.render(clipText)
        syncEditorToFile(currentProject, clipText)
        editorStatus.Text = "Large file loaded - " .. #BigCode.chunks .. " editable sections"
        editorStatus.TextColor3 = COLORS.Green
        logConsole("Success", "Loaded large clipboard text: " .. #clipText .. " characters")
    else
        BigCode.clearMode()
        editorBox.Visible = true
        editorBox.TextEditable = true
        editorBox.Text = clipText
        editorBox.CursorPosition = #clipText + 1
        editorBox.SelectionStart = #clipText + 1
        syncEditorToFile(currentProject, clipText)
        task.defer(measureEditorCanvas)
        editorBox:CaptureFocus()
        editorStatus.Text = "Clipboard pasted"
        editorStatus.TextColor3 = COLORS.Green
    end
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
renderFileTree=function()
    if not currentProject then return end
    for _,child in ipairs(treeList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local children=buildTreeMap(currentProject)
    local order=0
    local function addRows(parent,depth)
        for _,entry in ipairs(children[parent] or {}) do
            order=order+1
            local selected=selectedTreePath==entry.path and selectedTreeIsFolder==entry.isFolder
            local row=make("TextButton",{Name=entry.isFolder and "FolderRow" or "FileRow",Size=UDim2.new(1,-3,0,24),
                BackgroundColor3=selected and COLORS.PanelHover or COLORS.Panel2,BorderSizePixel=0,Text="",
                TextColor3=selected and COLORS.Accent or COLORS.Text,TextSize=9,
                Font=entry.isFolder and Enum.Font.GothamBold or Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,
                AutoButtonColor=true,LayoutOrder=order},treeList)
            addCorner(row,4)
            local iconText
            if entry.isFolder then
                iconText=expandedFolders[entry.path]==false and "📁" or "📂"
            else
                local extension=getFileExtension(entry.path)
                if extension=="lua" or extension=="luau" then iconText="📄"
                elseif extension=="json" then iconText="📋"
                elseif extension=="txt" then iconText="📃"
                elseif extension=="md" then iconText="📝"
                else iconText="📄" end
            end
            local entryLabel=createLabel(row,iconText.."  "..entry.name,UDim2.new(1,-(depth*14+12),1,0),
                UDim2.fromOffset(depth*14+6,0),9,selected and COLORS.Accent or COLORS.Text,
                entry.isFolder and Enum.Font.GothamBold or Enum.Font.Code)
            entryLabel.TextTruncate=Enum.TextTruncate.AtEnd
            row.Activated:Connect(function()
                local now=os.clock()
                local doubleClick=lastTreeClickPath==entry.path
                    and lastTreeClickIsFolder==entry.isFolder
                    and now-lastTreeClickTime<=0.38
                lastTreeClickPath=entry.path
                lastTreeClickIsFolder=entry.isFolder
                lastTreeClickTime=now
                selectedTreePath=entry.path
                selectedTreeIsFolder=entry.isFolder
                if updatePathBar then updatePathBar() end
                if doubleClick then
                    if entry.isFolder then
                        expandedFolders[entry.path]=expandedFolders[entry.path]==false
                    else
                        if BigCode.mode or editorBox.TextEditable then
                            BigCode.syncCurrentFile()
                        end
                        if BigCode.clearMode then BigCode.clearMode() end
                        currentProject.activeFile=entry.path
                        refreshEditorFileHeader(entry.path)
                        local fileSource=entry.file.code or ""
                        if BigCode.shouldUsePreview(fileSource) then
                            BigCode.render(fileSource)
                        else
                            editorBox.Visible=true
                            editorBox.TextEditable=true
                            editorBox.Text=fileSource
                            task.defer(measureEditorCanvas)
                        end
                        editorViewport.CanvasPosition=Vector2.new(0,0)
                        currentProject.updated=os.time()
                        saveData()
                    end
                end
                renderFileTree()
            end)
            if entry.isFolder and expandedFolders[entry.path]~=false then
                addRows(entry.path,depth+1)
            end
        end
    end
    addRows("",0)
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
        BackgroundTransparency=0.38,BorderSizePixel=0,ZIndex=100},targetParent)
    local popupWidth=math.min(360,math.max(260,(targetParent.AbsoluteSize.X or 360)-24))
    local popupHeight=154
    local popup=make("Frame",{Size=UDim2.fromOffset(popupWidth,popupHeight),
        Position=UDim2.new(0.5,-popupWidth/2,0.5,-popupHeight/2),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=101},overlay)
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
    if selectedTreePath~="" then displayText=displayText.." / "..selectedTreePath end
    pathBarUpdating=true
    pathBar.Text=displayText
    pathBarOriginalText=displayText
    pathBarUpdating=false
    pathCommitButton.Visible=false
    pathCancelButton.Visible=false
end

setTreeVisibility=function(open)
    isTreeOpen=open==true
    treePanel.Visible=isTreeOpen
    if isTreeOpen then
        codePanel.Position=UDim2.fromOffset(treePanelWidth+14,0)
        codePanel.Size=UDim2.new(1,-(treePanelWidth+21),1,0)
    else
        codePanel.Position=UDim2.fromOffset(7,0)
        codePanel.Size=UDim2.new(1,-14,1,0)
    end
    if treeToggleButton then treeToggleButton.Text=isTreeOpen and "Tree" or "Tree +" end
    task.defer(measureEditorCanvas)
end

editorMenu=make("Frame",{Name="EditorDropdown",Size=UDim2.fromOffset(compact and 142 or 164,126),
    Position=UDim2.fromOffset(10,82),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,Visible=false,ZIndex=30},editorPage)
addCorner(editorMenu,8)
addStroke(editorMenu,COLORS.Border)
createLabel(editorMenu,"Editor",UDim2.new(1,-16,0,22),UDim2.fromOffset(8,3),11,COLORS.Text,Enum.Font.GothamBold).ZIndex=31
local addFileMenuButton=createButton(editorMenu,"Add File",UDim2.new(1,-12,0,27),UDim2.fromOffset(6,28),function()
    editorMenu.Visible=false
    if createNewFile then createNewFile() end
end,COLORS.Panel2)
addFileMenuButton.ZIndex=31
local addFolderMenuButton=createButton(editorMenu,"Add Folder",UDim2.new(1,-12,0,27),UDim2.fromOffset(6,59),function()
    editorMenu.Visible=false
    if createNewFolder then createNewFolder() end
end,COLORS.Panel2)
addFolderMenuButton.ZIndex=31
local deleteMenuButton=createButton(editorMenu,"Delete",UDim2.new(1,-12,0,27),UDim2.fromOffset(6,90),function()
    editorMenu.Visible=false
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
    BackgroundColor3=COLORS.Panel,BorderSizePixel=0,Visible=false,ZIndex=20},editorPage)
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
    local editorFocusBound = false

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

        -- The overlay is parented to targetBox; use coordinates local to the TextBox
        -- rather than adding targetBox.Position a second time.
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
            -- Harvest live virtual editors first, then refresh offsets using the
            -- complete source so a match always targets the current chunk layout.
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
            -- Search the current, harvested source in every chunk. Advance by one
            -- byte so overlapping literal matches are included as well.
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
        if not editorFocusBound then
            editorBox.Focused:Connect(function()
                if findOverlay then findOverlay.Visible = false end
            end)
            editorFocusBound = true
        end

        findPopup = make("Frame", {
            Name = "FindPopup",
            Size = UDim2.fromOffset(300, 110),
            Position = UDim2.new(1, -310, 0, 125),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            Active = false,
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

local function raiseZIndex(root,value)
    if root:IsA("GuiObject") then root.ZIndex=value end
    for _,child in ipairs(root:GetChildren()) do if child:IsA("GuiObject") then raiseZIndex(child,value+1) end end
end
local function makeToolWindow(name,titleText,width,height,onClose)
    local frame=make("Frame",{Name=name,Size=UDim2.fromOffset(width,height),Position=UDim2.new(0.5,-width/2,0.5,-height/2),
        BackgroundColor3=COLORS.Background,BorderSizePixel=0,Visible=true,ZIndex=50},screenGui)
    addCorner(frame,10); addStroke(frame,COLORS.Border)
    local bar=make("Frame",{Size=UDim2.new(1,0,0,38),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=51},frame)
    addCorner(bar,10)
    local title=createLabel(bar,"  "..titleText,UDim2.new(1,-48,1,0),UDim2.fromOffset(6,0),13,COLORS.Text,Enum.Font.GothamBold); title.ZIndex=52
    local close=createButton(bar,"X",UDim2.fromOffset(28,26),UDim2.new(1,-34,0,6),function() if onClose then onClose() else frame.Visible=false end end)
    close.TextSize=18; close.ZIndex=52
    local content=make("Frame",{Name="Content",Position=UDim2.fromOffset(8,44),Size=UDim2.new(1,-16,1,-52),BackgroundTransparency=1,ZIndex=51},frame)
    return frame,content
end

-- === AI CHAT ===
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
    local chatWidth = compact and UDim2.fromOffset(340, 500) or UDim2.fromOffset(560, 560)
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
    }, editorPage)
    addCorner(frame, 10)
    addStroke(frame, COLORS.Border)

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
        -- Keep the cache for 24 hours to avoid unnecessary API requests.
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
                -- Filter out clearly non-chat models such as Whisper, TTS and embeddings.
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

    -- ===== Экран 1: список сервисов =====
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

    -- ===== Экран 2: список моделей =====
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
                -- Fall back to the provider's default model if the list cannot be loaded.
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

    -- ===== Экран 3: чат =====
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

        addMessage = function(speaker, message, kind)
            if not messageList or not messageList.Parent then return end
            message = tostring(message or "")
            local isError = kind == "error"
            local isAI = speaker == "AI"
            local color = isError and COLORS.Red or (isAI and COLORS.Blue or COLORS.Panel2)
            local row = make("Frame", {
                Size = UDim2.new(1, -2, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = color,
                BackgroundTransparency = isError and 0.78 or 0.72,
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

            local label = make("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Text = (isError and "Error: " or (speaker .. ": ")) .. message,
                TextColor3 = isError and COLORS.Red or COLORS.Text,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                LayoutOrder = 1,
                ZIndex = 83,
            }, inner)

            if isAI and not isError then
                row:SetAttribute("IsAIBubble", true)
                local btnRow = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    ZIndex = 83,
                }, inner)
                make("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, btnRow)

                local copyBtn = make("TextButton", {
                    Size = UDim2.fromOffset(56, 18),
                    BackgroundColor3 = COLORS.Panel2,
                    BackgroundTransparency = 0.3,
                    BorderSizePixel = 0,
                    Text = "Copy",
                    TextColor3 = COLORS.Muted,
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
                        task.delay(1, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
                        return
                    end
                    local ok = pcall(setclipboard, message)
                    copyBtn.Text = ok and "Copied!" or "Fail"
                    task.delay(1, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
                end)

                local regenBtn = make("TextButton", {
                    Size = UDim2.fromOffset(74, 18),
                    BackgroundColor3 = COLORS.Panel2,
                    BackgroundTransparency = 0.3,
                    BorderSizePixel = 0,
                    Text = "Regenerate",
                    TextColor3 = COLORS.Muted,
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

    -- ===== HTTP-запрос и отправка сообщений =====
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

        -- Persist the removal too, so a failed regeneration does not resurrect the old answer.
        if state.chatKey then
            state.sessionHistories[state.chatKey] = state.aiHistory
            saveAIChat(state.chatKey, state.aiHistory)
        end
        requestAI()
    end

    -- ===== Окно управления API-ключами =====
    openKeysEditor = function()
        local overlay = make("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            ZIndex = 200,
        }, frame)
        local pw = math.min(340, math.max(280, frame.AbsoluteSize.X - 24))
        local providerKeyCount = 0
        for _, provider in ipairs(AI_PROVIDERS) do
            if provider.keyRequired or provider.id == "pollinations" then
                providerKeyCount = providerKeyCount + 1
            end
        end
        local ph = math.max(190, 112 + providerKeyCount * 36)
        local popup = make("Frame", {
            Size = UDim2.fromOffset(pw, ph),
            Position = UDim2.new(0.5, -pw / 2, 0.5, -ph / 2),
            BackgroundColor3 = COLORS.Panel,
            BorderSizePixel = 0,
            ZIndex = 201,
        }, overlay)
        addCorner(popup, 10)
        addStroke(popup, COLORS.Border)
        local popupTitle = createLabel(popup, "API Keys", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 8), 14, COLORS.Text, Enum.Font.GothamBold)
        popupTitle.ZIndex = 202

        local y = 42
        for _, provider in ipairs(AI_PROVIDERS) do
            local selectedProvider = provider
            -- Show fields for required keys and for Pollinations' optional key.
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

-- === DEX ===
local dexWindow=nil
DexAutoRefresh = {Attach=nil, Detach=nil, SelectPartAttach=nil, SelectPartDetach=nil}
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
-- PATCH: extended class order
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
-- Sprite-sheet icons. Leave the ID empty until you upload your own sheet.
-- When empty, every class falls back to the built-in vector-drawn icons.
local DEX_ICON_SHEET_ID = ""
local ICON_CELL = 32
local DEX_ICON_MAP = {
    -- Coordinates: {column, row}, both zero-based.
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

    -- Legacy vector-drawn icon is retained as a fallback for unmapped classes.
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
    elseif vt=="EnumItem" then return tostring(value):gsub("^Enum%.","")
    elseif vt=="string" then return value=="" and '""' or value end
    return tostring(value)
end
local function openScriptNotepad(scriptObject)
    local sourceText=nil
    local sourceNote=nil
    local resultKind="unsupported"
    local diagnostics={}

    -- Resolve executor functions from the current chunk environment and the
    -- shared executor environment. Every lookup is protected as well.
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

    -- 1) Prefer the executor's native source decompiler.
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

    -- 2) If decompilation is unavailable, try to retrieve bytecode.
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

    -- 3) Last executor-specific option: retrieve the script closure.
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

    -- Keep the existing manual-source registration feature available.
    if not sourceText then
        local registeredSource=registeredScriptSources[scriptObject]
        if type(registeredSource)=="string" then
            sourceText=registeredSource
            resultKind="registered"
        end
    end

    -- 4) No supported method succeeded: explain the limitation clearly.
    if not sourceText then
        sourceText="Ваш исполнитель не поддерживает декомпиляцию скриптов. Попробуйте использовать другой исполнитель (например, Delta или Synapse)."
        if #diagnostics>0 then
            sourceText=sourceText.."\n\nРезультаты проверки:\n- "..table.concat(diagnostics,"\n- ")
        end
        sourceNote=sourceText
        resultKind="unsupported"
    end

    local w=math.max(300,math.min(820,viewport.X-36)); local h=math.max(240,math.min(600,viewport.Y-50))
    local frame,content
    frame,content=makeToolWindow("DexNotepad_"..tostring(#scriptViewerWindows+1),"Notepad - "..scriptObject.Name,w,h,function() frame.Visible=false end)
    table.insert(scriptViewerWindows,frame)
    local pathLabel=createLabel(content,objectPath(scriptObject),UDim2.new(1,-4,0,22),UDim2.fromOffset(0,0),9,COLORS.Muted,Enum.Font.Code); pathLabel.ZIndex=53
    local scroll=make("ScrollingFrame",{Position=UDim2.fromOffset(0,27),Size=UDim2.new(1,0,1,-27),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,
        ScrollBarThickness=7,ScrollBarImageColor3=COLORS.Muted,ScrollingDirection=Enum.ScrollingDirection.XY,CanvasSize=UDim2.fromOffset(0,0),ZIndex=52},content)
    addCorner(scroll,7)
    local noteBox=make("TextBox",{Name="SourceText",Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(600,300),BackgroundTransparency=1,BorderSizePixel=0,
        ClearTextOnFocus=false,MultiLine=true,TextEditable=false,Text=sourceText,TextColor3=sourceNote and COLORS.Yellow or COLORS.Text,
        TextSize=12,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=false,ZIndex=53},scroll)
    local maxW=500; local lc=1
    for line in (sourceText.."\n"):gmatch("(.-)\n") do
        lc=lc+1
        local ok,m=pcall(function() return TextService:GetTextSize(line,12,Enum.Font.Code,Vector2.new(100000,30)) end)
        if ok then maxW=math.max(maxW,m.X) end
    end
    local cw=math.max(scroll.AbsoluteSize.X-16,maxW+22); local ch=math.max(scroll.AbsoluteSize.Y-16,lc*17+20)
    noteBox.Size=UDim2.fromOffset(cw,ch); scroll.CanvasSize=UDim2.fromOffset(cw+16,ch+16)
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
    local width=math.max(300,math.min(940,viewport.X-28)); local height=math.max(260,math.min(650,viewport.Y-36))
    local selectedObject=game; local expanded={[game]=true}; local clickTimes=setmetatable({},{__mode="k"})
    local frame,content; local treeList,propertiesList,renderTree,updateProperties,searchBox
    local locateSelectedObject
    local selectPartAttach, selectPartDetach
    frame,content=makeToolWindow("DexExplorerWindow","Dex Explorer",width,height,function()
        frame.Visible=false
        if DexAutoRefresh.Detach then DexAutoRefresh.Detach() end
    end)
    dexWindow=frame

    local toolbar=make("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,ZIndex=53},content)
    local searchWrap=make("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,ZIndex=53},toolbar)
    addCorner(searchWrap,6)
    searchBox=make("TextBox",{Size=UDim2.new(1,-12,1,0),Position=UDim2.fromOffset(7,0),BackgroundTransparency=1,ClearTextOnFocus=false,
        PlaceholderText="Search name or class...",Text="",TextColor3=COLORS.Text,PlaceholderColor3=COLORS.Muted,TextSize=10,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=54},searchWrap)

    local dividerX=width<520 and 0.53 or 0.55
    treeList=make("ScrollingFrame",{Name="ExplorerTree",Position=UDim2.fromOffset(0,36),Size=UDim2.new(dividerX,-5,1,-72),BackgroundColor3=COLORS.Panel,
        BorderSizePixel=0,ScrollBarThickness=7,ScrollBarImageColor3=COLORS.Muted,CanvasSize=UDim2.fromOffset(0,0),ZIndex=52},content)
    addCorner(treeList,7)
    -- Virtual rows are positioned manually; no UIListLayout is needed here.

    local propertiesPanel=make("Frame",{Position=UDim2.new(dividerX,5,0,36),Size=UDim2.new(1-dividerX,-5,1,-72),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=52},content)
    addCorner(propertiesPanel,7)
    local dexSmallUI = width < 520
    local propertiesTitle=createLabel(propertiesPanel, dexSmallUI and "  P" or "  Properties", UDim2.new(1,-12,0,25), UDim2.fromOffset(6,1), 11, COLORS.Text, Enum.Font.GothamBold)
    propertiesTitle.ZIndex=54

    -- Local popups inside the Dex window
    local function showDexInputPopup(titleText, initialText, onConfirm)
        local overlay = make("Frame", {
            Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 150,
        }, frame)
        local pw = math.min(340, math.max(240, frame.AbsoluteSize.X - 30))
        local ph = 170
        local popup = make("Frame", {
            Size = UDim2.fromOffset(pw, ph), Position = UDim2.new(0.5, -pw/2, 0.5, -ph/2),
            BackgroundColor3 = COLORS.Panel, BorderSizePixel = 0, ZIndex = 151,
        }, overlay)
        addCorner(popup, 10); addStroke(popup, COLORS.Border)
        local tt = createLabel(popup, titleText, UDim2.new(1,-24,0,26), UDim2.fromOffset(12,8), 14, COLORS.Text, Enum.Font.GothamBold); tt.ZIndex=152
        local input = make("TextBox", {
            Size = UDim2.new(1,-28,0,36), Position = UDim2.fromOffset(14,42),
            BackgroundColor3 = COLORS.Panel2, BorderSizePixel = 0,
            Text = initialText or "", PlaceholderText = "New name", PlaceholderColor3 = COLORS.Muted,
            TextColor3 = COLORS.Text, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, ZIndex = 152,
        }, popup)
        addCorner(input, 6)
        local errLabel = createLabel(popup, "", UDim2.new(1,-28,0,16), UDim2.fromOffset(14,80), 9, COLORS.Red); errLabel.ZIndex=152
        local cancel = createButton(popup, "Cancel", UDim2.fromOffset(80,30), UDim2.new(1,-180,1,-40), function() overlay:Destroy() end, COLORS.Panel2); cancel.ZIndex=152
        local confirm = createButton(popup, "OK", UDim2.fromOffset(80,30), UDim2.new(1,-92,1,-40), function()
            local v = trim(input.Text or "")
            if v == "" then errLabel.Text = "Name cannot be empty."; return end
            local ok, err = onConfirm(v)
            if ok then overlay:Destroy() else errLabel.Text = tostring(err or "Failed.") end
        end, COLORS.Accent); confirm.ZIndex=152
        task.defer(function() if input and input.Parent then input:CaptureFocus() end end)
    end

    local function showDexConfirmPopup(titleText, message, onConfirm)
        local overlay = make("Frame", {
            Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 150,
        }, frame)
        local pw = math.min(340, math.max(240, frame.AbsoluteSize.X - 30))
        local ph = 150
        local popup = make("Frame", {
            Size = UDim2.fromOffset(pw, ph), Position = UDim2.new(0.5, -pw/2, 0.5, -ph/2),
            BackgroundColor3 = COLORS.Panel, BorderSizePixel = 0, ZIndex = 151,
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

    -- Dex footer with four full-width actions.
    local dexFooter = make("Frame", {
        Name = "DexFooter",
        Position = UDim2.new(0, 0, 1, -34),
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ZIndex = 53,
    }, content)
    addCorner(dexFooter, 6)
    addStroke(dexFooter, COLORS.Border, 0.5)

    local footerBtnW = math.floor((width - 24 - 16) / 5)
    local footerBtnH = 26
    local footerBtnY = 4

    local function footerBtnPos(i)
        return UDim2.fromOffset(6 + (i - 1) * (footerBtnW + 4), footerBtnY)
    end

    local renamePropButton = createButton(dexFooter, "Rename", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(1), function()
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
    renamePropButton.ZIndex = 54

    local deletePropButton = createButton(dexFooter, "Delete", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(2), function()
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
    deletePropButton.ZIndex = 54

    local copyPropButton
    copyPropButton = createButton(dexFooter, "Copy", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(3), function()
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
    copyPropButton.ZIndex = 54

    local locateButton = createButton(dexFooter, "Locate", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(4), function()
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
    locateButton.ZIndex = 54

    -- Select a world part by clicking it while Select mode is active.
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

        -- Ignore clicks on the Easy Scripting UI itself.
        if isPointOverDexGui(pos) then return end

        local cam = workspace.CurrentCamera
        if not cam then return end
        local ray = cam:ScreenPointToRay(pos.X, pos.Y)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)

        if result and result.Instance then
            local target = result.Instance

            -- Reveal the target's ancestors in the Explorer tree.
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

            -- SelectionBox adorns BaseParts. Terrain and other non-BasePart
            -- hits are still selected in Dex, but do not receive an outline.
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

    selectPartButton = createButton(dexFooter, "Select", UDim2.fromOffset(footerBtnW, footerBtnH), footerBtnPos(5), function()
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
    selectPartButton.ZIndex = 54

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
    local function addPropertyRow(name,value,order)
        local row=make("Frame",{Size=UDim2.new(1,-8,0,27),BackgroundColor3=order%2==0 and COLORS.Panel2 or COLORS.Panel,BorderSizePixel=0,LayoutOrder=order,ZIndex=54},propertiesList)
        local k=createLabel(row,name,UDim2.new(0.43,-4,1,0),UDim2.fromOffset(6,0),9,COLORS.Muted); k.ZIndex=55
        local v=createLabel(row,tostring(value),UDim2.new(0.57,-8,1,0),UDim2.new(0.43,0,0,0),9,COLORS.Text,Enum.Font.Code)
        v.TextTruncate=Enum.TextTruncate.AtEnd; v.ZIndex=55
        return order+1
    end
    updateProperties=function(object)
        clearGuiRows(propertiesList)
        local order=1
        if not object then
            order=addPropertyCategory("Selection",order); addPropertyRow("Object","Nothing selected",order); return
        end
        propertiesTitle.Text = dexSmallUI and "  P" or "  Properties"
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
    -- Virtualized tree: flat data list + a small reusable pool of row widgets.
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

            -- Sort children only when the node is expanded. Collapsed nodes still
            -- need a child count for their expander, but do not need sorting.
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
            -- Normal mode: preserve the full explorer tree and user expansion state.
            buildFlatList()
            emptyState.Text=""
        else
            -- Filter/search mode: include matching objects and only the ancestors
            -- required to show each match in its real hierarchy.
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

    -- Debounced live refresh. Connections are disconnected when Dex closes and
    -- reattached if the existing Dex window is opened again.
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

-- RemoteSpy → Cobalt loader (user's version)
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

-- FreeCam (camera only)
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
    if freeCam.controls then pcall(function() freeCam.controls:Enable() end); freeCam.controls=nil end
    local camera=workspace.CurrentCamera
    if camera then pcall(function()
        camera.CameraType=freeCam.oldCameraType or Enum.CameraType.Custom
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if freeCam.oldCameraSubject and freeCam.oldCameraSubject.Parent then camera.CameraSubject=freeCam.oldCameraSubject
        else camera.CameraSubject=hum end
    end) end
    pcall(function()
        UserInputService.MouseBehavior=freeCam.oldMouseBehavior or Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled=freeCam.oldMouseIconEnabled~=false
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
    local w=math.max(285,math.min(410,windowWidth-30)); local h=compact and 250 or 210
    local frame,content; frame,content=makeToolWindow("FreeCamWindow","FreeCam - camera only",w,h,function() stopFreeCam(); frame.Visible=false end)
    freeCamWindow=frame
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

-- Tools connections
toolDexButton.Activated:Connect(function() toolsPanel.Visible=false; openDex() end)
toolRemoteButton.Activated:Connect(function() toolsPanel.Visible=false; openRemoteSpy() end)
toolFreeCamButton.Activated:Connect(function() toolsPanel.Visible=false; openFreeCam() end)

-- Init
loadData(); renderProjects(); renderExecutePage()
if not fileStorageAvailable then
    logConsole("Warning","readfile/writefile unavailable. Session-only projects.")
else logConsole("Info","Project storage: "..DATA_FILE) end

task.defer(function()
    local startupAutoCount=0
    task.wait(0.75)
    for _,project in ipairs(projects) do
        ensureProjectStructure(project)
        for _,file in ipairs(project.files) do
            if file.autoExecute and isScriptFile(file.path) then
                startupAutoCount=startupAutoCount+1
                executeProjectFile(project,file,false)
            end
        end
    end
    if startupAutoCount>0 then logConsole("Info","Auto Execute started "..tostring(startupAutoCount).." file(s).") end
end)

screenGui.Destroying:Connect(function()
    if DexAutoRefresh.Detach then pcall(DexAutoRefresh.Detach) end
    if DexAutoRefresh.SelectPartDetach then pcall(DexAutoRefresh.SelectPartDetach) end
    if stopFreeCam then pcall(stopFreeCam) end
    if floatingGui then pcall(function() floatingGui:Destroy() end) end
    if sharedEnvironment then
        pcall(function()
            if sharedEnvironment.EasyScriptingDex==dexAPI then sharedEnvironment.EasyScriptingDex=nil end
        end)
    end
end)

print("Easy Scripting "..VERSION.." loaded.")
