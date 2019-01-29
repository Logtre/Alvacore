pragma solidity ^0.4.24;

//import "./FwdCont.sol";
import "./operation/Hedge.sol";
import "./operation/Request.sol";

/**
    @dev Request defines operation function and variable for Request, Deposit, and Withdraw.
*/
contract FwdContProcess is Hedge, Request {

    /**
        @dev    cancel request
        @param  _fwdId          fwd id
        @param  _reasonIndex    index of cancelReason
    */
    function _cancelRequest(uint256 _fwdId, uint256 _reasonIndex) internal {
        // if receiver request, setting receiverflag
        if (msg.sender == fwdRequests[_fwdId].receiverAddr) {
            cancelRequestReceiver[_fwdId] = true;
        }
        // if sender request, setting senderflag
        if (msg.sender == fwdRequests[_fwdId].senderAddr) {
            cancelRequestSender[_fwdId] = true;
        }
        // cancel operation
        _cancelRequestFwd(_fwdId, _reasonIndex);
    }

    /**
        @dev    cancel fwd and delete linked storage
        @param  _fwdId  fwd id
    */
    function _cancel(uint256 _fwdId) internal {
        // check wether fwdState = 'requestCancel'
        _checkState(_fwdId, 4);
        // if there is hedge amount, cancel it
        if (fwdHedges[_fwdId] > 0) {
            _cancelHedge(_fwdId);
        }
        // if there is deposit amount, refund it
        if (fwdDeposits[_fwdId] > 0) {
            _refundDepositFwd(_fwdId);
        }
        // cancel operation
        _cancelFwd(_fwdId);
    }

    /**
        @dev    cancel request
        @param  _fwdId          fwd id
        @param  _reasonIndex    index of cancelReason
    */
    function _emergencyRequest(uint256 _fwdId, uint256 _reasonIndex) internal {
        // only sender can execute
        _isSender(_fwdId);
        // emergency operation
        _emergencyRequestFwd(_fwdId, _reasonIndex);
    }

    /**
        @dev    cancel fwd and delete linked storage
        @param  _fwdId  fwd id
    */
    function _emergencyCancel(uint256 _fwdId) internal {
        // check wether fwdState = 'requestEmergency'
        _checkState(_fwdId, 6);
        // if there is hedge amount, cancel it
        if (fwdHedges[_fwdId] > 0) {
            _cancelHedge(_fwdId);
        }
        // if there is deposit amount, refund it
        if(fwdDeposits[_fwdId] > 0) {
            _refundDepositFwd(_fwdId);
        }
        // emergency operation
        _emergencyCancelFwd(_fwdId);
    }

    /**
        @dev    hedge set hedge amount
        @param  _fwdId  fwd id
    */
    function _hedge(uint256 _fwdId) internal {
        // confirm wether hedge is available
        _availHedge(_fwdId);
        // hedge operation
        _setHedge(_fwdId);
    }

    /**
        @dev    replenish hedge amount to deposit
        @param  _fwdId  fwd id
    */
    function _replenish(uint256 _fwdId) internal {
        // require hedgeState is 'confirmed'
        _availReplenish(_fwdId);

        if (fwdHedges[_fwdId] > 0) {
            // replenish operation
            _replenishHedge(_fwdId);
        } else {
            revert();
        }
    }

    /**
        @dev    withdraw deposit asset
                premise: only receiver execute this function
        @param  _fwdId  fwd id
    */
    function _withdraw(uint256 _fwdId) internal {
        // require today is after settlementDay
        _availSettlement(_fwdId);
        // only receiver can execute
        _isReceiver(_fwdId);
        // fwdState = 'confirmWithdraw'
        _checkState(_fwdId, 2);
        // hedgeState = 'confirmed'
        _checkHedge(_fwdId, 3);

        if (fwdDeposits[_fwdId] > 0) {
            // withdraw operation
            _withdrawFwd(_fwdId, fwdRequests[_fwdId].senderAddr);
            // delete storage
            _deleteFwd(_fwdId);
        } else {
            revert();
        }
    }

    /**
        @dev    deposit asset
                premise: only sender execute this function
        @param  _fwdId  fwd id
    */
    function _deposit(uint256 _fwdId) internal {
        // only sender can execute
        _isSender(_fwdId);
        // deposit operation
        _depositFwd(_fwdId);
    }

    /**
        @dev    confirm withdraw
                premise: only sender can execute this function
        @param  _fwdId  fwd id
    */
    function _confirmWithdraw(uint256 _fwdId) internal {
        // only sender can execute
        _isSender(_fwdId);
        // check wether fwdState = setDeposit
        _checkState(_fwdId, 1);
        // confirm withdraw operation
        _confirmWithdrawFwd(_fwdId);
    }

}
