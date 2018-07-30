#! /usr/bin/env python
# -*- coding: utf-8 -*-
import requests

class ApiConnector:

    def __init__(self, api_url):
        self.request_url = api_url
        self.url = ""
        self.response = 0

    # 削除候補
    #def cmp_code_detector(request_data):
    #    currency_code = request_data[2] # <---本当に2か確認
    #    # これ以降はあとで書く(観点：walletによって、requestdataの認識具合、固定長だったりが違う。)
    #    return currency_code

    def fetch_fxrate(code):
        # goal: apiからresponseをgetする
        url = request_url.format(currency_code = code)
        response = requests.get(url)

        if response:
            return response
        else:
            # error
            return False
