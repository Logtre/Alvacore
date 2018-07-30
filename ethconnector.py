#! /usr/bin/env python
# -*- coding: utf-8 -*-
from web3 import Web3, IPCProvider
from web3.middleware import geth_poa_middleware

w3 = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/eth_rinkeby_net/geth.ipc')) # on local PC
w3 = Web3(IPCProvider('/home/ubuntu/.ethereum/rinkeby/geth.ipc')) # on AWS

# rinkebyネットワークに接続するためのコマンドを実行
w3.middleware_stack.inject(geth_poa_middleware, layer=0)


CRED_KEY = '...' # key for indentify the ETHConnector

class ETHConnector:

    def __init__(self, addr, ab):
        self.addr = addr
        self.ab = ab
        self.contract = web3.eth.contract(address = addr,abi = ab)
        self.target_request_id = 0
        self.target_request = []

    def read_request():
        # 未取得のFWDリクエストリストの先頭インデックス番号を取得する
        target_request_id = contract.functions.getRequestIndex().call()
        # インデックス番号を元に、未取得のFWDリクエストを取得する
        target_request = contract.functions.getRequestData(target_request_id).call()

        if target_request:
            return target_request
        else:
            # error内容をrequest{}に保存
            return False


    def provide_response(response_data):

        provide_flag = contract.functions.deliver(response_data["request_id"], response_data["params_hash"], response_data["error"], response_data["resp_data"]).call()

        if provide_flag:
            return
        else:
            # error内容をrequest{}に保存
            return False
