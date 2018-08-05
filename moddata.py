#! /usr/bin/env python
# -*- coding: utf-8 -*-
import hashlib


class ModifyData:

    def __init__(self):
        self.extracted_text = ""


    def extract_text(input_text):
        extracted_text = input_text.decode('utf-8').replace('\x00', '')


    def modify_response_data(resp_data, request, params_hash, err_code, api_response):

        resp_data['request_id'] = request['request_id']
        resp_data['params_hash'] = params_hash
        resp_data['error'] = err_code
        resp_data['resp_data'] = api_response['usd_rate']

        return resp_data
