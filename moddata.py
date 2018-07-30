#! /usr/bin/env python
# -*- coding: utf-8 -*-
import hashlib
import json

#from apiconnector import ApiConnector
#from ethconnector import ETHConnector
#from dynamoconnector import DynamoConnector
#from queueworker import QueueWorker




class ModifyData:

    def __init__(self):
        self.resp = {}

    def modify_request_data(request):
        request_data = {
            'request_id':request[0], # requestを特定するために利用
            'request_type':request[1], # params_hashを計算するために利用
            #'requester':request[2], # 不要？
            #'fee':request[3], # 不要？
            #'callback_addr':request[4], # 不要？
            #'callbadk_fid':request[5], # 不要？
            #'params_hash':request[6], # 不要？
            'timestamp':request[7], # 実行日を特定するために利用
            'request_state':request[8], # requestの処理状況を特定するために利用
            'request_data_type':request[9][0], # params_hashを計算するために利用
            'request_data_length':request[9][1], # params_hashを計算するために利用
            'request_data_message':request[9][2] # params_hash & 為替レートの取得のために利用
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



class CreateCheckHash:

    def __init__(self):
        self.check_hash = ""

    def create_check_hash(request_type, request_data):

        check_hash = hashlib.sha256(request_type, request_data).hexdigest()

        if check_hash:
            return check_hash
        else:
            # error
            False
