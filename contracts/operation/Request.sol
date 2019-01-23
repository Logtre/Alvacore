pragma solidity ^0.4.24;

import "../FwdCont.sol";
import "../fees/Fees.sol";
import "../math/SafeMath.sol";

/**
    @dev Request defines operation function and variable for Request, Deposit, and Withdraw.
*/
contract Request is FwdCont, Fees {
    using SafeMath for uint256;

    event AddFwd(
        uint256 fwdId,
        address fwdOwner,
        bytes32 fwdState,
        uint256 contractDay,
        uint256 settlementDuration,
        address receiverAddr,
        address senderAddr
    );

    event DepositFwd(
        uint256 fwdId,
        uint256 depositAmt,
        bytes32 fwdState
    );

    event ConfirmWithdrawFwd(
        uint256 fwdId,
        bytes32 fwdState
    );

    event WithdrawFwd(
        uint256 fwdId,
        address withdrawer,
        uint256 amount
    );

    event CancelRequestFwd(
        uint256 fwdId,
        address canceller,
        bytes32 reason
    );

    event CancelFwd(
        uint256 fwdId,
        address canceller,
        bytes32 reason
    );

    event EmergencyRequestFwd(
        uint256 fwdId,
        address canceller,
        bytes32 reason
    );

    event EmergencyCancelFwd(
        uint256 fwdId,
        address canceller,
        bytes32 reason
    );

    event DeleteFwd(
        uint256 fwdId
    );

    event RefundDepositFwd(
        uint256 fwdId,
        address senderAddr,
        uint256 amount
    );

    constructor() public { // constractor
        _createFwd(
            msg.sender, // fwdOwner of fwdRequest[0]
            now, // contractDay
            0, // settlementDuration
            address(0), // receiverAddr
            address(0), // senderAddr
            0 // FwdCont
        );
    }

    /**
        @dev add fwd request
        @param _fwdId   fwdCnt use as fwdId.
        @param _fwdRequest   fwdRequest
    */
    function _addFwd(uint256 _fwdId, FwdRequest _fwdRequest) private {
        fwdRequests[_fwdId] = _fwdRequest;
        _setFwdState(_fwdId, 0);
        fwdDeposits[_fwdId] = 0;
        cancelRequestSender[_fwdId] = false;
        cancelRequestReceiver[_fwdId] = false;
        fwdCnt ++;
    }

    /**
        @dev add fwd request
        @param _fwdOwner                owner of fwd
        @param _contractDay             date when contract is created
        @param _settlementDuration      date when asset will be sent
        @param _receiverAddr            address of receiver of asset
        @param _senderAddr              address of sender of asset
        @param _fwdCnt                  serial number of fwdRequest.
    */
    function _createFwd(
        address _fwdOwner,
        uint256 _contractDay,
        uint256 _settlementDuration,
        address _receiverAddr,
        address _senderAddr,
        uint256 _fwdCnt
        ) internal returns(uint256) {

        FwdRequest memory fwdRequest = FwdRequest({
            fwdOwner: msg.sender, // the owner of fwd[0] is owner of contract
            contractDay: _contractDay, // the date when conclude the trade contract
            settlementDuration: _settlementDuration, // the date when money will be moved
            receiverAddr: _receiverAddr, // the address whose owner will receive money
            senderAddr: _senderAddr // the address whose owner will send money
        });

        _addFwd(
            _fwdCnt, // fwdCnt is use as fwdId
            fwdRequest
        );

        // set fwdIndexToHedgeState as 'unstarted'
        fwdIndexToHedgeState[_fwdCnt] = hedgeStates[0];

        emit AddFwd(
            _fwdCnt, // fwdId
            _fwdOwner,
            fwdStates[0], // requesting
            _contractDay,
            _settlementDuration,
            _receiverAddr,
            _senderAddr
        );

        return _fwdCnt; // _fwdCnt is use as fwdId
    }

    /**
        @dev    deposit assets
        @param  _fwdId  fwd id
    */
    function _depositFwd(uint256 _fwdId) internal {
        // set deposit
        fwdDeposits[_fwdId] = msg.value;
        // update fwdState as 'setDeposit'
        _setFwdState(_fwdId, 1);
        // emit event
        emit DepositFwd(_fwdId, fwdDeposits[_fwdId], fwdIndexToFwdState[_fwdId]);
    }

    /**
        @dev    confirm withdraw
        @param  _fwdId  fwd id
    */
    function _confirmWithdrawFwd(uint256 _fwdId) internal {
        // set fwdState as 'confirmWithdraw'
        _setFwdState(_fwdId, 2);
        // emit event
        emit ConfirmWithdrawFwd(_fwdId, fwdIndexToFwdState[_fwdId]);
    }

    /**
        @dev    transfer asset to receiver with add hedge amount
        @param  _fwdId  fwd id
        @param  _to     receiver's address
    */
    function _withdrawFwd(uint256 _fwdId, address _to) internal {
        // calculate payment amount(add hedge amount , and minus fee)
        uint256 _paymentAmt = fwdDeposits[_fwdId].add(fwdHedges[_fwdId]).sub(processFee);
        // transfer asset to receiver
        _to.transfer(_paymentAmt);
        // update fwdState as 'withdrawn'
        _setFwdState(_fwdId, 4);
        // delete mapping
        delete fwdDeposits[_fwdId];
        // emit event
        emit WithdrawFwd(_fwdId, _to, _paymentAmt);
    }

    /**
        @dev    cancel fwdRequest linked specified fwdId
                premise: withdrawing deposit asset is done
                when cancel all fwdRequest, check wether deposit is refunded
        @param  _fwdId  fwd id
    */
    function _deleteFwd(uint256 _fwdId) internal {
        _noDeposit(_fwdId);
        delete fwdRequests[_fwdId];
        delete fwdIndexToFwdState[_fwdId];
        delete cancelRequestSender[_fwdId];
        delete cancelRequestReceiver[_fwdId];
        // emit event
        emit DeleteFwd(_fwdId);
    }

    /**
        @dev    refund deposited asset to sender
        @param  _fwdId  fwd id
    */
    function _refundDepositFwd(uint256 _fwdId) internal {
        // escape deposit amount to another struct with minus fee
        uint256 targetDeposit = fwdDeposits[_fwdId].sub(processFee);
        // delete deposit
        delete fwdDeposits[_fwdId];
        // refund value to sender
        fwdRequests[_fwdId].senderAddr.transfer(targetDeposit);
        // emit event
        emit RefundDepositFwd(_fwdId, fwdRequests[_fwdId].senderAddr, targetDeposit);
    }

    /**
        @dev    cancel request
        @param  _fwdId          fwd id
        @param  _reasonIndex    index of cancelReason
    */
    function _cancelRequestFwd(uint256 _fwdId, uint256 _reasonIndex) internal {
        // set fwdState as 'requestCancel'
        _setFwdState(_fwdId, 4);
        // set cancelReason
        cancelReasons[_fwdId] = cancelReasonIndex[_reasonIndex];
        // emit event
        emit CancelRequestFwd(_fwdId, msg.sender, cancelReasons[_fwdId]);
    }

    /**
        @dev    cancel Fwd which is set cancel request
        @param  _fwdId  fwd id
    */
    function _cancelFwd(uint256 _fwdId) internal {
        // set fwdState as 'canceled'
        _setFwdState(_fwdId, 5);
        // escape cancel reason to temp valiable
        bytes32 reason = cancelReasons[_fwdId];
        // delete storage
        _deleteFwd(_fwdId);
        // emit event
        emit CancelFwd(_fwdId, msg.sender, reason);

    }

    /**
        @dev    cancel request
        @param  _fwdId          fwd id
        @param  _reasonIndex    index of cancelReason
    */
    function _emergencyRequestFwd(uint256 _fwdId, uint256 _reasonIndex) internal {
        // set fwdState as 'requestEmergency'
        _setFwdState(_fwdId, 6);
        // set cancelReason
        cancelReasons[_fwdId] = cancelReasonIndex[_reasonIndex];
        // emit event
        emit EmergencyRequestFwd(_fwdId, msg.sender, cancelReasons[_fwdId]);
    }

    /**
        @dev    cancel fwd and delete linked strage
        @param  _fwdId  fwd id
    */
    function _emergencyCancelFwd(uint256 _fwdId) internal {
        // set fwdState as 'emergencyCanceled'
        _setFwdState(_fwdId, 7);
        // escape cancel reason to temp valiable
        bytes32 reason = cancelReasons[_fwdId];
        // delete storage
        _deleteFwd(_fwdId);
        // emit event
        emit EmergencyCancelFwd(_fwdId, msg.sender, reason);
    }

    /**
        @dev    check whether deposit is set or not
        @param  _fwdId  fwd id
    */
    function _noDeposit(uint256 _fwdId) view internal {
        require (fwdDeposits[_fwdId] == 0);
    }
}
