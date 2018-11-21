pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/FwdCont.sol";


contract FwdContProcess is FwdCont {

    function _cancelFwd(uint256 _fwdId) internal {
        // fwdState = confirmCancel
        _checkState(_fwdId, 5);

        if (msg.value + fwdIndexToFees[_fwdId] >= minGas * gasPrice) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            if (fwdDeposits[_fwdId] > 0) {
                // exist deposit asset
                // withdraw deposit
                _refundPayedDeposit(_fwdId);
                // cancel fwd
                //_cancel(_fwdId, fwdRequests[_fwdId].receiverAddr, minGas * gasPrice);
                _cancel(_fwdId);
                // update fwdState
                _setFwdState(_fwdId, 6);
            } else {
                // no deposit, so need not to return deposit
                //_cancel(_fwdId, fwdRequests[_fwdId].receiverAddr, minGas * gasPrice);
                _cancel(_fwdId);
                // update fwdState
                _setFwdState(_fwdId, 6);
            }
        } else {
            // unsufficient fee
            revert();
        }
    }

    function _emergencyCancel(uint256 _fwdId) internal {
        // fwdState = confirmEmergency
        _checkState(_fwdId, 7);

        if (msg.value + fwdIndexToFees[_fwdId] >= minGas * gasPrice) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            if(fwdDeposits[_fwdId] > 0) {
                // exist deposit asset
                // withdraw deposit
                _refundPayedDeposit(_fwdId);
                // confirmCancel
                _setFwdState(_fwdId, 8);
                // cancel fwd
                //_cancel(_fwdId, fwdRequests[_fwdId].receiverAddr, minGas * gasPrice);
                _cancel(_fwdId);
            } else {
                // confirmCancel
                _setFwdState(_fwdId, 8);
                // no deposit, so need not to return deposit
                //_cancel(_fwdId, fwdRequests[_fwdId].receiverAddr, minGas * gasPrice);
                _cancel(_fwdId);
            }
        } else {
            revert();
        }
    }

    function _withdrawFwd(uint256 _fwdId) internal {
        // if now time greater than settlementDay,
        // function can execute
        _availSettlement(_fwdId);
        // only receiver can execute
        _isReceiver(_fwdId);
        // fwdState = confirmWithdraw
        _checkState(_fwdId, 3);

        if (fwdDeposits[_fwdId] > 0) {
            // exist deposit asset
            // withdraw deposit
            _withdrawDepositWithRate(_fwdId, fwdRequests[_fwdId].senderAddr, fwdIndexToFxRate[_fwdId]);
            // update fwdState
            _setFwdState(_fwdId, 4);

            _deleteFwdRequest(_fwdId);
        } else {
            revert();
        }
    }

    function _deposit(uint256 _fwdId) internal {

        _isSender(_fwdId);

        if (msg.value < _calculateFxAmt(fwdRequests[_fwdId].baseAmt, fwdIndexToFxRate[_fwdId])) {
            // insufficient fee
            // revert
            revert();
        } else {
            // create deposit
            fwdDeposits[_fwdId] = msg.value;
            // update fwdState
            _setFwdState(_fwdId, 2);
            // update fee
            _setFwdFee(_fwdId, fwdIndexToFees[_fwdId] - minGas * gasPrice);

            emit FwdDeposit(_fwdId, fwdDeposits[_fwdId], fwdIndexToFwdState[_fwdId], fwdIndexToFees[_fwdId]);
        }
    }

    function _withdrawConfirm(uint256 _fwdId) internal {
        // only sender can execute
        _isSender(_fwdId);
        // fwdState = setDeposit
        _checkState(_fwdId, 2);

        if (msg.value + fwdIndexToFees[_fwdId] > minGas * gasPrice) {
            // confirmWithdraw
            _setFwdState(_fwdId, 3);
            // update fee balance
            _setFwdFee(_fwdId, msg.value + fwdIndexToFees[_fwdId] - minGas * gasPrice);
        }
    }

    function _setCancelFlag(uint256 _fwdId) internal {
        if (msg.sender == fwdRequests[_fwdId].receiverAddr) {
            cancelRequestReceiver[_fwdId] = true;
        }

        if (msg.sender == fwdRequests[_fwdId].senderAddr) {
            cancelRequestSender[_fwdId] = true;
        }
    }

    function _cancelConfirm(uint256 _fwdId) internal {
        // set cancelflag
        _setCancelFlag(_fwdId);
        // confirmCancel
        _setFwdState(_fwdId, 5);

        _setFwdFee(_fwdId, msg.value + fwdIndexToFees[_fwdId] - minGas * gasPrice);
    }

    function _emergencyConfirm(uint256 _fwdId) internal {
        // only sender can execute
        _isSender(_fwdId);
        // confirmCancel
        _setFwdState(_fwdId, 7);

        _setFwdFee(_fwdId, msg.value + fwdIndexToFees[_fwdId] - minGas * gasPrice);
    }
}
