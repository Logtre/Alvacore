#! /usr/bin/env python
# -*- coding: utf-8 -*-
from web3 import Web3, IPCProvider
from web3.middleware import geth_poa_middleware
from hashprocessor import CreateCheckHash
from web3.contract import ConciseContract
from moddata import ModifyData
import init
import time
import logdefinition as logdef
import configparser

class ETHConnector:

    def __init__(self, bc_network):
        self.config = configparser.ConfigParser()
        self.config.read('setting.ini')
        #self.timeout = 120
        self.python_env = init.get_env()
        if self.python_env.startswith('mac') or self.python_env.startswith('win'):
            # @Main net
            if bc_network == 1:
                self.section1 = 'local_main_net'
                self.timeout = int(self.config.get(self.section1, 'timeout'))
                self.path_to_ipc = self.config.get(self.section1, 'ipc')
                self.orderly_abi = self.config.get(self.section1, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section1, 'orderly_addr')
                self.default_account = self.config.get(self.section1, 'def_account')
                self.default_account_pwd = self.config.get(self.section1, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                logdef.logger.info("connect to Main net")
            # @Ropsten testnet
            elif bc_network == 3:
                self.section3 = 'local_ropsten'
                self.timeout = int(self.config.get(self.section3, 'timeout'))
                self.path_to_ipc = self.config.get(self.section3, 'ipc')
                self.orderly_abi = self.config.get(self.section3, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section3, 'orderly_addr')
                self.default_account = self.config.get(self.section3, 'def_account')
                self.default_account_pwd = self.config.get(self.section3, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                #self.w3 = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/aws_testnet/geth.ipc')) # geth
                #self.w3 = Web3(IPCProvider('/Users/user/Library/Application Support/io.parity.ethereum/jsonrpc.ipc', timeout=self.timeout)) # parity
                logdef.logger.info("connect to Ropsten testnet")
            # @Rinkeby testnet
            elif bc_network == 4:
                self.section4 = 'local_rinkeby'
                self.timeout = int(self.config.get(self.section4, 'timeout'))
                self.path_to_ipc = self.config.get(self.section4, 'ipc')
                self.orderly_abi = self.config.get(self.section4, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section4, 'orderly_addr')
                self.default_account = self.config.get(self.section4, 'def_account')
                self.default_account_pwd = self.config.get(self.section4, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                #self.w3 = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/eth_rinkeby_net/geth.ipc'))
                self.w3.middleware_stack.inject(geth_poa_middleware, layer=0)
                logdef.logger.info("connect to Rinkeby testnet")
            # @Ropsten testnet
            elif bc_network == 5:
                self.section5 = 'local_private'
                self.timeout = int(self.config.get(self.section5, 'timeout'))
                self.path_to_ipc = self.config.get(self.section5, 'ipc')
                self.orderly_abi = self.config.get(self.section5, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section5, 'orderly_addr')
                self.default_account = self.config.get(self.section5, 'def_account')
                self.default_account_pwd = self.config.get(self.section5, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                #self.w3 = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/aws_testnet/geth.ipc')) # geth
                #self.w3 = Web3(IPCProvider('/Users/user/Library/Application Support/io.parity.ethereum/jsonrpc.ipc', timeout=self.timeout)) # parity
                logdef.logger.info("connect to Private net")
        # @AWS
        elif self.python_env.startswith('lin'):
            # @Main net
            if bc_network == 1:
                self.section6 = 'aws_main_net'
                self.timeout = int(self.config.get(self.section6, 'timeout'))
                self.path_to_ipc = self.config.get(self.section6, 'ipc')
                self.orderly_abi = self.config.get(self.section6, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section6, 'orderly_addr')
                self.default_account = self.config.get(self.section6, 'def_account')
                self.default_account_pwd = self.config.get(self.section6, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                #self.w3 = Web3(IPCProvider('path/to/ipc'))
                logdef.logger.info("connect to Main net")
            # @Ropsten testnet
            elif bc_network == 3:
                self.section8 = 'aws_ropsten'
                self.timeout = int(self.config.get(self.section8, 'timeout'))
                self.path_to_ipc = self.config.get(self.section8, 'ipc')
                self.orderly_abi = self.config.get(self.section8, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section8, 'orderly_addr')
                self.default_account = self.config.get(self.section8, 'def_account')
                self.default_account_pwd = self.config.get(self.section8, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                #self.w3 = Web3(IPCProvider('/home/ubuntu/.local/share/io.parity.ethereum/jsonrpc.ipc'))
                logdef.logger.info("connect to Ropsten testnet")
            # @Rinkeby testnet
            elif bc_network == 4:
                self.section9 = 'aws_rinkeby'
                self.timeout = int(self.config.get(self.section9, 'timeout'))
                self.path_to_ipc = self.config.get(self.section9, 'ipc')
                self.orderly_abi = self.config.get(self.section9, 'orderly_abi')
                self.orderly_addr = self.config.get(self.section9, 'orderly_addr')
                self.default_account = self.config.get(self.section9, 'def_account')
                self.default_account_pwd = self.config.get(self.section9, 'def_account_pwd')
                self.w3 = Web3(IPCProvider(self.path_to_ipc))
                #self.w3 = Web3(IPCProvider('/home/ubuntu/.ethereum/rinkeby/geth.ipc'))
                self.w3.middleware_stack.inject(geth_poa_middleware, layer=0)
                logdef.logger.info("connect to Rinkeby testnet")
            # @Private net
            elif bc_network == 5:
                    self.section10 = 'aws_private'
                    self.timeout = int(self.config.get(self.section10, 'timeout'))
                    self.path_to_ipc = self.config.get(self.section10, 'ipc')
                    self.orderly_abi = self.config.get(self.section10, 'orderly_abi')
                    self.orderly_addr = self.config.get(self.section10, 'orderly_addr')
                    self.default_account = self.config.get(self.section10, 'def_account')
                    self.default_account_pwd = self.config.get(self.section10, 'def_account_pwd')
                    self.w3 = Web3(IPCProvider(self.path_to_ipc, timeout=self.timeout))
                    #self.w3 = Web3(IPCProvider('/home/ubuntu/.local/share/io.parity.ethereum/jsonrpc.ipc'))
                    logdef.logger.info("connect to Private net")
        else:
            self.w3 = ''
        #self.w3 = init.set_IPCProvider(bc_network)
        # set pre-funded account as sender
        if (self.w3.isConnected()):
            logdef.logger.info("success to connect network")
            #self.w3.eth.defaultAccount = self.w3.eth.accounts[2]
            #self.addr = init.set_address(bc_network)
            self.addr = self.orderly_addr
            #self.abi = init.set_ABI()
            self.abi = init.set_ABI(self.orderly_abi)
            self.contract = self.w3.eth.contract(address = self.addr,abi = self.abi)
            #self.create_hash = CreateCheckHash()
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
        else:
            logdef.logger.info("fail to connect network")

    def read_request(self):
        create_hash = CreateCheckHash()
        target_request_id = ''
        target_request = ''
        # 未取得のFWDリクエストリストの先頭インデックス番号を取得する
        logdef.logger.info("start getting requestId")
        #transaction_msg = {'from':self.w3.eth.defaultAccount, 'gas':500000}
        target_request_id = self.contract.functions.getRequestIndex().call()
        #target_request_id = self.contract.getRequestIndex()
        logdef.logger.info("target requestId is: {}".format(target_request_id))
        # インデックス番号を元に、未取得のFWDリクエストを取得する
        target_request = self.contract.functions.getRequest(target_request_id).call()
        #target_request = self.contract.getRequest(target_request_id)
        logdef.logger.info("target request is: {}".format(target_request))

        if target_request != '':
            # paramsHashを付与
            logdef.logger.info("start calculating paramsHash.")
            self.params_hash = create_hash.create_check_hash(target_request[0], target_request[3])
            #logdef.logger.info("paramsHash is: {}".format(self.params_hash))
            # request_dataを更新
            self.request_data['request_id'] = self.mod_data.extract_numtext(str(target_request_id))
            self.request_data['request_type'] = self.mod_data.extract_text(target_request[0])
            self.request_data['timestamp'] = self.mod_data.extract_numtext(str(target_request[1]))
            self.request_data['request_state'] = self.mod_data.extract_text(target_request[2])
            self.request_data['request_data'] = self.mod_data.extract_text(target_request[3])
            logdef.logger.info("extracted request is: {}".format(self.request_data))
            return self.request_data, self.params_hash, 0
        else:
            # error
            logdef.logger.error("error: cannot get data from BCNetwork.")
            return self.request_data, "", 2


    def deliver_response(self, arg):
        logdef.logger.info("alvcWallet is: {}".format(self.contract.functions.alvcWallet().call()))
        #self.w3.eth.defaultAccount = self.w3.eth.accounts[2]
        self.w3.eth.defaultAccount = self.default_account
        logdef.logger.info("all eth accounts is{}".format(self.w3.eth.accounts))
        logdef.logger.info("eth defaultAccount is{}".format(self.w3.eth.defaultAccount))
        #self.w3.eth.defaultAccount = '0x6613b9220643D378B0a88B26C1ca86BB440DC22a'
        #executeAccount = '0x6613b9220643D378B0a88B26C1ca86BB440DC22a'
        if self.w3.personal.unlockAccount(self.w3.eth.defaultAccount, self.default_account_pwd):
            logdef.logger.info("success unlockAccount. sender address is: {}".format(self.w3.eth.defaultAccount))
            transaction_msg = {'from':self.w3.eth.defaultAccount, 'gas':50000000000000}
            #import pdb; pdb.set_trace()
            tx_hash = self.contract.functions.deliver(arg["request_id"], arg["params_hash"], arg["error"], arg["resp_data"]).transact({
                'from':self.w3.eth.defaultAccount,
                'gas':5000000
            })
            #self.contract.functions.deliver({'_requestId': arg["request_id"], 'paramsHash': arg["params_hash"], '_error': arg["error"], '_respData': arg["resp_data"]})
            #self.contract.deliver(buildTransaction = (arg["request_id"], arg["params_hash"], arg["error"], arg["resp_data"]), transact = transaction_msg)
            #self.contract.functions.deliver(arg["request_id"], arg["params_hash"], arg["error"], arg["resp_data"]).call()
            tx_receipt = self.w3.eth.waitForTransactionReceipt(tx_hash)
            logdef.logger.info("transaction receipt is:{}".format(tx_receipt))
        else:
            logdef.logger.info("unsuccess unlockAccount.")
            return

        deliver_flag = self.mod_data.extract_text(self.contract.functions.requestIndexToState(arg["request_id"]).call())
        logdef.logger.info("deliver flag is:{}".format(deliver_flag))
        if deliver_flag == "delivering":
            logdef.logger.info("sucess delivering. requestState is:{}".format(deliver_flag))
            return
        else:
            # error内容をrequest{}に保存
            logdef.logger.error("error: fail delivering. requestState is:{}".format(deliver_flag))
            return

    def wait_on_tx_receipt(tx_hash):
        start_time = time.time()
        while True:
            if start_time + self.timeout < time.time():
                raise TimeoutError("Timeout occurred waiting for tx receipt")
            if self.w3.eth.getTransactionReceipt(tx_hash):
                return self.w3.eth.getTransactionReceipt(tx_hash)
