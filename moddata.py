#! /usr/bin/env python
# -*- coding: utf-8 -*-
import hashlib


class ModifyData:

    def __init__(self):
        self.extracted_text = ""


    def extract_text(arg):
        extracted_text = arg.decode('utf-8').replace('\x00', '')


    def modify_response_data(resp, req, params_hash, err_code, api_resp):

        resp['request_id'] = req['request_id']
        resp['params_hash'] = params_hash
        resp['error'] = err_code
        resp['resp_data'] = api_resp['usd_rate']

        return resp_data
