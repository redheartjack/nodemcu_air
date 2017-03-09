-- declarations
dofile("credentials")
pinLED = 4
pinDHT = 6 -- D6/GPIO12 <==> DHT11 data pin 2
LW_Server = "open.lewei50.com"
LW_Gateway = "01"
--LW_SN = "xxxxxxxxxxxxxx"
LW_ID_AQI = "aqi"
LW_ID_PM25 = "pm25"
LW_ID_PM100 = "pm100"
LW_ID_Temp = "temp"
LW_ID_Humi = "humi"
--WIFI_SSID = "xxxx"
--WIFI_PWD = "xxxx"
INTERVAL_POST = 20000

function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in 'main.lua'
        dofile("main.lua")
    end
end

-- initial wifi
print("Connecting to WiFi access point...")
station_cfg={}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd = WIFI_PWD
station_cfg.auto = true 
station_cfg.save = true
wifi.setmode(wifi.STATION)
wifi.sta.autoconnect(1)
wifi.sta.config(station_cfg)
--wifi.sta.connect()    -- auto-connect

-- LED debug
gpio.mode(pinLED, gpio.OUTPUT)
gpio.write(pinLED, gpio.LOW)

-- wait for connection
tmrInitWifi = tmr.create()
cnt = 0
tmrInitWifi:alarm(1000, tmr.ALARM_SEMI, function (t) 
        if (wifi.sta.status() == 5) then
            t:unregister()
            gpio.write(pinLED, gpio.HIGH) -- Success
            print("Wifi network: "..wifi.sta.getip())
            print("You have 3 seconds to abort")
            print("Waiting...")
            -- Sync time
            --rtctime.get()
            sntp.sync()
            tmr.alarm(0,3000, tmr.ALARM_SINGLE, startup)
        elseif (cnt <30) then 
            cnt = cnt+1
            print(cnt) -- debug
            gpio.write(pinLED, cnt%2)   -- In progress 
            t:start() -- restart timer
        else
            gpio.write(pinLED, gpio.LOW) -- Error
            print("Wifi err. Status code " .. wifi.sta.status())
            wifi.sta.disconnect()
            -- Reinitial wifi
            wifi.setmode(wifi.STATION)
            station_cfg={}
            station_cfg.ssid = WIFI_SSID
            station_cfg.pwd = WIFI_PWD
            station_cfg.auto = true 
            station_cfg.save = true
            wifi.sta.config(station_cfg)
            wifi.sta.autoconnect(1)
            wifi.sta.connect()
            t:interval(30000)   -- increase interval to 30 seconds
            t:start()   -- Retry forever
        end
    end)
