function widget:GetInfo()
	return {
		name		= "Helps take map screenies",
		desc		= "Honk",
		author		= "",
		date		= "",
		license		= "",
		layer		= 0,
		enabled		= true
	}
end


function widget:GameStart()
    Spring.SendCommands("bind f12 screenshot png")
    Spring.SendCommands("cheat")
    Spring.SendCommands("globallos")
    Spring.SendCommands("hideinterface")
    Spring.SendCommands("showmetalmap")
end
function widget:Initialize()
    if Spring.GetGameFrame()>0 then
        widget:GameStart()
    end
end
