-- declaration
sensors = {}
PostData = nil
serverIP = nil
pm10 = -1
pm25 = -1
pm100 = -1

-- Return current UTC time in string format
function Now()
    local rtc = rtctime.get()
    local tm = rtctime.epoch2cal(rtc)
    local now = string.format("%04d/%02d/%02d %02d:%02d:%02d", 
        tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
    return now
end

function calcAQI(pNum)
     --local clow = {0,15.5,40.5,65.5,150.5,250.5,350.5}
     --local chigh = {15.4,40.4,65.4,150.4,250.4,350.4,500.4}
     --local ilow = {0,51,101,151,201,301,401}
     --local ihigh = {50,100,150,200,300,400,500}
     local ipm25 = {0,35,75,115,150,250,350,500}
     local laqi = {0,50,100,150,200,300,400,500}
     local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
     --print(table.getn(chigh))
     aqiLevel = 8
     for i = 1,table.getn(ipm25),1 do
          if(pNum < ipm25[i]) then
               aqiLevel = i
               break
          end
     end
     --aqiNum = (ihigh[aqiLevel]-ilow[aqiLevel])/(chigh[aqiLevel]-clow[aqiLevel])*(pNum-clow[aqiLevel])+ilow[aqiLevel]
     aqiNum = (laqi[aqiLevel]-laqi[aqiLevel-1])/(ipm25[aqiLevel]-ipm25[aqiLevel-1])*(pNum-ipm25[aqiLevel-1])+laqi[aqiLevel-1]
     return math.floor(aqiNum),result[aqiLevel-1]
end

function ReadSensors()
--  clean last data
    for i,v in pairs(sensors) do 
        sensors[i] = nil
    end
-- read temperature and humidity from DHT11 sensor
    local status, Temp, Hum = dht.read(pinDHT)
    if status == dht.OK then
        sensors[LW_ID_Temp] = Temp
        sensors[LW_ID_Humi] = Hum
    end
    -- read pm2.5 from Plantower PMS5003 sensor
    if (pm25 ~= -1 ) then 
        -- sensors["pm10"] = pm10
        sensors[LW_ID_PM25] = pm25
        sensors[LW_ID_PM100] = pm100
        aqi,result = calcAQI(pm25)
        sensors[LW_ID_AQI] = aqi
        --sensors["air_quality"] = result
    end
end

-- read pm2.5 data from serial port RX
cnt = 1
a_pm10 = 0 
a_pm25 = 0
a_pm100 = 0
DATA_NUM = 10
uart.setup( 0, 9600, 8, 0, 1, 0 )
uart.on("data", 0,  function(data)
        if((string.len(data)==32) and (string.byte(data,1)==0x42) and (string.byte(data,2)==0x4d))  then
          --a_pm10 = a_pm10 + (string.byte(data,11)*256 + string.byte(data,12))
          a_pm25 = a_pm25 + string.byte(data,13)*256 + string.byte(data,14)
          a_pm100 = a_pm100 + string.byte(data,15)*256 + string.byte(data,16)
          if (cnt < DATA_NUM) then 
            cnt = cnt + 1
          else
            --pm10 = math.floor(a_pm10 / DATA_NUM)
            pm25 = math.floor(a_pm25 / DATA_NUM)
            pm100 = math.floor(a_pm100 / DATA_NUM)
            --a_pm10 = 0
            a_pm25 = 0
            a_pm100 = 0
            cnt = 1
          end
        end
    end, 0)


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
--        Post()
    end)
tmrMain = tmr.create()
tmrMain:alarm(INTERVAL_POST, tmr.ALARM_AUTO, function (t)
        Post()
    end)
