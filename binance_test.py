#! /usr/bin/env python
# -*- coding: utf-8 -*-

#import forward
#import future
#import configparser
import binance_connector

def main():
    b_con = binance_connector.BinanceUSDCConnector()
    #return b_con.test_connect()
    print(b_con.get_exchange_info())
    
main()
