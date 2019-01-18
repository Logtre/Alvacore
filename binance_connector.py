#! /usr/bin/env python
# -*- coding: utf-8 -*-
from binance.client import Client
import configparser

class BinanceUSDCConnector:

    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('setting.ini')
        self.api_key = self.config.get('binance_api', 'api_key')
        self.api_secret = self.config.get('binance_api', 'api_secret')
        self.client = Client(self.api_key, self.api_secret)

    def test_connect(self):
        """Test connectivity to the Rest API."""
        return self.client.ping()

    def get_exchange_info(self):
        """Return rate limits and list of symbols"""
        return self.client.get_exchange_info()

    def get_order_book(self, **kwargs):
        """Get the Order Book for the market"""
        return self.client.get_order_book(data=kwargs)

    def get_ticker(self, **kwargs):
        """24 hour price change statistics."""
        return self.client.get_ticker(data=kwargs)

    def get_24h_price_change(self, **kwargs):
        """24 hour price change statistics."""
        return self.client.get_ticker(data=kwargs)

    def get_latest_price(self, **kwargs):
        """Latest price for a symbol or symbols."""
        return self.client.get_symbol_ticker(data=kwargs)

    def test_new_order(self, **kwargs):
        """Test new order creation and signature/recvWindow long."""
        return self.client.create_test_order(data=kwargs)

    def create_order(self, order_type, **kwargs):
        """Send in a new order"""

        if order_type == 'limit':
            pass
        elif order_type == 'limit_buy':
            pass
        elif order_type == 'limit_sell':
            pass
        elif order_type == 'market':
            pass
        elif order_type == 'market_buy':
            pass
        elif order_type == 'market_sell':
            pass

    def check_order:

    def cancel_order:

    def get_open_order:

    def'''
