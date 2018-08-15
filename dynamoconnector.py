#! /usr/bin/env python
# -*- coding: utf-8 -*-
import boto3
from boto3.dynamodb.conditions import Key, Attr


class DynamoConnector:

    def __init__(self, table_name):
        dynamodb = boto3.resource("dynamodb")
        FUT_TABLE = dynamodb.table(table_name)

    def create_fut_reservation(request_data):

        item_exp = {
            "request_id": request_data["request_id"],
            "request_meta_data": {
                "request_type": request_data["request_type"],
                #"requester": request_data["requester"],
                #"fee": request_data["fee"],
                #"callback_addr": request_data["callback_addr"],
                #"callback_fid": request_data["callback_fid"],
                #"params_hash": request_data["params_hash"],
                "timestamp": request_data["timestamp"],
                "reservation_date": request_data["reservation_date"],
                "request_state": "listed_db",
            },
            "request_data": {
                "request_data_type": request_data["request_data_type"],
                "request_data_length": request_data["request_data_length"],
                "request_data_message": request_data["request_data_message"]
            },
            "response_data": {
                "usd_rate": Null,
                "symbol": "Null",
                "volume_24h": Null,
                "timestamp": Null,
                "error_message": "Null"
            }
        }

        response = FUT_TABLE.put_item(
            Item = item_exp
        )

        if response:
            return response
        else:
            # error内容をrequest{}に保存
            return False

    def read_fut_reservation(timestamp):
        response = FUT_TABLE.scan(
            FilterExpression = Attr("reservation_date").lt(timestamp) & Attr("request_state").eq("listed_db")
        )

        if response:
            items = response["Items"]
            return items
        else:
            # error内容をrequest{}に保存
            return False

    def update_fut_request(request_id, resp_data):

        key_exp = {"request_id" : request_id}

        update_exp = 'SET request_meta_data: { \
                                request_state = :val1 \
                             }, \
                            response_data: { \
                                usd_rate = :val2, \
                                symbol = :val3, \
                                volume_24h = :val4, \
                                timestamp = :val5, \
                                error = :val6 \
                             }'

        update_attr_val = {
            ":val1": "rate_fetched",
            ":val2": resp_data["data"]["quotes"]["USD"]["price"],
            ":val3": resp_data["data"]["symbol"],
            ":val4": resp_data["data"]["quotes"]["USD"]["volume_24h"],
            ":val5": resp_data["metadata"]["timestamp"],
            ":val6": resp_data["metadata"]["error"]
        }

        response = FUT_TABLE.update_item(
            Key = key_exp,
            UpdateExpression = update_exp,
            ExpressionAttributeValues = update_attr_val
        )

        if response:
            return response
        else:
            # error内容をrequest{}に保存
            return False
