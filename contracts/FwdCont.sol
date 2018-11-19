pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/Base.sol";
import "https://github.com/Logtre/Alvacore/contracts/FwdOrderlyRequest.sol";


contract FwdCont is Base {

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

    event Deposit(
        int fwdId,
        int depositAmt,
        bytes32 fwdState,
        int fee
    );

    event FwdRequestInfo(
        address fwdOwner,
        int contractDay,
        int settlementDuration,
        int expireDuration,
        address receiverAddr,
        address senderAddr,
        int baseAmt
    );

    event FwdCancel(int fwdId, address canceller, int flag);
    event FwdDelete(int fwdId);
    event SetFwdState(int fwdId, bytes32 fwdState);
    event SetFwdFee(int storedFwdFee);
    event SetFxRate(int fwdId, int fxRate);
    event WithdrawDeposit(int fwdId, address withdrawer, int amount);
    event OutOfDeposit(int fwdId, address sender, int AdditionalCertificate);

    struct FwdRequest { // the data struct for forward contract
        address fwdOwner;
        int contractDay; // the date when conclude the trade contract
        int settlementDuration; // the date when money will be moved
        int expireDuration; // the date when contract will expire
        address receiverAddr; // the address whose owner will receive money
        address senderAddr; // the address whose owner will send money
        int baseAmt; // the amount of money calculated on a USD base
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

    int internal reqGas = 250000;

    bytes4 constant internal FWD_CALLBACK_FID = bytes4(keccak256("response(int256,int256,int256)"));
    bytes4 constant internal REQUESTTYPE = "FWD";
    bytes32 constant internal SYMBOL = "ETH";

    int internal fwdCnt;
    bool public setOrderly;

    mapping (int => FwdRequest) internal fwdRequests; // the mapping to link fwdId and FwdCont (key:fwdID)
    mapping (int => int) internal fwdIndexToRequests; // the mapping to link requestId and fwdId (key:requestId)
    mapping (int => int) internal requestIndexToFees; // the mapping to link requestId and fee (key:requestId)
    mapping (int => int) internal fwdIndexToFees; // the mapping to link fwdId and fee (key:fwdID)
    mapping (int => bytes32) internal fwdIndexToFwdState; // the mapping to link fwdId and fwdState (key:fwdID)
    mapping (int => int) internal fwdIndexToFxRate; // the mapping to link fwdId and fxRate (key:fwdID)
    mapping (int => int) internal fwdDeposits; // the mapping to link fwdId and depositAmt (key:fwdID)

    mapping (int => bool) internal cancelRequestSender;
    mapping (int => bool) internal cancelRequestReceiver;

    modifier orderlyConnected() {
        require(setOrderly && address(requestOrderly) != 0x0000000000000000000000000000000000000000);
        _;
    }

    modifier onlyParty(int _fwdId) {
        require(msg.sender == fwdRequests[_fwdId].fwdOwner ||
            msg.sender == fwdRequests[_fwdId].receiverAddr ||
            msg.sender == fwdRequests[_fwdId].senderAddr);
            _;
    }

    constructor() public { // constractor
        _createFwdRequest(
            msg.sender,
            int(now),
            0,
            0,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
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

    function _addFwdRequest(int _fwdId, FwdRequest _fwdRequest, int _requestId, int _reqFee) private {
        fwdRequests[_fwdId] = _fwdRequest;
        fwdIndexToRequests[_fwdId] = _requestId;
        fwdIndexToFees[_fwdId] = int(msg.value) - _reqFee;
        fwdIndexToFwdState[_fwdId] = fwdStates[0];
        fwdIndexToFxRate[_fwdId] = 0;
        fwdDeposits[_fwdId] = 0;
        cancelRequestSender[_fwdId] = false;
        cancelRequestReceiver[_fwdId] = false;
        fwdCnt ++;
    }

    function _createFwdRequest(
        address _fwdOwner,
        int _contractDay,
        int _settlementDuration,
        int _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        int _baseAmt,
        int _fwdCnt,
        int _requestId,
        int _reqFee
        ) internal returns(int) {
        FwdRequest memory fwdRequest = FwdRequest({
            fwdOwner: _fwdOwner,
            contractDay: _contractDay, // the date when conclude the trade contract
            settlementDuration: _settlementDuration, // the date when money will be moved
            expireDuration: _expireDuration, // the date when contract will expire
            receiverAddr: _receiverAddr, // the address whose owner will receive money
            senderAddr: _senderAddr, // the address whose owner will send money
            baseAmt: _baseAmt // the amount of money calculated on a USD base
        });

        _addFwdRequest(_fwdCnt, fwdRequest, _requestId, _reqFee);

        emit FwdRequestInfo(_fwdOwner, _contractDay, _settlementDuration, _expireDuration, _receiverAddr, _senderAddr, _baseAmt);
        emit SetFwdFee(fwdIndexToFees[_fwdCnt]);

        return _fwdCnt;
    }

    function _setReqFee(int _reqGas) internal {
        reqGas = _reqGas;
    }

    function adminSetOrderly(address _requestOrderly) onlyOwner() public {
        requestOrderly = FwdOrderlyRequest(_requestOrderly);

        setOrderly = true;
    }

    function _cancel(int _fwdId) internal {
        // delete fwdRequest
        _deleteFwdRequest(_fwdId);
    }

    function _deleteRequest(int _fwdId) internal {
        requestOrderly.requestCancel(fwdIndexToRequests[_fwdId], minGas * gasPrice * 80 / 100);
    }

    function _deleteFwdRequest(int _fwdId) internal {
        // premise: withdrawing deposit asset is done
        // check wether deposit is refunded
        _noDeposit(_fwdId);
        // escape fwdRequest to another struct
        int _payedFeeAmt = fwdIndexToFees[_fwdId];
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
        _transfer(_fwdOwner, minGas * gasPrice);
        // refund surplus value to FwdCont's owner
        if (_payedFeeAmt - minGas * gasPrice > 0) {
            _transfer(owner, _payedFeeAmt - minGas * gasPrice);
        }
        // emit event
        emit FwdDelete(_fwdId);
    }

    function _noDeposit(int _fwdId) view internal {
        require (fwdDeposits[_fwdId] == 0);
    }

    function _refundPayedDeposit(int _fwdId) internal {
        // escape deposit to another struct
        int targetDeposit = fwdDeposits[_fwdId];
        // delete deposit
        delete fwdDeposits[_fwdId];
        // refund value to sender
        _transfer(fwdRequests[_fwdId].senderAddr, targetDeposit);
        // minus refund fee from fwdIndexToFees
        _setFwdFee(_fwdId, fwdIndexToFees[_fwdId] - minGas * gasPrice);
        // emit event
        emit WithdrawDeposit(_fwdId, fwdRequests[_fwdId].senderAddr, targetDeposit);
    }

    function _withdrawDepositWithRate(int _fwdId, address _to, int _fxRate) internal {
        // calculate payment amount
        int _paymentAmt = _calculateFxAmt(fwdRequests[_fwdId].baseAmt, _fxRate);
        int tempDeposit = fwdDeposits[_fwdId];

        if (tempDeposit > _paymentAmt) {
            // sufficient deposit exist
            // refund exchanged deposit
            _transfer(_to, _paymentAmt);
            // refund surplus deposit
            _transfer(fwdRequests[_fwdId].senderAddr, fwdDeposits[_fwdId] - _paymentAmt - minGas * gasPrice);
            // delete deposit
            delete fwdDeposits[_fwdId];
            // emit event
            emit WithdrawDeposit(_fwdId, _to, _paymentAmt);
        } else {
            // insufficient deposit exist
            // refund all deposit amount
            _transfer(_to, fwdDeposits[_fwdId] - minGas * gasPrice);
            // update deposit amount
            fwdDeposits[_fwdId] = 0;
            // emit event
            emit OutOfDeposit(_fwdId, fwdRequests[_fwdId].senderAddr, _paymentAmt - tempDeposit);
        }
    }

    function _calculateFxAmt(int _baseAmt, int _fxRate) pure internal returns(int) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // Assumed unit is ether = 1000 finney
        int unit = 1000 finney;
        int exchangedAmt = _baseAmt  * 1000 * unit / _fxRate;
        return exchangedAmt;
    }

    function _calculateFxAmtFromId(int _fwdId) view internal returns(int) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // unit is finney (=1/1000 ether)
        int unit = 1000 finney;
        return fwdRequests[_fwdId].baseAmt * 1000 * unit / fwdIndexToFxRate[_fwdId];
    }

    function _calculateTotalFee(int _minGas, int _reqGas, int _gasPrice, int _buffer) view internal returns(int) {
        int fwdFetchRateFee = _minGas * _gasPrice;
        int fwdDepositFee = _minGas * _gasPrice;
        int fwdConfirmFee = _minGas * _gasPrice;
        int fwdWithdrawFee = _minGas * _gasPrice;
        int fwdCancellationFee = _reqGas * gasPrice;
        int totalFee = (fwdFetchRateFee + fwdDepositFee + fwdConfirmFee + fwdWithdrawFee + fwdCancellationFee) * _buffer / 100;

        return totalFee;
    }

    function _setFwdState(int _fwdId, int _index) internal {
        fwdIndexToFwdState[_fwdId] = fwdStates[uint(_index)];

        emit SetFwdState(_fwdId, fwdStates[uint(_index)]);
    }

    function _setFxRate(int _fwdId, int _fxRate) internal {
        fwdIndexToFxRate[_fwdId] = _fxRate;

        emit SetFxRate(_fwdId, _fxRate);
    }

    function _setFwdFee(int _fwdId, int _fee) internal {
        fwdIndexToFees[_fwdId] = _fee;
    }

    function _isOrderly(address _from) view internal {
        require(_from == address(requestOrderly));
    }

    function _isSender(int _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].senderAddr);
    }

    function _isReceiver(int _fwdId) view internal {
        require(msg.sender == fwdRequests[_fwdId].receiverAddr);
    }

    function _availSettlement(int _fwdId) view internal {
        require(int(now) >= fwdRequests[_fwdId].contractDay + fwdRequests[_fwdId].settlementDuration * 1 days);
    }

    function _isExpired(int _fwdId) view internal {
        require(int(now) >= fwdRequests[_fwdId].contractDay + fwdRequests[_fwdId].expireDuration * 1 days);
    }

    function _checkState(int _fwdId, int _index) view internal {
        require(fwdIndexToFwdState[_fwdId] == fwdStates[uint(_index)]);
    }
}
