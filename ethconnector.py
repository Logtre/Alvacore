#! /usr/bin/env python
# -*- coding: utf-8 -*-
from web3 import Web3, IPCProvider
from web3.middleware import geth_poa_middleware
from hashprocessor import CreateCheckHash
from moddata import ModifyData
import init
import logging

class ETHConnector:

    def __init__(self, bc_network):
        self.w3 = init.set_IPCProvider(bc_network)
        self.addr = init.set_address(bc_network)
        self.abi = init.set_ABI()
        self.contract = self.w3.eth.contract(address = self.addr,abi = self.abi)
        self.create_hash = CreateCheckHash()
        self.mod_data = ModifyData()
        self.target_request_id = 0
        self.target_request = []
        self.params_hash = ""
        self.deliver_flag = 0
        self.request_data = {
            'request_id':0,
            'request_type':0,
            'timestamp':0,
            'request_state':"",
            'request_data':""
        }

    def read_request(self):
        # 未取得のFWDリクエストリストの先頭インデックス番号を取得する
        target_request_id = self.contract.functions.getRequestIndex().call()
        logger.info("target requestId is: {}".format(target_request_id))
        # インデックス番号を元に、未取得のFWDリクエストを取得する
        target_request = self.contract.functions.getRequestData(target_request_id).call()
        logger.info("target request is: {}".format(target_request))

        if target_request.length > 0:
            # paramsHashを付与
            logger.info("start calculating paramsHash.")
            params_hash = create_hash.create_check_hash(target_request[0], target_request[3])
            logger.info("paramsHash is: {}".format(params_hash))
            # request_dataを更新
            request_data['request_id'] = target_request_id
            request_data['request_type'] = target_request[0]
            request_data['timestamp'] = target_request[1]
            request_data['request_state'] = mod_data.extract_text(target_request[2])
            request_data['request_data'] = mod_data.extract_text(target_request[3])

            return request_data, params_hash, 0
        else:
            # error
            logger.error("error: cannot get data from BCNetwork.")
            return request_data, "", 2


    def deliver_response(self, arg):

        deliver_flag = self.contract.functions.deliver(arg["request_id"], arg["params_hash"], arg["error"], arg["resp_data"]).call()

        if deliver_flag:
            logger.info("sucess delivering.")
            return
        else:
            # error内容をrequest{}に保存
            logger.error("error: fail delivering.")
            return
