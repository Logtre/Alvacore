pragma solidity ^0.4.24;

import "./FwdOrderlyRequest.sol";
import "./FwdBase.sol";
import "../math/SafeMath.sol";

/**
    @dev FwdCont defines basic function and variable for FwdCore.
*/
contract FwdCont is FwdBase {
    using SafeMath for uint256;

    event AddFwdRequest(
        uint256 fwdId,
        address fwdOwner,
        bytes32 fwdState,
        uint256 contractDay,
        uint256 settlementDuration,
        address receiverAddr,
        address senderAddr,
    );

    event FwdDeposit(
        uint256 fwdId,
        uint256 depositAmt,
        bytes32 fwdState,
        uint256 fee
    );

    event FwdWithdrawConfirm(
        uint256 fwdId,
        bytes32 fwdState
    );

    event SetFwdAmount(
        uint256 fwdId,
        bytes32 fwdState,
        uint256 settleAmount
    );

    event FwdCancel(
        uint256 fwdId,
        address canceller,
        uint256 flag
    );

    event FwdDelete(
        uint256 fwdId
    );

    event SetFwdFee(
        uint256 FwdFee
    );

    event Withdrawn(
        uint256 fwdId,
        address withdrawer,
        uint256 amount
    );

    event AdminWithdrawn(
        address owner,
        uint256 amount
    );

    event RefundDeposit(
        address fwdId,
        address senderAddr,
        uint256 amount
    );

    mapping (uint256 => FwdRequest) internal fwdRequests; // the mapping to link fwdId and FwdCont (key:fwdID)
    mapping (uint256 => bytes32) internal fwdIndexToFwdState; // the mapping to link fwdId and fwdState (key:fwdID)
    mapping (uint256 => uint256) internal fwdDeposits; // the mapping to link fwdId and depositAmt (key:fwdID)
    mapping (uint256 => uint256) internal fwdHegdes; // the mapping to link fwdId and hedge (key:fwdID)

    mapping (uint256 => bool) internal cancelRequestSender; // the mapping to link fwdId and cancelFlag
    mapping (uint256 => bool) internal cancelRequestReceiver; // the mapping to link fwdId and cancelFlag

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
        bytes32("confirmWithdraw"),
        bytes32("setFwdAmount")
        bytes32("withdrawn"),
        bytes32("confirmCancel"),
        bytes32("canceled"),
        bytes32("confirmEmergency"),
        bytes32("emergencyCanceled"),
        bytes32("error:FwdOrderly"),
        bytes32("error:wrongData"),
        bytes32("error:ALVCServer")
    ];

    //bytes4 constant internal REQUESTTYPE = "FWD";
    //bytes32 constant internal SYMBOL = "ETH";

    uint256 internal fwdCnt;

    /**
        @dev this modifier is used to decide
    */
    modifier onlyParty(uint256 _fwdId) {
        require(msg.sender == fwdRequests[_fwdId].fwdOwner ||
            msg.sender == fwdRequests[_fwdId].receiverAddr ||
            msg.sender == fwdRequests[_fwdId].senderAddr);
            _;
    }

    uint256 _contractDay, // date when contract is created
    uint256 _settlementDuration, // date when asset will be sent
    address _receiverAddr, // address of receiver of asset
    address _senderAddr, // address of sender of asset
    uint256 _fwdCnt, // the number of fwdRequest

    constructor() public { // constractor
        _createFwdRequest(
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
    function _addFwdRequest(uint256 _fwdId, FwdRequest _fwdRequest) private {
        fwdRequests[_fwdId] = _fwdRequest;
        fwdIndexToFwdState[_fwdId] = fwdStates[0];
        fwdDeposits[_fwdId] = 0;
        cancelRequestSender[_fwdId] = false;
        cancelRequestReceiver[_fwdId] = false;
        fwdCnt ++;
    }

    /**
        @dev add fwd request
        @param _fwdOwner
        @param _contractDay   date when contract is created
        @param _settlementDuration   date when asset will be sent
        @param _receiverAddr   address of receiver of asset
        @param _senderAddr   address of sender of asset
        @param _fwdCnt   serial number of fwdRequest.
    */
    function _createFwdRequest(
        address _fwdOwner,
        uint256 _contractDay,
        uint256 _settlementDuration,
        address _receiverAddr,
        address _senderAddr,
        uint256 _fwdCnt,
        ) internal returns(uint256) {

        FwdRequest memory fwdRequest = FwdRequest({
            contractDay: _contractDay, // the date when conclude the trade contract
            settlementDuration: _settlementDuration, // the date when money will be moved
            receiverAddr: _receiverAddr, // the address whose owner will receive money
            senderAddr: _senderAddr, // the address whose owner will send money
        });

        _addFwdRequest(
            _fwdCnt, // fwdCnt is use as fwdId
            fwdRequest
        );

        emit AddFwdRequest(
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
        @dev cancel fwdRequest
        @param _fwdId
    */
    function _cancel(uint256 _fwdId) internal {
        // delete fwdRequest
        _deleteFwdRequest(_fwdId);
    }

    /**
        @dev get fwdRequest's balance
        @dev premise: withdrawing deposit asset is done
        @dev when cancel all fwdRequest, check wether deposit is refunded
        @param _fwdId
    */
    function _getFwdRequestBalance(uint256 _fwdId) view internal {
        return fwdDeposits[_fwdId];
    }

    /**
        @dev cancel fwdRequest linked specified fwdId
        @dev premise: withdrawing deposit asset is done
        @dev when cancel all fwdRequest, check wether deposit is refunded
        @param _fwdId
    */
    function _deleteFwdRequest(uint256 _fwdId) internal {
        _noDeposit(_fwdId);
        // escape fwdRequest to another struct
        uint256 _payedFeeAmt = fwdIndexToFees[_fwdId];
        // escape fwdOwner to another struct
        address _fwdOwner = fwdRequests[_fwdId].fwdOwner;
        // delete mappings about fwd
        delete fwdRequests[_fwdId];
        delete fwdIndexToFwdState[_fwdId];
        delete cancelRequestSender[_fwdId];
        delete cancelRequestReceiver[_fwdId];
        // emit event
        emit FwdDelete(_fwdId);
    }

    /**
        @dev check whether deposit is set or not
        @param _fwdId
    */
    function _noDeposit(uint256 _fwdId) view internal {
        require (fwdDeposits[_fwdId] == 0);
    }

    /**
        @dev refund deposited asset to sender
        @param _fwdId
    */
    function _refundDeposit(uint256 _fwdId) internal {
        // escape deposit to another struct with minus fee
        uint256 targetDeposit = fwdDeposits[_fwdId].sub(processFee);
        // delete deposit
        delete fwdDeposits[_fwdId];
        // refund value to sender
        fwdRequests[_fwdId].senderAddr.transfer(targetDeposit);
        // emit event
        emit RefundDeposit(_fwdId, fwdRequests[_fwdId].senderAddr, targetDeposit);
    }

    /**
        @dev transfer asset to receiver with add hedge amount
        @param _fwdId
        @param _to   receiver's address
    */
    function _withdrawDeposit(uint256 _fwdId, address _to) internal {
        // calculate payment amount(add hedge amount , and minus fee)
        uint256 _paymentAmt = fwdDeposits[_fwdId].add(fwdHedge[_fwdId]).sub(processFee);
        // transfer asset to receiver
        _to.transfer(_paymentAmt);
        // delete mapping
        delete fwdDeposits[_fwdId];
        // emit event
        emit Withdrawn(_fwdId, _to, _paymentAmt);
    }

    /**
        @dev set fwdState
        @param _fwdId
        @param _index   index of fwdState
    */
    function _setFwdState(uint256 _fwdId, uint256 _index) internal {
        fwdIndexToFwdState[_fwdId] = fwdStates[uint(_index)];
        // emit event
        emit SetFwdState(_fwdId, fwdStates[uint(_index)]);
    }

    /**
        @dev set fee
        @param _fwdId
        @param _fee   amount of fee (unit: finney)
    */
    function _setFwdFee(uint256 _fwdId, uint256 _fee) internal {
        // set fee
        processFee = _fee.mul(1 finney);
        // emit event
        emit SetFwdFee(procwssFee);
    }

    /**
        @dev confirm operator is sender
        @param _fwdId
    */
    function _isSender(uint256 _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].senderAddr);
    }

    /**
        @dev confirm operator is receiver
        @param _fwdId
    */
    function _isReceiver(uint256 _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].receiverAddr);
    }

    /**
        @dev confirm whether is it after the scheduled payment date
        @param _fwdId
    */
    function _availSettlement(uint256 _fwdId) view internal {
        require(now >= (fwdRequests[_fwdId].contractDay.add(fwdRequests[_fwdId].settlementDuration)).mul(1 days);
    }

    /**
        @dev confirm whether the state is specific
        @param _fwdId
    */
    function _checkState(uint256 _fwdId, uint256 _index) view internal {
        require(fwdIndexToFwdState[_fwdId] == fwdStates[uint(_index)]);
    }
}
