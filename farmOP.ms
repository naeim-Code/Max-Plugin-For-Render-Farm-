fn copyIcons =
(
	try
	(
		local dest = getdir #userIcons 
		local src = (getdir #startupScripts) + "\\farm\\res\\"
		local RSrc=(getdir #startScripts)+"\\farm\\"
		if (getfiles (src + "*")).count == 0 then
			src = (getdir #userStartupScripts) + "\\farm\\res\\"
		local filein (RSrc+"farm.ms")
		deleteFile (dest+"\\farminizer_16a.bmp")
		deleteFile (dest+"\\farminizer_16i.bmp")
		deleteFile (dest+"\\farminizer_24a.bmp")
		deleteFile (dest+"\\farminizer_24i.bmp")
		deleteFile (dest+"\\farminizer_32a.bmp")
		deleteFile (dest+"\\farminizer_32i.bmp")
		copyFile (src + "farminizer_16a.bmp") (dest+"\\farminizer_16a.bmp")
		copyFile (src + "farminizer_16i.bmp") (dest+"\\farminizer_16i.bmp")
		copyFile (src + "farminizer_24a.bmp") (dest+"\\farminizer_24a.bmp")
		copyFile (src + "farminizer_24i.bmp") (dest+"\\farminizer_24i.bmp")
		copyFile (src + "farminizer_32a.bmp") (dest+"\\farminizer_32a.bmp")
		copyFile (src + "farminizer_32i.bmp") (dest+"\\farminizer_32i.bmp")
		-- colorman.reInitIcons()
	)
	catch()
)

copyIcons()

fn initializeFile =
(
	try
	(
		 	filein ( "farm.ms")
		 
	)
	catch
	(
		format "farm :42 : *** error when including farm.ms(e)\n"
	)
)

initializeFile()

fn reinitializeFarminizerDialog =
(
	global farminizerDialog
	if farminizerDialog !=undefined then
		destroydialog farminizerDialog
	initializeFile()
)

 
MacroScript FarmApp category:"FarmApp" buttonText:"FarmApp" tooltip:"Sasdasdasdasd" icon:#("farminizer",1)
(
	try 
	(
		reinitializeFarminizerDialog()
		RRibbon()
	)
	catch()

)

try
(
	farminizerDialog.installRibbon()
	farminizerDialog.installToolbar()
	farminizerDialog.removeAndAddCallbacks()
)
catch
(
	print("Something went wrong when installing Render Farm Application UI")
)


 
	try
	(
		menuMan.UnregisterMenu (menuMan.findMenu "FarmApp")
	)
	catch()
	main_menu = menuMan.getMainMenuBar()
	RMenu = menuMan.createMenu "FarmApp"
	RMainMenu = menuMan.createSubMenuItem "FarmApp" RMenu
	main_menu.addItem RMainMenu (11) -- Adding Menu at the currently last position in the main menu

	 
	menuR=menuMan.createActionItem "FarmApp" "FarmApp"
	
	 
	RMenu.addItem menuR(RMenu.numItems()+1)
	menuMan.updateMenuBar()
