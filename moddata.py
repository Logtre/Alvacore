#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import hashlib
import logdefinition as logdef
import binascii

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
        #extracted_text = binascii.a2b_hex(arg).decode('utf-8').replace('\x00','')
        extracted_text = arg.decode('utf-8').replace('\x00', '')
        #extracted_text = arg.decode('utf-8')
        return extracted_text

    def modify_response_data(self, req, params_hash, err_code, api_resp):
        #dec_params_hash = self.string_to_bytes32(params_hash)
        thousandtimes_usd_rate = api_resp['usd_rate'] * 1000
        #dec_api_resp = self.string_to_bytes32(str(hundredfold_usd_rate))

        self.response_data['request_id'] = int(req['request_id'])
        self.response_data['params_hash'] = params_hash
        self.response_data['error'] = err_code
        self.response_data['resp_data'] = int(thousandtimes_usd_rate)

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
