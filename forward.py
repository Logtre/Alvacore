#! /usr/bin/env python
# -*- coding: utf-8 -*-

from moddata import CreateCheckHash, ModifyData
from apiconnector import ApiConnector
from ethconnector import ETHConnector
from dynamoconnector import DynamoConnector

import time
import json
from datetime import date

FWD_ORDERLY_CONTRACT = "0xeDdF01f7C58664660c26624dE8521Da6aD337f7f"

with open("Forward_ABI.json") as fwd:
    FWD_ABI = json.load(fwd)

# CMP APIリクエスト用の通貨コード
CMP_CODE = {"BTC": 1, "ETH": 294, "ETC": 408, "BCC": 498, "EOS": 665}
# APIの雛形
cmp_api = "https://api.coinmarketcap.com/v2/ticker/{currency_code}"

api_con = ApiConnector(cmp_api)
create_hash = CreateCheckHash()
mod_data = ModifyData()

# fwd処理

def get_forward_fxrate():

    eth_con = ETHConnector(FWD_ORDERLY_CONTRACT, FWD_ABI)

    # ETH node経由でOrderlyコントラクトからrequestを取得
    request = eth_con.read_request(FWD_ORDERLY_CONTRACT, FWD_ABI)
    # requestデータを取り扱いしやすいように整形
    request_data = mod_data.modify_request_data(request)
    # API経由でCoinMarketCapからresponseを取得
    api_response = api_con.fetch_fxrate(CMP_CODE[request_data["request_data_message"]])
    # responseをjson形式に変換
    api_response_json = mod_data.modify_api_response_data(api_response)
    # checkdigitを付与
    request_detail = [request_data["request_data_type"], request_data["request_data_length"], request_data["request_data_message"]]
    check_params_hash = create_hash.create_check_hash(request["request_type"], request_detail)

    if check_params_hash:
        response_data = mod_data.modify_response_data(request_data, check_params_hash, api_response_json)
        # ETH node経由でOrderlyコントラクトにresponseを連携
        response_send = eth_con.provide_response(response_data)
