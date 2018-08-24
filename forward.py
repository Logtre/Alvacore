#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys,os
sys.path.append(os.path.dirname(os.path.abspath(__file__)) + '/lib')

from moddata import ModifyData
from apiconnector import ApiConnector
from ethconnector import ETHConnector
#from dynamoconnector import DynamoConnector
#from errorprocessor import ErrorChecker
from hashprocessor import CreateCheckHash

import json
import logdefinition as logdef

###### for LOCAL ######
# Ropsten
FWD_ORDERLY_CONTRACT = "0x849D10cd04e736e9FF176390849792F04781480F"
# Rinkeby
# FWD_ORDERLY_CONTRACT = ""
# Mainnet
# FWD_ORDERLY_CONTRACT = ""

with open("/Users/user/ubuntu/web3/FwdOrderly_ABI.json") as fwd:
    FWD_ABI = json.load(fwd)

#with open("/Users/user/ubuntu/web3/CMP_API_KEY.json") as cmp_key:
#    CMP_KEY = json.load(cmp_key)

"""
###### for AWS ######
# Ropsten
FWD_ORDERLY_CONTRACT = "0x3139F276560577b9f34E18D0d4fa6fC51d1459Ac"
# Rinkeby
# FWD_ORDERLY_CONTRACT = ""
# Mainnet
# FWD_ORDERLY_CONTRACT = ""

with open("/home/ubuntu/web3/FwdOrderly_ABI.json") as fwd:
    FWD_ABI = json.load(fwd)

with open("/home/ubuntu/web3/CMP_API_KEY.json") as cmp_key:
    CMP_KEY = json.load(cmp_key)
"""

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

def get_forward_fxrate():

    # ETH node経由でOrderlyコントラクトからrequestを取得
    logdef.logger.info("strat connecting to BCNetwork for get data.")
    request_data, params_hash, err_code = eth_con.read_request()

    if err_code < 2:
        # API経由でCoinMarketCapからresponseを取得
        logger.info("start connecting to CMP API.")
        api_response_data, err_code = api_con.fetch_fxrate(PUB_CMP_CODE[request_data["request_data"]])

    #if err_code < 2:
        # プロ用API経由でCoinMarketCapからresponseを取得
        #api_response_data ,err_code = api_con.fetch_fxrate_pro(api_response_data, request_data["request_data"])

    logger.info("start modifying response data.")
    response_data = mod_data.modify_response_data(request_data, params_hash, err_code, api_response_data)
    # ETH node経由でOrderlyコントラクトにresponseを連携
    logger.info("start connecting to BCNetwork for deliver data.")
    response_send = eth_con.deliver_response(response_data)
    return

get_forward_fxrate()
