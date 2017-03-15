-- Return current UTC time in string format
function Now()
    local rtc = rtctime.get()
    local tm = rtctime.epoch2cal(rtc)
    local now = string.format("%04d/%02d/%02d %02d:%02d:%02d",
        tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
    return now
end

--     local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
--     local result_en = {"Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous", "BEYOND INDEX"}
local Standards = {
  ["US"] = {
    ["PM 2.5"] = {
      ["High"] = {12.0, 35.4, 55.4, 150.4, 250.4, 350.4, 500.4},
      ["Low"] = {0, 12.1, 35.5, 55.5, 150.5, 250.5, 350.5}
    },
    ["PM 10"] = {
      ["High"] = {54, 154, 254, 354, 424, 504, 604},
      ["Low"] = {0, 55, 155, 255, 355, 425, 505}
    },
    ["AQI"] = {
      ["High"] = {50, 100, 150, 200, 300, 400, 500},
      ["Low"] = {0, 51, 101, 151, 201, 301, 401}
    }
  },
  ["CN"] = {
    ["PM 2.5"] = {
      ["High"] = {35, 75, 115, 150, 250, 350, 500},
      ["Low"] = {0, 35, 75, 115, 150, 250, 350}
    },
    ["PM 10"] = {
      ["High"] = {50, 150, 250, 350, 420, 500, 600},
      ["Low"] = {0, 50, 150, 250, 350, 420, 500}
    },
    ["AQI"] = {
      ["High"] = {50, 100, 150, 200, 300, 400, 500},
      ["Low"] = {0, 50, 100, 150, 200, 300, 400}
    }
  }
}

-- Calculate AQI number and level, given the ug/m3 values of PM2.5 and PM10
-- example, aqi_pm25, aqi_level = calcAQI(pm25_in_ug/m3, "CN", "PM 2.5")
function calcAQI(weight, subject, standard)
    local Ch = Standards[""..standard][""..subject]["High"]
    local Cl = Standards[""..standard][""..subject]["Low"]
    local Ih = Standards[""..standard]["AQI"]["High"]
    local Il = Standards[""..standard]["AQI"]["Low"]

    local l = 0
    for i=1, table.getn(Ch), 1 do
      l = i
      if(weight < Ch[i]) then
          break
      end
      l = i + 1
     end

    local aqi = 0
    if (l==table.getn(Ch)+1) then
        aqi = weight  -- above 500, beyond index
     else
        aqi = math.floor( (Ih[l] - Il[l]) * (weight - Cl[l]) /(Ch[l] - Cl[l]) + Il[l] )
     end

     return aqi, l
end
