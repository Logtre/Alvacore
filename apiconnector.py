#! /usr/bin/env python
# -*- coding: utf-8 -*-
import requests
import json
import logdefinition as logdef

class ApiConnector:

    def __init__(self, api_url):
        self.request_url = api_url
        self.url = ""
        self.response = []
        self.api_response_data = {
            "usd_rate": 0,
            "symbol": "",
            "volume_24h": 0,
            "timestamp": 0,
            "error": ""
        }

    def fetch_fxrate(self, arg):
        # goal: apiからresponseをgetする
        self.url = self.request_url.format(currency_code = arg)
        response = requests.get(self.url)

        if response:
            logdef.logger.info("sucess getting data from CMP API.")
            resp = response.json()
            self.api_response_data["usd_rate"] = resp["data"]["quotes"]["USD"]["price"]
            self.api_response_data["symbol"] = resp["data"]["symbol"]
            self.api_response_data["volume_24h"] = resp["data"]["quotes"]["USD"]["volume_24h"]
            self.api_response_data["timestamp"] = resp["metadata"]["timestamp"]
            self.api_response_data["error"] = resp["metadata"]["error"]

            if self.api_response_data["error"]:
                # error
                logdef.logger.error("fail to getting data from CMP API. err_msg is: {}".format(resp["metadata"]["error"]))
                return self.api_response_data, 3
            else:
                logdef.logger.info("sucess getting data from CMP API. response is: {}".format(self.api_response_data))
                return self.api_response_data, 0
        else:
            # error
            logdef.logger.error("cannot getting data from CMP API.")
            return self.api_response_data, 4


    def fetch_fxrate_pro(self, arg):

        self.response = requests.get(url, params = arg)

        if self.response:
            resp = response.json()
            self.api_response_data["usd_rate"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["price"]
            self.api_response_data["symbol"] = resp["data"]["symbol"]
            self.api_response_data["volume_24h"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["volume_24h_base"]
            self.api_response_data["timestamp"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["last_updated"]
            self.api_response_data["error"] = resp["status"]["error_code"]

            if self.api_response_data["error"]:
                # error get error response
                logdef.logger.error("fail to getting data from pro-CMP API. err_msg is: {}".format(resp["status"]["error_code"]))
                return self.api_response_data, self.api_response_data["error"]
            else:
                logdef.logger.error("success getting data from pro-CMP API.")
                return self.api_response_data, 0
        else:
            # error cannot get response
            logdef.logger.error("cannot getting data from pro-CMP API.")
            return self.api_response_data, 4
