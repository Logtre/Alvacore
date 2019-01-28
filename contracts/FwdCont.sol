pragma solidity ^0.4.24;

import "./FwdBase.sol";
import "./math/SafeMath.sol";

/**
    @dev FwdCont defines common function and variable for FwdCore.
*/
contract FwdCont is FwdBase {
    using SafeMath for uint256;

    event AdminWithdrawFwd(
        address owner,
        uint256 amount
    );

    event AdminSupplyBalance(
        address owner,
        uint256 amount
    );

    mapping (uint256 => FwdRequest) internal fwdRequests; // the mapping to link fwdId and FwdCont (key:fwdID)
    mapping (uint256 => bytes32) internal fwdIndexToFwdState; // the mapping to link fwdId and fwdState (key:fwdID)
    mapping (uint256 => bytes32) internal fwdIndexToHedgeState; // the mapping to link fwdId and hedgeState (key:fwdID)
    mapping (uint256 => bytes32) internal fwdIndexToHedgeSign; // the mapping to link fwdId and hedgeSign (key:fwdID)
    mapping (uint256 => uint256) internal fwdDeposits; // the mapping to link fwdId and depositAmt (key:fwdID)
    mapping (uint256 => uint256) internal fwdHedges; // the mapping to link fwdId and hedge (key:fwdID)

    mapping (uint256 => bool) internal cancelRequestSender; // the mapping to link fwdId and cancelFlag
    mapping (uint256 => bool) internal cancelRequestReceiver; // the mapping to link fwdId and cancelFlag

    mapping (uint256 => bytes32) internal cancelReasons; // the mapping to link fwdId and cancelReason
    /**
        @dev FwdRequest is struct for keep request information.
    */
    struct FwdRequest {
        address fwdOwner; // address who create contract
        uint256 contractDay; // date when contract is created
        uint256 settlementDuration; // date when asset will be sent
        address receiverAddr; // address who receiver of asset
        address senderAddr; // address who sender of asset
    }

    bytes32[] internal fwdStates = [
        bytes32("requesting"),
        bytes32("setDeposit"),
        bytes32("confirmedWithdraw"),
        bytes32("withdrawn"),
        bytes32("requestCancel"),
        bytes32("canceled"),
        bytes32("requestEmergency"),
        bytes32("emergencyCanceled")
    ];

    bytes32[] internal cancelReasonIndex = [
        bytes32("notcanceled"),
        bytes32("service is not provided"),
        bytes32("payment is not made"),
        bytes32("contract is canceled"),
        bytes32("cange of contract"),
        bytes32("other")
    ];

    bytes32[] internal hedgeStates = [
        bytes32("unstarted"),
        bytes32("pending"),
        bytes32("confirmed"),
        bytes32("complete"),
        bytes32("canceled")
    ];

    bytes32[] internal hedgeSign = [
        bytes32("neutral"),
        bytes32("positive"),
        bytes32("negative")
    ];

    uint256 internal fwdCnt;

    /**
        @dev    only fwdRequest's stakeholders can access function
        @param  _fwdId  id of fwd
    */
    modifier onlyParty(uint256 _fwdId) {
        require(msg.sender == fwdRequests[_fwdId].fwdOwner ||
            msg.sender == fwdRequests[_fwdId].receiverAddr ||
            msg.sender == fwdRequests[_fwdId].senderAddr);
            _;
    }

    /**
        @dev    only when hedge is not effective user can access function
        @param  _fwdId  id of fwd
    */
    modifier noHedge(uint256 _fwdId) {
        require(fwdIndexToHedgeState[_fwdId] == hedgeStates[0]);
        _;
    }

    /**
        @dev    set hedgeState
        @param  _fwdId  fwd id
        @param  _index  index of hedgeState
    */
    function _setHedgeState(uint256 _fwdId, uint256 _index) internal {
        fwdIndexToHedgeState[_fwdId] = hedgeStates[uint(_index)];
    }

    /**
        @dev    set hedgeSign
        @param  _fwdId  fwd id
        @param  _index  index of hedgeSign
    */
    function _setHedgeSign(uint256 _fwdId, uint256 _index) internal {
        fwdIndexToHedgeSign[_fwdId] = hedgeSign[uint(_index)];
    }

    /**
        @dev    set fwdState
        @param  _fwdId  fwd id
        @param  _index  index of fwdState
    */
    function _setFwdState(uint256 _fwdId, uint256 _index) internal {
        fwdIndexToFwdState[_fwdId] = fwdStates[uint(_index)];
    }

    /**
        @dev    confirm operator is sender
        @param  _fwdId  fwd id
    */
    function _isSender(uint256 _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].senderAddr);
    }

    /**
        @dev    confirm operator is receiver
        @param  _fwdId  fwd id
    */
    function _isReceiver(uint256 _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].receiverAddr);
    }

    /**
        @dev    confirm whether is it after the scheduled payment date
        @param  _fwdId  fwd id
    */
    function _availSettlement(uint256 _fwdId) view internal {
        require(now >= (fwdRequests[_fwdId].contractDay.add(fwdRequests[_fwdId].settlementDuration.mul(1 days))));
    }

    /**
        @dev    confirm whether is it avail to hedge
                restriction1:  hedgeState is 'unstarted'
                restriction2:  fwdState is 'setDeposit'
                restriction3:  deposit amount is over 0
        @param  _fwdId  fwd id
    */
    function _availHedge(uint256 _fwdId) view internal {
        require(
            fwdIndexToHedgeState[_fwdId] == hedgeStates[0] &&
            fwdIndexToFwdState[_fwdId] != fwdStates[0] &&
            fwdDeposits[_fwdId] > 0);
    }

    /**
        @dev    confirm whether is it avail to replenish deposit
        @param  _fwdId  fwd id
    */
    function _availReplenish(uint256 _fwdId) view internal {
        require(fwdIndexToHedgeState[_fwdId] == hedgeStates[2]);
    }

    /**
        @dev    confirm whether the state is specific
        @param  _fwdId  fwd id
        @param  _index  index of fwdState
    */
    function _checkState(uint256 _fwdId, uint256 _index) view internal {
        require(fwdIndexToFwdState[_fwdId] == fwdStates[uint(_index)]);
    }

    /**
        @dev    confirm whether the hedgeState is specific
        @param  _fwdId  fwd id
        @param  _index  index of hedgeState
    */
    function _checkHedge(uint256 _fwdId, uint256 _index) view internal {
        require(fwdIndexToHedgeState[_fwdId] == hedgeStates[uint(_index)]);
    }

    /**
        @dev    get fwdRequest's balance
                premise: withdrawing deposit asset is done
                when cancel all fwdRequest, check wether deposit is refunded
        @param  _fwdId  fwd id
    */
    function _getFwdRequestBalance(uint256 _fwdId) view internal returns(uint256) {
        return fwdDeposits[_fwdId];
    }
}
