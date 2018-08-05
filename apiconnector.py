#! /usr/bin/env python
# -*- coding: utf-8 -*-
import requests
import json

class ApiConnector:

    def __init__(self, api_url):
        self.request_url = api_url
        self.url = ""
        self.response = []

    def fetch_fxrate(api_resp, code):
        # goal: apiからresponseをgetする
        url = request_url.format(currency_code = code)
        response = requests.get(url)

        if response:
            resp = response.json()
            api_resp["usd_rate"] = resp["data"]["quotes"]["USD"]["price"]
            api_resp["symbol"] = resp["data"]["symbol"]
            api_resp["volume_24h"] = resp["data"]["quotes"]["USD"]["volume_24h"]
            api_resp["timestamp"] = resp["metadata"]["timestamp"]
            api_resp["error"] = resp["metadata"]["error"]

            if api_resp["error"]:
                # error
                return api_resp, 3
            else:
                return api_resp, 0
        else:
            # error
            return api_resp, 4


    def fetch_fxrate_pro(api_resp, payload):

        response = requests.get(url, params=payload)

        if response:
            resp = response.json()
            api_resp["usd_rate"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["price"]
            api_resp["symbol"] = resp["data"]["symbol"]
            api_resp["volume_24h"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["volume_24h_base"]
            api_resp["timestamp"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["last_updated"]
            api_resp["error"] = resp["status"]["error_code"]

            if api_resp["error"]:
                # error get error response
                return api_resp, api_resp["error"]
            else:
                return api_resp, 0
        else:
            # error cannot get response
            return api_resp, 4
