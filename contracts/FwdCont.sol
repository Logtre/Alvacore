pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/lifecycle/Pausable.sol";
import "https://github.com/Logtre/Alvacore/contracts/FwdOrderlyRequest.sol";
import "https://github.com/Logtre/Alvacore/contracts/math/SafeMath.sol";

contract FwdCont is Pausable {
    using SafeMath for uint256;

    /*event ForwardInfo(
    /    uint256 fwdId,
        address fwdOwner,
        bytes32 fwdState,
        uint256 contractDay,
        uint256 settlementDuration,
        uint256 expireDuration,
        address receiverAddr,
        address senderAddr,
        uint256 fee,
        uint256 baseAmt,
        uint256 fxRate,
        uint256 depositAmt
    ); // log for create requests*/

    /*event Request(
        uint256 requestId,
        address requester,
        bytes32 data
    ); // log for requests*/

    event FwdRequest(
        address fwdOwner,
        bytes32 fwdState,
        uint256 contractDay,
        uint256 settlementDuration,
        uint256 expireDuration,
        address receiverAddr,
        address senderAddr,
        uint256 baseAmt
    );

    event FwdResponse(
        uint256 requestId,
        address requester,
        uint256 error,
        uint256 data
    ); // log for responses

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


    event FwdCancel(uint256 fwdId, address canceller, uint256 flag);
    event FwdDelete(uint256 fwdId);
    event SetFwdState(uint256 fwdId, bytes32 fwdState);
    event SetFwdFee(uint256 storedFwdFee);
    event SetFxRate(uint256 fwdId, uint256 fxRate);
    event WithdrawDeposit(uint256 fwdId, address withdrawer, uint256 amount);
    event OutOfDeposit(uint256 fwdId, address sender, uint256 AdditionalCertificate);

    struct FwdRequestInfo { // the data struct for forward contract
        address fwdOwner;
        uint256 contractDay; // the date when conclude the trade contract
        uint256 settlementDuration; // the date when money will be moved
        uint256 expireDuration; // the date when contract will expire
        address receiverAddr; // the address whose owner will receive money
        address senderAddr; // the address whose owner will send money
        uint256 baseAmt; // the amount of money calculated on a USD base
    }

    bytes32[] internal fwdStates = [
        bytes32("requesting"),
        bytes32("getFxRate"),
        bytes32("setDeposit"),
        bytes32("confirmWithdraw"),
        bytes32("completeWithdraw"),
        bytes32("confirmCancel"),
        bytes32("canceled"),
        bytes32("confirmEmergency"),
        bytes32("emergencyCanceled"),
        bytes32("error:FwdOrderly"),
        bytes32("error:wrongData"),
        bytes32("error:ALVCServer")
    ];

    FwdOrderlyRequest internal requestOrderly;

    uint256 internal reqGas = 250000;

    bytes4 constant internal FWD_CALLBACK_FID = bytes4(keccak256("response(int256,int256,int256)"));
    bytes4 constant internal REQUESTTYPE = "FWD";
    bytes32 constant internal SYMBOL = "ETH";

    uint256 internal fwdCnt;
    bool public setOrderly;

    mapping (uint256 => FwdRequestInfo) internal fwdRequests; // the mapping to link fwdId and FwdCont (key:fwdID)
    mapping (uint256 => uint256) internal fwdIndexToRequests; // the mapping to link requestId and fwdId (key:requestId)
    mapping (uint256 => uint256) internal requestIndexToFees; // the mapping to link requestId and fee (key:requestId)
    mapping (uint256 => uint256) internal fwdIndexToFees; // the mapping to link fwdId and fee (key:fwdID)
    mapping (uint256 => bytes32) internal fwdIndexToFwdState; // the mapping to link fwdId and fwdState (key:fwdID)
    mapping (uint256 => uint256) internal fwdIndexToFxRate; // the mapping to link fwdId and fxRate (key:fwdID)
    mapping (uint256 => uint256) internal fwdDeposits; // the mapping to link fwdId and depositAmt (key:fwdID)

    mapping (uint256 => bool) internal cancelRequestSender;
    mapping (uint256 => bool) internal cancelRequestReceiver;

    modifier orderlyConnected() {
        require(setOrderly && address(requestOrderly) != address(0));
        _;
    }

    modifier onlyParty(uint256 _fwdId) {
        require(msg.sender == fwdRequests[_fwdId].fwdOwner ||
            msg.sender == fwdRequests[_fwdId].receiverAddr ||
            msg.sender == fwdRequests[_fwdId].senderAddr);
            _;
    }

    constructor() public { // constractor
        _createFwdRequest(
            msg.sender,
            now,
            0,
            0,
            address(0),
            address(0),
            0,
            0,
            0,
            0
            );
        //fwdCnt = 1;
        //fwdRequests[0].fwdOwner = msg.sender;
        owner = msg.sender;
        setOrderly = false;
    }

    function _addFwdRequest(uint256 _fwdId, FwdRequestInfo _fwdRequest, uint256 _requestId, uint256 _reqFee) private {
        fwdRequests[_fwdId] = _fwdRequest;
        fwdIndexToRequests[_fwdId] = _requestId;
        fwdIndexToFees[_fwdId] = msg.value - _reqFee;
        fwdIndexToFwdState[_fwdId] = fwdStates[0];
        fwdIndexToFxRate[_fwdId] = 0;
        fwdDeposits[_fwdId] = 0;
        cancelRequestSender[_fwdId] = false;
        cancelRequestReceiver[_fwdId] = false;
        fwdCnt ++;
    }

    function _createFwdRequest(
        address _fwdOwner,
        uint256 _contractDay,
        uint256 _settlementDuration,
        uint256 _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        uint256 _baseAmt,
        uint256 _fwdCnt,
        uint256 _requestId,
        uint256 _reqFee
        ) internal returns(uint256) {
        FwdRequestInfo memory fwdRequest = FwdRequestInfo({
            fwdOwner: _fwdOwner,
            contractDay: _contractDay, // the date when conclude the trade contract
            settlementDuration: _settlementDuration, // the date when money will be moved
            expireDuration: _expireDuration, // the date when contract will expire
            receiverAddr: _receiverAddr, // the address whose owner will receive money
            senderAddr: _senderAddr, // the address whose owner will send money
            baseAmt: _baseAmt // the amount of money calculated on a USD base
        });

        _addFwdRequest(_fwdCnt, fwdRequest, _requestId, _reqFee);

        emit FwdRequest(_fwdOwner, fwdStates[0], _contractDay, _settlementDuration, _expireDuration, _receiverAddr, _senderAddr, _baseAmt);
        emit SetFwdFee(fwdIndexToFees[_fwdCnt]);

        return _fwdCnt;
    }

    function _setReqFee(uint256 _reqGas) internal {
        reqGas = _reqGas;
    }

    function adminSetOrderly(address _requestOrderly) onlyOwner() public {
        requestOrderly = FwdOrderlyRequest(_requestOrderly);

        setOrderly = true;
    }

    function _cancel(uint256 _fwdId) internal {
        // delete fwdRequest
        _deleteFwdRequest(_fwdId);
    }

    function _deleteRequest(uint256 _fwdId) internal {
        requestOrderly.requestCancel(fwdIndexToRequests[_fwdId], minGas.mul(gasPrice).mul(80).div(100));
    }

    function _deleteFwdRequest(uint256 _fwdId) internal {
        // premise: withdrawing deposit asset is done
        // check wether deposit is refunded
        _noDeposit(_fwdId);
        // escape fwdRequest to another struct
        uint256 _payedFeeAmt = fwdIndexToFees[_fwdId];
        // escape fwdOwner to another struct
        address _fwdOwner = fwdRequests[_fwdId].fwdOwner;
        // delete mappings about fwd
        delete fwdRequests[_fwdId];
        delete fwdIndexToRequests[_fwdId];
        delete fwdIndexToFees[_fwdId];
        delete fwdIndexToFwdState[_fwdId];
        delete fwdIndexToFxRate[_fwdId];
        delete cancelRequestSender[_fwdId];
        delete cancelRequestReceiver[_fwdId];
        //delete fwdDeposits[_fwdId];
        // refund fee to fwdOwner
        //_transfer(_fwdOwner, minGas * gasPrice);
        _fwdOwner.transfer(minGas.mul(gasPrice));
        // refund surplus value to FwdCont's owner
        if (_payedFeeAmt - minGas.mul(gasPrice) > 0) {
            //_transfer(owner, _payedFeeAmt.sub(minGas.mul(gasPrice)));
            owner.transfer(_payedFeeAmt.sub(minGas.mul(gasPrice)));
        }
        // emit event
        emit FwdDelete(_fwdId);
    }

    function _noDeposit(uint256 _fwdId) view internal {
        require (fwdDeposits[_fwdId] == 0);
    }

    function _refundPayedDeposit(uint256 _fwdId) internal {
        // escape deposit to another struct
        uint256 targetDeposit = fwdDeposits[_fwdId];
        // delete deposit
        delete fwdDeposits[_fwdId];
        // refund value to sender
        //_transfer(fwdRequests[_fwdId].senderAddr, targetDeposit);
        fwdRequests[_fwdId].senderAddr.transfer(targetDeposit);
        // minus refund fee from fwdIndexToFees
        _setFwdFee(_fwdId, fwdIndexToFees[_fwdId] - minGas * gasPrice);
        // emit event
        emit WithdrawDeposit(_fwdId, fwdRequests[_fwdId].senderAddr, targetDeposit);
    }

    function _withdrawDepositWithRate(uint256 _fwdId, address _to, uint256 _fxRate) internal {
        // calculate payment amount
        uint256 _paymentAmt = _calculateFxAmt(fwdRequests[_fwdId].baseAmt, _fxRate);
        uint256 tempDeposit = fwdDeposits[_fwdId];

        if (tempDeposit > _paymentAmt) {
            // sufficient deposit exist
            // refund exchanged deposit
            //_transfer(_to, _paymentAmt);
            _to.transfer(_paymentAmt);
            // refund surplus deposit
            //_transfer(fwdRequests[_fwdId].senderAddr, fwdDeposits[_fwdId] - _paymentAmt - minGas * gasPrice);
            fwdRequests[_fwdId].senderAddr.transfer(fwdDeposits[_fwdId].sub(_paymentAmt).sub(minGas.mul(gasPrice)));
            // delete deposit
            delete fwdDeposits[_fwdId];
            // emit event
            emit WithdrawDeposit(_fwdId, _to, _paymentAmt);
        } else {
            // insufficient deposit exist
            // refund all deposit amount
            //_transfer(_to, fwdDeposits[_fwdId] - minGas * gasPrice);
            _to.transfer(fwdDeposits[_fwdId].sub(minGas.mul(gasPrice)));
            // update deposit amount
            fwdDeposits[_fwdId] = 0;
            // emit event
            emit OutOfDeposit(_fwdId, fwdRequests[_fwdId].senderAddr, _paymentAmt - tempDeposit);
        }
    }

    function _calculateFxAmt(uint256 _baseAmt, uint256 _fxRate) pure internal returns(uint256) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // Assumed unit is ether = 1000 finney
        uint256 unit = 1000 finney;
        //uint256 exchangedAmt = _baseAmt  * 1000 * unit / _fxRate;
        uint256 exchangedAmt = _baseAmt.mul(1000).mul(unit).div(_fxRate);
        return exchangedAmt;
    }

    function _calculateFxAmtFromId(uint256 _fwdId) view internal returns(uint256) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // unit is finney (=1/1000 ether)
        uint256 unit = 1000 finney;
        //return fwdRequests[_fwdId].baseAmt * 1000 * unit / fwdIndexToFxRate[_fwdId];
        return fwdRequests[_fwdId].baseAmt.mul(1000).mul(unit).div(fwdIndexToFxRate[_fwdId]);
    }

    function _calculateTotalFee(uint256 _minGas, uint256 _reqGas, uint256 _gasPrice, uint256 _buffer) view internal returns(uint256) {
        //uint256 fwdFetchRateFee = _minGas * _gasPrice;
        uint256 fwdFetchRateFee = _minGas.mul(_gasPrice);
        uint256 fwdDepositFee = _minGas * _gasPrice;
        uint256 fwdConfirmFee = _minGas * _gasPrice;
        uint256 fwdWithdrawFee = _minGas * _gasPrice;
        uint256 fwdCancellationFee = _reqGas * gasPrice;
        uint256 totalFee = (fwdFetchRateFee + fwdDepositFee + fwdConfirmFee + fwdWithdrawFee + fwdCancellationFee) * _buffer / 100;

        return totalFee;
    }

    function _setFwdState(uint256 _fwdId, uint256 _index) internal {
        fwdIndexToFwdState[_fwdId] = fwdStates[uint(_index)];

        emit SetFwdState(_fwdId, fwdStates[uint(_index)]);
    }

    function _setFxRate(uint256 _fwdId, uint256 _fxRate) internal {
        fwdIndexToFxRate[_fwdId] = _fxRate;

        emit SetFxRate(_fwdId, _fxRate);
    }

    function _setFwdFee(uint256 _fwdId, uint256 _fee) internal {
        fwdIndexToFees[_fwdId] = _fee;
    }

    function _isOrderly(address _from) view internal {
        require(_from == address(requestOrderly));
    }

    function _isSender(uint256 _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].senderAddr);
    }

    function _isReceiver(uint256 _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].receiverAddr);
    }

    function _availSettlement(uint256 _fwdId) view internal {
        require(now >= fwdRequests[_fwdId].contractDay + fwdRequests[_fwdId].settlementDuration * 1 days);
    }

    function _isExpired(uint256 _fwdId) view internal {
        require(now >= fwdRequests[_fwdId].contractDay + fwdRequests[_fwdId].expireDuration * 1 days);
    }

    function _checkState(uint256 _fwdId, uint256 _index) view internal {
        require(fwdIndexToFwdState[_fwdId] == fwdStates[uint(_index)]);
    }
}
