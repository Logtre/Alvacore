#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
from web3 import Web3, IPCProvider
from web3.middleware import geth_poa_middleware
import logdefinition as logdef
import json

def get_env():
    platform = ''
    if sys.platform.startswith('win') or sys.platform.startswith('cygwin'):
        platform = 'win'
    elif sys.platform.startswith('darwin'):
        platform = 'mac'
    elif sys.platform.startswith('linux'):
        platform = 'lnx'
    logdef.logger.info("success get platform:{}".format(platform))
    return platform + ('32' if sys.maxsize < 2**31 else '64')

def set_ABI(path_to_abi):
    abi = ''
    with open(path_to_abi) as json_file:
        abi = json.load(json_file)
    #logdef.logger.info("success get abi:{}".format(abi))
    return abi

def set_address(bc_network):
    contracts_address = ''
    # @Main net
    if bc_network == 1:
        contracts_address = 'set_your_address'
    # @Ropsten testnet
    elif bc_network == 3:
        contracts_address = '0xf1cB19B22050689472e29EBe4EEFCFAA1FF0D7A7'
    # @Rinkeby testnet
    elif bc_network == 4:
        contracts_address = 'set_your_address'
    logdef.logger.info("success get address:{}".format(contracts_address))
    return contracts_address

def set_IPCProvider(bc_network):
    ipcprovider = ''
    python_env = get_env()
    # executed in Local
    if python_env.startswith('mac') or python_env.startswith('win'):
        # @Main net
        if bc_network == 1:
            ipcprovider = Web3(IPCProvider('path/to/ipc'))
        # @Ropsten testnet
        elif bc_network == 3:
            #ipcprovider = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/aws_testnet/geth.ipc'))
            ipcprovider = Web3(IPCProvider('/Users/user/Library/Application Support/io.parity.ethereum/jsonrpc.ipc'))
        # @Rinkeby testnet
        elif bc_network == 4:
            ipcprovider = Web3(IPCProvider('/tools/ethereum/Geth-1.8.11/home/eth_rinkeby_net/geth.ipc'))
            ipcprovider.middleware_stack.inject(geth_poa_middleware, layer=0)
    elif python_env.startswith('lin'):
        # @Main net
        if bc_network == 1:
            ipcprovider = Web3(IPCProvider('path/to/ipc'))
        # @Ropsten testnet
        elif bc_network == 3:
            ipcprovider = Web3(IPCProvider('/home/ubuntu/.local/share/io.parity.ethereum/jsonrpc.ipc'))
        # @Rinkeby testnet
        elif bc_network == 4:
            ipcprovider = Web3(IPCProvider('/home/ubuntu/.ethereum/rinkeby/geth.ipc'))
            ipcprovider.middleware_stack.inject(geth_poa_middleware, layer=0)
    return ipcprovider

def set_cmp_key(path):
    key = ''
    keypath = path + 'CMP_API_KEY.json'
    with open(keypath) as json_file:
        key = json.load(json_file)
    return key
