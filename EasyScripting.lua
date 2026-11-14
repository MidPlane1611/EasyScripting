--[[ Easy Scripting v1.5 (Dex+) — compact patched build
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
local VERSION = "v1.5"

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

local header=make("Frame",{Size=UDim2.new(1,0,0,46),BackgroundColor3=COLORS.Panel,BorderSizePixel=0},window)
local headerTitle=createLabel(header,"  Easy Scripting "..VERSION,UDim2.new(1,-220,1,0),UDim2.fromOffset(8,0),16,COLORS.Text,Enum.Font.GothamBold)
local headerSubtitle=createLabel(header,"HOME",UDim2.fromOffset(150,20),UDim2.new(1,-224,0,13),10,COLORS.Muted)
headerSubtitle.TextXAlignment=Enum.TextXAlignment.Right

local toggleEasyScripting
local minimizeButton=createButton(header,"–",UDim2.fromOffset(34,30),UDim2.new(1,-80,0,8),function() if toggleEasyScripting then toggleEasyScripting() end end,COLORS.Panel2)
minimizeButton.TextSize=22
local closeButton=createButton(header,"X",UDim2.fromOffset(34,30),UDim2.new(1,-42,0,8),function() screenGui:Destroy() end,COLORS.Panel2)
closeButton.TextSize=20
makeDraggable(header,window)

local isHidden=false
function toggleEasyScripting()
    isHidden=not isHidden
    screenGui.Enabled=not isHidden
    floatingButton.Visible=isHidden
end
floatingButton.Activated:Connect(toggleEasyScripting)
UserInputService.InputBegan:Connect(function(input,processed) if processed then return end; if input.KeyCode==TOGGLE_KEY then toggleEasyScripting() end end)

local body=make("Frame",{Name="Body",Position=UDim2.fromOffset(0,46),Size=UDim2.new(1,0,1,-46),BackgroundTransparency=1},window)

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
local selectedTreePath="main.lua"
local selectedTreeIsFolder=false

local function refreshEditorFileHeader(path)
    if editorFileLabel then editorFileLabel.Text=path or "" end
    if path then
        local ext=getFileExtension(path)
        if editorBox then
            if ext=="json" then editorBox.PlaceholderText='{"key": "value"}'
            elseif ext=="txt" then editorBox.PlaceholderText="Write text here..."
            elseif ext=="md" then editorBox.PlaceholderText="# Project notes"
            else editorBox.PlaceholderText="-- Start writing Luau code here..." end
        end
        if runCheckButton then
            if isScriptFile(path) then runCheckButton.Text=compact and "Check" or "Run Script"
            else runCheckButton.Text=compact and "Valid." or "Validate" end
        end
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
    if not editorBox or not line or line<1 then return end
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
    makeDraggable(ch,consoleWindow); renderConsole()
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
    if src~=nil then file.code=src end
    project.code=file.code or ""; project.updated=os.time()
    return file
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
    currentProject=project
    ensureProjectStructure(project)
    local f=getProjectFile(project,project.activeFile)
    editorBox.Text=f and f.code or ""
    if editorViewport then editorViewport.CanvasPosition=Vector2.new(0,0) end
    selectedTreePath=project.activeFile or "main.lua"; selectedTreeIsFolder=false
    refreshEditorFileHeader(project.activeFile)
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
-- Editor toolbar
local editorToolbar=make("Frame",{Size=UDim2.new(1,-20,0,42),Position=UDim2.fromOffset(10,7),BackgroundTransparency=1},editorPage)
local toolbarBackWidth=compact and 34 or 38
local toolbarToolsWidth=compact and 62 or 82
local toolbarRunWidth=compact and 76 or 112
local toolbarSaveWidth=compact and 54 or 66
local toolbarConsoleWidth=compact and 70 or 82
local gap=compact and 4 or 7
local xBack=0
local xTools=xBack+toolbarBackWidth+gap
local xRun=xTools+toolbarToolsWidth+gap
local xSave=xRun+toolbarRunWidth+gap
local xConsole=xSave+toolbarSaveWidth+gap
createButton(editorToolbar,"Back",UDim2.fromOffset(toolbarBackWidth,32),UDim2.fromOffset(xBack,4),function()
    if currentProject then syncEditorToFile(currentProject,editorBox.Text); saveData() end
    if toolsPanel then toolsPanel.Visible=false end
    editorPage.Visible=false; projectsPage.Visible=true; headerSubtitle.Text="HOME"; renderProjects()
end,COLORS.Panel2).TextSize=18
local toolsButton=createButton(editorToolbar,"Tools",UDim2.fromOffset(toolbarToolsWidth,32),UDim2.fromOffset(xTools,4),function()
    if toolsPanel then toolsPanel.Visible=not toolsPanel.Visible end
end); toolsButton.TextSize=compact and 10 or 12
runCheckButton=createButton(editorToolbar,compact and "Check" or "Run Script",UDim2.fromOffset(toolbarRunWidth,32),UDim2.fromOffset(xRun,4),function()
    if not currentProject then return end
    syncEditorToFile(currentProject,editorBox.Text)
    local ap=currentProject.activeFile or "main.lua"
    local af=getProjectFile(currentProject,ap)
    local ok,msg,line=validateProjectFile(af,editorBox.Text)
    if ok then
        logConsole("Success",ap..": "..msg)
        editorStatus.Text=isScriptFile(ap) and "Syntax check passed - not executed" or msg
        editorStatus.TextColor3=COLORS.Green
    else
        logConsole("Error",ap..": "..msg,line)
        editorStatus.Text=line and ("Syntax error on line "..tostring(line)) or "Syntax check failed"
        editorStatus.TextColor3=COLORS.Red
    end
    openConsole()
end,COLORS.Panel2); runCheckButton.TextSize=compact and 10 or 12
createButton(editorToolbar,"Save",UDim2.fromOffset(toolbarSaveWidth,32),UDim2.fromOffset(xSave,4),function()
    if not currentProject then return end
    syncEditorToFile(currentProject,editorBox.Text)
    local s,msg=saveData()
    if s then
        editorStatus.Text="Saved - "..getProjectSize(currentProject); editorStatus.TextColor3=COLORS.Green
        logConsole("Success","Saved "..currentProject.name.."/"..currentProject.activeFile)
    else
        editorStatus.Text="Session copy updated"; editorStatus.TextColor3=COLORS.Yellow
        logConsole("Warning",msg)
    end
end,COLORS.Panel2).TextSize=compact and 10 or 12
createButton(editorToolbar,"Console",UDim2.fromOffset(toolbarConsoleWidth,32),UDim2.fromOffset(xConsole,4),openConsole,COLORS.Panel2).TextSize=compact and 10 or 12

local editorSurface=make("Frame",{Position=UDim2.fromOffset(10,56),Size=UDim2.new(1,-20,1,-91),BackgroundColor3=COLORS.Panel,BorderSizePixel=0},editorPage)
addCorner(editorSurface,8); addStroke(editorSurface,COLORS.Border,0.5)
local treePanelWidth=compact and 106 or 164
local treePanel=make("Frame",{Name="ProjectFileTree",Position=UDim2.fromOffset(7,7),Size=UDim2.new(0,treePanelWidth,1,-14),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0},editorSurface)
addCorner(treePanel,7)
createLabel(treePanel,"FILES",UDim2.new(1,-10,0,20),UDim2.fromOffset(6,4),9,COLORS.Muted,Enum.Font.GothamBold)
local actionScrollHeight=compact and 82 or 108
local fileActionsScroll=make("ScrollingFrame",{Name="FileActionsScroll",Position=UDim2.fromOffset(4,27),Size=UDim2.new(1,-8,0,actionScrollHeight),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y},treePanel)
local fileActionsLayout=make("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},fileActionsScroll)
fileActionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() fileActionsScroll.CanvasSize=UDim2.fromOffset(0,fileActionsLayout.AbsoluteContentSize.Y+4) end)
local newFileButton=createButton(fileActionsScroll,"+ File",UDim2.new(1,-4,0,24),UDim2.new(),nil,COLORS.PanelHover); newFileButton.TextSize=9; newFileButton.LayoutOrder=1
local newFolderButton=createButton(fileActionsScroll,"+ Folder",UDim2.new(1,-4,0,24),UDim2.new(),nil,COLORS.PanelHover); newFolderButton.TextSize=9; newFolderButton.LayoutOrder=2
local renameTreeButton=createButton(fileActionsScroll,"Rename",UDim2.new(1,-4,0,24),UDim2.new(),nil,COLORS.PanelHover); renameTreeButton.TextSize=9; renameTreeButton.LayoutOrder=3
local deleteTreeButton=createButton(fileActionsScroll,"Delete",UDim2.new(1,-4,0,24),UDim2.new(),nil,Color3.fromRGB(105,47,57)); deleteTreeButton.TextSize=9; deleteTreeButton.LayoutOrder=4
local treeListTop=27+actionScrollHeight+5
local treeList=make("ScrollingFrame",{Name="FileTreeList",Position=UDim2.fromOffset(4,treeListTop),Size=UDim2.new(1,-8,1,-(treeListTop+4)),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0)},treePanel)
local fileTreeLayout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},treeList)
fileTreeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() treeList.CanvasSize=UDim2.fromOffset(0,fileTreeLayout.AbsoluteContentSize.Y+6) end)
local codePanel=make("Frame",{Name="CodePanel",Position=UDim2.fromOffset(treePanelWidth+14,0),Size=UDim2.new(1,-(treePanelWidth+21),1,0),BackgroundTransparency=1},editorSurface)
editorFileLabel=createLabel(codePanel,"main.lua",UDim2.new(1,-58,0,25),UDim2.fromOffset(3,5),10,COLORS.Muted,Enum.Font.GothamBold)
local newlineButton=createButton(codePanel,"Enter",UDim2.fromOffset(48,24),UDim2.new(1,-51,0,5),nil,COLORS.Panel2); newlineButton.TextSize=10
editorViewport=make("ScrollingFrame",{Name="CodeViewport",Position=UDim2.fromOffset(3,32),Size=UDim2.new(1,-6,1,-38),BackgroundColor3=COLORS.Panel,
    BorderSizePixel=0,ClipsDescendants=true,ScrollBarThickness=compact and 5 or 7,ScrollBarImageColor3=COLORS.Muted,
    ScrollingDirection=Enum.ScrollingDirection.XY,CanvasSize=UDim2.fromOffset(0,0),Active=true},codePanel)
addCorner(editorViewport,6)
editorBox=make("TextBox",{Name="CodeEditor",Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(320,220),BackgroundTransparency=1,BorderSizePixel=0,
    Text="",PlaceholderText="-- Start writing Luau code here...",PlaceholderColor3=COLORS.Muted,TextColor3=COLORS.Text,
    TextSize=compact and 11 or 13,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
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
    if not editorBox or not editorBox.Parent or not editorViewport then return end
    local vis=editorViewport.AbsoluteSize
    if vis.X<=0 or vis.Y<=0 then return end
    local src=editorBox.Text or ""; local lc=0; local longest=""
    for line in (src.."\n"):gmatch("(.-)\n") do lc=lc+1; if #line>#longest then longest=line end end
    if lc==0 then lc=1 end
    local ts=editorBox.TextSize; local font=editorBox.Font
    local wb=TextService:GetTextSize(longest~="" and longest or " ",ts,font,Vector2.new(100000,100000))
    local lb=TextService:GetTextSize("Ag",ts,font,Vector2.new(100000,100000))
    local ew=math.max(vis.X-16,math.ceil(wb.X+28))
    local eh=math.max(vis.Y-12,math.ceil(lc*lb.Y+18))
    editorBox.Size=UDim2.fromOffset(ew,eh)
    editorViewport.CanvasSize=UDim2.fromOffset(ew+16,eh+12)
end
local function keepEditorCaretVisible()
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
    local lh=math.max(1,lb.Y); local cx=8+(lp=="" and 0 or pb.X); local cy=6+(ln-1)*lh
    local view=editorViewport.AbsoluteSize; local current=editorViewport.CanvasPosition
    local margin=16; local nx=current.X; local ny=current.Y; local cw=7
    if cx<current.X+margin then nx=math.max(0,cx-margin) elseif cx+cw>current.X+view.X-margin then nx=cx+cw-view.X+margin end
    if cy<current.Y+margin then ny=math.max(0,cy-margin) elseif cy+lh>current.Y+view.Y-margin then ny=cy+lh-view.Y+margin end
    editorViewport.CanvasPosition=Vector2.new(math.max(0,nx),math.max(0,ny))
end
editorBox:GetPropertyChangedSignal("Text"):Connect(function()
    if currentProject then syncEditorToFile(currentProject,editorBox.Text) end
    measureEditorCanvas(); task.defer(keepEditorCaretVisible)
end)
UserInputService.InputBegan:Connect(function(input)
    if not editorBox or not editorBox:IsFocused() then return end
    local k=input.KeyCode
    if k==Enum.KeyCode.Left or k==Enum.KeyCode.Right or k==Enum.KeyCode.Up or k==Enum.KeyCode.Down
        or k==Enum.KeyCode.Home or k==Enum.KeyCode.End or k==Enum.KeyCode.PageUp or k==Enum.KeyCode.PageDown then
        task.defer(keepEditorCaretVisible)
    end
end)
editorViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() measureEditorCanvas() end)
task.defer(measureEditorCanvas)
local function insertEditorNewline()
    local src=editorBox.Text or ""
    local cur=editorBox.CursorPosition; local sel=editorBox.SelectionStart
    if not cur or cur<1 then cur=lastEditorCursor end
    if not sel or sel<1 then sel=lastEditorSelection end
    if not cur or cur<1 then cur=#src+1 end
    if not sel or sel<1 then sel=cur end
    local first=math.clamp(math.min(cur,sel),1,#src+1); local last=math.clamp(math.max(cur,sel),1,#src+1)
    local updated=string.sub(src,1,first-1).."\n"..string.sub(src,last)
    editorBox.Text=updated
    local np=first+1; lastEditorCursor=np; lastEditorSelection=np
    editorBox.CursorPosition=np; editorBox.SelectionStart=np
    task.defer(function() if editorBox and editorBox.Parent and editorPage.Visible then editorBox:CaptureFocus() end end)
end
newlineButton.Activated:Connect(function() rememberCaret(); insertEditorNewline() end)
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
    for _,c in ipairs(treeList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local children=buildTreeMap(currentProject)
    local order=0
    local function addRows(parent,depth)
        for _,entry in ipairs(children[parent] or {}) do
            order=order+1
            local selected=selectedTreePath==entry.path and selectedTreeIsFolder==entry.isFolder
            local prefix
            if entry.isFolder then prefix=expandedFolders[entry.path]==false and "DIR+ " or "DIR- "
            else prefix="FILE " end
            local rowText=string.rep("  ",math.min(depth,4))..prefix..entry.name
            local row=make("TextButton",{Name=entry.isFolder and "FolderRow" or "FileRow",Size=UDim2.new(1,-3,0,24),
                BackgroundColor3=selected and COLORS.PanelHover or COLORS.Panel2,BorderSizePixel=0,Text=rowText,
                TextColor3=selected and COLORS.Accent or COLORS.Text,TextSize=9,
                Font=entry.isFolder and Enum.Font.GothamBold or Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,
                AutoButtonColor=true,LayoutOrder=order},treeList)
            addCorner(row,4)
            row.Activated:Connect(function()
                selectedTreePath=entry.path; selectedTreeIsFolder=entry.isFolder
                if entry.isFolder then expandedFolders[entry.path]=expandedFolders[entry.path]==false
                else
                    syncEditorToFile(currentProject,editorBox.Text)
                    currentProject.activeFile=entry.path
                    editorBox.Text=entry.file.code or ""
                    refreshEditorFileHeader(entry.path)
                    editorViewport.CanvasPosition=Vector2.new(0,0)
                    currentProject.updated=os.time(); saveData()
                end
                renderFileTree()
            end)
            if entry.isFolder and expandedFolders[entry.path]~=false then addRows(entry.path,depth+1) end
        end
    end
    addRows("",0)
end
local function showPathPopup(title,initialText,confirmText,onConfirm)
    showTextPopup(title,initialText or "",confirmText or "Create",function(value) return onConfirm(value) end)
end
local function currentCreationBase() if selectedTreeIsFolder then return selectedTreePath end; return parentPath(selectedTreePath) end
local function appendToBase(base,name) if base=="" then return name end; return base.."/"..name end
newFileButton.Activated:Connect(function()
    if not currentProject then return end
    local initial=appendToBase(currentCreationBase(),"new.lua")
    showPathPopup("Add file",initial,"Create",function(value)
        local path=normalizePath(value); if not path then return false,"Invalid file path." end
        if not path:match("%.[%w_%-]+$") then path=path..".lua" end
        if not isSupportedFile(path) then return false,"Supported: .lua/.luau/.json/.txt/.md" end
        if pathTaken(currentProject,path) then return false,"Path exists." end
        syncEditorToFile(currentProject,editorBox.Text)
        ensureParentFolders(currentProject,path)
        table.insert(currentProject.files,{path=path,code="",autoExecute=false})
        currentProject.activeFile=path; editorBox.Text=""; refreshEditorFileHeader(path)
        editorViewport.CanvasPosition=Vector2.new(0,0)
        selectedTreePath=path; selectedTreeIsFolder=false; currentProject.updated=os.time()
        saveData(); renderFileTree()
        if renderProjects then renderProjects() end
        if renderExecutePage then renderExecutePage() end
        return true
    end)
end)
newFolderButton.Activated:Connect(function()
    if not currentProject then return end
    local initial=appendToBase(currentCreationBase(),"NewFolder")
    showPathPopup("Add folder",initial,"Create",function(value)
        local path=normalizePath(value); if not path then return false,"Invalid folder path." end
        if pathTaken(currentProject,path) then return false,"Path exists." end
        syncEditorToFile(currentProject,editorBox.Text)
        ensureParentFolders(currentProject,path)
        table.insert(currentProject.folders,path)
        selectedTreePath=path; selectedTreeIsFolder=true; expandedFolders[path]=true
        currentProject.updated=os.time(); saveData(); renderFileTree()
        if renderProjects then renderProjects() end
        return true
    end)
end)
renameTreeButton.Activated:Connect(function()
    if not currentProject then return end
    if not selectedTreePath or selectedTreePath=="" then logConsole("Warning","Select file/folder to rename."); openConsole(); return end
    syncEditorToFile(currentProject,editorBox.Text)
    local oldPath=selectedTreePath; local isFolder=selectedTreeIsFolder
    showPathPopup(isFolder and "Rename folder" or "Rename file",oldPath,"Rename",function(value)
        local newPath=normalizePath(value); if not newPath then return false,"Invalid path." end
        if newPath==oldPath then return true end
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
                if not inside and (folder==newPath or string.sub(folder,1,#newPath+1)==newPath.."/") then return false,"Overlaps folder." end
            end
            local activePath=currentProject.activeFile
            if activePath==oldPath then currentProject.activeFile=newPath
            elseif string.sub(activePath or "",1,#oldPrefix)==oldPrefix then currentProject.activeFile=newPath..string.sub(activePath,#oldPath+1) end
            for _,file in ipairs(currentProject.files) do
                if file.path==oldPath then file.path=newPath
                elseif string.sub(file.path,1,#oldPrefix)==oldPrefix then file.path=newPath..string.sub(file.path,#oldPath+1) end
            end
            if currentProject.activeFile then refreshEditorFileHeader(currentProject.activeFile) end
            for i,folder in ipairs(currentProject.folders) do
                if folder==oldPath then currentProject.folders[i]=newPath
                elseif string.sub(folder,1,#oldPrefix)==oldPrefix then currentProject.folders[i]=newPath..string.sub(folder,#oldPath+1) end
            end
            local movedExpanded={}
            for path,expanded in pairs(expandedFolders) do
                if path==oldPath then movedExpanded[newPath]=expanded
                elseif string.sub(path,1,#oldPrefix)==oldPrefix then movedExpanded[newPath..string.sub(path,#oldPath+1)]=expanded
                else movedExpanded[path]=expanded end
            end
            expandedFolders=movedExpanded
            ensureParentFolders(currentProject,newPath)
        else
            local oldExt=getFileExtension(oldPath)
            if not newPath:match("%.[%w_%-]+$") then newPath=newPath.."."..oldExt end
            if not isSupportedFile(newPath) then return false,"Supported: .lua/.luau/.json/.txt/.md" end
            if pathTaken(currentProject,newPath,oldPath) then return false,"Path exists." end
            local file=getProjectFile(currentProject,oldPath); if not file then return false,"File gone." end
            file.path=newPath
            if not isScriptFile(newPath) then file.autoExecute=false end
            if currentProject.activeFile==oldPath then currentProject.activeFile=newPath; refreshEditorFileHeader(newPath) end
            ensureParentFolders(currentProject,newPath)
        end
        selectedTreePath=newPath; currentProject.updated=os.time(); saveData(); renderFileTree()
        if renderProjects then renderProjects() end
        if renderExecutePage then renderExecutePage() end
        logConsole("Success","Renamed "..oldPath.." to "..newPath)
        return true
    end)
end)
deleteTreeButton.Activated:Connect(function()
    if not currentProject then return end
    if not selectedTreePath or selectedTreePath=="" then logConsole("Warning","Select file/folder to delete."); openConsole(); return end
    syncEditorToFile(currentProject,editorBox.Text)
    local target=selectedTreePath
    if selectedTreeIsFolder then
        local prefix=target.."/"
        for i=#currentProject.files,1,-1 do
            local p=currentProject.files[i].path
            if p==target or string.sub(p,1,#prefix)==prefix then table.remove(currentProject.files,i) end
        end
        for i=#currentProject.folders,1,-1 do
            local f=currentProject.folders[i]
            if f==target or string.sub(f,1,#prefix)==prefix then table.remove(currentProject.folders,i) end
        end
        logConsole("Info","Deleted folder: "..target)
    else
        if #currentProject.files<=1 then logConsole("Warning","Project needs at least 1 file."); openConsole(); return end
        for i,file in ipairs(currentProject.files) do if file.path==target then table.remove(currentProject.files,i); break end end
        logConsole("Info","Deleted file: "..target)
    end
    if #currentProject.files==0 then
        table.insert(currentProject.files,{path="main.lua",code="",autoExecute=false})
        currentProject.folders={}; currentProject.activeFile="main.lua"
    elseif selectedTreeIsFolder then
        local af=getProjectFile(currentProject,currentProject.activeFile)
        if not af then currentProject.activeFile=currentProject.files[1].path end
    elseif currentProject.activeFile==target then
        currentProject.activeFile=currentProject.files[1].path
    end
    local af=getProjectFile(currentProject,currentProject.activeFile)
    editorBox.Text=af and af.code or ""
    refreshEditorFileHeader(currentProject.activeFile)
    editorViewport.CanvasPosition=Vector2.new(0,0)
    selectedTreePath=currentProject.activeFile; selectedTreeIsFolder=false
    currentProject.updated=os.time(); saveData(); renderFileTree()
    if renderProjects then renderProjects() end
    if renderExecutePage then renderExecutePage() end
end)

toolsPanel=make("Frame",{Name="ToolsPanel",Size=UDim2.fromOffset(compact and 190 or 220,152),Position=UDim2.fromOffset(48,48),
    BackgroundColor3=COLORS.Panel,BorderSizePixel=0,Visible=false,ZIndex=20},editorPage)
addCorner(toolsPanel,9); addStroke(toolsPanel,COLORS.Border)
createLabel(toolsPanel,"Tools",UDim2.new(1,-18,0,24),UDim2.fromOffset(10,4),13,COLORS.Text,Enum.Font.GothamBold).ZIndex=21
local toolDexButton=createButton(toolsPanel,"Dex Explorer",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,32),nil,COLORS.Panel2); toolDexButton.ZIndex=21
local toolRemoteButton=createButton(toolsPanel,"RemoteSpy",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,67),nil,COLORS.Panel2); toolRemoteButton.ZIndex=21
local toolFreeCamButton=createButton(toolsPanel,"FreeCam",UDim2.new(1,-16,0,30),UDim2.fromOffset(8,102),nil,COLORS.Panel2); toolFreeCamButton.ZIndex=21

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
    makeDraggable(bar,frame)
    return frame,content
end
local function objectPath(object)
    local names={}; local current=object
    while current and current~=game do table.insert(names,1,current.Name); current=current.Parent end
    return "game."..table.concat(names,".")
end

-- === DEX ===
local dexWindow=nil
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
-- PATCH: detailed icons
local function createDexIcon(parent,className,position,zIndex)
    local code,color=classBadge(className)
    local baseZ=zIndex or 55
    local root=make("Frame",{Size=UDim2.fromOffset(19,19),Position=position,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=baseZ},parent)
    local function shape(size,offset,fill,radius,transparency)
        local item=make("Frame",{Size=size,Position=offset,BackgroundColor3=fill,BackgroundTransparency=transparency or 0,BorderSizePixel=0,ZIndex=baseZ+1},root)
        if radius then addCorner(item,radius) end
        return item
    end
    local function bg(fill) return shape(UDim2.fromOffset(17,17),UDim2.fromOffset(1,1),fill or Color3.fromRGB(32,36,47),4) end
    local function miniLabel(target,text,size,pos,tsize,tcolor)
        local l=createLabel(target,text,size,pos,tsize,tcolor,Enum.Font.GothamBold)
        l.TextXAlignment=Enum.TextXAlignment.Center; l.TextYAlignment=Enum.TextYAlignment.Center; l.ZIndex=baseZ+3
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
    local sourceText=registeredScriptSources[scriptObject]; local sourceNote=nil
    if type(sourceText)~="string" then
        local ok,result=pcall(function() return scriptObject.Source end)
        if ok and type(result)=="string" then sourceText=result
        else
            sourceNote="Roblox does not expose this Script.Source to the client.\n\nFor a script you own, provide its source with:\n\ngetgenv().EasyScriptingDex.RegisterSource(scriptInstance, [[\n-- your source\n]])\n\nThe viewer does not bypass Roblox source-access restrictions."
            sourceText=sourceNote
        end
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
    if dexWindow then dexWindow.Visible=true; raiseZIndex(dexWindow,50); return end
    local width=math.max(300,math.min(940,viewport.X-28)); local height=math.max(260,math.min(650,viewport.Y-36))
    local selectedObject=game; local expanded={[game]=true}; local clickTimes=setmetatable({},{__mode="k"})
    local frame,content; local treeList,propertiesList,renderTree,updateProperties,searchBox
    frame,content=makeToolWindow("DexExplorerWindow","Dex Explorer",width,height,function() frame.Visible=false end)
    dexWindow=frame

    local toolbar=make("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,ZIndex=53},content)
    local searchWrap=make("Frame",{Size=UDim2.new(1,-86,1,0),BackgroundColor3=COLORS.Panel2,BorderSizePixel=0,ZIndex=53},toolbar)
    addCorner(searchWrap,6)
    searchBox=make("TextBox",{Size=UDim2.new(1,-12,1,0),Position=UDim2.fromOffset(7,0),BackgroundTransparency=1,ClearTextOnFocus=false,
        PlaceholderText="Search name or class...",Text="",TextColor3=COLORS.Text,PlaceholderColor3=COLORS.Muted,TextSize=10,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=54},searchWrap)

    -- PATCH: filter buttons
    local activeFilter="All"
    local filterDefs={
        {"All",function(o) return true end},
        {"Scripts",function(o) return o:IsA("BaseScript") or o:IsA("ModuleScript") end},
        {"Remotes",function(o) return o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("UnreliableRemoteEvent") or o:IsA("BindableEvent") or o:IsA("BindableFunction") end},
        {"Gui",function(o) return o:IsA("GuiObject") or o:IsA("LayerCollector") end},
        {"Values",function(o) return o:IsA("ValueBase") end},
        {"Services",function(o) return o.Parent==game end},
    }
    local filterBar=make("Frame",{Size=UDim2.new(1,0,0,26),Position=UDim2.fromOffset(0,38),BackgroundTransparency=1,ZIndex=53},content)
    local filterButtons={}
    local fbw=math.min(70,math.floor((width-16)/#filterDefs)-2)
    for i,def in ipairs(filterDefs) do
        local btn=createButton(filterBar,def[1],UDim2.fromOffset(fbw,24),UDim2.fromOffset((i-1)*(fbw+2),1),function()
            activeFilter=def[1]
            for _,b in pairs(filterButtons) do b.BackgroundColor3=COLORS.Panel2 end
            btn.BackgroundColor3=COLORS.Accent
            renderTree()
        end,def[1]=="All" and COLORS.Accent or COLORS.Panel2)
        btn.TextSize=9; btn.ZIndex=54; filterButtons[def[1]]=btn
    end

    local refresh=createButton(toolbar,"Refresh",UDim2.fromOffset(78,30),UDim2.new(1,-78,0,0),function() renderTree(); updateProperties(selectedObject) end,COLORS.Panel2)
    refresh.ZIndex=54

    local dividerX=width<520 and 0.53 or 0.55
    treeList=make("ScrollingFrame",{Name="ExplorerTree",Position=UDim2.fromOffset(0,66),Size=UDim2.new(dividerX,-5,1,-66),BackgroundColor3=COLORS.Panel,
        BorderSizePixel=0,ScrollBarThickness=7,ScrollBarImageColor3=COLORS.Muted,CanvasSize=UDim2.fromOffset(0,0),ZIndex=52},content)
    addCorner(treeList,7)
    local treeLayout=make("UIListLayout",{Padding=UDim.new(0,1),SortOrder=Enum.SortOrder.LayoutOrder},treeList)
    treeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() treeList.CanvasSize=UDim2.fromOffset(0,treeLayout.AbsoluteContentSize.Y+8) end)

    local propertiesPanel=make("Frame",{Position=UDim2.new(dividerX,5,0,66),Size=UDim2.new(1-dividerX,-5,1,-66),BackgroundColor3=COLORS.Panel,BorderSizePixel=0,ZIndex=52},content)
    addCorner(propertiesPanel,7)
    local propertiesTitle=createLabel(propertiesPanel,"  Properties",UDim2.new(1,-70,0,25),UDim2.fromOffset(6,1),11,COLORS.Text,Enum.Font.GothamBold); propertiesTitle.ZIndex=54

    -- PATCH: Locate button
    local locateButton=createButton(propertiesPanel,"Locate",UDim2.fromOffset(56,20),UDim2.new(1,-62,0,3),function()
        if not selectedObject then return end
        local current=selectedObject
        while current and current~=game do
            if current.Parent then expanded[current.Parent]=true end
            current=current.Parent
        end
        expanded[game]=true
        searchBox.Text=""
        for _,b in pairs(filterButtons) do b.BackgroundColor3=COLORS.Panel2 end
        filterButtons["All"].BackgroundColor3=COLORS.Accent
        activeFilter="All"
        renderTree()
    end,COLORS.Panel2)
    locateButton.TextSize=9; locateButton.ZIndex=54

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
        propertiesTitle.Text="  Properties - "..object.Name
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
    local function addTreeRow(object,depth,order,searchablePath)
        local children=safeChildren(object)
        local isExpanded=expanded[object]==true
        local indent=math.min(depth*13,150)
        local row=make("Frame",{Size=UDim2.new(1,-5,0,24),BackgroundColor3=selectedObject==object and COLORS.PanelHover or COLORS.Panel,
            BorderSizePixel=0,LayoutOrder=order,ZIndex=54},treeList)
        local expander=createButton(row,#children>0 and (isExpanded and "v" or ">") or " ",UDim2.fromOffset(15,22),UDim2.fromOffset(indent,1),function()
            if #children>0 then expanded[object]=not isExpanded; renderTree() end
        end,COLORS.Panel)
        expander.TextSize=10; expander.ZIndex=56
        createDexIcon(row,object.ClassName,UDim2.fromOffset(indent+16,2),55)
        local rowText=searchablePath or object.Name
        local selectButton=make("TextButton",{Size=UDim2.new(1,-(indent+40),1,0),Position=UDim2.fromOffset(indent+39,0),BackgroundTransparency=1,
            BorderSizePixel=0,Text=rowText..(searchablePath and ("  ["..object.ClassName.."]") or ""),TextColor3=COLORS.Text,
            TextSize=9,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,AutoButtonColor=true,ZIndex=55},row)
        selectButton.Activated:Connect(function()
            local now=os.clock(); local lastTap=clickTimes[object] or 0
            local doubleTap=now-lastTap<=0.38
            clickTimes[object]=now; selectedObject=object; updateProperties(object); renderTree()
            if doubleTap and (object.ClassName=="Script" or object.ClassName=="LocalScript" or object.ClassName=="ModuleScript") then openScriptNotepad(object) end
        end)
        if not searchablePath and isExpanded then
            for _,child in ipairs(children) do
                order=order+1; if order>3500 then break end
                order=addTreeRow(child,depth+1,order,nil)
            end
        end
        return order
    end

    -- PATCH: renderTree with filters & class search
    renderTree=function()
        clearGuiRows(treeList)
        local query=string.lower(searchBox.Text or "")
        local order=0
        if query~="" or activeFilter~="All" then
            local ok,desc=pcall(function() return game:GetDescendants() end)
            local matches={}
            if ok then
                for _,object in ipairs(desc) do
                    local passes=true
                    if activeFilter~="All" then
                        for _,def in ipairs(filterDefs) do
                            if def[1]==activeFilter then passes=def[2](object); break end
                        end
                    end
                    if passes then
                        local nm=query=="" or string.find(string.lower(object.Name),query,1,true)
                            or string.find(string.lower(object.ClassName),query,1,true)
                        if nm then table.insert(matches,object); if #matches>=1200 then break end end
                    end
                end
            end
            table.sort(matches,function(a,b)
                local ao=getDexClassOrder(a); local bo=getDexClassOrder(b)
                if ao~=bo then return ao<bo end
                return objectPath(a):lower()<objectPath(b):lower()
            end)
            for _,object in ipairs(matches) do order=order+1; addTreeRow(object,0,order,objectPath(object)) end
            if #matches==0 then
                local msg=activeFilter~="All" and ("No "..activeFilter:lower()..(query~="" and (" matching '"..query.."'") or "")) or "No matching objects"
                local empty=createLabel(treeList,msg,UDim2.new(1,-12,0,30),UDim2.fromOffset(6,4),10,COLORS.Muted)
                empty.LayoutOrder=1; empty.ZIndex=55
            end
        else order=addTreeRow(game,0,1,nil) end
        updateProperties(selectedObject)
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(renderTree)
    renderTree(); raiseZIndex(dexWindow,50)
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

local startupAutoCount=0
task.defer(function()
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
    if stopFreeCam then pcall(stopFreeCam) end
    if floatingGui then pcall(function() floatingGui:Destroy() end) end
    if sharedEnvironment then
        pcall(function()
            if sharedEnvironment.EasyScriptingDex==dexAPI then sharedEnvironment.EasyScriptingDex=nil end
        end)
    end
end)

print("Easy Scripting "..VERSION.." loaded.")
