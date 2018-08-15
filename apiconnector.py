#! /usr/bin/env python
# -*- coding: utf-8 -*-
import requests
import json

class ApiConnector:

    def __init__(self, api_url):
        self.request_url = api_url
        self.url = ""
        self.response = []

    def fetch_fxrate(arg1, arg2):
        # goal: apiからresponseをgetする
        url = request_url.format(currency_code = arg2)
        response = requests.get(url)

        if response:
            resp = response.json()
            arg1["usd_rate"] = resp["data"]["quotes"]["USD"]["price"]
            arg1["symbol"] = resp["data"]["symbol"]
            arg1["volume_24h"] = resp["data"]["quotes"]["USD"]["volume_24h"]
            arg1["timestamp"] = resp["metadata"]["timestamp"]
            arg1["error"] = resp["metadata"]["error"]

            if arg1["error"]:
                # error
                return arg1, 3
            else:
                return arg1, 0
        else:
            # error
            return arg1, 4


    def fetch_fxrate_pro(arg1, arg2):

        response = requests.get(url, params=arg2)

        if response:
            resp = response.json()
            arg1["usd_rate"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["price"]
            arg1["symbol"] = resp["data"]["symbol"]
            arg1["volume_24h"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["volume_24h_base"]
            arg1["timestamp"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["last_updated"]
            arg1["error"] = resp["status"]["error_code"]

            if arg1["error"]:
                # error get error response
                return arg1, arg1["error"]
            else:
                return arg1, 0
        else:
            # error cannot get response
            return arg1, 4
