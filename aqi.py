#!/usr/bin/python3
# -*- coding:utf-8 -*- 

import urllib.request
import json
import time
#from datetime import datetime, date, time

TOKEN_PM25IN = 'YpQx4AByXgTMxEa1YL1k'
TOKEN_LEWEI = 'd817f6d452e54b0691366fa0122b59b8 '

def store(data):
    with open('data.json', 'w') as json_file:
        json_file.write(json.dumps(data))

def load():
    with open('data.json') as json_file:
        data = json.load(json_file)
        return data

def get_aqi_by_station(station_code='1149A'):
    url = 'http://www.pm25.in/api/querys/aqis_by_station.json?token='  \
          + TOKEN_PM25IN + '&station_code=' + station_code
    station = {}
    try: 
        response = urllib.request.urlopen(url)
        if(response.getcode() == 200):
            content = response.read()
            station, = json.loads(content)  # the content is a list and consists of only one dictionary
            print(station)
            # store(station)
    except Exception as err: #  bad practice but suit for the need here
        print(err)
    if 'aqi' in station.keys():
        return station['aqi']
    elif 'error' in station.keys():
        return station['error']
    else:
        return 'Unkown error in' + __name__

def post(data):
    url = 'http://www.lewei50.com/api/V1/gateway/UpdateSensors/01' \
           +'?userkey=' +  TOKEN_LEWEI
    content =   json.dumps(data)
    try:
        request=urllib.request.Request(url,  content.encode('utf-8'))
        # print(request.data)
        response = urllib.request.urlopen(request)
        if(response.getcode() == 200):
            print(response.read().decode('utf-8'))
    except Exception as err: #  bad practice but suit for the need here
         print(err)
         
      
if __name__ ==  '__main__':
    while True:
        print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) )
        aqi_o = get_aqi_by_station()
        if (isinstance(aqi_o, int)):
            data = [{'Name': 'aqi_o', 'Value': aqi_o}]
            post(data)
        time.sleep(1800)    
