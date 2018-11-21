pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/FwdCont.sol";


contract FwdContRequest is FwdCont {
    //FwdOrderlyRequest public requestOrderly;

    uint256 buffer = 120;

    function _request(
        //uint256 _contractDay,
        uint256 _settlementDuration,
        uint256 _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        uint256 _baseAmt
        ) internal {

        //uint256 _fwdCnt = fwdCnt;
        uint256 _reqFee = minGas * gasPrice * buffer / 100;
        uint256 _requiredFee = _calculateTotalFee(minGas, reqGas, gasPrice, buffer);

        if (msg.value < _requiredFee) {
            revert();
        } else {
            // Record the request.

            uint256 _requestId = requestOrderly.request.value(_reqFee)(
                REQUESTTYPE,
                address(this),
                FWD_CALLBACK_FID,
                now,
                SYMBOL
            );

            uint256 _fwdId = _createFwdRequest(
                msg.sender,
                now,
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

        /*emit ForwardInfo(
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
        );*/
        emit FwdRequest(
            _fwdId,
            msg.sender,
            fwdStates[0],
            now,
            _settlementDuration,
            _expireDuration,
            _receiverAddr,
            _senderAddr,
            _baseAmt
        );

    }

    function _response(
        uint256 _requestId,
        uint256 _error,
        uint256 _respData
    ) internal {

        _isOrderly(msg.sender);

        uint256 _fwdFetchRateFee = minGas * gasPrice;

        uint256 _fwdId = fwdIndexToRequests[_requestId]; // Linkage requestId and FwdCont

        if (_error < 2) {
            // update fxRate
            _setFxRate(_fwdId, _respData);
            // update fwdState
            _setFwdState(_fwdId, 1);
            // payment
            //_transfer(owner, fwdIndexToFees[_fwdId]);
            owner.transfer(fwdIndexToFees[_fwdId]);
            // emit event
            emit FwdResponse(_requestId, owner, _error, _respData);
        } else {
            // error in ALVC server
            // return fee
            //_transfer(fwdRequests[_fwdId].fwdOwner, fwdIndexToFees[_fwdId] - _fwdFetchRateFee);
            fwdRequests[_fwdId].fwdOwner.transfer(fwdIndexToFees[_fwdId] - _fwdFetchRateFee);
            // emit event
            emit FwdResponse(_requestId, fwdRequests[_fwdId].fwdOwner, _error, 0);
        }
    }
}
