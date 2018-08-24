#! /usr/bin/env python
# -*- coding: utf-8 -*-
import requests
import json
"""import logging

logger = logging.getLogger(__name__)
for h in logger.handlers:
  logger.removeHandler(h)

h = logging.StreamHandler(sys.stdout)

FORMAT = '%(levelname)s %(asctime)s [%(funcName)s] %(message)s'
h.setFormatter(logging.Formatter(FORMAT))
logger.addHandler(h)

logger.setLevel(logging.INFO)"""

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
        url = request_url.format(currency_code = arg)
        response = requests.get(url)

        if response:
            logger.info("sucess getting data from CMP API. response is: {}".format(response))
            resp = response.json()
            api_response_data["usd_rate"] = resp["data"]["quotes"]["USD"]["price"]
            api_response_data["symbol"] = resp["data"]["symbol"]
            api_response_data["volume_24h"] = resp["data"]["quotes"]["USD"]["volume_24h"]
            api_response_data["timestamp"] = resp["metadata"]["timestamp"]
            api_response_data["error"] = resp["metadata"]["error"]

            if api_response_data["error"]:
                # error
                logger.error("fail to getting data from CMP API. err_msg is: {}".format(resp["metadata"]["error"]))
                return api_response_data, 3
            else:
                logger.error("success getting data from CMP API.")
                return api_response_data, 0
        else:
            # error
            logger.error("cannot getting data from CMP API.")
            return api_response_data, 4


    def fetch_fxrate_pro(self, arg):

        response = requests.get(url, params = arg)

        if response:
            resp = response.json()
            api_response_data["usd_rate"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["price"]
            api_response_data["symbol"] = resp["data"]["symbol"]
            api_response_data["volume_24h"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["volume_24h_base"]
            api_response_data["timestamp"] = resp["data"]["market_pairs"]["quote"]["exchange_reported"]["last_updated"]
            api_response_data["error"] = resp["status"]["error_code"]

            if api_response_data["error"]:
                # error get error response
                logger.error("fail to getting data from pro-CMP API. err_msg is: {}".format(resp["status"]["error_code"]))
                return api_response_data, api_response_data["error"]
            else:
                logger.error("success getting data from pro-CMP API.")
                return api_response_data, 0
        else:
            # error cannot get response
            logger.error("cannot getting data from pro-CMP API.")
            return api_response_data, 4
