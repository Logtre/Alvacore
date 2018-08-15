#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys, os
from web3 import Web3, IPCProvider
from web3.middleware import geth_poa_middleware
from hashprocessor import CreateCheckHash
from moddata import ModifyData

import logging
logger = logging.getLogger(__name__)
for h in logger.handlers:
    logger.removeHandler(h)

h = logging.StreamHandler(sys.stdout)

FORMAT = '%(levelname)s %(asctime)s [%(funcName)s] %(message)s'
h.setFormatter(logging.Formatter(FORMAT))
logger.addHandler(h)
logger.setLevel(logging.INFO)

### Rinkeby testnet ###
#w3 = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/eth_rinkeby_net/geth.ipc')) # LOCAL via geth
#w3 = Web3(IPCProvider('/home/ubuntu/.ethereum/rinkeby/geth.ipc')) # AWS via geth

# rinkebyネットワークに接続するためのコマンドを実行
#w3.middleware_stack.inject(geth_poa_middleware, layer=0)

### Ropsten testnet ###
w3 = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/aws_test_net/geth.ipc')) # LOCAL via geth
w3 = Web3(IPCProvider('/home/ubuntu/.local/share/io.parity.ethereum/jsonrpc.ipc')) # AWS via parity


class ETHConnector:

    def __init__(self, addr, abi):
        self.create_hash = CreateCheckHash()
        self.mod_data = ModifyData()
        self.addr = addr
        self.abi = abi
        self.contract = w3.eth.contract(address = addr,abi = abi)
        self.target_request_id = 0
        self.target_request = []
        self.params_hash = ""
        self.deliver_flag = 0

    def read_request(arg):
        # 未取得のFWDリクエストリストの先頭インデックス番号を取得する
        target_request_id = contract.functions.getRequestIndex().call()
        # インデックス番号を元に、未取得のFWDリクエストを取得する
        target_request = contract.functions.getRequestData(target_request_id).call()

        if target_request.length > 0:
            # paramsHashを付与
            params_hash = create_hash.create_check_hash(target_request[1], target_request[4])
            # request_dataを更新
            arg['request_id'] = target_request[0]
            arg['request_type'] = target_request[1]
            arg['timestamp'] = target_request[2]
            arg['request_state'] = mod_data.extract_text(target_request[3])
            arg['request_data'] = mod_data.extract_text(target_request[4])
            }
            return arg, params_hash, 0
        else:
            # error
            return arg, "", 2


    def deliver_response(arg):

        deliver_flag = contract.functions.deliver(arg["request_id"], arg["params_hash"], arg["error"], arg["resp_data"]).call()

        if deliver_flag:
            return
        else:
            # error内容をrequest{}に保存
            return "ERROR. deliver_response"
