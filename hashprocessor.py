#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import hashlib
from web3 import Web3
import json
import logdefinition as logdef

class CreateCheckHash:

    def __init__(self):
        self.check_hash = ""

    def create_check_hash(self, request_type, request_data):

        #check_hash = hashlib.sha256(request_type, request_data).hexdigest()
        #check_hash = Web3.soliditySha3(['bytes32', 'bytes32'], [request_type, request_data])
        check_hash = Web3.toHex(Web3.soliditySha3(['bytes32', 'bytes32'], [request_type, request_data]))
        #hexed_check_hash = Web3.toHex(check_hash)

        if check_hash:
            logdef.logger.info("success to create check_hash. check_hash is:{}".format(check_hash))
            return check_hash
        else:
            # error
            logdef.logger.info("fail to create check_hash.")
            return "0x0000000000000000000000000000000000000000000000000000000000000000"
