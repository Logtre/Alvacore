#! /usr/bin/env python
# -*- coding: utf-8 -*-

from moddata import CreateCheckHash, ModifyData
from apiconnector import ApiConnector
from ethconnector import ETHConnector
from dynamoconnector import DynamoConnector

import json

FWD_ORDERLY_CONTRACT = "0xeDdF01f7C58664660c26624dE8521Da6aD337f7f"

with open("/home/ubuntu/web3/Forward_ABI.json") as fwd:
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
create_hash = CreateCheckHash()
mod_data = ModifyData()


def get_forward_fxrate():

    # ETH node経由でOrderlyコントラクトからrequestを取得
    org_request = eth_con.read_request(FWD_ORDERLY_CONTRACT, FWD_ABI)

    # ParamsHash計算用に元のデータ型のrequestを退避
    org_request_type = request[1]
    org_request_data = request[4]

    # requestデータを取り扱いしやすいように整形
    request_data = mod_data.modify_request_data(org_request)

    # API経由でCoinMarketCapからresponseを取得
    api_response = api_con.fetch_fxrate(PUB_CMP_CODE[request_data["request_data_message"]])
    # responseをjson形式に変換
    api_response_json = mod_data.modify_api_response_data(api_response)

    # プロ用API経由でCoinMarketCapからresponseを取得
    #cmp_payload["symbol"] = request_data["request_data_message"]
    # responseをjson形式に変換
    #api_response = api_con.fetch_fxrate_pro(cmp_payload)

    # checkdigitを付与
    check_params_hash = create_hash.create_check_hash(org_request_type, org_request_data)

    if check_params_hash:
        response_data = mod_data.modify_response_data(request_data, check_params_hash, api_response_json)
        # ETH node経由でOrderlyコントラクトにresponseを連携
        response_send = eth_con.provide_response(response_data)
