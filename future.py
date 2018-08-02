#! /usr/bin/env python
# -*- coding: utf-8 -*-

from moddata import CreateCheckHash, ModifyData
from apiconnector import ApiConnector
from ethconnector import ETHConnector
from dynamoconnector import DynamoConnector

import time
import json
from datetime import date

FUT_ORDERLY_CONTRACT = "0x0000000000000000000000000000000000000000"

with open("Future_ABI.json") as fut:
    FUT_ABI = json.load(fut)

# CMP APIリクエスト用の通貨コード
CMP_CODE = {"BTC": 1, "ETH": 294, "ETC": 408, "BCC": 498, "EOS": 665}
# APIの雛形
cmp_api = "https://api.coinmarketcap.com/v2/ticker/{currency_code}"

api_con = ApiConnector(cmp_api)
create_hash = CreateCheckHash()
mod_data = ModifyData()


def set_future_reservation():

    eth_con = ETHConnector(FUT_ORDERLY_CONTRACT, FUT_ABI)
    dynamo_con = DynamoConnector("fut_request")

    # ETH node経由でOrderlyコントラクトからrequestを取得
    reserve = eth_con.read_request(FUT_ORDERLY_CONTRACT, FUT_ABI)
    # requestデータを取り扱いしやすいように整形
    reserve_data = mod_data.modify_request_data(reserve)
    # AWSのAPI経由でDynamoにrequestを保存
    dynamo_insert_flag = dynamo_con.create_fut_reservation(reserve_data)

    if dynamo_insert_flag:
        return
    else:
        # error
        False


def get_future_fxrate():

    eth_con = ETHConnector(FUT_ORDERLY_CONTRACT, FUT_ABI)
    dynamo_con = DynamoConnector("fut_request")

    # （request保存と同時に）AWSのAPI経由でDynamo上の条件に合致するrequestを取得（複数）
    today = date.today()
    requests = dynamo_con.read_fut_reservation(today)
    # （ループ）
    for request_data in requests:
        # API経由でCoinMarketCapからresponseを取得
        api_response = api_con.fetch_fxrate(CMP_CODE[request_data["request_data_message"]])
        # responseをjson形式に変換
        api_response_json = mod_data.modify_api_response_data(api_response)
        #AWSのAPI経由でDynamo上のrequestを更新
        dynamo_modify_flag = dynamo_con.update_fut_request(request_data["request_id"], api_response_json)
        # checkdigitを付与
        request_detail = [request_data["request_data_type"], request_data["request_data_length"], request_data["request_data_message"]]
        check_params_hash = create_hash.create_check_hash(request["request_type"],request_detail)

        if check_params_hash:
            response_data = mod_data.modify_response_data(request_data, check_params_hash, api_response_json)
            # ETH node経由でOrderlyコントラクトにresponseを連携
            response_send = eth_con.provide_response(response_data)
