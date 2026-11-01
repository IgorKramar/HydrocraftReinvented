-- Только HCRLabMP в отдельных localhost профилях, вне релизного common/.
HCRLabTwoBoot=HCRLabTwoBoot or tostring(getTimestampMs())
local ticks,last=0,nil
Events.OnTick.Add(function()
    ticks=ticks+1;if ticks%60~=0 then return end
    local reader=getFileReader('HCRLabTwoCommand.txt',false)
    if not reader then return end
    local line=reader:readLine();reader:close()
    if not line or line==last then return end
    local sequence,command=line:match('^(%d+):([%w]+)$')
    if not command then return end
    last=line
    local ok,reason=pcall(function()
        if command=='reload' then
            reloadLuaFile('media/lua/shared/HCRLabTwoCases.lua')
            assert(HCRLabTwo and HCRLabTwo.start,'Lab module did not load')
        elseif command=='start' then HCRLabTwo.start()
        elseif command=='verify' then HCRLabTwo.verifySaved()
        elseif command=='exit' then
            assert(isClient(),'Exit command belongs to lab clients')
            MainScreen.instance:quitToDesktop()
        else error('Unknown lab command') end
    end)
    print('[HCRLabTwoControl] '..sequence..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(reason)))
end)
Events.OnClientCommand.Add(function(module,command,player,args)
    if module=='HCRLabTwo' and HCRLabTwo then HCRLabTwo.server(command,player,args) end
end)
Events.OnServerCommand.Add(function(module,command,args)
    if module=='HCRLabTwo' and HCRLabTwo then HCRLabTwo.client(command,args) end
end)
Events.OnTick.Add(function()
    if HCRLabTwo and HCRLabTwo.tick then HCRLabTwo.tick() end
end)
