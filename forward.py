#! /usr/bin/env python
# -*- coding: utf-8 -*-

from moddata import ModifyData
from apiconnector import ApiConnector
from ethconnector import ETHConnector
from dynamoconnector import DynamoConnector
#from errorprocessor import ErrorChecker
#from hashprocessor import CreateCheckHash

import json

FWD_ORDERLY_CONTRACT = "0xeDdF01f7C58664660c26624dE8521Da6aD337f7f"

with open("/home/ubuntu/web3/ForwardOrderly_ABI.json") as fwd:
    FWD_ABI = json.load(fwd)

with open("/home/ubuntu/web3/CMP_API_KEY.json") as cmp_key:
    CMP_KEY = json.load(cmp_key)

# APIの雛形(公開)
pub_cmp_api = "https://api.coinmarketcap.com/v2/ticker/{currency_code}"
# CMP APIリクエスト用の通貨コード
PUB_CMP_CODE = {"BTC": 1, "ETH": 1027, "ETC": 1321, "BCC": 1831, "EOS": 1765}

# APIの雛形(PRO用)
#pro_cmp_api = " https://pro-api.coinmarketcap.com/v1/cryptocurrency/market-pairs/latest"
# クエリ
#cmp_payload = {'CMC_PRO_API_KEY':CMP_KEY, 'symbol':''}

api_con = ApiConnector(pub_cmp_api) # PUBLIC API
#api_con = ApiConnector(pro_cmp_api) # PRO API
eth_con = ETHConnector(FWD_ORDERLY_CONTRACT, FWD_ABI)
#create_hash = CreateCheckHash()
mod_data = ModifyData()
#err_check = ErrorChecker()

err_code = 0

request_data = {
    'request_id':0,
    'request_type':0,
    'timestamp':0,
    'request_state':"",
    'request_data':""
}

api_response_data = {
    "usd_rate": 0,
    "symbol": "",
    "volume_24h": 0,
    "timestamp": 0,
    "error": ""
}

response_data = {
    'request_id': 0,
    'params_hash': "",
    'error': 0,
    'resp_data': 0
}

def get_forward_fxrate():

    # ETH node経由でOrderlyコントラクトからrequestを取得
    request_data, params_hash, err_code = eth_con.read_request(request_data)

    if err_code < 2:
        # API経由でCoinMarketCapからresponseを取得
        api_response_data, err_code = api_con.fetch_fxrate(api_response_data, PUB_CMP_CODE[request_data["request_data"]])

    #if err_code < 2:
        # プロ用API経由でCoinMarketCapからresponseを取得
        #api_response_data ,err_code = api_con.fetch_fxrate_pro(api_response_data, request_data["request_data"])


    response_data = mod_data.modify_response_data(response_data, request_data_data, params_hash, err_code, api_response_data)
    # ETH node経由でOrderlyコントラクトにresponseを連携
    response_send = eth_con.deliver_response(response_data)
