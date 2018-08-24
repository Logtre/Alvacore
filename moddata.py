#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import hashlib

class ModifyData:

    def __init__(self):
        self.extracted_text = ""
        self.response_data = {
            'request_id': 0,
            'params_hash': "",
            'error': 0,
            'resp_data': 0
        }

    def extract_text(self, arg):
        extracted_text = arg.decode('utf-8').replace('\x00', '')

    def modify_response_data(self, req, params_hash, err_code, api_resp):

        response_data['request_id'] = req['request_id']
        response_data['params_hash'] = params_hash
        response_data['error'] = err_code
        response_data['resp_data'] = api_resp['usd_rate']

        return resp_data
