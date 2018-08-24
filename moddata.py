#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import hashlib
import logdefinition as logdef

class ModifyData:
    def __init__(self):
        self.extracted_text = ""
        self.response_data = {
            'request_id': 0,
            'params_hash': "",
            'error': 0,
            'resp_data': 0
        }

    def extract_numtext(self, arg):
        org_extracted_numtext = ''.join(arg.replace('\x00', ''))
        extracted_number = int(org_extracted_numtext)
        return extracted_number

    def extract_text(self, arg):
        extracted_text = arg.decode('utf-8').replace('\x00', '')
        return extracted_text

    def modify_response_data(self, req, params_hash, err_code, api_resp):
        dec_params_hash = self.string_to_bytes32(params_hash)
        dec_api_resp = self.string_to_bytes32(str(api_resp['usd_rate']))

        self.response_data['request_id'] = req['request_id']
        self.response_data['params_hash'] = dec_params_hash
        self.response_data['error'] = err_code
        self.response_data['resp_data'] = dec_api_resp

        logdef.logger.info("success get response_data:{}".format(self.response_data))
        return self.response_data

    def zerofill_to32bytes(self, str):
        zfilldigit = 32 - len(str)
        return zfilldigit

    def string_to_bytes32(self, data):
        if len(data) > 32:
            myBytes32 = data[:32]
        else:
            myBytes32 = data.ljust(32, '0')
        return bytes(myBytes32, 'utf-8')
