-- Return current UTC time in string format
function Now()
    local rtc = rtctime.get()
    local tm = rtctime.epoch2cal(rtc)
    local now = string.format("%04d/%02d/%02d %02d:%02d:%02d",
        tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
    return now
end

     local std_25 = {0,35,75,115,150,250,350,500}        -- China PM2.5 standard, http://kjs.mep.gov.cn/hjbhbz/bzwb/dqhjbh/jcgfffbz/201203/W020120410332725219541.pdf, p8
     local std_10 = {0,50,150,250,350,420,500,600}        -- China PM10 standard, as above
--std_25 = {0,12.0,35.4,55.4,150.4,250.4,350.4,500.4}   -- US PM2.5 standard, https://www.gpo.gov/fdsys/pkg/FR-2013-01-15/pdf/2012-30946.pdf, p202
--std_10 = {0,54,154,254,354,424,504,604}   -- US PM10 standard, as above
std_AQI = {0,50,100,150,200,300,400,500}    -- AQI levels
--     local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
--     local result_en = {"Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous", "BEYOND INDEX"}

-- Calculate AQI number and level, given the ug/m3 values of PM2.5 and PM10
function calcAQI(w25, w10)
     local aqi_25, aqi_10 = 0, 0
     -- calculate PM2.5 sub-index
     local l = 8
     for i = 2,table.getn(std_25),1 do
          if(w25 < std_25[i]) then
               l = i-1
               break
          end
     end
    if (l==8) then
        aqi_25 = w25  -- above 500, beyond index
     else
        aqi_25 = math.floor( (std_AQI[l+1]-std_AQI[l])/(std_25[l+1]-std_25[l])*(w25-std_25[l])+std_AQI[l] )
     end
    level = l

    -- calculate PM10 sub-index
     local l = 8
     for i = 2,table.getn(std_10),1 do
          if(w25 < std_10[i]) then
               l = i-1
               break
          end
     end

     if (l==8) then
        aqi_10 = w10  -- above 500, beyond index
     else
        aqi_10 = math.floor( (std_AQI[l+1]-std_AQI[l])/(std_10[l+1]-std_10[l])*(w10-std_10[l])+std_AQI[l] )
     end
    level = math.max(level, l)

     return math.max(aqi_25, aqi_10), level
end
