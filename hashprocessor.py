#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import hashlib
from web3 import Web3
import json


class CreateCheckHash:

    def __init__(self):
        self.check_hash = ""

    def create_check_hash(request_type, request_data):

        #check_hash = hashlib.sha256(request_type, request_data).hexdigest()
        check_hash = Web3.soliditySha3(['bytes32', 'bytes32'], [request_type, request_data]).hex()[2:]

        if check_hash:
            return check_hash
        else:
            # error
            return "0000000000000000000000000000000000000000000000000000000000000000"
