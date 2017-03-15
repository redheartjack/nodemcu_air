-- declarations
dofile("credentials")
pinLED = {i=4,r=7,g=5,b=6}    -- Pins for internal/red/green/blue LED
pinDHT = 8 -- D6/GPIO12 <==> DHT11 data pin 2
LW_Server = "open.lewei50.com"
LW_Gateway = "01"
--LW_SN = "xxxxxxxxxxxxxx"
LW_ID_AQI = "aqi"
LW_ID_AQI_US = "aqi_us"
LW_ID_PM25 = "pm25"
LW_ID_PM10 = "pm10"
LW_ID_Temp = "temp"
LW_ID_Humi = "humi"
--WIFI_SSID = "xxxx"
--WIFI_PWD = "xxxx"
INTERVAL_POST = 30000   -- debug

function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        file.close("init.lua")
        print("Running main.lua")
        -- the actual application is stored in 'main.lua'
        dofile("main.lua")
    end
end

-- load functions from misc.lua
misc = require("misc")

-- Initial LCD 1602
LCD_SDA = 3
LCD_SCL = 4
LCD_ADDR = 0x3F

lcd = require("lcd1602")
lcd.begin(LCD_SDA, LCD_SCL,LCD_ADDR)
lcd.setBacklight(1)
lcd.setCursor(0,0)
lcd.print("Home Environment")
lcd.setCursor(1,0)
lcd.print("Connecting WiFi  ")

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

-- LED
gpio.mode(pinLED.i, gpio.OUTPUT)
gpio.write(pinLED.i, gpio.LOW)
gpio.mode(pinLED.r, gpio.OUTPUT)
gpio.write(pinLED.r, gpio.LOW)
gpio.mode(pinLED.g, gpio.OUTPUT)
gpio.write(pinLED.g, gpio.LOW)
gpio.mode(pinLED.b, gpio.OUTPUT)
gpio.write(pinLED.b, gpio.LOW)

-- wait for connection
tmrInitWifi = tmr.create()
cnt = 0
tmrInitWifi:alarm(1000, tmr.ALARM_SEMI, function (t)
        if (wifi.sta.status() == 5) then
            t:unregister()
            gpio.write(pinLED.i, gpio.HIGH) -- Success
            lcd.setCursor(1,0)
            lcd.print(wifi.sta.getip().."         ")
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
            gpio.write(pinLED.i, cnt%2)   -- In progress
            t:start() -- restart timer
        else
            gpio.write(pinLED.i, gpio.LOW) -- Error
            print("Wifi err. Status code " .. wifi.sta.status())
            lcd.setCursor(1,0)
            lcd.print("Wifi error " .. wifi.sta.status().."    ")
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
