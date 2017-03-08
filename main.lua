-- declaration
sensors = {}
PostData = nil
serverIP = nil

-- Return current UTC time in string format
function Now()
    local rtc = rtctime.get()
    local tm = rtctime.epoch2cal(rtc)
    local now = string.format("%04d/%02d/%02d %02d:%02d:%02d", 
        tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
    return now
end

function ReadSensors()
--  clean last data
    for i,v in pairs(sensors) do 
        sensors[i] = nil
    end
-- read temperature and humidity from DHT11 sensor
    local status, Temp, Hum = dht.read(pinDHT)
    if status == dht.OK then
        print("DHT Temperature:"..Temp.."℃; Humidity:"..Hum.."%\r\n")
        sensors["T1"] = Temp
        sensors["H1"] = Hum
    elseif status == dht.ERROR_CHECKSUM then
        print( "DHT Checksum error." )
    elseif status == dht.ERROR_TIMEOUT then
        print( "DHT timed out." )
    end
    -- read pm2.5 from Plantower PMS5003 sensor
    sensors["dust"] = nil
    sensors["AQI"] = nil
--    return sensors
end

-- upload sensor values
function Post()
--     sntp.sync()
     ReadSensors()
     socket=net.createConnection(net.TCP, 0)
--[[     if(serverIP == nil) then
        net.dns.resolve(LW_Server, function(conn, ip)
--        socket:dns(LW_Server, function(conn, ip)
            serverIP = ip
            end)
     end
--]]
     socket:connect(80, serverIP)
     socket:on("connection", function(sck, response)
        PostData = "["
        for i,v in pairs(sensors) do 
            PostData = PostData .. '{"Name":"'..i..'","Value":"' .. v .. '"},'
        end
        len = string.len(PostData)
        PostData  = "POST /api/V1/gateway/UpdateSensors/".. LW_Gateway .. 
            " HTTP/1.1\r\nuserkey:" .. LW_SN .. 
            "\r\nHost:open.lewei50.com\r\nContent-Length:" .. len ..
            "\r\nConnection: close\r\n\r\n" ..
            string.sub(PostData,1,len-1)  .. "]"
        print(PostData) -- debug
        socket:send(PostData)
     end)
     
    socket:on("disconnection", function(sck, response)
        if (response ~= nil) then print("disconnection code "..response) end --debug
     end)
     
    socket:on("reconnection", function(sck, response)
        if (response ~= nil) then print("reconnection code  "..response) end --debug
     end)

    socket:on("sent", function(sck, response)
                print("[UTC]"..Now().." sent\r\n")
        end)
     
     socket:on("receive", function(sck, response)
          print("[UTC]"..Now().." received bytes ".. string.len(response))
          print(response)
          socket:close()
--        collectgarbage(); -- debug
          print("Heap="..node.heap()) -- debug
        end)
end

-- An infinite loop for read sensors and post the values to cloud
print("Begin at UTC time "..Now())
net.dns.resolve(LW_Server, function(conn, ip)
        serverIP = ip
        Post()
    end)
tmrMain = tmr.create()
tmrMain:alarm(INTERVAL_POST, tmr.ALARM_AUTO, function (t)
        Post()
    end)