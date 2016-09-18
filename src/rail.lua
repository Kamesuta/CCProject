--[[
##################################
       RailBuilder ver 1.6.4
        　created by b7n　著作権表記
          copyright b7n　消さないでね
##################################
--]]
--## functions ##
function Save(sj)
    local fh = fs.open("rail.pos","w")
    fh.write(sj)
    fh.close()
end
function Load()
    if fs.exists("rail.pos") then
        local fl = fs.open("rail.pos","r")
        local l = fl.readAll()
        fl.close()
        return tonumber(l)
    else return false end
end
function Help(more)
    if term.isColour() then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
    end
        term.clear()
        print("Usage:  More Details are here [-h more]")
        print(" It's easy to use this RailBuilder :-) ")
    if more then
        print("______Please set EnderChest below______")
        print("+--------+--------+--------+---------+ ")
        print("|        |        |        |         | ")
        print("+--------+--------+--------+---------+ ")
        print("|        |        |        |   fuel  | ")
        print("+--------+--------+--------+---------+ ")
        print("|        |        |        |redstone | ")
        print("+--------+--------+--------+---------+ ")
        print("| Block  |BoosterT| Track  |   LED   | ")
        print("+------------------------------------+ ")
        print("!Attention!set#ENDERCHEST#it's not item")
    else
        print("[-t] Controll mode")
        print("[-u] Update mode")
        print("[-r] Douki Recieveing mode")
        print("[-s] Douki Sending mode")
        print("[-n] How much distance between this")
        print("        turtle and Red Stone block?")
        print("[-h] Show you this help")
        print("[-h more] More Details!")
    end
    if term.isColour() then
        term.setCursorPos(1, 13)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clearLine()
    end
end
function setRail()
    if doukiSend then
        sleep(0.1)
        rednet.broadcast("$"..ia)
    end
    if ia == 0 then
        turtle.select(10)
        turtle.placeDown()
        ia = 16
    elseif ia == 8 then
        turtle.select(10)
        turtle.placeDown()
    elseif ia == 4 then
        turtle.select(9)
        turtle.placeDown()
    else
        turtle.select(slot["A"][2]+slot["A"][1])
        turtle.placeDown()
    end
    if ia == 3 then
        turtle.select(4)
        turtle.place()
    else
        turtle.select(slot["B"][2]+slot["B"][1])
        turtle.place()
    end
    ia = ia -1
    Save(ia)
end
function isCan()
    while wait do sleep(1) end
    while turtle.getItemCount(8)  < 1 do Wait("Please set enderchest of Coal to the 8th slot") end
    while turtle.getItemCount(12) < 1 do Wait("Please set enderchest of Redstone to the 12th slot") end
    while turtle.getItemCount(13) < 1 do Wait("Please set enderchest of Floor to the 13th slot") end
    while turtle.getItemCount(14) < 1 do Wait("Please set enderchest of BoosterT. to the 14th slot") end
    while turtle.getItemCount(15) < 1 do Wait("Please set enderchest of Track to the 15th slot") end
    while turtle.getItemCount(16) < 1 do Wait("Please set enderchest of LED to the 16th slot") end

    while not isMaterials("A") do
        Wait("Set Building materials into ender chest!")
    end
    while not isMaterials("B") do
        Wait("Set Tracks into ender chest!")
    end
    if turtle.getItemCount(4)  ==0 then
        while not LoadMaterials(4,1,14) do Wait("Set BoosterTracks into ender chest!") end
    end
    if turtle.getItemCount(9)  ==0 then
        while not LoadMaterials(9,1,12) do Wait("Set Blocks of Redstone into ender chest!") end
    end
    if turtle.getItemCount(10) ==0 then
        while not LoadMaterials(10,1,16) do Wait("Set LED into ender chest!") end
    end
    if turtle.getItemCount(11) ==0 then
        while not LoadMaterials(11,1,8) do Wait("Set Fuel items into ender chest!") end
    end
    if turtle.getFuelLevel() < 80 then
        turtle.select(11)
        turtle.refuel()
    end
    return ture
end
function Wait(mess)
    print(mess)
    while true do
        print("  Press enter key to continue!")
        local event,button = os.pullEvent("key")
        if button == 28 then
            print("  Continued!")
            return true
        else
            Help("more")
        end
    end
end
function LoadMaterials(item,max,ender)
    if turtle.getItemCount(ender) > 0 then
        rednet.send(id, "wait")
        turtle.select(ender)
        while not turtle.placeUp() do sleep(5) end
        for i=1,max do
            if turtle.getItemCount(item+(i-1)) == 0 then
                turtle.select(item+(i-1))
                turtle.suckUp()
            end
            sleep(0.1)
        end
        turtle.select(ender)
        if not turtle.getItemCount(ender) == 0 then
            turtle.drop()
        end
        turtle.digUp()
        if turtle.getItemCount(item) == 0 then return false end
        rednet.send(id, "start")
    else
        return false
    end
    return true
end
function isMaterials(types)
    if turtle.getItemCount(slot[types][2]) > 0 then
        slot[types][1] = 0 return true
    elseif turtle.getItemCount(slot[types][2]+1) > 0 then
        slot[types][1] = 1 return true
    elseif turtle.getItemCount(slot[types][2]+2) > 0 then
        slot[types][1] = 2 return true
    else
        if not LoadMaterials(slot[types][2],slot[types][4],slot[types][3]) then
            return false
        end
        return true
    end
end
--## Main ##
local tArgs = {...}
wait = false
doukiSend = false
doukiRecv = false
ia = Load() or 16
if tArgs[1] == "-t" then
    print("Command:turtle."..tostring(tArgs[2]).."()")
    local com = tArgs[2]
    local iz = tArgs[3] or 1
    if iz == 0 then return end
    if tArgs[2] == "right" then turtle.turnRight() com = "forward"
    elseif tArgs[2] == "left" then turtle.turnLeft() com = "forward" end
    for iv = 1,iz do
        turtle[com]()
    end
    if tArgs[2] == "left" then turtle.turnRight(); com = "left"
    elseif tArgs[2] == "right" then turtle.turnLeft() com = "right" end
    return
elseif tArgs[1] == "-h" then
    Help(tArgs[2])
    return true
elseif tArgs[1] == "-s" then
    rednet.open("right")
    doukiSend = true
    print("Start in douki sending mode!")
elseif tArgs[1] == "-r" then
    rednet.open("right")
    doukiRecv = true
    print("Start in douki recieving mode!")
elseif tArgs[1] == "-n" then
    ia = (tArgs[2]+4)%16
elseif tArgs[1] == "-u" then
    shell.run("pastebin","run","q0RehZjU",tArgs[2])
    return
end
slot = {["A"]={0,1,13,3,"Floor"},["B"]={0,5,15,3,"Rail"}}
parallel.waitForAll(
  function()
    while not isCan() do
        if doukiRecv then
            id,ip = rednet.receive()
            ia = tonumber(string.match(ip,"\$(%d+)"))
        end
        setRail()
        while not turtle.back() do sleep(4) end
    end
  end, function()
    if doukiSend then
      while true do
        local sid,sip = rednet.receive()
        if sip=="wait" then
          wait = true
        elseif sip=="start" then
          wait = false
        end
      end
    end
  end
)