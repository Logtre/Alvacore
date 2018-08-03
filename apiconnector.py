#! /usr/bin/env python
# -*- coding: utf-8 -*-
import requests

class ApiConnector:

    def __init__(self, api_url):
        self.request_url = api_url
        self.url = ""
        self.response = 0

    def fetch_fxrate(code):
        # goal: apiからresponseをgetする
        url = request_url.format(currency_code = code)
        response = requests.get(url)

        if response:
            return response
        else:
            # error
            return False


    def fetch_fxrate_pro(payload):

        response = requests.get(url, params=payload)

        if response:
            return response
        else:
            # error
            return False
