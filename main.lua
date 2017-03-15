-- declaration
sensors = {}
PostData = nil
serverIP = nil
--pm1 = -1
pm25 = -1
pm10 = -1
PWM_FREQ = 1000


-- LED colors
aqiColor = {}
aqiColor[1] = {name="Green",r=0,g=255,b=0}      -- 0~50
aqiColor[2] = {name="Yellow",r=255,g=255,b=0}   -- 51~100
--aqiColor[3] = {name="Orange",r=255,g=165,b=0}   -- 101~150
aqiColor[3] = {name="Blue",r=0,g=0,b=255}   -- 101~150
aqiColor[4] = {name="Red",r=255,g=0,b=0}        -- 151~200
aqiColor[5] = {name="Purple",r=160,g=32,b=240}  -- 201~300
aqiColor[6] = {name="Maroon",r=139,g=28,b=98}   -- 301~400
aqiColor[7] = {name="Maroon",r=139,g=28,b=98}   -- 401~500
aqiColor[8] = {name="Maroon",r=139,g=28,b=98}   -- beyond index

pwm.setup(pinLED.r, PWM_FREQ, 0)
pwm.setup(pinLED.g, PWM_FREQ, 0)
pwm.setup(pinLED.b, PWM_FREQ, 0)
pwm.start(pinLED.r)
pwm.start(pinLED.g)
pwm.start(pinLED.b)

function lightAqiLED(level)
    pwm.setduty(pinLED.r, aqiColor[level].r*4)
    pwm.setduty(pinLED.g, aqiColor[level].g*4)
    pwm.setduty(pinLED.b, aqiColor[level].b*4)
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
        lcd.setCursor(1,0)
        lcd.print(string.format("Temp=%2d Humi=%2d   ",Temp,Hum))
    end
    -- read pm2.5 from Plantower PMS5003 sensor
    if (pm25 ~= -1 ) then
        -- sensors["pm1"] = pm1
        sensors[LW_ID_PM25] = pm25
        sensors[LW_ID_PM10] = pm10
        local aqi
        local level = 0, 0

        local aqi, level = calcAQI(pm25, "PM 2.5", "CN")
        local aqi10, level10 = calcAQI(pm10, "PM 10", "CN")
        if (aqi10>aqi) then aqi=aqi10;level=level10 end

        local aqi_us, _ = calcAQI(pm25, "PM 2.5", "US")
        aqi10, _ = calcAQI(pm10, "PM 10", "US")
        if (aqi10>aqi_us) then aqi_us=aqi10 end

        sensors[LW_ID_AQI] = aqi
        sensors[LW_ID_AQI_US] = aqi_us
        lcd.setCursor(0,0)
        lcd.print(string.format("AQI=%3d (US:%d)  ",aqi,aqi_us))
        lightAqiLED(level)   -- light on LED as AQI indicator
    end
end

-- read pm2.5 data from serial port RX
cnt = 1
a_pm1 = 0
a_pm25 = 0
a_pm10 = 0
DATA_NUM = 10    -- debug
bufferCursor = 1
local buffer = {}

uart.setup( 0, 9600, 8, 0, 1, 0 )
uart.on("data", 0, function (data)
--        if((string.len(data)==32) and (string.byte(data,1)==0x42) and (string.byte(data,2)==0x4d))  then
--      local data_len = string.len(data)
  local data_len = #data
    if (data_len > 32) then
        bufferCursor = 1
        return -- wrong data
      end
      if (string.byte(data,1)==0x42) then
        if(data_len==32) then
            if (string.byte(data,2)==0x4d)  then
              local sum = 0
              for i=1, 30, 1 do
                sum = sum + string.byte(data,i)
              end
              if (sum == (string.byte(data,31)*256 + string.byte(data,32)) )  then -- data verification
                pm25 = string.byte(data,13)*256 + string.byte(data,14)     -- PM 2.5 weight in ug/m3
                pm10 = string.byte(data,15)*256 + string.byte(data,16)     -- PM 10 weight in ug/m3
              else
                  print ("PMS Data verification error, code "..tostring(string.byte(data,30)))
              end
            end
            bufferCursor = 1
        else
          -- copy buffer
          bufferCursor = 1
          for i=1, data_len, 1 do
            buffer[bufferCursor+i-1] = string.byte(data,i)
            bufferCursor = bufferCursor + 1
          end
        end
      else  -- is a partial frame without head
        if (data_len + bufferCursor -1 > 32) then
          bufferCursor = 1
          return -- wrong data
        end
        -- copy buffer
        for i=1, data_len, 1 do
          buffer[bufferCursor] = string.byte(data,i)
          bufferCursor = bufferCursor + 1
        end
        if (bufferCursor > 32) then
          local sum = 0
          for i=1, 30, 1 do
            sum = sum + buffer[i]
          end
          if (sum == buffer[31]*256 + buffer[32] )  then -- data verification
            pm25 = buffer[13]*256 + buffer[14]     -- PM 2.5 weight in ug/m3
            pm10 = buffer[15]*256 + buffer[16]     -- PM 10 weight in ug/m3
          else
              print ("PMS Data verification error, code "..tostring(buffer[30]))
          end
          bufferCursor =  1
        end
      end
      -- debug
--       print (Now() .. "Dumping ...  length=" .. string.len(data))
--       print(string.gsub(data,"(.)",function (x) return string.format("%02X ",string.byte(x)) end))
end, 0)

-- upload sensor values
function Post()
--     sntp.sync()    -- be careful, don't invoke sntp.sync too frequently, that may crash the nodemcu system.
     ReadSensors()
     socket=net.createConnection(net.TCP, 0)
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
    end)

tmr.alarm(0,5000, tmr.ALARM_SINGLE, function(t)
  Post()
  tmrMain = tmr.create()
  tmrMain:alarm(INTERVAL_POST, tmr.ALARM_AUTO, function (t)
          Post()
      end)

end)
