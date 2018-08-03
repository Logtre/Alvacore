#! /usr/bin/env python
# -*- coding: utf-8 -*-
import hashlib
from web3 import Web3
import json

#from apiconnector import ApiConnector
#from ethconnector import ETHConnector
#from dynamoconnector import DynamoConnector
#from queueworker import QueueWorker




class ModifyData:

    def __init__(self):
        self.resp = {}

    def extract_text(input_text):
        extracted_text = input_text.decode('utf-8').replace('\x00', '')


    def modify_request_data(request):
        request_data = {
            'request_id':request[0],
            'request_type':request[1],
            'timestamp':request[3],
            'request_state':extract_text(request[4]),
            'request_data':extract_text(request[5])
        }

        return request_data


    def modify_response_data(request, params_hash, response):

        response_data = {
            'request_id': request['request_id'],
            'params_hash': params_hash,
            'error': 0,
            'resp_data': response['usd_rate']
        }

        return response_data



    def modify_api_response_data(api_response):
        # goal: responseをjson形式に直す
        resp = api_response.json()

        response_data = {
            "usd_rate": resp["data"]["quotes"]["USD"]["price"],
            "symbol": resp["data"]["symbol"],
            "volume_24h": resp["data"]["quotes"]["USD"]["volume_24h"],
            "timestamp": resp["metadata"]["timestamp"],
            "error_message": resp["metadata"]["error"]
        }

        if not response_data["error_message"]:
            return response_data
        else:
            # error
            return False



def modify_api_response_data_pro(api_response):
    # goal: responseをjson形式に直す
    resp = api_response.json()

    response_data = {
        "usd_rate": resp["data"]["market_pairs"]["quote"]["exchange_reported"]["price"],
        "symbol": resp["data"]["symbol"],
        "volume_24h": resp["data"]["market_pairs"]["quote"]["exchange_reported"]["volume_24h_base"],
        "timestamp": resp["data"]["market_pairs"]["quote"]["exchange_reported"]["last_updated"],
        "error_code": resp["status"]["error_code"],
        "error_message": resp["status"]["error_message"]
    }

    if not response_data["error_message"]:
        return response_data
    else:
        # error
        return False


class CreateCheckHash:

    def __init__(self):
        self.check_hash = ""

    def create_check_hash(request_type, request_data):

        #check_hash = hashlib.sha256(request_type, request_data).hexdigest()
        check_hash = Web3.soliditySha3(['uint8', 'bytes32'], [request_type, request_data]).hex()[2:]

        if check_hash:
            return check_hash
        else:
            # error
            False
