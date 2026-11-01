-- Только частный localhost профиль. Credentials лежат в profile/Lua, не в моде.
-- Штатные обработчики меню сохраняют native handshake и создание персонажа.
if isServer() then return end
local ticks,attempted,failed=0,false,false
local function log(s) print('[HCRLabBoot] '..s) end
local function visible(panel) return panel and panel:isVisible() end
local function advance(panel,button,label)
    if visible(panel) and button and button.enable then
        log(label);button:forceClick();return true
    end
end
local function step()
    if getPlayer() then return end
    if not attempted and ServerConnectPopup and visible(ServerConnectPopup.instance) then
        local reader=getFileReader('HCRLabLogin.txt',false)
        assert(reader,'Missing private lab login file')
        local user,password=reader:readLine(),reader:readLine();reader:close()
        assert(user and password,'Incomplete private lab login')
        local panel=ServerConnectPopup.instance
        assert(panel.ip=='127.0.0.1' and tostring(panel.port)=='16271','Refuse non-local lab connection')
        panel.usernameEntry:setText(user);panel.passwordEntry:setText(password)
        attempted=true;panel:onOptionMouseDown(panel.connectBtn)
        log('native login submitted');return
    end
    local spawn=MapSpawnSelect and MapSpawnSelect.instance
    if advance(spawn,spawn and spawn.nextButton,'native spawn selection') then return end
    local main=MainScreen and MainScreen.instance
    local profession=main and main.charCreationProfession
    if advance(profession,profession and profession.playButton,'native profession selection') then return end
    local appearance=main and main.charCreationMain
    advance(appearance,appearance and appearance.playButton,'native character creation')
end
Events.OnFETick.Add(function()
    if failed then return end
    ticks=ticks+1;if ticks%60~=0 then return end
    local ok,err=pcall(step)
    if not ok then failed=true;log('FAIL '..tostring(err)) end
end)
Events.OnCreatePlayer.Add(function(index,player)
    if player and player:isLocalPlayer() then log('local player created') end
end)
