#! /usr/bin/env python
# -*- coding: utf-8 -*-

import forward
#import future

def main(business, bc_network):
    '''
    business = FWD, FUT
    bc_network = 1, 3, 4
    1: Main net
    3: Ropsten testnet
    4: Rinkeby testnet
    '''
    if business == "FWD":
        forward.get_forward_fxrate(bc_network)
    elif business == "FUT":
        future.get_future_fxrate(bc_network)
    else:
        return false

main('FWD', 3)
