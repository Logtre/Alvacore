pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/FwdCont.sol";


contract FwdContRequest is FwdCont {

    event ForwardInfo(
        int fwdId,
        address fwdOwner,
        bytes32 fwdState,
        int contractDay,
        int settlementDuration,
        int expireDuration,
        address receiverAddr,
        address senderAddr,
        int fee,
        int baseAmt,
        int fxRate,
        int depositAmt
    ); // log for create requests

    event Request(
        int requestId,
        address requester,
        bytes32 data
    ); // log for requests

    event Response(
        int requestId,
        address requester,
        int error,
        int data
    ); // log for responses

    //FwdOrderlyRequest public requestOrderly;

    int buffer = 120;

    function _request(
        //int _contractDay,
        int _settlementDuration,
        int _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        int _baseAmt
        ) internal {

        //int _fwdCnt = fwdCnt;
        int _reqFee = minGas * gasPrice * buffer / 100;
        int _requiredFee = _calculateTotalFee(minGas, reqGas, gasPrice, buffer);

        if (int(msg.value) < _requiredFee) {
            revert();
        } else {
            // Record the request.

            int _requestId = requestOrderly.request.value(uint(_reqFee))(
                REQUESTTYPE,
                address(this),
                FWD_CALLBACK_FID,
                int(now),
                SYMBOL
            );

            int _fwdId = _createFwdRequest(
                msg.sender,
                int(now),
                _settlementDuration,
                _expireDuration,
                _receiverAddr,
                _senderAddr,
                _baseAmt,
                fwdCnt,
                _requestId,
                _reqFee
            );
        }

        emit ForwardInfo(
            _fwdId,
            tx.origin,
            fwdStates[0],
            int(now),
            _settlementDuration,
            _expireDuration,
            _receiverAddr,
            _senderAddr,
            int(msg.value) - _reqFee,
            _baseAmt,
            0,
            0
        );

    }

    function _response(
        int _requestId,
        int _error,
        int _respData
    ) internal {

        _isOrderly(msg.sender);

        int _fwdFetchRateFee = minGas * gasPrice;

        int _fwdId = fwdIndexToRequests[_requestId]; // Linkage requestId and FwdCont

        if (_error < 2) {
            // update fxRate
            _setFxRate(_fwdId, _respData);
            // update fwdState
            _setFwdState(_fwdId, 1);
            // payment
            _transfer(owner, fwdIndexToFees[_fwdId]);
            // emit event
            emit Response(int(_requestId), owner, _error, _respData);
        } else {
            // error in ALVC server
            // return fee
            _transfer(fwdRequests[_fwdId].fwdOwner, fwdIndexToFees[_fwdId] - _fwdFetchRateFee);
            // emit event
            emit Response(int(_requestId), fwdRequests[_fwdId].fwdOwner, _error, 0);
        }
    }
}
