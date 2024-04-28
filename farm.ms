dotNet.loadAssembly "MaxCustomControls.dll"	
dotnet.loadAssembly "System.Drawing"
dotnet.loadAssembly "System.Core" 
    
(
	local dlg_main
 
     
struct TestResult
(
	id,
	index,
	validator,
	severity,
	type,
	val,
	message,
	flagMoreInfos
);

fn existsFile fname =
(
	if fname == "" or fname==undefined then return false
	return (getfiles fname).count != 0
)

fn tr id:0 index:0 validator:"" severity:0 type:0 value:0 message:"" flagMoreInfos:false =
(
	t = TestResult()
	t.id=id
	t.index=index
	t.validator=validator
	t.severity=severity
	t.type=type
	t.val=value
	t.message=message
	t.flagMoreInfos=flagMoreInfos
	return t
)

struct FileInfo
(
	serverPath,
	localPath,
	fileSize,
	toCopy,
	notFoundNormally
);

fn findVecItem vec p =
(
	local i = 1
	for stp in vec do
	(
		if stp.serverPath == p then
			return i
		i = i+1
	)
	return 0
)

fn appendFileInfo &vec lp sp tcopy:true type:undefined =
(
	if findVecItem vec sp == 0 then
	(
		local fi = FileInfo()
		fi.serverPath = sp
		fi.localPath = lp
		fi.fileSize = getFileSize fi.localPath
		fi.toCopy = tcopy
		fi.notFoundNormally = (type == "_workaround_")
		append vec fi
	)
)

fn getDirContentsRecursive dir vec =
(
	for f in (getFiles (dir + "\\*")) do
	(
		append vec f
	)
	for i in (getDirectories (dir + "\\*")) do
	(
		getDirContentsRecursive i vec
	)
)

fn getDirContents dir =
(
	local vec = #()
	getDirContentsRecursive dir vec
	local vec2 = #()
	for f in vec do
	(
		append vec2 (substring f (dir.count+1) -1)
	)
	return vec2
)

fn FindFiles mapfiles =
(
	fn addmap mapfile mf =
	(
		local mapfileN=mapfile as name
		local idx=finditem mf mapfileN
		if idx == 0 do append mf mapfileN
	)
	enumeratefiles addmap mapfiles
	sort mapfiles
)

fn replaceAll haystack srch repl  =
(
	ret = haystack
	while findString ret srch != undefined do
	(
		pos = findString ret srch
		ret = replace ret pos srch.count repl
	)
	return ret
)

--not supported in max <= 2014
fn mTimeGetTime =
(
	local maxver = maxVersion()
	if  maxver[1] >= 16000 then
		return timeGetTime()
	return 0
)

fn myToLower st =
(
	stRet = ""
	for i=1 to st.count do
	(
		s = st[i]
		ascii = bit.charasint s
		if  ascii >= 65 AND ascii <= 90 then
			stRet = stRet + (bit.intaschar (ascii + 32))
		else
			stRet = stRet + s
	)
	return stRet
)

global downloadFileFromUrl
fn downloadFileFromUrl url dest =
(
	try
	(
		wc = dotnetobject "System.Net.WebClient"
		wc.downloadFile url dest
		wc.dispose()
		return true
	)
	catch
	(
		return false
	)
)

fn getIflFilenames file =
(
	v = #()
	file = pathConfig.convertPathToAbsolute file
	if existsFile file then
	(
		f = openFile file mode:"rt"
		while NOT eof f do
		(
			st = readline f  -- get filename from line
			if NOT st[1] == ";" then -- if line wont begin with ; its fine
			(
				arr = filterString st " " -- if count == line is empty so -> ignore
				if arr.count == 0 then
					continue
				if arr[arr.count] as integer != undefined then
				(
					s = trimright (substring st 1 (st.count - arr[arr.count].count))
					append v s
				)
				else
					append v st
			)
		)
	)
	return v
)

fn splitBinaryUnicodeBuffer buffer=
(
	ret = #()
	enc = dotNetClass "System.Text.Encoding"
	cur = #()
	for i=1 to buffer.count-1 by 2 do
	(
		if buffer[i] == 0 and buffer[i+1] == 0 then
		(
			strData = enc.Unicode.GetString cur
			append ret strData
			cur = #()
		)
		else
		(
			append cur buffer[i]
			append cur buffer[i+1]
		)
	)
	strData = enc.Unicode.GetString cur
	append ret strData
	return ret
)

fn findMaxAssetsDirectly maxFile=
(
	try
	(
		gc() -- Fuck MAX!!! this is needed as otherwise multiple calls to this function will not necessarily result in the expected return values. Somehow the cFile object is reused over multiple session otherwise. Finding this maxscript bug was fucking hell

		local res = #()
		dotnet.loadassembly (dlg_main.my_path +"OpenMcdf.dll")

		local cFile = dotNetObject "OpenMcdf.CompoundFile" maxFile

		if not cFile.HasSourceStream then
		(
			return false
		)

		local stream = 0
		local entries = cFile.GetAllNamedEntries("FileAssetMetaData2")
		if entries.Count > 0 then
			stream = cFile.RootStorage.GetStream("FileAssetMetaData2")
		else
			stream = cFile.RootStorage.GetStream("FileAssetMetaData3")

		local buffer = stream.GetData()
		local assetData = splitBinaryUnicodeBuffer buffer

		for i=1 to assetData.count do
		(
			if assetData[i] == "Bitmap" or assetData[i] == "ExternalLink" then
			(
				local filename = assetData[i + 2]
				local filepath = assetData[i + 4]
				if filepath != undefined and filepath.count > 0 and filepath != "Bitmap"  and filepath != "ExternalLink" then
				(
					append res filepath
				)
				else if filename != undefined and filename.count > 0 and filename != "Bitmap"  and filename != "ExternalLink" then
				(
					append res filename
				)
			)
-- this only works if the renderoutput files come last in the list, but this does not seem to be the case in all max files
--			else if assetData[i] == "RenderOutput" then
--				exit
		)
		return res
	)
	catch( return false )
)

fn getMaxFileAssets maxFile vecFiles fromXref:false =
(
	try	--this should not be needed but as a workaround for now for safety reasons we get all the assets this way...
	(
		fileassets = findMaxAssetsDirectly maxFile
		for p in fileassets do
		(
			if myToLower (getFilenameType p) == ".max" and findItem vecFiles p == 0 then
			(
				if not existsFile p then
				(
					local f = xrefPaths.getFullFilePath p
					if f != "" then
						p = f
				)
				if not existsFile p then
				(
					local f = mapPaths.getFullFilePath p
					if f != "" then
						p = f
				)
				if existsFile p then
					getMaxFileAssets p vecFiles fromXref:true
			)
			else if fromXref then
			(
				if not existsFile p then
				(
					local f = mapPaths.getFullFilePath p
					if f != "" then
						p = f
				)
				if not existsFile p then
				(
					local f = xrefPaths.getFullFilePath p
					if f != "" then
						p = f
				)
			)
			append vecFiles p
		)
		--sub-sub-xrefs are not found, so search the old way as well
		fileassets = getMAXFileAssetMetadata maxFile
		for asset in fileassets do
		(
			if (ATSOps.IsInputFile asset.FileName or fromXref) and asset.FileName != undefined and asset.FileName != "" then
			(
				local p = asset.FileName
				if myToLower (getFilenameType p) == ".max" and findItem vecFiles p == 0 then
				(
					if not existsFile p then
					(
						local f = mapPaths.getFullFilePath p
						if f != "" then
							p = f
					)
					if not existsFile p then
					(
						local f = xrefPaths.getFullFilePath p
						if f != "" then
							p = f
					)
					if existsFile p then
						getMaxFileAssets p vecFiles fromXref:true
					append vecFiles p
				)
				else if myToLower (getFilenameType p) == ".maxc" and findItem vecFiles p == 0 then
				(
					append vecFiles p
				)
			)
		)
	)
	catch
	(
		format "getMaxFileAssets: *** % ***\n" (getCurrentException())
	)
)

fn documentSaved = (maxFilePath + maxFileName != "")

fn isRendererInstalled id =
(
	if id == undefined then return false
	return true
)

fn CheckPath filename =
(
	allowed = "abcdefghijklmnopqrstuvwxyz{}`~ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_&'()+,-.0123456789;=�����������������������������������������������������������������������\\/:. "
	for i = 1 to filename.count do
	(
		if (findstring allowed filename[i]) == undefined then
		(
			print ("unsupported char (pos:"+(i as string)+" chr:"+((bit.charAsInt filename[i]) as string)+") of path " +filename)
			return FALSE
		)
	)
	return TRUE
)

fn CheckFilename filename =
(
	allowed = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-. "
	for i = 1 to filename.count do
	(
		if (findstring allowed filename[i]) == undefined then
		(
			print ("unsupported char "+(i as string)+" of path " +filename)
			return FALSE
		)
	)
	return TRUE
)

fn CheckFilenameUnicode filename =
(
	if (maxVersion())[1] >= 15000 then
		return TRUE
	else return (CheckFilename filename)
)

fn ChangeFilename filename =
(
	allowed = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-. "

	bChanged=false
	for i = 1 to filename.count do
	(
		if (findstring allowed filename[i])==undefined then
		(
			print ("unsupported char "+(i as string)+" of path " +filename)
			filename[i] = "_"
			bChanged = TRUE
		)
	)
	if bChanged then	return filename
	else return ""
)

fn ChangeFilenameUnicode filename =
(
	if (maxVersion())[1] >= 15000 then
		return ""
	else return (ChangeFilename filename)
)

fn appendFilename file str =
(
	f = getFilenameFile file
	ex = getFilenameType file
	ret = f + "_" + str + "_" + ex
)

fn getLanguageSettings =
(
	dotnet.loadassembly "mscorlib.dll"
	Regis = dotNetClass "Microsoft.Win32.Registry"

	a = Regis.CurrentUser.OpenSubKey "Control Panel"
	a = a.OpenSubKey "International"
	return (a.GetValue "sDecimal")
)

fn bb &bool1 bool2 =
(
	bool1 = bool1 AND bool2
)

fn bb2 &bool1 barr =
(
	for b in barr while bool1 do
		bool1 = bool1 AND b
)

fn checkRes src =
( 
	return true
)

fn isMovieTexture tex =
(
	texlo = myToLower tex
	if texlo == ".mov" do return true
	if texlo == ".avi" do return true
	if texlo == ".mpg" do return true
	if texlo == ".mpeg" do return true
	if texlo == ".wmv" do return true
	if texlo == ".asf" do return true
	if texlo == ".mp4" do return true
	if texlo == ".flv" do return true
	if texlo == ".divx" do return true
	return false
)
fn isExtensionSupported saveExt =
(
	if (stricmp saveExt ".jpg") != 0 AND (stricmp saveExt ".jpeg") != 0 AND (stricmp saveExt ".bmp") != 0 AND
			 (stricmp saveExt ".rpf") != 0 AND (stricmp saveExt ".tif") != 0 AND (stricmp saveExt ".tiff") != 0 AND
			 (stricmp saveExt ".tga") != 0 AND (stricmp saveExt ".png") != 0 AND (stricmp saveExt ".exr") != 0 AND
			(stricmp saveExt ".hdr") != 0 AND (stricmp saveExt ".cxr") != 0 then
		return false
	else
		return true
)
fn isSingleFrameExtensionSupported saveExt =
(
	if classof renderers.production == mental_ray_renderer or classof renderers.production == CoronaRenderer or classof renderers.production == mental_ray_iray_Renderer then
	(
		if (stricmp saveExt ".exr") == 0 then
			return true
	)
	if classof renderers.production == vray or classof renderers.production == vrayrt then
	(
		if (stricmp saveExt ".exr") == 0 then
			return true
	)
	if classof renderers.production == CoronaRenderer then
	(
		if (stricmp saveExt ".cxr") == 0 then
			return true
	)
	if ((stricmp saveExt ".tif") != 0 AND (stricmp saveExt ".tiff") != 0 AND (stricmp saveExt ".tga") != 0 AND
	(stricmp saveExt ".png") != 0 AND (stricmp saveExt ".bmp") != 0) then
		return false
	else
		return true
)
fn createPath stPath stFile =
(
	return ("X:\\" + stPath + "\\" + stFile)
)
fn createTexPath stPath stFile =
(
	return ("X:\\" + stPath + "\\tex\\" + stFile)
)
fn createOutputPath stUser stFile =
(
	return ("c:\\logs\\output\\" + stUser + "\\" + stFile)
)
fn createTemprenderPath stUser stFile =
(
	return ("c:\\logs\\temprender\\" + stUser + "\\" + stFile)
)
fn findRenderDialogElement txt =
(
	dialogs = UIAccessor.GetPopupDialogs()

	bFound = false
	for d in dialogs do
	(
		if (((findstring (UIAccessor.GetWindowText d) "Render Scene:") == 1) OR
			((findstring (UIAccessor.GetWindowText d) "Render Setup:") == 1)) then
		(

			for a in (UIAccessor.GetChildWindows d) do
			(
				if UIAccessor.GetWindowText  a == txt then
				(
					return a
				)
			)
			bFound = true
		)
	)
	--if NOT bFound then
		--print "Render Dialog not found, or not open"

	return -1
)

fn calcMd5 filepath =
(
	try
	(
		md5 = dotnetobject "System.Security.Cryptography.MD5CryptoServiceProvider"
		file = dotnetclass "System.IO.File"
		filemode = dotnetclass "System.IO.FileMode"
		fileacc = dotnetclass "System.IO.FileAccess"
		f = file.Open filepath filemode.Open fileacc.Read
		bytes = md5.ComputeHash(f)
		f.Close()
		local st = ""
		for b in bytes do
		(
			st = st + formattedPrint b format:"02X"
		)
		return st
	)
	catch
	(
		return "0"
	)
)

fn GeneratePreview filepath =
(
	local grab_bmp
	grab_bmp = gw.getViewportDib()
	bimp = bitmap 120 80
	bimp.filename = filepath
	copy grab_bmp bimp
	save bimp
	-- render is not working with textures when executed after preparesave, but if executed before textures can't be found afterwards... weird?!
	--render frame:#current outputwidth:120 outputheight:80 outputfile:filepath useRadiosity:false quiet:true vfb:false
)

fn findIflPath iflfile iflentry =
(
	local iflfile = pathConfig.convertPathToAbsolute iflfile
	local iflFound = false
	local iflPath = mapPaths.getFullFilePath iflentry

	if existsFile iflPath then
		iflFound = true
	else
		iflPath = pathConfig.appendPath (pathConfig.removePathLeaf iflfile) (filenameFromPath iflentry)

	if existsFile iflPath and iflFound == false then
		iflFound = true

	if iflFound == true then
		return iflPath
	else
		return undefined
)
fn getConfigFileContent =
(
	file = openFile (dlg_main.my_path + "clientsettings.cfg") mode:"r"
	if file != undefined then
	(
		try
		(
			stUser = readline file
			stPath = readline file
			stManager = readline file
			stPluginVersion = readline file
			stCpuData = ""
			bLiveEnabled = false
			bCopyTex = true
			if not eof file then
			(
				stCpuData = readline file
			)
			if not eof file then
			(
				bLiveEnabled = (readline file) == "1"
			)
			if not eof file then
			(
				bCopyTex = (readline file) == "1"
			)
			ret = #()
			append ret stUser
			append ret stPath
			append ret stManager
			append ret stPluginVersion
			append ret stCpuData
			append ret bLiveEnabled
			append ret bCopyTex
			close file
			return ret
		)
		catch
		(
			return undefined
		)
	)
	return undefined
)
fn readFtpFileContents filePath &contsFiles &contsSizes =
(
	file = openFile filePath mode:"r"
	if file != undefined then
	(

			while not eof file do
			(
				try
				(
					local s = myToLower (readline file)
					local entry = filterString s ":"
					append contsFiles entry[1]
					append contsSizes entry[2]
				)
				catch
				(
				)
			)

		close file
		return true
	)
	return false
)
/* 	usage:
	im listener:

	a = proptest1 <obj>
	... irgendwas veraendern
	proptest2 <obj> a

*/
fn proptest1 rend =
(
	props = getPropNames rend
	vals1 = #()

	for i = 1 to props.count do
	(
		vals1[i] = getProperty rend props[i]
	)

	return vals1
)

fn proptest2 rend vals1 =
(
	props = getPropNames rend
	vals2 = proptest1 rend
	res = #()

	for i = 1 to vals1.count do
	(
		if vals1[i] != vals2[i] then
			append res props[i]
	)

	return res
)

fn getAllProperties obj =
(
	local props = getPropNames obj
	local keyvals= #()

	for i = 1 to props.count do
	(
		try(
		append keyvals #(props[i], getProperty obj props[i])
		)catch()
	)

	return keyvals
)

fn setAllProperties obj props exclude =
(
	for i = 1 to props.count do
	(
		local keyval = props[i]
		if (findItem exclude keyval[1]) == 0 then
		(
--			try(
			print((keyval[1] as string) + " " + (keyval[2] as string))
			setProperty obj keyval[1] keyval[2]
--			)catch()
		)
	)
)


fn getChangedMaxFilename dest:undefined =
(
	local maxFile = ChangeFilenameUnicode maxFileName
	if maxFile == "" then
		maxFile = maxFileName
	for i = 1 to maxFile.count do
		if maxFile[i] == " " then
			maxFile[i] = "_"
	if maxFile == undefined OR maxFile == "" then
		maxFile = "Untitled.max"

	if maxFile[1] == "-" then
		maxFile = "_" + maxFile

	if dest !=undefined and existsFile (pathConfig.appendPath dest maxFile) == true and existsFile (pathConfig.appendPath dest (maxFile+".cfg")) == true then
	(
		local pre = substring maxFile 1 (maxFile.count - 4)
		local i=1
		do
		(
			maxFile = pre + "_" +(i as string)+".max"
			i+=1
		)
		while(existsFile (pathConfig.appendPath dest maxFile) and existsFile (pathConfig.appendPath dest (maxFile+".cfg")))
	)

	return maxFile
)
fn getDefaultOutputName ext =
(
	if getChangedMaxFilename() == "Untitled.max" then
		return ("farm." + ext)
	else
		return ((getFilenameFile (getChangedMaxFilename())) + "." + ext)
)

fn hasMovieTextures =
(
	ATSOps.Refresh()
	local m = #()
	ATSOps.GetFiles &m

	for i = 1 to m.count do
	(
		local st = m[i] as string
		if isMovieTexture (getfilenametype st) then
			return true
	)
	return false
)
fn hasQuicktimeTextures =
(
	ATSOps.Refresh()
	local m = #()
	ATSOps.GetFiles &m

	for i = 1 to m.count do
	(
		local st = m[i] as string
		if ".mov" == myToLower (getfilenametype st) then
			return true
	)
	return false
)
fn hasRpcTextures =
(
	ATSOps.Refresh()
	local m = #()
	ATSOps.GetFiles &m

	for i = 1 to m.count do
	(
		local st = m[i] as string
		if getfilenametype st == ".rpc" then
			return true
	)
	return false
)
fn getExeVersion =
(
	local versinfo = dotnetclass "System.Diagnostics.FileVersionInfo"
	local myFI = versinfo.GetVersionInfo  (pathConfig.appendPath (pathConfig.GetDir #maxroot) "3dsmax.exe")
	return myFI.FileVersion
)
fn escapeString st =
(
	local a = filterstring st "%" splitEmptyTokens:true
	local s = ""
	for p in a do
	(
		if s.count > 0 then
			s = s + "\%"
		s = s + p
	)
	return s
)
fn sortTextFile =
(
	local plugsfile = openFile ("C:\\Users\\tobi\\Desktop\\test\\2009 64.txt.txt") mode:"r"
	if plugsfile != undefined then
	(
		local supportedplugs = #()
		while NOT (eof plugsfile) do
			append supportedplugs (readline plugsfile)

		supportedplugs = sort supportedplugs
		supportedplugs = makeUniqueArray (supportedplugs)
		for a in supportedplugs do
			print a
	)
)

fn getNumFrames =
(
	local numFrames = 0
	if rendTimeType == 2 then
		numFrames = ceil(((animationRange.end.frame as integer) - (animationRange.start.frame as integer) +1) / (rendNThFrame as float)) as integer
	if rendTimeType == 3 then
		numFrames = ceil(((rendEnd.frame as integer) - (rendStart.frame as integer) + 1) / (rendNThFrame as float)) as integer
	if rendTimeType == 1 then
		numFrames = 1
	return numFrames
)

fn calcMinMaxRP rpPerHour =
(
	local numFrames = getNumFrames()
	local minRP = numFrames * rpPerHour / 120
	if minRP < 2 then
		minRP = 2
	return minRP
)

fn getRpHourFactor =
(
	if classof renderers.production == vrayrt or classof renderers.production == vray then
		return 2.89
	return 1.60
)

fn getRpHourFactorGpu =
(
	return 7.56
)

fn getAnimatedProps theObject ap=
(
	try
	(
		if theObject.keys.count >1 do
		(
			for i=2 to theObject.keys.count do
			(
				if theObject.keys[i].value != theObject.keys[i-1].value do
					append ap theObject
			)
		)
	)catch(false)
	for i = 1 to theObject.numSubs do
		getAnimatedProps theObject[i] ap
)
fn hasAnimatedProps theObject=
(
	try
	(
		if theObject.keys.count >1 do
		(
			for i=2 to theObject.keys.count do
			(
				if theObject.keys[i].value != theObject.keys[i-1].value do
					return true
			)
		)
	)catch(false)
	for i = 1 to theObject.numSubs do
	(
		if hasAnimatedProps theObject[i] then
			return true
	)
	return false
)

fn importRebPythonUtils =
(
	local rebpath = "\"" + (replaceAll (getFilenamePath (getSourceFilename())) "\\" "/") + "\""
	local pyinit = "import sys
if "+rebpath+" not in sys.path:
	sys.path.append("+rebpath+")"
	python.execute pyinit
	local py = python.import "farmOption"
	python.reload py
	return py
)

fn importRebPYMXSUtils =
(
	local rebpath = "\"" + (replaceAll (getFilenamePath (getSourceFilename())) "\\" "/") + "\""
	local pyinit = "import sys
if "+rebpath+" not in sys.path:
	sys.path.append("+rebpath+")"
	python.execute pyinit
	local py = python.import "farmPx"
	python.reload py
	return py
)

fn isSceneAnimated =
(
	local maxver = maxversion()
	if maxver[1] >= 23000 then
	(
		local py = importRebPYMXSUtils()
		return py.pyIsSceneAnimated()
	)
	if maxver[1] >= 19000 then --huge performance issues in Max 2017 see rev20512 so use python
	(
		local py = importRebPythonUtils()
		return py.pyIsSceneAnimated()
	)
	else
	(
		local starttime = mTimeGetTime()
		for o in $* do
		(
			pushPrompt("checking Keyframe: " + o as string + "...")
			if hasAnimatedProps o then
				return true
			popPrompt()
			if mTimeGetTime() - starttime > 1000 then
			(
				print "redraw"
				starttime = mTimeGetTime()
				redrawViews()
			)
		)
		return false
	)
)
fn getAnimatedObjects count=
(
	animated_props = #()
	animated_objs = #()
	i=0
	for o in $* do
	(
		getAnimatedProps o animated_props
		if animated_props.count > 0 then
		(
			append animated_objs o
			i=i+1
			if i >= count then
				exit
		)
	)
	return animated_objs
)

fn deleteAllKeyframes =
(
	local maxver = maxversion()
	if maxver[1] >= 23000 then
	(
		local py = importRebPYMXSUtils()
		return py.pyDeleteAllKeyframes()
	)
	if maxver[1] >= 19000 then --huge performance issues in Max 2017 see rev20512 so use python
	(
		local py = importRebPythonUtils()
		return py.pyDeleteAllKeyframes()
	)
	else
	(
		if rendTimeType == 2 then
			sliderTime = animationRange.start
		if rendTimeType == 3 then
			sliderTime = rendStart

		local starttime = mTimeGetTime()
		animated_props = #()
		animated_objs = #()
		i=0
		for o in $* do
		(
			pushPrompt("Removing Keyframe: " + o as string + "...")
			getAnimatedProps o animated_props
			if animated_props.count > 0 then
			(
				for i =1 to  animated_props.count do
				(
					deleteKeys animated_props[i]
				)
			)
			popPrompt()
			if mTimeGetTime() - starttime > 1000 then
			(
				starttime = mTimeGetTime()
				redrawViews()
			)
		)
	)
)


fn onlyOneFrame =
(
	if (rendTimeType == 1 OR rendStart==rendEnd)then
		return true
	return false
)

-- GPU renderer are not valid for distributed rendering.
fn rendererValidForDistributedRendering =
(
	renderer_blocked_for_distributed = #(Redshift_Renderer, Iray, vrayrt)

	for renderer in renderer_blocked_for_distributed do
	(
		if classof renderers.production == renderer then
			return false
	)
	-- renderer is allowed for distributed rendering
	return true
)


fn isGpuRenderer =
(
	gpu_renderer = #(Redshift_Renderer, Iray, vrayrt)

	for renderer in gpu_renderer do
	(
		if classof renderers.production == renderer then
			return true
	)

	return false
)


fn enableDistributedRenderingCheckbox =
(
	if onlyOneFrame() and rendererValidForDistributedRendering() then
		return true
	else
		return false
)

-- this is for cost estimation. Only 5 or more frames are valid for cost estimation
fn renderFiveOrMoreFrames =
(
	if (rendEnd - rendStart >= 5) OR rendTimeType != 1 then
		return true
	else
		return false
)


fn enableCostEstimationButton =
(
	return renderFiveOrMoreFrames()
)


fn isSingleFrameRender =
(
	if (rendTimeType == 1 OR rendStart==rendEnd) AND dlg_main.isDistributedConfirmed then
		return true
	return false
)

fn isAdmin =
(
	wi = dotNetClass "System.Security.Principal.WindowsIdentity"
	id = wi.GetCurrent()
	p = dotNetObject "System.Security.Principal.WindowsPrincipal" id

	return (p.IsInRole "Administrators")
)

fn isUacEnabled =
(
	dotnet.loadassembly "mscorlib.dll"
	reg = dotNetClass "Microsoft.Win32.Registry"
	key = reg.LocalMachine.OpenSubKey "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System"

	if key == undefined then
		return false

	return ((key.GetValue "EnableLUA") == 1)
)

fn myFilenamefrompath p =
(
	return ((getFilenameFile p) + (getFilenameType p))
)

fn savefilenameFromPath p =
(
	local f = filenamefrompath p
	if f.count > 0 and (f[f.count] == "\\" or f[f.count] == "/") then
		f = substring f 1 (f.count-1)
	if f.count == 0 then
		f = "out.png"
	if getFilenameType f == "" then
		f = f + ".png"
	return f
)

fn removeTrailingDigits f =
(
	return trimRight f "0123456789"
)

fn isVrayIrrMulti =
(
	local rend = renderers.production
	local result = false
	try
	(
		if classof renderers.production == vray or classof renderers.production == vrayrt then
		(
			if classof renderers.production == vrayrt then
				rend = rend.V_Ray_settings
			result = true
			result = result and rend.gi_on
			result = result and (rend.gi_primary_type == 0)
			result = result and (rend.adv_irradmap_mode == 1)
		)
	)
	catch()
	return result
)

global TR_STRINGS		=#()
global TR_LANGUAGE	= "en"
global TR_ISINITED		= false


ONLINE_FAQ = 10101
global goToOnlineFaq
fn	goToOnlineFaq resultId =
( 
	 
)

fn getInteger64String i =
(
	local st = i as string
	try
	(
		if st[st.count] == "L" then
			st = substring st 1 (st.count-1)
	)
	catch()
	return st
)

struct texElem
(
	obj,
	property,
	filename
);

fn appendTexelem vecTex ob prop fin =
(
	t = texElem()
	t.obj=ob
	t.property=prop
	t.filename=fin
	append vecTex t
)

fn isTexElemInVec vecTex filepath =
(
	for elem in vecTex do
	(
		if elem.filename == filepath then
		(
			return true
		)
	)
	return false
)

fn findMultiFiles filename =
(
	local arr = #()
	local first = findString filename "<"
	local last = findString filename ">"
	local hash = findstring filename "#"
	if first != undefined and last != undefined then
	(
		local p = substring filename 1 (first-1)
		p += "*"
		p += substring filename (last+1) -1
	)

	if hash != undefined then
	(
		p = replaceAll filename "#" "*"
	)

	arr = getFiles p

	return arr
)

fn findExternalFiles objClass property vecTex callback:undefined=
(
	try
	(
		if objClass == undefined then return 0

		local objs = #()
		try(objs = getClassInstances objClass) --if it is a class then use it
		catch(append objs objClass) -- if not try if is a pure object
		for obj in objs do
		(
			if classof property == Array then
			(
				local subobj = obj
				try
				(
					for subProperty in property do
					(
						if subobj != undefined and hasProperty subobj subProperty then
							subobj = getProperty subobj subProperty
					)
					if subobj != undefined and subobj != "" then
					(
						if findString subobj "<" != undefined then
						(
							local arr = findMultiFiles subobj
							if arr.count > 0 then
							(
								for a in arr do
									appendTexelem vecTex obj property a
							)
							else
								appendTexelem vecTex obj property subobj
						)
						else
							appendTexelem vecTex obj property subobj

						if callback != undefined then
							callback vecTex[vecTex.count]
					)
				)
				catch
				(
					format "***2 % ***\n" (getCurrentException())
				)
			)
			else if classof obj == FumeFX then
			(
					-- FUMEFX special - as there is no property - only a method which is called with the FumeFX object
					-- when changing the path in the maxfile we need to use SetPath to change the attribute

				fumeFx_path_types = #("default", "wavelet", "retimer","illummap", "preview", "defaultpreset", "srcsim")

				for path_type in fumeFx_path_types do
				(
					filepath = obj.GetPath path_type ---path is always saved with filename but WITHOUT extension

					if filepath != "" and filepath != undefined then
					(
						appendTexelem vecTex obj path_type filepath  -- writing pathtype as property, to have those as SetPath Param when writing to vecFiles
					)

				)

			)
			else
			(
				if hasProperty obj property then
				(
					local fp = getProperty obj property
					if fp != undefined and fp != "" then
					(
						if findString fp "<" != undefined or findString fp "#" != undefined then
						(
							local arr = findMultiFiles fp
							if arr.count > 0 then
							(
								for a in arr do
									appendTexelem vecTex obj property a
							)
							else
								appendTexelem vecTex obj property fp
						)
						else
							appendTexelem vecTex obj property fp
						if callback != undefined then
							callback vecTex[vecTex.count]
					)
				)
			)
		)
	)
	catch
	(
		format "*** % ***\n" (getCurrentException())
	)
)



fn changeLastChar p =
(
	local ext = getFilenameType p
	local file = getFilenameFile p
	local fpath = getFilenamePath p
	return fpath + file + "_" + ext
)



fn setAllRegionRect b2 =
(
	for i=1 to 16 do
	(
		try(viewport.setRegionRect i b2)catch()
	)
)



fn parsePhoenixPath obj p =
(
	-- FIXME: Magic Number 10 --- Woher kommt die?
	for i=0 to 10 do
	(
		p = replaceAll p "$(implicit)" "$(dir)\$(scene)_Phoenix_frames\ND$(handle)_$(nodename)"
		p = replaceAll p "$(dir)" maxFilePath
		p = replaceAll p "$(scene)" maxFileName
		p = replaceAll p "$(handle)" "*"
		p = replaceAll p "$(nodename)" "*"
		p = replaceAll p "$(simoutput)" obj.simoutput
	)
	return p
)



fn getVrayVersion =
(
	vrversion = filterString (vray as string) "_"
	local high = vrversion[vrversion.count-2] as integer
	if high == undefined then high = 0
	local mid = vrversion[vrversion.count-1] as integer
	if mid == undefined then mid = 0
	local low = vrversion[vrversion.count] as integer
	if low == undefined then low = 0

	if high == 0 then
	(
		local versionString = vrayVersion()
		local version = filterString (versionString[1]) "."
		high = version[1] as integer
		mid = version[2] as integer
		low = version[3] as integer
	)

	return high*100*100 + mid*100 + low
)

fn getCoronaIntVersion =
(
	try
	(
		-- deprecated, use getVersionString instead
		local ver = CoronaRenderer.CoronaFp.getCoronaVersion()
		-- if ver[0] == 6 then 
		-- 	return 6
		
		local allowedchars = "0123456789."
		for i=1 to ver.count do
		(
			if findstring allowedchars ver[i] == undefined then
			(
				ver = substring ver 1 (i-1)
				exit
			)
		)
		ver = filterstring ver "."
		local version = (ver[1] as integer) * 10000
		if ver.count > 1 then
			version = version + (ver[2] as integer) * 100
		if ver.count > 2 then
			version = version + (ver[3] as integer)
		return version
	)
	catch
	(
		return 0
	)
)

fn getClassInstancesSave type =
(
	if type == undefined then
		return #()

	try
	(
		local inst = getClassInstances type
		return inst
	)
	catch()

	return #()
)

fn isProgressiveRendering =
(
	local progressive = false
	local rend = renderers.production
	try
	(
		if classof rend == CoronaRenderer then
		(
			if CoronaRenderer.CoronaFp.getVersionMajorNumber() > 6 then
				progressive = rend.shading_renderEngine == 1
			else
				progressive = rend.shading_renderEngine == 2
		)
		else if classof rend == vray then
			progressive = rend.imageSampler_type == 3
		else if classof rend == vrayrt then
			progressive = rend.V_Ray_settings.imageSampler_type == 3
		else if classof rend == mental_ray_iray_Renderer then
			progressive = true
	)catch()
	return progressive
)

fn findOverstructSphereObjects =
(
	local arr = #()
	for o in $* do
	(
		if getuserprop o "vpt_sphere" != undefined then
		(
			append arr o
		)
	)
	return arr
)


fn getSceneInfo =
(
	shadercounts = #()
	try
	(
		for shaderType in textureMap.classes do
		(
			try
			(
				cl = getClassInstances shaderType
				if cl.count > 0 then
					append shadercounts #(shaderType, cl.count)
			)catch()
		)
	)catch()

	try
	(
 
		local overstructSpheres = findOverstructSphereObjects()
		if overstructSpheres.count > 0 then
		(
			if (renderWidth == 2700 or renderWidth == 2*2700) and renderHeight == 1350 and classof renderers.production == vray then
			(
				append shadercounts #("OverstructIntersections", overstructSpheres.count)
			)
		)
	)
	catch()

	info = "{\"c4dshd\":{ "
	for sh in shadercounts do
	(
		info += "\"" + (sh[1] as string) + "\":" + (sh[2] as string) + ","
	)
	info = substring info 1 (info.count-1)
	info +="}}"
	return info
)


fn skyKeyShortcut =
(
	try
	(
		local kdb = actionMan.getKeyboardFile()
		if (getFileSize kdb == 0) then
			actionMan.saveKeyboardFile kdb

		dotNet.loadAssembly "system.xml"
		local assets = #()
		local xmldoc = dotnetobject "System.XML.XMLDocument"
		xmldoc.load kdb

		local itemIter = (xmldoc.selectnodes "//ADSK_KBD/shortcut[@fVirt='11' and @accleleratorKey='70' and @actionTableID='647394']").GetEnumerator()
		if itemIter.MoveNext() then
		(
			-- print ("Strg+F already found: " + itemIter.Current.GetAttribute("actionID"))
		)
		else
		(
			local newNode = xmldoc.CreateElement "shortcut"
			newNode.SetAttribute "fVirt" "11"
			newNode.SetAttribute "accleleratorKey" "70"
			newNode.SetAttribute "actionID" "SkySetup`FarmRender"
			newNode.SetAttribute "actionTableID" "647394"
			xmldoc.DocumentElement.AppendChild newNode
			xmldoc.save kdb
			actionMan.loadKeyboardFile (kdb)
		)
	)
	catch
	(
		print "can't set keyboard shortcut"
		print kdb
	)
)

struct ValGeneral
(
	CLOSE_RENDER_DIALOG = 1,
	XREF_SCENE = 2,
	XREF_OBJECT = 3,
	MOVIE_TEX = 4,
	UPDATE_MAX = 5,
	PATH_X = 6,
	UNSUPPORTED_LAYOUT = 7,
	SOLID_ROCKS = 8,

	oldviewportRenderLevel = viewport.getrenderlevel(),
	oldviewportLayout = viewport.getLayout(),
	old_active_viewport = viewport.activeViewport,
	oldShowRenderedFrameWindow = false,

	realflowPaths = #(),
	realflowParticlePaths = #(),
	realflowEditableMeshPaths = #(),

	oldAbcgeomPaths = #(),
	oldAbcmodPaths = #(),

	oldXMeshLoaderRenderPaths = #(),
	oldXMeshLoaderProxyPaths = #(),

	oldProxSiPaths = #(),
	oldVPOmnitilesPaths = #(),

	oldAnimaPaths = #(),

	solidRocksConfirmed = -1,

	is_renderer_validator = false,

	fn getName name:"" =
	(
		name = "General";
	),
	fn getIdentifier =
	(
		return #()
	),

	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;
		cam = getActiveCamera()

		if (maxversion())[1] < 16000 then
			append resultList (tr id:3034 index:index validator:val severity:2 message:"need to use last 3ds max 2014 the Render Farm Application")

		setinisetting (getmaxinifile()) "Performance" "WriteCompressed" "1"
		setinisetting (getmaxinifile()) "Performance" "SaveFileProperties" "1"
		setinisetting (getmaxinifile()) "File Language Options" "LegacyFilesCanBeStoredUsingUTF8" "1"

		local compressed = getinisetting (getmaxinifile()) "Performance" "WriteCompressed"
		if  compressed == "0" or compressed =="" then
			append resultList (tr id:3001 index:index validator:val severity:2 message:"Please activate the \"Compress on Save\" option in \"Customize -> Preferences -> Files\"")

		local saveProperties = getinisetting (getmaxinifile()) "Performance" "SaveFileProperties"
		if  saveProperties == "0" then
			append resultList (tr id:3002 index:index validator:val severity:2 message:"Please activate the \"Save File Properties\" option in \"Customize -> Preferences -> Files\"")

		local saveLegacy = getinisetting (getmaxinifile()) "File Language Options" "LegacyFilesCanBeStoredUsingUTF8"
		if saveLegacy == "0" or saveLegacy == "" then
			append resultList (tr id:3035 index:index validator:val severity:2 message:"Please activate the \"Save Strings in legacy non-scene files using UTF8\" option in \"Customize -> Preferences -> Files\"")

	 
		 
		-- rendering fails if any of the viewports are trackviews or other non 3d views
		if not (dlg_main.isVrsceneExport or dlg_main.isMiExport) then
		(
			oldviewportLayout = viewport.getLayout()
			viewport.setLayout #layout_4
			old_active_viewport_type = viewport.getType()
			old_render_level = viewport.GetRenderLevel()

			if viewport.numViews < 4 then
				append resultList (tr id:3007 index:index validator:val severity:2 message:"Viewport Layout not supported" flagMoreInfos:true type:ONLINE_FAQ)
			viewport.setLayout oldviewportLayout
			viewport.setType old_active_viewport_type
			viewport.SetRenderLevel old_render_level
		)

		rend = renderers.production
		--if renderSceneDialog.isOpen() then
		--	append resultList (tr id:3008 index:index validator:val severity:2 message:"Please close the Render Scene Dialog and restart the Test" flagMoreInfos:true type:CLOSE_RENDER_DIALOG)

		renderSceneDialog.commit()

		local b = false
		local b2 = false

		if classof rend == MaxwellRenderer then b2=true
		if classof rend == mental_ray_renderer then b2=true
		if classof rend == mental_ray_iray_Renderer then b2=true
		if classof rend == Quicksilver_Hardware_Renderer then b2=true
		if classof rend == finalRender_stage_1 then b2=true
		if classof rend == vray then b2=true
		if classof rend == vrayrt then b2=true
		if classof rend == Brazil_r_s_Rio_Learning_Edition_v2_0__build_1618 then b2=true
		if classof rend == Default_Scanline_Renderer then b2=true
		if classof rend == CoronaRenderer then b2=true
		if (stricmp (classof rend as string) "Octane_Render") != 0 then b2=true
		if classof rend == A360_Cloud_Rendering then b2=true
		if classof rend == ART_Renderer then b2=true
		if classof rend == Iray then b2=true
		if classof rend == Redshift_Renderer then b2=true
		if classof rend == cycles_Renderer then b2=true
		if classof rend == FStormRender then b2 = true
		if classof rend == Arnold then b2=true

		if b2==false then
		(
			append resultList (tr id:3018 index:index validator:val severity:2 message:("Selected Renderer \""+(rend as string)+"\" is not supported"))
		)
		if getrendertype() != #view AND getrendertype() != #normal then
			append resultList (tr id:3019 index:index validator:val severity:1 message:("Render Type: "+getrendertype() as string + " Render active") flagMoreInfos:true type:ONLINE_FAQ)
 
		if hasMovieTextures() then
			append resultList (tr id:3020 index:index validator:val severity:2 message:"Movie file textures found" flagMoreInfos:true type:ONLINE_FAQ)

		if hasQuicktimeTextures() then
			append resultList (tr id:3021 index:index validator:val severity:2 message:"Due to technical limitations .mov textures are not allowed")
 
		if lights.count == 0 and
			not classof rend == MaxwellRenderer and
			not classof rend == mental_ray_iray_Renderer  and
			not classof rend == Iray  and
			not classof rend == Redshift_Renderer  and
			not classof rend == cycles_Renderer  and
			not classof rend == FStormRender and
			not (classof rend == vray and (rend.options_defaultLights==2 or rend.options_defaultLights==0)) and
			not classof rend == CoronaRenderer and not (classof rend == Octane_Render or classof rend == Octane_Render_Demo) then
			append resultList(tr id:3025 index:index validator:val severity:2 message:"No lights in scene - default light not supported." flagMoreInfos:true type:ONLINE_FAQ)

		local rfParticles = getClassInstancesSave ParticleLoader
		if rfParticles.count > 0 then
		(
			if not hasProperty rfParticles[1] "binPath" then
				append resultList(tr id:3026 index:index validator:val severity:2 message:"RealFlow: You need at least version 5.0.4, please update")
		)
 
		local exeVers = getExeVersion()
		local versions = filterString exeVers "."
		if versions != undefined then
		(
			if versions.count == 4 then
			(
				if versions[1] == "9" then
					if versions[2] as integer < 2 then
						append resultList(tr id:3027 index:index validator:val severity:2 message:"Please download the latest Service Packs and Hotfixes for your Max." flagMoreInfos:true type:ONLINE_FAQ)
				if versions[1] == "11" then
					if versions[2] as integer < 1 then
						append resultList(tr id:3028 index:index validator:val severity:2 message:"Please download the latest Service Packs and Hotfixes for your Max." flagMoreInfos:true type:ONLINE_FAQ)
				if versions[1] == "12" then
					if versions[2] as integer < 1 then
						append resultList(tr id:3029 index:index validator:val severity:2 message:"Please download the latest Service Packs and Hotfixes for your Max." flagMoreInfos:true type:ONLINE_FAQ)
				if versions[1] == "14" then
					if versions[2] as integer == 0 and versions[3] as integer < 1 then
						append resultList(tr id:3030 index:index validator:val severity:2 message:"Please download the latest Service Packs and Hotfixes for your Max." flagMoreInfos:true type:ONLINE_FAQ)
			)
		)

		local networkError = false
		if (maxVersion())[1] < 10000 and pathConfig.resolveUNC == true then
			networkError = true
		if (maxVersion())[1] >= 10000 and pathIsNetworkPath "X:\\" and pathConfig.resolveUNC == true then
			networkError = true
		if networkError then
			pathConfig.resolveUNC = false


--realflow files
		realflowPaths = #()
		realflowParticlePaths = #()
		try
		(
			local rfMeshes = getClassInstancesSave RFMeshLoader
			for rfMesh in rfMeshes do
			(
				local prefix = rfMesh.prefix
				if prefix == undefined then
					continue
				if findString prefix ".bin" == prefix.count - 3 then
					prefix = substring prefix 1 (prefix.count-4)

				local rfPath = rfMesh.path + prefix

				local bFound = false
				for f in realflowPaths do
				(
					if (filenameFromPath f) == prefix and f != rfPath then
					(
						append resultList(tr id:3032 index:index validator:val severity:2 message:("Realflow object with same name and different path is already in your scene "+f))
						bFound = true
						break
					)
				)
				print rfPath
				if not bFound then
					append realflowPaths rfPath

				local files = getFiles ((pathConfig.appendPath rfMesh.path prefix) + "*")
				if files.count == 0 then
					append resultList(tr id:3032 index:index validator:val severity:2 message:("No realflow files found in  "+(pathConfig.appendPath rfMesh.path prefix)))
			)

			local rfParticles = getClassInstancesSave ParticleLoader
			for rfParticle in rfParticles do
			(
				local prefix = rfParticle.binPrefix
				if prefix == undefined then
					continue
				if findString prefix ".bin" == prefix.count - 3 then
					prefix = substring prefix 1 (prefix.count-4)

				local rfPath = rfParticle.binPath + prefix

				local bFound = false
				for f in realflowParticlePaths do
				(
					if (filenameFromPath f) == prefix and f != rfPath then
					(
						append resultList(tr id:3032 index:index validator:val severity:2 message:("Realflow object with same name and different path is already in your scene "+f))
						bFound = true
						break
					)
				)
				if not bFound then
					append realflowParticlePaths rfPath

				local files = getFiles ((pathConfig.appendPath rfParticle.binPath prefix) + "*")
				if files.count == 0 then
					append resultList(tr id:3032 index:index validator:val severity:2 message:("No realflow files found in  "+(pathConfig.appendPath rfParticle.binPath prefix)))

			)

		)
		catch
		(
			--	format "val_general.ms: realflow *** % ***\n" (getCurrentException())
		)

--alembic files
		try
		(
			local abcGeoms = getClassInstancesSave abcgeom
			for geo in abcGeoms do
			(
				local f = geo.filename
				if not existsFile f then
					append resultList(tr id:3036 index:index validator:val severity:2 message:("abcgeom File not found: "+f))
			)

			local abcMods = getClassInstancesSave abcmod
			for m in abcMods do
			(
				local f = m.filename
				if not existsFile f then
					append resultList(tr id:3037 index:index validator:val severity:2 message:("abcmod File not found: "+f))
			)
		)
		catch
		(
			--	format "val_general.ms: alembic *** % ***\n" (getCurrentException())
		)

		try
		(
			local abcGeoms = getClassInstancesSave AlembicObject
			for geo in abcGeoms do
			(
				local f = geo.source
				if not existsFile f then
					append resultList(tr id:3036 index:index validator:val severity:2 message:("AlembicObject File not found: "+f))
			)
		)
		catch
		(
				format "val_general.ms: AlembicObject *** % ***\n" (getCurrentException())
		)

		try
		(
			local meshLoader = getClassInstancesSave XMeshLoader
			for geo in meshLoader do
			(
				local rFile = geo.renderSequence
				if rFile == undefined then
					rFile = ""
				rPrefix = (removeTrailingDigits (getFilenameFile rFile))
				local pFile = geo.proxySequence
				if pFile == undefined then
					pFile = ""
				pPrefix = (removeTrailingDigits (getFilenameFile pFile))
				if rPrefix == "" and pPrefix == "" then
					append resultList(tr id:3036 index:index validator:val severity:2 message:("XMeshLoader File paths empty"))
				else
				(
					local files = #()
					if rPrefix != "" then
						files += getFiles ((getFilenamePath rFile) + rPrefix + "*")
					if pPrefix != "" then
						files = getFiles((getFilenamePath pFile) + pPrefix + "*")
					if files.count == 0 then
						append resultList(tr id:3036 index:index validator:val severity:2 message:("XMeshLoader no files found: render:\""+rFile + "\" proxy:\"" + pFile + "\""))
				)
			)
		)
		catch
		(
				format "val_general.ms: XMeshLoader *** % ***\n" (getCurrentException())
		)

--SolidRocks
		if classof renderers.production == vray or classof renderers.production == vrayrt then
		(
			if SRversion != undefined then
			(
				if SRversion < 161 then
					append resultList(tr id:3038 index:index validator:val severity:2 message:"Incompatible SolidRocks version. You need v.1.6.1 or higher.")
				else
				(
					try
					(
						if SRmainpanel.indialog then
							SRApplySettings true
					)
					catch()
				)
			)
			else
			(
				local srpath = pathConfig.appendPath (pathConfig.appendPath (getDir #maxRoot) "MacroScripts") "SolidRocks.mse"
				if existsFile srpath then
				(
					if solidRocksConfirmed == 1 then
						append resultList(tr id:3038 index:index validator:val severity:2 message:"Incompatible SolidRocks version. You need v.1.6.1 or higher." flagMoreInfos:true type:SOLID_ROCKS)
					else if solidRocksConfirmed == -1 then
						append resultList(tr id:3038 index:index validator:val severity:2 message:"Are you using SolidRocks?"  flagMoreInfos:true type:SOLID_ROCKS)
				)
			)
		)

--anima2 files
		try
		(
			if anima2scene != undefined or animascene != undefined or animaProject != undefined then
			(
				local anima = getClassInstancesSave anima2scene
				if anima.count == 0 then
					anima = getClassInstancesSave animascene
				if anima.count == 0 then
					anima = getClassInstancesSave animaProject
				for a in anima do
				(
					local f = ""
					try(f=a.anima2projectpath)catch()
					try(f=a.animaprojectpath)catch()
					if not existsFile f then
						append resultList(tr id:3036 index:index validator:val severity:2 message:("anima File not found: "+f))
				)
			)
		)
		catch
		(
			--	format "val_general.ms: alembic *** % ***\n" (getCurrentException())
		)

--ProxSi files
		try
		(
			local prox = getClassInstancesSave ProxSi
			for a in prox do
			(
				if a.Path != undefined and a.Path != "" then
				(
					local f = a.Path
					if not existsFile f then
						append resultList(tr id:3036 index:index validator:val severity:2 message:("ProxSi File not found: "+f))
				)
			)
		)
		catch
		(
			format "val_general.ms: ProxSi *** % ***\n" (getCurrentException())
		)

		try
		(
			local pops = getClassInstancesSave PopSkinObject
			if pops.count > 0 and isSingleFrameRender() then
				append resultList(tr id:3036 index:index validator:val severity:2 message:("Populate persons not supported with distributed rendering, please bake these objects."))
		)
		catch
		(
			format "val_general.ms: populate *** % ***\n" (getCurrentException())
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValVRay!"
		case result.type of
		(
			UAC_NO_ADMIN:
			(
				st = "Please try either running 3ds Max as administrator (right-click on 3dsmax.exe -> \"Run as administrator\") or disable User Access Control (UAC) (requires reboot)."
				messagebox st title:"Render Farm Application"
			)
		XREF_SCENE:
			(
				st = "Render Farm Application  can not validate the xref file for correctness.
it is strongly recommended to collapse the Xref file into the scene before export"
				messagebox st title:" Render Farm Application"
			)
		XREF_OBJECT:
			(
				st = "Render Farm Application can not validate the xref file for correctness.
it is strongly recommended to collaps the Xref file into the scene before export"
				messagebox st title:"Render Farm Application"
			)
		MOVIE_TEX:
			(
				st="If movie file codec is not supported on Render Farm Application the texture can not be rendered and appears in diffuse color only
to avoid problems please use image sequences instead";
				messagebox st title:"Render Farm Application"
			)
		PATH_X:
			(
				st="There is a compatibility problem between 3dsMax and Render Farm Application. So it is not possible to export a project if you have the letter \"X\" assigned to a network-Drive. This should be fixed in a future release, for now please unmount the Drive X:\\";
				messagebox st title:"Render Farm Application"
			)
		UNSUPPORTED_LAYOUT:
			(
				st="Your viewport Layout is not supported, please open the \"Viewport Configuration...\" from the \"Views\"-Menu\r\n
From the \"Layout\"-Tab change all Viewports to \"perspective\" for Example";
				messagebox st title:"Render Farm Application"
			)
		ONLINE_FAQ:
			(
				goToOnlineFaq result.id
			)
		SOLID_ROCKS:
			(
				if querybox "Do you use SolidRocks in your scene?" title:"Render Farm Application" then
				(
					solidRocksConfirmed = 1
					goToOnlineFaq result.id
				)
				else
				(
					solidRocksConfirmed = 0
					dlg_main.btnStart.pressed()
				)
				resolved = true
			)
		)
		case result.type of
		(
			UPDATE_MAX:
			(
				ShellLaunch "http://usa.autodesk.com/adsk/servlet/ps/dl/index?siteID=123112&id=2334435&linkID=9241178" ""
			)
		)
		case result.type of
		(
			CLOSE_RENDER_DIALOG:
			(
				renderSceneDialog.close()
				resolved = true
			)
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		makeDir (pathConfig.appendPath fPath "tex") all:true
		oldviewportRenderLevel = viewport.getrenderlevel()
		oldShowRenderedFrameWindow = rendShowVFB

		viewport.setrenderlevel #box
		rendShowVFB = true

		for i = 1 to xrefs.getXRefFileCount() do
		(
			local x = (xrefs.getXRefFile i)
			local st = mapPaths.getFullFilePath x.filename
			local stNew = pathConfig.appendPath "tex" (filenameFromPath st)

			appendFileInfo &vecFiles st ("tex/" + (filenameFromPath stNew))
		)
		for i = 1 to objXRefs.getNumfiles() do
		(
			local x = (objXRefs.getFileName i)
			local st = mapPaths.getFullFilePath x
			local stNew = pathConfig.appendPath "tex" (filenameFromPath st)
			appendFileInfo &vecFiles st ("tex/" + (filenameFromPath stNew))
		)


--realflow files
		realflowPaths = #()
		realflowParticlePaths = #()
		realflowEditableMeshPaths = #()
		try
		(
			local rfMeshes = getClassInstancesSave RFMeshLoader
			for rfMesh in rfMeshes do
			(
				local prefix = rfMesh.prefix
				if prefix == undefined then
					continue
				if findString prefix ".bin" == prefix.count - 3 then
					prefix = substring prefix 1 (prefix.count-4)

				local files = getFiles ((pathConfig.appendPath rfMesh.path prefix) + "*")
				for f in files do
				(
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
				)
				append realflowPaths rfMesh.path
				rfMesh.path = createTexPath dlg_main.m_userName ""
			)

			local rfParticles = getClassInstancesSave ParticleLoader
			for rfParticle in rfParticles do
			(
				local prefix = rfParticle.binPrefix
				if prefix == undefined then
					continue
				if findString prefix ".bin" == prefix.count - 3 then
					prefix = substring prefix 1 (prefix.count-4)

				local files = getFiles ((pathConfig.appendPath rfParticle.binPath prefix) + "*")
				for f in files do
				(
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
				)
				append realflowParticlePaths rfParticle.binPath
				rfParticle.binPath = createTexPath dlg_main.m_userName ""
			)

			local rfEditableMeshPaths = getClassInstancesSave RFSoftBody
			for rfMesh in rfEditableMeshPaths do
			(
				if hasProperty rfMesh "SD_Filename" then
				(
					if existsFile rfMesh.SD_Filename then
					(
						local f = rfMesh.SD_Filename

						appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))

						append realflowEditableMeshPaths rfMesh.SD_Filename
						rfMesh.SD_Filename = createTexPath dlg_main.m_userName (filenameFromPath f)
					)
				)
			)
		)
		catch
		(
			--	format "val_general.ms: realflow *** % ***\n" (getCurrentException())
		)

--alembic files
		oldAbcgeomPaths = #()
		oldAbcmodPaths = #()
		try
		(
			local abcGeoms = getClassInstancesSave abcgeom
			for geo in abcGeoms do
			(
				local f = geo.filename
				if existsFile f then
				(
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
					append oldAbcgeomPaths f
					geo.filename = createTexPath dlg_main.m_userName (filenameFromPath f)
				)

			)

			local abcMods = getClassInstancesSave abcmod
			for m in abcMods do
			(
				local f = m.filename
				if existsFile f then
				(
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
					append oldAbcmodPaths f
					m.filename = createTexPath dlg_main.m_userName (filenameFromPath f)
				)
			)
		)
		catch
		(
			--	format "val_general.ms: disk_cache *** % ***\n" (getCurrentException())
		)

		try
		(
			local abcGeoms = getClassInstancesSave AlembicObject
			for geo in abcGeoms do
			(
				local f = geo.source
				if existsFile f then
				(
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
					append oldAbcgeomPaths f
					geo.source = createTexPath dlg_main.m_userName (filenameFromPath f)
				)
			)
		)
		catch
		(
				format "val_general.ms: AlembicObject *** % ***\n" (getCurrentException())
		)

		oldXMeshLoaderRenderPaths = #()
		oldXMeshLoaderProxyPaths = #()
		try
		(
			local meshLoader = getClassInstancesSave XMeshLoader
			for geo in meshLoader do
			(
				local rFile = geo.renderSequence
				if rFile == undefined then rFile = ""
				local pFile = geo.proxySequence
				if pFile == undefined then pFile = ""
				local files = #()
				if rFile != "" then
					files += getFiles ((getFilenamePath rFile) + (removeTrailingDigits (getFilenameFile rFile)) + "*")
				if pFile != "" then
					files += getFiles ((getFilenamePath pFile) + (removeTrailingDigits (getFilenameFile pFile)) + "*")
				for f in files do
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))

				append oldXMeshLoaderRenderPaths rFile
				geo.renderSequence = createTexPath dlg_main.m_userName (filenameFromPath rFile)
				append oldXMeshLoaderProxyPaths pFile
				geo.proxySequence = createTexPath dlg_main.m_userName (filenameFromPath pFile)
			)
		)
		catch
		(
				format "val_general.ms: XMeshLoader *** % ***\n" (getCurrentException())
		)
 
		try
		(
			if anima2scene != undefined or animascene != undefined or animaProject != undefined then
			(
				local anima = getClassInstancesSave anima2scene
				if anima.count == 0 then
					anima = getClassInstancesSave animascene
				if anima.count == 0 then
					anima = getClassInstancesSave animaProject
				for a in anima do
				(
					local f = ""
					try(f=a.anima2projectpath)catch()
					try(f=a.animaprojectpath)catch()

					local aniname = getFilenameFile f

					local pack_file_local_path = pathConfig.appendPath fPath (pathConfig.appendPath "tex" (aniname + ".anipack"))
					local pack_file_remote_path = "tex/" + (aniname + ".anipack")

					anima_project_name = a.projectname
					append oldAnimaPaths a.animaprojectpath 
					a.saveanipack = pack_file_local_path
					if not doesFileExist pack_file_local_path then (
						a.saveanipacknobake = pack_file_local_path 
					)
					 
					local renderanipath = createPath dlg_main.m_userName (aniname + "\\" + aniname + ".anipro")
				 
					a.projectname = anima_project_name

					appendFileInfo &vecFiles pack_file_local_path pack_file_remote_path toCopy:false
				)
			)
		)
		catch
		(
			format "val_general.ms: anima *** % ***\n" (getCurrentExceptionStackTrace())
		)

--ProxSi files
		try
		(
			oldProxSiPaths = #()
			local prox = getClassInstancesSave ProxSi
			for a in prox do
			(
				if a.Path != undefined and a.Path != "" then
				(
					appendFileInfo &vecFiles a.Path ("tex/" + (filenameFromPath a.Path))
					append oldProxSiPaths a.Path
					a.Path = createTexPath dlg_main.m_userName (filenameFromPath a.Path)
				)
			)
		)
		catch()

--VP_Omnitiles files
		try
		(
			oldVPOmnitilesPaths = #()
			local prox = getClassInstancesSave VP_Omnitiles
			for a in prox do
			(
				if a.Description_file != undefined and a.Description_file != "" then
				(
					append oldVPOmnitilesPaths a.Description_file
					a.Description_file = createTexPath dlg_main.m_userName (filenameFromPath a.Description_file)
				)
			)
		)
		catch()
	),
	fn postSave zip =
	(
		viewport.setrenderlevel oldviewportRenderLevel
		rendShowVFB = oldShowRenderedFrameWindow

--reset realflow files
		try
		(
			local rfMeshes = getClassInstancesSave RFMeshLoader
			local i=0
			for rfMesh in rfMeshes do
			(
				i=i+1
				rfMesh.path = realflowPaths[i]
			)
		)
		catch
		(
			--	format "val_general.ms: realflow *** % ***\n" (getCurrentException())
		)

		try
		(
			local rfParticleMeshes = getClassInstancesSave ParticleLoader
			local i=0
			for rfParticleMesh in rfParticleMeshes do
			(
				i=i+1
				rfParticleMesh.binPath = realflowParticlePaths[i]
			)
		)
		catch
		(
			--	format "val_general.ms: realflow *** % ***\n" (getCurrentException())
		)

		try
		(
			local rfEditableMeshPaths = getClassInstancesSave RFSoftBody
			local i=0
			for rfMesh in rfEditableMeshPaths do
			(
				if hasProperty rfMesh "SD_Filename" then
				(
					i=i+1
					rfMesh.SD_Filename = realflowEditableMeshPaths[i]
				)
			)
		)
		catch
		(
			--	format "val_general.ms: realflow *** % ***\n" (getCurrentException())
		)

--reset alembic files
		try
		(
			local abcGeoms = getClassInstancesSave abcgeom
			local i=0
			for geom in abcGeoms do
			(
				i=i+1
				geom.filename = oldAbcgeomPaths[i]
			)
			local abcMods = getClassInstancesSave abcmod
			local i=0
			for m in abcMods do
			(
				i=i+1
				m.filename = oldAbcmodPaths[i]
			)
		)
		catch
		(
			--	format "val_general.ms: realflow *** % ***\n" (getCurrentException())
		)

		try
		(
			local abcGeoms = getClassInstancesSave AlembicObject
			local i=0
			for geo in abcGeoms do
			(
				i=i+1
				geo.source = oldAbcgeomPaths[i]
			)
		)
		catch
		(
				format "val_general.ms: AlembicObject *** % ***\n" (getCurrentException())
		)

		try
		(
			local meshLoader = getClassInstancesSave XMeshLoader
			local i=0
			for geo in meshLoader do
			(
				i=i+1
				geo.renderSequence = oldXMeshLoaderRenderPaths[i]
				geo.proxySequence = oldXMeshLoaderProxyPaths[i]
			)
		)
		catch
		(
				format "val_general.ms: XMeshLoader *** % ***\n" (getCurrentException())
		)

--ProxSi files
		try
		(
			local prox = getClassInstancesSave ProxSi
			local i=0
			for a in prox do
			(
				if a.Path != undefined and a.Path != "" then
				(
					i=i+1
					print ("reset " + a.Path + " to " +oldProxSiPaths[i])
					a.Path = oldProxSiPaths[i]
				)
			)
		)
		catch()

--ProxSi files
		try
		(
			local prox = getClassInstancesSave VP_Omnitiles
			local i=0
			for a in prox do
			(
				if a.Description_file != undefined and a.Description_file != "" then
				(
					i=i+1
					print ("reset " + a.Description_file + " to " +oldVPOmnitilesPaths[i])
					a.Description_file = oldVPOmnitilesPaths[i]
				)
			)
		)
		catch()

		try
		(
			if anima2scene != undefined or animascene != undefined or animaProject != undefined then
			(
				local anima = getClassInstancesSave anima2scene
				if anima.count == 0 then
					anima = getClassInstancesSave animascene
				if anima.count == 0 then
					anima = getClassInstancesSave animaProject
				local i=0
				for a in anima do
				(
					i=i+1
					-- a.changeanipack = oldAnimaPaths[i]
				)
			)
		)
		catch()
	)
)

struct ValTexture
(
	REPLACE_ALL_MISSING = 2,
	DUPLICATE_TEX = 3,
	vecTex = #(),
	vecTexRetarget = #(),
	missingfiles = #(),

	texExcludes = #("uv_checker.png"),

	oldPcOptions = #(),

	ftpContentsSizes = #(),
	ftpContentsFiles = #(),

	pathNoCopy = #(),

	statfiles = #(),
	oldFilenames = #(),
	newFilenames = #(),

	vrIesValues = #(),
	cacheDiskPaths = #(),

	is_renderer_validator = false,

	fn cacheIesValues =
	(
		try
		(
			vrIesValues = #()
			local ies = getClassInstancesSave VRayIES
			for i in ies do
			(
				append vrIesValues i.power
			)
		)
		catch( )
	),

	fn resetIesValues =
	(
		try
		(
			local ies = getClassInstancesSave VRayIES
			local c=1
			for i in ies do
			(
				i.power = vrIesValues[c]
				c=c+1
			)
		)
		catch()
	),

	fn checkTextureType filename =
	(
		local ext = myToLower (getfilenametype filename)
		local retval = true
		jpgtypes = #(".jpg", ".jpeg", ".jpe", ".jif", ".jfif", ".jfi")

		dotnet.loadassembly "mscorlib.dll"
		dotFileStream = dotNetClass "System.IO.FileStream"
		dotFileMode = dotNetClass "System.IO.FileMode"
		dotFileAccess = dotNetClass "System.IO.FileAccess"
		dotSeekOrigin = dotNetClass "System.IO.SeekOrigin"
		try
		(
			if findItem jpgtypes ext != 0 then
			(
				fs = dotNetObject dotFileStream filename dotFileMode.Open dotFileAccess.ReadWrite
				if fs != undefined then
				(
					if fs.ReadByte() != 255 then	-- "\xff\d8
						retval = false
					if fs.ReadByte() != 216 then
						retval = false
					fs.Close()
				)
			)
			else if ext == ".png" then
			(
				fs = dotNetObject dotFileStream filename dotFileMode.Open dotFileAccess.ReadWrite
				if fs != undefined then
				(
					if fs.ReadByte() != 137 then  --"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a"
						retval = false
					if fs.ReadByte() != 80 then
						retval = false
					if fs.ReadByte() != 78 then
						retval = false
					if fs.ReadByte() != 71 then
						retval = false
					if fs.ReadByte() != 13 then
						retval = false
					if fs.ReadByte() != 10 then
						retval = false
					if fs.ReadByte() != 26 then
						retval = false
					if fs.ReadByte() != 10 then
						retval = false

					fs.Close()
				)
			)
			else if ext == ".gif" then
			(
				fs = dotNetObject dotFileStream filename dotFileMode.Open dotFileAccess.ReadWrite
				if fs != undefined then
				(
					if fs.ReadByte() != 71 then	--"GIF89a"
						retval = false
					if fs.ReadByte() != 73 then
						retval = false
					if fs.ReadByte() != 70 then
						retval = false
					if fs.ReadByte() != 56 then
						retval = false
					if fs.ReadByte() != 57 then
						retval = false
					if fs.ReadByte() != 97 then
						retval = false
					fs.Close()
				)
			)
			else if ext == ".bmp" then
			(
				fs = dotNetObject dotFileStream filename dotFileMode.Open dotFileAccess.ReadWrite
				if fs != undefined then
				(
					if fs.ReadByte() != 66 then	--"B"
						retval = false
					if fs.ReadByte() != 77 then
						retval = false
					fs.Close()
				)
			)
		)
		catch
		(
			print ("could not check file " + filename)
			format "checkTextureType *** % ***\n" (getCurrentException())
		)
		return retval
	),

	fn findAllTextures =
	(
		local vecTex = #()
		findExternalFiles Bitmaptexture "filename" vecTex callback:callbackFunction
		findExternalFiles abcgeom "filename" vecTex
		findExternalFiles abcmod "filename" vecTex

		findExternalFiles MXSRef "mxsFile" vecTex
		findExternalFiles MaxwellBitmap "FileName" vecTex
		findExternalFiles Maxwell_Material "IORFilename" vecTex

		findExternalFiles VRayIES "ies_file" vecTex
		findExternalFiles VRayBmpFilter "bitmapname" vecTex
		findExternalFiles VRayPhysicalCamera "lens_file" vecTex

		--findExternalFiles VRayLight #("texmap", "fileName")  vecTex --this is already in Bitmaptexture array
		findExternalFiles VRayStereoscopic "shademap_file" vecTex
		findExternalFiles VRayProxy "filename" vecTex
		findExternalFiles VRayHDRI "HDRIMapName" vecTex
		findExternalFiles VRayOSLTex "shader_file" vecTex

		findExternalFiles mr_Proxy "Filename" vecTex
		findExternalFiles GlaretextureMap "Streak_Image" vecTex
		findExternalFiles mental_ray_renderer "ShadowMapFilename" vecTex

		findExternalFiles SubstanceTexture "SubstanceFilename" vecTex
		findExternalFiles Point_CacheSpacewarpModifier "filename" vecTex
		findExternalFiles Point_Cache "filename" vecTex

		findExternalFiles RedshiftVolumeGrid "file" vecTex
		findExternalFiles IESLight "profile" vecTex

--this crashes Max 2018 in 	FStormRender_v1_2_2f, but it is not needed as the bitmap is in asset tracker
--		findExternalFiles FStormBitmap "fileName" vecTex
		findExternalFiles FStormIES "file" vecTex
		findExternalFiles FStormProxy "File" vecTex

		findExternalFiles CoronaBitmap "filename" vecTex
		findExternalFiles CProxy "filename" vecTex
		findExternalFiles CoronaLight "iesFile" vecTex

		findExternalFiles RGB_image "filename" vecTex

		findExternalFiles FumeFX "GetPath" vecTex -- ACHTUNG FumeFX hat keine Property. "GetPath" ist eine Funktion, welche aufgerufen werden muss

		for l in light.classes do	findExternalFiles l "webFile" vecTex

		findExternalFiles WAVsound "filename" vecTex

		findExternalFiles VRayPresenz "prz_detectFile" vecTex

		--can't find any other way to find dwg file paths (FileLinkMgr and any other stuff doesn't work)
		try
		(
			for i = 1 to AssetManager.GetNumAssets() do
			(
				local AUIO = AssetManager.GetAssetByIndex i
				if AUIO == undefined then
					continue
				local type = AUIO.getType()
				try
				(
					local filename = AUIO.getfilename()
					if type == #ExternalLink then
					(
						if myToLower (getFilenameType filename) == ".dwg" then
							appendTexelem vecTex undefined "" filename
					)
					else if getfilenametype (AUIO.getfilename()) == ".stat" then --stat files are only in asset tracker and can't be found anyway else
					(
						appendTexelem vecTex undefined "" filename
					)
				)
				catch()
			)
		)
		catch
		(
			format "texture.ms: find*** % ***\n" (getCurrentException())
		)

		try	--this should not be needed but as a workaround for now for safety reasons we get all the assets this way...
		(
			fileassets = getMAXFileAssetMetadata (maxFilePath + maxFileName)
			local ignoreFiles = #()
			try
			(
				--vray raw image file is flagged wrongly as input file in 2011
				local rend = renderers.production
				if classof renderers.production == vrayrt then
					rend = rend.V_Ray_settings
				if rend.output_rawFileName != undefined and rend.output_rawFileName != "" then
					append ignoreFiles rend.output_rawFileName
				if rend.output_splitFileName != undefined and rend.output_splitFileName != "" then
					append ignoreFiles rend.output_splitFileName
			)
			catch()

			try
			(
				--corona 1.7 adds the uhd cache as asset, it is set as inactive says ondra but i don't see a way to check this. So ignore it
				local rend = renderers.production
				if classof rend == coronarenderer then
				(
					append ignoreFiles rend.gi_uhdCache_file
				)
			)
			catch()

			for asset in fileassets do
			(
				local ext = getfilenametype asset.FileName
				local forceInput = false
				if findItem #(".vrmesh", ".cproxy") ext > 0 then
					forceInput = true
				if ((ATSOps.IsInputFile asset.FileName) or forceInput) and findItem ignoreFiles asset.FileName == 0 then
				(
					if not isTexElemInVec vecTex asset.FileName then
						appendTexelem vecTex undefined "_workaround_" asset.FileName
				)
			)
		)
		catch
		(
		--	format "texture.ms: disp*** % ***\n" (getCurrentException())
		)

		local xrefAssets = #()
		for i = 1 to xrefs.getXRefFileCount() do
		(
			local x = (xrefs.getXRefFile i)
			local xreffile = mapPaths.getFullFilePath x.filename
			try
			(
				getMaxFileAssets xreffile xrefAssets  fromXref:true
				appendTexelem vecTex undefined "" xreffile
				for asset in xrefAssets do
				(
					if asset != "" then
						appendTexelem vecTex undefined "" asset
				)
			)
			catch
			(
				format "val_texture.ms: Xref *** % ***\n" (getCurrentException())
			)

		)

		return vecTex
	),

	fn getName name:"" =
	(
		name = "Texture";
	),
	fn getIdentifier =
	(
		return #()
	),

	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

			if fastCheck then
				return true

			if (maxversion())[1] >= 12000 then -- vray environment files are not in asset tracker in max 2010
			(
				local env = useEnvironmentMap	--extremely weird bug in max: if a special hdr file is in the env slot it activates the env map. nobody knows why... FUCK MAX
				rend = renderers.production
				if classof renderers.production == vray or classof renderers.production == vrayrt then
				(
					if classof renderers.production == vrayrt then
						rend = rend.V_Ray_settings
					try
					(
						if rend.environment_gi_on and rend.environment_gi_map != undefined then
						(
							rend.environment_gi_map.name="GI"
							setMeditMaterial 1 rend.environment_gi_map
						)
						if rend.environment_rr_on and rend.environment_rr_map != undefined then
						(
							rend.environment_rr_map.name="GI"
							setMeditMaterial 2 rend.environment_rr_map
						)
						if rend.environment_refract_on and rend.environment_refract_map != undefined then
						(
							rend.environment_refract_map.name="GI"
							setMeditMaterial 3 rend.environment_refract_map
						)
					)catch()
				)
				useEnvironmentMap = env
			)
			missingfiles = #()

			--ask manager to write txt file with files in /tex folder on FTP
			/*local refreshFtpTxtPath = pathConfig.appendPath (dlg_main.m_defaultPath) "shadows.txt"

			--workaround for max 2012 maxscript problem that files are not closed properly, and so the manager can't delete it
			if (maxversion())[1] >= 14000 then
			(
				HiddenDOSCommand ("echo naeim a > \""+refreshFtpTxtPath+"\"")
			)
			else
			(
				local refreshFtpFile = openFile refreshFtpTxtPath mode:"w"
				close refreshFtpFile
			)*/

			local ftpContentsPath = pathConfig.appendPath (dlg_main.m_defaultPath) "shadows.txt"
			/*deleteFile ftpContentsPath*/

			local c=0
			local bConnected = true
			ftpContentsSizes = #()
			ftpContentsFiles = #() 
			if not doesFileExist ftpContentsPath do(				
				shellLaunch dlg_main.m_managerPath ""
			) 
			dlg_main.progressStart()
			while (existsFile refreshFtpTxtPath AND NOT (existsFile ftpContentsPath)) do
			(
				 
				PushPrompt("Asking Render Farm Application Desk..."+ c as string)
				
				tmpC=0.0
				while(tmpC<1.0) do
				(
					tmpC= tmpC+0.2
					sleep(0.2)

					tmpProgress= 100.0/15.0 * (tmpC+c)
					tmpCaption= "Asking Render Farm Application Desk..."+ c as string
					dlg_main.progressUpdate  progress:tmpProgress msg:tmpCaption
				)
				--sleep(1)
				redrawViews()
				c=c+1
				popPrompt()
			)

			dlg_main.progressEnd()

			if bConnected then
			(
				readFtpFileContents ftpContentsPath &ftpContentsFiles &ftpContentsSizes
				/*deleteFile ftpContentsPath*/
			)

			vecTex = findAllTextures()

			local lastRedraw = mTimeGetTime()
			local vecTexChecked = #()
			local vecTexFullPaths = #()
			dlg_main.progressStart()
			for i = 1 to vecTex.count do
			(
				if findItem vecTexChecked vecTex[i].filename != 0 then
					continue
				else
					append vecTexChecked vecTex[i].filename

				PushPrompt("Checking Texture " + (i as string) + " of " + (vecTex.count as string) + "...")
				dlg_main.progressUpdate progress:(100.0/vecTex.count*i) msg:("Checking Texture " + (i as string) + " of " + (vecTex.count as string) + "...")
				if mTimeGetTime() - lastRedraw > 500 then
				(
					lastRedraw = mTimeGetTime()
					redrawViews()
				)

				local st = (mapPaths.getFullFilePath vecTex[i].filename) as string
				if (getfilenametype st) == ".gz" then
					continue

				if findItem texExcludes (myToLower (filenameFromPath vecTex[i].filename)) != 0 then
					continue

				if (getfilenametype vecTex[i].filename) == ".stat" then
				(
					statpath = getFilenamePath vecTex[i].filename+ "*.stat"
					if (getFiles statpath).count > 0 then -- there are *0001.stat files etc.
						continue
				)

				if (getfilenametype st) == ".dds" then
					append resultList (tr id:11002 index:index validator:val severity:2 message:("DDS textures are not allowed: \"" + st + "\" convert to TIF and replace!") flagMoreInfos:true type:ONLINE_FAQ)
				if (getfilenametype st) == ".sbsar" then
					append resultList (tr id:11002 index:index validator:val severity:2 message:("Substance textures currently not allowed: \"" + st + "\""))
				-- if vecTex[i].filename != undefined and (findString vecTex[i].filename "..\\" != undefined OR findString vecTex[i].filename ".\\" != undefined )then
				-- 	append resultList (tr id:11003 index:index validator:val severity:2 message:("Relative texture paths are not allowed: " + vecTex[i].filename) flagMoreInfos:true type:ONLINE_FAQ)

				if (maxVersion())[1] < 15000 then
				(
					if not (CheckPath st) then
						append resultList (tr id:11004 index:index validator:val severity:2 message:("Filepath has unsupported characters, use only ASCII in file paths: " + st) flagMoreInfos:true type:ONLINE_FAQ)
				)

				--todo ifls gehen manchmal? wenn sie im asset tracker drinstehn? aber dann  problem mit hash hintenhinh�ngen... komische sache
 				if (getfilenametype st) == ".ifl" then
 				(
 					iflFilenames = getIflFilenames vecTex[i].filename
 					for f in iflFilenames do
 					(
						local iflPath = findIflPath vecTex[i].filename f

						if iflPath == undefined then
 							append resultList (tr id:11005 index:index validator:val severity:2 message:("Ifl file entry not found: " + f))
 					)
 				)
				 -- Presenz File Check
				if (getfilenametype st) == ".przDetect" then
 				(
					-- Need to add Check for VRAY Raw image
					-- ADd info that the presenz Camera needs to be selected
					if not hasProperty renderers.production "output_rawFileName" or (getfilenametype renderers.production.output_rawFileName) != ".przRender" then
					(
						append resultList (tr id:11006 index:index validator:val severity:2 message:("The Vray Raw image extension is not set to .przRender or the Renderer is not set to Vray"))
					)
 					if vecTex[i].obj.render_phase != 1 then
					(
						append resultList (tr id:11006 index:index validator:val severity:2 message:("Presenz Camera not set to Render Phase "))
					)
					if vecTex[i].obj.block_range != false then
					(
						append resultList (tr id:11006 index:index validator:val severity:2 message:("Presenz Manual Rendering: Block Range is not disabled "))
					)
					append resultList (tr id:11006 index:index validator:val severity:1 message:("Please keep in mind, that the PresenZ Camera needs to be selected."))
 				)


				if NOT existsFile (st) then  -- added * because FumeFx does not provide a file extension
				(
					append resultList (tr id:11006 index:index validator:val severity:2 message:("File not found: " +vecTex[i].filename) flagMoreInfos:true type:REPLACE_ALL_MISSING)
					append missingfiles vecTex[i].filename
				)
				else
				(
					local fPath = myToLower (ChangeFilenameUnicode (filenameFromPath st))
					if fPath == undefined OR fPath == "" then
						fPath = myToLower (filenameFromPath st)
					local pos = findItem ftpContentsFiles fPath
					if pos != 0 then
					(
						local localSize = getFileSize st
						local remoteSize = (ftpContentsSizes[pos]+"L") as Integer64
						if localSize != remoteSize then
							append resultList (tr id:11007 index:index validator:val severity:2 message:("Texture: \"" + (filenameFromPath st) + "\" Found on server, got the same name but different size (Local: " + (replace (localSize as string) (findString (localSize as string) "L") 1 " ") + "byte Server: " + (replace (remoteSize as string) (findString (remoteSize as string) "L") 1 " ") + "byte). Please rename and replace in Asset Tracker") flagMoreInfos:true type:ONLINE_FAQ)
					)

					if checkTextureType st == false then
						append resultList (tr id:11008 index:index validator:val severity:2 message:("Texture \""+(filenameFromPath st)+"\" is not of type \""+(getfilenametype st)+"\"") flagMoreInfos:true type:ONLINE_FAQ)

					local fname = myToLower(filenameFromPath st)
					for j = 1 to amin #(i-1, vecTexFullPaths.count) do
					(
						mm = vecTexFullPaths[j] as string
						mmfname = filenameFromPath mm
						if mmfname == fname then
						(
							if mm != (myToLower st) then
							(
								if getFileSize st != getFileSize mm then
									append resultList (tr id:11009 index:index validator:val severity:2 message:("Duplicate Texture found: "+(st)) value:("\""+(st)+"\" and \""+(mm)+"\"") flagMoreInfos:true type:DUPLICATE_TEX)
							)
						)
					)
				)

				--point cache files
				if (maxVersion())[1] >= 10000 then
				(
					if (getfilenametype st) == ".xml" then
					(
						local pcpath = (substring st 1 (st.count-4))
						local pcFiles = getFiles (pcpath + "*")
						local pcFileFound = false
						for p in pcFiles do
						(
							local pctype = getfilenametype p
							if (substring pctype 1 3) == ".mc" then
								pcFileFound = true
						)
						if not pcFileFound then
							append resultList (tr id:11010 index:index validator:val severity:2 message:("Pointcache File not found for: " +st) flagMoreInfos:true type:ONLINE_FAQ)
					)
				)

				popPrompt()
			)
			dlg_main.progressEnd()

		index = index + 1;
		-- todo ifl files = sequence files
		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		if result.type == REPLACE_ALL_MISSING then
		(
			goToOnlineFaq result.id
			if querybox "Do you want to replace all missing textures with a black 100x100 dummy texture?" title:"Render Farm Application" then
			(
				if maxFilePath != "" then
				(
					local dummypath = pathConfig.appendPath maxFilePath "FarmRender"
					makeDir (dummypath) all:true

					for i =1 to missingfiles.count do
					(
						if (getfilenametype missingfiles[i]) == ".ies" or (getfilenametype missingfiles[i]) == ".psd" then
						(
							local f = pathConfig.appendPath dummypath (filenameFromPath missingfiles[i]) 
						)
						else
						(
							local bm = bitmap 100 100
							bm.filename = pathConfig.appendPath dummypath (filenameFromPath missingfiles[i])
							save bm quiet:true
						)
					)
				)
				resolved = true
			)
		)
		else if result.type == DUPLICATE_TEX then
		(
			goToOnlineFaq result.id
			messagebox ("Texture at path "+result.val+" are not the same. Use Asset Tracker and repath (rightcklick to texture) both textures or rename one of them.")
			ATSOps.Visible = true
		)
		else if result.type == ONLINE_FAQ then
		(
			goToOnlineFaq result.id
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		pathNoCopy = #()
		if ZipFile == undefined then
			makeDir (pathConfig.appendPath fPath "tex") all:true
		dlg_main.progressStart()
		cacheIesValues()
		local lastRedraw = mTimeGetTime()
		vecTexRetarget = #()
		oldFilenames = #()
		newFilenames = #()
		check_fumefx_folder = ""
		for i = 1 to vecTex.count do
		(
			PushPrompt("Exporting Texture " + (i as string) + " of " + (vecTex.count as string) + "...")
			dlg_main.progressUpdate progress:(100.0/vecTex.count*i) msg:("Exporting Texture " + (i as string) + " of " + (vecTex.count as string) + "...")
			if mTimeGetTime() - lastRedraw > 500 then
			(
				lastRedraw = mTimeGetTime()
				redrawViews()
			)
			try
			(
				local st = (mapPaths.getFullFilePath vecTex[i].filename) as string
				print st

				if (getfilenametype vecTex[i].filename) == ".vrmap" or  (getfilenametype vecTex[i].filename) == ".vrlmap" or  (getfilenametype vecTex[i].filename) == ".gz" then
				(
					continue
				)


				if (getfilenametype st) == ".mib" then
				(
					stOld = vecTex[i].filename
					local stOldChanged = ChangeFilenameUnicode (filenameFromPath stOld)
					if stOldChanged == undefined or stOldChanged == "" then
					(
						stOldChanged = stOld
					)
					stFilename = filenameFromPath stOldChanged

					local newpath = (createTexPath dlg_main.m_userName (myFilenamefrompath stOldChanged))

					setProperty vecTex[i].obj vecTex[i].property newpath
					appendTexelem vecTexRetarget vecTex[i].obj vecTex[i].property stOld

					mibpath = getFilenamePath st+ "*.mib"
					mibFiles = getFiles mibpath

					for mibFile in mibFiles do
					(
						local stch= ChangeFilenameUnicode (filenameFromPath mibFile)
						if stch == undefined or stch == "" then
							stch = filenameFromPath mibFile

						appendFileInfo &vecFiles mibFile ("tex/" + stch)
					)
				)
				else if (getfilenametype vecTex[i].filename) == ".ifl" then
				(
					iflFilenames = getIflFilenames  (mapPaths.getFullFilePath vecTex[i].filename)

					for f in iflFilenames do
					(
						filepath = findIflPath vecTex[i].filename f

						if filepath != undefined then
						(
							local filenametocopy = filenameFromPath filepath
							local pos = vecFiles.count
							appendFileInfo &vecFiles filepath ("tex/" + filenametocopy)
							if pos != vecFiles.count then	--only add the nocopy entry if the file was really added to the vecFiles array, as this is not guaranteed
								append pathNoCopy (vecFiles.count-1)
						)
					)
					iflfile = mapPaths.getFullFilePath vecTex[i].filename
					local filenametocopy = filenameFromPath iflfile
					appendFileInfo &vecFiles iflfile ("tex/" + filenametocopy)
				)
				else if (getfilenametype vecTex[i].filename) == ".stat" then
				(
					stOld = vecTex[i].filename
					local stOldChanged = ChangeFilenameUnicode (filenameFromPath stOld)
					if stOldChanged == undefined or stOldChanged == "" then
					(
						stOldChanged = stOld
					)
					stFilename = filenameFromPath stOldChanged

					--stat files can't be retargeted manually -> fuck max
					ATSOps.ClearSelection()
					ATSOps.SelectFiles #(stOld)
					local newpath = (createTexPath dlg_main.m_userName (myFilenamefrompath stOldChanged))
					local bSuccess = ATSOps.RetargetSelection newpath
					append oldFilenames stOld
					append newFilenames newpath

					statpath = getFilenamePath vecTex[i].filename+ "*.stat"
					realStatFiles = getFiles statpath
					for statFile in realStatFiles do
					(
						local stch= ChangeFilenameUnicode (filenameFromPath statFile)
						if stch == undefined or stch == "" then
							stch = filenameFromPath statFile

						appendFileInfo &vecFiles statFile ("tex/" + stch)
					)
				)
				-- Presenz File Check
				else if (getfilenametype st) == ".przDetect" then
 				(
					remote_path = "tex/" + (myFilenamefrompath st)
					local absPath = (createTexPath dlg_main.m_userName (myFilenamefrompath st))
					appendFileInfo &vecFiles st remote_path
					setProperty vecTex[i].obj vecTex[i].property absPath
					appendTexelem vecTexRetarget vecTex[i].obj vecTex[i].property st
 				)
				else if classof vecTex[i].obj == FumeFX then -- if current obj is a fumeFX object use the method to set the path instead of the property.... pretty hard coded
				(

					-- getting thew last folder mentioned in the curretn path to move all files into those accordingly
					splitted_fumefx_folder = filterString vecTex[i].filename "\\"
					fumefx_folder = splitted_fumefx_folder[(splitted_fumefx_folder.count - 1)]
					ffx_file_extension = ".fxd"

					if vecTex[i].property == "illummap" then
					(
						ffx_file_extension = ".fim"
					)
					else if vecTex[i].property == "preview" then
					(
						ffx_file_extension = ".png"
					)
 
					local absPath = (createTexPath dlg_main.m_userName (fumefx_folder + "\\" + (myFilenamefrompath vecTex[i].filename + ffx_file_extension)))

					-- path is always saved with filename but WITHOUT Frames and extension. vecTex Property gives path type
					vecTex[i].obj.SetPath absPath #(vecTex[i].property, "nocheck")

					-- there is only a path with the basefilename saved in the properies.
					-- So i am getting all files in the folder for copying those to the Server
					fumefx_files = getFiles (getFilenamePath vecTex[i].filename + "*.*")

					-- Append to vecTex Retarget to fix the paths after saving the file in another path
					appendTexelem vecTexRetarget vecTex[i].obj vecTex[i].property vecTex[i].filename

					if check_fumefx_folder != fumefx_folder then  -- just once
					(
						for file in fumefx_files do
						(
							appendFileInfo &vecFiles file ("tex/" + fumefx_folder + "/" + filenameFromPath file)
						)
						check_fumefx_folder = fumefx_folder
					)

				)
 				else
				(
					stOld = vecTex[i].filename
					if findItem texExcludes (myToLower (filenameFromPath vecTex[i].filename)) != 0 then
					(
						if not pathConfig.isAbsolutePath vecTex[i].filename then
						(
							vecTex[i].filename = pathConfig.convertPathToAbsolute vecTex[i].filename
						)

						if not existsFile vecTex[i].filename then
						(
							continue
						)
					)
					local stOldChanged = ChangeFilenameUnicode (filenameFromPath stOld)
					local changed = true
					if stOldChanged == undefined or stOldChanged == "" then
					(
						stOldChanged = stOld
						changed = false
					)
					stFilename = filenameFromPath stOldChanged

					if (getfilenametype vecTex[i].filename) == ".ai" then
					(
						local absPath = (createTexPath dlg_main.m_userName (myFilenamefrompath stOldChanged))
						setProperty vecTex[i].obj vecTex[i].property absPath
						appendTexelem vecTexRetarget vecTex[i].obj vecTex[i].property stOld
					)
					else
					(
						if changed then
						(
							setProperty vecTex[i].obj vecTex[i].property (filenameFromPath stFilename)
							appendTexelem vecTexRetarget vecTex[i].obj vecTex[i].property stOld
						)
					)

					try --vray <UDIM> multi paths need to have absolute path
					(
						local origPath = getProperty vecTex[i].obj vecTex[i].property
						if (findString origPath "<") != undefined then
						(
							local absPath = (createTexPath dlg_main.m_userName (myFilenamefrompath origPath))
							setProperty vecTex[i].obj vecTex[i].property absPath
							local alreadyAdded = false
							for el in vecTexRetarget do
							(
								if el.obj == vecTex[i].obj and el.property == vecTex[i].property then
									alreadyAdded = true
							)
							if not alreadyAdded then
								appendTexelem vecTexRetarget vecTex[i].obj vecTex[i].property origPath
						)
					)
					catch()

					appendFileInfo &vecFiles st ("tex/" + stFilename) type:vecTex[i].property
					--point cache files
					if (maxVersion())[1] >= 10000 then
					(
						if (getfilenametype st) == ".xml" then
						(
--								local bSuccess = ATSOps.RetargetSelection (createTexPath dlg_main.m_userName (filenameFromPath st))
							local pcpath = (substring st 1 (st.count-4))
							local pcFiles = getFiles (pcpath + "*")
							for p in pcFiles do
							(
								local pctype = getfilenametype p
								if pctype != ".xml" then
								(
									local pcchanged = ChangeFilenameUnicode (myFilenamefrompath p)
									if pcchanged == undefined or pcchanged == "" then
									(
										pcchanged = myFilenamefrompath p
									)
									pcchanged = pathConfig.appendPath (pathConfig.appendPath fPath "tex") pcchanged
									local pcfilepath = "tex/" + (myFilenamefrompath pcchanged)
									appendFileInfo &vecFiles p pcfilepath
								)
							)
						)
					)
				)

			)
			catch
			(
				format "texture.ms: *** % ***\n" (getCurrentException())
			)
			popPrompt()
		)
		dlg_main.progressEnd()

		--retarget point cache files
		for o in $* do
		(
			try
			(
				for p in o.modifiers do
				(
					if classof p == Point_Cache or classof p == Point_Cache_Binding then
					(
						try(
							local alreadyDone = false
							for pc in oldPcOptions do
							(
								if pc[1] == p then
								(
									alreadyDone = true
									print "already done"
									print p
								)
							)
							if not alreadyDone then
							(
								local playbackType = p.playbackType
								local playbackStart = p.playbackStart
								local playbackEnd = p.playbackEnd
								local playbackFrame = p.playbackFrame
								local clampGraph = p.clampGraph
								append oldPcOptions #(p,#(#(#filename, p.filename), #(#playbackType, playbackType), #(#playbackStart, playbackStart), #(#playbackEnd, playbackEnd), #(#playbackFrame, playbackFrame), #(#clampGraph, clampGraph)))
								local oldPcPath = mapPaths.getFullFilePath p.filename
								if oldPcPath == "" then
									oldPcPath = p.filename
								newPcPath = (createTexPath dlg_main.m_userName (myFilenamefrompath oldPcPath))
								p.filename = newPcPath
								p.playbackType = playbackType
								p.playbackStart = playbackStart
								p.playbackEnd = playbackEnd
								p.playbackFrame = playbackFrame
								p.clampGraph =clampGraph
							)
						)catch(format "val_texture.ms: oldPcOptions3*** % ***\n" (getCurrentException()))
					)
				)
			)catch(format "val_texture.ms: oldPcOptions2*** % ***\n" (getCurrentException()))
		)

--Cache_disk files
		cacheDiskPaths = #()
		try
		(
			local cds = getClassInstancesSave Cache_Disk
			for cd in cds do
			(
				local prefix = cd.Write_To_File
				if findString prefix ".pfc" == prefix.count - 3 then
					prefix = substring prefix 1 (prefix.count-4)

				local files = getFiles (prefix + "*")
				for f in files do
				(
					local pos = vecFiles.count
					appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
					if pos != vecFiles.count then	--only add the nocopy entry if the file was really added to the vecFiles array, as this is not guaranteed
						append pathNoCopy (vecFiles.count-1)
				)
				append cacheDiskPaths cd.Write_To_File
				cd.Write_To_File = createTexPath dlg_main.m_userName (filenameFromPath cd.Write_To_File)
			)
		)
		catch
		(
			--	format "val_texture.ms: disk_cache *** % ***\n" (getCurrentException())
		)

		for nocopy in pathNoCopy do
		(
			settingsToWrite += "pathnocopy" + (nocopy as string) + "=1\n"
		)

		resetIesValues()
	),
	fn postSave zip =
	(
		if zip == false then
		(
			for i = 1 to oldFilenames.count do
			(
				ATSOps.ClearSelection()
				ATSOps.SelectFiles #(newFilenames[i])
				ATSOps.RetargetSelection oldFilenames[i]
			)

			dlg_main.progressStart()
			for i = 1 to vecTexRetarget.count do
			(
				dlg_main.progressUpdate progress:(100.0/vecTexRetarget.count*i) msg:("Resetting Texture " + (i as string) + " of " + (vecTexRetarget.count as string) + "...")
				PushPrompt("Resetting Texture " + (i as string) + " of " + (vecTexRetarget.count as string) + "...")

				if classof vecTexRetarget[i].obj == FumeFX then
				(
					ffx_file_extension = ".fxd"

					if vecTex[i].property == "illummap" then
					(
						ffx_file_extension = ".fim"
					)
					else if vecTex[i].property == "preview" then
					(
						ffx_file_extension = ".png"
					)
					ffx_params = #()

					vecTexRetarget[i].obj.SetPath (vecTexRetarget[i].filename + ffx_file_extension) #(vecTexRetarget[i].property, "nocheck")
				)
				else
				(
					setProperty vecTexRetarget[i].obj vecTexRetarget[i].property vecTexRetarget[i].filename
				)

				popPrompt()
			)
			dlg_main.progressEnd()

--point cache files
			for pc in oldPcOptions do
			(
				try(
					for keyval in pc[2] do
					(
						setProperty pc[1] keyval[1] keyval[2]
					)
				)catch(format "val_texture.ms: oldPcOptions*** % ***\n" (getCurrentException()))
			)

--Cache_disk files
			try
			(
				local cds = getClassInstancesSave Cache_Disk
				local i=0
				for cd in cds do
				(
					i=i+1
					print ("reset: " + cd.Write_To_File + " to " + cacheDiskPaths[i])
					cd.Write_To_File = cacheDiskPaths[i]
				)
			)
			catch
			(
			--	format "val_texture.ms: disk_cache *** % ***\n" (getCurrentException())
			)
		)
		resetIesValues()
	)
)

selected_camera = 0
rollout general_select_camera "Select your camera" width:200 height:100
(
	local cam = undefined
	local cams = #()

	Dropdownlist drpCam "Cameras"
	Button btnOk "Ok" align:#right

	on general_select_camera open do
	(
		cams = #()
		for c in cameras do
		(
			try
			(
				if classof c == Targetobject then
					continue
				append cams c.name
			)
			catch()
		)
		append cams "Active Viewport"
		drpCam.items = cams
		active_camera = getActiveCamera()

		if active_camera == undefined and selected_camera == 0 then
		(
			selected_camera = 1
		)

		if selected_camera == 0 then
		(

			drpCam.selection = findItem cams active_camera.name
		)
		else
		(
			drpCam.selection = selected_camera
		)
	)

	on drpCam selected i do
	(
		selected_camera = i
	)

	on btnOk pressed do
	(
		if cameras.count != 0 and drpCam.selection > 0 then
			cam = cams[drpCam.selection]
		DestroyDialog general_select_camera
	)
)


rollout general_select_slices "How many machines should work on your job?" width:420 height:180
(
	local slices = 100
	local confirmed = false

	Slider sliderSlices "Nodes: 100" ticks:9 range:[10,100,100]
	Button btnOk "Ok"
	Label lbl "Lower the number of nodes to have less overhead charged on your job.
Less nodes will result in slightly lower rendercosts, but will make your renderjob take longer to complete." align:#center width:400 height:40
 
	on iray_gpu_dlg open do
	(
	)

	on sliderSlices changed val do
	(
		local rounded = floor(val/10)*10
		sliderSlices.value = rounded
		sliderSlices.text = "Nodes: " + ((sliderSlices.value as integer) as string)
	)

	on btnOk pressed do
	(
		slices = sliderSlices.value as integer
		if slices > 100 then	--some users have unit conversion issues and might land at 1000 slices somehow
			slices = 100
		confirmed = true
		DestroyDialog general_select_slices
	)
)


struct ValRenderSettings
(
	COMP_ADV_LIGHT = 1,
	INVALIDRAD_ADV_LIGHT = 2,
	ENABLE_SINGLE_FRAME = 3,
	REMOVE_KEYFRAMES = 4,
	SELECT_CAMERA = 5,
	DR_SELECT_SLICES = 6,
	NTH_FRAME = 7,
	RENDER_FIELDS = 8,
	VRAY_DENOISE_ENABLE = 9,
	REMOVE_ELEMENTS = 10,
	ELEMENTS_NAMES = 11,
	UNLOCK_VIEWPORT = 12,

	oldRendOutPath = "",
	oldOutputFiles = #(),
	m_PSDEffect = undefined,
	oldPSDManagerPath = "",

	oldCamName = "",
	newCamName = "",

	oldCamNames = #(),
	newCamNames = #(),

	batchOutputNames = #(),

	oldViewportType = undefined,
	oldViewportCamera = undefined,

	is_renderer_validator = false,

	fn filterCameraName camname =
	(
		newName = copy camname
		-- removed for Unicode
		-- allowed = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.- "
		-- for i = 1 to newName.count do
		-- (
		-- 	if (findstring allowed newName[i])==undefined then
		-- 	(
		-- 		newName[i] = "_"
		-- 	)
		-- )
		-- if newName != camname then
		-- 	for camera in cameras do
		-- 	(
		-- 		if camera == newName then
		-- 		(
		-- 			newName = uniqueName newName
		-- 			exit
		-- 		)
		-- 	)

		return newName

	),
	fn get_batch_render_views_camera_by_name cam_name =
	(
		-- check if any of the batch render views is using the given camera and return an array containing those cameras
		local batch_render_views = #() -- an array of arrays each containing the view name and the camera
		if skyatchRender.batchRender.checked then
		(
			for i=1 to batchRenderMgr.numViews do
			(
				local batch_render_params = batchRenderMgr.GetView i
				if batch_render_params.enabled then
				(
					if batch_render_params.camera != undefined and batch_render_params.camera.name == cam_name then
					(
						append batch_render_views batch_render_params.name
					)
				)
			)
		)
		return batch_render_views
	),

	fn set_batch_render_views_camera_by_name batch_render_views new_camera =
	(
		for view in batch_render_views do
		(
			batch_render_view = batchRenderMgr.GetView (batchRenderMgr.findView view)
			batch_render_view.camera = new_camera
		)
	),

	fn renameCamera oldName newName =
	(
		batch_render_views = get_batch_render_views_camera_by_name(oldName)
		if batch_render_views.count > 0 then
		(
			for c in cameras do
			(
				if classof c != Targetobject and c.name == oldName then
				(
					c.name = newName
					set_batch_render_views_camera_by_name batch_render_views c
				)
			)
		)
	),

	fn asciify_camera_names =
	(
		for camera in cameras do
		(
			old_camera_name = ""
			new_camera_name = ""
			if classof camera != Targetobject and camera.name != undefined then
			(
				old_camera_name = (copy camera.name)
				new_camera_name = (filterCameraName (copy camera.name))

				renameCamera old_camera_name new_camera_name
				append oldCamNames old_camera_name
				append newCamNames new_camera_name
			)
		)
	),

	fn getName name:"" =
	(
		name = "Render Settings";
	),
	fn getIdentifier =
	(
		return #()
	),

	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
		index = 0;

		if (maxVersion())[1] >= 11000 then
		(
--			if rendViewIndex == undefined then
--				append resultList (tr id:3033 index:index validator:val severity:2 message:"Can't detect your render camera" flagMoreInfos:true type:ONLINE_FAQ)
		)

		if (maxVersion())[1] >= 11000 then
		(
			if setting_batch_render == False then
			(
				cam = getActiveCamera()
				if rendUseActiveView == false and rendViewIndex != undefined then -- viewport locked
				(
					cam = viewport.getCamera index:rendViewIndex
					if rendViewIndex > viewport.numViews then
						append resultList (tr id:3033 index:index validator:val severity:2 message:"Your \"View to Render\" is not available" flagMoreInfos:true type:UNLOCK_VIEWPORT)
				)

				if cam == undefined and general_select_camera.cam == undefined then
				(
					if cameras.count > 0 then
						append resultList (tr id:3033 index:index validator:val severity:2 message:"Select your render camera" flagMoreInfos:true type:SELECT_CAMERA)
					else
						append resultList (tr id:3033 index:index validator:val severity:0 message:"Render camera: Active Viewport" flagMoreInfos:true type:SELECT_CAMERA)
				)
				else if general_select_camera.cam != undefined then
						append resultList (tr id:3033 index:index validator:val severity:0 message:("Render camera: "+general_select_camera.cam) flagMoreInfos:true type:SELECT_CAMERA)
				else if cam != undefined then
				(
					append resultList (tr id:3033 index:index validator:val severity:0 message:("Render camera: "+cam.name) flagMoreInfos:true type:SELECT_CAMERA)
					local found = false
					for c in cameras do
					(
						if c == cam then
							found=true
					)
					if not found then --this happens if the camera is in a xref file, renaming won't work so generate an Error if it has unsupported chars
					(
						local camname = cam.name
						local newCamName = filterCameraName camname
						if camname != newCamName then
							append resultList (tr id:3033 index:index validator:val severity:2 message:("Your Camera name has unsupported characters, use only letters and numbers, no spaces: "+cam.name))
					)
				)
			)
		)

		if renderSceneDialog.isOpen() then
		(
			renderSceneDialog.commit()
		)

		if dlg_main.estimateRenderpoints then
		(
				if getNumFrames() < 5 then
					append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: for Cost Estimation your frame range must consist of at least 5 frames"))
		)

		if isSingleFrameRender() then
		(
			if renderWidth < 640 or renderHeight < 480 then
				append resultList (tr id:9001 index:index validator:val severity:2 message:"Common: Image resolution too small. Do not use distributed render")

			if not isProgressiveRendering() then
			(
				append resultList (tr id:9051 index:index validator:val severity:0 message:("Common: Your job will render distributed on "+(dlg_main.m_slices as string)+" Nodes. To lower Overhead costs") flagMoreInfos:true type:DR_SELECT_SLICES)

				if (maxVersion())[1] < 18000 and mod renderWidth dlg_main.m_slices != 0 then
					append resultList (tr id:9052 index:index validator:val severity:2 message:("Common: Render Resolution width must be divisible by number of machines ("+(dlg_main.m_slices as string)+") for distributed Rendering!"))
			)

			if dlg_main.estimateRenderpoints then
				append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating Costs for Distributed Rendering currently not possible!"))

			if isSceneAnimated() then
			(
				append resultList (tr id:9002 index:index validator:val severity:2 message:"Common: Keyframes found. No animation allowed for Distributed render, please remove keys from scene" flagMoreInfos:true type:REMOVE_KEYFRAMES)
		--		local animObjs = getAnimatedObjects 10
		--		for i=1 to animObjs.count do
		--		(
		--			append resultList (tr id:9003 index:index validator:val severity:2 message:("Keyframe Object: " + animObjs[i] as string))
		--		)
			)
		-- collides with MAX_VIEWPORT_BUG, so removed for now
		--	if (maxVersion())[1] >= 11000 then
		--	(
		--		if rendUseActiveView == false then
		--			append resultList (tr id:9004 index:index validator:val severity:2 message:"Common: Use Active View is disabled (little lock symbol in Render settings next to \"Render\"-button")
		--	)
		)
		--TODO

		if rendTimeType == 4 then
			append resultList (tr id:9005 index:index validator:val severity:2 message:"Common: Time Output \"Frames\" not yet supported")

		if rendNThFrame  != 1 then
		(
			if isSingleFrameRender() then
				append resultList (tr id:9006 index:index validator:val severity:2 message:("Common: \"Every Nth Frame\" must be set to 1 for distributed render") flagMoreInfos:true type:NTH_FRAME)
			else
				append resultList (tr id:9006 index:index validator:val severity:1 message:("Common: \"Every Nth Frame\" is set to " +(rendNThFrame as string)))
		)

		if rendFileNumberBase != 0 then
		(
			append resultList (tr id:9005 index:index validator:val severity:2 message:"Common: Time Output \"File Number Base\" not yet supported and needs to be 0(zero)")
		)

		if MaxLiquid != undefined and (getClassInstances MaxLiquid).count > 0 then
		(
			append resultList (tr id:9005 index:index validator:val severity:1 message:"WARNING: Max Liquids are currently not supported. Please convert to use Alembic instead")
		)

		if renderWidth < 350  then
			append resultList (tr id:9007 index:index validator:val severity:1 message:"Common: Resolution X seems to be very low.")
		if renderWidth > 1921 and not isSingleFrameRender() then
			append resultList (tr id:9008 index:index validator:val severity:1 message:"Common: Resolution X seems to be very high.")

		if renderHeight < 350  then
			append resultList (tr id:9009 index:index validator:val severity:1 message:"Common: Resolution Y seems to be very low.")
		if renderHeight > 1081 and not isSingleFrameRender() then
			append resultList (tr id:9010 index:index validator:val severity:1 message:"Common: Resolution Y seems to be very high.")

		if rendFieldRender  == true then
			append resultList (tr id:9011 index:index validator:val severity:1 message:"Common: \"Render to Fields\" is activated." flagMoreInfos:true type:RENDER_FIELDS)

		local defaultExtension = "tif"

		local dontSetSave = false -- bloody hack for vray DR
		if classof renderers.production == vray or classof renderers.production == vrayrt then
		(
			local rend = renderers.production
			if classof renderers.production == vrayrt then
				rend = renderers.production.V_Ray_settings
			if isSingleFrameRender() then
			(
				if rend.imageSampler_type != 3 and rend.output_on and (rend.output_saveRawFile or rend.output_splitgbuffer) then
				(
					dontSetSave = true
				)
				defaultExtension = "exr"
			)
		)

		if rendOutputFilename == "" or rendOutputFilename == undefined then
		(
			rendOutputFilename = getDefaultOutputName defaultExtension
			if defaultExtension == "tif" then
			(
				TIF.setAlpha(true)
				TIF.setType("color16")
			)
			renderSceneDialog.update()
		)

		saveExt = getFilenameType rendOutputFilename
		if NOT rendSaveFile  then
		(
			if not dontSetSave then
				rendSaveFile = true
			renderSceneDialog.update()
		)

		if saveExt.count == 0 then
			append resultList (tr id:9014 index:index validator:val severity:2 message:("Common: Your output Filename has no extension."))
		else
		(
			if not isExtensionSupported(saveExt) AND saveExt.count > 0 then
				append resultList (tr id:9013 index:index validator:val severity:2 message:("Common: File Extension \"" +saveExt+ "\" not supported"))
		)

		local outfilename = filenameFromPath rendOutputFilename
		if CheckFilenameUnicode outfilename == false then
			append resultList (tr id:9018 index:index validator:val severity:2 message:("Common: Your output filename \""+outfilename+"\" has unsupported characters."))
		if outfilename.count > 60 then
			append resultList (tr id:9019 index:index validator:val severity:2 message:("Common: Your output filename \""+outfilename+"\" is to long (max. 60 chars)."))
		if isSingleFrameRender() then
		(
			fileOnly = getFilenameFile rendOutputFilename
			local lastChar = fileOnly[fileOnly.count]
			if lastChar != undefined AND bit.charAsInt lastChar >= 48 AND bit.charAsInt lastChar <=  57 then
			(
				rendOutputFilename = changeLastChar rendOutputFilename
				renderSceneDialog.update()
			)
		)

		local maxfile = dlg_main.changedMaxFile
		if maxfile == undefined then
			maxfile = ""
		if maxfile.count > 60 then
			append resultList (tr id:9020 index:index validator:val severity:2 message:("Common: Your .max filename \""+maxfile+"\" is to long (max. 60 chars)."))

		if isSingleFrameRender() then
		(

			if skyatchRender.batchRender.checked and batchRenderMgr.numViews != 0 and classof renderers.production != vray then
				append resultList (tr id:9021 index:index validator:val severity:2 message:("Combining Batch rendering and Distributed Rendering is only possible with Vray"))

			if not isSingleFrameExtensionSupported saveExt then
				append resultList (tr id:9021 index:index validator:val severity:2 message:("Common: File Extension \"" +saveExt+ "\" not supported for single frame rendering"))

			if saveExt == ".tif" then
			(
				if TIF.getType() == #logLUV or TIF.getType() == #logL then
					append resultList (tr id:9021 index:index validator:val severity:2 message:("Common: Tif type SGI Log is not supported for single frame rendering, use EXR instead"))
			)
			else if saveExt != ".exr" then
			(
				if (renderWidth >= 26000 or renderHeight >= 26000) then
					append resultList (tr id:9021 index:index validator:val severity:2 message:("Common: Resolution over 26000 not supported for this format, use EXR instead"))
			)

			if saveExt == ".png" then
			(
				if pngio.getType() == #true48 then
					append resultList (tr id:9021 index:index validator:val severity:2 message:("Common: 48 bit png is not supported for single frame rendering, use EXR instead"))
				if renderWidth >= 16000 or renderHeight >= 16000 then
					append resultList (tr id:9021 index:index validator:val severity:2 message:("Common: PNG not supported for resolutions over 16000, use EXR instead"))
			)

			if saveExt != ".exr" and (renderWidth >= 16000 or renderHeight >= 16000) then
				append resultList (tr id:9021 index:index validator:val severity:2 message:("Common: output format not supported for resolutions over 16000, use EXR instead"))
		)

		if usePreRendScript OR usePostRendScript OR preRendScript != "" OR postRendScript != "" then
			append resultList (tr id:9024 index:index validator:val severity:2 message:"Common: Scripts are not supported, please remove and disable")

		if not (classof renderers.production == MaxwellRenderer) then
		(
			renderElementsMgr = maxOps.GetRenderElementMgr #Production
			bElements=false
			bDoubleNameFound=false
			local elementNames = #()
			local isSingle = isSingleFrameRender()
			local isVrayVfb = false
			local isVrayVfbOn = false
			if (classof renderers.production == vray) or (classof renderers.production == vrayrt) then
			(
				local rend = renderers.production
				if (classof renderers.production == vrayrt) then
					rend = renderers.production.V_Ray_settings
				if rend.output_on and rend.output_saveRawFile and not rend.output_splitgbuffer then
					isVrayVfb = true
				isVrayVfbOn = rend.output_on
			)
			for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
			(
				el = renderElementsMgr.GetRenderElement n
				if el.enabled == undefined OR el.enabled == false then
					append resultList (tr id:9025 index:index validator:val severity:2 message:("Render Element \"" + el.elementName + "\" is disabled, remove or activate them."))
				if (renderElementsMgr.GetRenderElementFilename n) =="" and not isVrayVfb then
					append resultList (tr id:9026 index:index validator:val severity:2 message:("Render Element \"" + el.elementName + "\" has no path assigned."))

				local elemExt = ""
				if renderElementsMgr.GetRenderElementFilename n != undefined then
					elemExt = getFilenameType (renderElementsMgr.GetRenderElementFilename n)

				if isSingle then
				(
					if not isSingleFrameExtensionSupported(elemExt) and not isVrayVfb then
						append resultList (tr id:9027 index:index validator:val severity:2 message:("Common: Render Element File Extension \"" +elemExt+ "\" not supported for single frame rendering"))

					local elemname = ""
					if renderElementsMgr.GetRenderElementFilename n != undefined then
					(
						elemname = getFilenameFile (renderElementsMgr.GetRenderElementFilename n)
						local lastChar = elemname[elemname.count]
						if lastChar != undefined AND bit.charAsInt lastChar >= 48 AND bit.charAsInt lastChar <=  57 then
							renderElementsMgr.SetRenderElementFilename n (changeLastChar (renderElementsMgr.GetRenderElementFilename n))
					)

					local lastChar = el.elementName[el.elementName.count]
					if lastChar != undefined AND bit.charAsInt lastChar >= 48 AND bit.charAsInt lastChar <=  57 then
						append resultList (tr id:9027 index:index validator:val severity:2 message:("Common: Render Element \"" +el.elementName+ "\": last character in Name must not be a number"))
				)
				else
				(
					if not isExtensionSupported(elemExt) then
						append resultList (tr id:9028 index:index validator:val severity:2 message:("Common: Render Element File Extension \"" +elemExt+ "\" not supported"))
				)

				if not CheckFilenameUnicode el.elementName then
					append resultList (tr id:9027 index:index validator:val severity:2 message:("Common: Render Element \"" +el.elementName+ "\": has unsupported characters"))

				local elname = myToLower(el.elementName)
				if findItem elementNames elname > 0 then
					bDoubleNameFound = true
				else
					append elementNames elname
				bElements=true

				try
				(
					if classof el == VRayDenoiser then
					(
						if not isVrayVfbOn then
							append resultList (tr id:9027 index:index validator:val severity:2 message:("Common: VRayDenoiser needs Vray frame buffer to be activated") flagMoreInfos:true type:VRAY_DENOISE_ENABLE)

						if isSingleFrameRender() then
							append resultList (tr id:9027 index:index validator:val severity:2 message:("Common: VRayDenoiser not yet supported for distributed rendering"))
						if el.denoising_engine !=0 and not dlg_main.gpuSelected() then
							append resultList (tr id:9053 index:index validator:val severity:2 message:("VRayDenoiser: NVIDIA AI denoiser only supported for GPU rendering"))
					)
				)catch()
			)
			if isSingleFrameRender() and bDoubleNameFound then
				append resultList (tr id:9029 index:index validator:val severity:2 message:"Scene includes Render Elements with same names, please rename one of them!")
			-- NEED TO REAPPLY FOR ERROR MAX23
			if (maxversion())[1] < 25000 then
			(
				if renderElementsMgr.GetCombustionOutputEnabled() == true then
				append resultList (tr id:9030 index:index validator:val severity:2 message:"Render Elements: \"Output to Combustion\" is not supported.")
				else
				(
					if renderElementsMgr.GetCombustionOutputPath() != "" then
					append resultList (tr id:9031 index:index validator:val severity:2 message:"Render Elements: \"Output to Combustion\" Path must be empty.")
				)
			)

			if bElements==true AND renderElementsMgr.GetElementsActive() == false then
				append resultList (tr id:9032 index:index validator:val severity:2 message:"Scene includes Render Elements but they are disabled, remove or activate them." flagMoreInfos:true type:REMOVE_ELEMENTS)
		)
		if classof renderers.production == default_scanline_renderer then
		(
			if SceneRadiosity.radiosity != undefined then
			(
				if RadiosityPreferences.useAdvancedLighting == false then
				(

				)
			)
			if classof SceneRadiosity.radiosity == Radiosity then
			(
				if RadiosityPreferences.computeAdvancedLighting  == true then
				(
					append resultList (tr id:9033 index:index validator:val type:COMP_ADV_LIGHT severity:1 message:"Common: \"Compute Advanced Lighting when Required\" is not recommended for static scenes" flagMoreInfos:true)
				)
				else
				(
					if SceneRadiosity.Radiosity.radProcessInRenderOnly == false then -- radiosity "start" can be pressed
					(
						-- open render dialog to check  radiosity settings
						rOpen = renderSceneDialog.isOpen()

						if rOpen then
						(
							btnResetAll = findRenderDialogElement "Reset All"
							if btnResetAll != undefined AND btnResetAll != -1 then
							(
								btnReset = UIAccessor.getNextWindow btnResetAll
								if btnReset != undefined then
								(
									btnStart = UIAccessor.getNextWindow btnReset
									if btnStart != undefined then
									(
										txtStart = UIAccessor.getWindowText btnStart
										if txtStart == "Start" then
										(
											-- "start" enabled and not "continue"
											append resultList (tr id:9034 index:index validator:val severity:2 message:"Advanced Lighting: \"Radiosity solution not generated; Please bake radiosity solution to scene.")-- "start" enabled and not "continue"
										)
										else
										(
											if txtStart == "Continue" then
											(
												lblInvalid = findRenderDialogElement "Solution is invalid at current time frame"
												if lblInvalid != undefined AND lblInvalid != -1 then
												(
													-- "continue -> solution invalid at current time frame"
													append resultList (tr id:9035 index:index validator:val severity:2 message:"Advanced Lighting: \"Radiosity solution not generated; Please bake radiosity solution to scene.")
												)
												else
												(
													append resultList (tr id:9036 index:index validator:val type:INVALIDRAD_ADV_LIGHT severity:1 message:"Advanced Lighting: \"Radiosity solution baken to scene! " flagMoreInfos:true)
												)
											)
										)
									)
								)
							)
						)
						else
						(
							append resultList (tr id:9037 index:index validator:val severity:2 message:"Advanced Lighting: Radiosity settings need to be checked. Please open the Render Dialog and press Validate again." flagMoreInfos:false)
						)
					)
				)
			)
		)
		if useEnvironmentMap == false and environmentMap != undefined and getclassname environmentMap == "mr Physical Sky" then
		(
			append resultList (tr id:9038 index:index validator:val severity:2 message:"Environment and Effects: Environment Map is not used. enable or delete it!" flagMoreInfos:false)
		)

		if SceneExposureControl.exposureControl != undefined then
		(
			try
			(
				if SceneExposureControl.exposureControl.active == false then
					append resultList (tr id:9043 index:index validator:val severity:1 message:("Environment: Exposure Control is not active"))
			)
			catch()
		)
		if skyatchRender.batchRender.checked then
		(
			if batchRenderMgr.numViews != 0 then
				append resultList (tr id:9044 index:index validator:val severity:0 message:("Batch Render: rendering " + batchRenderMgr.numViews as string + " views"))
		)

		for i = 1 to numEffects do
		(
			try
			(
				eff = getEffect i
				if getClassName eff == "psd-manager" then
				(
					if eff.filename == "" OR getFilenameType eff.filename != ".psd" then
					(
						append resultList (tr id:9045 index:index validator:val severity:1 message:("Effects: PSD manager - save path or file name incorrect"))
					)
				)
				if getClassName eff == "File Output" then
				(
					append resultList (tr id:9050 index:index validator:val severity:2 message:("Effects: File Output not supported."))
				)
			)
			catch
			(
			)
		)

		try
		(
			local outputnames = #()
			append outputnames (myToLower (pathConfig.stripPathToLeaf rendOutputFilename))
			renderElementsMgr = maxOps.GetRenderElementMgr #Production
			for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
			(
				local elempath = renderElementsMgr.GetRenderElementFileName n
				local p = myToLower (pathConfig.stripPathToLeaf (elempath))
				if findItem outputnames p > 0 then
				(
					append resultList (tr id:9046 index:index validator:val severity:2 message:("Some Elements have the same output names") flagMoreInfos:true type:ELEMENTS_NAMES)
					exit
				)
				append outputnames p
			)
		)
		catch
		(
			format "settings.ms: *** % ***\n" (getCurrentException())
		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValRendersettings!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			SELECT_CAMERA:
			(
				CreateDialog general_select_camera modal:true
				if general_select_camera.cam != undefined then
				(
					result.message = "Render camera: "+general_select_camera.cam
					resolved = true
				)
			)
			COMP_ADV_LIGHT:
			(
				st="A static scene includes No object-, light- or material animations.
The Camera is the only moving part. If your scene is static, please disable that switch.
If your scene is NOT static the light solution is computed each frame and can cause a light flicker in the final output";
				messagebox st title:"Render Farm Application"
			)
			INVALIDRAD_ADV_LIGHT:
			(
				st="If your scene includes object-, light- or material animations you should activate \"Compute advanced lighting when required\" in the common render tab to update the light solution in the scene.
Warning: that updating can cause a light flicker in the final output";
				messagebox st title:"Render Farm Application"
			)
			REMOVE_KEYFRAMES:
			(
				if querybox "Do you want to remove all keyframes?" title:"Render Farm Application" then
				(
					deleteAllKeyframes()
					resolved = true
				)
			)
			DR_SELECT_SLICES:
			(
				CreateDialog general_select_slices modal:true
				dlg_main.m_slices = general_select_slices.slices
				result.message = ("Common: Your job will render distributed on "+(dlg_main.m_slices as string)+" Nodes. To lower Overhead costs")
				resolved = true
			)
			UNLOCK_VIEWPORT:
			(
				st="Open the Render Setup Dialog and click the Lock Icon twice to fix this";
				messagebox st title:"Render Farm Application"
			)
			NTH_FRAME:
			(
				if queryBox "Do you want me to set Nth frame to 1?" beep:false then
				(
					rendNThFrame = 1
					renderSceneDialog.update()
					resolved = true
				)
			)
			RENDER_FIELDS:
			(
				if queryBox "Do you want me to disable Render to Fields?" beep:false then
				(
					rendFieldRender = false
					renderSceneDialog.update()
					resolved = true
				)
			)
			VRAY_DENOISE_ENABLE:
			(
				if queryBox "Do you want me to enable Vray Framebuffer?" beep:false then
				(
					renderers.production.output_on = true
					renderSceneDialog.update()
					resolved = true
				)
			)
			REMOVE_ELEMENTS:
			(
				if queryBox "Do you want me to remove all Render Elements?" beep:false then
				(
					local renderElementsMgr = maxOps.GetRenderElementMgr #Production
					renderElementsMgr.RemoveAllRenderElements()
					renderSceneDialog.update()
					resolved = true
				)
			)
			ELEMENTS_NAMES:
			(
				if queryBox "Do you want me to rename clashing elements?" beep:false then
				(
					local outputnames = #()
					append outputnames (myToLower (pathConfig.stripPathToLeaf rendOutputFilename))
					renderElementsMgr = maxOps.GetRenderElementMgr #Production
					for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
					(
						local elempath = renderElementsMgr.GetRenderElementFileName n
						local p =  (pathConfig.stripPathToLeaf (elempath))
						local changed = ""
						local i=1
						while findItem outputnames (myToLower p) > 0 do
						(
							local s = elempath
							local ext = getFilenameType s
							changed = (substring elempath 1 (elempath.count - ext.count)) + "_" + i as string + "_" + ext
							p = (pathConfig.stripPathToLeaf (changed))
							i+=1
						)
						if changed != "" then
						(
							renderElementsMgr.SetRenderElementFileName n changed
						)
						append outputnames (myToLower p)
					)
					resolved = true
				)
			)
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		renderSceneDialog.commit()
		oldRendOutPath = rendOutputFilename
		local downloadPath = ""
		if findString oldRendOutPath "\\" != undefined then
			downloadPath = (pathConfig.removePathLeaf (pathConfig.convertPathToAbsolute oldRendOutPath))
		local rendOutFilenameChanged = ChangeFilenameUnicode (filenameFromPath rendOutputFilename)
		if rendOutFilenameChanged == "" then
			rendOutFilenameChanged = (filenameFromPath rendOutputFilename)
		rendOutFilenameChanged = trimleft rendOutFilenameChanged

		rendUseNet = false
		skipRenderedFrames = false


		mrendOutputFilename = createOutputPath dlg_main.m_userName rendOutFilenameChanged
		try
		(
			if classof renderers.production == vray or classof renderers.production == vrayrt then
			(
				local rend = renderers.production
				if (classof renderers.production == vrayrt) then
					rend = renderers.production.V_Ray_settings
				if isSingleFrameRender() and rend.output_on then
				(
					if rend.output_saveRawFile then
						mrendOutputFilename = createOutputPath dlg_main.m_userName "vray_frame_buffer.exr"
					else if rend.output_splitgbuffer then -- ; FIXME Why c:\logs
						mrendOutputFilename = createOutputPath dlg_main.m_userName (filenameFromPath rend.output_splitFileName)
				)

				if rend.output_on then
				(
					if rend.output_saveRawFile then
					(
						downloadPath = (pathConfig.removePathLeaf (pathConfig.convertPathToAbsolute rend.output_rawFileName))
						if maxver[1] >= 23000 then
						(
							downloadPath = (pathConfig.removePathLeaf (pathConfig.convertPathToAbsolute oldRendOutPath))
						)
					)
					else if rend.output_splitgbuffer then
					(
						downloadPath = (pathConfig.removePathLeaf (pathConfig.convertPathToAbsolute rend.output_splitFileName))
						if maxver[1] >= 23000 then
						(
							downloadPath = (pathConfig.removePathLeaf (pathConfig.convertPathToAbsolute oldRendOutPath))
						)
					)
				)
			)
		)
		catch()
		if mrendOutputFilename[rendOutputFilename.count] == "\\" then
		(
			saveExt = getFilenameType rendOutputFilename
			mrendOutputFilename = mrendOutputFilename + "output" + saveExt
		)
		TIF.setCompression #packBits

		if ZipFile == undefined then
			makeDir (pathConfig.appendPath fPath "output") all:true
		else
		(
			entry = ZipFile.AddStringAsFile "Output of this project will be in this directory" "outputdir.txt" (dlg_main.m_userName+"/output")
		)

		try(if exrio != undefined do exrio.SetSaveCompressionType 3) catch()
		try(if fopenexr != undefined do fopenexr.SetCompression 3) catch()


		-- settingsToWrite = "[region]\n"
		settingsToWrite += "user="+dlg_main.m_userName+"\n"
		settingsToWrite += "decimal="
		if  getLanguageSettings() == "." then
			settingsToWrite += "punkt\n"
		else
			settingsToWrite += "komma\n"
		settingsToWrite += "units=0\n"
		settingsToWrite += "program=MAX\n"
		settingsToWrite += "version="
		case of
		(
			((maxversion())[1] >= 16000 and (maxversion())[1] < 17000):
				settingsToWrite+="2014\n"
			((maxversion())[1] >= 17000 and (maxversion())[1] < 18000):
				settingsToWrite+="2015\n"
			((maxversion())[1] >= 18000 and (maxversion())[1] < 19000):
				settingsToWrite+="2016\n"
			((maxversion())[1] >= 19000 and (maxversion())[1] < 20000):
				settingsToWrite+="2017\n"
			((maxversion())[1] >= 20000 and (maxversion())[1] < 21000):
				settingsToWrite+="2018\n"
			((maxversion())[1] >= 21000 and (maxversion())[1] < 22000):
				settingsToWrite+="2019\n"
			((maxversion())[1] >= 22000 and (maxversion())[1] < 23000):
				settingsToWrite+="2020\n"
			((maxversion())[1] >= 23000 and (maxversion())[1] < 24000):
				settingsToWrite+="2021\n"
			((maxversion())[1] >= 24000 and (maxversion())[1] < 25000):
				settingsToWrite+="2022\n"
			((maxversion())[1] >= 25000):
				settingsToWrite+="2023\n"
		)
		settingsToWrite += "renderer=" + dlg_main.getRendererString() + "\n"

		if rendTimeType == 2 then
		(			
			settingsToWrite += "startframe=" + (animationRange.start.frame as integer) as string + "\n" 
			settingsToWrite += "endframe="+    (animationRange.end.frame as integer) as string + "\n"
	    )
		if rendTimeType == 3 then
		(		
			settingsToWrite += "startframe=" + (rendStart.frame as integer) as string + "\n"
			settingsToWrite += "endframe=" + (rendEnd.frame as integer) as string + "\n"
		)
		if rendTimeType == 1 then
		(
			settingsToWrite += "startframe="+ (sliderTime.frame as integer) as string + "\n" 
			settingsToWrite += "endframe="+ (sliderTime.frame as integer) as string + "\n"
		)
		if rendNThFrame != 1 then
			settingsToWrite += "rangestep="+ rendNThFrame as string + "\n"
		gam = "undef"
		if (maxversion())[1] >= 10000 then
		(
			if IDisplayGamma.colorCorrectionMode == #gamma then
				gam = "on"
			else
				gam = "off"
		)
		else
		(
			if dlg_main.isGammaEnabled then
				gam = "on"
			else
				gam = "off"
		)
		settingsToWrite += "gamma=" + gam + "\n"
		settingsToWrite += "gamma_bitmap_in=" + fileInGamma as string + "\n"
		settingsToWrite += "gamma_bitmap_out=" + fileOutGamma as string + "\n"
		fieldren = "off"

		if rendFieldRender then
		(
			if rendFieldOrder == 1 then
				fieldren = "even"
			else
				fieldren = "odd"
		)
		settingsToWrite += "field_order=" + fieldren + "\n"
		settingsToWrite += "pixelaspect=" + renderPixelAspect as string + "\n"

		if isSingleFrameRender() and not isProgressiveRendering() then
			settingsToWrite += "slices=" + (dlg_main.m_slices as string) + "\n"

		settingsToWrite += "resolution=" + (renderWidth as string) + "x" + (renderHeight as string) + "\n"

		sysbit = "32"
		if (is64bitApplication() == TRUE) do sysbit = "64"
		settingsToWrite += "OS=Windows\n"
		settingsToWrite += "Bits="+sysbit+"\n"
		settingsToWrite += "output="+mrendOutputFilename+"\n"
		settingsToWrite += "downloadpath="+downloadPath+"\n"
		settingsToWrite += "sceneInfo="+getSceneInfo()+"\n"
		settingsToWrite += "localRend=2\n"

		if dlg_main.estimateRenderpoints then
		(
			settingsToWrite += "estimationFrames=3\n"
			settingsToWrite += "autostart=1\n"
		)

		if (maxVersion())[1] >= 11000 then
		(
			cam = getActiveCamera()
			if rendUseActiveView == false and rendViewIndex != undefined then -- viewport locked
				cam = viewport.getCamera index:rendViewIndex

			asciify_camera_names()

			oldCamName = newCamName = ""
			if cam == undefined and general_select_camera.cam == undefined then
			(
				--do nothing as it seems he wants to use the current viewport
			)
			else if general_select_camera.cam != undefined then
			(
				if general_select_camera.cam != "Active Viewport" then
				(
					settingsToWrite += "camera=" +general_select_camera.cam +"\n"

					if dlg_main.isVrsceneExport then
					(
						oldViewportType = viewport.getType()
						if oldViewportType == #view_camera then
						(
							oldViewportCamera=viewport.getCamera()
						)
						viewport.setCamera(getNodeByName(newCamName))
					)
				)
			)
			else if cam != undefined then
			(
				settingsToWrite += "camera=" + cam.name +"\n"
			)

			try
			(
				local i=0
				for cam in cameras do
				(
					if classof cam == Targetobject then
						continue

					settingsToWrite += "camera"+i as string+"=" +cam.name+"\n"
					i = i+1
				)
				settingsToWrite += "cameraCount=" +i as string+"\n"
			)
			catch
			(
				format "settings.ms: Camera *** % ***\n" (getCurrentException())
			)
		)
		
		--ItooSoft plugins versions
		local fplite = doesFileExist("$max/plugins/ForestPackLite.dlo")
		local fppro = doesFileExist("$max/plugins/ForestPackPro.dlo")

		local fpversion = 0


		case of
		(
			(fplite == true): fpversion = getFileVersion("$max/plugins/ForestPackLite.dlo") 
			(fppro == true): fpversion = getFileVersion("$max/plugins/ForestPackPro.dlo") 
		)

		if fpversion != 0 then
		(
			local allowedchars = "0123456789."
			for i=1 to fpversion.count do
			(
				if findstring allowedchars fpversion[i] == undefined then
				(
					fpversion = substring fpversion 1 (i-1)
					exit
				)
			)
		)

		if fpversion == 0 then fpversion = 6

		fpversion = fpversion as integer

		local rclite = doesFileExist("$max/plugins/railclonelite.dlo")
		local rcpro = doesFileExist("$max/plugins/railclonepro.dlo")

		local rcversion = 0


		case of
		(
			(rclite == true): rcversion = getFileVersion("$max/plugins/railclonelite.dlo") 
			(rcpro == true): rcversion = getFileVersion("$max/plugins/railclonepro.dlo") 
		)

		if rcversion != 0 then
		(
			local allowedchars = "0123456789."
			for i=1 to rcversion.count do
			(
				if findstring allowedchars rcversion[i] == undefined then
				(
					rcversion = substring rcversion 1 (i-1)
					exit
				)
			)
		)

		if rcversion == 0 then rcversion = 3

		rcversion = rcversion as integer

		if fpversion == 7 then rcversion = 4

		settingsToWrite += "forestpackv=" + fpversion as string +"\n"
		settingsToWrite += "railclonev=" + rcversion as string +"\n"

-- retarget output file paths
		local mrendOutputFilename = ""
		if isSingleFrameRender() then
			mrendOutputFilename = createTemprenderPath dlg_main.m_userName rendOutFilenameChanged
		else
			mrendOutputFilename = createOutputPath dlg_main.m_userName rendOutFilenameChanged

		-- this seems not to be right
		if not dlg_main.isMiExport then
			rendOutputFilename = mrendOutputFilename

		if classof renderers.production == MaxwellRenderer then
		(
			rendOutputFilename = "c:\\logs\\"+rendOutFilenameChanged
		)
		renderElementsMgr = maxOps.GetRenderElementMgr #Production

		for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
		(
			local elempath = renderElementsMgr.GetRenderElementFileName n
			local p = ((pathConfig.removePathLeaf mrendOutputFilename) + "\\" + (pathConfig.stripPathToLeaf (elempath)))

			if not dlg_main.isMiExport then
				renderElementsMgr.SetRenderElementFilename n p

			append oldOutputFiles elempath

			try
			(
				if isSingleFrameRender() then
				(
					local renderelem = renderElementsMgr.GetRenderElement n
					if hasProperty renderelem "vrayVFB" then
						renderelem.vrayVFB = true
				)
			)
			catch
			(
				format "settings.ms: *** % ***\n" (getCurrentException())
			)
		)
-- retarget Cebas PSD-Manager output path
		for i = 1 to numEffects do
		(
			try
			(
				eff = getEffect i
				if getClassName eff == "psd-manager" then
				(
					m_PSDEffect = eff
					oldPSDManagerPath = eff.filename
					eff.filename = ((pathConfig.removePathLeaf mrendOutputFilename) + "\\" + (pathConfig.stripPathToLeaf (oldPSDManagerPath)))
				)
			)
			catch
			(
			)
		)

		if skyatchRender.batchRender.checked then
		(
			batchOutputNames = #()
			local batchRenderCount = 0
			SeparateJobs_section_content = "[SeparateJobs]\n"
			for i=1 to batchRenderMgr.numViews do
			(

				local b = batchRenderMgr.GetView i
				if b.enabled then
				(
					batch_render_section_content = stringstream ""
					batch_render_section_name = "IGNORE_batchrender" + (batchRenderCount as string) + "_" + (b.name as string)

					format "[%]\n" batch_render_section_name to:batch_render_section_content
					-- Preparing to get Batchrendername into RQ for sending this to Deadline
					format "batch=%\n" (b.name as string) to:batch_render_section_content
					if b.overridePreset then
					(
						format "startframe=%  \n" ( (b.startFrame.frame as integer) as string)   to:batch_render_section_content
						format "endframe=%  \n"   ((b.endFrame.frame as integer) as string) to:batch_render_section_content
						format "resolution=%x%\n" (b.width as string) (b.height as string) to:batch_render_section_content
						format "pixelaspect=%\n" (b.pixelAspect as string) to:batch_render_section_content
					)
					if b.camera != undefined then
						format "camera=%\n" (b.camera.name as string) to:batch_render_section_content

					if b.sceneStateName  != "" then
						format "batchrenderSceneStateName=%\n" (b.sceneStateName as string) to:batch_render_section_content

					if b.outputFilename != "" then
						format "downloadpath=%\n" (b.outputFilename as string)  to:batch_render_section_content

					if b.presetFile.count > 0 then
						format "batchrenderPresetFile=%\n" (b.presetFile as string) to:batch_render_section_content

					append batchOutputNames b.outputFilename

					if (filenameFromPath b.outputFilename).count > 0 then
						b.outputFilename = createPath (dlg_main.m_userName + "\\output\\" + dlg_main.changedMaxFile) (filenameFromPath b.outputFilename)

					SeparateJobs_section_content += "section" + (batchRenderCount as string) + "=" + batch_render_section_name + "\n"

					batchRenderCount = batchRenderCount +1

					settingsToWrite += (batch_render_section_content as string) + "\n"
				)

			)
			if batchRenderCount > 0 then
				settingsToWrite += SeparateJobs_section_content + "\n"
		)

	),
	fn postSave zip =
	(

		rendOutputFilename = oldRendOutPath
		renderElementsMgr = maxOps.GetRenderElementMgr #Production
		try
		(
			local camindex=1
			for cam in cameras do
			(
				if cam.name != undefined  then
				(
					if oldCamNames[camindex] != newCamNames[camindex] then
						renameCamera newCamNames[camindex] oldCamNames[camindex]
					camindex = camindex+1
				)
			)
		)
		catch
		(
			format "settings.ms: Camera *** % ***\n" (getCurrentException())
		)

		if dlg_main.isVrsceneExport then
		(
			if oldViewportType != undefined then
			(
				viewport.setType oldViewportType
				if oldViewportType == #view_camera and oldViewportCamera != undefined then
				(
					viewport.setCamera(oldViewportCamera)
				)
			)
		)

		for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
			renderElementsMgr.SetRenderElementFilename n oldOutputFiles[n+1]
		try
		(
			if m_PSDEffect != undefined then
				m_PSDEffect.filename = oldPSDManagerPath
		)
		catch
		()

		if skyatchRender.batchRender.checked then
		(
			local batchRenderCount = 0
			for i=1 to batchRenderMgr.numViews do
			(
				local b = batchRenderMgr.GetView i
				if b.enabled then
				(
					b.outputFilename = batchOutputNames[batchRenderCount+1]
					batchRenderCount = batchRenderCount +1
				)
			)
		)
		renderSceneDialog.commit()
	)
)

struct ValScanline
(
	FORCE_WIREFRAME = 0,
	ANTI_ALIASING = 1,
	FILTER_MAPS = 2,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Default Scanline Renderer";
	),
	fn getIdentifier =
	(
		return #(Default_Scanline_Renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == Default_Scanline_Renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))

			if isSingleFrameRender() then
				append resultList (tr id:10001 index:index validator:val severity:2 message:"Scanline still frame render not yet supported on Render Farm Application")

			if rend.forceWireframe then
				append resultList (tr id:10002 index:index validator:val severity:1 message:"Renderer: \"Force Wireframe\" is activated" flagMoreInfos:true type:FORCE_WIREFRAME)

			if NOT rend.antiAliasing then
				append resultList (tr id:10003 index:index validator:val severity:1 message:"Renderer: Antialiasing is not activated" flagMoreInfos:true type:ANTI_ALIASING)

			if NOT rend.filterMaps then
				append resultList (tr id:10004 index:index validator:val severity:1 message:"Renderer: Filter Maps is not activated" flagMoreInfos:true type:FILTER_MAPS)
		)
		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		case result.type of
		(
			FORCE_WIREFRAME:
			(
				if queryBox "Force Wireframe is enabled. Do you want me to disable it?" beep:false then
				(
					renderers.production.forceWireframe = false
					renderSceneDialog.update()
					resolved = true
				)
			)
			ANTI_ALIASING:
			(
				if queryBox "Antialiasing is disabled. Do you want me to enable it?" beep:false then
				(
					renderers.production.antiAliasing = true
					renderSceneDialog.update()
					resolved = true
				)
			)
			FILTER_MAPS:
			(
				if queryBox "Filter Maps is disabled. Do you want me to enable it?" beep:false then
				(
					renderers.production.filterMaps = true
					renderSceneDialog.update()
					resolved = true
				)
			)
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

fn lc_pass1 fname =
(
	-- seems to be setting the lightccache pass for distributed rendering

	local rend = renderers.production
	if classof renderers.production == vrayrt then
		rend = rend.V_Ray_settings
	--remember old settings
	local oldIrrMode = rend.adv_irradmap_mode
	local oldDontRender = rend.options_dontRenderImage
	local oldrendSaveFile = rendSaveFile
	if oldrendSaveFile == undefined then oldrendSaveFile = ""
	local oldirrshowCalcPhase = rend.gi_irradmap_showCalcPhase
	local oldlcshowCalcPhase = rend.lightcache_showCalcPhase
	local oldsystem_region_x = rend.system_region_x
	local oldsystem_region_y = rend.system_region_y
	local oldlightcache_autoSave = rend.lightcache_autoSave
	local oldlightcache_autoSaveFileName = rend.lightcache_autoSaveFileName
	if oldlightcache_autoSaveFileName == undefined then oldlightcache_autoSaveFileName = ""
	local oldgi_primary_type = rend.gi_primary_type
	local oldgi_irradmap_preset = rend.gi_irradmap_preset
	local oldgi_irradmap_minRate = rend.gi_irradmap_minRate
	local oldgi_irradmap_maxRate = rend.gi_irradmap_maxRate
	local oldadv_irradmap_mode = rend.adv_irradmap_mode
	local oldadv_irradmap_autoSave = rend.adv_irradmap_autoSave
	local oldDisplacement = rend.options_displacement
	local oldlightcache_mode = rend.lightcache_mode
	local oldroutput_rawFileName = rend.output_rawFileName
	if oldroutput_rawFileName == undefined then oldroutput_rawFileName = ""
	local oldoutput_getsetsfrommax = rend.output_getsetsfrommax
	local oldoutput_width = rend.output_width
	local oldoutput_height = rend.output_height
	local oldoutput_on = rend.output_on
	local oldoutput_aspect = rend.output_aspect
	local oldoutput_saveRawFile = rend.output_saveRawFile
	local oldoutput_genrpeview = rend.output_genrpeview
	local oldoutput_useram = rend.output_useram
	local oldoutput_renderType = 0
	try (oldoutput_renderType = rend.output_renderType) catch ()
	local oldoutput_splitgbuffer = rend.output_splitgbuffer
	local oldrenderWidth = renderWidth
	local oldrenderHeight = renderHeight
	local renderElementsMgr = maxOps.GetRenderElementMgr #Production
	local oldGetElementsActive = renderElementsMgr.GetElementsActive()

	--change values for pass1
	rend.adv_irradmap_mode = 0
	rend.options_dontRenderImage = true
	rendSaveFile = false
	rend.gi_irradmap_showCalcPhase = true
	rend.lightcache_showCalcPhase = 1
	rend.system_region_x = 64
	rend.system_region_y = 64
	rend.lightcache_mode = 0
	rend.lightcache_autoSave = true
	if not ((rend.gi_secondary_type == 3 or rend.gi_primary_type == 3) and rend.lightcache_mode == 2) then
	(
		local vlpath = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
		rend.lightcache_autoSaveFileName = vlpath
	)
	if ((rend.gi_primary_type == 0 and rend.gi_secondary_type == 3) or
		(rend.gi_primary_type == 2 and rend.gi_secondary_type == 3) or
		(rend.gi_primary_type == 1 and rend.gi_secondary_type == 3) ) and classof renderers.production == vray then
	(
		rend.gi_primary_type = 0	--set primary to IRR
		rend.gi_irradmap_preset = 0	--preset custom
		rend.gi_irradmap_minRate = -10
		rend.gi_irradmap_maxRate = -10
		rend.adv_irradmap_mode = 0 --single frame
		rend.adv_irradmap_autoSave = false
	)
	rend.output_rawFileName = "c:\\logs\\"+dlg_main.changedMaxFile + ".exr"
	rend.options_displacement = false
	if 	rend.output_on then
	(
		rend.output_getsetsfrommax = false
		rend.output_width = renderWidth
		rend.output_height = renderHeight
		rend.output_aspect = renderPixelAspect
		rend.output_saveRawFile = true
		rend.output_genrpeview = true
		rend.output_useram = false
		if rend.imageSampler_type == 3 then -- progressive
			rend.output_useram = true
		try (rend.output_renderType = 3) catch ()
		rend.output_splitgbuffer = false
	)
	else
	(
		rendSaveFile = false
		renderElementsMgr.SetElementsActive false
	)
	local presetCats = (renderpresets.SaveCategories 0)
	deleteItem presetCats 2
	deleteItem presetCats 3
	renderpresets.Save 0 (fname + "\\" + dlg_main.changedMaxFile + ".lc_pass1.rps") presetCats

	--reset old settings
	rend.adv_irradmap_mode =oldIrrMode
	rend.options_dontRenderImage =oldDontRender
	rendSaveFile =oldrendSaveFile
	rend.gi_irradmap_showCalcPhase =oldirrshowCalcPhase
	rend.lightcache_showCalcPhase =oldlcshowCalcPhase
	rend.system_region_x =oldsystem_region_x
	rend.system_region_y =oldsystem_region_y
	rend.lightcache_autoSave =oldlightcache_autoSave
	if oldlightcache_autoSaveFileName == undefined then
		oldlightcache_autoSaveFileName = ""
	rend.lightcache_autoSaveFileName =oldlightcache_autoSaveFileName
	rend.gi_primary_type =oldgi_primary_type
	rend.gi_irradmap_preset =oldgi_irradmap_preset
	rend.gi_irradmap_minRate =oldgi_irradmap_minRate
	rend.gi_irradmap_maxRate =oldgi_irradmap_maxRate
	rend.adv_irradmap_mode =oldadv_irradmap_mode
	rend.adv_irradmap_autoSave =oldadv_irradmap_autoSave
	rend.options_displacement = oldDisplacement
	rend.lightcache_mode = oldlightcache_mode

	rend.output_getsetsfrommax = oldoutput_getsetsfrommax
	rend.output_width = oldoutput_width
	rend.output_height = oldoutput_height
	rend.output_on = oldoutput_on
	rend.output_aspect = oldoutput_aspect
	rend.output_saveRawFile = oldoutput_saveRawFile
	rend.output_genrpeview = oldoutput_genrpeview
	rend.output_useram = oldoutput_useram
	try (rend.output_renderType = oldoutput_renderType) catch ()
	rend.output_splitgbuffer = oldoutput_splitgbuffer
	renderWidth = oldrenderWidth
	renderHeight = oldrenderHeight
	rend.output_rawFileName = oldroutput_rawFileName
	renderElementsMgr.SetElementsActive oldGetElementsActive

	return (dlg_main.changedMaxFile + ".lc_pass1.rps")
)

fn lc_pass2 fname =
(
	-- seems to be setting the irradiance map pass for disributed rendering

	local rend = renderers.production
	if classof renderers.production == vrayrt then
		rend = rend.V_Ray_settings

	--remember old settings
	local oldadv_irradmap_mode = rend.adv_irradmap_mode
	local oldoptions_dontRenderImage = rend.options_dontRenderImage
	local oldrendSaveFile = rendSaveFile
	if oldrendSaveFile == undefined then oldrendSaveFile = ""
	local oldgi_irradmap_showCalcPhase = rend.gi_irradmap_showCalcPhase
	local oldsystem_region_x = rend.system_region_x
	local oldsystem_region_y = rend.system_region_y
	local oldadv_irradmap_mode = rend.adv_irradmap_mode
	local oldadv_irradmap_autoSave = rend.adv_irradmap_autoSave
	local oldlightcache_mode = rend.lightcache_mode
	local oldadv_irradmap_autoSaveFileName = rend.adv_irradmap_autoSaveFileName
	if oldadv_irradmap_autoSaveFileName == undefined then oldadv_irradmap_autoSaveFileName = ""
	local oldadv_irradmap_autoSave = rend.adv_irradmap_autoSave
	local oldDisplacement = rend.options_displacement
	local oldroutput_rawFileName = rend.output_rawFileName
	if oldroutput_rawFileName == undefined then oldroutput_rawFileName = ""
	local oldlightcache_loadFileName = rend.lightcache_loadFileName
	if oldlightcache_loadFileName == undefined then oldlightcache_loadFileName = ""
	local oldoutput_getsetsfrommax = rend.output_getsetsfrommax
	local oldoutput_width = rend.output_width
	local oldoutput_height = rend.output_height
	local oldoutput_on = rend.output_on
	local oldoutput_aspect = rend.output_aspect
	local oldoutput_saveRawFile = rend.output_saveRawFile
	local oldoutput_genrpeview = rend.output_genrpeview
	local oldoutput_useram = rend.output_useram
	try
	(
		local oldoutput_renderType = rend.output_renderType
	)
	catch
	(
		local oldoutput_renderType = 0
	)
	local oldoutput_splitgbuffer = rend.output_splitgbuffer
	local oldrenderWidth = renderWidth
	local oldrenderHeight = renderHeight
	local renderElementsMgr = maxOps.GetRenderElementMgr #Production
	local oldGetElementsActive = renderElementsMgr.GetElementsActive()




	--change values for pass2
	rend.adv_irradmap_loadFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
	rend.adv_irradmap_mode = 2 -- from file        -- When this mode is set why is there no file set to load?
	rend.options_dontRenderImage = true
	rendSaveFile = false
	rend.gi_irradmap_showCalcPhase = true  -- ; FIXME: Needed? takes longer and is not necessary as nobody can see that.
	rend.gi_irradmap_showCalcPhase = false
	rend.system_region_x = 24
	rend.system_region_y = 24
	if not ((rend.gi_secondary_type == 3 or rend.gi_primary_type == 3) and rend.lightcache_mode == 2) then
	(
		local vlpath = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
		rend.lightcache_autoSaveFileName = vlpath
		rend.lightcache_loadFileName = vlpath
	)
	if not (rend.gi_primary_type == 0 and rend.adv_irradmap_mode ==  2) then -- ; FIXME: How should this ever be true if adv_irradmap_mode = 2 before....
	(
		rend.adv_irradmap_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
	)
	rend.output_rawFileName = "c:\\logs\\" + dlg_main.changedMaxFile + ".exr" -- switched from vrimg to exr due to validate output errors in Deadline
	rend.adv_irradmap_mode = 0
	rend.adv_irradmap_autoSave = true
	rend.lightcache_mode = 2
	rend.options_displacement = false

	if rend.output_on then
	(
		rend.output_getsetsfrommax = false
		rend.output_width = renderWidth
		rend.output_height = renderHeight
		rend.output_aspect = renderPixelAspect
		rend.output_saveRawFile = true
		rend.output_genrpeview = true
		rend.output_useram = false
		if rend.imageSampler_type == 3 then -- progressive
			rend.output_useram = true
		try (rend.output_renderType = 3) catch ()
		rend.output_splitgbuffer = false
	)
	else
	(
		rendSaveFile = false
		renderElementsMgr.SetElementsActive false
	)

	local presetCats = (renderpresets.SaveCategories 0)  -- ; FIXME : Might be dangerous deleting those items by index when user has already set some
	deleteItem presetCats 2
	deleteItem presetCats 3
	renderpresets.Save 0 (fname + "\\" + dlg_main.changedMaxFile + ".lc_pass2.rps") presetCats

	--reset old settings
	rend.adv_irradmap_mode =oldadv_irradmap_mode
	rend.options_dontRenderImage =oldoptions_dontRenderImage
	rendSaveFile =oldrendSaveFile
	rend.gi_irradmap_showCalcPhase =oldgi_irradmap_showCalcPhase
	rend.system_region_x =oldsystem_region_x
	rend.system_region_y =oldsystem_region_y
	rend.adv_irradmap_autoSave =oldadv_irradmap_autoSave
	rend.lightcache_mode = oldlightcache_mode
	if oldadv_irradmap_autoSaveFileName == undefined then
		oldadv_irradmap_autoSaveFileName = ""
	rend.adv_irradmap_autoSaveFileName  = oldadv_irradmap_autoSaveFileName
	rend.options_displacement = oldDisplacement
	rend.lightcache_loadFileName = oldlightcache_loadFileName
	rend.output_getsetsfrommax = oldoutput_getsetsfrommax
	rend.output_width = oldoutput_width
	rend.output_height = oldoutput_height
	rend.output_on = oldoutput_on
	rend.output_aspect = oldoutput_aspect
	rend.output_saveRawFile = oldoutput_saveRawFile
	rend.output_genrpeview = oldoutput_genrpeview
	rend.output_useram = oldoutput_useram
	try (rend.output_renderType = oldoutput_renderType) catch ()
	rend.output_splitgbuffer = oldoutput_splitgbuffer
	renderWidth = oldrenderWidth
	renderHeight = oldrenderHeight
	rend.output_rawFileName = oldroutput_rawFileName
	renderElementsMgr.SetElementsActive oldGetElementsActive
	return (dlg_main.changedMaxFile + ".lc_pass2.rps")
)

fn lc_pass4 fname =
(
	local rend = renderers.production
	if classof renderers.production == vrayrt then
		rend = rend.V_Ray_settings

	--remember old settings
	local oldadv_irradmap_mode =rend.adv_irradmap_mode
	local oldsystem_region_x = rend.system_region_x
	local oldsystem_region_y = rend.system_region_y

	--change values for pass2
	rend.adv_irradmap_mode = 2
	rend.system_region_x = 24
	rend.system_region_y = 24
	local presetCats = (renderpresets.SaveCategories 0)
	deleteItem presetCats 2
	deleteItem presetCats 3
	renderpresets.Save 0 (fname + "\\" + dlg_main.changedMaxFile + ".lc_pass4.rps") presetCats


	--reset old settings
	rend.adv_irradmap_mode = oldadv_irradmap_mode
	rend.system_region_x = oldsystem_region_x
	rend.system_region_y = oldsystem_region_y
	return (dlg_main.changedMaxFile + ".lc_pass4.rps")
)

fn irrlc_pass1 fname =
(
	local rend = renderers.production
	if classof renderers.production == vrayrt then
		rend = rend.V_Ray_settings
	--remember old settings
	local oldIrrMode = rend.adv_irradmap_mode
	local oldDontRender = rend.options_dontRenderImage
	local oldrendSaveFile = rendSaveFile
	if oldrendSaveFile == undefined then oldrendSaveFile = ""
	local oldirrshowCalcPhase = rend.gi_irradmap_showCalcPhase
	local oldlcshowCalcPhase = rend.lightcache_showCalcPhase
	local oldsystem_region_x = rend.system_region_x
	local oldsystem_region_y = rend.system_region_y
	local oldlightcache_autoSave = rend.lightcache_autoSave
	local oldlightcache_autoSaveFileName = rend.lightcache_autoSaveFileName
	if oldlightcache_autoSaveFileName == undefined then oldlightcache_autoSaveFileName = ""
	local oldgi_primary_type = rend.gi_primary_type
	local oldgi_irradmap_preset = rend.gi_irradmap_preset
	local oldgi_irradmap_minRate = rend.gi_irradmap_minRate
	local oldgi_irradmap_maxRate = rend.gi_irradmap_maxRate
	local oldadv_irradmap_mode = rend.adv_irradmap_mode
	local oldadv_irradmap_autoSave = rend.adv_irradmap_autoSave
	local oldDisplacement = rend.options_displacement
	local oldlightcache_mode = rend.lightcache_mode
	local oldroutput_rawFileName = rend.output_rawFileName
	if oldroutput_rawFileName == undefined then oldroutput_rawFileName = ""
	local oldoutput_getsetsfrommax = rend.output_getsetsfrommax
	local oldoutput_width = rend.output_width
	local oldoutput_height = rend.output_height
	local oldoutput_on = rend.output_on
	local oldoutput_aspect = rend.output_aspect
	local oldoutput_saveRawFile = rend.output_saveRawFile
	local oldoutput_genrpeview = rend.output_genrpeview
	local oldoutput_useram = rend.output_useram
	local oldoutput_renderType = 0
	try (oldoutput_renderType = rend.output_renderType) catch ()
	local oldoutput_splitgbuffer = rend.output_splitgbuffer
	local oldrenderWidth = renderWidth
	local oldrenderHeight = renderHeight
	local oldRenderelementsActive = false
	local oldLightcache_numPasses = rend.lightcache_numPasses

	--change values for pass1
	rend.adv_irradmap_mode = 0
	rend.options_dontRenderImage = true
	rendSaveFile = false
	rend.gi_irradmap_showCalcPhase = true
	rend.lightcache_showCalcPhase = 1
	rend.lightcache_mode = 1
	rend.lightcache_autoSave = true
	if not ((rend.gi_secondary_type == 3 or rend.gi_primary_type == 3) and rend.lightcache_mode == 2) then
	(
		local vlpath = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
		rend.lightcache_autoSaveFileName = vlpath
	)
	if (rend.gi_primary_type == 0 and rend.gi_secondary_type == 3) then
	(
		rend.gi_primary_type = 0	--set primary to IRR
		rend.gi_irradmap_preset = 0	--preset custom
		rend.gi_irradmap_minRate = -10
		rend.gi_irradmap_maxRate = -10
		rend.adv_irradmap_mode = 0 --single frame
		rend.adv_irradmap_autoSave = false
	)
	rend.output_rawFileName = "c:\\logs\\"+dlg_main.changedMaxFile + ".exr"
	rend.options_displacement = false
	rend.output_getsetsfrommax = false
	rend.output_width = renderWidth
	rend.output_height = renderHeight
	rend.output_on = false
	rend.output_aspect = renderPixelAspect
	rend.output_saveRawFile = false
	rend.output_genrpeview = true
	rend.output_useram = false
	try (rend.output_renderType = 3) catch ()
	rend.output_splitgbuffer = false
	rend.lightcache_numPasses = 24

	local rm = MaxOps.GetCurRenderElementMgr()
	oldRenderelementsActive = rm.GetElementsActive()
	rm.SetElementsActive(false)

	local presetCats = (renderpresets.SaveCategories 0)
	deleteItem presetCats 2
	deleteItem presetCats 3
	renderpresets.Save 0 (fname + "\\" + dlg_main.changedMaxFile + ".irrlc_pass1.rps") presetCats

	--reset old settings
	rend.lightcache_numPasses = oldLightcache_numPasses
	rm.SetElementsActive(oldRenderelementsActive)
	rend.adv_irradmap_mode =oldIrrMode
	rend.options_dontRenderImage =oldDontRender
	rendSaveFile =oldrendSaveFile
	rend.gi_irradmap_showCalcPhase =oldirrshowCalcPhase
	rend.lightcache_showCalcPhase =oldlcshowCalcPhase
	rend.system_region_x =oldsystem_region_x
	rend.system_region_y =oldsystem_region_y
	rend.lightcache_autoSave =oldlightcache_autoSave
	if oldlightcache_autoSaveFileName == undefined then
		oldlightcache_autoSaveFileName = ""
	rend.lightcache_autoSaveFileName =oldlightcache_autoSaveFileName
	rend.gi_primary_type =oldgi_primary_type
	rend.gi_irradmap_preset =oldgi_irradmap_preset
	rend.gi_irradmap_minRate =oldgi_irradmap_minRate
	rend.gi_irradmap_maxRate =oldgi_irradmap_maxRate
	rend.adv_irradmap_mode =oldadv_irradmap_mode
	rend.adv_irradmap_autoSave =oldadv_irradmap_autoSave
	rend.options_displacement = oldDisplacement
	rend.lightcache_mode = oldlightcache_mode

	rend.output_getsetsfrommax = oldoutput_getsetsfrommax
	rend.output_width = oldoutput_width
	rend.output_height = oldoutput_height
	rend.output_on = oldoutput_on
	rend.output_aspect = oldoutput_aspect
	rend.output_saveRawFile = oldoutput_saveRawFile
	rend.output_genrpeview = oldoutput_genrpeview
	rend.output_useram = oldoutput_useram
	try (rend.output_renderType = oldoutput_renderType) catch ()
	rend.output_splitgbuffer = oldoutput_splitgbuffer
	rend.output_rawFileName = oldroutput_rawFileName
	return (dlg_main.changedMaxFile + ".irrlc_pass1.rps")
)

fn irrlc_pass2 fname =
(
	local rend = renderers.production
	if classof renderers.production == vrayrt then
		rend = rend.V_Ray_settings

	--remember old settings
	local oldadv_irradmap_mode = rend.adv_irradmap_mode
	local oldoptions_dontRenderImage = rend.options_dontRenderImage
	local oldrendSaveFile = rendSaveFile
	if oldrendSaveFile == undefined then oldrendSaveFile = ""
	local oldgi_irradmap_showCalcPhase = rend.gi_irradmap_showCalcPhase
	local oldsystem_region_x = rend.system_region_x
	local oldsystem_region_y = rend.system_region_y
	local oldadv_irradmap_mode = rend.adv_irradmap_mode
	local oldadv_irradmap_autoSave = rend.adv_irradmap_autoSave
	local oldlightcache_mode = rend.lightcache_mode
	local oldadv_irradmap_autoSaveFileName = rend.adv_irradmap_autoSaveFileName
	if oldadv_irradmap_autoSaveFileName == undefined then oldadv_irradmap_autoSaveFileName = ""
	local oldadv_irradmap_autoSave = rend.adv_irradmap_autoSave
	local oldDisplacement = rend.options_displacement
	local oldroutput_rawFileName = rend.output_rawFileName
	if oldroutput_rawFileName == undefined then oldroutput_rawFileName = ""
	local oldlightcache_loadFileName = rend.lightcache_loadFileName
	if oldlightcache_loadFileName == undefined then oldlightcache_loadFileName = ""
	local oldoutput_getsetsfrommax = rend.output_getsetsfrommax
	local oldoutput_width = rend.output_width
	local oldoutput_height = rend.output_height
	local oldoutput_on = rend.output_on
	local oldoutput_aspect = rend.output_aspect
	local oldoutput_saveRawFile = rend.output_saveRawFile
	local oldoutput_genrpeview = rend.output_genrpeview
	local oldoutput_useram = rend.output_useram
	local oldoutput_renderType = 0
	try (oldoutput_renderType = rend.output_renderType) catch ()
	local oldoutput_splitgbuffer = rend.output_splitgbuffer
	local oldrenderWidth = renderWidth
	local oldrenderHeight = renderHeight
	local oldRenderelementsActive = false

	--change values for pass2
	rend.adv_irradmap_mode = 1 -- from file
	rend.options_dontRenderImage = true
	rendSaveFile = false
	rend.gi_irradmap_showCalcPhase = true
	if not ((rend.gi_secondary_type == 3 or rend.gi_primary_type == 3) and rend.lightcache_mode == 2) then
	(
		local vlpath = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
		rend.lightcache_autoSaveFileName = vlpath
		rend.lightcache_loadFileName = vlpath
	)
	rend.adv_irradmap_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")

	rend.output_rawFileName = "c:\\logs\\"+dlg_main.changedMaxFile + ".exr"
	rend.adv_irradmap_mode = 1
	rend.adv_irradmap_autoSave = true
	rend.lightcache_mode = 2
	rend.options_displacement = false

	rend.output_getsetsfrommax = false
	rend.output_width = renderWidth
	rend.output_height = renderHeight
	rend.output_on = false
	rend.output_aspect = renderPixelAspect
	rend.output_saveRawFile = false
	rend.output_genrpeview = true
	rend.output_useram = false
	try (rend.output_renderType = 3) catch ()
	rend.output_splitgbuffer = false

	local rm = MaxOps.GetCurRenderElementMgr()
	oldRenderelementsActive = rm.GetElementsActive()
	rm.SetElementsActive(false)

	local presetCats = (renderpresets.SaveCategories 0)
	deleteItem presetCats 2
	deleteItem presetCats 3
	renderpresets.Save 0 (fname + "\\" + dlg_main.changedMaxFile + ".irrlc_pass2.rps") presetCats

	--reset old settings
	rm.SetElementsActive(oldRenderelementsActive)
	rend.adv_irradmap_mode =oldadv_irradmap_mode
	rend.options_dontRenderImage =oldoptions_dontRenderImage
	rendSaveFile =oldrendSaveFile
	rend.gi_irradmap_showCalcPhase =oldgi_irradmap_showCalcPhase
	rend.system_region_x =oldsystem_region_x
	rend.system_region_y =oldsystem_region_y
	rend.adv_irradmap_autoSave =oldadv_irradmap_autoSave
	rend.lightcache_mode = oldlightcache_mode
	if oldadv_irradmap_autoSaveFileName == undefined then
		oldadv_irradmap_autoSaveFileName = ""
	rend.adv_irradmap_autoSaveFileName  = oldadv_irradmap_autoSaveFileName
	rend.options_displacement = oldDisplacement
	rend.lightcache_loadFileName = oldlightcache_loadFileName
	rend.output_getsetsfrommax = oldoutput_getsetsfrommax
	rend.output_width = oldoutput_width
	rend.output_height = oldoutput_height
	rend.output_on = oldoutput_on
	rend.output_aspect = oldoutput_aspect
	rend.output_saveRawFile = oldoutput_saveRawFile
	rend.output_genrpeview = oldoutput_genrpeview
	rend.output_useram = oldoutput_useram
	try (rend.output_renderType = oldoutput_renderType) catch ()
	rend.output_splitgbuffer = oldoutput_splitgbuffer
	rend.output_rawFileName = oldroutput_rawFileName
	return (dlg_main.changedMaxFile + ".irrlc_pass2.rps")
)

vray_maxrp_dlg_maxPasses = -1
vray_maxrp_dlg_noiseThreshold = -1
rollout vray_maxrp_dlg "Choose your Progressive settings" width:550 height:280
(

	local distributedMachines = 25

	EditText lblCamera text:"" height:150 readOnly:true

	Spinner spPasses "Max subdivs:" range:[1,10000,1] type:#integer
	Spinner spNoise "Noise threshold:" range:[0,10000,0.005] type:#float scale:0.01
	Button btnOk "Ok" align:#right
	Button btnCancel "Cancel" align:#right

	on vray_maxrp_dlg open do
	(
		lblCamera.text = "Choose your settings here to overwrite the ending criteria form your scene.

You can input the Max. subdivs to use and the noise level to be reached.
The rendering will stop if either of these is reached.

Stopping after selected time or after Renderpoint Limit is reached is currently not possible.
"

		if isSingleFrameRender() or not hasProperty renderers.production "progressive_noise_threshold" then
		(
		lblCamera.text = "Choose your settings here to overwrite the ending criteria form your scene.

The rendering stops if the Max. subidvs are reached.

Stopping after selected time or after Renderpoint Limit is reached is currently not possible.
"
			spNoise.visible = false
			spPasses.range= [25,10000,25]
		)
		else
			spPasses.range= [1,10000,1]

		rend = renderers.production
		if hasProperty rend "progressive_noise_threshold" then
		(
			vray_maxrp_dlg_noiseThreshold = spNoise.value = rend.progressive_noise_threshold
		)
		if classof renderers.production == vrayrt then
		(
			-- rend = rend.V_Ray_settings
			vray_maxrp_dlg_maxPasses = spPasses.value = rend.max_paths_per_pixel

			if isSingleFrameRender() and spPasses.value < 25 then
				spPasses.value = 25
		)
		else
		(
			vray_maxrp_dlg_maxPasses = spPasses.value = rend.progressive_maxSamples

			if isSingleFrameRender() and spPasses.value < 25 then
				spPasses.value = 25
		)
	)

	on spNoise changed val inSpin_arg do
	(
		if hasProperty renderers.production "progressive_noise_threshold" then
		(
			vray_maxrp_dlg_noiseThreshold = renderers.production.progressive_noise_threshold = spNoise.value
		)
	)

	on spPasses changed val inSpin_arg do
	(
		if classof renderers.production == vrayrt then
		(
			if isSingleFrameRender() and val < 25 then
				spPasses.value = 25
		)
		else
		(
			if isSingleFrameRender() and spPasses.value < 25 then
				spPasses.value = 25
		)

		if hasProperty renderers.production "progressive_maxSamples" then
		(
			vray_maxrp_dlg_maxPasses = renderers.production.progressive_maxSamples = spPasses.value
		)
	)

	on btnOk pressed do
	(
		vray_maxrp_dlg_maxPasses = spPasses.value
		vray_maxrp_dlg_noiseThreshold = spNoise.value
		DestroyDialog vray_maxrp_dlg
	)
	on btnCancel pressed do
	(
		DestroyDialog vray_maxrp_dlg
	)
)


rollout vray_gpu_dlg "Do you want to render on GPU or on CPU" width:380 height:60
(
	local gpu = false
	local confirmed = false

	Button btnGPU "GPU" pos:[130, 20]
	Button btnCPU "CPU" pos:[210, 20]

	on vray_gpu_dlg open do
	(
	)

	on btnGPU pressed do
	(
		gpu = true
		confirmed = true
		DestroyDialog vray_gpu_dlg
	)

	on btnCPU pressed do
	(
		gpu = false
		confirmed = true
		DestroyDialog vray_gpu_dlg
	)
)


struct ValVray
(
	GI_PHOTON_MAP_NEW = 1,
	GI_PHOTON_MAP_FILE = 2,
	GI_LIGHTCACHE_SINGLE = 3,
	GI_LIGHTCACHE_PATH = 4,
	GI_LIGHTCACHE_FLY = 5,
	GI_IRRADIANCE_SINGLE = 6,
	GI_IRRADIANCE_MULTI = 7,
	GI_IRRADIANCE_BUCKET = 8,
	CAUSTICS_NEW_MAP = 9,
	CAUSTICS_FROM_FILE = 10,
	INTERPOLATION_MAT = 11,
	GI_LIGHTCACHE_DISTRIBUTED = 12,
	GI_IRRADIANCE_DISTRIBUTED = 13,
	INTERPOLATION_MAT_SINGLE = 14,
	GI_IRRADIANCE_PREPASS = 15,
	GI_IRRADIANCE_FROMFILE = 16,
	GI_IRRADIANCE_ANIMRENDER = 17,
	GI_LIGHTCACHE_FROMFILE = 18,
	MAX_RP_DIALOG = 19,
	BAD_VRAY_VERSION = 20,
	REPLACE_RAYTRACE_MAT = 21,
	PHOENIX_FD_NOT_FOUND = 22,
	REPLACE_RAYTRACE_MAP = 23,
	USE_PROGRESSIVE = 24,
	GPU_DIALOG = 25,
	VRAYVOLUMEGRID_NOT_FOUND = 26,
	VRAY_STANDALONE = 27,
	SHOW_GI_ONLY = 28,
	GLOSSY_EFFECTS = 29,
	AUTOSAVE_LC = 30,
	AUTOSAVE_IRR = 31,
	AUTOSAVE_CAUSTICS = 32,
	RT_VRSCENE = 33,
	RT_DONT_RENDER = 34,
	RT_DISTRIBUTED = 35,


	oldcauFilename = "",
	oldphFilename = "",
	oldRenderType = #view,

	oldVRoutput_getsetsfrommax = "",
	oldVRoutput_width = "",
	oldVRoutput_height = "",
	oldVRoutput_on = "",
	oldVRoutput_aspect = "",
	oldVRoutput_saveRawFile = "",
	oldVRoutput_genpreview = "",
	oldVRoutput_useram = "",
	oldVRoutput_renderType = "",
	oldVRoutput_splitgbuffer = "",
	oldVRrenderWidth = "",
	oldVRrenderHeight = "",
	oldVRrendSaveFile = "",
	oldVRrendShowVFB = "",
	oldVRoutput_rawFileName = "",
	oldRegionX = 0,
	oldRegionY = 0,
	oldIrrAutoSaveFilename = "",
	oldIrrLoadFilename = "",
	oldIrrMode = "",
	oldLCAutoSaveFilename = "",
	oldLCLoadFilename = "",
	oldLCMode = "",
	oldSystemRegionMeaning = "",
	oldVRoutput_splitFileName = "",
	irrPrepassSet = false,
	oldNumThreads = 0,
	oldgi_irradmap_showCalcPhase = false,
	oldlightcache_showCalcPhase = 0,
	oldlightcache_numPasses = 0,
	oldLensFiles = #(),
	oldgi_irradmap_multipleViews =false,
	oldlightcache_multipleViews = false,

	oldprogressive_max_render_time = 0,
	oldprogressive_maxSamples =  0,
	olddmc_timeDependent = true,
	olddmc_lockNoisePattern = true,

	distributedMachines = 25,

	shademapfiles = #(),
	shademaprendering = false,
	vrayIrrMulti = true,

	oldPhoenixSimulatorPaths = #(),
	oldPhoenixSimulatorOutputPaths = #(),
	oldVRayVolumeGridPaths = #(),
	oldVRayScannedMtl = #(),

	oldGlareImage = undefined,
	oldGlareObstacleImage = undefined,

	vrsceneExport = false,
	vrsceneTemp = "",
	vrsceneCheckResult = #(),

	is_renderer_validator = true,

	fn findIrrFiles rend start:0 end:0=
	(
		local irrpath = rend.adv_irradmap_loadFileName
		local irrFiles = #()
		if irrpath != undefined and irrpath.count > 6 and matchPattern irrpath pattern:"*.vrmap" then
		(
			irrpath = (substring irrpath 1 (irrpath.count - 6)) + "*.vrmap"
			irrFiles = getFiles irrpath
			local i = irrFiles.count
			while i > 0 do
			(
				irrFile = irrFiles[i]
				bFound = false
				for j=start to end do
				(
					if findString irrFile ((j as string)+".") != undefined then
						bFound = true
				)
				if not bFound then
					deleteItem irrFiles i
				i=i-1
			)
		)
		return irrFiles
	),

	fn findVray3XmlPaths xmlPath =
	(
		dotNet.loadAssembly "system.xml"
		local assets = #()
		local xmldoc = dotnetobject "System.XML.XMLDocument"
		xmldoc.load xmlPath

		local itemIter = (xmldoc.selectnodes "//Asset/plugin/vrayplugin[@type='bitmap']/parameters/parameter[@name='file']").GetEnumerator()
		while itemIter.MoveNext() do
		(
			local assetPath = itemIter.Current.ChildNodes.itemOf[0].InnerText
			append assets assetPath
		)
		return assets
	),

	fn hasLinearWorkflow =
	(
		local bLinEnabled = false
		try
		(
			local b = renderers.production.colorMapping_linearWorkflow
			if b then
				bLinEnabled = true
		)
		catch()
		return bLinEnabled
	),

	fn getProgressivePasses =
	(
		if vray_maxrp_dlg_maxPasses != undefined and vray_maxrp_dlg_maxPasses > 0 then
			return vray_maxrp_dlg_maxPasses

		if classof renderers.production == vrayrt then
			return renderers.production.max_paths_per_pixel
		else
			return renderers.production.progressive_maxSamples
	),

	fn getProgressiveThreshold =
	(
		if vray_maxrp_dlg_noiseThreshold != undefined and vray_maxrp_dlg_noiseThreshold > 0 then
			return vray_maxrp_dlg_noiseThreshold

		if hasProperty renderers.production "progressive_noise_threshold" then
			return renderers.production.progressive_noise_threshold
		return 0
	),

	fn exportVrscene vrscenepath lStartframe lEndframe =
	(
		if vrayExportRTScene == undefined then
		(
			print "vrayExportRTScene not found"
			return false
		)
		local enabledVRActiveShade = ((renderers.activeShade.classid[1] == 1770671000) and (renderers.activeShade.classid[2] == 1323107829))
		if (not enabledVRActiveShade) do renderers.activeShade=VRayRT()

		local res = false
		if lStartframe == lEndframe then
			res = vrayExportRTScene vrscenepath exportCompressed:true exportHEXFormatMesh:true exportHEXFormatTransf:true separateFiles:false prefix:"" stripPaths:false
		else
			res = vrayExportRTScene vrscenepath exportCompressed:true exportHEXFormatMesh:true exportHEXFormatTransf:true separateFiles:false prefix:"" startFrame:lStartframe endFrame:lEndframe stripPaths:false
		print res
		return res
	),

	fn exec exe args =
	(
		local p = dotNetObject "System.Diagnostics.Process"
		p.StartInfo.UseShellExecute = false
		p.StartInfo.RedirectStandardOutput = true
		p.StartInfo.CreateNoWindow = true
		p.StartInfo.FileName = exe
		p.StartInfo.Arguments = args
		p.Start()
		local stoutput = p.StandardOutput.ReadToEnd()
		p.WaitForExit()
		return stoutput
	),

	fn checkVrscene vrscenepath vrsceneparser =
	(
		local searchPaths = #()
		append searchPaths (trimRight maxfilepath "\\")
		local stSearchPaths = ""
		for f in searchPaths do
			stSearchPaths = stSearchPaths + " -s \"" + f + "\""

		local stoutput = exec vrsceneparser ("passX4f -i \""+vrscenepath+"\" "+stSearchPaths+" -t check")

		local keyval = #()
		local vOut = filterstring stoutput "\n" splitEmptyTokens:false
		for i=1 to vOut.count do
		(
			try
			(
				local entry = filterString vOut[i] "|"
				local key = entry[1]
				local val = (substring entry[2] 1 (entry[2].count-1))
				append keyval #(key, val)
			)
			catch
			(
				return undefined
			)
		)
		return keyval
	),

	fn changeVrscene vrscenepath vrsceneparser texPath outPath =
	(
		local changeParams = #()
		local changeOrCreateParams = #()

		try
		(
			local rend = renderers.production
			local cam = getActiveCamera()
			try
			(
				if cam != undefined and cam.orthoProjection then
					append changeParams #("RenderView",  "orthographic", "1")
			)catch()

			if rend.filter_on then --due to chaosgroup bug #927061
			(
				if classof rend.filter_kernel == VRayLanczosFilter then
					append changeOrCreateParams #("FilterLanczos",  "aaFilter", "size", rend.filter_size as string)
				if classof rend.filter_kernel == VRaySincFilter then
					append changeOrCreateParams #("FilterSinc",  "aaFilter", "size", rend.filter_size as string)
				if classof rend.filter_kernel == VRayBoxFilter then
					append changeOrCreateParams #("FilterBox",  "aaFilter", "size", rend.filter_size as string)
				if classof rend.filter_kernel == VRayTriangleFilter then
					append changeOrCreateParams #("FilterTriangle",  "aaFilter", "size", rend.filter_size as string)
				if classof rend.filter_kernel == VRayMitNetFilter then
					append changeOrCreateParams #("FilterMitNet",  "aaFilter", "size", rend.filter_size as string)
				if classof rend.filter_kernel == Cook_Variable then
					append changeOrCreateParams #("FilterCookVariable",  "aaFilter", "size", rend.filter_size as string)
				if classof rend.filter_kernel == Area then
					append changeOrCreateParams #("FilterArea",  "aaFilter", "size", rend.filter_size as string)
			)
			else
			(
				append changeOrCreateParams #("FilterTriangle",  "aaFilter", "size", "1")
			)

			local saveExt = getFilenameType rendOutputFilename
			if saveExt == ".png" then
			(
				if pngio.getAlpha() == false then
					append changeParams #("SettingsOutput",  "img_noAlpha", "1")
				if pngio.getType() == #true24 then
					append changeOrCreateParams #("SettingsPNG",  "output_settings_png", "bits_per_channel", "8")
				if pngio.getType() == #true48 then
					append changeOrCreateParams #("SettingsPNG",  "output_settings_png", "bits_per_channel", "16")
			)
			if saveExt == ".tif" then
			(
				if TIF.getAlpha() == #false then
					append changeParams #("SettingsOutput",  "img_noAlpha", "1")
				if TIF.getType() == #color then
					append changeOrCreateParams #("SettingsTIFF",  "output_settings_tiff", "bits_per_channel", "8")
				if TIF.getType() == #logL or TIF.getType() == #color16 then
					append changeOrCreateParams #("SettingsTIFF",  "output_settings_tiff", "bits_per_channel", "16")
			)

			local startframe = 1
			local endframe = 1
			if rendTimeType == 2 then
			(
				startframe = animationRange.start.frame as integer
				endframe = animationRange.end.frame as integer
			)
			if rendTimeType == 3 then
			(
				startframe = rendStart.frame as integer
				endframe = rendEnd.frame as integer
			)
			--there seems to be a bug in vray version 3.20 that does not export these settings. But these seem to be needed so camera animation works
			append changeParams #("SettingsOutput",  "anim_start", startframe as string)
			append changeParams #("SettingsOutput",  "anim_end", endframe as string)
			append changeParams #("SettingsOutput",  "frame_start", startframe as string)
		)
		catch
		(
			format "vray.ms:changeVrscene *** % ***\n" (getCurrentException())
		)

		local stChange = ""
		for p in changeParams do
			stChange = stChange + " -so " + p[1] + ":" + p[2] + "=" + p[3]
		for p in changeOrCreateParams do
			stChange = stChange + " -soc " + p[1] + "," + p[2] + ":" + p[3] + "=" + p[4]

		local searchPaths = #()
		append searchPaths (trimRight maxfilepath "\\")
		local stSearchPaths = ""
		for f in searchPaths do
			stSearchPaths = stSearchPaths + " -s \"" + f + "\""

		exec vrsceneparser ("passX4f -i \""+vrscenepath+"\" "+stSearchPaths+ " -t change -ro \""+outPath+"\" -rt \""+texPath+"\"" + stChange)
	),


	fn getName name:"" =
	(
		name = "Vray";
	),

	fn getIdentifier =
	(
		return #(vray, vrayrt)
	),

	originalMats = #(),
	replacedMats = #(),

	fn replaceMat oldMat newMat =
	(
		print ("Replacing " + (oldMat as string) + " with " + (newMat as string))
		replaceinstances oldMat newMat
		append originalMats oldMat
		append replacedMats newMat
	),

	fn restoreMats =
	(
		for i = 1 to originalMats.count do
		(
			print ("Resetting " + (replacedMats[i] as string) + " with " + (originalMats[i] as string))
			replaceinstances replacedMats[i] originalMats[i]
		)
	),

	fn replaceMaterials =
	(
		local mats = getClassInstances Autodesk_material
		for m in mats do
		(
			local mat = undefined
			print m.DefinitionId
			try
			(
			case m.DefinitionId as name of
			(
				#Ceramic : mat = vraymtl  name:m.name Diffuse:m.Ceramic_Color  Reflection:(color 200 200 200) reflection_glossiness: 0.85 reflection_subdivs: 16 reflection_fresnel: on reflection_lockIOR:off reflection_ior: 1.8
				#Concrete : mat = vraymtl name:m.name Diffuse:(color 120 120 120)
				#Generic :  mat = vraymtl name:m.name Diffuse:m.Generic_Color
				#Glazing : mat = vraymtl name:m.name Diffuse:(color 0 0 0) reflection:(color 255 255 255) refraction:(color 255 255 255) reflection_fresnel: on refraction_ior: 1.52 refraction_fogColor: (color 234 252 247) refraction_fogMult: 5 option_traceReflection:on option_doubleSided:on option_reflectOnBack: on
				#Hardwood : mat = vraymtl name:m.name textmap_diffuse:m.wood_image
				#MasonryCMU : mat = vraymtl name:m.name Diffuse:m.Masonry_Color
				#Metal : mat = vraymtl name:m.name Diffuse:(color 156 156 156)
				#MetallicPaint : mat = vraymtl name:m.name Diffuse:m.Metallic_Paint_Color
				#Mirror : mat = vraymtl name:m.name Diffuse:m.Mirror_Tint_Color reflection:(color 255 255 255) refraction:(color 0 0 0) reflection_fresnel: on refraction_ior: 0.0  option_traceReflection:on option_doubleSided:on option_reflectOnBack: on
				#PlasticVinyl : mat = vraymtl name:m.name Diffuse:(color 177 177 177)
				#Solidglass : mat = vraymtl name:m.name Diffuse:(color 0 0 0) reflection:(color 255 255 255) refraction:(color 255 255 255) reflection_fresnel: on refraction_ior:m.Solid_Glass_Refraction refraction_fogColor: (color 234 252 247) refraction_fogMult: 5 option_traceReflection:on option_doubleSided:on option_reflectOnBack: on
				#Stone : mat = vraymtl name:m.name Diffuse:(color 120 120 120)
				#WallPaint : mat = vraymtl name:m.name  Diffuse:m.Wall_Paint_Color
				#water : mat = vraymtl name:m.name Diffuse:(color 1 7 36) reflection:(color 255 255 255) refraction:(color 176 176 176) reflection_fresnel: on refraction_ior: 1.1
			)
			if mat == undefined then
				mat = VRayMtl name:m.name Diffuse:m.ConvertToGeneric.Generic_Color texmap_diffuse:m.ConvertToGeneric.Generic_Image
			)
			catch(format "replaceMaterials: *** % ***\n" (getCurrentException()))
			if mat == undefined then
				mat = VRayMtl()

			replaceMat m mat
		)

		local maps = getClassInstances Autodesk_map
		for m in maps do
		(
			try
			(
				if m.DefinitionId == "UnifiedBitmap" then
				(
					if m.Parameters_Source != undefined then
					(
						local btex = bitmaptexture()
						btex.name = m.name
						btex.bitmap = m.Parameters_Source
						replaceMat m btex
					)
				)
			)
			catch(format "replaceMaterials: *** % ***\n" (getCurrentException()))
		)

	),

	fn preCheckStandalone =
	(
		if classof renderers.production == vray then
		(
			if vrsceneExport then
			(
				dlg_main.isVrsceneExport = true
			)
		)
	),

	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(
		rend = renderers.production
		if dlg_main.isVrsceneExport and classof renderers.production == vray or classof renderers.production == vrayrt then
		(
			if classof renderers.production == vrayrt then
				rend = rend.V_Ray_settings

			local allvalid = true
			local vrparser = pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath) "plugins"
			vrparser = pathConfig.appendPath vrparser "vray"
			vrparser = pathConfig.appendPath vrparser "vrayparser.exe"
			if existsFile vrparser then
			(
				vrsceneTemp = sysInfo.tempdir + (mTimeGetTime() as string) + ".vrscene"

				local startframe = 1
				local endframe = 1
				if rendTimeType == 2 then
				(
					startframe = animationRange.start.frame as integer
					endframe = animationRange.end.frame as integer
				)
				if rendTimeType == 3 then
				(
					startframe = rendStart.frame as integer
					endframe = rendEnd.frame as integer
				)

				originalMats = #()
				replacedMats = #()
				replaceMaterials()
				if (exportVrscene vrsceneTemp startframe endframe) == OK then
				(
					vrsceneCheckResult = #()
					local keyval = checkVrscene vrsceneTemp vrparser
					if keyval != undefined then
					(
						for i=1 to keyval.count do
						(
							if keyval[i][1] == "err" then
							(
								append resultList (tr id:12103 index:index validator:val severity:2 message:("Vrscene: " + keyval[i][2]))
								allvalid = false
							)
							else
								append vrsceneCheckResult keyval[i]
						)
					)
					else
					(
						append resultList (tr id:12103 index:index validator:val severity:2 message:("Unknown error checking vrscene"))
						allvalid = false
					)
				)
				else
				(
					append resultList (tr id:12103 index:index validator:val severity:2 message:("Scene could not be exported to .vrscene"))
					allvalid = false
				)
				restoreMats()

			)
			else
			(
				append resultList (tr id:12103 index:index validator:val severity:2 message:("Please install the Vray plugin in the Render Farm Application settings"))
				allvalid = false
			)

			if allvalid then
			(
				local vrparser = pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath) "plugins"
				vrparser = pathConfig.appendPath vrparser "vray"
				vrparser = pathConfig.appendPath vrparser "vrayparser.exe"
				changeVrscene vrsceneTemp vrparser (createTexPath dlg_main.m_userName "") (createOutputPath dlg_main.m_userName "")

				local dest = fPath + "\\tex\\" + dlg_main.changedMaxFile + ".0000.vrscene"
				deleteFile dest
				renameFile vrsceneTemp dest
				appendFileInfo &vecFiles dest  ("tex/" + (filenameFromPath dest)) tcopy:false
				for i=1 to vrsceneCheckResult.count do
				(
					if vrsceneCheckResult[i][1] == "texfound" or vrsceneCheckResult[i][1] == "vrmeshfound" or vrsceneCheckResult[i][1] == "includefound" then
						appendFileInfo &vecFiles vrsceneCheckResult[i][2]  ("tex/" + filenameFromPath vrsceneCheckResult[i][2])
				)
				settingsToWrite += "singleVrayFile=1\n"
				return true
			)
		)
		return false
	),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof renderers.production == vray or classof renderers.production == vrayrt then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			if classof renderers.production == vrayrt then
				rend = rend.V_Ray_settings

/*			if vrsceneExport then
			(
				dlg_main.isVrsceneExport = true
				append resultList (tr id:12103 index:index validator:val severity:0 message:("Rendering with Vray Standalone, do you want to render in 3ds Max?") flagMoreInfos:true type:VRAY_STANDALONE)

				for i=1 to numAtmospherics do
				(
					local atmo = getAtmospheric i
					if classof atmo == VrayToon and isActive atmo then
						append resultList (tr id:12103 index:index validator:val severity:2 message:("Standalone: VrayToon is not supported with Vray Standalone rendering"))
				)
			)
			else
				append resultList (tr id:12103 index:index validator:val severity:0 message:("Rendering with 3ds Max, do you want to render in Vray Standalone?") flagMoreInfos:true type:VRAY_STANDALONE)
*/
			if not isSingleFrameRender() then
			(
				if rend.output_on then --=="Enable built'in Frame Buffer"
				(
					if rend.output_saveRawFile then
					(
						if rend.output_rawFileName == "" then
						(
							rend.output_rawFileName = getDefaultOutputName "exr"
						)
					)

					if (rend.output_useram and rend.output_splitgbuffer) then
					(
						if rend.output_splitFileName == "" then
							rend.output_splitFileName = getDefaultOutputName "exr"
					)
				)

				try
				(
					local cams = getClassInstancesSave VRayStereoscopic
					for cam in cams do
					(
						if cam.enabled == false then
							continue
						if cam.adjust_resolution then
						(
							append resultList (tr id:12100 index:index validator:val severity:2 message:("VRayStereoscopic: \"adjust resolution\" parameter not allowed, please set the resolution manually in Render Settings."))
							break
						)
					)
				)
				catch()
			)
			else
			(
				local v = myToLower (vray as string)
				if (findstring v "RC3") != undefined then
					append resultList (tr id:12005 index:index validator:val severity:2 message:"distributed render not supported for vrayRC3 - you need RC4 or higher")
				local sssMats = getClassInstancesSave VRayFastSSS
				if sssMats != undefined and rend.imageSampler_type != 3 then
					for m in sssMats do
						append resultList (tr id:12006 index:index validator:val severity:2 message:("Due to technical limitations SubSurfaceScatter materials ("+m.name+") are not supported in distributed rendering.") flagMoreInfos:true type:ONLINE_FAQ)
				sssMats = getClassInstancesSave VRayFastSSS2
				if sssMats != undefined and rend.imageSampler_type != 3 then
					for m in sssMats do
						append resultList (tr id:12006 index:index validator:val severity:2 message:("Due to technical limitations SubSurfaceScatter materials ("+m.name+") are not supported in distributed rendering.") flagMoreInfos:true type:ONLINE_FAQ)

				if rend.output_on and not rend.output_getsetsfrommax then
					append resultList (tr id:12077 index:index validator:val severity:2 message:("Vray Frame buffer: Please enable \"Get resolution from MAX\""))

				if rend.output_saveRawFile and getFilenameType rend.output_rawFileName == ".vrimg" then
					append resultList (tr id:12077 index:index validator:val severity:2 message:("Vray Frame buffer: VRIMG is currently not supported with distributed rendering please use EXR instead"))

				if not getrendertype() == #view and rend.imageSampler_type != 3 then
					append resultList (tr id:12008 index:index validator:val severity:2 message:("Rendertype \"" + getrendertype() as string + "\" is not allowed, please set to \"view\"") flagMoreInfos:true type:ONLINE_FAQ)

				if rend.imageSampler_type != 3 then
				(
					if getVrayVersion() > 40000 and classof renderers.production != vrayrt then
					(
						if rend.camera_autoExposure or rend.camera_autoWhiteBalance != 0 then
							append resultList (tr id:12107 index:index validator:val severity:2 message:"Auto Exposure and White balance not supported for bucket distributed rendering. Please set it up in the Camera.")
					)
				)

				if skyatchRender.batchRender.checked and batchRenderMgr.numViews != 0 then
				(
					if renderers.production.gi_on == true then
					(
						if rend.gi_primary_type != 2 then
							append resultList (tr id:12100 index:index validator:val severity:2 message:("Currently only Brute Force Mode as Primary GI is supported when using Batch Render and Distributed Render"))

						if rend.gi_secondary_type != 0 and rend.gi_secondary_type != 2 then
							append resultList (tr id:12100 index:index validator:val severity:2 message:("Currently only No GI or Brute Force Mode as Secondary GI are supported when using Batch Render and Distributed Render"))
					)
				)

				try
				(
					if vrayVFBGetRegionEnabled() and rend.imageSampler_type != 3 then
						append resultList (tr id:12009 index:index validator:val severity:2 message:("Vray Frame buffer: make sure you have disabled region render !") flagMoreInfos:true type:ONLINE_FAQ)
				)
				catch
				(
					append resultList (tr id:12009 index:index validator:val severity:1 message:("Vray Frame buffer: make sure you have disabled region render !") flagMoreInfos:true type:ONLINE_FAQ)
				)

				try
				(
					local cams = getClassInstancesSave VRayStereoscopic
					for cam in cams do
					(
						if cam.enabled == false then
							continue
						if cam.view == 0 then --view="both"
						(
							append resultList (tr id:12100 index:index validator:val severity:2 message:("VRayStereoscopic: Set Stereoscopic parameter \"view\" to Left or Right. For technical reasons you need to send each view separatley."))
							break
						)
					)
				)
				catch()

				if rend.output_on and (rend.output_saveRawFile or rend.output_splitgbuffer) then
				(
					if rend.output_saveRawFile then
					(
						if rend.output_rawFileName == "" or rend.output_rawFileName == undefined then
							rend.output_rawFileName = "vray_raw_image.exr"

						fileOnly = getFilenameFile rend.output_rawFileName
						local lastChar = fileOnly[fileOnly.count]
						if lastChar != undefined AND bit.charAsInt lastChar >= 48 AND bit.charAsInt lastChar <=  57 then
						(
							rend.output_rawFileName = changeLastChar rend.output_rawFileName
						)

					)
					if rend.output_splitgbuffer then
					(
						if rend.output_splitFileName == "" or rend.output_splitFileName == undefined then
							rend.output_splitFileName =  "vray_separate_render_channels.exr"

						fileOnly = getFilenameFile rend.output_splitFileName
						local lastChar = fileOnly[fileOnly.count]
						if lastChar != undefined AND bit.charAsInt lastChar >= 48 AND bit.charAsInt lastChar <=  57 then
						(
							rend.output_splitFileName = changeLastChar rend.output_splitFileName
						)

						if (getFilenameType rend.output_splitFileName) == ".tif" and (renderWidth >= 16000 or renderHeight >= 16000) then
							append resultList (tr id:12009 index:index validator:val severity:2 message:("Vray Frame buffer: separate channels resolutions higher than 16000 are not supported with tif. Use exr instead!"))

						if not isSingleFrameExtensionSupported (getFilenameType rend.output_splitFileName) then
							append resultList (tr id:12009 index:index validator:val severity:2 message:("Vray Frame buffer: File Extension \"" +(getFilenameType rend.output_splitFileName)+ "\" not supported for single frame rendering"))
					)
				)
			)

--version checks

			if rend as string == "V_Ray_Adv_2_00_01:V_Ray_Adv_2_00_01" then
				append resultList (tr id:12010 index:index validator:val severity:2 message:"Your Vray version is not compatible with our farm, use SP5 or version 2.00.02")

			if rend as string == "V_Ray_Adv_3_00_01:V_Ray_Adv_3_00_01" or  rend as string == "V_Ray_Adv_3_00_02:V_Ray_Adv_3_00_02" or rend as string == "V_Ray_DEMO_3_00_01:V_Ray_DEMO_3_00_01" or rend as string == "V_Ray_DEMO_3_00_02:V_Ray_DEMO_3_00_02" then
				append resultList (tr id:12010 index:index validator:val severity:2 message:"Your version of vray is not supported - you need at least Vray 3.00.03 or higher")

			if (maxVersion())[1] == 16000 then
			(
				local vrayDllSize = getFileSize (getDir #maxRoot + "vray2015.dll")
				if vrayDllSize > 0 and vrayDllSize < 3000000 then
					append resultList (tr id:12010 index:index validator:val severity:2 message:"Incompatible Vray version" flagMoreInfos:true type:BAD_VRAY_VERSION)
			)

			try
			(
				if rend.imageSampler_renderMask_type == 2 then
					append resultList (tr id:12095 index:index validator:val severity:2 message:"Render mask \"Selected\" not supported. Use Layer or ID instead.")
			)
			catch()

			if hasProperty rend "output_resumableRendering" and rend.output_resumableRendering then
				append resultList (tr id:12106 index:index validator:val severity:2 message:"Please deactivate \"Resumable rendering\", if you want to resume your Distributed Rendering you can do so from the Controlcenter")

			-- if classof renderers.production == vrayrt then
			-- (
			-- 	if vray_gpu_dlg.confirmed == false then
			-- 		append resultList (tr id:12101 index:index validator:val severity:2 message:"Do you want to render on GPU or CPU?" flagMoreInfos:true type:GPU_DIALOG)
			-- 	else
			-- 	(
			-- 		if vray_gpu_dlg.gpu then
			-- 		(
			-- 			append resultList (tr id:12101 index:index validator:val severity:0 message:"Your job will be rendered on GPU" flagMoreInfos:true type:GPU_DIALOG)
			-- 			if isSingleFrameRender() then
			-- 				append resultList (tr id:12101 index:index validator:val severity:2 message:"Distributed rendering with GPU not yet supported - say No in the dialog or select CPU")
			-- 		)
			-- 		else
			-- 			append resultList (tr id:12101 index:index validator:val severity:0 message:"Your job will be rendered on CPU only" flagMoreInfos:true type:GPU_DIALOG)
			-- 	)
			-- )

--global switches
			if rend.options_overrideMtl_on == true then
				append resultList (tr id:12012 index:index validator:val severity:1 message:"Global: Override material is activated")

			if rend.options_showGIOnly == true then
				append resultList (tr id:12014 index:index validator:val severity:2 message:"Global: \"Show GI only\" is activated" flagMoreInfos:true type:SHOW_GI_ONLY)

			if rend.options_maps == false then
				append resultList (tr id:12015 index:index validator:val severity:1 message:"Global: \"Maps\" are not active")

			try
			(
				if rend.options_reflectionRefraction and rend.options_limitDepth == true and rend.options_maxDepth >= 4 then
					append resultList (tr id:12016 index:index validator:val severity:1 message:"Global: Reflection depth is very high")
			)
			catch()

			if NOT rend.options_glossyEffects then
				append resultList (tr id:12017 index:index validator:val severity:1 message:"Global: Glossy effects is disabled" flagMoreInfos:true type:GLOSSY_EFFECTS)

--antialiasing (imagesampler)
			case rend.imageSampler_type of
			(
				0: --fixed
				(
					if getVrayVersion() >= 32000 and isSingleFrameRender() then
						append resultList (tr id:12098 index:index validator:val severity:0 message:"We strongly recommend using Vray progressive rendering." flagMoreInfos:true type:USE_PROGRESSIVE)

					if rend.fixedRate_subdivs == 1 then
						append resultList (tr id:12018 index:index validator:val severity:1 message:"Image sampler: Antialiasing is set to fixed with 1 Subdivs")
				)
				1: --dmc
				(
					if getVrayVersion() >= 32000 and isSingleFrameRender() then
						append resultList (tr id:12098 index:index validator:val severity:0 message:"We strongly recommend using Vray progressive rendering." flagMoreInfos:true type:USE_PROGRESSIVE)

					if rend.twoLevel_baseSubdivs > 3 then
						append resultList (tr id:12019 index:index validator:val severity:1 message:"Adaptive DMC: Min subdivs is very high")

					if rend.twoLevel_fineSubdivs > 5 then
						append resultList (tr id:12020 index:index validator:val severity:1 message:"Adaptive DMC: Max subdivs is very high")
				)
				2: --subdivision
				(
					if getVrayVersion() >= 32000 and isSingleFrameRender() then
						append resultList (tr id:12098 index:index validator:val severity:0 message:"We strongly recommend using Vray progressive rendering." flagMoreInfos:true type:USE_PROGRESSIVE)

					if rend.adaptiveSubdivision_minRate >= 3 then
						append resultList (tr id:12021 index:index validator:val severity:1 message:"Adaptive Subdiv: Min. rate is very high")

					if rend.adaptiveSubdivision_maxRate > 3 then
						append resultList (tr id:12022 index:index validator:val severity:1 message:"Adaptive Subdiv: Max. rate is very high")
				)
				3: --progressive
				(
					if getVrayVersion() < 32000 then
						append resultList (tr id:12098 index:index validator:val severity:2 message:"You need Vray version 3.20.00 or higher to use Progressive renderer")

					if rend.filter_on and (classof rend.filter_kernel == VRaySincFilter or classof rend.filter_kernel == Catmull_Rom or classof rend.filter_kernel == Blackman or classof rend.filter_kernel == Mitchell_Netravali) then
						append resultList (tr id:12099 index:index validator:val severity:2 message:("Image filter "+(classof rend.filter_kernel as string)+" not supported due to a bug in Vray"))

					if vray_maxrp_dlg_maxPasses == -1 then
					(
						local threshold = getProgressiveThreshold()
						local maxPasses = getProgressivePasses()


						local errorOrInfo = 0
						if maxPasses > 100 or threshold > 0.01 then
							errorOrInfo = 2
						append resultList (tr id:12091 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Please confirm your options" flagMoreInfos:true type:MAX_RP_DIALOG)
					)
					else
					(
						if classof renderers.production == vrayrt then
							local passes = renderers.production.max_paths_per_pixel
						else
							local passes = renderers.production.progressive_maxSamples

						append resultList (tr id:12091 index:index validator:val severity:0 message:("Progressive rendering: Your Job is setup to use " + passes as string + " subdivs!") flagMoreInfos:true type:MAX_RP_DIALOG)
					)

				)
			)
			if rend.filter_on == false then
				append resultList (tr id:12023 index:index validator:val severity:1 message:"Image sampler: Filter is deactivated")
--dmc
			try --for vray Spx
			(
			if rend.dmc_subdivs_mult > 1.0 then
				append resultList (tr id:12024 index:index validator:val severity:1 message:"DMC Sampler: Global Subdiv higher 1 will increase the render time")

			if rend.dmc_earlyTermination_minSamples < 8 then
				append resultList (tr id:12025 index:index validator:val severity:1 message:"DMC Sampler: Minimum samples seems to be very low")

			if rend.dmc_earlyTermination_minSamples >= 17 then
				append resultList (tr id:12026 index:index validator:val severity:1 message:"DMC Sampler: Minimum samples seems to be very high and can increase rendertime")

			)
			catch
			(
			)
			try --for vray Rcx
			(
				if rend.qmc_subdivs_mult > 1.0 then
					append resultList (tr id:12028 index:index validator:val severity:1 message:"rQMC Sampler: Global Subdiv higher 1 will increase the render time")

				if rend.qmc_earlyTermination_minSamples < 8 then
					append resultList (tr id:12029 index:index validator:val severity:1 message:"rQMC Sampler: Minimum samples seems to be very low")

				if rend.qmc_earlyTermination_minSamples >= 17 then
					append resultList (tr id:12030 index:index validator:val severity:1 message:"rQMC Sampler: Minimum samples seems to be very high and can increase rendertime")

				if rend.qmc_timeDependent == false then
					append resultList (tr id:12031 index:index validator:val severity:1 message:"rQMC Sampler: To get identical image noise \"Time dependent\" should be activated")
			)
			catch
			(
			)
--indirect illumination
			if rend.gi_on == true then
			(
				if false then --rend.gi_saveMapsPerFrame == true then --TODO findet man wo?
					append resultList (tr id:12032 index:index validator:val severity:2 message:"GI: \"Save Maps per frame\" not supported")
				if rend.gi_primary_type == 1 OR rend.gi_secondary_type == 1 then -- Photon Map
				(
					if rend.photonMap_mode == 0 then -- new map
					(
						if isSingleFrameRender() then
							append resultList (tr id:12033 index:index validator:val severity:2 message:"GI engine Photon map: For Distributed Render, Photon map must be rendered to file first.")
						else
						(
							append resultList (tr id:12034 index:index validator:val severity:1 message:"GI engine Photon map: Attention, map mode is set to \"new map\"" flagMoreInfos:true type:GI_PHOTON_MAP_NEW)
						)
					)
					if rend.photonMap_mode == 1 then -- from file
					(
						append resultList (tr id:12037 index:index validator:val severity:1 message:"GI engine Photon map: Attention, map mode is set to \"from file\"" flagMoreInfos:true type:GI_PHOTON_MAP_FILE)
						if existsFile rend.photonMap_loadFileName == false then
							append resultList (tr id:12038 index:index validator:val severity:2 message:"GI engine Photon Map: Can not find Photon Map file")
					)
				)
				if rend.gi_primary_type == 3 OR rend.gi_secondary_type == 3 then -- Light cache
				(
					if isSingleFrameRender() then
					(
						if not ((rend.lightcache_mode == 0 AND rend.lightcache_autoSave == false) OR (rend.lightcache_mode == 2 AND existsFile rend.lightcache_loadFileName == true)) then
							append resultList (tr id:12039 index:index validator:val severity:2 message:"GI engine Lightcache: For Distributed Render, set mode to \"Single frame\"" flagMoreInfos:true type:GI_LIGHTCACHE_DISTRIBUTED)

						local recommendedSubdiv = (sqrt(renderWidth * renderHeight)) /2.0
						if rend.lightcache_subdivs < 0.85 * recommendedSubdiv OR rend.lightcache_subdivs > 1.15 * recommendedSubdiv then
							append resultList (tr id:12040 index:index validator:val severity:1 message:("GI engine Lightcache: Recommended Lightcache subdivision is " + (recommendedSubdiv as integer)as string))

						if rend.lightcache_autoSave == true then
							append resultList (tr id:12041 index:index validator:val severity:2 message:"GI engine Lightcache: Please disable Autosave for singleframe rendering.")
					)
					else
					(
						case rend.lightcache_mode of
						(
							0: -- single frame
							(
								if NOT onlyOneFrame() then
									append resultList (tr id:12042 index:index validator:val severity:1 message:"GI engine Lightcache: Lightcache mode \"single frame\" is used" flagMoreInfos:true type:GI_LIGHTCACHE_SINGLE)
								if rend.lightcache_autoSave == true then
									append resultList (tr id:12043 index:index validator:val severity:2 message:"GI engine Lightcache: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_LC)
							)
							1: -- fly-through
							(
								append resultList (tr id:12044 index:index validator:val severity:1 message:"GI engine Lightcache: Lightcache mode \"Fly through\" is used" flagMoreInfos:true type:GI_LIGHTCACHE_FLY)
								if rend.lightcache_autoSave == true then
									append resultList (tr id:12045 index:index validator:val severity:2 message:"GI engine Lightcache: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_LC)
							)
							2: -- from file
							(
								if existsFile rend.lightcache_loadFileName == false then
									append resultList (tr id:12046 index:index validator:val severity:2 message:("GI engine Lightcache: File not found") flagMoreInfos:true type:GI_LIGHTCACHE_FROMFILE)
							)
							3: -- progressive path-tracing
							(
								append resultList (tr id:12047 index:index validator:val severity:1 message:"GI engine Lightcache: Lightcache mode \"path tracing\" is used" flagMoreInfos:true type:GI_LIGHTCACHE_PATH)
								if rend.lightcache_autoSave == true then
									append resultList (tr id:12048 index:index validator:val severity:2 message:"GI engine Lightcache: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_LC)
							)
						)
					)
				)
				if rend.gi_primary_type == 0 then -- Irradiance Map
				(
					if rend.gi_irradmap_maxRate >= 1 then
						append resultList (tr id:12049 index:index validator:val severity:1 message:"GI engine Irradiance: Max rate seems to be very high")

					if rend.gi_irradmap_detail_on == true then
						append resultList (tr id:12050 index:index validator:val severity:1 message:"GI engine Irradiance: Detail enhancement is active")

					if NOT rend.adv_irradmap_useCurrentPassSamples then
						append resultList (tr id:12051 index:index validator:val severity:1 message:"GI engine Irradiance: Multipass disabled - can cause impropper GI solutions on the bucket borders")

					if isSingleFrameRender() then
					(
						if not ((rend.adv_irradmap_mode == 0 AND rend.adv_irradmap_autoSave == false) OR (rend.adv_irradmap_mode == 2 AND existsFile rend.adv_irradmap_loadFileName == true)) then
							append resultList (tr id:12052 index:index validator:val severity:2 message:"GI engine Irradiance: For Distributed Render, set mode to \"Single frame\"" flagMoreInfos:true type:GI_IRRADIANCE_DISTRIBUTED)
						if rend.gi_irradmap_preset > 4 then
							append resultList (tr id:12053 index:index validator:val severity:1 message:"GI engine Irradiance: Irradiance preset will produce a giant irradiance map and can increase rendertime !!!" flagMoreInfos:true type:ONLINE_FAQ)
						if rend.adv_irradmap_autoSave == true then
							append resultList (tr id:12054 index:index validator:val severity:2 message:"GI engine Irradiance: Please disable Autosave for singleframe rendering.")
					)
					else
					(
						case rend.adv_irradmap_mode of
						(
							0: --single frame
							(
								append resultList (tr id:12055 index:index validator:val severity:1 message:"GI engine Irradiance: Irradiance mode \"single frame\" is used" flagMoreInfos:true type:GI_IRRADIANCE_SINGLE)
								if rend.adv_irradmap_autoSave == true then
									append resultList (tr id:12056 index:index validator:val severity:2 message:"GI engine Irradiance: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_IRR)
							)
							1: --multiframe incremental
							(
								if isVrayIrrMulti() then
								(
									if getVrayVersion() > 30000 then
									(
										if rend.gi_secondary_type == 1 and rend.photonMap_mode == 0 then
											append resultList (tr id:12083 index:index validator:val severity:2 message:"GI engine Irradiance: Irradience mode \"Multiframe incremental\" supports Photonmap \"from file\" only")

										if rend.gi_secondary_type == 3 and (rend.lightcache_mode == 0 or rend.lightcache_mode == 3) and getVrayVersion() < 60000 then
											append resultList (tr id:12084 index:index validator:val severity:2 message:"GI engine Irradiance: Irradience mode \"Multiframe incremental\" supports Lightcache \"Flythrough\" only")
									)
									else
										append resultList (tr id:12083 index:index validator:val severity:2 message:"GI engine Irradiance: Irradience mode \"Multiframe incremental\" is only supported in Vray 2.x")

								)
								else
								(
									if rend.adv_irradmap_autoSave == true then
										append resultList (tr id:12058 index:index validator:val severity:2 message:"GI engine Irradiance: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_IRR)
								)
								append resultList (tr id:12057 index:index validator:val severity:1 message:"GI engine Irradiance: Irradiance mode \"Multiframe Incremental\" is used" flagMoreInfos:true type:GI_IRRADIANCE_MULTI)
							)
							2: --from file
							(
								if existsFile rend.adv_irradmap_loadFileName == false then
									append resultList (tr id:12059 index:index validator:val severity:2 message:("GI engine Irradiance: file not found") flagMoreInfos:true type:GI_IRRADIANCE_FROMFILE)
							)
							3: --add to current map
							(
								append resultList (tr id:12060 index:index validator:val severity:2 message:"GI engine Irradiance: Add to current map not supported")
							)
							4: --incremental add to current map
							(
								append resultList (tr id:12061 index:index validator:val severity:2 message:"GI engine Irradiance: Incremental add to current map not supported")
							)
							5: --bucket mode
							(
								append resultList (tr id:12062 index:index validator:val severity:2 message:"GI engine Irradiance: Bucket mode not supported - set GI mode to single frame instead")
							)
							6: --animation (prepass)
							(
								append resultList (tr id:12064 index:index validator:val severity:1 message:"GI engine Irradiance: Irradiance mode \"Animation prepass\" is used" flagMoreInfos:true type:GI_IRRADIANCE_PREPASS)
								if skyatchRender.batchRender.checked and batchRenderMgr.numViews != 0 then
									append resultList (tr id:12064 index:index validator:val severity:2 message:("Combining Batch rendering and animation prepass is not yet possible"))
								if dlg_main.estimateRenderpoints then
									append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating animation prepass rendering currently not possible!"))
							)
							7: --animation (rendering)
							(
								local framestart = rendStart.frame as integer
								local frameend = rendEnd.frame as integer
								if rendTimeType == 2 then
								(
									framestart = animationRange.start.frame as integer
									frameend = animationRange.end.frame as integer
								)
								local irrFiles = findIrrFiles rend start:framestart end:frameend
								if irrFiles.count == 0 then
									append resultList (tr id:12065 index:index validator:val severity:2 message:"GI engine Irradiance: No vrmap files found" flagMoreInfos:true type:GI_IRRADIANCE_ANIMRENDER)
								else
								(
									local missingMaps = #()
									for i=framestart to frameend do
									(
										local bFound = false
										for irrFile in irrFiles do
										(
											if findstring irrFile (i as string)  != undefined then
												bFound = true
										)
										if not bFound then
											append missingMaps i
									)
									for m in missingMaps do
									(
										append resultList (tr id:12066 index:index validator:val severity:2 message:("GI engine Irradiance: IRR file for frame " + (m as string) + " not found") flagMoreInfos:true type:GI_IRRADIANCE_ANIMRENDER)
									)
								)
							)
						)
					)
				)
			)
--caustics
			if rend.caustics_on == true then
			(
				if rend.caustics_mode == 0 then --new map
				(
						if isSingleFrameRender() then
							append resultList (tr id:12067 index:index validator:val severity:2 message:"Caustics: Map mode \"new map\" is not supported for single frame rendering." flagMoreInfos:true type:ONLINE_FAQ)
						else
							append resultList (tr id:12068 index:index validator:val severity:1 message:"Caustics: Attention, recompute mode is set to \"new map\"" flagMoreInfos:true type:ONLINE_FAQ)

						try
						(
							if rend.casutics_autoSave == true then -- old vray versions have a typo in caustics<->casutics
								append resultList (tr id:12069 index:index validator:val severity:2 message:"Caustics: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_CAUSTICS)
						)catch()
						try
						(
							if rend.caustics_autoSave == true then
								append resultList (tr id:12069 index:index validator:val severity:2 message:"Caustics: Auto save not supported" flagMoreInfos:true type:AUTOSAVE_CAUSTICS)
						)catch()
				)
				if rend.caustics_mode == 1 then --from file
				(
						if not isSingleFrameRender() then
							append resultList (tr id:12070 index:index validator:val severity:1 message:"Caustics: Attention, recompute mode is set to \"from file\"" flagMoreInfos:true type:ONLINE_FAQ)
						if existsFile rend.caustics_loadFileName == false then
							append resultList (tr id:12071 index:index validator:val severity:2 message:"Caustics: Can not find file")
				)
			)

--vray stereoscopic camera
			shademaprendering = false
			shademapfiles = #()
			try
			(
				local cams = getClassInstancesSave VRayStereoscopic
				for cam in cams do
				(
					if cam.enabled == false then
						continue
					if cam.shademap_mode == 1 then
					(
						append resultList (tr id:12080 index:index validator:val severity:1 message:("VRayStereoscopic: \"Shape Map\" rendering enabled. The rendering will be done in 2 passes on Render Farm Application"))
						shademaprendering = true
					)
					if cam.shademap_mode == 2 then
					(
						local p = cam.shademap_file
						if p == undefined OR (existsFile p == false) then
							append resultList (tr id:12081 index:index validator:val severity:2 message:("VRayStereoscopic: File not found \"" + p + "\""))
						else
						(
							if not CheckFilenameUnicode (filenameFromPath p) then
								append resultList (tr id:12082 index:index validator:val severity:2 message:("VRayStereoscopic: File has unsupported characters \"" + p + "\""))
							else
							(
								local sp = (substring p 1 (p.count - (filenameFromPath p).count)) + "*.vrst"
								local spFiles = getFiles sp
								for pp in spFiles do
								(
									append shademapfiles pp
								)
							)
						)
					)
				)
			)
			catch()

--vrayMtl
			mtls = getClassInstancesSave vraymtl
			local isSingle = isSingleFrameRender()
			for m in mtls do
			(
				if m.reflection_useInterpolation == true OR m.refraction_useInterpolation == true then
				(
					if isSingle then
						append resultList (tr id:12076 index:index validator:val severity:2 message:("Vray material \""+m.name+"\" uses interpolation") flagMoreInfos:true type:INTERPOLATION_MAT_SINGLE)
					else
						append resultList (tr id:12076 index:index validator:val severity:1 message:("Vray material \""+m.name+"\" uses interpolation") flagMoreInfos:true type:INTERPOLATION_MAT)
				)

			)

			mtls = getClassInstancesSave RaytraceMaterial
			if mtls.count > 0 then
				append resultList (tr id:12094 index:index validator:val severity:2 message:("Raytrace Materials not supported in vray, do you want to replace them?") flagMoreInfos:true type:REPLACE_RAYTRACE_MAT)
			mtls = getClassInstances Raytrace
			if mtls.count > 0 then
				append resultList (tr id:12094 index:index validator:val severity:2 message:("Raytrace Map not supported in vray, do you want to replace them?") flagMoreInfos:true type:REPLACE_RAYTRACE_MAP)
--vray light
			local vrlights = getClassInstancesSave VRayLight
			for l in vrlights do
			(
				try
				(
					if l.texmap_on then
					(
						local b = l.texmap
						if b != undefined then
						(
							local lpath = b.fileName
							if lpath != undefined then
							(
								local ext = myToLower (getFilenameType lpath)
								if (stricmp (ext) ".exr") == 0 then
									append resultList (tr id:12087 index:index validator:val severity:2 message:("EXR texture for Lights not supported. Use HDRi format.") flagMoreInfos:true type:ONLINE_FAQ)
							)
						)
					)
				)
				catch()
			)

--VRayPhysicalCamera
			try
			(
				local cams = getClassInstancesSave VRayPhysicalCamera
				join cams (getClassInstancesSave Physical)
				for cam in cams do
				(
					local useLens = false
					try(useLens = cam.use_lens_file) catch() -- not possible with hasProperty
					if cam.distortion_type == 2 or useLens then
					(
						if cam.lens_file == undefined OR existsFile cam.lens_file == false then
						(
							local lf = cam.lens_file
							if lf == undefined then lf = ""
							append resultList (tr id:12086 index:index validator:val severity:2 message:("VRayPhysicalCamera: Lens File not found \"" + lf + "\""))
						)
					)
				)
			)
			catch()
--VRayProxy
			try
			(
				local proxies = getClassInstancesSave VRayProxy
				for proxy in proxies do
				(
					if proxy.filename != undefined then
					(
						if (getfilenametype proxy.filename) != ".vrmesh" AND (getfilenametype proxy.filename) != ".abc" then
						(
							append resultList (tr id:12088 index:index validator:val severity:2 message:("VRayProxy: File extension must be \".vrmesh\" or \".abc\" (\"" + proxy.filename + "\")"))
						)
					)
				)
			)
			catch()

			if not isSingle and isVrayIrrMulti() then
			(
				if rend.gi_irradmap_preset > 4 then
					append resultList (tr id:12053 index:index validator:val severity:1 message:"GI engine Irradiance: Irradiance preset will produce a giant irradiance map and can increase rendertime !!!" flagMoreInfos:true type:ONLINE_FAQ)
				if skyatchRender.batchRender.checked and batchRenderMgr.numViews != 0 then
					append resultList (tr id:12053 index:index validator:val severity:2 message:("Combining Batch rendering and Irradiance precaching is not yet possible"))
				if dlg_main.estimateRenderpoints then
					append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating Irradiance precaching rendering currently not possible!"))
			)

			if isSingle then
			(
				for i = 1 to numAtmospherics do
				(
					try
					(
						atmo = getAtmospheric i
						if (getClassName atmo) == "VRaySphereFade" then
							append resultList (tr id:12085 index:index validator:val severity:2 message:"Atmosphere: Due to a bug in vray sphere fade is not supported")
					)
					catch()
				)
			)
		)

--Vray 3 xml materials
		try
		(
			local mats = getClassInstancesSave VRayVRmatMtl
			for mat in mats do
			(
				local f = mat.filename
				local vrmat = f
				if not existsFile vrmat then
					vrmat = mapPaths.getFullFilePath vrmat
				if existsFile vrmat == false then
					append resultList (tr id:12089 index:index validator:val severity:2 message:("VRayVRmatMtl: xml File not found \"" + f + "\""))
				else
				(
					local assets = findVray3XmlPaths vrmat
					for assetPath in assets do
					(
						local assetRealPath = assetPath
						if existsFile assetRealPath == false then
							assetRealPath = mapPaths.getFullFilePath assetRealPath
						if existsFile assetRealPath == false then
							append resultList (tr id:12089 index:index validator:val severity:2 message:("VRayVRmatMtl: File not found \"" + assetPath+ "\" in material \"" + f + "\""))
					)
				)
			)
		)
		catch()

--PhoenixFD
		try
		(
			local fds = getClassInstancesSave PhoenixSimulator
			join fds (getClassInstancesSave FireSmokeSim)
			join fds (getClassInstancesSave LiquidSim)
			for fd in fds do
			(
				local f = parsePhoenixPath fd fd.rendinput
				f = replaceAll f "#" "*"

				if findString f "$(" != undefined then
					append resultList (tr id:12097 index:index validator:val severity:2 message:("PhoenixFD: \"$\" not allowed in input path. Use absolute path instead of \""+f+"\"."))
				else
				(
					local files = getFiles f
					if files.count == 0 then
					(
						append resultList (tr id:12096 index:index validator:val severity:2 message:("PhoenixFD simulation files not found (input rollout) \""+f+"\".") flagMoreInfos:true type:PHOENIX_FD_NOT_FOUND)
					)
				)
			)
		)
		catch()

--VRayVolumeGrid
		try
		(
			local fds = getClassInstancesSave VRayVolumeGrid
			for fd in fds do
			(
				local f = fd.rendinput
				f = replaceAll f "#" "*"
				local files = getFiles f
				if files.count == 0 then
				(
					append resultList (tr id:12102 index:index validator:val severity:2 message:("VRayVolumeGrid files not found (input rollout) \""+f+"\".") flagMoreInfos:true type:VRAYVOLUMEGRID_NOT_FOUND)
				)
			)
		)
		catch()

--Vray Framebuffer settings
		try
		(
			local glareimage = undefined
			if (vfbControl #glare)[1] == 1 then
			(
				if isSingle then
					append resultList (tr id:12105 index:index validator:val severity:2 message:("Vray Frame buffer: \"Glare\" not supported for Distributed Render"))

				if (vfbControl #glaretype)[1] == "image" then
				(
					glareimage = (vfbControl #glareimage)[1]
					if glareimage == undefined or glareimage == "" then
						append resultList (tr id:12104 index:index validator:val severity:2 message:("Vray frame buffer: Glare image path is empty"))
				)
				else
				(
					if (vfbControl #glareuseobstacle)[1] == 1 then
						glareimage = (vfbControl #glareobstacleimage)[1]

				)
				if glareimage != undefined and glareimage.count > 0 and not existsfile glareimage then
					append resultList (tr id:12104 index:index validator:val severity:2 message:("Vray frame buffer: Glare image not found \""+glareimage+"\""))
			)
		)
		catch()

		try
		(
			if isSingle and (vfbControl #bloom)[1] == 1 then
				append resultList (tr id:12105 index:index validator:val severity:2 message:("Vray Frame buffer: \"Bloom\" not supported for Distributed Render"))
		)catch()

		if classof renderers.production == vrayrt then
		(
			rendrt = renderers.production
			if rendrt.vrscene_on then
				append resultList (tr id:12092 index:index validator:val severity:2 message:("VRay RT: disable .vrscene export") flagMoreInfos:true type:RT_VRSCENE)
			if rendrt.vrscene_dontRender then
				append resultList (tr id:12093 index:index validator:val severity:2 message:("VRay RT: disable \"Don't render (just export)\"") flagMoreInfos:true type:RT_DONT_RENDER)
			if rendrt.distributed_rendering then
				append resultList (tr id:12092 index:index validator:val severity:2 message:("VRay RT: disable \"Distributed\"") flagMoreInfos:true type:RT_DISTRIBUTED)
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValVRay!"
		case result.type of
		(
		ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
		GI_PHOTON_MAP_NEW:
			st = "Map mode \"new map\" is used for non static scenes only !
A non static scene include animated objects, morphing objects, animated lights or textures
Attention, that recomputing mode force the renderer to redo the Photon map solution each frame
that causes different solutions in each frame and can produce a flickering in the final output
to reduce flickering you could increase the settings but that rise the rendertime per image without guarantee of flickerfree output
Note: refer map mode \"from file\" for static scene rendering"
		GI_PHOTON_MAP_FILE:
			st = "Map mode \"from file\" force Vray to read the caustic information from file
Vray will NOT compute the Photon map solution during the render process.
To create a Photon map file on your computer you MUST have a static scene
A static scene have no animated objects, no morphing objects, no animated lights or textures
! the camera is the only moving part
-go Vray options and hit \"dont render final image\"
-set one frame to render
-check \"save solution\" and specify a save path
-hit render
-on renderend load Photon map from file
-switch back \"dont render final image\"";
		GI_LIGHTCACHE_SINGLE:
			st = "Map mode \"single frame\" is used for non-static scenes only !
A non-static scene include animated objects,light or textures.
Vray will calculate each frame a new GI solution. It can produce
a flicker depending on scene and setup.

If your Camera is the only animated part of scene set GI mode
\"Fly through\"
";
		GI_LIGHTCACHE_PATH:
			st="Map mode \"pathtracing\" will refine the image during the render until all subdivisions are done
that mode can produce rendertimes of several hours per image";
		GI_LIGHTCACHE_FLY:
			st="Map mode \"Fly through\" is used for static scenes only !
A static scene include NO animated objects,light or textures.
If your scene is not static set map mode \"single Frame\".

Render Farm Application will render the Lightcache map to file and
afterwards the final images (2 jobs in one).
";
		GI_LIGHTCACHE_FROMFILE:
			st="to create an LC map :
-set GI mode \"Fly through\"
-below, enable autosave, set save path and save file name
-enable \"don't render final image\" (vray global switches)
-hit render and Vray generate the LC map
Afterwards reset all setings and select the map you just created.

!! Render Farm Application could render the LC map for you.
Set LC mode to \"Fly through\".
"

	GI_IRRADIANCE_SINGLE:
			st="Map mode \"single frame\" is used for non-static scenes only !
A non-static scene include animated objects,light or textures.
Vray will calculate each frame a new GI solution. It can produce
a flicker depending on scene and setup.

To reduce flicker you could use GI mode \"Animation prepass\".

If your Camera is the only animated part of scene set GI mode
\"from file\" or \"multiframe incremental\".
"
		GI_IRRADIANCE_MULTI:
			st="Map mode \"multiframe incremental\" is used for static scenes only !
A static scene include NO animated objects,light or textures.
! the camera is the only animated part  of scene !

!! Render Farm Application could render the Irradience map for you.
We will render each 10th frame to file and afterwards the
final images (2 jobs in one).

If your scene include moving objects, lights or textures set GI mode to \"Animation prepass\".
"
		GI_IRRADIANCE_FROMFILE:
			st="to creat an IRR map :
-set GI mode \"multiframe incremental\"
-below, enable autosave, set save path and save file name
-setup to render each 10th frame only
-enable \"dont render final image\" (vray global switches)
-hit render and Vray generate the IRR map
Afterwards reset all setings and select the map you just created.

!! Render Farm Application could render the Irradience map for you.
Set GI mode to \"multiframe incremental\".
"
		CAUSTICS_NEW_MAP:
			st="Recompute mode \"new map\" is used for non static scenes only!
A non static scene include animated objects, morphing objects, animated lights or textures
Attention, that recomputing mode force the renderer to redo the Caustic solution each frame
that causes different solutions in each frame and can produce a flickering in the final output
to reduce flickering you could increase the settings but that rise the rendertime per image without guarantee of flickerfree output"
		CAUSTICS_FROM_FILE:
			st="Recompute mode \"from file\" force VRay to read the caustic information from file
Vray will NOT compute the caustic solution during the render process.
To create a caustic file on your computer you MUST have a static scene
A static scene have no animated objects, no morphing objects, no animated lights or textures
! the camera is the only moving part
-go vray options and hit \"dont render final image\"
-set one frame to render
-check \"save solution\" and specify a save path
-hit render
-on renderend load caustic from file
-switch back \"dont render final image\""
		GI_LIGHTCACHE_DISTRIBUTED:
			st="You could pre-render the Lightcache to file to save rendertime and costs.
-set Light cache mode \"single image\"
-enable autosave and specify save path
-hit render
If Lightcache finished cancel render
switch back \"dont render final image\" and choose Lightcache mode \"from file\""
		GI_IRRADIANCE_DISTRIBUTED:
			st="You could pre-render the Irradiance map to file to save rendertime and costs.
-set Irradiance map mode \"single image\"
-enable autosave and specify save path
-hit render
If Irradiance map finished cancel render
switch back \"dont render final image\" and choose Irradiance mode \"from file\""
		GI_IRRADIANCE_PREPASS:
			st="Map mode \"Animation prepass\" is used for non-static scenes only !
A non-static scene include animated objects,light or textures.

Render Farm Application will render the Irradience map each frame to
file and afterwards the final images (2 jobs in one).
! that GI mode do not guarantee flicker free renders !

If your Camera is the only animated part of scene set GI mode
\"from file\" or \"multiframe incremental\"
"
		GI_IRRADIANCE_ANIMRENDER:
			st="you need to generate all Irradience maps first
to create all IRR maps:
-set GI mode \"animation prepass\"
-below, enable autosave, set save path and save file name
-enable \"dont render final image\" (vray global switches)
-hit render and vray generate all IRR maps
Afterwards reset all setings and set GI mode \"animation render\".
Select the maps you just created.

!! Render Farm Application could render the Irradience map for you.
Set GI mode to \"Animation prepass\".
"
		VRAY_FRAMEBUFFER_ELEMS:
			st="Render Elements do NOT save to disk as long Vray Frame buffer is active!
Enable in Vray Buffer \"render to memory\" and \"save separate channels\"
otherwise disable Vray Buffer or remove elements"
		BAD_VRAY_VERSION:
			st= "The version you use is not compatible to farm. It does not work properly and cause all Vray settings resetted to default on our side. Use Vray version 3.00.03 !"

		PHOENIX_FD_NOT_FOUND:
			st="You need to simulate FD solution first. Render Farm Application can't simulate the caches for you"
		VRAYVOLUMEGRID_NOT_FOUND:
			st="You need to simulate FD solution first. Render Farm Application can't simulate the caches for you"
		USE_PROGRESSIVE:
			st="Progressive rendering enables you to set a rendercost limit!
Your renderjob will stop, after reaching the renderpoint limit and save
your image with the achieved quality.

Set Vray \"image sampler (anti aliasing)\" to progressive and
run smartcheck again.

!! Please note !!
Make sure your scene renders fine on progressive mode."
		)

		if result.type == INTERPOLATION_MAT then
		(
			goToOnlineFaq result.id
			if queryBox "It is not recommended to enable interpolation for animation renderings. Interpolation forces Vray to pre-render the reflection/refraction map.
That can produce a flicker in the final output. Do you want to disable Interpolation for all materials?" beep:false then
			(
				mtls = getClassInstancesSave vraymtl
				for m in mtls do
				(
					m.reflection_useInterpolation = false
					m.refraction_useInterpolation = false
				)
				resolved = true
			)
		)
		else if result.type == INTERPOLATION_MAT_SINGLE then
		(
			goToOnlineFaq result.id
			if queryBox "Due to technical limitations Interpolated materials are not suppoerted. Do you want to disable Interpolation for all materials?" beep:false then
			(
				mtls = getClassInstancesSave vraymtl
				for m in mtls do
				(
					m.reflection_useInterpolation = false
					m.refraction_useInterpolation = false
				)
				resolved = true
			)
		)
		else if result.type == REPLACE_RAYTRACE_MAT then
		(
			if queryBox "Raytrace materials are not supported by Vray, do you want to replace these with a dummy material?" beep:false then
			(
				for c in (getClassInstancesSave RaytraceMaterial) do
				(
					print c.name
					replaceinstances c (vraymtl name:c.name)
				)
				if (getClassInstancesSave RaytraceMaterial).count > 0 then
					messagebox "Could not replace all materials, please replace these yourself" title:"Render Farm Application"
				else
					resolved = true
			)
		)
		else if result.type == REPLACE_RAYTRACE_MAP then
		(
			if queryBox "Raytrace maps are not supported by Vray, do you want to replace these with a dummy material?" beep:false then
			(
				for c in (getClassInstancesSave Raytrace) do
				(
					print c.name
					replaceinstances c (VRayColor name:c.name)
				)
				if (getClassInstancesSave Raytrace).count > 0 then
					messagebox "Could not replace all materials, please replace these yourself" title:"Render Farm Application"
				else
					resolved = true
			)
		)
		else if result.type == MAX_RP_DIALOG then
		(
			CreateDialog vray_maxrp_dlg modal:true
			if vray_maxrp_dlg_maxPasses != undefined and vray_maxrp_dlg_maxPasses > 0 then
			(
				result.message = ("Progressive rendering: Your Job is setup to reach " + vray_maxrp_dlg_maxPasses as string + " subdivs!")
				resolved = true
			)
		)
		else if result.type == GPU_DIALOG then
		(
			if isSingleFrameRender() then
			(
				messagebox "Distributed rendering with GPU not yet supported - say No in the dialog or select CPU" title:"Render Farm Application"
				return false
			)
			CreateDialog vray_gpu_dlg modal:true
			dlg_main.vrayGPUselected = vray_gpu_dlg.gpu

			if vray_gpu_dlg.gpu then
				result.message = "Your job will be rendered on GPU"
			else
				result.message = "Your job will be rendered on CPU only"

			resolved = true
			if FarmRenderSetting != undefined then
				FarmRenderSetting.updatePrioDropdown()

		)
		else if result.type == VRAY_STANDALONE then
		(
			if queryBox "Do you want to render with Vray Standalone?" beep:false then
				vrsceneExport = true
			else
				vrsceneExport = false
			resolved = true
		)
		else if result.type == SHOW_GI_ONLY then
		(
			if queryBox "Do you want me to disable Show GI only?" beep:false then
			(
				renderers.production.options_showGIOnly = false
				renderSceneDialog.update()
			)
			return 0
		)
		else if result.type == GLOSSY_EFFECTS then
		(
			if queryBox "Do you want me to enable Glossy effects?" beep:false then
			(
				renderers.production.options_glossyEffects = true
				renderSceneDialog.update()
				resolved = true
			)
		)
		else if result.type == AUTOSAVE_LC then
		(
			if queryBox "Do you want me to disable Auto Save?" beep:false then
			(
				renderers.production.lightcache_autoSave = false
				renderSceneDialog.update()
				resolved = true
			)
		)
		else if result.type == AUTOSAVE_IRR then
		(
			if queryBox "Do you want me to disable Auto Save?" beep:false then
			(
				renderers.production.adv_irradmap_autoSave = false
				renderSceneDialog.update()
				resolved = true
			)
		)
		else if result.type == AUTOSAVE_CAUSTICS then
		(
			if queryBox "Do you want me to disable Auto Save?" beep:false then
			(
				renderers.production.caustics_autoSave = false
				renderSceneDialog.update()
				resolved = true
			)
		)
		else if result.type == RT_VRSCENE then
		(
			if queryBox "Do you want me to disable .vrsene export?" beep:false then
			(
				renderers.production.vrscene_on = false
				renderSceneDialog.update()
				resolved = true
			)
		)
		else if result.type == RT_DONT_RENDER then
		(
			if queryBox "Do you want me to disable \"Don't render just export\"?" beep:false then
			(
				renderers.production.vrscene_dontRender = false
				renderSceneDialog.update()
				resolved = true
			)
		)
		else if result.type == RT_DISTRIBUTED then
		(
			if queryBox "Do you want me to disable Vray RT distributed setting?" beep:false then
			(
				renderers.production.distributed_rendering = false
				renderSceneDialog.update()
				resolved = true
			)
		)
		else
			messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof renderers.production == vray or classof renderers.production == vrayrt then
		(
			if classof renderers.production == vrayrt then
				rend = rend.V_Ray_settings
			try
			(
				oldlightcache_multipleViews = rend.lightcache_multipleViews
				rend.lightcache_multipleViews = false
			)catch()

			try
			(
				oldgi_irradmap_multipleViews = rend.gi_irradmap_multipleViews
				rend.gi_irradmap_multipleViews = false
			)catch()

			if rend.gi_on AND rend.gi_primary_type == 0 then --irr map
			(
				try
				(
					oldIrrLoadFilename = rend.adv_irradmap_loadFileName
					if rend.adv_irradmap_mode == 7 then
					(
						local framestart = rendStart.frame as integer
						local frameend = rendEnd.frame as integer
						if rendTimeType == 2 then
						(
							framestart = animationRange.start.frame as integer
							frameend = animationRange.end.frame as integer
						)
						local irrFiles = findIrrFiles rend start:framestart end:frameend
						for f in irrFiles do
						(
							if existsfile f then
							(
								appendFileInfo &vecFiles f ("tex/" + filenameFromPath f)
							)
						)
						rend.adv_irradmap_loadFileName = createTexPath dlg_main.m_userName (filenameFromPath rend.adv_irradmap_loadFileName)
					)
					else
					(
						if rend.adv_irradmap_loadFileName  != undefined then
						(
							mpath = (mapPaths.getFullFilePath rend.adv_irradmap_loadFileName )
							if existsfile mpath then
							(
								appendFileInfo &vecFiles mpath ("tex/" + dlg_main.m_userName + "/" + filenameFromPath mpath)
								rend.adv_irradmap_loadFileName = createTexPath dlg_main.m_userName (filenameFromPath mpath)
							)
						)
					)
				)
				catch
				(
					format "vray.ms:1 *** % ***\n" (getCurrentException())
				)
			)

			if rend.gi_on AND rend.gi_primary_type == 1 OR rend.gi_secondary_type == 1 AND rend.photonMap_mode == 1 then -- Photon Map
			(
				try
				(
					oldphFilename = rend.photonMap_loadFileName
					if rend.photonMap_loadFileName != undefined then
					(
						mpath = (mapPaths.getFullFilePath rend.photonMap_loadFileName )
						if existsfile mpath then
						(
							appendFileInfo &vecFiles mpath ("tex/" + filenameFromPath mpath)
							rend.photonMap_loadFileName = createTexPath dlg_main.m_userName (filenameFromPath mpath)
						)
					)
				)
				catch
				(
					format "vray.ms:2 *** % ***\n" (getCurrentException())
				)
			)
			if rend.gi_on AND rend.gi_primary_type == 3 OR rend.gi_secondary_type == 3 AND  rend.lightcache_mode == 2 then -- Light cache
			(
				try
				(
					oldLCLoadFilename = rend.lightcache_loadFileName
					if rend.lightcache_loadFileName != undefined then
					(
						mpath = (mapPaths.getFullFilePath rend.lightcache_loadFileName )
						if existsfile mpath then
						(
							appendFileInfo &vecFiles mpath ("tex/" + filenameFromPath mpath)
							rend.lightcache_loadFileName = createTexPath dlg_main.m_userName (filenameFromPath mpath)
						)
					)
				)
				catch
				(
					format "vray2.ms: *** % ***\n" (getCurrentException())
				)
			)
			if rend.caustics_on == true AND rend.caustics_mode == 1 then --caustics
			(
				try
				(
					oldcauFilename = rend.caustics_loadFileName
					if rend.caustics_loadFileName != undefined then
					(
						mpath = (mapPaths.getFullFilePath rend.caustics_loadFileName )
						if existsfile mpath then
						(
							appendFileInfo &vecFiles mpath ("tex/" + filenameFromPath mpath)
							rend.caustics_loadFileName = createTexPath dlg_main.m_userName (filenameFromPath mpath)
						)
					)
				)
				catch
				(
					format "vray4ms: *** % ***\n" (getCurrentException())
				)
			)

			for hd in shademapfiles do
			(
				if existsfile hd then
				(
					local newpath = (filenameFromPath hd)
					newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
					local newfile = ("tex/" + filenameFromPath hd)
					appendFileInfo &vecFiles hd newfile
				)
			)

			--VRayPhysicalCamera
			oldLensFiles = #()
			local cams = getClassInstancesSave VRayPhysicalCamera
			join cams (getClassInstancesSave Physical)
			for cam in cams do
			(
				local useLens = false
				try(useLens = cam.use_lens_file) catch() -- not possible with hasProperty
				if cam.distortion_type == 2 or useLens then
				(
					local ppath = cam.lens_file
					append oldLensFiles ppath
					if existsFile ppath then
					(
						local newpath = (filenameFromPath ppath)
						newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
						local newfile = ("tex/" + filenameFromPath ppath)
						cam.lens_file = createTexPath dlg_main.m_userName (filenameFromPath ppath)
						appendFileInfo &vecFiles ppath newfile
					)

				)
			)

			--Vray 3 xml materials
			try
			(
				local mats = getClassInstancesSave VRayVRmatMtl
				for mat in mats do
				(
					local f = mat.filename
					if not existsFile f then
						f = mapPaths.getFullFilePath f
					local assets = findVray3XmlPaths f
					for assetPath in assets do
					(
						if not existsFile assetPath  then
							assetPath = mapPaths.getFullFilePath assetPath
						if existsFile assetPath then
						(
							local newpath = (filenameFromPath assetPath)
							newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
							local newfile = ("tex/" + filenameFromPath assetPath)
							appendFileInfo &vecFiles assetPath newfile
						)
					)
				)
			)
			catch()

			if classof renderers.production == vrayrt then
			(
				if dlg_main.vrayGPUselected then
					renderers.production.engine_type = 2
				else
					renderers.production.engine_type = 0
			)

			--PhoenixFD
			try
			(
				local fds = getClassInstancesSave PhoenixSimulator
				join fds (getClassInstancesSave FireSmokeSim)
				join fds (getClassInstancesSave LiquidSim)
				local found = false
				oldPhoenixSimulatorPaths = #()
				oldPhoenixSimulatorOutputPaths = #()
				for fd in fds do
				(
					local f = parsePhoenixPath fd fd.rendinput
					local parsedF = f
					f = replaceAll f "#" "*"
					local files = getFiles f
					for fp in files do
					(
						local newpath = (filenameFromPath fp)
						newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
						local newfile = ("tex/" + filenameFromPath fp)
						appendFileInfo &vecFiles fp newfile
					)
					append oldPhoenixSimulatorPaths fd.rendinput
					append oldPhoenixSimulatorOutputPaths fd.simoutput
					fd.rendinput = createTexPath dlg_main.m_userName (filenameFromPath parsedF)
					fd.simoutput = ""
				)
			)
			catch()

			--VRayVolumeGrid
			try
			(
				local fds = getClassInstancesSave VRayVolumeGrid
				local found = false
				oldVRayVolumeGridPaths = #()
				for fd in fds do
				(
					local f = replaceAll fd.rendinput "#" "*"
					local files = getFiles f
					for fp in files do
					(
						local newpath = (filenameFromPath fp)
						newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
						local newfile = ("tex/" + filenameFromPath fp)
						appendFileInfo &vecFiles fp newfile
					)
					append oldVRayVolumeGridPaths fd.rendinput
					fd.rendinput = createTexPath dlg_main.m_userName (filenameFromPath fd.rendinput)
				)
			)
			catch()

			--Vray Framebuffer settings
			try
			(
				oldGlareImage = undefined
				oldGlareObstacleImage = undefined

				if (vfbControl #glare)[1] == 1 then
				(
					if (vfbControl #glaretype)[1] == "image" then
					(
						oldGlareImage = (vfbControl #glareimage)[1]
						if oldGlareImage != undefined and oldGlareImage.count > 0 and existsfile oldGlareImage then
						(
							appendFileInfo &vecFiles oldGlareImage ("tex/" + filenameFromPath oldGlareImage)
							vfbControl #glareimage (createTexPath dlg_main.m_userName (filenameFromPath oldGlareImage))
						)
					)
					else
					(
						if (vfbControl #glareuseobstacle)[1] == 1 then
						(
							oldGlareObstacleImage = (vfbControl #glareobstacleimage)[1]
							if oldGlareObstacleImage != undefined and oldGlareObstacleImage.count > 0 and existsfile oldGlareObstacleImage then
							(
								appendFileInfo &vecFiles oldGlareObstacleImage ("tex/" + filenameFromPath oldGlareObstacleImage)
								vfbControl #glareobstacleimage (createTexPath dlg_main.m_userName (filenameFromPath oldGlareObstacleImage))
							)
						)
					)
				)
			)
			catch()

			--VRayScannedMtl
			try
			(
				local fds = getClassInstancesSave VRayScannedMtl
				local found = false
				oldVRayScannedMtl = #()
				for fd in fds do
				(
					append oldVRayScannedMtl fd.filename
					fd.filename = createTexPath dlg_main.m_userName (filenameFromPath fd.filename)
				)
			)
			catch()

--VRayOSLTex
			try
			(
				local osls = getClassInstancesSave VRayOSLTex
				if osls.count == 0 then
					osls = getClassInstancesSave VRayOSLMtl
				if osls.count > 0 then
				(
					local ver = "2016"
					if (((maxVersion())[1] >= 17000) AND ((maxVersion())[1] < 17900)) then
						ver = "2015"
					else if (((maxVersion())[1] >= 18000) AND ((maxVersion())[1] < 18900)) then
						ver = "2016"
					else if (((maxVersion())[1] >= 19000) AND ((maxVersion())[1] < 19900)) then
						ver = "2017"
					else if ((maxVersion())[1] >= 19900) then
						ver = "2018"
					local pathvariable = "VRAY_OSL_PATH_3DSMAX"+ver+"_x64"

					local env = dotNetClass "System.Environment"
					local oslpath = env.GetEnvironmentVariable pathvariable
					if oslpath != undefined then
					(
						for oslfile in getFiles (oslpath + "\\*.h") do
						(
							appendFileInfo &vecFiles oslfile ("tex/" + filenameFromPath oslfile)
						)

					)
				)
			)
			catch()


			if rend.gi_on == true and rend.gi_primary_type == 0 and rend.adv_irradmap_mode == 6 then
			(
				--irr animation prepass
				print("GI: On|| Primary: IrrMap || Mode: aniPrePass")
				local oldoutput_splitFileName=rend.output_splitFileName
				local oldoutput_splitgbuffer = rend.output_splitgbuffer
				local oldoutput_rawFileName = rend.output_rawFileName
				if oldoutput_rawFileName == undefined then
					oldoutput_rawFileName = ""
				if oldoutput_splitFileName == undefined then
					oldoutput_splitFileName = ""
				rend.output_splitFileName=""
				rend.output_splitgbuffer = false
				oldirradmap_autoSaveFileName = rend.adv_irradmap_autoSaveFileName
				rend.adv_irradmap_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
				local anim_prePresetPath = dlg_main.changedMaxFile + ".anim_pre_pass1.rps"
				rend.adv_irradmap_autoSave = true
				rend.adv_irradmap_dontDelete = true
				local rawout = filenamefrompath oldoutput_rawFileName
				if rawout == "" then
					rawout = "output.jpg"
				rend.output_rawFileName = createOutputPath dlg_main.m_userName rawout
				local presetCats = (renderpresets.SaveCategories 0)
				deleteItem presetCats 2
				deleteItem presetCats 3
				renderpresets.Save 0 (fPath + "\\" + anim_prePresetPath) presetCats
				appendFileInfo &vecFiles (fPath + "\\" + anim_prePresetPath) (anim_prePresetPath) tcopy:false
				rend.adv_irradmap_mode = 7
				-- oldIrrLoadFilename = rend.adv_irradmap_loadFileName
				rend.adv_irradmap_loadFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
				irrPrepassSet = true
				settingsToWrite += "animprepass=1\n"
				rend.output_splitFileName = oldoutput_splitFileName
				rend.output_splitgbuffer = oldoutput_splitgbuffer
				rend.output_rawFileName = oldoutput_rawFileName
			)

			vrayIrrMulti=false
			if not isSingleFrameRender() and isVrayIrrMulti() then
			(
				vrayIrrMulti = true
				local vlpath = irrlc_pass1 fPath
				appendFileInfo &vecFiles (fPath + "\\" + vlpath) (vlpath) tcopy:false
				local vlpath2 = irrlc_pass2 fPath
				appendFileInfo &vecFiles (fPath + "\\" + vlpath2) (vlpath2) tcopy:false
				settingsToWrite += "irrmultipass=1\n"
				if rend.gi_secondary_type == 3 and rend.lightcache_mode == 1 then
					settingsToWrite += "irrmultipass_lc=1\n"


				oldIrrAutoSaveFilename = rend.adv_irradmap_autoSaveFileName
				-- oldIrrLoadFilename = rend.adv_irradmap_loadFileName
				oldIrrMode = rend.adv_irradmap_mode
				oldLCAutoSaveFilename = rend.lightcache_autoSaveFileName
				-- oldLCLoadFilename = rend.lightcache_loadFileName
				oldLCMode = rend.lightcache_mode

				rend.adv_irradmap_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
				rend.adv_irradmap_loadFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
				rend.adv_irradmap_mode = 2
				if rend.lightcache_mode == 2 then
				(
					rend.lightcache_autoSaveFileName = createTexPath dlg_main.m_userName (filenameFromPath oldLCAutoSaveFilename)
					rend.lightcache_loadFileName = createTexPath dlg_main.m_userName (filenameFromPath oldLCLoadFilename)
				)
				else
				(
					rend.lightcache_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
					rend.lightcache_loadFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
					rend.lightcache_mode = 2
				)
			)

			oldNumThreads = rend.system_numthreads
			rend.system_numthreads=0
			oldgi_irradmap_showCalcPhase = rend.gi_irradmap_showCalcPhase
			oldlightcache_showCalcPhase = rend.lightcache_showCalcPhase
			oldlightcache_numPasses = rend.lightcache_numPasses
			rend.gi_irradmap_showCalcPhase = true
			rend.lightcache_showCalcPhase = 1
			rend.lightcache_numPasses = 32

			try
			(
				oldprogressive_max_render_time = rend.progressive_max_render_time
				oldprogressive_maxSamples = rend.progressive_maxSamples
				olddmc_timeDependent = rend.dmc_timeDependent
				oldprogressive_maxSamples = renderers.production.max_paths_per_pixel
			)catch()
			try(olddmc_lockNoisePattern = rend.dmc_lockNoisePattern)catch()

			if isSingleFrameRender() then
			(
				saveExt = getFilenameType rendOutputFilename
				if (stricmp saveExt ".jpg") ==0 then
					jpeg.ijpegio.setQuality(100)

				if rend.imageSampler_type == 3 then -- progressive
				(
					settingsToWrite += "singleframeMaxVrayProgressive=1\n"
					settingsToWrite += "samplinglevel="+(getProgressivePasses()) as string+"\n"

					--merge script won't work if filename ends with digit, elements are already checked for that and raise an E
					rendOutputFilename = (pathConfig.removePathLeaf rendOutputFilename) + "\\"+ (removeTrailingDigits (getFilenameFile rendOutputFilename)) + (getFilenameType rendOutputFilename)

					rend.progressive_max_render_time = 0

					if classof renderers.production ==	vrayrt then
						rend.max_paths_per_pixel = ceil ((getProgressivePasses()) / distributedMachines as float)
					else
						rend.progressive_minSamples = 1
						rend.progressive_maxSamples = ceil ((getProgressivePasses()) / distributedMachines as float)

					try(renderers.production.max_render_time = rend.progressive_max_render_time)catch()
					try(rend.dmc_timeDependent = false)catch()
					try(rend.dmc_lockNoisePattern = false)catch()
				)

				settingsToWrite += "singleframeMaxVrayNew2=1\n"
				local primary = "undef"
				if rend.gi_on == true then
				(
					if rend.gi_primary_type == 0 and rend.adv_irradmap_mode ==  2 then
						primary = "IRRf"
					else if rend.gi_primary_type == 0 then
						primary = "IRR"
					else if rend.gi_primary_type == 1 then
						primary = "PM"
					else if rend.gi_primary_type == 2 then
						primary = "QMC"
					else if rend.gi_primary_type == 3 and rend.lightcache_mode == 2 then
						primary = "LCf"
					else if rend.gi_primary_type == 3 then
						primary = "LC"
				)

				local secondary = "undef"
				if rend.gi_on == true then
				(
					if rend.gi_secondary_type == 1 then
						secondary = "PM"
					else if rend.gi_secondary_type == 2 then
						secondary = "QMC"
					else if rend.gi_secondary_type == 3 and rend.lightcache_mode == 2 then
						secondary = "LCf"
					else if rend.gi_secondary_type == 3 then
						secondary = "LC"
				)

				if classof renderers.production == vrayrt then
				(
					rend.lightcache_mode = 0 --always use single frame as there are currently problems writing out the cache files
					if rend.gi_primary_type == 3 then
						primary = "QMC"
					if rend.gi_secondary_type == 3 then
						secondary = "QMC"
				)
			--	local vlpath4 = lc_pass4 fPath
			--	appendFileInfo &vecFiles (fPath + "\\" + vlpath4) (vlpath4) tcopy:false

				settingsToWrite += "primary=" + primary + "\n"
				settingsToWrite += "secondary="+secondary+"\n"

				oldRenderType = getrendertype()
				oldRegionX = rend.system_region_x
				oldRegionY = rend.system_region_y
				oldIrrAutoSaveFilename = rend.adv_irradmap_autoSaveFileName
				--oldIrrLoadFilename = rend.adv_irradmap_loadFileName
				oldIrrMode = rend.adv_irradmap_mode
				oldLCAutoSaveFilename = rend.lightcache_autoSaveFileName
				-- oldLCLoadFilename = rend.lightcache_loadFileName
				oldLCMode = rend.lightcache_mode
				oldSystemRegionMeaning = rend.system_region_meaning

				rend.system_region_x = 24
				rend.system_region_y = 24
				if not classof renderers.production == vrayrt then
				(
					if not primary == "IRRf" then
					(
						local vlpath = lc_pass1 fPath
						appendFileInfo &vecFiles (fPath + "\\" + vlpath) (vlpath) tcopy:false
						rend.adv_irradmap_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
						rend.adv_irradmap_loadFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrmap")
						rend.adv_irradmap_mode = 2
					)
					if not (primary == "LCf" or secondary == "LCf") then
					(
						local vlpath2 = lc_pass2 fPath
						appendFileInfo &vecFiles (fPath + "\\" + vlpath2) (vlpath2) tcopy:false
						rend.lightcache_autoSaveFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
						rend.lightcache_loadFileName = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrlmap")
						rend.lightcache_mode = 2
					)
				)
				rend.system_region_meaning = 0

				-- vray internal framebuffer
				oldVRoutput_getsetsfrommax = rend.output_getsetsfrommax
				oldVRoutput_width = rend.output_width
				oldVRoutput_height = rend.output_height
				oldVRoutput_on = rend.output_on
				oldVRoutput_aspect = rend.output_aspect
				oldVRoutput_saveRawFile = rend.output_saveRawFile
				oldVRoutput_genpreview = rend.output_genrpeview
				oldVRoutput_useram = rend.output_useram
				oldVRoutput_renderType = 0
				try (oldVRoutput_renderType = rend.output_renderType) catch ()
				oldVRoutput_splitgbuffer = rend.output_splitgbuffer
				oldVRrenderWidth = renderWidth
				oldVRrenderHeight = renderHeight
				oldVRrendSaveFile = rendSaveFile
				oldVRrendShowVFB = rendShowVFB
				oldVRoutput_rawFileName = rend.output_rawFileName
				oldVRoutput_splitFileName = rend.output_splitFileName

				local extension = ".exr"
				rend.output_getsetsfrommax = false
				rend.output_width = renderWidth
				rend.output_height = renderHeight
				rend.output_aspect = renderPixelAspect
				rend.output_genrpeview = false
				rend.output_useram = false
				try (rend.output_renderType = 3) catch ()

				if rend.output_on then
					rend.output_useram = true
				if rend.output_splitgbuffer then
				(
					rend.output_splitRGB=true
					rend.output_splitAlpha=true
				)
				if rend.output_on and (rend.output_saveRawFile or rend.output_splitgbuffer) then
				(
					rendSaveFile = false
				)
				else
				(
					rendSaveFile = true
					rend.output_on = false

					renderElementsMgr = maxOps.GetRenderElementMgr #Production
					for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
					(
						local elem = filenameFromPath (renderElementsMgr.GetRenderElementFilename n)
						renderElementsMgr.SetRenderElementFilename n (createTemprenderPath dlg_main.m_userName elem)
					)

					if rend.imageSampler_type != 3 then -- !progressive
					(
						setrendertype #region
						setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))
						setrendertype #crop
						setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))
					)
					else
					(
						setrendertype #region
						setAllRegionRect (Box2 0 0 (renderWidth) (renderHeight))
					)
				)

				if rend.output_rawFileName == "" or rend.output_rawFileName == undefined then
				(
					rend.output_rawFileName = getDefaultOutputName "vfb.exr"
				)
				if (getFilenameType rend.output_rawFileName) != ".exr" then
					rend.output_rawFileName = rend.output_rawFileName + ".exr"

				rend.output_rawFileName = createTemprenderPath dlg_main.m_userName (savefilenameFromPath rend.output_rawFileName)
				if rend.output_splitFileName == "" or rend.output_splitFileName == undefined then
				(
					rend.output_splitFileName = getDefaultOutputName "split.exr"
				)
				rend.output_splitFileName = createTemprenderPath dlg_main.m_userName (savefilenameFromPath rend.output_splitFileName)


				rendShowVFB = false
			)
			else
			(
				if rend.imageSampler_type == 3 then -- progressive
				(
					settingsToWrite += "animationMaxVrayProgr=1\n"
					settingsToWrite += "samplinglevel="+(getProgressivePasses()) as string+"\n"
					if getProgressiveThreshold() >=0 then
					(
						settingsToWrite += "noiselevel="+(getProgressiveThreshold()) as string+"\n"
						rend.progressive_noise_threshold = getProgressiveThreshold()
					)

					local framecount = 1
					if rendTimeType == 2 then
						framecount = (animationRange.end.frame as integer) - (animationRange.start.frame as integer) + 1
					if rendTimeType == 3 then
						framecount = (rendEnd.frame as integer) - (rendStart.frame as integer) +1
					if rendTimeType == 1 then
						framecount = 1
					framecount = floor((framecount as float) / rendNthframe)
					if framecount < 1 then
						framecount = 1

					rend.progressive_max_render_time = 0
					rend.progressive_minSamples = 1
					if classof renderers.production == vrayrt then
						renderers.production.max_paths_per_pixel = getProgressivePasses()
					else
						rend.progressive_maxSamples = ceil (getProgressivePasses())
					try(renderers.production.max_render_time = rend.progressive_max_render_time)catch()
				)

				oldVRoutput_useram = rend.output_useram
				oldVRoutput_rawFileName = rend.output_rawFileName
				oldVRoutput_splitFileName = rend.output_splitFileName

				rend.output_useram = true

				local extension = ".exr"

				if rend.output_saveRawFile and rend.output_rawFileName != undefined and rend.output_rawFileName != "" then
					rend.output_rawFileName =  createOutputPath dlg_main.m_userName (savefilenameFromPath rend.output_rawFileName)

				if rend.output_splitgbuffer and rend.output_splitFileName != undefined and rend.output_splitFileName != "" then
					rend.output_splitFileName = createOutputPath dlg_main.m_userName (savefilenameFromPath rend.output_splitFileName )

				if shademaprendering then
				(
					try
					(
						local tmpfileload = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + "0000.vrst")
						local tmpfilewrite  = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".vrst")
						local cams = getClassInstancesSave VRayStereoscopic
						for cam in cams do
						(
							cam.shademap_mode = 2
							cam.shademap_file = tmpfileload
						)

						settingsToWrite += "shademapmode=1\n"

						local filename = dlg_main.changedMaxFile + ".shdmap.ms"
						local filepath = (fPath + "\\" + filename)
						file = openFile filepath mode:"a"
						if file == undefined then
							file = createFile filepath

						if file != undefined then
						(
							local fileTxt = "fn at2VrayShadermap1 =
(
	cams = getClassInstances VRayStereoscopic
	for cam in cams do
	(
		cam.shademap_mode = 1
		cam.shademap_file = @\""+tmpfilewrite+"\"
	)
	rendSaveFile = false
	renderElementsMgr = maxOps.GetRenderElementMgr #Production
	for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
	(
		el = renderElementsMgr.GetRenderElement n
		el.enabled = false
	)
)

fn at2PreRenderSkript =
(
	if existsFile (\"c:\\\\logs\\\\ShademapYes.txt\") then
		at2VrayShadermap1()

)

at2PreRenderSkript()
"

							format "%" fileTxt to:file

							callbacks.addscript #preRender id:#at2PreRender fileName:(createPath dlg_main.m_userName (dlg_main.changedMaxFile + ".shdmap.ms")) persistent:true
						)
						close file
						appendFileInfo &vecFiles filepath filename tcopy:false
					)
					catch(format "vray.ms:shademap *** % ***\n" (getCurrentException()))
				)
			)


			rend.options_dontRenderImage = false
			rend.system_frameStamp_on = false
			oldRegionX = rend.system_region_x
			oldRegionY = rend.system_region_y
			rend.system_region_x = 16
			rend.system_region_y = 16
			rend.system_distributedRender = false
			rend.photonMap_autoSave = false
			rend.photonMap_loadFileName = ""

			vray_gpu_dlg.confirmed = false
		)
	),

	fn postSave zip =
	(

		rend = renderers.production
		--try
		--(
			if classof renderers.production == vray or classof renderers.production == vrayrt then
			(
				if classof renderers.production == vrayrt then
					rend = rend.V_Ray_settings


				if oldcauFilename == undefined then oldcauFilename = ""
				if oldRenderType == undefined then oldRenderType = #view
				if oldVRoutput_getsetsfrommax == undefined then oldVRoutput_getsetsfrommax = true
				if oldVRoutput_width == undefined then oldVRoutput_width = 100
				if oldVRoutput_height == undefined then oldVRoutput_height = 100
				if oldVRoutput_on == undefined then oldVRoutput_on = false
				if oldVRoutput_aspect == undefined then oldVRoutput_aspect = 1.0
				if oldVRoutput_saveRawFile == undefined then oldVRoutput_saveRawFile = false
				if oldVRoutput_genpreview == undefined then oldVRoutput_genpreview = false
				if oldVRoutput_useram == undefined then oldVRoutput_useram = false
				if oldVRoutput_renderType == undefined then oldVRoutput_renderType = 1
				if oldVRoutput_splitgbuffer == undefined then oldVRoutput_splitgbuffer = false
				if oldVRrenderWidth == undefined then oldVRrenderWidth = 100
				if oldVRrenderHeight == undefined then oldVRrenderHeight = 100
				if oldVRrendSaveFile == undefined then oldVRrendSaveFile = true
				if oldIrrAutoSaveFilename == undefined then oldIrrAutoSaveFilename = ""
				if oldIrrLoadFilename == undefined then oldIrrLoadFilename = ""
				if oldIrrMode == undefined then oldIrrMode = 1
				if oldLCAutoSaveFilename == undefined then oldLCAutoSaveFilename = ""
				if oldLCLoadFilename == undefined then oldLCLoadFilename = ""
				if oldLCMode == undefined then oldLCMode = 1
				if oldSystemRegionMeaning == undefined then oldSystemRegionMeaning = ""
				if oldNumThreads == undefined then oldNumThreads = 0
				if oldgi_irradmap_showCalcPhase == undefined then oldgi_irradmap_showCalcPhase = false
				if oldlightcache_showCalcPhase == undefined then oldlightcache_showCalcPhase = 0
				if oldlightcache_numPasses == undefined then oldlightcache_numPasses = 32
				if oldVRoutput_splitFileName == undefined then oldVRoutput_splitFileName = ""
				if oldVRoutput_useram == undefined then oldVRoutput_useram = ""
				if oldVRoutput_rawFileName == undefined then oldVRoutput_rawFileName = ""
				if oldVRoutput_splitFileName == undefined then oldVRoutput_splitFileName = ""

				try
				(
					rend.lightcache_multipleViews = oldlightcache_multipleViews
				)catch()
				try
				(
					rend.gi_irradmap_multipleViews = oldgi_irradmap_multipleViews
				)catch()
				rend.system_numthreads = oldNumThreads
				rend.gi_irradmap_showCalcPhase = oldgi_irradmap_showCalcPhase
				rend.lightcache_showCalcPhase = oldlightcache_showCalcPhase
				rend.lightcache_numPasses = oldlightcache_numPasses

				if rend.gi_on AND oldIrrLoadFilename != undefined AND rend.gi_primary_type == 0 then
				(
					rend.adv_irradmap_loadFileName = oldIrrLoadFilename
				)
				if rend.gi_on AND oldphFilename != undefined AND rend.gi_primary_type == 1 OR rend.gi_secondary_type == 1 AND rend.photonMap_mode == 0 then
				(
					rend.photonMap_loadFileName = oldphFilename
				)
				if rend.gi_on AND oldLCLoadFilename != undefined AND rend.gi_primary_type == 3 OR rend.gi_secondary_type == 3 AND  rend.lightcache_mode == 2 then
				(
					rend.lightcache_loadFileName = oldLCLoadFilename
				)
				if rend.gi_on AND oldcauFilename != undefined AND rend.caustics_on == true AND rend.caustics_mode == 1 then
				(
					rend.caustics_loadFileName = oldcauFilename
				)
				if isSingleFrameRender() then
				(
					setrendertype oldRenderType
					oldRenderType = getrendertype()
					rend.adv_irradmap_autoSaveFileName = oldIrrAutoSaveFilename
					rend.adv_irradmap_loadFileName = oldIrrLoadFilename
					rend.adv_irradmap_mode = oldIrrMode
					rend.lightcache_autoSaveFileName = oldLCAutoSaveFilename
					rend.lightcache_loadFileName = oldLCLoadFilename
					rend.lightcache_mode = oldLCMode
					rend.system_region_meaning = oldSystemRegionMeaning

					rend.output_getsetsfrommax = oldVRoutput_getsetsfrommax
					rend.output_width = oldVRoutput_width
					rend.output_height = oldVRoutput_height
					rend.output_on = oldVRoutput_on
					rend.output_aspect = oldVRoutput_aspect
					rend.output_saveRawFile = oldVRoutput_saveRawFile
					rend.output_genrpeview = oldVRoutput_genpreview
					rend.output_useram = oldVRoutput_useram
					try (rend.output_renderType = oldVRoutput_renderType) catch ()
					rend.output_splitgbuffer = oldVRoutput_splitgbuffer
					renderWidth = oldVRrenderWidth
					renderHeight = oldVRrenderHeight
					rendSaveFile = oldVRrendSaveFile
					rendShowVFB = oldVRrendShowVFB
					rend.output_rawFileName = oldVRoutput_rawFileName
					rend.output_splitFileName = oldVRoutput_splitFileName
				)
				else
				(
					rend.output_useram = oldVRoutput_useram
					rend.output_rawFileName = oldVRoutput_rawFileName
					rend.output_splitFileName = oldVRoutput_splitFileName
				)

				if irrPrepassSet then
				(
					--undo settings made for animation prepass rendering
					if oldirradmap_autoSaveFileName == undefined then oldirradmap_autoSaveFileName = ""
					rend.adv_irradmap_autoSaveFileName = oldirradmap_autoSaveFileName
					rend.adv_irradmap_mode = 6
					rend.adv_irradmap_loadFileName = createTemprenderPath dlg_main.m_userName (filenameFromPath rend.adv_irradmap_loadFileName)
					irrPrepassSet = false
				)

				if shademaprendering then
				(
					callbacks.removeScripts #preRender id:#at2PreRender
				)

				if vrayIrrMulti then
				(
					rend.adv_irradmap_autoSaveFileName = oldIrrAutoSaveFilename
					rend.adv_irradmap_loadFileName = oldIrrLoadFilename
					rend.adv_irradmap_mode = oldIrrMode
					rend.lightcache_autoSaveFileName = oldLCAutoSaveFilename
					rend.lightcache_loadFileName = oldLCLoadFilename
					rend.lightcache_mode = oldLCMode
				)

				--Vray Framebuffer settings
				if oldGlareImage != undefined then
					vfbControl #glareimage oldGlareImage
				if oldGlareObstacleImage != undefined then
					vfbControl #glareobstacleimage oldGlareObstacleImage

				--VRayPhysicalCamera
				local cams = getClassInstancesSave VRayPhysicalCamera
				join cams (getClassInstancesSave Physical)
				local iCam=1
				for cam in cams do
				(
					local useLens = false
					try(useLens = cam.use_lens_file) catch() -- not possible with hasProperty
					if cam.distortion_type == 2 or useLens then
					(
						cam.lens_file = oldLensFiles[iCam]
						iCam=iCam+1
					)
				)

				try
				(
					local fds = getClassInstancesSave PhoenixSimulator
					join fds (getClassInstancesSave FireSmokeSim)
					join fds (getClassInstancesSave LiquidSim)
					i=1
					for fd in fds do
					(
						fd.rendinput = oldPhoenixSimulatorPaths[i]
						fd.simoutput = oldPhoenixSimulatorOutputPaths[i]
						i=i+1
					)
				)
				catch()

				--VRayScannedMtl
				try
				(
					local fds = getClassInstancesSave VRayScannedMtl
					local i=1
					for fd in fds do
					(
						fd.filename = oldVRayScannedMtl[i]
						i=i+1
					)
				)
				catch()

				try
				(
					local fds = getClassInstancesSave VRayVolumeGrid
					i=1
					for fd in fds do
					(
						fd.rendinput = oldVRayVolumeGridPaths[i]
						i=i+1
					)
				)
				catch( format "VRayVolumeGrid*** % ***\n" (getCurrentException()) )

				try
				(
					if classOf renderers.production == vrayrt then
					(
						renderers.production.max_paths_per_pixel = oldprogressive_maxSamples
					)
					else
					(
						rend.progressive_max_render_time = oldprogressive_max_render_time
						rend.progressive_maxSamples = oldprogressive_maxSamples
						rend.dmc_timeDependent = olddmc_timeDependent
					)
				)catch()
				try(rend.dmc_lockNoisePattern = olddmc_lockNoisePattern)catch()

				rend.system_region_x = oldRegionX
				rend.system_region_y = oldRegionY
			)
		--)
		--catch(format "vray.ms:3 *** % ***\n" (getCurrentException()))
		renderSceneDialog.update()
	)
)

struct ValFR
(
	CAUSTICS_SINGLE = 1,
	CAUSTICS_REUSE = 2,
	GI_STILL = 3,
	GI_CAMERA_FLY = 4,
	INTERPOLATION_MAT = 5,
	GI_CAMERA_FLY_PREPASS35 = 6,
	GI_CAMERA_FLY_RENDER35 = 7,

	oldGIFilename = "",
	oldFinalToonPath = "",
	bVersion35 = false,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Final Render";
	),
	fn getIdentifier =
	(
		return #(finalRender_stage_1)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == finalRender_stage_1 then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			append resultList (tr id:2053 index:index validator:val severity:2 message:"Final Render is not supported by Render Farm Application anymore")
			return 0

			if isSingleFrameRender() then
				append resultList (tr id:2001 index:index validator:val severity:2 message:"Final Render still frame render not yet supported on Render Farm Application")

--Antialiasing
			if rend.useAntialiasing==true then
			(
				if rend.aaSamplerRef != undefined then
				(
					sampref = rend.aaSamplerRef
					if sampref.minSamplesInt <= 1 then -- equals 1/16 samples
						append resultList (tr id:2002 index:index validator:val severity:1 message:"Anti-Aliasing: Minimum Samples seems very low.")

					if sampref.minSamplesInt >=4 then -- equals 4 samples
						append resultList (tr id:2003 index:index validator:val severity:1 message:"Anti-Aliasing: Minimum Samples seems very high.")

					if sampref.maxSamplesInt <= 3 then -- equals 1 samples
						append resultList (tr id:2004 index:index validator:val severity:1 message:"Anti-Aliasing: Maximum Samples seems very low.")

					if sampref.maxSamplesInt >=5 then -- equals 16 samples
						append resultList (tr id:2005 index:index validator:val severity:1 message:"Anti-Aliasing: Maximum Samples seems very high.")

					if sampref.showSamples then
						append resultList (tr id:2006 index:index validator:val severity:1 message:"Anti-Aliasing: Show Samples is activated.")
				)

				if rend.filterImage==false then
					append resultList (tr id:2007 index:index validator:val severity:1 message:"Anti-Aliasing: Filter Image is disabled")
			)
			else
			(
				append resultList (tr id:2008 index:index validator:val severity:1 message:"Global Options: Antialiasing is disabled")
			)

			if NOT rend.filterMaps then
				append resultList (tr id:2009 index:index validator:val severity:1 message:"Anti-Aliasing: Filter Maps is disabled")

--General Options
			if rend.useMaterialOverwrite then
				append resultList (tr id:2010 index:index validator:val severity:1 message:"Global Options: Material Override is activated.")

			if rend.useDistributedRendering then
				append resultList (tr id:2011 index:index validator:val severity:2 message:"Global Options: Distributed Rendering is activated.")
			if rend.useInformationStamp then
				append resultList (tr id:2012 index:index validator:val severity:2 message:"Global Options: Information Stamp is activated.")

			if NOT rend.useShadows then
				append resultList (tr id:2013 index:index validator:val severity:1 message:"Global Options: Shadows is deactivated.")
			if NOT rend.useMappings then
				append resultList (tr id:2014 index:index validator:val severity:1 message:"Global Options: Mapping is deactivated.")
			if NOT rend.useBlurry then
				append resultList (tr id:2015 index:index validator:val severity:1 message:"Global Options: Blurry Reflet/Refract is deactivated.")
			if NOT rend.useAutoRefl then
				append resultList (tr id:2016 index:index validator:val severity:1 message:"Global Options: Reflect/Refract Maps is deactivated.")
			if NOT rend.useReflections then
				append resultList (tr id:2017 index:index validator:val severity:1 message:"Raytracing: Reflection is deactivated.")
			if NOT rend.useRefractions then
				append resultList (tr id:2018 index:index validator:val severity:1 message:"Raytracing: Refraction is deactivated.")

			if rend.useCaustics OR rend.useVolumeCaustics then
			(
				if rend.csEngineRef != undefined then
				(
					engineref = rend.csEngineRef
					if NOT engineref.reUsePhotons and NOT onlyOneFrame() then
						append resultList (tr id:2019 index:index validator:val severity:1 message:"Caustics: Single frame mode activated." flagMoreInfos:true type:CAUSTICS_SINGLE)

					if engineref.reUsePhotons then
						append resultList (tr id:2020 index:index validator:val severity:1 message:"Caustics: Caustic reuse mode activated." flagMoreInfos:true type:CAUSTICS_REUSE)

					if engineref.reUsePhotons then
						append resultList (tr id:2021 index:index validator:val severity:1 message:"Caustic map path can not be modified by Farminizer. In case of caustic from file contact Render Farm Application")

				)
			)
--GI
			bVersion35 = false
			if hasProperty rend "giEngineSec" then
			(
				bVersion35=true
			)
			if rend.giEnable then
			(

				if not bVersion35 then
				(
					giengine = rend.giEngine -- 0: HyperGI 1: adaptiveQMC 2: Image 3: Quasi Monte-Carlo
					--HyperGI
					if giengine == 0 then
						append resultList (tr id:2022 index:index validator:val severity:2 message:"Global Illumination: \"HyperGI\" is not supported, please set to Adaptive DMC.")
					--image
					if giengine == 2 then
						append resultList (tr id:2023 index:index validator:val severity:2 message:"Global Illumination: \"FR-Image\" is not supported, please set to Adaptive DMC.")

					--adaptive QMC
					if giengine == 1 AND rend.giEngineRef != undefined then
					(
						giengineref = rend.giEngineRef
					--	if giengineref.
					--		vpush(0,1,0,"", "Global Illumination: Details Enhancement is enabled", FALSE)

						if giengineref.maxRate >=1 then
							append resultList (tr id:2024 index:index validator:val severity:1 message:"Global Illumination: Max Rate seems to be very high")

						if giengineref.solutionMode == 1 AND giengineref.animationMode == 0 then --camera fly
						(
							append resultList (tr id:2025 index:index validator:val severity:1 message:"Global Illumination: Attention, Solution is set to \"camera fly\"" flagMoreInfos:true type:GI_CAMERA_FLY)

							if giengineref.animationPass == 0 then --prepass
								append resultList (tr id:2026 index:index validator:val severity:2 message:"Global Illumination: Animation Pass Prepass not supported")

							if giengineref.animationPass == 1 then --render
							(
								if giengineref.loadFrom == "" OR giengineref.loadFrom == undefined then
									append resultList (tr id:2027 index:index validator:val severity:2 message:"Global Illumination: \"Load From...\" File not found")
								else if giengineref.loadFrom != "" AND giengineref.loadFrom != undefined AND existsFile (mapPaths.getFullFilePath giengineref.loadFrom) == false then
									append resultList (tr id:2028 index:index validator:val severity:2 message:"Global Illumination: \"Load From...\" File not found")

							)
						)

						if giengineref.solutionmode == 1 AND giengineref.animationMode == 1 then --character animation
							append resultList (tr id:2029 index:index validator:val severity:2 message:"Global Illumination: Solution Mode \"Character Animation\" not yet supported, please contact Render Farm Application")

						if giengineref.solutionMode == 0 then --single frame
						(
							append resultList (tr id:2030 index:index validator:val severity:1 message:"Global Illumination: Attention, Solution is set to \"still\"" flagMoreInfos:true type:GI_STILL)
							if giengineref.reuse then
								append resultList (tr id:2031 index:index validator:val severity:2 message:"Global Illumination: GI Solution Reuse is not supported")

							if giengineref.lock then
								append resultList (tr id:2032 index:index validator:val severity:2 message:"Global Illumination: GI Solution Lock is not supported")

						)
					)
				)
				else --version 3.5
				(
			--tests for first gi engine
					giengine = rend.giEngine -- 0: Quasi Monte-Carlo 1: Image 2: AdaptiveQMC 3: HyperGI 4: HarmonicsGI
					--HyperGI
					if giengine == 3 then
						append resultList (tr id:2033 index:index validator:val severity:2 message:"Global Illumination: \"HyperGI\" is not supported, please set to Adaptive DMC.")
					--image
					if giengine == 1 then
						append resultList (tr id:2034 index:index validator:val severity:2 message:"Global Illumination: \"FR-Image\" is not supported, please set to Adaptive DMC.")

					--harmonics
					if giengine == 3 AND rend.giEngineRef != undefined then
					(
						giengineref = rend.giEngineRef

						if giengineref.samples < 300 then
							append resultList (tr id:2035 index:index validator:val severity:1 message:"Global Illumination: Harmonics: Samples seems to be very low")

						if giengineref.samples > 2500 then
							append resultList (tr id:2036 index:index validator:val severity:1 message:"Global Illumination: Harmonics: Samples seems to be very high")
					)

					--adaptive QMC
					if giengine == 2 AND rend.giEngineRef != undefined then
					(
						giengineref = rend.giEngineRef

						if giengineref.maxRate >=1 then
							append resultList (tr id:2037 index:index validator:val severity:1 message:"Global Illumination: Max Rate seems to be very high")
					)

			--tests for secondary gi Engine
					giengine = rend.giEngineSec -- 0: Quasi Monte-Carlo 1: Image 2: HyperGI 3: HarmonicsGI
					--HyperGI
					if giengine == 2 then
						append resultList (tr id:2038 index:index validator:val severity:2 message:"Global Illumination: \"HyperGI\" is not supported, please set to QMC or Harmonics.")
					--image
					if giengine == 1 then
						append resultList (tr id:2039 index:index validator:val severity:2 message:"Global Illumination: \"FR-Image\" is not supported, please set to QMC or Harmonics.")

					--harmonics
					if giengine == 3 AND rend.giEngineSecRef != undefined then
					(
						giengineref = rend.giEngineSecRef

						if giengineref.samples < 300 then
							append resultList (tr id:2040 index:index validator:val severity:1 message:"Global Illumination: Harmonics: Samples seems to be very low")

						if giengineref.samples > 2500 then
							append resultList (tr id:2041 index:index validator:val severity:1 message:"Global Illumination: Harmonics: Samples seems to be very high")
					)

			--tests for files
					if NOT (rend.giEngine == 0 AND rend.giEngineSec == 0 ) then
					(
						if rend.giSolutionMode == 1 AND rend.giSolutionAnimationMode == 0 then --camera fly
						(
							if rend.giSolutionMultipleFiles == 0 then
							(
								if rend.giSolutionAnimationPass == 0 then --prepass
									append resultList (tr id:2042 index:index validator:val severity:2 message:"Global Illumination: Attention, Solution is set to \"camera fly\"" flagMoreInfos:true type:GI_CAMERA_FLY_PREPASS35)

								if rend.giSolutionAnimationPass == 1 then --render
								(
									append resultList (tr id:2043 index:index validator:val severity:1 message:"Global Illumination: Attention, Solution is set to \"camera fly\"" flagMoreInfos:true type:GI_CAMERA_FLY_RENDER35)

									if rend.giUseSolutionFile then
									(
										if rend.giSolutionFile == "" OR rend.giSolutionFile == undefined then
											append resultList (tr id:2044 index:index validator:val severity:2 message:"Global Illumination: \"Solution...\" File not found")
										else if rend.giSolutionFile != "" AND rend.giSolutionFile != undefined AND existsFile (mapPaths.getFullFilePath rend.giSolutionFile) == false then
											append resultList (tr id:2045 index:index validator:val severity:2 message:"Global Illumination: \"Solution...\" File not found")
									)
								)
							)
							else
							(
								append resultList (tr id:2046 index:index validator:val severity:2 message:"Global Illumination: \"camera fly+Multiple Files\" is not yet supported, use \"Single Frame\" instead")
							)
						)

						if rend.giSolutionMode == 1 AND rend.giSolutionAnimationMode == 1 then --character animation
							append resultList (tr id:2047 index:index validator:val severity:2 message:"Global Illumination: Solution Mode \"Character Animation\" not yet supported, please contact Render Farm Application")

						if rend.giSolutionMode == 0 then --single frame
						(
							append resultList (tr id:2048 index:index validator:val severity:1 message:"Global Illumination: Attention, Solution is set to \"still\"" flagMoreInfos:true type:GI_STILL)
							if rend.giSolutionReuse then
								append resultList (tr id:2049 index:index validator:val severity:2 message:"Global Illumination: GI Solution Reuse is not supported")

							if rend.giSolutionLock then
								append resultList (tr id:2050 index:index validator:val severity:2 message:"Global Illumination: GI Solution Lock is not supported")

							if rend.giPrepassOnly then
								append resultList (tr id:2051 index:index validator:val severity:2 message:"Global Illumination: GI Solution Prepass Only is not supported")
						)
					)
				)
			)
--FRMtl
			mtls = getClassInstancesSave fr_architectural
			for m in mtls do
			(
				if m.refl_interpolate == true OR m.refr_interpolate == true then
				(
					append resultList (tr id:2052 index:index validator:val severity:1 message:("Final Render material \""+m.name+"\" uses interpolation") flagMoreInfos:true type:INTERPOLATION_MAT)
				)

			)

		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValFR!"
		case result.type of
		(
			CAUSTICS_SINGLE:
				st="This mode is used for non static scenes only !
A non static scene includes animated objects, morphing objects, animated lights or textures
Attention, that recomputing mode forceFianl render to redo the Caustic photon map solution each frame
that causes different solutions in each frame and can produce a flickering in the final output
to reduce flickering you could increase the Caustic photon settings but that rise the rendertime per image without guarantee of flickerfree output
Note: for static scenes save Caustic photonmap to file"
			CAUSTICS_REUSE:
				st="This mode is used for static scenes only !
A static scene include NO animated objects, NO morphing objects, NO animated lights or textures
! the camera is the only moving part
when Using that mode you first need to pre-render the Photon map to file
-diable Anti alising
-render first frame only
-press \"Save Photons\" and \"load Photons\" from file
Note: when Photons NOT load from file each time the render start a new Photon map is generated
that can produce a flickering in the final output"
			GI_STILL:
				st="GI Solution mode \"still\" is used for non static scenes only !
A non static scene include animated objects, morphing objects, animated lights or textures
Attention, that mode force Final Render to redo the light solution each frame
that causes different solutions in each frame and can produce a flickering in the final output
to reduce flickering you could increase the settings but that rise the rendertime per image without guarantee of flickerfree output
Note: A flickerfree animation can be generated by using Quasi Montecarlo with the disadvantage of high rendertime per image"
			GI_CAMERA_FLY:
				st="GI Solution mode \"camera Fly\" is used to bake the light solution to file
To bake the light solution to file on your computer you MUST have a static scene
A static scene include no animated objects, no morphing objects, no animated lights or textures
! the camera is the only moving part
-set animation \"prepass\" and update solution
-set \"save to\" path and filename
-set frame range you need
-set frame step to 10 or higher depending on the camera speed
-hit render
-you will notice the file size is growing as more frames are rendered
-on renderend set map \"Load from\"
-set animation pass \"rendering\""
			GI_CAMERA_FLY_PREPASS35:
				st="Gi solution mode \"camera Fly + single frame\" is used for static scenes only
A static scene include no animated objecs, no animated lights and textures
-set animation \"prepass\" and enable \"update\"
-enable solution and set file name and file path (select ...)
-set frame step to 10 or higher depening on camera speed
-hit render and finish the sequence
-if render finish switch \"prepass\" to \"rendering\""
			GI_CAMERA_FLY_RENDER35:
				st="Gi solution mode \"camera Fly + single frame\" is used for static scenes only
A static scene include no animated objecs, no animated lights and textures
-set animation \"prepass\" and enable \"update\"
-enable solution and set file name and file path (select ...)
-set frame step to 10 or higher depening on camera speed
-hit render and finish the sequence
-if render finish switch \"prepass\" to \"rendering\""
		)
		if result.type == INTERPOLATION_MAT then
		(
			if queryBox "It is not recommended to enable interpolation for animation renderings. Interpolation forces Final Render to pre-render the reflection/refraction map.
That can produce a flicker in the final output. Do you want to disable Interpolation for all materials?" beep:false then
			(
				mtls = getClassInstancesSave fr_architectural
				for m in mtls do
				(
					m.refl_interpolate = false
					m.refr_interpolate = false
				)
			)
		)
		else
			messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == finalRender_stage_1 then
		(
			if rend.giEnable then
			(
				if not bVersion35 then
				(
					giengine = rend.giEngine
					if giengine == 1 AND rend.giEngineRef != undefined then
					(
						giengineref = rend.giEngineRef
						if giengineref.animationPass == 1 then --render
						(
							try
							(
								oldGIFilename = giengineref.loadFrom
								mpath = (mapPaths.getFullFilePath giengineref.loadFrom)
								if existsfile mpath then
								(
									appendFileInfo &vecFiles mpath ("tex/" + filenameFromPath mpath)
									giengineref.loadFrom = createTexPath dlg_main.m_userName (filenameFromPath mpath)
								)
								else
									format "fr.ms: *** Error: File not found ***"
							)
							catch
							(
								format "fr.ms: *** % ***\n" (getCurrentException())
							)
						)
					)
				)
				else -- version 3.5
				(
					rend.giShowPrepass = true
					giengine = rend.giEngine
					giengine2 = rend.giEngineSec
					if giengine == 2 OR giengine == 4 OR giengine2 == 3 then
					(
						if rend.giSolutionAnimationPass == 1 then --render
						(
							try
							(
								oldGIFilename = rend.giSolutionFile
								mpath = (mapPaths.getFullFilePath rend.giSolutionFile)
								if existsfile mpath then
								(
									appendFileInfo &vecFiles mpath ("tex/" + filenameFromPath mpath)
									rend.giSolutionFile = createTexPath dlg_main.m_userName (filenameFromPath mpath)
								)
								else
									format "fr.ms: *** Error: File not found ***"
							)
							catch
							(
								format "fr.ms: *** % ***\n" (getCurrentException())
							)
						)
					)
					if rend.giEngine == 0 AND rend.giEngineSec == 0 then
					(
						rend.giSolutionMode = 0
						rend.giSolutionReuse = false
						rend.giSolutionLock = false
						rend.giPrepassOnly = false
						rend.giSolutionFile = ""
						rend.giUseSolutionFile = false
					)
				)
			)

--finaltoon render effect
			for i = 1 to numEffects do
			(
				eff = getEffect i
				if classof eff == finalToonrenderEffect then
				(
					if eff.bitmap != undefined then
					(
						try
						(
							local st = (mapPaths.getFullFilePath eff.bitmap.filename) as string
							stOld = eff.bitmap.filename
							stNew = st

							appendFileInfo &vecFiles st ("tex/" + filenameFromPath stNew)

							--TODO can't set filename?
							eff.bitmap.filename = filenameFromPath stNew
							oldFinalToonPath = stOld
						)
						catch
						(
							format "fr.ms: *** % ***\n" (getCurrentException())
						)
					)
				)
			)
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == finalRender_stage_1 then
		(
			if rend.giEnable then
			(
				if not bVersion35 then
				(
					giengine = rend.giEngine
					if giengine == 1 AND rend.giEngineRef != undefined then
					(
						giengineref = rend.giEngineRef
						if giengineref.animationPass == 1 then --render
						(
							giengineref.loadFrom = oldGIFilename
						)
					)
				)
				else
				(
					giengine = rend.giEngine
					giengine2 = rend.giEngineSec
					if giengine == 2 OR giengine == 4 OR giengine2 == 3 then
					(
						if rend.giSolutionAnimationPass == 1  then --render
						(
							rend.giSolutionFile = oldGIFilename
						)
					)
				)
			)
			for i = 1 to numEffects do
			(
				eff = getEffect i
				if classof eff == finalToonrenderEffect  AND oldFinalToonPath != "" then
				(
					if eff.bitmap != undefined then
					(
						eff.bitmap.filename = oldFinalToonPath
					)
				)
			)
		)
	)
)

struct ValMental
(
	GI_1 = 1,
	GI_2 = 2,
	GI_3 = 3,
	GI_4 = 4,
	GI_5 = 5,
	GI_6 = 6,
	GI_7 = 7,
	GI_8 = 8,
	GI_9 = 9,
	GI_10 = 10,
	GI_11 = 11,
	GI_12 = 12,
	GI_13 = 13,
	GI_14 = 14,
	GI_15 = 15,
	GI_16 = 16,
	GI_17 = 17,
	GI_18 = 18,
	GI_19 = 19,
	GI_20 = 20,
	GI_21 = 21,
	GI_22 = 22,
	GI_23 = 23,
	GI_24 = 24,

	INTERPOLATION_MAT = 25,
	SINGLE_PHOTON_PRERENDER = 26,
	SINGLE_PHOTON_PRERENDER2 = 27,
	MI_STANDALONE = 28,
	ENABLE_RAYTRACING = 29,
	ENABLE_SHADOWS = 30,

	oldFGFilename = "",
	oldPhFilename = "",
	oldShadowMapsFilename = "",
	oneFileIncremental = false,
	oldFGInterpolateNFrames =2,
	oldSkipFinalRender = false,
	oldShadowsEnable = false,

	oldRenderType = #crop,
	oldActiveViewport = 1,
	oldRegionRect = (Box2 0 0 100 100),
	oldGIUseFile = false,
	oldGIFreeze = false,
	oldFGUseFile = false,
	oldFGFreeze = false,
	oldXres = 100,
	oldYres = 100,
	oldUse_Placeholders = false,

	miExport = false,

	is_renderer_validator = true,

	fn findFGFiles rend=
	(
		local fgpath = rend.FinalGatherFilename
		local fgFiles = #()
		local num = #("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
		if fgpath != undefined and fgpath.count > 4 and matchPattern fgpath pattern:"*.fgm" then
		(
			local p = (substring fgpath 1 (fgpath.count - 4))
			while(findItem num p[p.count] != 0) do p = substring p 1 (p.count-1)
			fgpath = p + "*.fgm"
			fgFiles = getFiles fgpath
		)
		return fgFiles
	),

	fn createFGPass fname =
	(
		local rend = renderers.production
		--remember old settings
		local oldFGpath =rend.FinalGatherFilename
		if oldFGpath == undefined then oldFGpath = ""
		local oldFGFreeze = rend.FinalGatherFreeze
		local oldFGUseFile = rend.UseFinalGatherFile
		local oldMinSamples = rend.MinimumSamples
		local oldMaxSamples = rend.MaximumSamples
		local oldRedSpatialContrast  = rend.RedSpatialContrast
		local oldGreenSpatialContrast = rend.GreenSpatialContrast
		local oldBlueSpatialContrast = rend.BlueSpatialContrast
		local oldAlphaSpatialContrast  = rend.AlphaSpatialContrast
		local oldSkipFinal = false
		if (maxversion())[1] > 11000 then
			oldSkipFinal = rend.SkipFinalRender

		--change values for pass1
		local fgpath = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".fgm")
		rend.FinalGatherFilename = fgpath
		if (maxversion())[1] <= 11000 then
		(
			rend.MinimumSamples = -3
			rend.MaximumSamples = -3
			rend.RedSpatialContrast = rend.GreenSpatialContrast = rend.BlueSpatialContrast = rend.AlphaSpatialContrast = 1.0
		)
		else
			rend.SkipFinalRender = true

		rend.FinalGatherFreeze = false
		rend.UseFinalGatherFile = true
		local presetCats = (renderpresets.SaveCategories 0)
		deleteItem presetCats 2
		deleteItem presetCats 3
		renderpresets.Save 0 (fname + "\\" + dlg_main.changedMaxFile + ".mr_fgpass.rps") presetCats
		--reset old settings
		rend.FinalGatherFreeze = oldFGFreeze
		rend.UseFinalGatherFile = oldFGUseFile
		rend.FinalGatherFilename = oldFGpath
		if (maxversion())[1] <= 11000 then
		(
			rend.MinimumSamples = oldMinSamples
			rend.MaximumSamples = oldMaxSamples
			rend.RedSpatialContrast = oldRedSpatialContrast
			rend.GreenSpatialContrast =  oldGreenSpatialContrast
			rend.BlueSpatialContrast = oldBlueSpatialContrast
			rend.AlphaSpatialContrast = oldAlphaSpatialContrast
		)
		else
			rend.SkipFinalRender = oldSkipFinal

		return (dlg_main.changedMaxFile + ".mr_fgpass.rps")
	),


	fn getName name:"" =
	(
		name = "Mental Ray";
	),
	fn getIdentifier =
	(
		return #(mental_ray_renderer)
	),

	fn exportMi mipath startframe endframe =
	(
		res = false
		if existsFile mipath then
			deleteFile mipath

		rend = renderers.production
		rend.Export_On_Render = true
		rend.Incremental_Echo = true
		rend.Export_Filename = mipath
		rend.Export_ASCII = false

		max quick render

		rend.Export_On_Render = false
		rend.Incremental_Echo = true
		rend.Export_Filename = ""
		rend.Export_ASCII = false


		if existsFile mipath then
			res = true
		return res
	),

	fn exec exe args =
	(
		local p = dotNetObject "System.Diagnostics.Process"
		p.StartInfo.UseShellExecute = false
		p.StartInfo.RedirectStandardOutput = true
		p.StartInfo.CreateNoWindow = true
		p.StartInfo.FileName = exe
		p.StartInfo.Arguments = args
		p.Start()
		local stoutput = p.StandardOutput.ReadToEnd()
		p.WaitForExit()
		return stoutput
	),

	fn checkMi mipath miparser =
	(
		local searchPaths = #()
		append searchPaths (trimRight maxfilepath "\\")
		append searchPaths (trimRight (getDir #maxRoot) "\\")
		local stSearchPaths = ""
		for f in searchPaths do
			stSearchPaths = stSearchPaths + " -s \"" + f + "\""

		local stoutput = exec miparser ("passX4f -i \""+mipath+"\" "+stSearchPaths+" -t check")

		local keyval = #()
		local vOut = filterstring stoutput "\n" splitEmptyTokens:false
		for i=1 to vOut.count do
		(
			try
			(
				local entry = filterString vOut[i] "|"
				local key = entry[1]
				local val = (substring entry[2] 1 (entry[2].count-1))
				append keyval #(key, val)
			)
			catch
			(
				return undefined
			)
		)
		return keyval
	),

	fn changeMi mipath miparser texPath outPath =
	(
		local changeParams = #()

		local stChange = ""
		for p in changeParams do
			stChange = stChange + " -so " + p[1] + ":" + p[2] + "=" + p[3]

		local searchPaths = #()
		append searchPaths (trimRight maxfilepath "\\")
		append searchPaths (trimRight (getDir #maxRoot) "\\")
		local stSearchPaths = ""
		for f in searchPaths do
			stSearchPaths = stSearchPaths + " -s \"" + f + "\""

		exec miparser ("passX4f -i \""+mipath+"\" "+stSearchPaths+ " -t change -ro \""+outPath+"\" -rt \""+texPath+"\"" + stChange)
	),

	originalMats = #(),
	replacedMats = #(),

	fn replaceMat oldMat newMat =
	(
		print ("Replacing " + (oldMat as string) + " with " + (newMat as string))
		replaceinstances oldMat newMat
		append originalMats oldMat
		append replacedMats newMat
	),

	fn restoreMats =
	(
		for i = 1 to originalMats.count do
		(
			print ("Resetting " + (replacedMats[i] as string) + " with " + (originalMats[i] as string))
			replaceinstances replacedMats[i] originalMats[i]
		)
	),

	fn replaceMaterials =
	(

	),

	fn preCheckStandalone =
	(
		if classof renderers.production == mental_ray_renderer then
		(
			if miExport then
			(
				dlg_main.isMiExport = true
			)
		)
	),

	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(
		rend = renderers.production
		if dlg_main.isMiExport and classof renderers.production == mental_ray_renderer then
		(
			local allvalid = true
			local miparser = pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath) "plugins"
			miparser = pathConfig.appendPath miparser "mentalray"
			miparser = pathConfig.appendPath miparser "miparser.exe"
			if existsFile miparser then
			(
				miTemp = sysInfo.tempdir + (mTimeGetTime() as string) + ".mi"

				local startframe = 1
				local endframe = 1
				if rendTimeType == 2 then
				(
					startframe = animationRange.start.frame as integer
					endframe = animationRange.end.frame as integer
				)
				if rendTimeType == 3 then
				(
					startframe = rendStart.frame as integer
					endframe = rendEnd.frame as integer
				)

				originalMats = #()
				replacedMats = #()
				replaceMaterials()
				if exportMi miTemp startframe endframe then
				(
					miCheckResult = #()
					local keyval = checkMi miTemp miparser
					if keyval != undefined then
					(
						for i=1 to keyval.count do
						(
							if keyval[i][1] == "err" then
							(
								append resultList (tr id:12103 index:index validator:val severity:2 message:("Mi: " + keyval[i][2]))
								allvalid = false
							)
							else
								append miCheckResult keyval[i]
						)
					)
					else
					(
						append resultList (tr id:12103 index:index validator:val severity:2 message:("Unknown error checking mi"))
						allvalid = false
					)
				)
				else
				(
					append resultList (tr id:12103 index:index validator:val severity:2 message:("Scene could not be exported to .mi"))
					allvalid = false
				)
				restoreMats()

			)
			else
			(
				append resultList (tr id:12103 index:index validator:val severity:2 message:("Please install the mentalray plugin in the Render Farm Application settings"))
				allvalid = false
			)

			if allvalid then
			(
				changeMi miTemp miparser (createTexPath dlg_main.m_userName "") (createOutputPath dlg_main.m_userName "")

				local dest = fPath + "\\tex\\" + dlg_main.changedMaxFile + ".0001.mi"
				deleteFile dest
				renameFile miTemp dest
				appendFileInfo &vecFiles dest  ("tex/" + (filenameFromPath dest)) tcopy:false
				for i=1 to miCheckResult.count do
				(
					if miCheckResult[i][1] == "texfound" or miCheckResult[i][1] == "linkfound" or miCheckResult[i][1] == "includefound" then
						appendFileInfo &vecFiles miCheckResult[i][2]  ("tex/" + filenameFromPath miCheckResult[i][2])
				)
				settingsToWrite += "singleMiFile=1\n"
				return true
			)
		)
		return false
	),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == mental_ray_renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
/*				if miExport then
				(
					dlg_main.isMiExport = true
					append resultList (tr id:6001 index:index validator:val severity:0 message:("Rendering with mental ray Standalone, do you want to render in 3ds Max?") flagMoreInfos:true type:MI_STANDALONE)
					if isSingleFrameRender() then
						append resultList (tr id:6001 index:index validator:val severity:2 message:("Distributed rendering with mental ray Standalone is not yet supported!"))
				)
				else
					append resultList (tr id:6001 index:index validator:val severity:0 message:("Rendering with 3ds Max, do you want to render in mental ray Standalone?") flagMoreInfos:true type:MI_STANDALONE)
*/

				if rend.MinimumSamples <= -2 then -- equals 1/16 samples
					append resultList (tr id:6001 index:index validator:val severity:1 message:"Samples per Pixel: Minimum Samples seems very low.")

				if rend.MinimumSamples >=1 then -- equals 4 samples
					append resultList (tr id:6002 index:index validator:val severity:1 message:"Samples per Pixel: Minimum Samples seems very high.")

				if rend.MaximumSamples <= 0 then -- equals 1 samples
					append resultList (tr id:6003 index:index validator:val severity:1 message:"Samples per Pixel: Maximum Samples seems very low.")

				if rend.MaximumSamples >=2 then -- equals 16 samples
					append resultList (tr id:6004 index:index validator:val severity:1 message:"Samples per Pixel: Maximum Samples seems very high.")

				if rend.TaskSize < 32 then
					append resultList (tr id:6005 index:index validator:val severity:1 message:"Bucket size seems to be small, can increase rendertime depending on scene content.")

				if rend.TaskSize > 127 then
					append resultList (tr id:6006 index:index validator:val severity:1 message:"Bucket size seems to be high, can increase rendertime depending on scene content.")

				if NOT rend.RaytraceEnable then
					append resultList (tr id:6008 index:index validator:val severity:1 message:"Rendering: Ray Tracing is deactivated" flagMoreInfos:true type:ENABLE_RAYTRACING)

				if NOT rend.ShadowsEnable then
					append resultList (tr id:6009 index:index validator:val severity:1 message:"Rendering: Shadows are deactivated" flagMoreInfos:true type:ENABLE_SHADOWS)

				if rend.ShadowsEnable AND rend.UseShadowMapFile AND rend.ShadowMapFilename != "" then
				(
					mappath = pathConfig.convertPathToAbsolute rend.ShadowMapFilename
					mappathFile = getFilenameFile mappath
					extension = getFilenameType mappath
					if extension != "" then
					(
						path1 = pathConfig.appendPath (getFilenamePath mappath) (mappathFile+"*")
						f = getFiles path1
						print path1
						if f.count == 0 then
							append resultList (tr id:6011 index:index validator:val severity:2 message:("Rendering: Shadow Map not found: " + rend.ShadowMapFilename))
					)
				)

				if rend.Enable_Material_Override then
					append resultList (tr id:6012 index:index validator:val severity:1 message:"Processing: Material Override is activated")

				if rend.Skip_Texture_Maps then
					append resultList (tr id:6013 index:index validator:val severity:1 message:"Processing: Skip Maps and Textures is activated")

				if rend.DiagnosticsEnabled then
					append resultList (tr id:6014 index:index validator:val severity:1 message:"Processing: Diagnostics is activated")

				if not isSingleFrameRender() then
				(
					if (maxversion())[1] <= 10000 then	-- 9, 2008
					(
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==false AND rend.FinalGatherFreeze==false) then
							append resultList (tr id:6017 index:index validator:val severity:1 message:"Indirect Illumination: FG single frame mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==false AND rend.FinalGatherFreeze==true) then
							append resultList (tr id:6018 index:index validator:val severity:1 message:"Indirect Illumination: FG render mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==false) then
							append resultList (tr id:6019 index:index validator:val severity:2 message:"Indirect Illumination: FG pre-render mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==true) then
							append resultList (tr id:6020 index:index validator:val severity:1 message:"Indirect Illumination: FG render mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.PhotonMapUseFile==false) then
							append resultList (tr id:6021 index:index validator:val severity:1 message:"Indirect Illumination: GI/Caustics single frame mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.PhotonMapUseFile==true) then
							append resultList (tr id:6022 index:index validator:val severity:1 message:"Indirect Illumination: GI/Caustics render mode active" flagMoreInfos:true type:ONLINE_FAQ)

						if rend.FinalGatherEnable2 AND (rend.UseFinalGatherFile OR rend.FinalGatherFreeze) AND NOT existsFile (mapPaths.getFullFilePath rend.FinalGatherFilename) then
							append resultList (tr id:6023 index:index validator:val severity:2 message:"Indirect Illumination: FG map not found")
					)
					else if (maxversion())[1] <= 11000 then -- 2009
					(
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==false AND rend.FinalGatherFreeze==false) then
							append resultList (tr id:6024 index:index validator:val severity:1 message:"Indirect Illumination: FG single frame mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==false AND rend.FinalGatherFreeze==true) then
							append resultList (tr id:6025 index:index validator:val severity:1 message:"Indirect Illumination: FG render mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==false) then
							append resultList (tr id:6026 index:index validator:val severity:2 message:"Indirect Illumination: FG pre-render mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if (rend.FinalGatherEnable2==true AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==true) then
							append resultList (tr id:6027 index:index validator:val severity:1 message:"Indirect Illumination: FG render mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.PhotonMapUseFile==false) then
							append resultList (tr id:6028 index:index validator:val severity:1 message:"Indirect Illumination: GI/Caustics single frame mode active" flagMoreInfos:true type:ONLINE_FAQ)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.PhotonMapUseFile==true) then
							append resultList (tr id:6029 index:index validator:val severity:1 message:"Indirect Illumination: GI/Caustics render mode active" flagMoreInfos:true type:ONLINE_FAQ)

						if rend.FinalGatherEnable2 AND (rend.UseFinalGatherFile OR rend.FinalGatherFreeze) AND NOT existsFile (mapPaths.getFullFilePath rend.FinalGatherFilename) then
							append resultList (tr id:6030 index:index validator:val severity:2 message:"Indirect Illumination: FG map not found")
					)
					else --2010
					(
						if (rend.FinalGatherEnable2==true AND rend.IlluminationCacheMode==0 AND rend.UseFinalGatherFile==false) then
							append resultList (tr id:6031 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - \"single File only\" with \"FG Map - Off...\" selected" flagMoreInfos:true type:GI_13)
						if (rend.FinalGatherEnable2==true AND rend.IlluminationCacheMode==0 AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==false) then
							append resultList (tr id:6032 index:index validator:val severity:2 message:"Indirect Illumination: Reuse FG Mode - \"single File only\" with \"FG Map - incremantally Add...\" selected" flagMoreInfos:true type:GI_14)
						if (rend.FinalGatherEnable2==true AND rend.IlluminationCacheMode==0 AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==true) then
							append resultList (tr id:6033 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - \"single File only\" with \"FG Map - Read FG Points...\" selected" flagMoreInfos:true type:GI_15)
						if (rend.FinalGatherEnable2==true AND rend.IlluminationCacheMode==1 AND rend.UseFinalGatherFile==false) then
							append resultList (tr id:6034 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - \"One File per Frame\" with \"FG Map - Off\" selected" flagMoreInfos:true type:GI_16)
						if (rend.FinalGatherEnable2==true AND rend.IlluminationCacheMode==1 AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==false) then
							append resultList (tr id:6035 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - \"One File per Frame\" with \"FG Map - incremantal\" selected" flagMoreInfos:true type:GI_17)
						if (rend.FinalGatherEnable2==true AND rend.IlluminationCacheMode==1 AND rend.UseFinalGatherFile==true AND rend.FinalGatherFreeze==true) then
							append resultList (tr id:6036 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - \"One File per Frame\" with \"FG Map - Read\" selected" flagMoreInfos:true type:GI_18)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.IlluminationCacheMode==0 AND rend.PhotonMapUseFile==false) then
							append resultList (tr id:6037 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - GI/Caustics - \"single File only\" with \"Caustics Map - Photon Map Off\" selected" flagMoreInfos:true type:GI_19)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.IlluminationCacheMode==0 AND rend.PhotonMapUseFile==true AND rend.PhotonFreeze==false) then
							append resultList (tr id:6038 index:index validator:val severity:2 message:"Indirect Illumination: Reuse FG Mode - GI/Caustics - \"single File only\" with \"Caustics Map - read/write\" selected" flagMoreInfos:true type:GI_20)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.IlluminationCacheMode==0 AND rend.PhotonMapUseFile==true AND rend.PhotonFreeze==true) then
							append resultList (tr id:6039 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - GI/Caustics - \"single File only\" with \"Caustics Map - Read only\" selected" flagMoreInfos:true type:GI_21)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.IlluminationCacheMode==1 AND rend.PhotonMapUseFile==false) then
							append resultList (tr id:6040 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - GI/Caustics - \"One File per Frame\" with \"Caustics Map - Photon Map Off\" selected" flagMoreInfos:true type:GI_22)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.IlluminationCacheMode==1 AND rend.PhotonMapUseFile==true AND rend.PhotonFreeze==false) then
							append resultList (tr id:6041 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - FG GI/Caustics - \"One File per Frame\" with \"Caustics Map - Read/Write\" selected" flagMoreInfos:true type:GI_23)
						if ((rend.GlobalIllumEnable==true OR rend.CausticsEnable==true) AND rend.IlluminationCacheMode==1 AND rend.PhotonMapUseFile==true AND rend.PhotonFreeze==true) then
							append resultList (tr id:6042 index:index validator:val severity:1 message:"Indirect Illumination: Reuse FG Mode - GI/Caustics - \"One File per Frame\" with \"Caustics Map - Read only\" selected" flagMoreInfos:true type:GI_24)

						if rend.FinalGatherEnable2 AND rend.IlluminationCacheMode == 0 AND rend.UseFinalGatherFile == true and rend.FinalGatherFreeze == true then --read fg points from existing map files
						(
							if rend.FinalGatherFilename == undefined or NOT existsFile (mapPaths.getFullFilePath rend.FinalGatherFilename) then
								append resultList (tr id:6044 index:index validator:val severity:2 message:"Indirect Illumination: FG map not found")
						)

						if rend.FinalGatherEnable2 AND rend.IlluminationCacheMode == 1 AND rend.UseFinalGatherFile == true and rend.FinalGatherFreeze == true then --read fg points from existing map files
						(
							local fgfiles = findFGFiles rend
							local frames = (rendEnd.frame - rendStart.frame+1) as integer
							if rendTimeType == 2 then
								frames = (animationRange.end.frame - animationRange.start.frame+1) as integer
							if fgfiles.count == 0 then
								append resultList (tr id:6045 index:index validator:val severity:2 message:"Indirect Illumination: no FG maps not found")
							else if fgfiles.count != frames then
								append resultList (tr id:6045 index:index validator:val severity:2 message:("Indirect Illumination: You want to render " + (frames as string) + " frames but have " + (fgfiles.count as string) + " FG map files"))
						)
					)

					if (rend.GlobalIllumEnable OR rend.CausticsEnable) AND rend.PhotonMapUseFile AND NOT existsFile (mapPaths.getFullFilePath rend.PhotonMapFilename) then
						append resultList (tr id:6046 index:index validator:val severity:2 message:"Indirect Illumination: Photon Map not found")

					if (maxversion())[1] >= 12000 then
					(
						if rend.softshadowsprecision <= 0.25 then
							append resultList (tr id:6047 index:index validator:val severity:1 message:"Renderer: Soft Shadows Precision seems very low")
						if rend.softshadowsprecision >=4 then
							append resultList (tr id:6048 index:index validator:val severity:1 message:"Renderer: Soft Shadows Precision seems very high")
						if rend.glossyreflectionsprecision <=0.5 then
							append resultList (tr id:6049 index:index validator:val severity:1 message:"Renderer: Glossy Reflection Precision seems very low")
						if rend.glossyreflectionsprecision > 2 then
							append resultList (tr id:6050 index:index validator:val severity:1 message:"Renderer: Glossy Reflection Precision seems very high")
						if rend.glossyrefractionsprecision <=0.5 then
							append resultList (tr id:6051 index:index validator:val severity:1 message:"Renderer: Glossy Refraction Precision seems very low")
						if rend.glossyrefractionsprecision > 2 then
							append resultList (tr id:6052 index:index validator:val severity:1 message:"Renderer: Glossy Refraction Precision seems very high")
						if rend.MaximumReflections <=2 then
							append resultList (tr id:6053 index:index validator:val severity:1 message:"Renderer: Max Reflections seems very low")
						if rend.MaximumReflections >= 9 then
							append resultList (tr id:6054 index:index validator:val severity:1 message:"Renderer: Max Reflections seems very high")
						if rend.MaximumRefractions <=2 then
							append resultList (tr id:6055 index:index validator:val severity:1 message:"Renderer: Max Refractions seems very low")
						if rend.MaximumRefractions >= 9 then
							append resultList (tr id:6056 index:index validator:val severity:1 message:"Renderer: Max Refractions seems very high")
					)
				)
				else
				(
					if rend.Enable_Camera_Lens_Shader and rend.Camera_Lens_Shader != undefined then
						append resultList (tr id:6065 index:index validator:val severity:2 message:"Renderer: Camera Shaders are not supported for distributed render")
					if rend.Enable_Camera_Output_Shader and rend.Camera_Output_Shader != undefined then
						append resultList (tr id:6066 index:index validator:val severity:2 message:"Renderer: Camera Shaders are not supported for distributed render")
					if rend.Enable_Camera_Volume_Shader and rend.Camera_Volume_Shader != undefined then
						append resultList (tr id:6067 index:index validator:val severity:2 message:"Renderer: Camera Shaders are not supported for distributed render")

					local filenames = #()
					if rendSaveFile then
						append filenames rendOutputFilename
					local renderElementsMgr = maxOps.GetRenderElementMgr #Production
					for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
					(
						local el = renderElementsMgr.GetRenderElement n
						if el.enabled == undefined OR el.enabled == false then
							continue
						if (renderElementsMgr.GetRenderElementFilename n) !="" then
							append filenames (renderElementsMgr.GetRenderElementFilename n)
					)

					for i = 2 to filenames.count do
					(
						if getfilenametype filenames[i] != getfilenametype filenames[i-1] then
						(
							append resultList (tr id:6068 index:index validator:val severity:2 message:("Render elements and render output must have the same format!"))
							exit
						)
					)
				)

				if onlyOneFrame() then
				(
					if (maxversion())[1] < 12000 then -- max9-2009
					(
						if (rend.GlobalIllumEnable OR rend.CausticsEnable) AND NOT existsFile (mapPaths.getFullFilePath rend.PhotonMapFilename) then
							append resultList (tr id:6058 index:index validator:val severity:2 message:"Indirect Illumination: Photon Map not found" flagMoreInfos:true type:ONLINE_FAQ)

						if rend.FinalGatherEnable2 AND rend.FinalGatherFreeze AND NOT existsFile (mapPaths.getFullFilePath rend.FinalGatherFilename) then
							append resultList (tr id:6059 index:index validator:val severity:2 message:"Indirect Illumination: FG map not found")
					)
					else	--max 2010
					(
						if rend.FinalGatherEnable2 AND rend.IlluminationCacheMode == 0 AND rend.UseFinalGatherFile == true and rend.FinalGatherFreeze == true then --read fg points from existing map files
						(
							if rend.FinalGatherFilename == undefined or NOT existsFile (mapPaths.getFullFilePath rend.FinalGatherFilename) then
								append resultList (tr id:6062 index:index validator:val severity:2 message:"Indirect Illumination: FG map not found")
						)

						if rend.FinalGatherEnable2 AND rend.IlluminationCacheMode == 1 AND rend.UseFinalGatherFile == true and rend.FinalGatherFreeze == true then --read fg points from existing map files
						(
							local fgfiles = findFGFiles rend
							if fgfiles.count == 0 then
								append resultList (tr id:6063 index:index validator:val severity:2 message:"Indirect Illumination: FG map not found")
						)
					)
				)
--MRMtl
			local eOrw = 1
			if isSingleFrameRender() then
				eOrw = 2
			mtls = getClassInstancesSave Arch___Design__mi
			for m in mtls do
			(
				if m.refr_interp == true OR m.refl_interp then
				(
					append resultList (tr id:6064 index:index validator:val severity:eOrw message:("Mental material \""+m.name+"\" uses interpolation") flagMoreInfos:true type:INTERPOLATION_MAT)
				)

			)

			--remember paths for prepareSave because val_texture sets paths to X:\\ before val_mental is called
			oldFGFilename = rend.FinalGatherFilename
			oldPhFilename = rend.PhotonMapFilename
			oldShadowMapsFilename = rend.ShadowMapFilename
		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		-- local result = false
		local resolved = false
		st = "Message from ValMental!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			MI_STANDALONE:
			(
				if queryBox "Do you want to render with mental ray Standalone?" beep:false then
					miExport = true
				else
					miExport = false
				dlg_main.btnStart.pressed()
				return 0
			)
			ENABLE_SHADOWS:
			(
				if queryBox "Shadows are disabled. Do you want me to enable it?" beep:false then
				(
					renderers.production.ShadowsEnable = true
					renderSceneDialog.update()
					return 0
				)
			)
			ENABLE_RAYTRACING:
			(
				if queryBox "Raytracing are disabled. Do you want me to enable it?" beep:false then
				(
					renderers.production.RaytraceEnable = true
					renderSceneDialog.update()
					return 0
				)
			)
			GI_1:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute Final Gather each frame !
That causes different Final Gather solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Final Gather settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static enable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_2:
			(
				st="This mode read the FG from file only and not generate FG on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-set Anti Aliasing to lowest level to speed up render
-hit render
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read only (FG Freeze)\" active if you \"Upload\"


If bake need to long, increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_3:
			(
				st="This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-set Anti Alising to lowest level to speed up render
-hit render
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read only (FG Freeze)\" active if you \"Upload\"


If bake need to long, increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_4:
			(
				st="This mode read the FG from file only and not generate FG on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-set Anti Alising to lowest level to speed up render
-hit render
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read only (FG Freeze)\" active if you \"Upload\"


If bake need to long, increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_5:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute the Photon map each frame !
That causes different Photon solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Photon map settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static enable Photon map: \"read/write file (...)\" and run Smart Check again
";
			)
			GI_6:
			(
				st="This mode read the GI from file only and not generate GI on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part
Note: that mode read Photons from file only and NOT generate on render

to use that mode you need to bake the Photon map to file first
-set frame range to 0-0
-assign save path for Photon map  (...)
-hit render
-wait until map is calculated

if completed reset render settings
!make sure you have \"read/write file\" active if you \"Upload\"

If your scene is NOT Static disable Photon map: \"read/write file\" and run Smart Check again
";
			)
			GI_7:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute Final Gather each frame !
That causes different Final Gather solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Final Gather settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static enable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_8:
			(
				st="This mode read the FG from file only and not generate FG on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-hit \"Generate Final Gather Map file Now\"
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read only (FG Freez)\" active if you \"Upload\"


If bake need to long, increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_9:
			(
				st="This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-hit \"Generate Final Gather Map file Now\"
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read only (FG Freez)\" active if you \"Upload\"


If bake need to long, increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_10:
			(
				st="This mode read the GI from file only and not generate GI on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-hit \"Generate Final Gather Map file Now\"
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read only (FG Freez)\" active if you \"Upload\"


If bake need to long, increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"read write file\" and run Smart Check again
";
			)
			GI_11:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute the Photon map each frame !
That causes different Photon solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Photon map settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static enable Photon map: \"read/write file (...)\" and run Smart Check again
";
			)
			GI_12:
			(
				st="This mode read the GI from file only and not generate GI on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part
Note: that mode read Photons from file only and NOT generate on render

to use that mode you need to bake the Photon map to file first
-set frame range to 0-0
-assign save path for Photon map  (...)
-hit \"Generate Photon Map file Now\"
-wait until map is calculated

if completed reset render settings
!make sure you have \"read/write file\" active if you \"Upload\"

If your scene is NOT Static disable Photon map: \"read/write file\" and run Smart Check again
";
			)
			GI_13:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute the Final Gather map each frame !
That causes different FG solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the FG settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static set FG map: \"incremantal\" and run Smart Check again
";
			)
			GI_14:
			(
				st="This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-hit \"Generate Final Gather Map file Now\"
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read FG points\" active if you \"Upload\"

If bake need to long increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"Off\" or \"one file per frame\"
";
			)
			GI_15:
			(
				st="This mode read the FG from file only and not generate FG on render!
This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 10 or higher depending on Camera speed
-assign save path for Final Gather (...)
-hit \"Generate Final Gather Map file Now\"
-wait until all frames are calculated

if completed reset render settings
!make sure you have \"read FG points\" active if you \"Upload\"

If bake need to long increase the Frame steps and/or reduce the FG settings
If your scene is NOT Static disable Final Gather map: \"Off\" or \"one file per frame\"
";
			)
			GI_16:
			(
				st="! Attention !
That mode will recompute the Final Gather map each frame !
That causes different FG solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the FG settings but that rise the rendertime without
guarantee of flicker free output.

This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects and animated Textures

If your scene is Static set Final Gather map: \"Single file only\" and run Smart Check again\"
";
			)
			GI_17:
			(
				st="This mode render the Final Gather solution to file first
afterwards it interpolate the FG solution and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Final Gather settings but that rise the rendertime without
guarantee of flicker free output.

This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects and animated Textures

If your scene is Static set Final Gather map: \"Single file only\" and run Smart Check again
";
			)
			GI_18:
			(
				st="This mode reads the Final Gather solution from file only and NOT generate Final Gather during render
This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects and animated Textures

to use that mode you need to bake the Final Gather map to file first
-set frame range you need
-set frame step to 1!
-assign save path for Final Gather (...)
-hit \"Generate Final Gather Map file Now\"
-wait until all frames are calculated

!make sure you have \"read FG points\" active if you \"Upload\"


If your scene is Static set Final Gather map: \"Single file only\" and run Smart Check again
";
			)
			GI_19:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute the Photon map each frame !
That causes different Photon solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the GI settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static set Photon map: \"read write file\" and run Smart Check again
";
			)
			GI_20:
			(
				st="This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part

to use that mode you need to bake the Photon map to file first
-set frame range to 0-0
-assign save path for Photons (...)
-hit \"Generate Photon Map file Now\"
-wait until map is calculated

if completed reset render setting
!make sure you have \"read Photons only\" active if you \"Upload\"

If your scene is NOT Static set Photon map: \"One file per frame\" and run Smart Check again
";
			)
			GI_21:
			(
				st="This mode is used for Static scenes only !
A static scene include No animated Lights, NO animated Objects and NO animated Textures
! the Camera is the only moving part
Note: that mode will read Photons from file only and NOT generate on render

to use that mode you need to bake the Photon map to file first
-set frame range to 0-0
-assign save path for Photons (...)
-hit \"Generate Photon Map file Now\"
-wait until map is calculated

if completed reset render setting
!make sure you have \"read Photons only\" active if you \"Upload\"

If your scene is NOT Static set Photon map: \"One file per frame\" and run Smart Check again
";
			)
			GI_22:
			(
				st="This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects or animated Textures

! Attention !
That mode will recompute the Photon map each frame !
That causes different Photon solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the GI settings but that rise the rendertime without
guarantee of flicker free output.

If your scene is Static set Photon map: \"Single file only\" and run Smart Check again
";
			)
			GI_23:
			(
				st="This mode render the Photon solution to file first and interpolate it afterwards
That causes different Photon solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Photon settings but that rise the rendertime without
guarantee of flicker free output.

This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects and animated Textures

If your scene is Static set Photon map: \"Single file only\" and run Smart Check again
";
			)
			GI_24:
			(
				st="This mode read the Photon solution from only and NOT generate Photons on render
Photons are read from file and interpolated for render
That causes different Photon solutions and MAYBE produce a flicker in final output.
To reduce flicker you could increase the Photon settings but that rise the rendertime without
guarantee of flicker free output.

This mode is used for Non Static scenes only !
A non static scene include animated Lights, animated Objects and animated Textures

to use that mode you need to bake the Photon map to file first
-set frame range you need
-assign save path for Photons (...)
-hit \"Generate Photon Map file Now\"
-wait until maps are calculated

if completed reset render setting
!make sure you have \"read Photons only\" active if you \"Upload\"

If your scene is Static set Photon map: \"Single file only\" and run Smart Check again
";
			)
			SINGLE_PHOTON_PRERENDER:
			(
				st="Due to technical limitations you need to pre-render the Photon map first.
Set Photon mode \"read/write\", define Save Path(...) and render map to file";
			)
			SINGLE_PHOTON_PRERENDER2:
			(
				st="Due to technical limitations you need to pre-render the Photon map first.
Set Photon mode \"read/write\", define Save Path(...) and hit \"Generate Photon map now\"
if completed set \"read Photons only from file\"";
			)
		)
		if result.type == INTERPOLATION_MAT then
		(
			text = "It is not recommended to enable interpolation for animation renderings. Interpolation forces Mental Ray to pre-render the reflection/refraction map.
That can produce a flicker in the final output. Do you want to disable Interpolation for all materials?"
			if isSingleFrameRender() then
				text = "It is not recommended to enable interpolation for still image renderings. Interpolation can cause improper resultson the render bucket.
Do you want to disable Interpolation for all materials?"
			if queryBox text beep:false then
			(
				mtls = getClassInstancesSave Arch___Design__mi
				for m in mtls do
				(
					m.refr_interp = false
					m.refl_interp = false
				)
			)
		)
		else
			messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == mental_ray_renderer then
		(
			local copyFGMap = true
			if rend.DistributedEnable then
				rend.DistributedEnable = false
			if (maxversion())[1] >= 12000 then
			(
				if rend.Export_On_Render == true then
					rend.Export_On_Render = false
			)
			if rend.FinalGatherEnable2 AND hasProperty rend "SkipFinalRender" then
				rend.SkipFinalRender = false

			if (isSingleFrameRender() AND rend.UseFinalGatherFile AND NOT rend.FinalGatherFreeze) then
				copyFGMap = false
			if rend.FinalGatherEnable2 AND (rend.UseFinalGatherFile OR rend.FinalGatherFreeze) AND copyFGMap then
			(
				try
				(
					if (maxversion())[1] >=12000 then
					(
						local fgFiles = findFGFiles rend
						for f in fgFiles do
						(
							if existsfile f then
							(
								appendFileInfo &vecFiles f ("tex/" + filenameFromPath f)
							)
							else
								print ("fgFile not found: " + f as string)
						)

						if fgFiles.count == 0 then
						(
							fgpath = oldFGFilename
							if not existsfile fgpath then
								fgpath = mapPaths.getFullFilePath oldFGFilename
							if existsfile fgpath then
							(
								appendFileInfo &vecFiles fgpath ("tex/" + filenameFromPath fgpath)

								rend.FinalGatherFilename = createTexPath dlg_main.m_userName (filenameFromPath fgpath)
							)
							else
								format "mental.ms: *** Error: FGFile2 not found ***\n"
						)
						rend.FinalGatherFilename = createTexPath dlg_main.m_userName (filenameFromPath oldFGFilename)
					)
					else
					(
						fgpath = oldFGFilename
						if not existsfile fgpath then
							fgpath = mapPaths.getFullFilePath oldFGFilename
						if existsfile fgpath then
						(
							appendFileInfo &vecFiles fgpath ("tex/" + filenameFromPath fgpath)

							rend.FinalGatherFilename = createTexPath dlg_main.m_userName (filenameFromPath fgpath)
						)
						else
							format "mental.ms: *** Error: FGFile not found ***\n"
					)

				)
				catch
				(
					format "mental.ms: *** % ***\n" (getCurrentException())
				)
			)
			if (rend.GlobalIllumEnable OR rend.CausticsEnable) AND (rend.PhotonMapUseFile OR isSingleFrameRender()) AND rend.PhotonMapUseFile != "" then
			(
				try
				(
					phpath = oldPhFilename
					if not existsfile phpath then
						phpath = mapPaths.getFullFilePath oldPhFilename
					if existsfile phpath then
					(
						appendFileInfo &vecFiles phpath ("tex/" + filenameFromPath phpath)

						rend.PhotonMapFilename = createTexPath dlg_main.m_userName (filenameFromPath phpath)
					)
					else
						format "mental.ms: *** Error: PhotonFile not found ***"
				)
				catch
				(
					format "mental.ms: *** % ***\n" (getCurrentException())
				)
			)
			if rend.ShadowsEnable AND rend.UseShadowMapFile then
			(
				mappath = pathConfig.convertPathToAbsolute oldShadowMapsFilename
				mappathFile = getFilenameFile mappath
				extension = getFilenameType mappath
				if extension != "" then
				(
					path1 = pathConfig.appendPath (getFilenamePath mappath) (mappathFile+"*")
					files = getFiles path1
					for file in files do
					(
						appendFileInfo &vecFiles file ("tex" + filenameFromPath file)
					)
					rend.ShadowMapFilename = createTexPath dlg_main.m_userName (filenameFromPath mappath)
				)
			)


			--2 pass rendering if one file per frame and incremental FG mode:
			if (maxversion())[1] >=12000 then
			(
				if rend.FinalGatherEnable2 and rend.IlluminationCacheMode == 1 and rend.UseFinalGatherFile == true and rend.FinalGatherFreeze == false and not isSingleFrameRender() then
				(
					oneFileIncremental = true
					oldFGInterpolateNFrames = rend.FGInterpolateNFrames
					oldSkipFinalRender = rend.SkipFinalRender
					--pass1
					rend.FinalGatherFilename = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".fgm")
					rend.SkipFinalRender = true
					local mrendOutputFilename = "c:\\logs\\" +  (filenameFromPath rendOutputFilename)
					local oldOutfile = rendOutputFilename
					rendOutputFilename = mrendOutputFilename

					--save rps
					local mentalAnim_prePresetPath = dlg_main.changedMaxFile + ".mental_pre_pass1.rps"
					local presetCats = (renderpresets.SaveCategories 0)
					deleteItem presetCats 2
					deleteItem presetCats 3
					renderpresets.Save 0 (fPath + "\\" + mentalAnim_prePresetPath) presetCats
					appendFileInfo &vecFiles (fPath + "\\" + mentalAnim_prePresetPath) (mentalAnim_prePresetPath) tcopy:false
					settingsToWrite += "mentalprepass=1\n"
					--pass2
					rendOutputFilename = oldOutfile
					rend.SkipFinalRender = false
					rend.UseFinalGatherFile = true
					rend.FinalGatherFreeze = true
					rend.FGInterpolateNFrames = 3
				)
				else
					oneFileIncremental = false
			)

			oldUse_Placeholders = rend.Use_Placeholders
		--	rend.Use_Placeholders = false

			--distributed single frame rendering
			if isSingleFrameRender() then
			(
				saveExt = getFilenameType rendOutputFilename
				if (stricmp saveExt ".jpg") ==0 then
					jpeg.ijpegio.setQuality(100)

				GIenabled = "0"
--				if (rend.GlobalIllumEnable OR rend.CausticsEnable) then
--					GIenabled = "1"
				FGenabled = "0"
				if rend.FinalGatherEnable2 then
					FGenabled = "1"
				FGFreeze = "0"
				if rend.UseFinalGatherFile and rend.FinalGatherFreeze then
					FGFreeze = "1"
				settingsToWrite += "singleframeMaxMentalNew2=1\n"
				settingsToWrite += "fgenabled=" + FGenabled +"\n"
				settingsToWrite += "gienabled=" + GIenabled +"\n"
				settingsToWrite += "fgfreeze=" + FGFreeze +"\n"

				oldFGUseFile = rend.UseFinalGatherFile
				oldFGFreeze = rend.FinalGatherFreeze
				if rend.FinalGatherFreeze then
					rend.UseFinalGatherFile = true

				local fgpath = createFGPass fPath
				appendFileInfo &vecFiles (fPath + "\\" + fgpath) fgpath tcopy:false

				oldRenderType = getrendertype()
				oldActiveViewport = viewport.activeViewport
				try
				(
					if rendViewIndex != undefined then
						viewport.activeViewport = rendViewIndex
				)
				catch
				(
				)
				oldRegionRect = viewport.getRegionRect oldActiveViewport
				oldGIUseFile = rend.PhotonMapUseFile
				if (maxversion())[1] >=12000 then oldGIFreeze = rend.PhotonFreeze
				--todo region

				if not (rend.UseFinalGatherFile and rend.FinalGatherFreeze) then
					rend.FinalGatherFilename = createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".fgm")

				rend.PhotonMapUseFile = true
				if (maxversion())[1] >=12000 then rend.PhotonFreeze = true
				rend.UseFinalGatherFile = true
				rend.FinalGatherFreeze = true
				setrendertype #region
				setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))
				setrendertype #crop
				setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))
			)
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == mental_ray_renderer then
		(
			rend.Use_Placeholders = oldUse_Placeholders

			if rend.FinalGatherEnable2 AND (rend.UseFinalGatherFile OR rend.FinalGatherFreeze) then
			(
				rend.FinalGatherFilename = oldFGFilename
			)
			if (rend.GlobalIllumEnable OR rend.CausticsEnable) AND rend.PhotonMapUseFile AND rend.PhotonMapUseFile != "" then
			(
				rend.PhotonMapFilename = oldPhFilename
			)
			if rend.ShadowsEnable AND rend.UseShadowMapFile then
			(
				rend.ShadowMapFilename = oldShadowMapsFilename
			)
			if oneFileIncremental then
			(
				rend.UseFinalGatherFile = true
				rend.FinalGatherFreeze = false
				rend.FGInterpolateNFrames = oldFGInterpolateNFrames
				rend.SkipFinalRender = oldSkipFinalRender
			)

			if isSingleFrameRender() then
			(
				setrendertype oldRenderType
				viewport.activeViewport = oldActiveViewport
				rend.PhotonMapUseFile = oldGIUseFile
				if (maxversion())[1] >=12000 then rend.PhotonFreeze = oldGIFreeze
				rend.UseFinalGatherFile = oldFGUseFile
				rend.FinalGatherFreeze = oldFGFreeze
			)
		)
	)
)

rollout iray_maxrp_dlg "Choose your Maximum RenderPoints settings" width:500 height:400
(
	local maxRp = -1
	local maxIterations = -1

	EditText lblCamera text:"" height:300 readOnly:true

	Spinner spRenderpoints "RenderPoints:" range:[1,10000,10] type:#integer
	Spinner spIterations "Iterations:" range:[0,100000,10] type:#integer
	Button btnOk "Ok" align:#right

	on iray_maxrp_dlg open do
	(
		spRenderpoints.range = [(calcMinMaxRP (getRpHourFactor())), 10000, 10]

		if isSingleFrameRender() then
			iray_maxrp_dlg.setJobType #single
		else
			iray_maxrp_dlg.setJobType #ani
	)

	on btnOk pressed do
	(
		iray_maxrp_dlg.maxRp = spRenderpoints.value
		iray_maxrp_dlg.maxIterations = spIterations.value
		DestroyDialog iray_maxrp_dlg
	)

	fn setJobType type =
	(
		if type == #ani then
		(
			lblCamera.text = "Input how many RenderPoints you like to spend for render
and
input the maximal Iterations you like to have per frame
The farm render each frame until:
- the Renderpoints per frame are spend
or
- the Iterations per frame are completed.

Example:
setup 100 Renderpoints and 100 Iterations for 100 frames
you get:
- all 100 frames with 100 Iterations for LESS 100 Renderpoints
or
- all 100 frames have the BEST POSSIBLE Iterations for 100 Renderpoints"
			spIterations.range= [1,100000,25]
		)
		else
		(
			lblCamera.text = "Input how many RenderPoints you like to spend for your render
and
input the maximal Iterations you like to have
The farm renders until:
- the Renderpoints are spent
or
- the Iterations are completed.

Example:
setup 10 Renderpoints and 100 Iterations
you get:
- the highest possible Iterations for 10 Renderpoints
or
- 100 Iterations for less then 10 Renderpoints

Render stops if either Renderpoint maximum or Iteration maximum is reached."
			spIterations.range= [25,100000,25]
		)
	)
)

rollout iray_gpu_dlg "Do you want to render on GPU or on CPU" width:380 height:60
(
	local gpu = false
	local confirmed = false

	Button btnGPU "GPU" pos:[130, 20]
	Button btnCPU "CPU" pos:[210, 20]

	on iray_gpu_dlg open do
	(
	)

	on btnGPU pressed do
	(
		gpu = true
		confirmed = true
		DestroyDialog iray_gpu_dlg
	)

	on btnCPU pressed do
	(
		gpu = false
		confirmed = true
		DestroyDialog iray_gpu_dlg
	)
)


struct ValIray
(
	MAX_RP_DIALOG = 2,
	GPU_DIALOG = 3,
	LIGHT_BOUNCES = 4,

	distributedMachines = 25,
	rpHourFactorGpu_Tblack = 2.8,
	rpHourFactorGpu_TX = 4.5,

	oldDurationMode = #iterations,
	oldDurationInSeconds =1,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Mental Ray iray";
	),
	fn getIdentifier =
	(
		return #(mental_ray_iray_Renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == mental_ray_iray_Renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			append resultList (tr id:4009 index:index validator:val severity:2 message:"Iray+ is currently not supported on Render Farm Application")

			if (maxversion())[1] < 17000 then
				append resultList (tr id:4009 index:index validator:val severity:2 message:"You need at least 3ds Max 2015 to render with iray")

			if iray_gpu_dlg.confirmed == false then
				append resultList (tr id:4012 index:index validator:val severity:2 message:"Do you want to render on GPU or CPU?" flagMoreInfos:true type:GPU_DIALOG)
			else
			(
				if iray_gpu_dlg.gpu then
					append resultList (tr id:4012 index:index validator:val severity:0 message:"Your job will be rendered on GPU" flagMoreInfos:true type:GPU_DIALOG)
				else
					append resultList (tr id:4012 index:index validator:val severity:0 message:"Your job will be rendered on CPU only" flagMoreInfos:true type:GPU_DIALOG)
			)

			if iray_maxrp_dlg.maxRp == -1 or iray_maxrp_dlg.maxRp < (calcMinMaxRP (getRpHourFactor())) then
			(
				append resultList (tr id:4008 index:index validator:val severity:2 message:"Select your options" flagMoreInfos:true type:MAX_RP_DIALOG)
			)
			else
			(
				append resultList (tr id:4010 index:index validator:val severity:0 message:("Your Job is setup to use " + iray_maxrp_dlg.maxRp as string + " RenderPoints or reach " + iray_maxrp_dlg.maxIterations as string + " iterations!") flagMoreInfos:true type:MAX_RP_DIALOG)
			)

			if rend.overrideMaterialEnabled then
				append resultList (tr id:4006 index:index validator:val severity:1 message:"Material Overwrite is enabled")
			if rend.lightBouncesLimited then
			(
				if rend.lightBouncesMaximum >= 5 then
					append resultList (tr id:4007 index:index validator:val severity:1 message:"Advanced options - Maximum numbers of lightbounce seems very high" flagMoreInfos:true type:LIGHT_BOUNCES)
			)

			if isSingleFrameRender() then
			(
				append resultList (tr id:4013 index:index validator:val severity:2 message:"Distributed rendering in iray not yet supported - say No in the dialog")
				local extensions = #()
				appendIfUnique extensions (getfilenametype rendOutputFilename)
				local renderElementsMgr = maxOps.GetRenderElementMgr #Production
				for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
				(
					local el = renderElementsMgr.GetRenderElement n
					if el.enabled == undefined OR el.enabled == false then
						continue
					if (renderElementsMgr.GetRenderElementFilename n) !="" then
						appendIfUnique extensions (getfilenametype (renderElementsMgr.GetRenderElementFilename n))
				)
			)
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValIray!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			MAX_RP_DIALOG:
			(
				CreateDialog iray_maxrp_dlg modal:true
				dlg_main.btnStart.pressed()
				return 0
			)
			GPU_DIALOG:
			(
				CreateDialog iray_gpu_dlg modal:true
				dlg_main.irayGPUselected = iray_gpu_dlg.gpu
				dlg_main.btnStart.pressed()
				return 0
			)
			LIGHT_BOUNCES:
			(
				if queryBox "Light bounces higher than 5 might result in longer render times. Do you want me to set the maximum to 5?" beep:false then
				(
					renderers.production.lightBouncesMaximum = 5
					renderSceneDialog.update()
				)
				return 0
			)
		)
		messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == mental_ray_iray_Renderer then
		(
			oldDurationMode = rend.durationMode
			oldDurationInSeconds = rend.durationInSeconds

			if isSingleFrameRender() then
			(
				settingsToWrite += "singleframeMaxIrayProgressive=1\n"
				settingsToWrite += "maxrp="+iray_maxrp_dlg.maxRp as string+"\n"
				settingsToWrite += "samplinglevel="+iray_maxrp_dlg.maxIterations as string+"\n"

				rend.durationMode = #time
				rend.durationInSeconds = 180

				local m = iray_string_options
				for i = m.numOptions to 1 by -1 do
					m.removeOption i

				local rpFac = getRpHourFactor()
				local txtTimeLimit = ""
				if dlg_main.irayGPUselected then
				(
					txtTimeLimit = "local env = dotNetClass \"System.Environment\"
					local node = env.MachineName
					local rpFac = "+(rpHourFactorGpu_TX as string)+"
					if matchPattern node pattern:\"*001\" then
						rpFac = "+(rpHourFactorGpu_Tblack as string)+"
					local timelimit = (((\""+(iray_maxrp_dlg.maxRp as string)+"\" as float / (\""+(distributedMachines as string)+"\" as float)) / rpFac) * (60*60)) as integer
					"
				)
				else
				(
					local timelimit = ((iray_maxrp_dlg.maxRp as float / distributedMachines as float) / rpFac) * (60*60) as integer
					txtTimeLimit = "local timelimit = "+((timelimit as integer) as string)
				)
				print timelimit
				local iterations = ceil (iray_maxrp_dlg.maxIterations / distributedMachines as float) as integer
				--there seems no way to set string options that can be saved with scene with maxscript, so use a callback

				local filename = dlg_main.changedMaxFile + ".irayprogressive.ms"
				local filepath = (fPath + "\\" + filename)
				file = openFile filepath mode:"a"
				if file == undefined then
					file = createFile filepath
				if file != undefined then
				(
					local fileTxt = "fn at2IraySettings =
	(
		local m = iray_string_options
		"+txtTimeLimit+"
--		m.addOption \"iray threads\" 0
		m.addOption \"progressive interactive\" true
		m.addOption \"progressive max time\" timelimit
		m.addOption \"progressive max samples\" "+iterations as string+"
	)

	at2IraySettings()
	"
						format "%" fileTxt to:file

				)
				close file
				appendFileInfo &vecFiles filepath filename tcopy:false
				callbacks.addscript #preRender id:#at2irayPreRender fileName:(createPath dlg_main.m_userName (dlg_main.changedMaxFile + ".irayprogressive.ms")) persistent:true
			)
			else
			(
				settingsToWrite += "maxrp="+iray_maxrp_dlg.maxRp as string+"\n"
				settingsToWrite += "samplinglevel="+iray_maxrp_dlg.maxIterations as string+"\n"

				rend.durationMode = #time
				rend.durationInSeconds = 180

				local m = iray_string_options
				for i = m.numOptions to 1 by -1 do
					m.removeOption i

				local framecount = 1
				if rendTimeType == 2 then
					framecount = (animationRange.end.frame as integer) - (animationRange.start.frame as integer) + 1
				if rendTimeType == 3 then
					framecount = (rendEnd.frame as integer) - (rendStart.frame as integer) +1
				if rendTimeType == 1 then
					framecount = 1
				framecount = floor((framecount as float) / rendNthframe)
				if framecount < 1 then
					framecount = 1

				local rpFac = getRpHourFactor()
				local txtTimeLimit = ""
				if dlg_main.irayGPUselected then
				(
					txtTimeLimit = "local env = dotNetClass \"System.Environment\"
					local node = env.MachineName
					local rpFac = "+(rpHourFactorGpu_TX as string)+"
					if matchPattern node pattern:\"*001\" then
						rpFac = "+(rpHourFactorGpu_Tblack as string)+"
					local timelimit = (((\""+(iray_maxrp_dlg.maxRp as string)+"\" as float / (\""+(framecount as string)+"\" as float)) / rpFac) * (60*60)) as integer
					"
				)
				else
				(
					local timelimit = ((iray_maxrp_dlg.maxRp as float / framecount as float) / rpFac) * (60*60) as integer
					txtTimeLimit = "local timelimit = "+((timelimit as integer) as string)
				)

				--there seems no way to set string options that can be saved with scene with maxscript, so use a callback

				local filename = dlg_main.changedMaxFile + ".iray.ms"
				local filepath = (fPath + "\\" + filename)
				file = openFile filepath mode:"a"
				if file == undefined then
					file = createFile filepath
				if file != undefined then
				(
					local fileTxt = "fn at2IraySettings =
	(
		local m = iray_string_options
		"+txtTimeLimit+"
--		m.addOption \"iray threads\" 0
		m.addOption \"progressive interactive\" true
		m.addOption \"progressive max time\" timelimit
		m.addOption \"progressive max samples\" "+iray_maxrp_dlg.maxIterations as string+"
	)

	at2IraySettings()
	"
						format "%" fileTxt to:file

				)
				close file
				appendFileInfo &vecFiles filepath filename tcopy:false
				callbacks.addscript #preRender id:#at2irayPreRender fileName:(createPath dlg_main.m_userName (dlg_main.changedMaxFile + ".iray.ms")) persistent:true
			)
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == mental_ray_iray_Renderer then
		(
			callbacks.removeScripts #preRender id:#at2irayPreRender
			rend.durationMode = oldDurationMode
			rend.durationInSeconds = oldDurationInSeconds
		)
	)
)

rollout iray_plus_maxrp_dlg "Choose your Maximum RenderPoints settings" width:500 height:400
(
	local maxRp = -1
	local maxIterations = -1

	EditText lblCamera text:"" height:300 readOnly:true

	Spinner spRenderpoints "Renderpoints:" range:[1,10000,10] type:#integer
	Spinner spIterations "Iterations:" range:[0,100000,10] type:#integer
	Button btnOk "Ok" align:#right

	on iray_plus_maxrp_dlg open do
	(
		spRenderpoints.range = [(calcMinMaxRP (getRpHourFactor())), 10000, 10]
		if isSingleFrameRender() then
			iray_plus_maxrp_dlg.setJobType #single
		else
			iray_plus_maxrp_dlg.setJobType #ani
	)

	on btnOk pressed do
	(
		iray_plus_maxrp_dlg.maxRp = spRenderpoints.value
		iray_plus_maxrp_dlg.maxIterations = spIterations.value
		DestroyDialog iray_plus_maxrp_dlg
	)

	fn setJobType type =
	(
		if type == #ani then
		(
			lblCamera.text = "Input how many RenderPoints you like to spend for render
and
input the maximal Iterations you like to have per frame
The farm render each frame until:
- the Renderpoints per frame are spend
or
- the Iterations per frame are completed.

Example:
setup 100 Renderpoints and 100 Iterations for 100 frames
you get:
- all 100 frames with 100 Iterations for LESS 100 Renderpoints
or
- all 100 frames have the BEST POSSIBLE Iterations for 100 Renderpoints"
			spIterations.range= [1,100000,25]
		)
		else
		(
			lblCamera.text = "Input how many RenderPoints you like to spend for your render
and
input the maximal Iterations you like to have
The farm renders until:
- the Renderpoints are spent
or
- the Iterations are completed.

Example:
setup 10 Renderpoints and 100 Iterations
you get:
- the highest possible Iterations for 10 Renderpoints
or
- 100 Iterations for less then 10 Renderpoints

Render stops if either Renderpoint maximum or Iteration maximum is reached."
			spIterations.range= [25,100000,25]
		)
	)
)

rollout iray_plus_gpu_dlg "Do you want to render on GPU or on CPU" width:380 height:60
(
	local gpu = false
	local confirmed = false

	Button btnGPU "GPU" pos:[130, 20]
	Button btnCPU "CPU" pos:[210, 20]

	on iray_plus_gpu_dlg open do
	(
	)

	on btnGPU pressed do
	(
		gpu = true
		confirmed = true
		DestroyDialog iray_plus_gpu_dlg
	)

	on btnCPU pressed do
	(
		gpu = false
		confirmed = true
		DestroyDialog iray_plus_gpu_dlg
	)
)


struct ValIrayPlus
(
	MAX_RP_DIALOG = 2,
	GPU_DIALOG = 3,

	distributedMachines = 25,

	olditeration_count = 10000,
	oldmax_rendering_time =1,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Iray+";
	),
	fn getIdentifier =
	(
		return #(Iray)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == Iray then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			append resultList (tr id:16013 index:index validator:val severity:2 message:"Iray+ is currently not supported on Render Farm Application")

			if iray_plus_gpu_dlg.confirmed == false then
				append resultList (tr id:16012 index:index validator:val severity:2 message:"Do you want to render on GPU or CPU?" flagMoreInfos:true type:GPU_DIALOG)
			else
			(
				if iray_plus_gpu_dlg.gpu then
					append resultList (tr id:16012 index:index validator:val severity:0 message:"Your job will be rendered on GPU" flagMoreInfos:true type:GPU_DIALOG)
				else
					append resultList (tr id:16012 index:index validator:val severity:0 message:"Your job will be rendered on CPU only" flagMoreInfos:true type:GPU_DIALOG)
			)

			if iray_plus_maxrp_dlg.maxRp == -1 or iray_plus_maxrp_dlg.maxRp < (calcMinMaxRP (getRpHourFactor())) then
			(
				append resultList (tr id:16008 index:index validator:val severity:2 message:"Select your options" flagMoreInfos:true type:MAX_RP_DIALOG)
			)
			else
			(
				append resultList (tr id:16010 index:index validator:val severity:0 message:("Your Job is setup to use " + iray_plus_maxrp_dlg.maxRp as string + " RenderPoints or reach " + iray_plus_maxrp_dlg.maxIterations as string + " iterations!") flagMoreInfos:true type:MAX_RP_DIALOG)
			)

			if isSingleFrameRender() then
			(
				append resultList (tr id:16013 index:index validator:val severity:2 message:"Distributed rendering in Iray+ not yet supported - say No in the dialog")
				local extensions = #()
				appendIfUnique extensions (getfilenametype rendOutputFilename)
				local renderElementsMgr = maxOps.GetRenderElementMgr #Production
				for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
				(
					local el = renderElementsMgr.GetRenderElement n
					if el.enabled == undefined OR el.enabled == false then
						continue
					if (renderElementsMgr.GetRenderElementFilename n) !="" then
						appendIfUnique extensions (getfilenametype (renderElementsMgr.GetRenderElementFilename n))
				)
			)
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValIrayPlus!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			MAX_RP_DIALOG:
			(
				CreateDialog iray_plus_maxrp_dlg modal:true
				dlg_main.btnStart.pressed()
				return 0
			)
			GPU_DIALOG:
			(
				CreateDialog iray_plus_gpu_dlg modal:true
				dlg_main.irayGPUselected = iray_plus_gpu_dlg.gpu
				dlg_main.btnStart.pressed()
				return 0
			)
		)
		messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == Iray then
		(
			olditeration_count = rend.iteration_count
			oldmax_rendering_time = rend.max_rendering_time

			if isSingleFrameRender() then
			(
				settingsToWrite += "singleframeMaxIrayPlusProgressive=1\n"
				settingsToWrite += "maxrp="+iray_plus_maxrp_dlg.maxRp as string+"\n"
				settingsToWrite += "samplinglevel="+iray_plus_maxrp_dlg.maxIterations as string+"\n"

				rend.iteration_count = 10000
				rend.max_rendering_time = 3

				local rpFac = getRpHourFactor()
				if dlg_main.irayGPUselected then
					rpFac = getRpHourFactorGpu()
				local timelimit = ((iray_maxrp_dlg.maxRp as float / distributedMachines as float) / rpFac) * (60*60) as integer
				print timelimit
				local iterations = ceil (iray_maxrp_dlg.maxIterations / distributedMachines as float) as integer

				rend.iteration_count = iterations
				rend.max_rendering_time = ceil(timelimit / 60.0)


			)
			else
			(
				settingsToWrite += "maxrp="+iray_plus_maxrp_dlg.maxRp as string+"\n"
				settingsToWrite += "samplinglevel="+iray_plus_maxrp_dlg.maxIterations as string+"\n"

				local framecount = 1
				if rendTimeType == 2 then
					framecount = (animationRange.end.frame as integer) - (animationRange.start.frame as integer) + 1
				if rendTimeType == 3 then
					framecount = (rendEnd.frame as integer) - (rendStart.frame as integer) +1
				if rendTimeType == 1 then
					framecount = 1
				framecount = floor((framecount as float) / rendNthframe)
				if framecount < 1 then
					framecount = 1

				local rpFac = getRpHourFactor()
				if dlg_main.irayGPUselected then
					rpFac = getRpHourFactorGpu()
				local timelimit = ((iray_plus_maxrp_dlg.maxRp as float / framecount as float) / rpFac) * (60*60) as integer
				print timelimit

				rend.iteration_count = iray_plus_maxrp_dlg.maxIterations
				rend.max_rendering_time = ceil(timelimit / 60.0)
			)
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == Iray then
		(
			rend.iteration_count = olditeration_count
			rend.max_rendering_time = oldmax_rendering_time
		)
	)
)

struct ValRedshift
(
	GPU_DIALOG = 3,
	PM_REBUILD = 4,
	SSS_REBUILD = 5,
	IRRPC_REBUILD = 6,
	IRRC_REBUILD = 7,

	distributedMachines = 25,

	oldAbortOnLicenseFail = false,
	oldRenderViewEnable = false,

	proxyFiles = #(),

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Redshift";
	),
	fn getIdentifier =
	(
		return #(Redshift_Renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn exec exe args =
	(
		local p = dotNetObject "System.Diagnostics.Process"
		p.StartInfo.UseShellExecute = false
		p.StartInfo.RedirectStandardOutput = true
		p.StartInfo.CreateNoWindow = true
		p.StartInfo.FileName = exe
		p.StartInfo.Arguments = args
		local oldPath = p.StartInfo.EnvironmentVariables.Item["PATH"]
		p.StartInfo.EnvironmentVariables.Remove "PATH"
		p.StartInfo.EnvironmentVariables.Add "PATH" (oldPath + ";C:\\ProgramData\\Redshift\\bin");
		p.Start()
		local stoutput = p.StandardOutput.ReadToEnd()
		p.WaitForExit()
		return stoutput
	),

	fn getRedshiftParserResult rspath rsparser =
	(
		local searchPaths = #()
		append searchPaths (trimRight maxfilepath "\\")
		local stSearchPaths = ""
		for f in searchPaths do
			stSearchPaths = stSearchPaths + " -s \"" + f + "\""

		local stoutput = exec rsparser ("passX4f -i \""+rspath+"\" "+stSearchPaths+" -t check")

		local keyval = #()
		local vOut = filterstring stoutput "\n" splitEmptyTokens:false
		for i=1 to vOut.count do
		(
			try
			(
				local entry = filterString vOut[i] "|"
				local key = entry[1]
				local val = (substring entry[2] 1 (entry[2].count-1))
				append keyval #(key, val)
			)
			catch
			(
				return undefined
			)
		)
		return keyval
	),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		dlg_main.redshiftGPUselected = false
		if classof rend == Redshift_Renderer then
		(
			dlg_main.redshiftGPUselected = true

			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))

			if rend.PrimaryGIEngine == #RS_GIENGINE_PHOTON_MAPPING or rend.SecondaryGIEngine == #RS_GIENGINE_PHOTON_MAPPING or rend.PhotonCausticsEnable then
			(
				if rend.PhotonMode != #RS_PHOTON_MODE_REBUILD_DONT_SAVE then
					append resultList (tr id:17012 index:index validator:val severity:2 message:"Photon Mode not yet supported, set to \"Rebuild (don't save)\"" flagMoreInfos:true type:PM_REBUILD)
			)
			if rend.SubsurfaceScatteringMode != #RS_SUBSURFACE_SCATTERING_MODE_REBUILD_DONT_SAVE then
				append resultList (tr id:17012 index:index validator:val severity:2 message:"SSS Mode not yet supported, set to \"Rebuild (don't save)\"" flagMoreInfos:true type:SSS_REBUILD)
			if rend.IrradiancePointCloudMode != #RS_IRRADIANCE_POINT_CLOUD_MODE_REBUILD_DONT_SAVE then
				append resultList (tr id:17012 index:index validator:val severity:2 message:"Irradiance Point Cloud Mode not yet supported, set to \"Rebuild (don't save)\"" flagMoreInfos:true type:IRRPC_REBUILD)
			if rend.IrradianceCacheMode != #RS_IRRADIANCE_CACHE_MODE_REBUILD_DONT_SAVE then
				append resultList (tr id:17012 index:index validator:val severity:2 message:"Irradiance Cache Mode not yet supported, set to \"Rebuild (don't save)\"" flagMoreInfos:true type:IRRC_REBUILD)

			if isSingleFrameRender() then
			(
				append resultList (tr id:17013 index:index validator:val severity:2 message:"Distributed rendering in Redshift not yet supported - say No in the dialog")
				local extensions = #()
				appendIfUnique extensions (getfilenametype rendOutputFilename)
				local renderElementsMgr = maxOps.GetRenderElementMgr #Production
				for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
				(
					local el = renderElementsMgr.GetRenderElement n
					if el.enabled == undefined OR el.enabled == false then
						continue
					if (renderElementsMgr.GetRenderElementFilename n) !="" then
						appendIfUnique extensions (getfilenametype (renderElementsMgr.GetRenderElementFilename n))
				)

				if extensions.count > 1 then
					append resultList (tr id:17011 index:index validator:val severity:2 message:"You can not mix filetypes in Render output and Render Elements, please use \"only png\" or \"only exr\"")
			)

			proxyFiles = #()
			local proxies = getClassInstancesSave RedshiftProxy
			for pr in proxies do
			(
				local rsparser = pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath) "plugins"
				rsparser = pathConfig.appendPath rsparser "redshift"
				rsparser = pathConfig.appendPath rsparser "rsparser.exe"
				if existsFile rsparser then
				(
					local keyval = getRedshiftParserResult pr.file rsparser
					local success = false
					if keyval != undefined then
					(
						for i=1 to keyval.count do
						(
							if keyval[i][1] == "err" then
							(
								append resultList (tr id:17012 index:index validator:val severity:2 message:("Rs Proxy: " + keyval[i][2]))
							)
							else if keyval[i][1] == "texfound" then
								append proxyFiles keyval[i][2]
							else if keyval[i][1] == "success" then
								success = true
						)
						if not success then
							append resultList (tr id:17012 index:index validator:val severity:2 message:("Something went wrong while checking proxy file. Make sure Redshift is installed"))
					)
					else
					(
						append resultList (tr id:17012 index:index validator:val severity:2 message:("Unknown error checking vrscene"))
					)
				)
				else
				(
					append resultList (tr id:17012 index:index validator:val severity:2 message:("Please install the Redshift plugin in the Render Farm Application settings"))
				)
			)
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValRedshift!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
			)
			PM_REBUILD:
			(
				if queryBox "Do you want me to set Photon Mode to Rebuild (don't save)?" beep:false then
				(
					renderers.production.PhotonMode = #RS_PHOTON_MODE_REBUILD_DONT_SAVE
					renderSceneDialog.update()
					resolved = true
				)
			)
			SSS_REBUILD:
			(
				if queryBox "Do you want me to set SSS Mode to Rebuild (don't save)?" beep:false then
				(
					renderers.production.SubsurfaceScatteringMode = #RS_SUBSURFACE_SCATTERING_MODE_REBUILD_DONT_SAVE
					renderSceneDialog.update()
					resolved = true
				)
			)
			IRRPC_REBUILD:
			(
				if queryBox "Do you want me to set Irradiance Point Cloud Mode to Rebuild (don't save)?" beep:false then
				(
					renderers.production.IrradiancePointCloudMode = #RS_IRRADIANCE_POINT_CLOUD_MODE_REBUILD_DONT_SAVE
					renderSceneDialog.update()
					resolved = true
				)
			)
			IRRC_REBUILD:
			(
				if queryBox "Do you want me to set Irradiance Cache Mode to Rebuild (don't save)?" beep:false then
				(
					renderers.production.IrradianceCacheMode = #RS_IRRADIANCE_CACHE_MODE_REBUILD_DONT_SAVE
					renderSceneDialog.update()
					resolved = true
				)
			)

		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == Redshift_Renderer then
		(
			oldAbortOnLicenseFail = rend.AbortOnLicenseFail
			rend.AbortOnLicenseFail = true
			oldRenderViewEnable = rend.RenderViewEnable
			rend.RenderViewEnable = false
			for f in proxyFiles do
				appendFileInfo &vecFiles f ("tex/" + filenameFromPath f)
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == Redshift_Renderer then
		(
			rend.AbortOnLicenseFail = oldAbortOnLicenseFail
			rend.RenderViewEnable = oldRenderViewEnable
		)
	)
)

rollout cycles_gpu_dlg "Do you want to render on GPU or on CPU" width:380 height:60
(
	local gpu = false
	local confirmed = false

	Button btnGPU "GPU" pos:[130, 20]
	Button btnCPU "CPU" pos:[210, 20]

	on cycles_gpu_dlg open do
	(
	)

	on btnGPU pressed do
	(
		gpu = true
		confirmed = true
		DestroyDialog cycles_gpu_dlg
	)

	on btnCPU pressed do
	(
		gpu = false
		confirmed = true
		DestroyDialog cycles_gpu_dlg
	)
)


struct ValCycles
(
	GPU_DIALOG = 3,

	distributedMachines = 25,

	oldrenderDevice=0,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Cycles";
	),
	fn getIdentifier =
	(
		return #(cycles_renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == cycles_renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			if cyclesRender == undefined then
				append resultList (tr id:18012 index:index validator:val severity:2 message:"You need at least Cycles alpha 3.09")

			if cycles_gpu_dlg.confirmed == false then
				append resultList (tr id:18012 index:index validator:val severity:2 message:"Do you want to render on GPU or CPU?" flagMoreInfos:true type:GPU_DIALOG)
			else
			(
				if cycles_gpu_dlg.gpu then
					append resultList (tr id:18012 index:index validator:val severity:0 message:"Your job will be rendered on GPU" flagMoreInfos:true type:GPU_DIALOG)
				else
					append resultList (tr id:18012 index:index validator:val severity:0 message:"Your job will be rendered on CPU only" flagMoreInfos:true type:GPU_DIALOG)
			)

			if isSingleFrameRender() then
			(
				append resultList (tr id:18013 index:index validator:val severity:2 message:"Distributed rendering in Cycles not yet supported - say No in the dialog")
				local extensions = #()
				appendIfUnique extensions (getfilenametype rendOutputFilename)
				local renderElementsMgr = maxOps.GetRenderElementMgr #Production
				for n = 0 to (renderElementsMgr.numrenderelements()- 1) do
				(
					local el = renderElementsMgr.GetRenderElement n
					if el.enabled == undefined OR el.enabled == false then
						continue
					if (renderElementsMgr.GetRenderElementFilename n) !="" then
						appendIfUnique extensions (getfilenametype (renderElementsMgr.GetRenderElementFilename n))
				)
			)
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValCycles!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			GPU_DIALOG:
			(
				CreateDialog cycles_gpu_dlg modal:true
				dlg_main.cyclesGPUselected = cycles_gpu_dlg.gpu
				if cycles_gpu_dlg.gpu then
					result.message = "Your job will be rendered on GPU"
				else
					result.message = "Your job will be rendered on CPU only"
				resolved = true

				if FarmRenderSetting != undefined then
					FarmRenderSetting.updatePrioDropdown()
			)
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == cycles_Renderer then
		(
			oldrenderDevice = cyclesRender.renderDevice
			if cycles_gpu_dlg.gpu then
				cyclesRender.renderDevice=3
			else
				cyclesRender.renderDevice=0
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == cycles_Renderer then
		(
			cyclesRender.renderDevice = oldrenderDevice
		)
	)
)

struct ValFstorm
(
	distributedMachines = 25,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Fstorm";
	),
	fn getIdentifier =
	(
		return #(FStormRender)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		dlg_main.fstormGPUselected = false
		if classof rend == FStormRender then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			dlg_main.fstormGPUselected = true

			append resultList (tr id:19005 index:index validator:val severity:2 message:"FStorm is currently not supported")

			if isSingleFrameRender() then
				append resultList (tr id:19004 index:index validator:val severity:2 message:"FStorm still frame render not yet supported on Render Farm Application")

			if rend.gray_material_mode then
				append resultList (tr id:19000 index:index validator:val severity:1 message:"\"Grey material mode\" is enabled")
			if not rend.displacemen_on then
				append resultList (tr id:19001 index:index validator:val severity:1 message:"\"render displacement\" is disabled")
			if not rend.render_beauty_pass then
				append resultList (tr id:19002 index:index validator:val severity:1 message:"\"render beauty pass\" is disabled")

			if rend.lut_file != undefined and rend.lut_file != "" then
			(
				if not existsFile rend.lut_file then
					append resultList (tr id:19003 index:index validator:val severity:2 message:("LUT file \""+rend.lut_file+"\" not found"))
			)
		)
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValFstorm!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
		)
		messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == FStormRender then
		(
			if rend.lut_file != undefined and rend.lut_file != "" then
				appendFileInfo &vecFiles rend.lut_file ("tex/" + filenameFromPath rend.lut_file)
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == FStormRender then
		(
		)
	)
)

struct ValQuicksilver
(
	QUICKSILVER_1 = 1,
	ENABLE_SHADOWS = 2,
	ENABLE_REFLECTIONS = 3,
	ENABLE_DOF = 4,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Quicksilver";
	),
	fn getIdentifier =
	(
		return #(Quicksilver_Hardware_Renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == Quicksilver_Hardware_Renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			append resultList (tr id:8001 index:index validator:val severity:2 message:"Quicksilver rendering is currently not supported on Render Farm Application!" flagMoreInfos:true type:ONLINE_FAQ)

			if isSingleFrameRender() then
				append resultList (tr id:8002 index:index validator:val severity:2 message:"Quicksilver still frame render not yet supported on Render Farm Application")

			if rend.RenderingMode != #iterations then
				append resultList (tr id:8003 index:index validator:val severity:2 message:"Rendering Duration must be set to \"Iterations\"")
			else
			(
				if rend.RenderingIterations < 50 then
					append resultList (tr id:8004 index:index validator:val severity:1 message:"\"Iterations\" seems to be very low")
				if rend.RenderingIterations > 800 then
					append resultList (tr id:8005 index:index validator:val severity:1 message:"\"Iterations\" seems to be very high")
			)

			if rend.UseDefaultLights then
				append resultList (tr id:8006 index:index validator:val severity:2 message:"Illuminate with default lights is not supported")

			if rend.SoftShadowMultiplier <= 0.5 then
				append resultList (tr id:8007 index:index validator:val severity:1 message:"Shadow quality is very low")

			if rend.SoftShadowMultiplier >= 4.0 then
				append resultList (tr id:8008 index:index validator:val severity:1 message:"Shadow quality is very high")

			if rend.useShadows == false then
				append resultList (tr id:8009 index:index validator:val severity:1 message:"Shadows are disabled" flagMoreInfos:true type:ENABLE_SHADOWS)
			if rend.ReflectionsEnabled == false then
				append resultList (tr id:8010 index:index validator:val severity:1 message:"Reflections are disabled" flagMoreInfos:true type:ENABLE_REFLECTIONS)
			if rend.DepthOfFieldEnabled then
				append resultList (tr id:8011 index:index validator:val severity:1 message:"Depth of Field is enabled" flagMoreInfos:true type:ENABLE_DOF)
		)

	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValQuicksilver!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			QUICKSILVER_1:
			(
				st="The Render Farm Application currently does not support GPU accelerated Rendering.
There will be no CUDA speedup if you render with iray on the renderfarm so the rendering process will be much slower than on a Computer equipped with a CUDA enabled Graphics Card.";
			)
			ENABLE_SHADOWS:
			(
				if queryBox "Shadows are disabled. Do you want me to enable it?" beep:false then
				(
					renderers.production.useShadows = true
					renderSceneDialog.update()
				)
				return 0
			)
			ENABLE_REFLECTIONS:
			(
				if queryBox "Reflections are disabled. Do you want me to enable it?" beep:false then
				(
					renderers.production.ReflectionsEnabled = true
					renderSceneDialog.update()
				)
				return 0
			)
			ENABLE_DOF:
			(
				if queryBox "Depth of Field is enabled. Do you want me to disable it?" beep:false then
				(
					renderers.production.DepthOfFieldEnabled = false
					renderSceneDialog.update()
				)
				return 0
			)
		)
		messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == Quicksilver_Hardware_Renderer then
		(

		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == Quicksilver_Hardware_Renderer then
		(

		)
	)
)

struct ValVue
(
	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Vue";
	),
	fn getIdentifier =
	(
		return #(VUE_File_Renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == VUE_File_Renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			append resultList (tr id:13002 index:index validator:val severity:0 message:"Vue not supported at the moment.")
		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

struct ValMaxwell
(
	texfiles = #(),
	oldMxmFilenames = #(),
	oldMxsFilenames = #(),
	oldMxsOutput = "",
	oldMxiOutput = "",
	oldMxsEnabled = false,
	oldMxiEnabled = false,
	oldMXCLFlags = "",
	oldMultilight = false,
	oldMaxwellSequenceRendering = false,
	oldRenderTime = 0,
	binMeshPaths = #(),
	oldParticles = #(),
	oldgsOverrideImage = false,
	oldibeBgImagePath,
	oldibeReflectionImagePath,
	oldibeRefractionImagePath,
	oldibeIlluminationImagePath,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Maxwell";
	),
	fn getIdentifier =
	(
		return #(MaxwellRenderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn fileCreationMinutes filepath =
	(
		local dFile = dotnetclass "System.IO.File"
		local dDateTime = dotnetclass "System.DateTime"
		local ft = dFile.GetLastWriteTime(filepath)
		local diff = dDateTime.Now.Subtract(ft)
		return diff.TotalMinutes
	),

	fn test resultList val fastCheck =
	(
		index = 0;
		texfiles = #()
		rend = renderers.production
		if classof rend == MaxwellRenderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			if not hasProperty rend "gsChannelRoughness" then
			(
				append resultList (tr id:5001 index:index validator:val severity:2 message:"You need at least Maxwell v2" flagMoreInfos:true type:ONLINE_FAQ)
				return 0
			)
			if isSingleFrameRender() then
				append resultList (tr id:5002 index:index validator:val severity:2 message:"Maxwell still frame render out of 3ds Max not yet supported, export scene to mxs format and use Render Farm Application to import" flagMoreInfos:true type:ONLINE_FAQ)

			if rend.gsChannelRGB == false then
				append resultList (tr id:5003 index:index validator:val severity:2 message:"At least the RGB channel must be active")

			if rend.gsMXCLFlags as string	!= "" AND rend.gsMXCLFlags as string != "-d -nowait" then
				append resultList (tr id:5004 index:index validator:val severity:2 message:("Please remove additional flags \""+rend.gsMXCLFlags+"\""))

			if rend.gsSamplingLevel <= 7 then
				append resultList (tr id:5005 index:index validator:val severity:1 message:"Sampling level very low")

			if rend.gsSamplingLevel >= 15 then
				append resultList (tr id:5006 index:index validator:val severity:1 message:"Sampling level very high - high levels produce long rendertimes")

			if rend.gsRenderTime > 120 then
				append resultList (tr id:5007 index:index validator:val severity:2 message:"Maximum rendertime is 120min. If you need higher values contact Render Farm Application")

			if NOT onlyOneFrame() AND rend.gsMultilight == true then
				append resultList (tr id:5008 index:index validator:val severity:2 message:"Multilight is not supported for animation renders")

			local vptype = viewport.getType()
			if vptype != #view_persp_user and vptype != #view_camera then
				append resultList (tr id:5015 index:index validator:val severity:2 message:"Only Perspective or Camera views can be rendered")

			if getRenderType() == #crop then
				append resultList (tr id:5016 index:index validator:val severity:2 message:"Rendertype Crop is not allowed" flagMoreInfos:true type:ONLINE_FAQ)

--special files from rendersettings
			local bgEnable = false
			if hasProperty rend "ibeBgEnable" then
				bgEnable = rend.ibeBgEnable
			if hasProperty rend "ibeBgState" then
				bgEnable = rend.ibeBgState
			if bgEnable and not (rend.ibeBgImagePath as string== "") then
			(
				if not existsfile(rend.ibeBgImagePath) then
					append resultList (tr id:5017 index:index validator:val severity:2 message:("IBE: Background Map not found ("+rend.ibeBgImagePath+")"))
				else
					append texfiles rend.ibeBgImagePath
			)

			local bgReflectionEnable = false
			if hasProperty rend "ibeReflectionEnable" then
				bgReflectionEnable = rend.ibeReflectionEnable
			if hasProperty rend "ibeReflectionState" then
				bgReflectionEnable = rend.ibeReflectionState
			if bgReflectionEnable and not rend.ibeReflectionUseAsBg then
			(
				if not existsfile(rend.ibeReflectionImagePath) then
					append resultList (tr id:5018 index:index validator:val severity:2 message:("IBE: Reflection Map not found ("+rend.ibeReflectionImagePath+")"))
				else
					append texfiles rend.ibeReflectionImagePath
			)

			local bgRefractionEnable = false
			if hasProperty rend "ibeRefractionEnable" then
				bgRefractionEnable = rend.ibeRefractionEnable
			if hasProperty rend "ibeRefractionState" then
				bgRefractionEnable = rend.ibeRefractionState
			if bgRefractionEnable and not rend.ibeRefractionUseAsBg then
			(
				if not existsfile(rend.ibeRefractionImagePath) then
					append resultList (tr id:5019 index:index validator:val severity:2 message:("IBE: Refraction Map not found ("+rend.ibeRefractionImagePath+")"))
				else
					append texfiles rend.ibeRefractionImagePath
			)

			local bgIlluminationEnable = false
			if hasProperty rend "ibeIlluminationEnable" then
				bgIlluminationEnable = rend.ibeIlluminationEnable
			if hasProperty rend "ibeIlluminationState" then
				bgIlluminationEnable = rend.ibeIlluminationState
			if bgIlluminationEnable and not rend.ibeIlluminationUseAsBg then
			(
				if not existsfile(rend.ibeIlluminationImagePath) then
					append resultList (tr id:5020 index:index validator:val severity:2 message:("IBE: Illumination Map not found ("+rend.ibeIlluminationImagePath+")"))
				else
					append texfiles rend.ibeIlluminationImagePath
			)
			if rend.slApertureImagePath as string != "" then
			(
				if not existsfile(rend.slApertureImagePath) then
					append resultList (tr id:5021 index:index validator:val severity:2 message:("IBE: Aperture Map not found ("+rend.slApertureImagePath+")"))
				else
					append texfiles rend.slApertureImagePath
			)
			if rend.slObscureImagePath as string != "" then
			(
				if not existsfile(rend.slObscureImagePath) then
					append resultList (tr id:5022 index:index validator:val severity:2 message:("IBE: Obstacle Map not found ("+rend.slObscureImagePath+")"))
				else
					append texfiles rend.slObscureImagePath
			)

			if not fastCheck then
			(
				local sref = getClassInstancesSave MXSRef
				for ref in sref do
				(
					try
					(
						if ref.mxsFile != "" then
						(
							if not existsfile(ref.mxsFile) then
								append resultList (tr id:5029 index:index validator:val severity:2 message:("MXSRef: File not found: " + ref.mxsFile))
							else
							(
								local mxspath = ref.mxsFile
								append texfiles mxspath
								local mwcheck = pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath) "plugins"
								mwcheck = pathConfig.appendPath mwcheck "maxwell"
								mwcheck = pathConfig.appendPath mwcheck "mwcheck.exe"
								if existsfile(mwcheck) then
								(
									local p = dotNetObject "System.Diagnostics.Process"
									p.StartInfo.UseShellExecute = false
									p.StartInfo.RedirectStandardOutput = true
									p.StartInfo.CreateNoWindow = true
									p.StartInfo.FileName = mwcheck
									p.StartInfo.Arguments = "passX4f -mxs \"" + mxspath + "\""
									p.Start()
									local stoutput = p.StandardOutput.ReadToEnd()
									p.WaitForExit()

									local keys = #()
									local values = #()
									local vOut = filterstring stoutput "\n" splitEmptyTokens:false
									for i=1 to vOut.count do
									(
										try
										(
											local entry = filterString vOut[i] "|"
											append keys entry[1]
											append values (substring entry[2] 1 (entry[2].count-1))
										)
										catch
										(
										)
									)

									if keys.count != values.count then
										append resultList (tr index:index validator:val severity:2 message:"Could not check mxs file")
									else
									(
										for i=1 to keys.count do
										(
											if keys[i] == "tex" then
											(
												local file = values[i]
												if not existsfile(file) then
													append resultList (tr id:5027 index:index validator:val severity:2 message:("MXSRef: File not found ("+a.name+"): " + values[i]))
												else
													append texfiles values[i]
											)
										)
									)
								)
								else
								(
									append resultList (tr id:5028 index:index validator:val severity:2 message:("mwcheck.exe not found, cannot use mxm files: " + mwcheck))
								)
							)
						)
					)
					catch()
				)

				binMeshPaths = #()
				local binmeshs = getClassInstancesSave BINMesh
				for a in binmeshs do
				(
					try
					(
						if a.path != "" and a.prefix != "" then
						(
							print a.path
							local files = getFiles ((pathConfig.appendPath a.path a.prefix) + "*.bin")
							if files != undefined and files.count == 0 then
								append resultList (tr id:5023 index:index validator:val severity:2 message:("BINMesh: no meshes found at : " + (pathConfig.appendPath a.path a.prefix)) flagMoreInfos:true type:ONLINE_FAQ)
						)
					)
					catch()
				)

				local particles = getClassInstancesSave MxParticles
				for a in particles do
				(
					try
					(
						if a.filename != "" then
						(
							if not existsfile(a.filename) then
								append resultList (tr id:5023 index:index validator:val severity:2 message:("MxParticles: File not found: " + a.filename) flagMoreInfos:true type:ONLINE_FAQ)
							else
								append texfiles a.filename
						)
					)
					catch()
				)

				local filenames = getClassInstancesSave MaxwellBitmap
				for a in filenames do
				(
					try
					(
						if a.FileName != "" then
						(
							if not existsfile(a.FileName) then
								append resultList (tr id:5023 index:index validator:val severity:2 message:("MaxwellBitmap: File not found: " + a.FileName) flagMoreInfos:true type:ONLINE_FAQ)
							else
								append texfiles a.FileName
						)
					)
					catch()
				)
				mxMaterials = getClassInstancesSave Maxwell_Material
				for m in mxMaterials do
				(
					for l in m.Layers do
					(
						for b in l.Bsdfs do
						(
							if b.UseIORFile then
							(
								if not existsfile(b.IORFilename) then
									append resultList (tr id:5024 index:index validator:val severity:2 message:("IOR File not found ("+m.Name+"): " + b.IORFilename))
								else
									append texfiles b.IORFilename
							)
						)
					)
				)
				local refMaterials = getClassInstancesSave Maxwell_Material__Ref
				for a in refMaterials do
				(
					if a.filename != undefined  then
					(
						if not existsfile(a.filename) then
						(
							append resultList (tr id:5025 index:index validator:val severity:2 message:("mxm not found ("+a.name+"): " + a.filename))
							continue
						)
						if (maxversion())[1] < 10000 then
						(
							append resultList (tr id:5026 index:index validator:val severity:2 message:("Due to SDK limitations MXM files are not supported in Max9"))
							continue
						)
						local datapath = pathConfig.appendPath  dlg_main.my_path "mwtemp.tmp"
						deleteFile datapath
						local mxmpath = a.filename
						append texfiles mxmpath
						local mwcheck = pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath) "plugins"
						mwcheck = pathConfig.appendPath mwcheck "maxwell"
						mwcheck = pathConfig.appendPath mwcheck "mwcheck.exe"
						if existsfile(mwcheck) then
						(
							local cmd = ("\"" + mwcheck + "\" passX4f -mxm \""  + mxmpath + "\"")
							local p = dotNetObject "System.Diagnostics.Process"
							p.StartInfo.UseShellExecute = false
							p.StartInfo.RedirectStandardOutput = true
							p.StartInfo.CreateNoWindow = true
							p.StartInfo.FileName = mwcheck
							p.StartInfo.Arguments = "passX4f -mxm \"" + mxmpath + "\""
							p.Start()
							local stoutput = p.StandardOutput.ReadToEnd()
							p.WaitForExit()

							local keys = #()
							local values = #()
							local vOut = filterstring stoutput "\n" splitEmptyTokens:false
							for i=1 to vOut.count do
							(
								try
								(
									local entry = filterString vOut[i] "|"
									append keys entry[1]
									append values (substring entry[2] 1 (entry[2].count-1))
								)
								catch
								(
								)
							)

							if keys.count != values.count then
								append resultList (tr index:index validator:val severity:2 message:"Could not check mxm file")
							else
							(
								for i=1 to keys.count do
								(
									if keys[i] == "tex" then
									(
										local file = values[i]
										if not existsfile(file) then
											append resultList (tr id:5027 index:index validator:val severity:2 message:("Material Ref: File not found ("+a.name+"): " + values[i]))
										else
											append texfiles values[i]
									)
								)
							)
						)
						else
						(
							append resultList (tr id:5028 index:index validator:val severity:2 message:("mwcheck.exe not found, cannot use mxm files: " + mwcheck))
						)
					)
				)
			)
		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == MaxwellRenderer then
		(
			oldMxsOutput = rend.gsMXSOutputPath
			oldMxiOutput = rend.gsMXIOutputPath
			oldMxsEnabled = rend.gsGenerateMXSOutput
			oldMxiEnabled = rend.gsGenerateMXIOutput
			oldMXCLFlags = "-d -nowait"
			oldMultilight = rend.gsMultilight
			oldMaxwellSequenceRendering = rend.gsMaxwellSequenceRendering
			oldRenderTime = rend.gsRenderTime
			rend.gsMXSOutputPath = "c:\\logs\\temp.mxs"
			rend.gsMXIOutputPath = "c:\\logs\\temp.mxi"
			rend.gsGenerateMXSOutput = true
			rend.gsGenerateMXIOutput = true
			rend.gsMXCLFlags = "-nowait -nomxi -mintime:120 -node -bitmaps:\"" + (createTexPath dlg_main.m_userName  "") + "\"  -copyimage:\""+(createOutputPath dlg_main.m_userName "")+"\""
			rend.gsMultilight = false
			rend.gsMaxwellSequenceRendering = false
			rend.gsRenderTime = 120
			--output filename must not have digits at the end "test000.jpg" -> "test.jpg"
			rendOutputFilename = "C:\\logs\\" + (removeTrailingDigits (getFilenameFile rendOutputFilename)) + (getFilenameType rendOutputFilename)
			oldgsOverrideImage = rend.gsOverrideImage
			try
			(
				rend.gsOverrideImage=false
				outfilename = filenameFromPath rendOutputFilename
				rend.gsMXSOutputPath = "c:\\logs\\"+(getFilenameFile outfilename) +".mxs"
				rend.gsMXIOutputPath = "c:\\logs\\"+(getFilenameFile outfilename) +".mxi"
			)catch()

			for i=1 to texfiles.count do
			(
				local f = texfiles[i]
				appendFileInfo &vecFiles f ("tex/" + filenameFromPath f)
			)

			oldMxmFilenames = #()
			local refMaterials = getClassInstancesSave Maxwell_Material__Ref
			for a in refMaterials do
			(
				if a.filename != undefined  then
				(
					append oldMxmFilenames a.filename
					local mp = createTexPath dlg_main.m_userName (filenameFromPath a.filename)
					a.filename = mp
				)
			)

			oldParticles = #()
			local particles = getClassInstancesSave MxParticles
			for a in particles do
			(
				try
				(
					if a.filename != "" then
					(
						append oldParticles a.filename
						local mp = createTexPath dlg_main.m_userName (filenameFromPath a.filename)
						a.filename = mp
					)
				)
				catch()
			)

			oldMxsFilenames = #()
			local srefs = getClassInstancesSave MXSRef
			for a in srefs do
			(
				if a.mxsFile != undefined  then
				(
					append oldMxsFilenames a.mxsFile
					local mp = createTexPath dlg_main.m_userName (filenameFromPath a.mxsFile)
					a.mxsFile = mp
				)
			)

			binMeshPaths = #()
			local binmeshs = getClassInstancesSave BINMesh
			for a in binmeshs do
			(
				try
				(
					if a.path != "" and a.prefix != "" then
					(
						local files = getFiles ((pathConfig.appendPath a.path a.prefix) + "*.bin")
						for f in files do
						(
							appendFileInfo &vecFiles f ("tex/" + (filenameFromPath f))
						)
						append binMeshPaths a.path
						a.path = createTexPath dlg_main.m_userName ""
					)
				)
				catch()
			)

			try
			(
			 
			)
			catch( format "texture.ms: disp*** % ***\n" (getCurrentException()) )
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == MaxwellRenderer then
		(
			rend.gsMXSOutputPath = oldMxsOutput
			rend.gsMXIOutputPath = oldMxiOutput
			rend.gsGenerateMXSOutput = oldMxsEnabled
			rend.gsGenerateMXIOutput =oldMxiEnabled
			rend.gsMXCLFlags = oldMXCLFlags
			rend.gsMultilight = oldMultilight
			rend.gsMaxwellSequenceRendering = oldMaxwellSequenceRendering
			rend.gsRenderTime = oldRenderTime
			rendSaveFile=true
			local i = 1
			local refMaterials = getClassInstancesSave Maxwell_Material__Ref
			for a in refMaterials do
			(
				if a.filename != undefined  then
				(
					a.filename = oldMxmFilenames[i]
					i=i+1
				)
			)

			i=1
			local srefs = getClassInstancesSave MXSRef
			for a in srefs do
			(
				if a.mxsFile != undefined  then
				(
					a.mxsFile = oldMxsFilenames[i]
					i=i+1
				)
			)

			i=1
			local particles = getClassInstancesSave MxParticles
			for a in particles do
			(
				try
				(
					if a.filename != "" then
					(
						a.filename = oldParticles[i]
						i=i+1
					)
				)
				catch()
			)


			try
			(
				local binMeshes = getClassInstancesSave BINMesh
				local i=0
				for b in binMeshes do
				(
					i=i+1
					b.path = binMeshPaths[i]
				)
			)
			catch
			(
					format "val_maxwell.ms: binmesh *** % ***\n" (getCurrentException())
			)

			try
			(
				rend.ibeBgImagePath = oldibeBgImagePath
				rend.ibeReflectionImagePath = oldibeReflectionImagePath
				rend.ibeRefractionImagePath = oldibeRefractionImagePath
				rend.ibeIlluminationImagePath = oldibeIlluminationImagePath
			)
			catch( format "texture.ms: disp*** % ***\n" (getCurrentException()) )
		)
	)
)

struct ValBrazil
(

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Brazil";
	),
	fn getIdentifier =
	(
		return #(Brazil_r_s_Rio_Learning_Edition_v2_0__build_1618)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == Brazil_r_s_Rio_Learning_Edition_v2_0__build_1618 then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			if isSingleFrameRender() then
				append resultList (tr id:1001 index:index validator:val severity:2 message:"Brazil still frame render not yet supported on Render Farm Application")

			append resultList (tr id:1002 index:index validator:val severity:2 message:"Brazil found.")
		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

rollout corona_dlg "Your job uses Global Illumination" width:500 height:500
(
	local selectedMode = -1

	Button btnCameraFly "Calculate before Rendering" align:#left
	EditText lblCamera text:"\"Calculate before Rendering\"
Choose this option for Render Farm Application to calculate your UHD file for the whole animation.
It means the UHD will be calculated separately from the Pixel calculation." height:100 readOnly:true
	Button btnCameraMoreInfo "more infos" align:#right

	Button btnObjectAni "Calculate on the Fly" align:#left
	EditText lblObject text:"\"Calculate on the Fly\"
Choose this option for the UHD to be calculated for every starting frame.
Take into count flickering might appear, since the animation will be distributed among several nodes." height:100 readOnly:true
	Button btnObjectMoreInfo "more infos" align:#right

	Button btnLocal "Use Local Solution" align:#left
	EditText lblLocal  text:"\"Use Local Solution\"
Choose this option if you have cached a UHD file.
Render Farm Application will use your solution and NOT render any UHD for you. The costs wil be then reduced." height:100 readOnly:true
	Button btnLocalMoreInfo "more infos" align:#right

	on btnCameraMoreInfo pressed do
	(
		goToOnlineFaq 14003
	)

	on btnObjectMoreInfo pressed do
	(
		goToOnlineFaq 14004
	)

	on btnLocalMoreInfo pressed do
	(
		goToOnlineFaq 14005
	)

	on btnCameraFly pressed do
	(
		corona_dlg.selectedMode = 0
		DestroyDialog corona_dlg
	)

	on btnObjectAni pressed do
	(
		corona_dlg.selectedMode = 1
		DestroyDialog corona_dlg
	)

	on btnLocal pressed do
	(
		corona_dlg.selectedMode = 2
		DestroyDialog corona_dlg
	)
)

corona_maxrp_dlg_maxPasses = -1
corona_maxrp_dlg_maxNoiseLevel = -1
corona_maxrp_dlg_jobType = #ani

rollout corona_maxrp_dlg "Choose your Progressive settings" width:500 height:250
(
	EditText lblCamera text:"txt" height:150 readOnly:true

	Spinner spPasses "Pass limit:" range:[25,100000,25] type:#integer
	Spinner spNoise "Noise level limit:" range:[0.0000,100000,0] type:#float visible:false scale:0.001
	Button btnOk "Ok" align:#right
	Button btnCancel "Cancel" align:#right

	fn hasNoiseOption =
	(
		return (hasProperty renderers.production "adaptivity_targetError") and corona_maxrp_dlg_jobType == #ani
	)

	on corona_maxrp_dlg open do
	(

		if isSingleFrameRender() then
			corona_maxrp_dlg.setJobType #single
		else
		(
			corona_maxrp_dlg.setJobType #ani
		)
		corona_maxrp_dlg.spNoise.visible=hasNoiseOption()
		if hasNoiseOption() then
			corona_maxrp_dlg_maxPasses = spNoise.value = renderers.production.adaptivity_targetError

		corona_maxrp_dlg_maxPasses = spPasses.value = renderers.production.progressive_passLimit

		if spPasses.value < 0 then
			spPasses.value = 0
	)

	on spPasses changed val inSpin_arg do
	(
		corona_maxrp_dlg_maxPasses = renderers.production.progressive_passLimit = spPasses.value
	)

	on spNoise changed val inSpin_arg do
	(
		if hasNoiseOption() do
		(
			corona_maxrp_dlg_maxNoiseLevel = renderers.production.adaptivity_targetError = spNoise.value
		)
	)

	on btnOk pressed do
	(
		min_passes = 0

		if hasNoiseOption() and (spPasses.value <= min_passes or spNoise.value <= 0.005) then
		(
			messagebox "You need to set Passes higher than 1 and Noise level higher than 0.005" title:"Render Farm Application Manager"
			return 0
		)
		corona_maxrp_dlg_maxPasses = renderers.production.progressive_passLimit = spPasses.value
		corona_maxrp_dlg_maxNoiseLevel = renderers.production.adaptivity_targetError = spNoise.value
		DestroyDialog corona_maxrp_dlg
	)
	on btnCancel pressed do
	(
		DestroyDialog corona_maxrp_dlg
	)

	fn setJobType type =
	(
		corona_maxrp_dlg_jobType = type

		lblCamera.text = "Choose your settings here to overwrite the ending criteria form your scene.

The rendering stops if the Pass Limit is reached.

Stopping after selected time or after Renderpoint Limit is reached is currently not possible.
"
		if type == #ani then
		(
			local passRangeLow = 1
			if hasNoiseOption() then
			(
				passRangeLow = 0
		lblCamera.text = "Choose your settings here to overwrite the ending criteria form your scene.

You can input the Pass Limit to use and the noise level to be reached.
The rendering will stop if either of these is reached.

Stopping after selected time or after Renderpoint Limit is reached is currently not possible.
"
			)

			spPasses.range= [passRangeLow,100000,25]
		)
		else
		(
			spPasses.range= [25,100000,25]
		)

	)
)

struct OldCoronaVolumeGrids
(
	object,
	file_paths
);

struct ValCorona
(
	METHOD_UNSET = -1,
	METHOD_CAM = 0,
	METHOD_OBJ = 1,
	METHOD_LOC = 2,

	ANI_METHOD = 1,
	MAX_RP_DIALOG = 2,

	distributedMachines = 25,

	oldDistributed = false,
	oldgi_hdCache_file = "",
	oldgi_hdCache_save = false,
	oldgi_hdCache_precalcMode = 0,
	oldRenderer = 0,
	oldprogressive_timeLimit = 0,
	oldprogressive_passLimit = 0,
	oldRenderType = #crop,
	oldlockSamplingPattern = 0,
	oldXres = 0,
	oldYres = 0,
	oldvfb_autosave_enable = false,
	oldrenderstamp_use = false,
	oldcolorMap_lut_path = "",
	olddenoise_filterType = undefined,
	oldstringOptions = "",
	oldPhoenixSimulatorPaths = #(),
	oldPhoenixSimulatorOutputPaths = #(),
	old_corona_volume_grids = #(),


	-- cache file name for corona 6 will be replaced further down in each function
	hdCache_file = "gi_uhdCache_file",
	hdCache_save = "gi_uhdCache_save",
	hdCache_precalcMode = "gi_uhdCache_precalcMode",

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "CoronaRenderer";
	),
	fn getIdentifier =
	(
		return #(CoronaRenderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn getProgressivePasses =
	(
		if corona_maxrp_dlg_maxPasses != undefined and corona_maxrp_dlg_maxPasses > 0 then
			return corona_maxrp_dlg_maxPasses

		return renderers.production.progressive_passLimit
	),

	fn getProgressiveThreshold =
	(
		if corona_maxrp_dlg_maxNoiseLevel != undefined and corona_maxrp_dlg_maxNoiseLevel > 0 then
			return corona_maxrp_dlg_maxNoiseLevel

		if corona_maxrp_dlg.hasNoiseOption() then
			return renderers.production.adaptivity_targetError
		return 0
	),


	fn test resultList val fastCheck =
	(
		index = 0;
		local version = getCoronaIntVersion()
		local coronaver = CoronaRenderer.CoronaFp.getVersionMajorNumber()
		if version >= 60000 or coronaver >= 7 then
		(
			hdCache_file = "gi_giCache_file"
			hdCache_save = "gi_giCache_save"
			hdCache_precalcMode = "gi_giCache_precalcMode"
		)

		rend = renderers.production
		version_to_old_message = "Corona Version too old: You need at least version 3, you have..." + getCoronaIntVersion() as string

		if classof rend == CoronaRenderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			if not hasProperty rend "HD_cache_dump_filename" and not hasProperty rend "gi_hdCache_file" and not hasProperty rend "gi_uhdCache_file" and not hasProperty rend "gi_giCache_file" then
			(
				append resultList (tr id:14008 index:index validator:val severity:2 message:version_to_old_message)
				return false
			)
			if not hasProperty rend "gi_uhdCache_file" and not hasProperty rend "gi_giCache_file" then
			(
				hdCache_file = "gi_hdCache_file"
				hdCache_save = "gi_hdCache_save"
				hdCache_precalcMode = "gi_hdCache_precalcMode"
			)



			try
			(
				local version = getCoronaIntVersion()
				if version < 30000 then
					append resultList (tr id:14008 index:index validator:val severity:2 message:version_to_old_message)
			)
			catch
			(
				append resultList (tr id:14008 index:index validator:val severity:2 message:version_to_old_message)
				return false
			)
			
			if CoronaRenderer.CoronaFp.getVersionMajorNumber() <= 6 then --Corona 6 and below
			(
				if isSingleFrameRender() then -- Distributed Rendering
				(
					if rend.shading_renderEngine == 2 then -- progressive
					(
						errorOrInfo = val.check_progressive_settings()
						if errorOrInfo == 2 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Please confirm your options" flagMoreInfos:true type:MAX_RP_DIALOG)
						else if errorOrInfo == 1 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Your passes setting seems to be very high" flagMoreInfos:true type:MAX_RP_DIALOG)
						else
						(
							append resultList (tr id:14010 index:index validator:val severity:0 message:("Progressive rendering: Your Job is setup to use reach " + corona_maxrp_dlg_maxPasses as string + " passes!") flagMoreInfos:true type:MAX_RP_DIALOG)
						)
					)
					else if rend.shading_renderEngine == 0 then --bucket
					(
						--nothing here
					)
					else
						append resultList (tr id:14001 index:index validator:val severity:2 message:"Render engine not supported for technical reasons. Use \"Bucket\" or \"Progressive\" instead" flagMoreInfos:true type:ONLINE_FAQ)

					if hasProperty rend "denoise_filterType" then
					(
						if rend.denoise_filterType == 2 then
						(
							if rend.shading_renderEngine == 2 then
								append resultList (tr id:14011 index:index validator:val severity:0 message:("Full denoising will be charged additionally to the maximum RenderPoints you have chosen."))

							if (getFilenameType rendOutputFilename) != ".cxr" then
								append resultList (tr id:14011 index:index validator:val severity:2 message:("Denoise Mode: \"Full denoising\" only works with .cxr files."))
						)
						if rend.denoise_filterType == 3 then
						(
							if (getFilenameType rendOutputFilename) != ".cxr" then
									append resultList (tr id:14011 index:index validator:val severity:2 message:("Denoise Mode: \"Gather data for later\" only works with .cxr files."))
						)
					)
				)
				else
				(
					if rend.shading_renderEngine == 3  then
						append resultList (tr id:14001 index:index validator:val severity:2 message:"Rendereingine \"BiDir\" not supported for technical reasons")

					if rend.shading_renderEngine == 2 then -- progressive
					(
						errorOrInfo = val.check_progressive_settings()
						if errorOrInfo == 2 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Please confirm your options" flagMoreInfos:true type:MAX_RP_DIALOG)
						else if errorOrInfo == 1 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Your passes setting seems to be very high" flagMoreInfos:true type:MAX_RP_DIALOG)
						else
						(
							corona_maxrp_dlg_maxPasses = renderers.production.progressive_passLimit

							append resultList (tr id:14010 index:index validator:val severity:errorOrInfo message:("Progressive rendering: Your Job is setup to use reach " + corona_maxrp_dlg_maxPasses as string + " passes!") flagMoreInfos:true type:MAX_RP_DIALOG)
							if dlg_main.estimateRenderpoints then
								append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating progressive rendering currently not possible!"))
						)
					)

					if rend.shading_primarySolver == 1 and (rend.shading_secondarySolver == 3 or rend.shading_secondarySolver == 4) and not onlyOneFrame() then
					(
						case corona_dlg.selectedMode of
						(
							METHOD_UNSET:
								append resultList (tr id:14003 index:index validator:val severity:2 message:"Choose your GI modus" flagMoreInfos:true type:ANI_METHOD)
							METHOD_CAM:
							(
								append resultList (tr id:14003 index:index validator:val severity:0 message:"\"Calculate before Rendering\" selected" flagMoreInfos:true type:ANI_METHOD)
								if skyatchRender.batchRender.checked and batchRenderMgr.numViews != 0 then
									append resultList (tr id:14003 index:index validator:val severity:2 message:("Combining Batch rendering and Camera Animation is not yet possible"))
								if dlg_main.estimateRenderpoints then
									append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating Camera Animation rendering currently not possible!"))
							)
							METHOD_OBJ:
								append resultList (tr id:14003 index:index validator:val severity:0 message:"\"Calculate on the Fly\" selected" flagMoreInfos:true type:ANI_METHOD)
							METHOD_LOC:
							(
								append resultList (tr id:14003 index:index validator:val severity:0 message:"\"Use Local Solution\" selected" flagMoreInfos:true type:ANI_METHOD)
								local files = getFiles ((getFilenamePath (getProperty rend hdCache_file)) + "*" + (getFilenameType (getProperty rend hdCache_file)))
								if files.count == 0 then
									append resultList (tr id:14006 index:index validator:val severity:2 message:"GI File not found" flagMoreInfos:true type:ANI_METHOD)
							)
						)
					)
				)
			) -- corona 7 and above
			else
			(
				if isSingleFrameRender() then -- Distributed Rendering
				(
					if rend.shading_renderEngine == 1 then -- progressive
					(
						errorOrInfo = val.check_progressive_settings()
						if errorOrInfo == 2 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Please confirm your options" flagMoreInfos:true type:MAX_RP_DIALOG)
						else if errorOrInfo == 1 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Your passes setting seems to be very high" flagMoreInfos:true type:MAX_RP_DIALOG)
						else
						(
							append resultList (tr id:14010 index:index validator:val severity:0 message:("Progressive rendering: Your Job is setup to use reach " + corona_maxrp_dlg_maxPasses as string + " passes!") flagMoreInfos:true type:MAX_RP_DIALOG)
						)
					)
					else if rend.shading_renderEngine == 0 then --bucket
					(
						--nothing here
					)
					else
						append resultList (tr id:14001 index:index validator:val severity:2 message:"Render engine not supported for technical reasons. Use \"Bucket\" or \"Progressive\" instead" flagMoreInfos:true type:ONLINE_FAQ)

					if hasProperty rend "denoise_filterType" then
					(
						if rend.denoise_filterType == 2 then
						(
							if rend.shading_renderEngine == 1 then
								append resultList (tr id:14011 index:index validator:val severity:0 message:("Full denoising will be charged additionally to the maximum RenderPoints you have chosen."))

							if (getFilenameType rendOutputFilename) != ".cxr" then
								append resultList (tr id:14011 index:index validator:val severity:2 message:("Denoise Mode: \"Full denoising\" only works with .cxr files."))
						)
						if rend.denoise_filterType == 3 then
						(
							if (getFilenameType rendOutputFilename) != ".cxr" then
									append resultList (tr id:14011 index:index validator:val severity:2 message:("Denoise Mode: \"Gather data for later\" only works with .cxr files."))
						)
					)
				)
				else
				(
					if rend.shading_renderEngine == 3  then
						append resultList (tr id:14001 index:index validator:val severity:2 message:"Rendereingine \"BiDir\" not supported for technical reasons")

					if rend.shading_renderEngine == 1 then -- progressive
					(
						errorOrInfo = val.check_progressive_settings()
						if errorOrInfo == 2 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Please confirm your options" flagMoreInfos:true type:MAX_RP_DIALOG)
						else if errorOrInfo == 1 then
							append resultList (tr id:14008 index:index validator:val severity:errorOrInfo message:"Progressive rendering: Your passes setting seems to be very high" flagMoreInfos:true type:MAX_RP_DIALOG)
						else
						(
							corona_maxrp_dlg_maxPasses = renderers.production.progressive_passLimit

							append resultList (tr id:14010 index:index validator:val severity:errorOrInfo message:("Progressive rendering: Your Job is setup to use reach " + corona_maxrp_dlg_maxPasses as string + " passes!") flagMoreInfos:true type:MAX_RP_DIALOG)
							if dlg_main.estimateRenderpoints then
								append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating progressive rendering currently not possible!"))
						)
					)

					if rend.shading_primarySolver == 1 and (rend.shading_secondarySolver == 2 or rend.shading_secondarySolver == 3) and not onlyOneFrame() then
					(
						case corona_dlg.selectedMode of
						(
							METHOD_UNSET:
								append resultList (tr id:14003 index:index validator:val severity:2 message:"Choose your GI modus" flagMoreInfos:true type:ANI_METHOD)
							METHOD_CAM:
							(
								append resultList (tr id:14003 index:index validator:val severity:0 message:"\"Calculate before Rendering\" selected" flagMoreInfos:true type:ANI_METHOD)
								if skyatchRender.batchRender.checked and batchRenderMgr.numViews != 0 then
									append resultList (tr id:14003 index:index validator:val severity:2 message:("Combining Batch rendering and Camera Animation is not yet possible"))
								if dlg_main.estimateRenderpoints then
									append resultList (tr id:9054 index:index validator:val severity:2 message:("Common: estimating Camera Animation rendering currently not possible!"))
							)
							METHOD_OBJ:
								append resultList (tr id:14003 index:index validator:val severity:0 message:"\"Calculate on the Fly\" selected" flagMoreInfos:true type:ANI_METHOD)
							METHOD_LOC:
							(
								append resultList (tr id:14003 index:index validator:val severity:0 message:"\"Use Local Solution\" selected" flagMoreInfos:true type:ANI_METHOD)
								local files = getFiles ((getFilenamePath (getProperty rend hdCache_file)) + "*" + (getFilenameType (getProperty rend hdCache_file)))
								if files.count == 0 then
									append resultList (tr id:14006 index:index validator:val severity:2 message:"GI File not found" flagMoreInfos:true type:ANI_METHOD)
							)
						)
					)
				)
			)

			if rend.bg_source == 2 then -- .bg_source = Multimap Scene environment in rendersettings.
			(
				append resultList (tr id:14003 index:index validator:val severity:1 message:"!!!!!!: \"Multiple maps Scene Environment\" selected. We strongly advice to send small resolution tests, before rendering. This may lead to lighting differences." )
			)

			if hasProperty rend "colorMap_lut_path" then
			(
				if rend.colorMap_lut_enable then
				(
					if rend.colorMap_lut_path != undefined and not existsFile rend.colorMap_lut_path then
						append resultList (tr id:14009 index:index validator:val severity:2 message:("LUT file not found " + rend.colorMap_lut_path))
				)
			)
		)
		--PhoenixFD
		try
		(
			local fds = getClassInstancesSave PhoenixSimulator
			join fds (getClassInstancesSave FireSmokeSim)
			join fds (getClassInstancesSave LiquidSim)
			for fd in fds do
			(
				local f = parsePhoenixPath fd fd.rendinput
				f = replaceAll f "#" "*"

				if findString f "$(" != undefined then
					append resultList (tr id:12097 index:index validator:val severity:2 message:("PhoenixFD: \"$\" not allowed in input path. Use absolute path instead of \""+f+"\"."))
				else
				(
					local files = getFiles f
					if files.count == 0 then
					(
						append resultList (tr id:12096 index:index validator:val severity:2 message:("PhoenixFD simulation files not found (input rollout) \""+f+"\".") flagMoreInfos:true type:PHOENIX_FD_NOT_FOUND)
					)
				)
			)
		)
		catch()
	

	),

	fn check_progressive_settings =
	(

		corona_maxrp_dlg_maxPasses = getProgressivePasses()
		corona_maxrp_dlg_maxNoiseLevel = getProgressiveThreshold()

		if corona_maxrp_dlg_maxPasses <= 0 or (corona_maxrp_dlg_maxNoiseLevel < 0.0005 and corona_maxrp_dlg_jobType == #ani) then
			errorOrInfo = 2
		else if corona_maxrp_dlg_maxPasses > 500 then
			errorOrInfo = 1
		else
			errorOrInfo = 0

		return errorOrInfo
	),

	fn furtherAction result =
	(
		local resolved = false
		case result.type of
		(
		ANI_METHOD:
			(
				CreateDialog corona_dlg modal:true
				case corona_dlg.selectedMode of
				(
					METHOD_CAM:
					(
						result.message = "\"Calculate before Rendering\" selected"
						resolved = true
					)
					METHOD_OBJ:
					(
						result.message = "\"Calculate on the Fly\" selected"
						resolved = true
					)
					METHOD_LOC:
					(
						result.message = "\"Use Local Solution\" selected"
						resolved = true
					)
				)
			)
		ONLINE_FAQ:
			(
				goToOnlineFaq result.id
			)
		MAX_RP_DIALOG:
			(
				CreateDialog corona_maxrp_dlg modal:true
				if corona_maxrp_dlg_maxPasses != undefined and corona_maxrp_dlg_maxPasses > 0 then
				(
					result.message = ("Progressive rendering: Your Job is setup to reach " + corona_maxrp_dlg_maxPasses as string + " passes!")
					resolved = true
				)
			)
		PHOENIX_FD_NOT_FOUND:
		st="You need to simulate FD solution first. Render Farm Application can't simulate the caches for you"
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		local version = getCoronaIntVersion()
		local coronaver = CoronaRenderer.CoronaFp.getVersionMajorNumber()
		if version >= 60000 or coronaver >= 7 then
		(
			hdCache_file = "gi_giCache_file"
			hdCache_save = "gi_giCache_save"
			hdCache_precalcMode = "gi_giCache_precalcMode"
		)

		rend = renderers.production
		if classof rend == CoronaRenderer then
		(
			if not hasProperty rend "gi_hdCache_file" and not hasProperty rend "gi_uhdCache_file" and not hasProperty rend "gi_giCache_file" then --this is a older corona version
			(
				return true
			)
			oldDistributed = rend.dr_enable
			old_check_on_lan_during_render = rend.dr_searchDuringRender
			rend.dr_enable = false
			rend.dr_searchDuringRender = false
			oldgi_hdCache_file = (getProperty rend hdCache_file)
			oldgi_hdCache_save = (getProperty rend hdCache_save)
			oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
			oldRenderType = getrendertype()
			oldprogressive_timeLimit = rend.progressive_timeLimit
			oldprogressive_passLimit = rend.progressive_passLimit
			oldlockSamplingPattern = rend.lockSamplingPattern
			oldXres = renderWidth
			oldYres = renderHeight
			try(oldvfb_autosave_enable = rend.vfb_autosave_enable)catch()
			oldrenderstamp_use = rend.renderstamp_use
			olddenoise_filterType = undefined
			oldstringOptions = rend.stringOptions

			try(rend.vfb_autosave_enable=false)catch()

			settingsToWrite += "coronaV1=1\n"
			--corona 7 and above. Should be done better instead of repeat code
			if CoronaRenderer.CoronaFp.getVersionMajorNumber() > 6 then
			(
				if isSingleFrameRender() then
				(
					if rend.shading_renderEngine == 1 then -- progressive
					(
						settingsToWrite += "singleframeMaxCoronaProgressive=1\n"
						settingsToWrite += "samplinglevel="+(getProgressivePasses()) as string+"\n"
						if getProgressiveThreshold() >0 then
							settingsToWrite += "noiselevel="+(getProgressiveThreshold()) as string+"\n"

						--merge script won't work if filename ends with digit, elements are already checked for that and raise an E
						rendOutputFilename = (pathConfig.removePathLeaf rendOutputFilename) + "\\"+ (removeTrailingDigits (getFilenameFile rendOutputFilename)) + (getFilenameType rendOutputFilename)

						rend.progressive_timeLimit = 0
						print rend.progressive_timeLimit
						rend.progressive_passLimit = ceil ((getProgressivePasses()) / distributedMachines as float)
						print rend.progressive_passLimit
						rend.lockSamplingPattern = false

						if findstring rend.stringOptions "bool shading.firstPassWithoutAa = false" == undefined then
							rend.stringOptions += "\r\nbool shading.firstPassWithoutAa = false"

						local filename = dlg_main.changedMaxFile + ".corona_progressive_post.ms"
						local filepath = (fPath + "\\" + filename)
						file = openFile filepath mode:"a"
						if file == undefined then
							file = createFile filepath

						if file != undefined then
						(
							local fileTxt = "
	fn at2CoronaPostRenderSkript =
	(
		local passes = CoronaRenderer.CoronaFp.getStatistic 0 as integer
		local framenumber = (currentTime as string)
		framenumber = substring framenumber 1 (framenumber.count-1)
		local filepath = rendOutputFilename + \".passinfo.\"+ framenumber + \".lock\"
		file = openFile filepath mode:\"w\"
		if file == undefined then
			file = createFile filepath
		format \"%\" passes to:file
		close file
	)

	at2CoronaPostRenderSkript()
	"

							format "%" fileTxt to:file

							callbacks.addscript #postRenderFrame id:#at2PostRender fileName:(createPath dlg_main.m_userName (dlg_main.changedMaxFile + ".corona_progressive_post.ms")) persistent:true
						)
						close file
						appendFileInfo &vecFiles filepath filename tcopy:false
					)
					else
					(
						settingsToWrite += "singleframeMaxCoronaNew2=1\n"

						setrendertype #region
						setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))
						setrendertype #crop
						setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))

						rend.renderstamp_use = false
					)

					if rend.shading_primarySolver == 1 and (rend.shading_secondarySolver == 2 or rend.shading_secondarySolver == 3) then
					(
						if existsFile (getProperty rend hdCache_file) then
						(
							local filename = filenameFromPath (getProperty rend hdCache_file)
							appendFileInfo &vecFiles (getProperty rend hdCache_file) ("tex/" + filename)
							setProperty rend hdCache_save (false)
							setProperty rend hdCache_precalcMode (1)
							setProperty rend hdCache_file (createTexPath dlg_main.m_userName filename)

						)
						else
						(
							settingsToWrite += "hdcache=1\n"

							oldgi_hdCache_file = (getProperty rend hdCache_file)
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							oldRenderer = rend.shading_renderEngine
							local moldprogressive_timeLimit = rend.progressive_timeLimit	--use local variable so it gets reset correctly in postsave
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							oldrendSaveFile = rendSaveFile
							oldElems = (maxOps.GetRenderElementMgr #Production).GetElementsActive()

							setProperty rend hdCache_file (createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".cgd"))
							setProperty rend hdCache_save (true)
							setProperty rend hdCache_precalcMode (0)
							rend.shading_renderEngine = 1
							rend.progressive_timeLimit = 3000
							rendSaveFile = false
							(maxOps.GetRenderElementMgr #Production).SetElementsActive false

							local presetCats = (renderpresets.SaveCategories 0)
							deleteItem presetCats 2
							deleteItem presetCats 3
							local corona_prePresetPath = dlg_main.changedMaxFile + ".corona_single_pass1.rps"
							renderpresets.Save 0 (fPath + "\\" + corona_prePresetPath) presetCats
							appendFileInfo &vecFiles (fPath + "\\" + corona_prePresetPath) (corona_prePresetPath) tcopy:false

							--reset
							setProperty rend hdCache_save (false)
							setProperty rend hdCache_precalcMode (1)
							rend.shading_renderEngine = oldRenderer
							rend.progressive_timeLimit = moldprogressive_timeLimit
							rendSaveFile = oldrendSaveFile
							(maxOps.GetRenderElementMgr #Production).SetElementsActive oldElems
						)
					)


					if rend.denoise_filterType == 2 then
					(
						settingsToWrite += "coronaDenoise=1\n"
						settingsToWrite += "coronaDenoiseSensitivity="+rend.denoise_sensitivity as string+"\n"
						settingsToWrite += "coronaDenoiseBlendAmount="+rend.denoise_blendAmount as string+"\n"
						olddenoise_filterType = rend.denoise_filterType
						rend.denoise_filterType = 3
					)

				)
				else
				(
					-- check for Corona Volume Grid Filepaths are saved in an array
					-- array needs to be stored and changed
					-- moved up here because This got no string to convert to Filename before looping though the array

					volume_grids = getClassInstances CVolumeGrid

					for volume_grid in volume_grids do
					(
						local current_volume_grid_paths = (deepcopy ((getProperty volume_grid "filePaths") as Array))
						-- because f****** MaxScript keeps referencing that shitty CVolumeGrid ArrayParamater (which should be an Array), although it is a deepcopy.
						-- Converted to Array to make it work

						old_corona_volume_grid = OldCoronaVolumeGrids object: volume_grid file_paths: (deepcopy current_volume_grid_paths)

						append old_corona_volume_grids old_corona_volume_grid

						new_volume_grid_paths = #()

						for file_path in current_volume_grid_paths do
						(
							server_path = ("tex/" + (myFilenamefrompath file_path))
							appendFileInfo &vecFiles file_path server_path
							append new_volume_grid_paths server_path
						)
						if new_volume_grid_paths.count > 0 then
							setProperty volume_grid "filePaths" new_volume_grid_paths
					)


					if rend.shading_renderEngine == 1 then -- progressive
					(
						settingsToWrite += "animationMaxCoronaProgr=1\n"
						settingsToWrite += "samplinglevel="+(getProgressivePasses()) as string+"\n"
						if getProgressiveThreshold() >0 then
							settingsToWrite += "noiselevel="+(getProgressiveThreshold()) as string+"\n"

						local framecount = 1
						if rendTimeType == 2 then
							framecount = (animationRange.end.frame as integer) - (animationRange.start.frame as integer) + 1
						if rendTimeType == 3 then
							framecount = (rendEnd.frame as integer) - (rendStart.frame as integer) +1
						if rendTimeType == 1 then
							framecount = 1
						framecount = floor((framecount as float) / rendNthframe)
						if framecount < 1 then
							framecount = 1

						rend.progressive_timeLimit = 0
						rend.progressive_passLimit = getProgressivePasses()
						if corona_maxrp_dlg.hasNoiseOption() then
							rend.adaptivity_targetError = getProgressiveThreshold()
					--	rend.lockSamplingPattern = false
					)

					case corona_dlg.selectedMode of
					(
						METHOD_CAM:
						(
							--backup
							oldgi_hdCache_file = (getProperty rend hdCache_file)
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							oldRenderer = rend.shading_renderEngine
							oldprogressive_timeLimit = rend.progressive_timeLimit
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							oldrendSaveFile = rendSaveFile
							oldElems = (maxOps.GetRenderElementMgr #Production).GetElementsActive()

							setProperty rend hdCache_file (createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".cgd"))
							setProperty rend hdCache_save (true)
							rend.shading_renderEngine = 1
							rend.progressive_timeLimit = 3000
							setProperty rend hdCache_precalcMode (0)
							rendSaveFile = false
							(maxOps.GetRenderElementMgr #Production).SetElementsActive false

							local presetCats = (renderpresets.SaveCategories 0)
							deleteItem presetCats 2
							deleteItem presetCats 3
							renderpresets.Save 0 (fPath + "\\" + dlg_main.changedMaxFile + ".corona_pass1.rps") presetCats
							appendFileInfo &vecFiles (fPath + "\\" + dlg_main.changedMaxFile + ".corona_pass1.rps") (dlg_main.changedMaxFile + ".corona_pass1.rps") tcopy:false
							settingsToWrite += "coronaanimation=1\n"

							--reset
							setProperty rend hdCache_file (oldgi_hdCache_file)
							setProperty rend hdCache_save (oldgi_hdCache_save)
							rend.shading_renderEngine = oldRenderer
							rend.progressive_timeLimit = oldprogressive_timeLimit
							rendSaveFile = oldrendSaveFile
							(maxOps.GetRenderElementMgr #Production).SetElementsActive oldElems

							setProperty rend hdCache_file (createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".cgd"))
							setProperty rend hdCache_save (false)
							setProperty rend hdCache_precalcMode (1)
						)
						METHOD_OBJ:
						(
							oldgi_hdCache_file = (getProperty rend hdCache_file)
							setProperty rend hdCache_file ("c:\\logs\\temp.cgd")
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							setProperty rend hdCache_save (false)
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							setProperty rend hdCache_precalcMode (0)
						)
						METHOD_LOC:
						(
							local giFile = (getProperty rend hdCache_file)
							getfilenametype
							local files = getFiles ((getFilenamePath giFile) + "*" + (getFilenameType giFile))
							for ppath in files do
							(
								local newpath = (filenameFromPath ppath)
								newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
								local newfile = ("tex/" + filenameFromPath ppath)
								appendFileInfo &vecFiles ppath newfile
							)
							oldgi_hdCache_file = (getProperty rend hdCache_file)
							setProperty rend hdCache_file (createTexPath dlg_main.m_userName (filenameFromPath giFile))
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							setProperty rend hdCache_save (false)
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							setProperty rend hdCache_precalcMode (1)
						)
					)
				)
			)
			else --Corona 6 and before
			(
				if isSingleFrameRender() then
				(
					if rend.shading_renderEngine == 2 then -- progressive
					(
						settingsToWrite += "singleframeMaxCoronaProgressive=1\n"
						settingsToWrite += "samplinglevel="+(getProgressivePasses()) as string+"\n"
						if getProgressiveThreshold() >0 then
							settingsToWrite += "noiselevel="+(getProgressiveThreshold()) as string+"\n"

						--merge script won't work if filename ends with digit, elements are already checked for that and raise an E
						rendOutputFilename = (pathConfig.removePathLeaf rendOutputFilename) + "\\"+ (removeTrailingDigits (getFilenameFile rendOutputFilename)) + (getFilenameType rendOutputFilename)

						rend.progressive_timeLimit = 0
						print rend.progressive_timeLimit
						rend.progressive_passLimit = ceil ((getProgressivePasses()) / distributedMachines as float)
						print rend.progressive_passLimit
						rend.lockSamplingPattern = false

						if findstring rend.stringOptions "bool shading.firstPassWithoutAa = false" == undefined then
							rend.stringOptions += "\r\nbool shading.firstPassWithoutAa = false"

						local filename = dlg_main.changedMaxFile + ".corona_progressive_post.ms"
						local filepath = (fPath + "\\" + filename)
						file = openFile filepath mode:"a"
						if file == undefined then
							file = createFile filepath

						if file != undefined then
						(
							local fileTxt = "
	fn at2CoronaPostRenderSkript =
	(
		local passes = CoronaRenderer.CoronaFp.getStatistic 0 as integer
		local framenumber = (currentTime as string)
		framenumber = substring framenumber 1 (framenumber.count-1)
		local filepath = rendOutputFilename + \".passinfo.\"+ framenumber + \".lock\"
		file = openFile filepath mode:\"w\"
		if file == undefined then
			file = createFile filepath
		format \"%\" passes to:file
		close file
	)

	at2CoronaPostRenderSkript()
	"

							format "%" fileTxt to:file

							callbacks.addscript #postRenderFrame id:#at2PostRender fileName:(createPath dlg_main.m_userName (dlg_main.changedMaxFile + ".corona_progressive_post.ms")) persistent:true
						)
						close file
						appendFileInfo &vecFiles filepath filename tcopy:false
					)
					else
					(
						settingsToWrite += "singleframeMaxCoronaNew2=1\n"

						setrendertype #region
						setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))
						setrendertype #crop
						setAllRegionRect (Box2 0 0 (renderWidth/dlg_main.m_slices) (renderHeight))

						rend.renderstamp_use = false
					)

					if rend.shading_primarySolver == 1 and (rend.shading_secondarySolver == 3 or rend.shading_secondarySolver == 4) then
					(
						if existsFile (getProperty rend hdCache_file) then
						(
							local filename = filenameFromPath (getProperty rend hdCache_file)
							appendFileInfo &vecFiles (getProperty rend hdCache_file) ("tex/" + filename)
							setProperty rend hdCache_save (false)
							setProperty rend hdCache_precalcMode (1)
							setProperty rend hdCache_file (createTexPath dlg_main.m_userName filename)

						)
						else
						(
							settingsToWrite += "hdcache=1\n"

							oldgi_hdCache_file = (getProperty rend hdCache_file)
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							oldRenderer = rend.shading_renderEngine
							local moldprogressive_timeLimit = rend.progressive_timeLimit	--use local variable so it gets reset correctly in postsave
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							oldrendSaveFile = rendSaveFile
							oldElems = (maxOps.GetRenderElementMgr #Production).GetElementsActive()

							setProperty rend hdCache_file (createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".cgd"))
							setProperty rend hdCache_save (true)
							setProperty rend hdCache_precalcMode (0)
							rend.shading_renderEngine = 2
							rend.progressive_timeLimit = 3000
							rendSaveFile = false
							(maxOps.GetRenderElementMgr #Production).SetElementsActive false

							local presetCats = (renderpresets.SaveCategories 0)
							deleteItem presetCats 2
							deleteItem presetCats 3
							local corona_prePresetPath = dlg_main.changedMaxFile + ".corona_single_pass1.rps"
							renderpresets.Save 0 (fPath + "\\" + corona_prePresetPath) presetCats
							appendFileInfo &vecFiles (fPath + "\\" + corona_prePresetPath) (corona_prePresetPath) tcopy:false

							--reset
							setProperty rend hdCache_save (false)
							setProperty rend hdCache_precalcMode (1)
							rend.shading_renderEngine = oldRenderer
							rend.progressive_timeLimit = moldprogressive_timeLimit
							rendSaveFile = oldrendSaveFile
							(maxOps.GetRenderElementMgr #Production).SetElementsActive oldElems
						)
					)


					if rend.denoise_filterType == 2 then
					(
						settingsToWrite += "coronaDenoise=1\n"
						settingsToWrite += "coronaDenoiseSensitivity="+rend.denoise_sensitivity as string+"\n"
						settingsToWrite += "coronaDenoiseBlendAmount="+rend.denoise_blendAmount as string+"\n"
						olddenoise_filterType = rend.denoise_filterType
						rend.denoise_filterType = 3
					)

				)
				else
				(
					-- check for Corona Volume Grid Filepaths are saved in an array
					-- array needs to be stored and changed
					-- moved up here because This got no string to convert to Filename before looping though the array

					volume_grids = getClassInstances CVolumeGrid

					for volume_grid in volume_grids do
					(
						local current_volume_grid_paths = (deepcopy ((getProperty volume_grid "filePaths") as Array))
						-- because f****** MaxScript keeps referencing that shitty CVolumeGrid ArrayParamater (which should be an Array), although it is a deepcopy.
						-- Converted to Array to make it work

						old_corona_volume_grid = OldCoronaVolumeGrids object: volume_grid file_paths: (deepcopy current_volume_grid_paths)

						append old_corona_volume_grids old_corona_volume_grid

						new_volume_grid_paths = #()

						for file_path in current_volume_grid_paths do
						(
							server_path = ("tex/" + (myFilenamefrompath file_path))
							appendFileInfo &vecFiles file_path server_path
							append new_volume_grid_paths server_path
						)
						if new_volume_grid_paths.count > 0 then
							setProperty volume_grid "filePaths" new_volume_grid_paths
					)


					if rend.shading_renderEngine == 2 then -- progressive
					(
						settingsToWrite += "animationMaxCoronaProgr=1\n"
						settingsToWrite += "samplinglevel="+(getProgressivePasses()) as string+"\n"
						if getProgressiveThreshold() >0 then
							settingsToWrite += "noiselevel="+(getProgressiveThreshold()) as string+"\n"

						local framecount = 1
						if rendTimeType == 2 then
							framecount = (animationRange.end.frame as integer) - (animationRange.start.frame as integer) + 1
						if rendTimeType == 3 then
							framecount = (rendEnd.frame as integer) - (rendStart.frame as integer) +1
						if rendTimeType == 1 then
							framecount = 1
						framecount = floor((framecount as float) / rendNthframe)
						if framecount < 1 then
							framecount = 1

						rend.progressive_timeLimit = 0
						rend.progressive_passLimit = getProgressivePasses()
						if corona_maxrp_dlg.hasNoiseOption() then
							rend.adaptivity_targetError = getProgressiveThreshold()
					--	rend.lockSamplingPattern = false
					)

					case corona_dlg.selectedMode of
					(
						METHOD_CAM:
						(
							--backup
							oldgi_hdCache_file = (getProperty rend hdCache_file)
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							oldRenderer = rend.shading_renderEngine
							oldprogressive_timeLimit = rend.progressive_timeLimit
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							oldrendSaveFile = rendSaveFile
							oldElems = (maxOps.GetRenderElementMgr #Production).GetElementsActive()

							setProperty rend hdCache_file (createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".cgd"))
							setProperty rend hdCache_save (true)
							rend.shading_renderEngine = 2
							rend.progressive_timeLimit = 3000
							setProperty rend hdCache_precalcMode (0)
							rendSaveFile = false
							(maxOps.GetRenderElementMgr #Production).SetElementsActive false

							local presetCats = (renderpresets.SaveCategories 0)
							deleteItem presetCats 2
							deleteItem presetCats 3
							renderpresets.Save 0 (fPath + "\\" + dlg_main.changedMaxFile + ".corona_pass1.rps") presetCats
							appendFileInfo &vecFiles (fPath + "\\" + dlg_main.changedMaxFile + ".corona_pass1.rps") (dlg_main.changedMaxFile + ".corona_pass1.rps") tcopy:false
							settingsToWrite += "coronaanimation=1\n"

							--reset
							setProperty rend hdCache_file (oldgi_hdCache_file)
							setProperty rend hdCache_save (oldgi_hdCache_save)
							rend.shading_renderEngine = oldRenderer
							rend.progressive_timeLimit = oldprogressive_timeLimit
							rendSaveFile = oldrendSaveFile
							(maxOps.GetRenderElementMgr #Production).SetElementsActive oldElems

							setProperty rend hdCache_file (createTemprenderPath dlg_main.m_userName (dlg_main.changedMaxFile + ".cgd"))
							setProperty rend hdCache_save (false)
							setProperty rend hdCache_precalcMode (1)
						)
						METHOD_OBJ:
						(
							oldgi_hdCache_file = (getProperty rend hdCache_file)
							setProperty rend hdCache_file ("c:\\logs\\temp.cgd")
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							setProperty rend hdCache_save (false)
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							setProperty rend hdCache_precalcMode (0)
						)
						METHOD_LOC:
						(
							local giFile = (getProperty rend hdCache_file)
							getfilenametype
							local files = getFiles ((getFilenamePath giFile) + "*" + (getFilenameType giFile))
							for ppath in files do
							(
								local newpath = (filenameFromPath ppath)
								newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
								local newfile = ("tex/" + filenameFromPath ppath)
								appendFileInfo &vecFiles ppath newfile
							)
							oldgi_hdCache_file = (getProperty rend hdCache_file)
							setProperty rend hdCache_file (createTexPath dlg_main.m_userName (filenameFromPath giFile))
							oldgi_hdCache_save = (getProperty rend hdCache_save)
							setProperty rend hdCache_save (false)
							oldgi_hdCache_precalcMode = (getProperty rend hdCache_precalcMode)
							setProperty rend hdCache_precalcMode (1)
						)
					)
				)
			)

			if hasProperty rend "colorMap_lut_path" then
			(
				if rend.colorMap_lut_enable then
				(
					if rend.colorMap_lut_path !=undefined and existsFile rend.colorMap_lut_path then
					(
						appendFileInfo &vecFiles rend.colorMap_lut_path ("tex/" + filenameFromPath rend.colorMap_lut_path)
						oldcolorMap_lut_path = rend.colorMap_lut_path
						rend.colorMap_lut_path = createTexPath dlg_main.m_userName (filenameFromPath rend.colorMap_lut_path)
					)
				)
			)
			--PhoenixFD
			try
			(
				local fds = getClassInstancesSave PhoenixSimulator
				join fds (getClassInstancesSave FireSmokeSim)
				join fds (getClassInstancesSave LiquidSim)
				local found = false
				oldPhoenixSimulatorPaths = #()
				oldPhoenixSimulatorOutputPaths = #()
				for fd in fds do
				(
					local f = parsePhoenixPath fd fd.rendinput
					local parsedF = f
					f = replaceAll f "#" "*"
					local files = getFiles f
					for fp in files do
					(
						local newpath = (filenameFromPath fp)
						newpath = (pathConfig.appendPath (pathConfig.appendPath fPath "tex") newpath)
						local newfile = ("tex/" + filenameFromPath fp)
						appendFileInfo &vecFiles fp newfile
					)
					append oldPhoenixSimulatorPaths fd.rendinput
					append oldPhoenixSimulatorOutputPaths fd.simoutput
					fd.rendinput = createTexPath dlg_main.m_userName (filenameFromPath parsedF)
					fd.simoutput = ""
				)
			)
			catch()
		)
	),
	fn postSave zip =
	(
		local version = getCoronaIntVersion()
		local coronaver = CoronaRenderer.CoronaFp.getVersionMajorNumber()
		if version >= 60000 or coronaver >= 7 then
		(
			hdCache_file = "gi_giCache_file"
			hdCache_save = "gi_giCache_save"
			hdCache_precalcMode = "gi_giCache_precalcMode"
		)

		rend = renderers.production
		if classof rend == CoronaRenderer then
		(
			if not hasProperty rend "gi_hdCache_file" and not hasProperty rend "gi_uhdCache_file" and not hasProperty rend "gi_giCache_file" then --this is a older corona version
			(
				return true
			)
			callbacks.removeScripts #postRenderFrame id:#at2PostRender
			rend.dr_enable = oldDistributed

			if old_check_on_lan_during_render != undefined then
				rend.dr_searchDuringRender = old_check_on_lan_during_render

			if oldgi_hdCache_file != undefined then
				setProperty rend hdCache_file (oldgi_hdCache_file)
			setProperty rend hdCache_save (oldgi_hdCache_save)
			setProperty rend hdCache_precalcMode (oldgi_hdCache_precalcMode)
			setrendertype oldRenderType
			rend.progressive_timeLimit = oldprogressive_timeLimit
			rend.progressive_passLimit = oldprogressive_passLimit
			rend.lockSamplingPattern = oldlockSamplingPattern
			renderWidth = oldXres
			renderHeight = oldYres
			try(rend.vfb_autosave_enable = oldvfb_autosave_enable)catch()
			rend.renderstamp_use = oldrenderstamp_use
			if oldcolorMap_lut_path != "" then
				rend.colorMap_lut_path = oldcolorMap_lut_path

			if olddenoise_filterType != undefined then
				rend.denoise_filterType = olddenoise_filterType

			if oldstringOptions != "" then
				rend.stringOptions = oldstringOptions

			if old_corona_volume_grids != undefined and old_corona_volume_grids.count > 0 then
			(
				for volume_grid in old_corona_volume_grids do
				(
					setProperty volume_grid.object "filePaths" volume_grid.file_paths
				)
			)
			---Phoenix
			try
				(
					local fds = getClassInstancesSave PhoenixSimulator
					join fds (getClassInstancesSave FireSmokeSim)
					join fds (getClassInstancesSave LiquidSim)
					i=1
					for fd in fds do
					(
						fd.rendinput = oldPhoenixSimulatorPaths[i]
						fd.simoutput = oldPhoenixSimulatorOutputPaths[i]
						i=i+1
					)
				)
				catch()
		)
	)
)

struct ValPlugins
(
	PLUGIN_CHECK = 1,
	is_renderer_validator = false,

	fn getName name:"" =
	(
		name = "Plugins";
	),
	fn getIdentifier =
	(
		return #()
	),

	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
--	*.dlh OR *.dlm OR *.dlo OR *.dlt OR *.dlu OR *.gup OR *.dlc OR *.dlr OR *.dlk OR *.dlv
		index = 0;

		local plugs = fileProperties.getItems "Used Plug-Ins"
		if plugs == undefined then
			return 0
		local plugsfile = openFile (dlg_main.my_path + "plugs.cfg") mode:"r"
		if plugsfile != undefined then
		(
			local supportedplugs = #()
			local toAdd = false
			local delim = ";"
			local ver = delim
			local maxver = maxVersion()
			local readFurther = true

			if(maxver[1] < 10000) then
				ver += "9"
			else if ((maxver[1] >= 10000) AND (maxver[1] < 11000)) then
				ver += "2008"
			else if ((maxver[1] >= 11000) AND (maxver[1] < 12000)) then
				ver += "2009"
			else if ((maxver[1] >= 12000) AND (maxver[1] < 13000)) then
				ver += "2010"
			else if ((maxver[1] >= 13000) AND (maxver[1] < 14000)) then
				ver += "2011"
			else if ((maxver[1] >= 14000) AND (maxver[1] < 14900)) then
				ver += "2012"
			else if ((maxver[1] >= 15000) AND (maxver[1] < 15900)) then
				ver += "2013"
			else if ((maxver[1] >= 16000) AND (maxver[1] < 16900)) then
				ver += "2014"
			else if ((maxver[1] >= 17000) AND (maxver[1] < 17900)) then
				ver += "2015"
			else if ((maxver[1] >= 18000) AND (maxver[1] < 18900)) then
				ver += "2016"
			else if ((maxver[1] >= 19000) AND (maxver[1] < 19900)) then
				ver += "2017"
			else if ((maxver[1] >= 20000) AND (maxver[1] < 20900)) then
				ver += "2018"
			else if ((maxver[1] >= 21000) AND (maxver[1] < 21900)) then
				ver += "2019"
			else if ((maxver[1] >= 22000) AND (maxver[1] < 22900)) then
				ver += "2020"
			else if ((maxver[1] >= 23000) AND (maxver[1] < 23900)) then
				ver += "2021"
			else if ((maxver[1] >= 24000) AND (maxver[1] < 24900)) then
				ver += "2022"
			else if (maxver[1] >= 25000) then
				ver += "2023"

			if(maxver[1] < 14900) then
			(
				if(is64bitApplication() == TRUE) then
					ver += "_64"
				else
					ver += "_32"
			)

			while NOT (eof plugsfile) AND readFurther do
			(
				local stLine = (readline plugsfile)

				if(stLine == ver) then
				(
					toAdd = true
					continue
				)

				if(toAdd AND (stLine[1] == delim)) then
					readFurther = false

				if(toAdd AND stLine.count > 0 AND readFurther) then
				(
					append supportedplugs (myToLower stLine)
				)
			)

			if supportedplugs.count == 0 then
				append resultList (tr id:7003 index:index validator:val severity:2 message:("Used Plugins could not be checked, maybe your 3ds Max version is not (yet) supported!"))
			else
			(
				for i = 1 to plugs.count do
				(
					if findItem supportedplugs (myToLower plugs[i]) ==0 then
						append resultList (tr id:7002 index:index validator:val severity:2 message:("Plugin: Render Farm Application doesn't know about " + plugs[i] + ". Remove from scene or contact Render Farm Application for installation.") flagMoreInfos:true type:ONLINE_FAQ)

					if findString plugs[i] "multitexture" != undefined then
					(
						if classof renderers.production == vray or classof renderers.production == vrayrt then
							append resultList (tr id:7004 index:index validator:val severity:1 message:("Make sure you use MultiTexture version 2 ! Old versions do not render correctly!"))
					)
				)
			)
			close plugsfile
		)
		else
			append resultList (tr id:7003 index:index validator:val severity:2 message:("plugs.cfg could not be found, please reinstall plugin from Render Farm Application Desk!"))
	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValPlugins!"
		case result.type of
		(
		ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
		PLUGIN_CHECK:
			(
				st = "Plugins can only be checked if you have saved your .max file.
If you already removed this plugin please save your scene file and hit \"Smartcheck\" again."
				messagebox st title:"Render Farm Application"
			)
		)
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

struct ValOctane
(
	OCTANE_1 = 1,

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Octane";
	),
	fn getIdentifier =
	(
		return #(Octane_Render, Octane_Render_Demo)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == Octane_Render or classof rend == Octane_Render_Demo then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			-- append resultList (tr id:15001 index:index validator:val severity:2 message:"Octane is not yet supported, stay tuned!")
		)

	),

	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValOctane!"
		case result.type of
		(
			ONLINE_FAQ:
			(
				goToOnlineFaq result.id
				return 0
			)
			OCTANE_1:
			(
				st="";
			)
		)
		messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == Octane_Render or classof rend == Octane_Render_Demo then
		(

		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == Octane_Render or classof rend == Octane_Render_Demo then
		(

		)
	)
)

struct ValA360
(
	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "A360";
	),

	fn getIdentifier =
	(
		return #(A360_Cloud_Rendering)
	),

	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == A360_Cloud_Rendering then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			append resultList (tr id:1001 index:index validator:val severity:2 message:"A360 not yet supported on Render Farm Application")

		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

-- TODO compared to Maya:
/*



*/
struct ValArnold
(
	is_renderer_validator = true,
	abort_on_license_fail = false,

	fn getName name:"" =
	(
		name = "Arnold";
	),
	fn getIdentifier =
	(
		return #(Arnold)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn get_arnold_license_count arnold_license_file  =
	(
		return ""
	),

	fn test resultList val fastCheck =
	(
		index = 0

		rend = renderers.production
		if classof rend == Arnold then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))

			append resultList (tr id:15001 index:index validator:val severity:1 message:"Arnold Renderer is currently in beta. Please contact our support if you like to know more. Stay tuned.")
 
			
			arnold_license_file = pathConfig.appendPath farminizerDialog.m_defaultPath "shadows.txt"
			if (getfiles arnold_license_file).count < 1 then
			(
				limit = 100 
			)
			else
			( 
				limit = 100 
			)
 

			if (maxVersion())[1] < 20000 then
			(
				append resultList (tr id:15001 index:index validator:val severity:2 message:"Arnold Renderer needs 3ds Max 2018 or higher")
				return false
			)

			if getNumFrames() < 0 then
				append resultList (tr id:15001 index:index validator:val severity:2 message:"Higher Endframe number than Startframe number is not allowed.")

			if isSingleFrameRender() then
				append resultList (tr id:15001 index:index validator:val severity:2 message:"Distributed rendering with Arnold Renderer is not supported yet.")

			if rend.ignore_textures == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Textures is activated.")

			if rend.ignore_shaders == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Shaders is activated.")

			if rend.ignore_atmosphere == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Atmosphere is activated.")

			if rend.ignore_lights == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Lights is activated.")

			if rend.ignore_shadows == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Shadows is activated.")

			if rend.ignore_subdivision == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Subdivision is activated.")

			if rend.ignore_bump == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Bump is activated.")

			if rend.ignore_smoothing == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Normal Smoothing is activated.")

			if rend.ignore_motion_blur == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Motion Blur is activated.")

			if rend.ignore_dof == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Depth of Field is activated.")

			if rend.ignore_sss == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Sub-Surface Scattering is activated.")

			if hasproperty rend "ignore_operators" and rend.ignore_operators == true then
				append resultList (tr id:15001 index:index validator:val severity:1 message:"Ignore Operators is activated.")

			-- Add stand ins --> See Maya Farminizer
			-- iesFiles = cmds.ls(et="aiPhotometricLight")

			photometric_light = 7  -- $ArnoldLight001.shapeType
			-- Function check scene lights

			-- aiImageFiles = cmds.ls(et="aiImage")
			-- aiVolumes = cmds.ls(et="aiVolume")

		)

	),


	fn furtherAction result =
	(
		local resolved = false
		st = "Message from ValArnold!"
		case result.type of
		(
		)
		messagebox st title:"Render Farm Application"
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
		rend = renderers.production
		if classof rend == Arnold then
		(
			-- to avoid watermarks in render activate fail on license fail:
			--rend.abort_on_license_fail = true
		)
	),
	fn postSave zip =
	(
		rend = renderers.production
		if classof rend == Arnold then
		(
			--rend.abort_on_license_fail = abort_on_license_fail
		)
	)
)

struct ValArt
(

	is_renderer_validator = true,

	fn getName name:"" =
	(
		name = "Art";
	),
	fn getIdentifier =
	(
		return #(ART_Renderer)
	),
	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
		index = 0;

		rend = renderers.production
		if classof rend == ART_Renderer then
		(
			append resultList (tr id:0 index:index validator:val severity:0 message:("Checking " + val.getName()))
			if isSingleFrameRender() then
				append resultList (tr id:1001 index:index validator:val severity:2 message:"Art still frame render not yet supported on Render Farm Application")

		)

		index = index + 1;

		-- ...
	),

	fn furtherAction result =
	(
		local resolved = false
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

-- Just a placeholder to get the name in the result list
struct ValPreUpload
(

	is_renderer_validator = false,

	fn getName name:"" =
	(
		name = "Pre-Upload";
	),
	fn getIdentifier =
	(
		return #()
	),

	fn preCheckStandalone =
	(),
	fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
	(),

	fn test resultList val fastCheck =
	(
	),

	fn furtherAction result =
	(
		local resolved = false
		return resolved
	),

	fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
	(
	),
	fn postSave zip =
	(
	)
)

global skyThr

struct BgThread
(
	threadObj = undefined,
	timerObj = undefined,
	knownPaths = #(),
	newPaths = #()
)

struct FarmRenderWorkFlow
(
	running = false,
	texFolder = "",
	defaultPath = "",
	maxFile = "",
	

	fn BackgroundThreadFunction sender e =
	(	
		global createSkyf
		local run = true
		while run do
		(
			try
			(
				if skyThr == undefined or skyThr.threadObj==undefined or skyThr.threadObj.CancellationPending then 
					run = false
				else 
				(
					if skyThr.newPaths.count > 0 then
					(
						makeDir createSkyf.texFolder all:true
						local elem = skyThr.newPaths[skyThr.newPaths.count]
						deleteItem skyThr.newPaths skyThr.newPaths.count
						
						append skyThr.knownPaths elem
						local dest = pathConfig.appendPath createSkyf.texFolder (filenameFromPath elem)
						local src = mapPaths.getFullFilePath elem
						if not existsFile dest and existsFile src then
						(
							if (getfilenametype src) == ".ifl" then
							(
								local iflFilenames = getIflFilenames  (mapPaths.getFullFilePath src)
								for f in iflFilenames do
								(
									local filepath = findIflPath src f
									if filepath != undefined then
									(
										local filenametocopy = filenameFromPath filepath
										local mp = pathConfig.appendPath createSkyf.texFolder filenametocopy
										FarmRenderWorkFlow.handleFile filepath mp
									)
								)
							)
							FarmRenderWorkFlow.handleFile src dest
						)
					)
					else
						sleep 1
				)
			)
			catch
			(
				format "BackgroundThreadFunction*** % ***\n" (getCurrentException())
			)
		)		
	),
	
	fn handleFile src dest =
	(
		global createSkyf
		format "file found: %\n"  src
		local p = pathConfig.appendPath (createSkyf.defaultPath) "at2_reb_livefiles.txt"

		local liveFile = openFile p mode:"a"
		format "%|/tex\n" src to:liveFile
		close liveFile

	--	if dlg_main.copyTexFiles then
	--		copyFile src dest
	),

	fn at2Timer2 =
	(
		global createSkyf
		if createSkyf.maxFile != maxFileName then
		(
			createSkyf.stopTimer()
			return 0
		)
		skyThr.timerObj.stop()
		local vecTex = ValTexture.findAllTextures()

		for t in vecTex do
		(
			--local filePath = filenameFromPath t.filename
			local filePath = t.filename
			if findItem skyThr.knownPaths filePath == 0 and findItem skyThr.newPaths filePath == 0 then
			(
				append skyThr.newPaths filePath
			)
		)
		skyThr.timerObj.start()
	),

	fn startTimer =
	(
		maxFile = maxFileName
		if skyThr == undefined then
		(
			skyThr = BgThread()
			skyThr.threadObj = dotnetobject "CSharpUtilities.SynchronizingBackgroundWorker"
			skyThr.threadObj.WorkerSupportsCancellation = true		
			dotNet.addEventHandler skyThr.threadObj "DoWork" BackgroundThreadFunction
			if not skyThr.threadObj.IsBusy then 
				skyThr.threadObj.RunWorkerAsync()

			skyThr.timerObj = dotNetObject "System.Windows.Forms.Timer"
			dotnet.addEventHandler skyThr.timerObj "tick" at2Timer2
			skyThr.timerObj.interval = 10000
			skyThr.timerObj.start()
			running = true
		)
	),
	
	fn stopTimer =
	(
		if skyThr != undefined then
		(
			if skyThr.threadObj.IsBusy then 
				skyThr.threadObj.CancelAsync()
			skyThr.threadObj=undefined
			skyThr.timerObj.stop()
			skyThr.timerObj = undefined
			skyThr=undefined
			running = false
		)
	)
)

	vecTests = #()
	v = ValGeneral()
	append vecTests v
	v = ValTexture()
	append vecTests v
	v = ValScanline()
	append vecTests v
	v = ValMental()
	append vecTests v
	v = ValIray()
	append vecTests v
	v = ValIrayPlus()
	append vecTests v
	v = ValRedshift()
	append vecTests v
	v = ValCycles()
	append vecTests v
	v = ValFstorm()
	append vecTests v
	v = ValQuicksilver()
	append vecTests v
	v = ValVray()
	append vecTests v
	v = ValFR()
	append vecTests v
	v = ValVue()
	append vecTests v
	v = ValMaxwell()
	append vecTests v
	v = ValBrazil()
	append vecTests v
	v = ValCorona()
	append vecTests v
	v = ValOctane()
	append vecTests v
	v = ValA360()
	append vecTests v
	v = ValArt()
	append vecTests v
	v = ValArnold()
	append vecTests v
	v = ValRenderSettings()
	append vecTests v
	v = ValPlugins()
	append vecTests v
	v = ValPreUpload()
	append vecTests v
	vecResults = #()

	listIndex = #()
	settings = #()

	global createSkyf
	if createSkyf == undefined then
		createSkyf = FarmRenderWorkFlow()

	fn isAllValid =
	(
		local bValid = true

		if vecResults == undefined OR vecResults.count == 0 then
			bValid = false

		if bValid then
		(
			for i in vecResults do
				bValid = bValid AND i.severity != 2
		)
		return bValid
	)

	fn DisplayResults listbox =
	(
		list = #();
		listIndex = #();
		txtLine = "";
		sev = 0;
		sev_text = #("Info", "Warning", "Error", "Resolved", "", "", "", "");
		sev_sep  = #("            ", "     ", "           ", "    ", "", "", "", "");
		sev_filter = 0;
		grp = "";
		pre_grp = "";
		hint = "";
		bContent = false;

		sev_filter = 0

		for i = 1 to vecResults.count do
		(
			if vecResults[i].validator != undefined then
			(
				grp = vecResults[i].validator.getName()
				if grp != pre_grp then
				(
					if i > 1 then
						append list ""

					append list grp
					pre_grp = grp
				)
			)

			sev = vecResults[i].severity
			if sev == sev_filter OR sev_filter == 0 then
			(
				if vecResults[i].type != 0 then
					hint = " (click here...)"
				else
					hint = ""

				txtLine = "      " + sev_text[sev+1] + sev_sep[sev+1] + vecResults[i].message + hint
				append list txtLine;
				listIndex[list.count] = i;

				bContent = true;
			)
		)

		if not bContent AND vecResults.count > 0 then
		(
			append list "                  No Errors"
		)

		listbox.items = list;
	)

	global gValStatus = undefined

	struct ValStatus
	(
		statusCostEstimationFinished=0,
		statusExported=1,

		fn getName name:"" =
		(
			name = "Status";
		),
		fn preCheckStandalone =
		(),
		fn standaloneExport resultList val fPath:"" &settingsToWrite:"" &vecFiles:"" =
		(),
		fn test resultList val fastCheck =
		(),

		fn furtherAction result =
		(
			local resolved = false
			case result.type of
			(
				statusCostEstimationFinished:
					farminizerDialog.createOpenCCFile()
				statusExported:
					farminizerDialog.createOpenCCFile() 
			)
			return resolved
		),

		fn prepareSave ZipFile fPath:"" &settingsToWrite:"" &vecFiles:""=
		(),
		fn postSave zip =
		(),

		fn addStatusMessageToList statusId =
		(
			global gValStatus
			case statusId of
			(
				statusCostEstimationFinished:
				(
					append vecResults (tr id:statusId index:0 validator:gValStatus severity:0 message:"Preparing Render Cost Estimation.")
					append vecResults (tr id:statusId index:0 validator:gValStatus severity:0 message:"Render Cost Estimation started. You will receive an email as soon as the estimation is ready." flagMoreInfos:true type:statusId)
					--append vecResults (tr id:statusId index:0 validator:gValStatus severity:0 message:"You can also monitor the estimation process in the ControlCenter" flagMoreInfos:true type:statusId)
				)
				statusExported:
				(
					append vecResults (tr id:statusId index:0 validator:gValStatus severity:0 message:"Exporting Job.")
					append vecResults (tr id:statusId index:0 validator:gValStatus severity:0 message:"Job upload started." flagMoreInfos:true type:statusId)
					--append vecResults (tr id:statusId index:0 validator:gValStatus severity:0 message:"You can also monitor the rendering in the ControlCenter" flagMoreInfos:true type:statusId)
				)
			)
			DisplayResults dlg_main.lstMain
		)
	)
	global gValStatus = ValStatus()

	fn DoExportFolder fname &success =
	(
		success = false

		if fname != undefined then
		(
			try
			(
				wasRunning = false
				if dlg_main.liveExport and createSkyf.running then
				(
					createSkyf.stopTimer()
					wasRunning = true
				)
				try
				(
				dotnet.loadAssembly   (dlg_main.my_path + "Ionic.Utils.Zip.dll")
				)
				catch
				(
					format "Error on loading \"Ionic.Utils.Zip.dll\""
					format "farm.ms:3 *** % ***\n" (getCurrentException())
					messagebox "Error on loading \"Ionic.Utils.Zip.dll\": file not found." title:"Error"
					return false
				)

				setWaitCursor()

				local maxFile = dlg_main.changedMaxFile

				maxpath = pathConfig.appendPath fname maxFile

				stSettingsToWrite = "[region]\n"
				if FarmRenderSetting.autostart.checked then
					stSettingsToWrite += "autostart=1\n"
				if FarmRenderSetting.prio.selection > 1 then
					stSettingsToWrite += "prio="+(FarmRenderSetting.prio.selection as string)+"\n"
				-- Preparing to get Batchrendername into RQ for sending this to Deadline
				if skyatchRender.batchRender.checked then
					stSettingsToWrite += "batch=\n"

				if skyNotify.sendMail.checked then
				(
					if skyNotify.notifyStart.checked then
						stSettingsToWrite += "notifyStart=1\n"
					if skyNotify.notifyComplete.checked then
						stSettingsToWrite += "notifyComplete=1\n"
				)
				vecFiles = #()
				try(macros.run "Medit Tools" "condense_medit_slots")catch()
				dlg_main.progressStart()
				i=0
				for val in vecTests do
				(
					st = ""
					validator_identifier = val.getIdentifier()
					if findItem validator_identifier (classof renderers.production) >= 1 or val.is_renderer_validator == false then
					(
						pushPrompt("Preparing: " + val.getName() + "...")
						dlg_main.progressUpdate progress:(100.0/vecTests.count*i) msg:("Preparing: " + val.getName() + "...")
						redrawViews()
						val.prepareSave undefined fPath:fname settingsToWrite:&st vecFiles:&vecFiles
					)
					if st != "" then
						stSettingsToWrite += st + "\n"
					popPrompt()
					i=i+1
				)
				dlg_main.progressEnd msg:"Exporting Render Farm Application file..."

				if dlg_main.isVrsceneExport or dlg_main.isMiExport then
				(
					for val in vecTests do
					(
						validator_identifier = val.getIdentifier()
						if findItem validator_identifier (classof renderers.production) >= 1 or val.is_renderer_validator == false then
						(
							val.standaloneExport vecResults val fPath:fname settingsToWrite:&stSettingsToWrite vecFiles:&vecFiles
						)
					)



					if not isAllValid() then
					(
						messagebox "This project could not be exported, please check the displayed errors." title:"Render Farm Application"
						DisplayResults dlg_main.lstMain
						for val in vecTests do
						(
							validator_identifier = val.getIdentifier()
							if findItem (classof renderers.production) >= 1 or val.is_renderer_validator == false then
							(
								pushPrompt("Post: " + val.getName() + "...")
								val.postSave false
								popPrompt()
							)
						)
						success = false
						return false
					)
				)


				GeneratePreview (maxpath + ".jpg")

				-- write settings file
				settingspath = (maxpath as string) + ".cfg"

				pushPrompt "Exporting Render Farm Application file..."

				stSettingsToWrite += "[files]\n"
				i = 0
				for stp in vecFiles do
				(
					stSettingsToWrite += "path" + (i as string) + "=" + stp.serverPath + "\n"
					stSettingsToWrite += "pathlocal" + (i as string) + "=" + stp.localPath + "\n"
					stSettingsToWrite += "pathsize" + (i as string) + "=" + (getInteger64String stp.fileSize) + "\n"
					if stp.notFoundNormally then
						stSettingsToWrite += "pathnotfoundnormally" + (i as string) + "=1\n"
					if dlg_main.copyTexFiles and stp.toCopy then
						copyFile stp.localPath (pathConfig.appendPath fname stp.serverPath)
					i = i+1
				)
				stSettingsToWrite += "paths=" + (i as string) + "\n"

				b = saveMaxFile maxpath clearNeedSaveFlag:false useNewFile:false quiet:true
				if b == false then
					print ("could not write " + maxpath)

				stSettingsToWrite += "[checksum]\ncheck=" +(calcMd5 maxpath)+ "\n"
				stSettingsToWrite += "scenesize=" + (getInteger64String (getFileSize maxpath)) + "\n"
				f = createFile settingspath
				if f != undefined then
					format "%" stSettingsToWrite to:f
				close f

				for val in vecTests do
				(
					validator_identifier = val.getIdentifier()
					if findItem validator_identifier (classof renderers.production) >= 1 or val.is_renderer_validator == false then
					(
						pushPrompt("Post: " + val.getName() + "...")
						val.postSave false
						popPrompt()
					)
				)
				try(macros.run "Medit Tools" "restore_medit_slots")catch()
				
				popPrompt()
				setArrowCursor()

				local refreshTxtPath = pathConfig.appendPath (dlg_main.m_defaultPath) "shadows.txt"

				--workaround for max 2012 maxscript problem that files are not closed properly, and so the manager can't delete it
				if (maxversion())[1] >= 14000 then
				(
					HiddenDOSCommand ("echo a > \""+refreshTxtPath+"\"")
				)
				else
				(
					local refreshFile = openFile refreshTxtPath mode:"w"
					close refreshFile
				)

				dlg_main.isDistributedConfirmed = false
				irayGPUselected = false
				vrayGPUselected = false
				redshiftGPUselected = false
				cyclesGPUselected = false
				fstormGPUselected = false
				success = true
				vec_results_index = vecResults.count+1
				if dlg_main.estimateRenderpoints then
				(
					dlg_main.progressEnd msg:"Success! Your job is uploading and rendering a cost estimation."
					gValStatus.addStatusMessageToList gValStatus.statusCostEstimationFinished
					append vecResults (tr id:0 index:vec_results_index validator:gValStatus severity:0 message:"Success! Your job is uploading and rendering a cost estimation.")
				)
				else
				(
					dlg_main.progressEnd msg:"Success! Your job is uploading."
					gValStatus.addStatusMessageToList gValStatus.statusExported
					append vecResults (tr id:0 index:vec_results_index validator:gValStatus severity:0 message:"Success! Your job is uploading.")
				)
				-- deactivate Button
				dlg_main.submitToSky.enabled = false

				DisplayResults dlg_main.lstMain

				scene_upload_history_path = pathConfig.appendPath (dlg_main.m_defaultPath) (pathConfig.appendPath (dlg_main.m_userName) ((getFilenameFile maxFileName) + "_upload_history.txt"))

				if existsFile scene_upload_history_path then
					deleteFile scene_upload_history_path

				if dlg_main.liveExport and wasRunning then
					createSkyf.startTimer()
			)
			catch
			(
				format "farm.ms:4*** % ***\n*** % ***\n" (getCurrentException()) (getCurrentExceptionStackTrace())
				setArrowCursor()
				success = false
			)
		)
	)

	fn ActionStart &bValid fastCheck:true resolved:undefined =
	(
		--hwnd = findRenderDialogElement "Atmospherics"
		--for a in (UIAccessor.GetChildWindows (UIAccessor.GetParentWindow hwnd)) do print (a as string + " " + UIAccessor.GetWindowText  a)
		--print hwnd as string
		--b = UIAccessor.SendMessage hwnd 0x00F0 0 0 --BM_GETCHECK
		--print b as string
		
		dlg_main.fastCheck = fastCheck

		save_required = getSaveRequired()

		setWaitCursor()
		pushPrompt "Running Render Farm Application validation..."
		vecResults = #()
		renderSceneDialog.commit()
		renderSceneDialog.close()

		append vecResults (tr id:0 index:0 validator:ValGeneral severity:0 message:"Running Render Farm Application validation...")

		if objects.count==0 then
		(
			append vecResults (tr id:0 index:0 validator:ValGeneral severity:2 message:"Your scene is empty. Nothing to check.")
			DisplayResults dlg_main.lstMain;
			return false
		)

		if onlyOneFrame() then
		(
			dlg_main.isDistributedConfirmed = FarmRenderSetting.distributed.checked
			if isSingleFrameRender() then
				append vecResults (tr id:1 index:0 validator:undefined severity:0 message:"Your frame will be rendered distributed on the farm.")
			else
				append vecResults (tr id:2 index:0 validator:undefined severity:0 message:"Your frame will be rendered on a single PC on the farm.")
		)
		else
		(
			dlg_main.isDistributedConfirmed = false
		)
		dlg_main.isVrsceneExport = false
		dlg_main.isMiExport = false

		DisplayResults dlg_main.lstMain;

		conf = getConfigFileContent()
		if conf == undefined then
			append vecResults (tr id:3 index:0 validator:undefined severity:2 message:"clientsettings.cfg could not be found, please reinstall plugin from Drop!")
		else
		(
			dlg_main.m_userName = conf[1]
			dlg_main.m_defaultPath = conf[2]
			dlg_main.m_managerPath = conf[3]
			dlg_main.m_PluginVersion = conf[4]
			dlg_main.m_CpuData = conf[5]
			dlg_main.changedMaxFile = getChangedMaxFilename dest:(pathConfig.appendPath dlg_main.m_defaultPath dlg_main.m_userName)
			createSkyf.texFolder = pathConfig.appendPath (pathConfig.appendPath dlg_main.m_defaultPath dlg_main.m_userName) "tex"
			createSkyf.defaultPath = dlg_main.m_defaultPath

			if(dlg_main.m_userName == "") then
			(
				append vecResults (tr id:4 index:0 validator:undefined severity:2 message:"You are not logged in correcly, please login from Drop first!")
			)
			else
			(
				FarmRenderAccount.username.text = "User: " + dlg_main.m_userName
				FarmRenderAccount.renderpoints.text = "RenderPoints: " + (farminizerDialog.getRenderpoints())
			)
/*
			local versionFile = openFile (pathConfig.appendPath (pathConfig.removePathLeaf dlg_main.m_managerPath)  "version.txt") mode:"r"
			local stManagerVersion = ""
			if versionFile != undefined then
			(
				try
				(
					stManagerVersion = readline versionFile
					close versionFile
				)
				catch()
			)
			if stManagerVersion != dlg_main.m_PluginVersion then
				append vecResults (tr id:5 index:0 validator:undefined severity:2 message:"Your plugin is outdated, please close your application and reinstall plugin from Drop!")
*/
		)

		scene_file_name = maxFileName
		if scene_file_name.count <= 7 then
			append vecResults (tr id:5 index:0 validator:undefined severity:2 message:"Your scene filename has to be longer than 3 characters(not including the extension \".max\")")

		for validator in vecTests do
		(
			validator_identifier = validator.getIdentifier()
			if findItem validator_identifier (classof renderers.production) >= 1 or validator.is_renderer_validator == false then
			(
				validator.preCheckStandalone()
			)

		)

		--dlg_main.progressStart()
		i=0
		for validator in vecTests do
		(
			validator_identifier = validator.getIdentifier()
			if findItem validator_identifier (classof renderers.production) >= 1 or validator.is_renderer_validator == false then
			(
				dlg_main.progressUpdate progress:(100.0/vecTests.count*i) msg:("Checking: " + validator.getName() + "...")
				pushPrompt("Checking: " + validator.getName() + "...")
				validator.test vecResults validator dlg_main.fastCheck
			)

			popPrompt()
			redrawViews()
			i=i+1
			DisplayResults dlg_main.lstMain;
		)
		--dlg_main.progressEnd()

		if vecResults.count == 0 then
		(
			append vecResults (tr id:7 index:0 validator:undefined severity:0 message:"No errors or warnings found")
		)

		append vecResults (tr id:(vecResults.count+2) index:0 validator:ValGeneral severity:0 message:"SceneCheck Finished")

		bValid = isAllValid()
		-- bValid = bValid AND NOT dlg_main.fastCheck
--		dlg_main.btnCalculateCosts.enabled = true
		DisplayResults dlg_main.lstMain;
		--popPrompt()
		--setArrowCursor()
	--	setFocus dlg_main
	)

	fn ActionExport estimation:false =
	(
		if objects.count==0 then
		(
			vecResults = #()
			append vecResults (tr id:0 index:0 validator:ValGeneral severity:2 message:"Your scene is empty. Nothing to check.")
			DisplayResults dlg_main.lstMain;
			return false
		)

		valid = false
		dlg_main.show()
		dlg_main.estimateRenderpoints = estimation

		dlg_main.fastCheck = true

		if objects.count==0 then
		(
			dlg_main.submitToSky.enabled = false
			return false
		)

		ActionStart &valid fastCheck:dlg_main.fastCheck

		if objects.count > 0 then
		(
			dlg_main.submitToSky.visible = true
			dlg_main.submitToSky.enabled = true
		)


	)

	fn ActionSaveLog =
	(
		fname = getSaveFileName caption:"Render Farm Application Logfile" types:"Textfile (*.txt)|*.txt|All Files (*.*)|*.*|" filename:"log.txt"
		if fname != undefined then
		(
			fileTxt = ""
			maxver = maxVersion()
			curos = "Error"

			if SystemTools.IsWindows9x() then
				curos = "Windows 9x"
			if SystemTools.IsWindows98or2000() then
				curos = "Windows98, Windows 2000, Windows XP or Windows Vista"

			sysbit = "32Bit"
			if (is64bitApplication() == TRUE) do sysbit = "64Bit"

			fileTxt += "Logfile written by Render Farm Application 3ds Max Plugin\r\n"; 
			fileTxt += "\r\n";

			fileTxt += "Environment:\r\n";
			fileTxt += "------------------------------ \r\n";

			fileTxt += "Client Document: " + maxFilePath + maxFileName + "\r\n";
			fileTxt += "Scripts Path: " + scriptsPath + "\r\n";
			fileTxt += "Client 3ds Max Ver.: " + (maxver[1] / 1000.0) as string + " (API: " + maxver[2] as string + "), (SDK revision: " + maxver[3] as string + ") "+sysbit+" \r\n";
			fileTxt += "Client OS: " + curos + "\r\n";
			fileTxt += "\r\n\r\n";

			fileTxt += "Farminizer Plugin output:\r\n";
			fileTxt += "------------------------------ \r\n\r\n";

			sst = stringstream ""
			sev_text = #("Info", "Warning", "Error", "", "", "", "", "")  -- ; TODO: same as in display.. how ugly
			grp = ""
			pre_grp = ""

			format "%" fileTxt to:sst
			for i in vecResults do
			(
				if i.validator != undefined then
				(
					grp = i.validator.getName()
					if grp != pre_grp then
					(
						format "%" ("\r\n" + grp + ":\r\n\r\n") to:sst
						pre_grp = grp
					)
				)

				format "%" (" --- " + sev_text[i.severity+1] + " --- " + i.message + "\r\n") to:sst
			)

			fileTxt = sst as string

			f = createFile fname
			if f != undefined then
			(
				format "%" fileTxt to:f
			)
			close f
		)
	)

	fn getBitmap bitmapPath =
	(
		if (maxversion())[1] >= 16000 then
		(
			if IDisplayGamma.colorCorrectionMode != #gamma then
			(
				return openBitmap bitmapPath gamma:#default
			)
			else
			(
				return openBitmap bitmapPath gamma:displayGamma
			)
		)
		else
			return openBitmap bitmapPath
	)

	save_required = getSaveRequired()
	
	fn setImage imagePath submitToSky =
    (
        local image = dotNetObject "System.Drawing.Bitmap" (dotNetObject "System.Drawing.Image").FromFile imagePath
        myBitmap.Image = image
		submitToSky.bounds=dotNetObject "System.drawing.rectangle"540 348 160 44
		submitToSky.backColor=SendBtn.backColor.transparent
		submitToSky.image= SendBtnPicN
    )
	
	rollout dlg_main "Render Farm Application Check" width:1000 height:650
	( 
		local my_path = getFilenamePath (getSourceFilename())
		local m_userName = ""
		local m_defaultPath = ""
		local m_managerPath = ""
		local m_PluginVersion = ""
		local m_CpuData = ""
		local m_slices = 100
		local changedMaxFile = ""
		local copyTexFiles = false
		local liveExport = false
		local rPosX = 762
		local posY = 120
		local rdbOffsetX = 94
		local btnHeight = 25

		local isGammaEnabled = false
		local custom_gamma = ""
		local isDistributedConfirmed = false
		local irayGPUselected = false
		local vrayGPUselected = false
		local fstormGPUselected = false
		local redshiftGPUselected = false
		local cyclesGPUselected = false
		local isVrsceneExport = false
		local isMiExport = false
		local estimateRenderpoints = false

		local fastCheck = true
		 

		bitmap 'bmp3' "Bitmap" pos:[0,0] width:1000 height:650 fileName:"E:\RenderFarm\UI_DESIGN\SKYSENDER_sendbg.jpg" align:#left
		
		ListBox lstMain "" across:1 height:36 pos:[12,80] style_sunkenedge:true 

		Label lblPgb "Progress" style_sunkenedge:true pos:[10,616] height:20 width:(dlg_main.width-200) across:2 align:#left 

		Button submitToSky "Submit to Render Farm Application" width:170 height:54 pos:[dlg_main.width-180,dlg_main.height-65] images: #(my_path + "res\\send_n.jpg", my_path + "res\dashboard_a.jpg",1,1,1,1,1) enabled:false visible:false
		
	 
	 
		fn progressStart=
		(
			 
		)

		fn progressUpdate progress:0 msg:""=
		(
			 

			if(lblPgb.caption!= msg) then
			(
				lblPgb.caption= msg
			)
 
		)

		fn progressEnd msg:""=
		(
			dlg_main.progressUpdate progress:0 msg:msg
		)

		on submitToSky pressed do
		( 
			dlg_main.fastCheck = false

					ActionStart &valid fastCheck:dlg_main.fastCheck

			f = pathConfig.appendPath dlg_main.m_defaultPath dlg_main.m_userName
			if (f == undefined) OR (getDirectories f).count != 1 then
				f = getSavePath()
			b = false
			if f != undefined then
			(
				if existsFile (pathConfig.appendPath f (dlg_main.changedMaxFile)) == false and existsFile (pathConfig.appendPath f (dlg_main.changedMaxFile+".cfg")) == true then
				(
					deleteFile (pathConfig.appendPath f (dlg_main.changedMaxFile+".cfg"))
				)

				if existsFile (pathConfig.appendPath f (dlg_main.changedMaxFile+".cfg")) == true then
				(
					messagebox "Farminizer can\'t export due to a bug in 3ds Max. save scene with new name or restart 3ds Max.!" title:"Render Farm Application Manager"
				)
				else
				(
					if valid then
					(
						DoExportFolder f &b
					)
					else
						messagebox "This project could not be exported, please check the displayed errors." title:"Render Farm Application"
				)
			)
		)

		 

		fn getRendererString =
		(
			-- ; FIXME : should be moved into each validator. To move validator functions into those too.
			-- This causes multiple changes if a Renderer changes or is added
			local stRenderer = ""
			case classof renderers.production of
			(
				vray:
				(
					local curVrayVersion = vray as string
					local vpos = findString curVrayVersion "RC3"
					if vpos != undefined then
						curVrayVersion = replace curVrayVersion vpos 3 "RC4"
					local gpu = ""
					if vrayGPUselected then
						gpu = "GPU "
					if isVrsceneExport then
						stRenderer = "VrayStandalone " + gpu + curVrayVersion
					else
						stRenderer = "Vray " + gpu + curVrayVersion
					if getVrayVersion() > 40000 then
						stRenderer += " " + (getVrayVersion() as string)
				)
				vrayrt:
				(
					local curVrayVersion = vrayrt as string
					local gpu = " "
					if vrayGPUselected then
						gpu = "GPU "
					if isVrsceneExport then
						stRenderer = "VrayStandalone " + gpu + curVrayVersion
					else
						stRenderer = "Vray " + gpu + curVrayVersion
					if getVrayVersion() > 40000 then
						stRenderer += " " + (getVrayVersion() as string)
				)
				MaxwellRenderer:
					stRenderer = "MX"
				mental_ray_renderer:
					if isMiExport then
						stRenderer = "mentalStandalone"
					else
						stRenderer = "MR"
				mental_ray_iray_Renderer:
					if irayGPUselected then
						stRenderer = "irayGPU"
					else
						stRenderer = "iray"
				Iray:
					if irayGPUselected then
						stRenderer = "irayPlusGPU"
					else
						stRenderer = "irayPlus"
				Redshift_Renderer:
				(
					local redshiftVersion = ""
					if rsVersion != undefined then
					(
						local v = rsVersion()
						redshiftVersion = "_" + v[1] as string + "." + v[2] as string + "." + v[3] as string
					)
					stRenderer = "redshiftGPU"+redshiftVersion
				)
				cycles_renderer:
					if cyclesGPUselected then
						stRenderer = "cyclesGPU"
					else
						stRenderer = "cycles"
				FStormRender:
					if fstormGPUselected then
						stRenderer = ((classof renderers.production) as string) + "GPU"
					else
						stRenderer = (classof renderers.production) as string

				finalRender_stage_1:
					stRenderer = "FR"
				Default_Scanline_Renderer:
					stRenderer = "SL"
				CoronaRenderer:
					stRenderer = "corona " + (getCoronaIntVersion() as string)
				Octane_Render:
					stRenderer = "octaneGPU"
				Octane_Render_Demo:
					stRenderer = "octaneGPU"
				A360_Cloud_Rendering:
					stRenderer = "a360"
				ART_Renderer:
					stRenderer = "art"
				Arnold:
					stRenderer = "Arnold"
				default:
					if (findString (classof renderers.production as string) "OctaneRender") != undefined then
						stRenderer = "octaneGPU"
					else
						stRenderer = "X"
			)
			return stRenderer
		)

		fn getPriorityArrayByRenderer =
		(
			cpu_priorities = #("Standard (1,2 Cent / GHzh)",
								"Prio +1 (1,8 Cent / Ghzh)",
								"Prio +2 (2,4 Cent / Ghzh)",
								"Prio +3 (3,0 Cent / Ghzh)",
								"Prio +4 (3,6 Cent / Ghzh)",
								"Prio +5 (4,2 Cent / Ghzh)",
								"Prio +6 (4,8 Cent / Ghzh)",
								"Prio +7 (5,4 Cent / Ghzh)"
								)

			gpu_priorities = #("Standard (0,9 Cent / OBh)",
								"Prio +1 (1,4 Cent / OBh)",
								"Prio +2 (1,9 Cent / OBh)",
								"Prio +3 (2,4 Cent / OBh)",
								"Prio +4 (2,9 Cent / OBh)",
								"Prio +5 (3,4 Cent / OBh)",
								"Prio +6 (3,9 Cent / OBh)",
								"Prio +7 (4,5 Cent / OBh)"
								)

			if isGpuRenderer() then
				return gpu_priorities

			return cpu_priorities
		)

		fn getStatusInfoValue key =
		(
			local filePath = pathConfig.appendPath (pathConfig.appendPath (m_defaultPath) (m_userName)) "shadows.txt"
			local val = ""
			local file = openFile filePath mode:"r"

			if file != undefined then
			(
					while not eof file do
					(
						try
						(
							local s = readline file
							local entry = filterString s ":"
							if entry[1] == key then
								val = entry[2]
						)
						catch
						(
						)
					)

				close file
			)
			return val
		)

		fn gpuSelected =
		(
			if irayGPUselected == true or vrayGPUselected == true or redshiftGPUselected == true or cyclesGPUselected == true or fstormGPUselected == true then
				return true
			return false
		)

		fn getRenderpoints =
		(
			return getStatusInfoValue "rp"
		)
		fn getJobsRendering =
		(
			local jobsRendering = getStatusInfoValue "jobsRunningCount"

			if (jobsRendering == "") then
				return "-"
			else
				return jobsRendering
		)
		fn getJobsCompleted =
		(
			local jobsCompleted = getStatusInfoValue "jobsReadyCount"

			if (jobsCompleted == "") then
				return "-"
			else
				return jobsCompleted
		)
		fn getJobsWaiting =
		(
			local jobsWaiting = getStatusInfoValue "jobsQueuedCount"

			if (jobsWaiting == "") then
				return "-"
			else
				return jobsWaiting
		)
		fn getJobsPaused =
		(
			local jobsPaused = getStatusInfoValue "jobsPausedCount"

			if (jobsPaused == "") then
				return "-"
			else
				return jobsPaused
		) 

		fn skyCheckScene =
		(
			dlg_main.show()
			dlg_main.btnStartPressed()
		)

		fn addStringToFileIfNotPresent search_string file_path =
		(
			local maxver = maxversion()
			if maxver[1] >= 23000 then
			(
				local py = importRebPYMXSUtils()
				return py.pyAddStringToFileIfNotPresent search_string file_path
			)
			else 
			(
				local py = importRebPythonUtils()
				return py.pyAddStringToFileIfNotPresent search_string file_path
			)
			
		)

		fn getFileModifiedTimestamp file_path =
		(
			local maxver = maxversion()
			if maxver[1] >= 23000 then
			(
				local py = importRebPYMXSUtils()
				return py.pyGetFileModifiedTimestamp file_path
			)
			else
			(
				local py = importRebPythonUtils()
				return py.pyGetFileModifiedTimestamp file_path
			)
			
		)


		fn skyUploading =
		(
			local vecTex = ValTexture.findAllTextures()
			print vecTex.count
			if vecTex.count == 0 then
			(
				vecResults = #()
				dlg_main.show()
				append vecResults (tr id:0 index:current_vecResult validator:ValPreUpload severity:0 message:( "Currently there are no texture to upload in the scene." ))
				DisplayResults dlg_main.lstMain
			)

			local maxver = maxVersion()

			if maxver[1] < 19000 then
			(
				st="We are sorry, but PreUpload is only avaiable in 3ds Max 2017 and newer."
				messagebox st title:"Render Farm Application"
				return false
			)

			local lastRedraw = mTimeGetTime()
			local vecTexFullPaths = #()
			local vecTexChecked = #()

			dlg_main.show()

			for i = 1 to vecTex.count do
			(
				if findItem vecTexChecked vecTex[i].filename != 0 then
					continue
				else
					append vecTexChecked vecTex[i].filename
				PushPrompt("Exporting Texture " + (i as string) + " of " + (vecTex.count as string) + "...")
				if mTimeGetTime() - lastRedraw > 500 then
				(
					lastRedraw = mTimeGetTime()
					redrawViews()
				)

				local st = (mapPaths.getFullFilePath vecTex[i].filename) as string
				if existsFile st then
					append vecTexFullPaths (myToLower st)
				popPrompt()
			)

			if vecTexFullPaths.count > 0 then
			(
				dlg_main.show()
				-- DisplayResults dlg_main.lstMain

				local p = pathConfig.appendPath (dlg_main.m_defaultPath) "shadows.txt"
				local scene_upload_history_path = pathConfig.appendPath (dlg_main.m_defaultPath) (pathConfig.appendPath (dlg_main.m_userName) ((getFilenameFile maxFileName) + "_upload_history.txt"))
				scene_upload_history_path = substituteString scene_upload_history_path "\\" "/"

				local liveFile = openFile p mode:"w"
				already_uploaded = 0
				added_to_upload = 0

				for i = 1 to vecTexFullPaths.count do
				(
					vecTexFullPaths[i] = substituteString vecTexFullPaths[i] "\\" "/"
					file_size = (getFileSize vecTexFullPaths[i]) as string
					file_modified_date = getFileModifiedTimestamp vecTexFullPaths[i]

					search_string = vecTexFullPaths[i] + "|/tex|" +  file_size + "|" +  file_modified_date

					if not addStringToFileIfNotPresent (search_string) (scene_upload_history_path)  then
					(
						format "%|/tex|%|%\n" (vecTexFullPaths[i]) (trimRight (file_size) "L") file_modified_date to:liveFile
						added_to_upload += 1
					)
					else
						already_uploaded += 1

				)
				close liveFile

				vecResults = #()
				append vecResults (tr id:0 index:current_vecResult validator:ValPreUpload severity:0 message:( (added_to_upload as string) + " texture files have been added to the upload queue for Render Farm Application."))
				DisplayResults dlg_main.lstMain
			)
		)

		 
		 

		 

		fn setManagerFileSettings =
		(
			conf = getConfigFileContent()
			if conf != undefined AND conf.count >= 4 then
			(
				dlg_main.m_userName = conf[1]
				dlg_main.m_defaultPath = conf[2]
				dlg_main.m_managerPath = conf[3]
				dlg_main.m_PluginVersion = conf[4]
				dlg_main.m_CpuData = conf[5]
			)
		)

		fn genarateSkyFile filename content:"" =
		(
			setManagerFileSettings()

			if farminizerDialog.m_defaultPath != "" then
			(
				farminizer_defaultPath = farminizerDialog.m_defaultPath
			)
			else if dlg_main.m_defaultPath != "" then
			(
				farminizer_defaultPath = dlg_main.m_defaultPath
			)
			else
			(
				messagebox "Farminizer is not properly configured.\nTry to close an open the Farminizer Window.\nQuit 3ds Max and reinstall the Farminizer Plugin." title:"Render Farm Application"
				return false
			)

			link_file = createFile (pathConfig.appendPath farminizerDialog.m_defaultPath filename)

			if content != "" then
			(
				format (trimright (trimleft content "\"") "\"") to:link_file
			)
			close link_file
		)


		fn createOpenCalcWithValuesFile =
		(
			local numFrames = getNumFrames()

			local prio = 0
			try
			(
				if FarmRenderSetting != undefined then
					prio = FarmRenderSetting.prio.selection - 1
			)
			catch
			(
					format "farm.ms:getCalculateCostsUrl *** % ***\n" (getCurrentException())
			)
			local timePerFrame = 0 --there seems to be no way to get the most recent render times
			local stRenderer = getRendererString()
			str_parameter = ("?program=MAX&renderer="+stRenderer+"&frames="+(numFrames as string)+"&time="+(timePerFrame as string) + "&prio="+(prio as string)+"&cpudata=" + dlg_main.m_CpuData)

			farminizerDialog.genarateSkyFile "opencalcwithvalues.txt" content:str_parameter
		)


		fn createOpenPaymentsFile =
		(
			farminizerDialog.genarateSkyFile "openpayments.txt"
		)


		fn createOpenCalculatorFile =
		(
			farminizerDialog.genarateSkyFile "opencalculator.txt"
		)


		fn createOpenCCFile =
		(
			farminizerDialog.genarateSkyFile "opencc.txt"
		)
 

		fn installRibbon=
		(
			try
			(
					local currentWorkspace = WorkspaceManager.GetCurrentWorkspaceIdentifier()
				local directory = WorkspaceManager.GetWriteDirectory()
				local workspaces = getfiles (directory + "\\usersave\\*__usersave__.ribbonconfig.xaml")
				local updated = false

				if workspaces.count == 0 then
				(
					MessageBox "Installation of the 'Render Farm Application Ribbon' did not work. Please use another Workspace and restart 3ds Max!\n\nAfter the installation into another workspace you can change back to this workspace and use the ribbon." title:"Information"
				)
				else
				(
					for workspaceName in workspaces do
					(
						local RIBBON_UID= "d70cd0a9-88b7-489e-8e4c-6236e1a4b666" --change this id if the content changes
						local RIBBON_MARKER = "Title=\"Render Farm Application\""

						local contents = stringstream ""
						local file = openFile (workspaceName) mode:"r"

						-- format "Ribbon : %\n" file

						while not eof file do
						(
							append contents ((readline file) + "\r\n")
						)
						close file
						contents = contents as string
						local ribbonMarkerPos = findString contents RIBBON_MARKER
						local ribbonUidPos = findString contents RIBBON_UID

						if ribbonMarkerPos== undefined or ribbonUidPos == undefined then
						(
							if ribbonMarkerPos == undefined then
								print("Installing Render Farm Application Ribbon in " + workspaceName)
							else
								print("Updating Render Farm Application Ribbon in " + workspaceName)

							local st = "<wpfcust:MaxRibbonTab IsActive=\"true\" Title=\"FarmRender\" UID=\""+RIBBON_UID+"\">
	<wpfcust:MaxModelingRibbonPanel CollapsedPanelImage=\"__respath__/render_now_32.png\" FloatingGroup=\"0\" FloatingOrder=\"0\" UID=\"2497c827-2148-427c-a7a7-859e69d0ed6d\">
	<wpfcust:MaxRibbonPanelSource Title=\"Renderpoints: 0 | Jobs rendering 0 | completed 0 | waiting 0 | paused 0\" UID=\"4c7e042c-d738-4273-82b7-bc417926e259\">
		<ads:RibbonRowPanel AllowInToolBar=\"false\" Image=\"Icons/MissingImage_16.png\" IsToolTipEnabled=\"true\" LargeImage=\"Icons/MissingImage_32.png\" MinWidth=\"100\" ShowText=\"false\" UID=\"c5d0a25c-e95e-448f-bd3a-94b7df1aa592\">		 
		<wpfcust:MaxscriptRibbonButton Image=\"__respath__/buy_renderpoints_16.png\" 
							IsCheckable=\"false\" IsToolTipEnabled=\"true\" LargeImage=\"__respath__/buy_renderpoints_32.png\" MaxscriptCommand=\"skyRibbonBuy()\" MinWidth=\"0\" ResizeStyle=\"Collapse\" 
							ShowText=\"true\" Size=\"Large\" Text=\"Buy renderpoints\" UID=\"1d70c75d-8b19-4050-be82-5c444bd5f531\">
			<wpfcust:MaxscriptRibbonButton.CommandHandler>
			<wpfcust:MaxscriptCommand Maxscript=\"skyRibbonBuy()\" />
			</wpfcust:MaxscriptRibbonButton.CommandHandler>
		</wpfcust:MaxscriptRibbonButton>
		</ads:RibbonRowPanel>
	</wpfcust:MaxRibbonPanelSource>
	</wpfcust:MaxModelingRibbonPanel>
</wpfcust:MaxRibbonTab>
";
							local respath = (getFilenamePath (getSourceFilename()) + "res")
							respath = replaceAll respath "\\" "/"
							st = replaceAll st "__respath__" respath

							if ribbonUidPos == undefined and ribbonMarkerPos != undefined then
							(
								local tagStart = ribbonMarkerPos
								while contents[tagStart] != "<" and tagStart > 0 do
									tagStart -=1
								if tagStart > 0 then
								(
									local tagContents = substring contents tagStart -1
									local endTag = "</wpfcust:MaxRibbonTab>"
									local endTagPos = findString tagContents endTag
									if endTagPos != undefined then
									(
										local p1 = substring contents 1 (tagStart-1)
										local p2 = substring contents (tagStart + endTagPos + endTag.count) -1
										contents = p1 + p2
									)
								)
							)

							local insertPos = findString contents "<wpfcust:MaxRibbonTab"

							local inserted = substring contents 1 (insertPos-1)
							inserted = inserted + st
							inserted = inserted + substring contents (insertPos) -1
							deleteFile workspaceName
							file = createFile workspaceName
							if file != undefined then
								format "%" inserted to:file
							close file
							updated = true
						)
						else
						(
							print("ribbon already found")
						)
						if updated then
							MaxRibbon.LoadRibbonConfig (directory + "\\usersave\\"+currentWorkspace+"__usersave__.ribbonconfig.xaml")
					)

				)
			)
			catch
			(
				print("Error in Ribbon creation")
			)
		)

		fn installToolbar =
		(
			-- -- not used anymore
			-- return true
			local currentWorkspace = WorkspaceManager.GetCurrentWorkspaceIdentifier()
			local directory = WorkspaceManager.GetWriteDirectory()
			local workspaces = (getfiles (directory + "\\usersave\\*.cuix")) + getfiles (directory + "\\*.cuix")
			local updated = false
			if workspaces.count == 0 then
			(
				MessageBox "Installation of the 'Render Farm Application Toolbar' did not work. Please use another Workspace and restart 3ds Max!\n\nAfter the installation into another workspace you can change back to this workspace and use the toolbar." title:"Information"
			)
			else
			(
				for workspaceName in workspaces do
				(
					local TOOLBAR_UID= "objectName=\"Render Farm Application_v35\"" --change this id if the content changes
					local TOOLBAR_MARKER = "name=\"Render Farm Application\""

					local contents = stringstream ""
					local file = openFile (workspaceName) mode:"r"

					-- format "Toolbar : %\n" file

					while not eof file do
					(
						append contents ((readline file) + "\r\n")
					)
					close file
					contents = contents as string
					local ribbonMarkerPos = findString contents TOOLBAR_MARKER
					local ribbonUidPos = findString contents TOOLBAR_UID

					if ribbonMarkerPos== undefined or ribbonUidPos == undefined then
					(
						if ribbonMarkerPos == undefined then
							print("Installing Render Farm Application Toolbar in " + workspaceName)
						else
							print("Updating Render Farm Application Toolbar in " + workspaceName)
-- , FIXME : REMOVE image from images
						local st = "     <Window "+TOOLBAR_UID+" name=\"Render Farm Application\" type=\"T\" cType=\"1\" toolbarRows=\"1\" rank=\"0\" subRank=\"0\" hidden=\"0\" dPanel=\"3\" tabbed=\"0\" curTab=\"-1\" toolbarType=\"16\">
             
        </Window>"
			-- after </Items>
			-- <FRect left=\"941\" top=\"506\" right=\"1056\" bottom=\"575\" />
            -- <DRect left=\"1427\" top=\"53\" right=\"1568\" bottom=\"92\" />
            -- <DRectPref left=\"2147483647\" top=\"2147483647\" right=\"-2147483648\" bottom=\"-2147483648\" />
            -- <CurPos left=\"941\" top=\"506\" right=\"1056\" bottom=\"575\" floating=\"1\" panelID=\"16\" />
						local respath = (getFilenamePath (getSourceFilename()) + "res")
						respath = replaceAll respath "\\" "/"
						st = replaceAll st "__respath__" respath

						if ribbonUidPos == undefined and ribbonMarkerPos != undefined then
						(
							local tagStart = ribbonMarkerPos
							while contents[tagStart] != "<" and tagStart > 0 do
								tagStart -=1
							if tagStart > 0 then
							(
								local tagContents = substring contents tagStart -1
								local endTag = "</Window>"
								local endTagPos = findString tagContents endTag
								if endTagPos != undefined then
								(
									local p1 = substring contents 1 (tagStart-1)
									local p2 = substring contents (tagStart + endTagPos + endTag.count) -1
									contents = p1 + p2
								)
							)
						)

						local insertPos = findString contents "</CUIWindows>"
						insertPos = insertPos - 1
						local inserted = substring contents 1 (insertPos-1)
						inserted = inserted + st
						inserted = inserted + substring contents (insertPos) -1
						deleteFile workspaceName
						file = createFile workspaceName
						if file != undefined then
							format "%" inserted to:file
						close file
						updated = true
					)
					else
					(
						--print("toolbar already found")
					)
				)
				if updated then
					cui.LoadConfig (directory + "\\"+currentWorkspace+".cuix")
			)
		)

		fn farminizerSettingsCheck =
		(
			distribution_enabled = enableDistributedRenderingCheckbox()
			if distribution_enabled == false then
				FarmRenderSetting.distributed.checked = distribution_enabled

			FarmRenderSetting.distributed.enabled = distribution_enabled 

			FarmRenderSetting.prio.items = farminizerDialog.getPriorityArrayByRenderer()
 
			FarmRenderAccount.updateJobData()
		)

		fn removeAndAddCallbacks =
		(
			callbacks.removeScripts id:#changedRenderParams
			callbacks.addscript #renderParamsChanged "farminizerDialog.farminizerSettingsCheck()" id:#changedRenderParams
			callbacks.addscript #postRendererChange "farminizerDialog.farminizerSettingsCheck()" id:#changedRenderParams
			callbacks.addscript #tabbedDialogCreated "farminizerDialog.farminizerSettingsCheck()" id:#changedRenderParams
			callbacks.addscript #tabbedDialogDeleted "farminizerDialog.farminizerSettingsCheck()" id:#changedRenderParams
			-- RegisterTimeCallback farminizerSettingsCheck
		)

		fn init =
		(
			setManagerFileSettings()
  
		)

		on dlg_main open do
		(

			createSkyf.texFolder = pathConfig.appendPath (pathConfig.appendPath dlg_main.m_defaultPath dlg_main.m_userName) "tex"
			createSkyf.defaultPath = dlg_main.m_defaultPath

		)

		on dlg_main close do
		(
			
		)

		on dlg_main resized size do
		(
			lstMain.width = size.x-30
			--lstMain.height = size.y-64
			--submitToSky.pos.y = size.y - 56
			submitToSky.pos.x = size.x - 180

			--lblPgb.pos.y= size.y - 56
		)

		on lstMain selected id do
		(
			if id <=0 then
				return 0

			idx = listIndex[id]
			if idx != undefined then
			(
				if vecResults[idx] != undefined AND vecResults[idx].flagMoreInfos != undefined AND vecResults[idx].validator != undefined AND vecResults[idx].flagMoreInfos then
				(
					local resolved = vecResults[idx].validator.furtherAction vecResults[idx]

					if resolved != false and resolved !=0 then
					(
						vecResults[idx].severity = 3
						DisplayResults lstMain

						local valid = false
						ActionStart &valid fastCheck:dlg_main.fastCheck resolved:resolved

						if valid != false and valid != 0 then
							dlg_main.submitToSky.enabled=true
					)
				)
			)
		)

		fn btnStartPressed=
		(
			 
		    dlg_main.fastCheck = true

		    valid = false
		    ActionStart &valid fastCheck:dlg_main.fastCheck
		 

			if FarmRenderSetting != undefined then
				FarmRenderSetting.updatePrioDropdown()

		)

		fn btnExportPressed estimation:false=
		(
			ActionExport estimation:estimation
		)

		fn getCalculateCostsUrl =
		( 
			local numFrames = getNumFrames()

			local prio = 0
			try
			(
				if FarmRenderSetting != undefined then
					prio = FarmRenderSetting.prio.selection - 1
			)
			catch
			(
				format "farm.ms:getCalculateCostsUrl *** % ***\n" (getCurrentException())
			)
			local timePerFrame = 0 --there seems to be no way to get the most recent render times
			local stRenderer = getRendererString()
			return (url+"/lets-go/calculator?program=MAX&renderer="+stRenderer+"&frames="+(numFrames as string)+"&time="+(timePerFrame as string) + "&prio="+(prio as string)+"&cpudata=" + dlg_main.m_CpuData)
		)

		fn btnCalculateCostsPressed =
		(
			renderSceneDialog.commit()
			ShellLaunch (getCalculateCostsUrl()) ""
		)

		fn show =
		(
			farminizerDialog = dlg_main
			farminizerDialog.init()
			global check_scene_dialog = CreateDialog dlg_main style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing, #style_sunkenedge) lockHeight:true
		)
		
	)
	-- createTemprenderPath()
	global farminizerDialog 
	farminizerDialog = dlg_main 
	farminizerDialog.init()

)

fn writeSetupSettingsToFile =
(
	max_settings_file_path = pathConfig.appendPath (pathConfig.appendPath farminizerDialog.m_defaultPath farminizerDialog.m_userName) "max_settings_file"

	settings = ""
	settings += "setting_priority=" + setting_priority as string + "\n"
	settings += "setting_autostart=" + (if setting_autostart then "1" else "0") + "\n"
	settings += "setting_batch_render=" + (if setting_batch_render then "1" else "0") + "\n"
	settings += "setting_distributed=" + (if setting_distributed then "1" else "0") + "\n"
	settings += "setting_send_mail=" + (if setting_send_mail then "1" else "0") + "\n"
	settings += "setting_mail_finish=" + (if setting_mail_finish then "1" else "0") + "\n"
	settings += "setting_mail_start=" + (if setting_mail_start then "1" else "0") + "\n"

	try
	(
		local max_settings_file = createFile max_settings_file_path
		if max_settings_file != undefined then
			format "%" settings to:max_settings_file
		close max_settings_file
	)
	catch
	(
		format "Farminizer Settings could not be written into file."
	)
)


fn getSetupSettingsFromFile =
(
	max_settings_file_path = pathConfig.appendPath (pathConfig.appendPath farminizerDialog.m_defaultPath farminizerDialog.m_userName) "max_settings_file"

	if (getfiles max_settings_file_path).count != 0 then
	(
		local max_settings_file = openFile (max_settings_file_path) mode:"r"

		while not eof max_settings_file do
		(
			local line_content = filterString (readline max_settings_file) "="
			if line_content[1] == "setting_priority" then
				setting_priority = line_content[2] as number
			if line_content[1] == "setting_autostart" then
				setting_autostart = if line_content[2] == "1" then true else false
			if line_content[1] == "setting_batch_render" then
				setting_batch_render = if line_content[2] == "1" then true else false
			if line_content[1] == "setting_distributed" then
				setting_distributed = if line_content[2] == "1" then true else false
			if line_content[1] == "setting_send_mail" then
				setting_send_mail = if line_content[2] == "1" then true else false
			if line_content[1] == "setting_mail_finish" then
				setting_mail_finish = if line_content[2] == "1" then true else false
			if line_content[1] == "setting_mail_start" then
				setting_mail_start = if line_content[2] == "1" then true else false
			else
				continue
		)
		close max_settings_file
	)
)


rollout FarmRender "Render"
(
	Button btnSmartcheck "QuickCheck" width:150 height:60 align:#left across:2 tooltip:"Check your scene before sending it to Render Farm Application."
	Button btnRender "Render now" width:150 height:60 align:#right tooltip:"Your job will be uploaded. If you did not tick 'activate autostart' you will have to start your job in the ControlCenter. If you ticked the 'activate autostart' your rendering will start right after the upload."

	on btnRender pressed do
	(
		farminizerDialog.btnExportPressed()
	)
	on btnSmartcheck pressed do
	(
		farminizerDialog.skyCheckScene()
	)
)

rollout FarmRenderAccount "Account"
(
	 -- PictureBoxSizeMode = 1 = streching
	global setting_priority = 1
	global setting_autostart = false
	global setting_distributed = false
	global setting_batch_render = false
	global setting_send_mail = false
	global setting_mail_start = false
	global setting_mail_finish = true

	local PictureBoxSizeMode = 1

	dotNetControl banner "System.Windows.Forms.PictureBox" align:#center width:380 height:105 SizeMode:PictureBoxSizeMode 
	local jobs_rendering_text 	= " rendering"
	local jobs_completed_text 	= " completed"
	local jobs_waiting_text 	= " waiting"
	local jobs_paused_text 		= " paused"

	fn updateBannerData =
	(
		 
	)

	fn updateUserData =
	(
		if farminizerDialog != undefined then
		(
			FarmRenderAccount.username.text = "User: " + farminizerDialog.m_userName
			FarmRenderAccount.renderpoints.text = "RenderPoints: " + (farminizerDialog.getRenderpoints())
		)
	)

	fn updateJobData =
	(
		if farminizerDialog != undefined then
		(
			FarmRenderAccount.rendering.text = (farminizerDialog.getJobsRendering() as string) + jobs_rendering_text
			FarmRenderAccount.completed.text = (farminizerDialog.getJobsCompleted() as string) + jobs_completed_text
			FarmRenderAccount.waiting.text = (farminizerDialog.getJobsWaiting() as string) + jobs_waiting_text
			FarmRenderAccount.paused.text = (farminizerDialog.getJobsPaused() as string) + jobs_paused_text
			--calccosts.address = farminizerDialog.getCalculateCostsUrl()
		)
	)

	on banner Paint senderArg paintEventArgs do
	(
		bmpRectangle = dotNetObject "System.Drawing.Rectangle" 0 0 380 105
		Graphics = paintEventArgs.Graphics  
	)

	on banner MouseEnter senderArg paintEventArgs do
	(
	)

	on banner MouseLeave senderArg paintEventArgs do
	(
	)

	Label username "User: " across:2 align:#left
	Label renderpoints "RenderPoints: " align:#left

	group "My Jobs"
	(
		Label rendering jobs_rendering_text  across:4 height:20 width:88 -- align:#left
		Label completed jobs_completed_text height:20 width:88 -- align:#center
		Label waiting jobs_waiting_text height:20 width:88 -- align:#left
		Label paused jobs_paused_text height:20 width:88 -- align:#center

	)
	local linkColor = color 61 128 219
  

	on home pressed do
	( 
	)

	on controlcenter pressed do
	(
		farminizerDialog.createOpenCCFile()
	)

	on pre_upload pressed do
	(
		farminizerDialog.skyUploading()
	)

	on calccosts pressed do
	(
		farminizerDialog.createOpenCalcWithValuesFile()
	)
	on buyrp pressed do
	(
		farminizerDialog.createOpenPaymentsFile()
	)

	on farminizerSettingsCheckTimer tick do
	(
		farminizerDialog.farminizerSettingsCheck()
	)


	Timer timerBannerRotator interval:4000 active:true
	Timer farminizerSettingsCheckTimer interval:3000 active:true
	local bannerIndex = 1


	on FarmRenderAccount open do
	(
		banner.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand 

		FarmRenderAccount.updateBannerData()
		FarmRenderAccount.updateUserData()
		FarmRenderAccount.updateJobData()
		getSetupSettingsFromFile()
	)


	on timerBannerRotator tick do
	(
	 
	)

	on banner click do
	(
	 
	)


)

rollout FarmRenderSetting "Settings"
(

	label lblPrio "Priority: " across:2 align:#left tooltip:"Set your preferred render priority here."
	dropdownlist prio "" selection:setting_priority offset:[-130,0] width:310 tooltip:"If you choose a higher priority, your job will move up in the queue. The higher the priority you choose the higher the costs." items:#() height:15
	label waittime "Estimated wait time 2 hours" tooltip:"This is an estimation how long your job will be queued based on current Render Farm Application load." width:310 offset:[26,0] height:20 style_sunkenedge:true
	checkbox autostart "Activate autostart" checked:setting_autostart offset:[53,0] tooltip:"When autostart is checked, your rendering will go straight to the render queue after the upload is finished, otherwise you need to start it in the ControlCenter."
	checkbox distributed "Render distributed" checked:setting_distributed offset:[53,0] tooltip:"Single Frame renderings will be split and sent to different nodes to render it more quickly. Please be aware that this will increase the costs of your rendering!"

	local waittimes = #("2 hours", "30 minutes", "10 minutes", "< 10 minutes", "< 10 minutes", "< 10 minutes", "< 10 minutes", "< 10 minutes")

	on FarmRenderSetting open do
	(
		prio.items = farminizerDialog.getPriorityArrayByRenderer()
 
		local skyWaitTimes = #()
		local file = openFile (farminizerDialog.my_path + "res/waittimes.txt") mode:"r"
		local i=0
		if file != undefined then
		(
			while not eof file do
			(
				local ln = (readline file)
				local vOut = filterstring ln "|" splitEmptyTokens:false
				if vOut.count == 2 then
				(
					append skyWaitTimes #(vOut[1], vOut[2])
				)
			)
			close file
		)

		if skyWaitTimes.count > 0 then
		(
			try
			(
				local i=1
				for waittime in skyWaitTimes do
				(
					if i > waittimes.count then
						exit
					local waittext = ""
					local wait_hours = waittime[2] as integer / (60*60)
					local wait_minutes = (waittime[2] as integer / (60))

					if wait_hours > 0 then
						waittext = wait_hours as string + " hours"
					else if wait_minutes > 0 then
						if wait_minutes < 5 then
							waittext = wait_minutes as string + " minutes"
						else
							waittext = "is less than a minute"
					else
						waittext = "0 minutes"
					waittimes[i] = waittext
					i = i+1
				)
				waittime.text = "Estimated wait time " + waittimes[1]
			)
			catch
			( 

			)
		)
	)

	on prio selected i do
	(
		waittime.text = "Estimated wait time " + waittimes[i]
		setting_priority = i
		writeSetupSettingsToFile()
	)

	fn updateRenderButton=
	(
		if autostart.checked then
		(
			FarmRender.btnRender.text = "Render Now"
		)
		else
		(
			FarmRender.btnRender.text = "Submit to Skr Render"
		)
	)
 

	fn updatePrioDropdown =
	(
		prio.items = farminizerDialog.getPriorityArrayByRenderer()
	)

	on autostart changed state do
	(
		updateRenderButton()
		print state
		setting_autostart = state
		writeSetupSettingsToFile()
	)

	on distributed changed state do
	( 
		setting_distributed = state
		writeSetupSettingsToFile()
	)

)

rollout skyatchRender "Batch Render"
(
	checkbox batchRender "Activate Batch Render (i.e. multiple cameras)" checked:setting_batch_render offset:[53,0] tooltip:"Batch Render for rendering multiple cameras."
	Button setupBatchRender "Setup Batch Render" height:32 width:310 offset:[116,0] across:2 tooltip:"Open Batch Render dialogc. Check \"Activate Batch Render\" to send these to Render Farm Application then"

	on setupBatchRender pressed do
	(
		actionMan.executeAction -43434444 "4096"
	)

	on batchRender changed state do
	(
		setting_batch_render = state
		writeSetupSettingsToFile()
	)
)
 

rollout skyNotify "Notifications"
(
	Checkbox sendMail "Send e-mail" checked:setting_send_mail across:4 tooltip:"You will be notified by e-mail when your rendering starts and/or your rendering is completed."
	Checkbox notifyStart "by start" enabled:setting_send_mail checked:setting_mail_start
	Checkbox notifyComplete "when complete" enabled:setting_send_mail checked:setting_mail_finish

	on qSendMail pressed do
	(
		goToOnlineFaq 30006
	)

	on sendMail changed state do
	(
		setting_send_mail = state
		if sendMail.checked == true then
		(
			notifyStart.enabled = true
			notifyComplete.enabled = true
		)
		else
		(
			notifyStart.enabled = false
			notifyComplete.enabled = false
		)
		writeSetupSettingsToFile()
	)

	on notifyStart changed state do
	(
		setting_mail_start = state
		writeSetupSettingsToFile()
	)

	on notifyComplete changed state do
	(
		setting_mail_finish = state
		writeSetupSettingsToFile()
	)

)

fn getBuildVersionFromFile =
(
	try
	(
		version = "unavailable"
		local version_file = openFile (farminizerDialog.my_path + "version.txt") mode:"r"
		if version_file != undefined then
		(
			local version_line = (readline version_file)
			version = trimRight version_line
			close version_file
		)

		return version
	)
	catch
	(
		format "utils.ms:1592*** % ***\n" (getCurrentException())
	)
)


fn showSkyDialog =
(
	global farminizerRolloutFloater
	--try(closeRolloutFloater farminizerRolloutFloater)catch()

	if farminizerRolloutFloater != undefined and farminizerRolloutFloater.open then
	(
		closeRolloutFloater farminizerRolloutFloater
	)
	else
	(
		build = getBuildVersionFromFile()

		farminizerRolloutFloater = newRolloutFloater ("Render Farm Application Setup: v3.0.0 build " + build) 400 750
		addRollout FarmRenderAccount farminizerRolloutFloater
		addRollout FarmRenderSetting farminizerRolloutFloater
		addRollout skyatchRender farminizerRolloutFloater 
		addRollout skyNotify farminizerRolloutFloater
		addRollout FarmRender farminizerRolloutFloater border:false

		FarmRenderSetting.updateRenderButton()
		farminizerDialog.farminizerSettingsCheck()
	)
)
try(form.close())catch()
	
	global setting_priority = 0
	global setting_autostart = false
	global setting_distributed = false
	global setting_batch_render = false
	global setting_send_mail = true
	global setting_mail_start = false
	global setting_mail_finish = false
	
(
	src = (getdir #userStartupScripts) + "\\sky\\assets\\bottuns\\"
	srcroot = (getdir #userStartupScripts) + "\\sky\\"
	
	--fn createForm =
	fs = openFile (srcroot+"clientsettings.cfg") mode:"r"
	username = readline fs	
	DashBtnPicN= dotNetObject "System.Drawing.Bitmap" (src+ "dashboard_n.jpg")
	DashBtnPicO = dotNetObject "System.Drawing.Bitmap" (src+ "dashboard_o.jpg")
	DashBtnPicD = dotNetObject "System.Drawing.Bitmap" (src + "dashboard_d.jpg")


	UserLbl = dotNetObject "system.windows.forms.label"
	UserLbl.bounds=dotNetObject "System.drawing.rectangle" 68 206 160 44
	UserLbl.text = username
	UserLbl.backColor=UserLbl.backColor.transparent
	UserLbl.font = dotnetobject "system.drawing.font" (dotnetobject "system.drawing.fontfamily" "arial") 10

	DashBtn = dotNetObject "system.windows.forms.label" 
	DashBtn.bounds=dotNetObject "System.drawing.rectangle" 65 271 160 44
	DashBtn.backColor=DashBtn.backColor.transparent
	DashBtn.image= DashBtnPicN
	--DashBtn.flatStyle=DashBtn.flatStyle.flat
	--DashBtn.Text="Dashboard"
	--DashBtn.font = dotnetobject "system.drawing.font" (dotnetobject "system.drawing.fontfamily" "Poppins") 12  (dotNetClass "system.drawing.fontStyle").regular
	--DashBtn.flatappearance.MouseoverBackColor = (dotnetclass"System.Drawing.color").deepskyblue
	--DashBtn.Forecolor = DashBtn.Forecolor.deepskyblue
	--DashBtn.FlatAppearance.BorderSize = 0;
	--DashBtn.FlatAppearance.Bordercolor = (dotnetclass"System.Drawing.color").deepskyblue

	BuyBtnPicN= dotNetObject "System.Drawing.Bitmap" (src+ "BuyCredits_n.jpg")
	BuyBtnPicO = dotNetObject "System.Drawing.Bitmap" (src+ "BuyCredits_o.jpg")
	BuyBtnPicD = dotNetObject "System.Drawing.Bitmap" (src + "BuyCredits_d.jpg")

	BuyBtn = dotNetObject "system.windows.forms.label" 
	BuyBtn.bounds=dotNetObject "System.drawing.rectangle" 65 342 160 44
	BuyBtn.backColor=BuyBtn.backColor.transparent
	BuyBtn.image= BuyBtnPicN

	CostBtnPicN= dotNetObject "System.Drawing.Bitmap" (src+ "Cost_n.jpg")
	CostBtnPicO = dotNetObject "System.Drawing.Bitmap" (src+ "Cost_o.jpg")
	CostBtnPicD = dotNetObject "System.Drawing.Bitmap" (src + "Cost_d.jpg")

	CostBtn = dotNetObject "system.windows.forms.label" 
	CostBtn.bounds=dotNetObject "System.drawing.rectangle"304 393 160 44
	CostBtn.backColor=CostBtn.backColor.transparent
	CostBtn.image= CostBtnPicN

	AnlyzBtnPicN= dotNetObject "System.Drawing.Bitmap" (src+ "Analyze_n.jpg")
	AnlyzBtnPicO = dotNetObject "System.Drawing.Bitmap" (src+ "Analyze_o.jpg")
	AnlyzBtnPicD = dotNetObject "System.Drawing.Bitmap" (src + "Analyze_d.jpg")

	AnlyzBtn = dotNetObject "system.windows.forms.label" 
	AnlyzBtn.bounds=dotNetObject "System.drawing.rectangle"540 283 160 44
	AnlyzBtn.backColor=AnlyzBtn.backColor.transparent
	AnlyzBtn.image= AnlyzBtnPicN

	SendBtnPicN= dotNetObject "System.Drawing.Bitmap" (src+ "Send_n.jpg")
	SendBtnPicO = dotNetObject "System.Drawing.Bitmap" (src+ "Send_o.jpg")
	SendBtnPicD = dotNetObject "System.Drawing.Bitmap" (src + "Send_d.jpg")

	SendBtn = dotNetObject "system.windows.forms.label" 
	SendBtn.bounds=dotNetObject "System.drawing.rectangle"540 348 160 44
	SendBtn.backColor=SendBtn.backColor.transparent
	SendBtn.image= SendBtnPicN

	prio = dotnetobject "System.Windows.Forms.ComboBox"
	prio.bounds=dotNetObject "System.drawing.rectangle" 303 200 160 44
	prio.flatStyle=prio.flatStyle.flat
	--ComboBoxStyle = dotNetClass "System.Windows.Forms.ComboBoxStyle"
	--prio.DropDownStyle = ComboBoxStyle.DropDownList
	--prio.backColor=prio.backColor.
	--prio.DroppedDown= true
	--prio.backColor=prio.backColor.white
	--prio.foreColor=prio.foreColor.deepskyblue
	prio.items.addrange #("Standard", "Silver", "Gold")
	prio.SelectedIndex = 0

	Autostart = dotnetobject "System.Windows.Forms.CheckBox"
	Autostart.bounds=dotNetObject "System.drawing.rectangle" 388 257 14 14
	Autostart.backColor=Autostart.backColor.transparent
	--Autostart.checked = setting_autostart
	--Autostart.AutoCheck = false
	--Autostart.AutoSize =True
	--Autostart.flatStyle=Autostart.flatStyle.flat
	
	Distributed = dotnetobject "System.Windows.Forms.CheckBox"
	Distributed.bounds=dotNetObject "System.drawing.rectangle" 405 286 14 14
	Distributed.backColor=Distributed.backColor.transparent
	--Distributed.checked = setting_distributed
	--Distributed.flatStyle=Distributed.flatStyle.flat

	Batch = dotnetobject "System.Windows.Forms.CheckBox"
	Batch.bounds=dotNetObject "System.drawing.rectangle" 422 320 14 14
	Batch.backColor=Batch.backColor.transparent
	--Batch.checked = setting_batch_render

	byStart = dotnetobject "System.Windows.Forms.CheckBox"
	byStart.bounds=dotNetObject "System.drawing.rectangle" 606 198 14 14
	byStart.backColor=byStart.backColor.transparent
	--byStart.Checked = setting_mail_start

	complete = dotnetobject "System.Windows.Forms.CheckBox"
	complete.bounds=dotNetObject "System.drawing.rectangle" 666 232 14 14
	complete.backColor=complete.backColor.transparent
	--complete.Checked = setting_mail_finish
	form = dotnetobject "MaxCustomControls.MaxForm"
    form.ClientSize = dotnetobject "System.Drawing.Size" 1000 540
	form.StartPosition = form.StartPosition.CenterScreen
	form.FormBorderStyle = none
    form.Text = "FarmRender"
	--form.topmost=true 
	-- Set the background image
	form.BackgroundImage = dotNetBackgroundImage

	-- Add Close Button
	CloseButton = dotNetObject "System.Windows.Forms.Button"
	CloseButton.Size = dotNetObject "System.Drawing.Size" 20 20
	CloseButton.Text = "X" 
	CloseButton.BackColor = form.BackColor.SkyBlue
	CloseButton.FlatStyle = CloseButton.FlatStyle.flat
	CloseButton.ForeColor = form.ForeColor.white
	CloseButton.FlatAppearance.BorderSize = 0
	CloseButton.Location = dotNetObject "System.Drawing.Point" (form.Width - CloseButton.Width - 10) 10
	
	-- Ribbons
	fn showSkyDlg s e =
	(
		form.showModeless()	 
	)
	
	
	
	-- Add MouseDown, MouseMove and MouseUp event handlers to the form
	fn onMouseDown s e =
		(
			-- Save the location of the mouse when the left mouse button is pressed
			if (e.Button.ToString() == "Left")
				then
						(
							global formOffset = dotNetObject "System.Drawing.Point" e.X e.Y
						)
		)

		dotNet.addEventHandler form "MouseDown" onMouseDown

	fn onMouseMove s e =
		(
			-- Move the form based on the current mouse position and the location of the mouse when the left mouse button was pressed
			if (e.Button.ToString() == "Left")
				then
					(
						form.Location = dotNetObject "System.Drawing.Point" (form.Left + e.X - formOffset.X) (form.Top + e.Y - formOffset.Y)
					)
		)
		dotNet.addEventHandler form "MouseMove" onMouseMove

	fn onMouseUp s e =
		(
			-- Reset the form offset when the left mouse button is released
			if (e.Button.ToString() == "Left")
				then
					(
						global formOffset = undefined
					)
		)
		dotNet.addEventHandler form "MouseUp" onMouseUp






	-- Mouse Events Dashboard
		
	-- Close Button
	fn whenButtonIsPressed  =
		(
			form.Close()
		)
	dotNet.addEventHandler CloseButton "click" whenButtonIsPressed		
		
	-- Priority
	fn ComboBoxIndexChanged  =
		(
			setting_priority = prio.SelectedIndex + 1
			writeSetupSettingsToFile()
		)
	dotNet.addEventHandler Prio "SelectedIndexChanged" ComboBoxIndexChanged		
		
	-- Autostart Check	
	fn autoStartchecked Checked =
		(
			setting_autostart = Autostart.Checked
			writeSetupSettingsToFile()
		)
	dotNet.addEventHandler Autostart "CheckedChanged" autoStartchecked
		
	-- Distributed Check	
	fn Distributedchecked Checked =
		(
			setting_distributed = Distributed.Checked
			writeSetupSettingsToFile()
		)
	dotNet.addEventHandler Distributed "CheckedChanged" Distributedchecked
		
	-- Batchrender Check	
	fn Batchchecked Checked =
		(
			setting_batch_render = Batch.Checked
			writeSetupSettingsToFile()
		)
	dotNet.addEventHandler Batch "CheckedChanged" Batchchecked
			
	-- bystart Check	
	fn byStartchecked Checked =
		(
			setting_send_mail = true
			setting_mail_start = byStart.Checked
			writeSetupSettingsToFile()
		)
	dotNet.addEventHandler byStart "CheckedChanged" byStartchecked
		
	-- whenFinished Check	
	fn completechecked Checked =
		(
			setting_send_mail = true
			setting_mail_finish = complete.Checked
			writeSetupSettingsToFile()
			print setting_send_mail
		)
	dotNet.addEventHandler complete "CheckedChanged" completechecked
		
	fn onMouseEnter s e = 
		(
			DashBtn.image = DashBtnPicO
		)
			
	dotnet.addeventhandler DashBtn "MouseEnter" onMouseEnter

	fn onMouseLeave s e = 
		(
			DashBtn.image=DashBtnPicN
		)
	dotnet.addeventhandler DashBtn "MouseLeave" onMouseLeave
	
	fn onMouseDown s e = 
		(
			DashBtn.image=DashBtnPicD
		)
	dotnet.addeventhandler DashBtn "MouseDown" onMouseDown
	
	fn onMouseUp s e = 
		(
			DashBtn.image=DashBtnPicO
		)
	dotnet.addeventhandler DashBtn "MouseUp" onMouseUp
			
	fn onClick s e = 
		(
			ShellLaunch "www.kartonrobot-istanbul.com" ""
		)
	dotnet.addeventhandler DashBtn "Click" onClick
	
	
-- Mouse Events BuyCredits
	
	fn onMouseEnter s e = 
		(
			BuyBtn.image = BuyBtnPicO
		)
	
	dotnet.addeventhandler BuyBtn "MouseEnter" onMouseEnter

	fn onMouseLeave s e = 
		(
			BuyBtn.image=BuyBtnPicN
		)
		
	dotnet.addeventhandler BuyBtn "MouseLeave" onMouseLeave
	
	fn onMouseDown s e = 
		(
			BuyBtn.image=BuyBtnPicD
		)
		
	dotnet.addeventhandler BuyBtn "MouseDown" onMouseDown
	
	fn onMouseUp s e = 
		(
			BuyBtn.image=BuyBtnPicO
		)
		
	dotnet.addeventhandler BuyBtn "MouseUp" onMouseUp
		
			fn onClick s e = 
		(
			ShellLaunch "www.kartonrobot-istanbul.com" ""
		)
		
	dotnet.addeventhandler BuyBtn "Click" onClick
	
	
-- Mouse Events CostCalculator
	
	fn onMouseEnter s e = 
		(
			CostBtn.image = CostBtnPicO
		)
	
	dotnet.addeventhandler CostBtn "MouseEnter" onMouseEnter

	fn onMouseLeave s e = 
		(
			CostBtn.image=CostBtnPicN
		)
		
	dotnet.addeventhandler CostBtn "MouseLeave" onMouseLeave
	
	fn onMouseDown s e = 
		(
			CostBtn.image=CostBtnPicD
		)
		
	dotnet.addeventhandler CostBtn "MouseDown" onMouseDown
	
	fn onMouseUp s e = 
		(
			CostBtn.image=CostBtnPicO
		)
		
	dotnet.addeventhandler CostBtn "MouseUp" onMouseUp
		
			fn onClick s e = 
		(
			ShellLaunch "www.kartonrobot-istanbul.com" ""
		)
		
	dotnet.addeventhandler CostBtn "Click" onClick		
		
	-- Mouse Events Analyze
			
	fn onMouseEnter s e = 
		(
			AnlyzBtn.image = AnlyzBtnPicO
		)
	
	dotnet.addeventhandler AnlyzBtn "MouseEnter" onMouseEnter

	fn onMouseLeave s e = 
		(
			AnlyzBtn.image=AnlyzBtnPicN
		)
		
	dotnet.addeventhandler AnlyzBtn "MouseLeave" onMouseLeave
	
	fn onMouseDown s e = 
		(
			AnlyzBtn.image=AnlyzBtnPicD
		)
		
	dotnet.addeventhandler AnlyzBtn "MouseDown" onMouseDown
	
	fn onMouseUp s e = 
		(
			AnlyzBtn.image=AnlyzBtnPicO
		)
		
	dotnet.addeventhandler AnlyzBtn "MouseUp" onMouseUp
		
			fn onClick s e = 
		(
			skyCheckScene()
		)
		
	dotnet.addeventhandler AnlyzBtn "Click" onClick		
		
		
	-- Mouse Events Send
	
	fn onMouseEnter s e = 
		(
			SendBtn.image = SendBtnPicO
		)
	
	dotnet.addeventhandler SendBtn "MouseEnter" onMouseEnter

	fn onMouseLeave s e = 
		(
			SendBtn.image=SendBtnPicN
		)
		
	dotnet.addeventhandler SendBtn "MouseLeave" onMouseLeave
	
	fn onMouseDown s e = 
		(
			SendBtn.image=SendBtnPicD
		)
		
	dotnet.addeventhandler SendBtn "MouseDown" onMouseDown
	
	fn onMouseUp s e = 
		(
			SendBtn.image=SendBtnPicO
		)
		
	dotnet.addeventhandler SendBtn "MouseUp" onMouseUp
		
	fn onClick s e = 
		(
		farminizerDialog.btnExportPressed()
		)
		
	dotnet.addeventhandler SendBtn "Click" onClick
	
		
	--Add Controls to Form
	form.controls.add UserLbl	
	form.controls.add DashBtn
	form.controls.add BuyBtn
	form.controls.add CostBtn
	form.controls.add AnlyzBtn
	form.controls.add SendBtn
	form.controls.add prio
	form.controls.add Autostart
	form.controls.add Distributed
	form.controls.add Batch
	form.controls.add byStart
	form.controls.add complete
	form.Controls.Add CloseButton


   
   form.showModeless()
)
 
