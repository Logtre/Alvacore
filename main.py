#! /usr/bin/env python
# -*- coding: utf-8 -*-

import forward
#import future
import configparser

def main(business, bc_network):
    '''
    business = FWD, FUT
    bc_network = 1, 3, 4, 5
    1: Main net
    3: Ropsten testnet
    4: Rinkeby testnet
    5: Private net
    '''
    if business == "FWD":
        forward.get_forward_fxrate(bc_network)
    elif business == "FUT":
        future.get_future_fxrate(bc_network)
    else:
        return false

config = configparser.ConfigParser()
config.read('./setting.ini')
section99 = 'bc_network'
network = config.get(section99, 'network')
BC_NETWORK = int(config.get(network, 'bc_network'))

main('FWD', BC_NETWORK)
