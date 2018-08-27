pragma solidity ^0.4.9;

contract FwdAccessControl {

    address public owner;

    bool public paused = false;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    function setOwner(address _newOwner) external onlyOwner() {
        require(_newOwner != address(0));

        owner = _newOwner;
    }

    function pause() external onlyOwner() whenNotPaused() {
        paused = true;
    }

    function unpause() public onlyOwner() whenPaused() {
        paused = false;
    }
}

contract FwdBase is FwdAccessControl {

    event Upgrade(address newAddr);

    int public minGas = 300000;
    int public gasPrice = 5 * 10**10;
    int public cancellationGas = 250000; // charged when the requester cancels a request that is not responded
    int public externalGas = 50000;

    int public constant CANCELLED_FEE_FLAG = 1;
    int public constant DELIVERED_FEE_FLAG = 0;
    int public constant FAIL_FLAG = -2 ** 250;
    int public constant SUCCESS_FLAG = 1;

    bool public killswitch;
    bool public cancelFlag;
    int public unrespondedCnt;
    int public newVersion;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier available() {
        require(killswitch == false && newVersion == 0);
        _;
    }

    modifier noKillswitch() {
        require(killswitch == false);
        _;
    }

    modifier noCancelFlag() {
        require(cancelFlag == false);
        _;
    }

    modifier noNewVersion() {
        require(newVersion == 0);
        _;
    }

    constructor() public {
        killswitch = false;
        cancelFlag = false;
        unrespondedCnt = 0;
        newVersion = 0;
    }

    function _convertBytesToBytes8(bytes inBytes) internal pure returns (bytes8 outBytes8) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes8 := mload(add(inBytes, 8))
        }
    }

    function _convertBytesToBytes32(bytes inBytes) internal pure returns (bytes32 outBytes32) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes32 := mload(add(inBytes, 32))
        }
    }

    function _withdraw() internal {
        if (!owner.call.value(address(this).balance)()) {
            revert();
        }
    }

    function _upgrade(address _newAddr) internal {
        newVersion = -int(_newAddr);
        killswitch = true;
        emit Upgrade(_newAddr);
    }

    function _restart() internal {
        if (newVersion == 0) {
            killswitch = false;
        }
    }

    function _setFees(int _gasPrice, int _minGas, int _cancellationGas, int _externalGas) internal {
        gasPrice = _gasPrice;
        minGas = _minGas;
        cancellationGas = _cancellationGas;
        externalGas = _externalGas;
    }
    function _resetKillswitch() internal {
        killswitch = false;
    }

    function _resetUnrespond() internal {
        unrespondedCnt = 0;
    }

    function _setNewVersion(address _newAddr) internal {
        newVersion = int(_newAddr);
    }

    function _externalCall(address _to, int _value) internal {
        // if transfer volume greater than balance,
        // set volume as 80% of balance.
        // if there is surplus asset, administor
        // withdraw via withdraw function.
        if (_value > int(address(this).balance)) {
            _value = int(address(this).balance * 80 / 100);
        }

        if (!_to.call.value(uint(_value))()) {
            revert();
        }
    }

    function _transfer(address _to, int _value) internal {
        // if transfer volume greater than balance,
        // set volume as 80% of balance.
        // if there is surplus asset, administor
        // withdraw via withdraw function.
        if (_value > int(address(this).balance)) {
            _value = int(address(this).balance * 80 / 100);
        }

        if (!_to.send(uint(_value))) {
            revert();
        }
    }

    function _setAllCancel(bool _flag) internal {
        cancelFlag = _flag;
    }
}

contract FwdOrderly is FwdBase {

    event RequestCancel(int requestId, address canceller, int flag);
    event RequestDelete(int requestId);
    event RequestState(int requestId, bytes32 requestState);

    struct Request { // the data structure for each request
        address requester;
        int fee; // the amount of wei the requester pays for the request
        bytes4 callbackFID; // the specification of the callback function
        bytes32 paramsHash; // the hash of the request parameters
        int timestamp; // the timestamp of the request emitted
        bytes32 requestData; // the request data
    }

    bytes32[] public requestStates = [
        bytes32("requesting"),
        bytes32("delivering"),
        bytes32("canceled"),
        bytes32("pendingFromOwner"),
        bytes32("error:wrongData"),
        bytes32("error:ALVCServer")
    ];

    address public ALVC_ADDRESS = 0xD7E2b2857fA34F08Db2262Fb684A3782BC750e70; // address of the ALVC ADDRESS @TestNet
    address public ALVC_WALLET = 0x0115b95cdF80C0463c60190efC965Ba857F2F8B7; // address of the ALVC WALLET @TestNet

    bytes32 public constant KEYWORD = "FWD";

    mapping (int => Request) public requests;
    mapping (int => bytes32) public requestIndexToState;

    int public requestCnt;

    constructor() public {
        // Start request IDs at 1 for two reasons:
        //   1. We can use 0 to denote an invalid request (ids are unsigned)
        //   2. Storage is more expensive when changing something from zero to non-zero,
        //      so this means the first request isn't randomly more expensive.
        _createRequest(msg.sender, 0, "", "", int(now), "", 0);
        //requestCnt = 1;
        owner = msg.sender;
        killswitch = false;
        cancelFlag = false;
        unrespondedCnt = 0;
    }

    function _addRequest(int _requestId, Request _request) private {
        requests[_requestId] = _request;
        requestIndexToState[_requestId] = requestStates[0];
        requestCnt ++;
    }

    function _createRequest(
        address _requester,
        int _fee,
        bytes4 _callbackFID,
        bytes32 _paramsHash,
        int _timestamp,
        bytes32 _requestData,
        int _requestCnt
        ) internal returns(int) {
        Request memory request = Request({
            requester: _requester,
            fee: _fee, // the amount of wei the requester pays for the request
            callbackFID: _callbackFID, // the specification of the callback function
            paramsHash: _paramsHash, // the hash of the request parameters
            timestamp: _timestamp, // the timestamp of the request emitted
            requestData: _requestData // the request data
        });

        _addRequest(_requestCnt, request);

        return _requestCnt;
    }

    function _setAlvcWallet(address _newAlvcWallet) internal {
        ALVC_WALLET = _newAlvcWallet;
    }

    function getRequestIndex() public view returns(int) {
        int requestsLength = requestCnt;

        for (int i=1; i<requestsLength; i++) {
            if (requestIndexToState[i] == requestStates[0]) {
                return (i);
            }
        }
        // there is request to match requestState
        return 0;
    }

    function getRequest(int _requestId) view public returns(bytes32, int, bytes32, bytes32) {
        bytes32 _requestType = KEYWORD;
        int _timestamp = requests[_requestId].timestamp;
        bytes32 _requestState = requestIndexToState[_requestId];
        bytes32 _requestData = requests[_requestId].requestData;

        return(_requestType, _timestamp, _requestState, _requestData);
    }

    function _cancel(int _requestId, int _value) internal {
        // return value and delete request
        _deleteRequest(_requestId, msg.sender, _value);
        // emit event
        emit RequestCancel(_requestId, msg.sender, SUCCESS_FLAG);
    }

    function _deleteRequest(int _requestId, address _to, int _value) internal {
        // escape Request another struct
        Request memory targetRequest = requests[_requestId];
        // delete request
        delete requests[_requestId];
        // in case refund someone, refund process is executed
        if (_value > 0) {
            // refund value
            _transfer(_to, _value);

        }
        // refund surplus value
        if(targetRequest.fee - _value > 0) {
            _transfer(owner, targetRequest.fee - _value);
        }
        // emit event
        emit RequestDelete(_requestId);
    }

    function _setRequestState(int _requestId, uint _index) internal {
        requestIndexToState[_requestId] = requestStates[_index];

        emit RequestState(_requestId, requestStates[_index]);
    }

    function _isRequester(int _requestId) view internal {
         require (msg.sender == requests[_requestId].requester);
    }

    function _isFwd(bytes32 _keyword) pure internal {
        require (keccak256(abi.encodePacked(_keyword)) == keccak256(abi.encodePacked(KEYWORD)));
    }

    function _isALVC(address _from) view internal {
        require (_from == ALVC_WALLET);
    }
}

contract FwdOrderlyRequest is FwdOrderly {

    event RequestInfo(int requestId, bytes4 requestType, address requester, int fee, bytes32 paramsHash, int timestamp, bytes32 _requestState, bytes32 requestData); // log of requests, the Town Crier server watches this event and processes requests
    event DeliverInfo(int requestId, int fee, int gasPrice, int gasLeft, int callbackGas, bytes32 paramsHash, int error, int respData); // log of responses
    // for debug
    event CheckFee(int msgValue, int minFee, address msgSnder);

    function withdraw() onlyOwner() public {
        _withdraw();
    }

    function request(
        bytes32 _requestType,
        address _requester,
        bytes4 _callbackFID,
        int _timestamp,
        bytes32 _requestData
        ) whenNotPaused() available() noCancelFlag() public payable returns (int) {

        //int _requestCnt = requestCnt;

        _isFwd(_requestType);

        if (int(msg.value) < minGas * gasPrice) {
            //emit CheckFee(msg.value, minGas * gasPrice, msg.sender);
            //_externalCall(msg.sender, msg.value);
            //return FAIL_FLAG;
            revert();
        } else {

            int requestId = _createRequest(
                _requester,
                int(msg.value),
                _callbackFID,
                keccak256(abi.encodePacked(_requestType, _requestData)),
                _timestamp,
                _requestData,
                requestCnt
            );

            // Log the request for the Town Crier server to process.
            emit RequestInfo(
                requestId,
                bytes4(_requestType),
                msg.sender,
                int(msg.value),
                keccak256(abi.encodePacked(_requestType, _requestData)),
                _timestamp,
                requestStates[0],
                _requestData
            );

            return requestId;
        }
    }

    function requestCancel(
        int _requestId,
        int _value
        ) public  whenNotPaused() available() {
        // primise: this function is called by FwdCont
        _isRequester(_requestId); // only requester can execute

        _cancel(_requestId, _value);
    }

    function deliver(int _requestId, bytes _paramsHash, int _error, int _respData) whenNotPaused() available() public {
        int _callbackGas = (requests[_requestId].fee - minGas * gasPrice) / int(tx.gasprice); // gas left for the callback function
        bytes32 _paramsHash32bytes = _convertBytesToBytes32(_paramsHash);

        _isALVC(msg.sender);

        if (_requestId <= 0 ||
            _paramsHash32bytes != requests[_requestId].paramsHash) {
            // error
            _setRequestState(_requestId, 4);
            return;
        } else if (cancelFlag) {
            // If the request is cancelled by the requester, cancellation
            // fee goes to the SGX account and set the request as having
            // been responded to.
            _transfer(ALVC_ADDRESS, cancellationGas * gasPrice);
            // canceled
            _setRequestState(_requestId, 2);
            return;
        }

        if (_error < 2) {
            // Either no error occurs, or the requester sent an invalid query.
            // Send the fee to the SGX account for its delivering.
            _transfer(ALVC_ADDRESS, requests[_requestId].fee);
        } else {
            // Error in TC, refund the requester.
            _transfer(requests[_requestId].requester, requests[_requestId].fee);

            _setRequestState(_requestId, 5);
        }

        emit DeliverInfo(_requestId, requests[_requestId].fee, int(tx.gasprice), int(gasleft()), _callbackGas, _paramsHash32bytes, _error, _respData); // log the response information

        if (_callbackGas > int(gasleft()/tx.gasprice) - externalGas) {
            _callbackGas = int(gasleft()/tx.gasprice) - externalGas;
        }

        if(!requests[_requestId].requester.call.gas(uint(_callbackGas * gasPrice))(
            requests[_requestId].callbackFID,
            _requestId,
            _error,
            _respData)) { // call the callback function in the application contract
            revert();
        }

        _setRequestState(_requestId, 1);

        _deleteRequest(_requestId, ALVC_ADDRESS, minGas * gasPrice * 80 / 100);
    }

    function setAllCancel(bool _flag) onlyOwner() public {
        _setAllCancel(_flag);
    }

    function setAlvcWallet(address _newAlvcWallet) onlyOwner() public {
        _setAlvcWallet(_newAlvcWallet);
    }

    function setFees(int _gasPrice, int _minGas, int _cancellationGas, int _externalGas) onlyOwner() public {
        _setFees(_gasPrice, _minGas, _cancellationGas, _externalGas);
    }

    function resetKillswitch() onlyOwner() public {
        _resetKillswitch();
    }

    function resetUnrespond() onlyOwner() public {
        _resetUnrespond();
    }

    function setNewVersion(address _newAddr) onlyOwner() public {
        _setNewVersion(_newAddr);
    }

    function setRequestState(int _requestId, uint _index) onlyOwner() public {
        _setRequestState(_requestId, _index);
    }
}



contract FwdCont is FwdBase {

    event FwdRequestInfo(address fwdOwner, int contractDay, int settlementDuration, int expireDuration, address receiverAddr, address senderAddr, int baseAmt);
    event FwdCancel(int fwdId, address canceller, int flag);
    event FwdDelete(int fwdId);
    event SetFwdState(int fwdId, bytes32 fwdState);
    event SetFwdFee(int storedFwdFee);
    event SetFxRate(int fwdId, int fxRate);
    event WithdrawDeposit(int fwdId, address withdrawer, int amount);
    event OutOfDeposit(int fwdId, address sender, int Additional_certificate);

    struct FwdRequest { // the data struct for forward contract
        address fwdOwner;
        int contractDay; // the date when conclude the trade contract
        int settlementDuration; // the date when money will be moved
        int expireDuration; // the date when contract will expire
        address receiverAddr; // the address whose owner will receive money
        address senderAddr; // the address whose owner will send money
        int baseAmt; // the amount of money calculated on a USD base
    }

    bytes32[] public fwdStates = [
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

    FwdOrderlyRequest public requestOrderly;

    int public reqGas = 250000;

    bytes4 constant public FWD_CALLBACK_FID = bytes4(keccak256("response(int256,int256,int256)"));
    bytes4 constant public REQUESTTYPE = "FWD";
    bytes32 constant public SYMBOL = "ETH";

    int public fwdCnt;
    bool public setOrderly;

    mapping (int => FwdRequest) public fwdRequests; // the mapping to link fwdId and FwdCont (key:fwdID)
    mapping (int => int) public fwdIndexToRequests; // the mapping to link requestId and fwdId (key:requestId)
    mapping (int => int) public requestIndexToFees; // the mapping to link requestId and fee (key:requestId)
    mapping (int => int) public fwdIndexToFees; // the mapping to link fwdId and fee (key:fwdID)
    mapping (int => bytes32) public fwdIndexToFwdState; // the mapping to link fwdId and fwdState (key:fwdID)
    mapping (int => int) public fwdIndexToFxRate; // the mapping to link fwdId and fxRate (key:fwdID)
    mapping (int => int) public fwdDeposits; // the mapping to link fwdId and depositAmt (key:fwdID)

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

    function setOrderly(address _requestOrderly) onlyOwner() public {
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
        // unit is finney (=1/1000 ether)
        int exchangedAmt = _baseAmt  * 1000 * 1000 / _fxRate;
        return exchangedAmt;
    }

    function _calculateFxAmtFromId(int _fwdId) view internal returns(int) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // unit is finney (=1/1000 ether)
        return fwdRequests[_fwdId].baseAmt * 1000 * 1000 / fwdIndexToFxRate[_fwdId];
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

contract FwdContRequest is FwdCont {

    event ForwardInfo(int fwdId,
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
    ); // log for

    event Request(int requestId,
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

contract FwdContProcess is FwdCont {

    function _cancelFwd(int64 _fwdId) internal {
        // fwdState = confirmCancel
        _checkState(_fwdId, 5);

        if (int(msg.value) + fwdIndexToFees[_fwdId] >= minGas * gasPrice) {
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

    function _emergencyCancel(int64 _fwdId) internal {
        // fwdState = confirmEmergency
        _checkState(_fwdId, 7);

        if (int(msg.value) + fwdIndexToFees[_fwdId] >= minGas * gasPrice) {
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

    function _withdrawFwd(int _fwdId) internal {
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

    function _deposit(int _fwdId) internal {

        _isSender(_fwdId);

        if (int(msg.value) < _calculateFxAmt(fwdRequests[_fwdId].baseAmt, fwdIndexToFxRate[_fwdId])) {
            // insufficient fee
            // revert
            revert();
        } else {
            // create deposit
            fwdDeposits[_fwdId] = int(msg.value);
            // update fwdState
            _setFwdState(_fwdId, 2);
            // update fee
            _setFwdFee(_fwdId, fwdIndexToFees[_fwdId] - minGas * gasPrice);
        }
    }

    function _withdrawConfirm(int _fwdId) internal {
        // only sender can execute
        _isSender(_fwdId);
        // fwdState = setDeposit
        _checkState(_fwdId, 2);

        if (int(msg.value) + fwdIndexToFees[_fwdId] > minGas * gasPrice) {
            // confirmWithdraw
            _setFwdState(_fwdId, 3);
            // update fee balance
            _setFwdFee(_fwdId, int(msg.value) + fwdIndexToFees[_fwdId] - minGas * gasPrice);
        }
    }

    function _cancelConfirm(int _fwdId) internal {
        // confirmCancel
        _setFwdState(_fwdId, 5);

        _setFwdFee(_fwdId, int(msg.value) + fwdIndexToFees[_fwdId] - minGas * gasPrice);
    }

    function _emergencyConfirm(int _fwdId) internal {
        // only sender can execute
        _isSender(_fwdId);
        // confirmCancel
        _setFwdState(_fwdId, 7);

        _setFwdFee(_fwdId, int(msg.value) + fwdIndexToFees[_fwdId] - minGas * gasPrice);
    }
}

contract FwdCore is FwdContRequest, FwdContProcess {
    function calculateFxAmtFromId(int _fwdId) orderlyConnected() available() onlyParty(_fwdId) view public returns(int) {
        return _calculateFxAmtFromId(_fwdId);
    }

    // Admin Functions
    function admin_setAllCancel(bool _flag) onlyOwner() public {
        _setAllCancel(_flag);
    }

    function admin_getContractBalance() onlyOwner() view public returns(uint) {
        return address(this).balance;
    }

    function admin_setFees(int _gasPrice, int _minGas, int _cancellationGas, int _externalGas, int _reqGas) onlyOwner() public {
        _setFees(_gasPrice, _minGas, _cancellationGas, _externalGas);

        _setReqFee(_reqGas);
    }

    function admin_resetKillswitch() onlyOwner() public {
        _resetKillswitch();
    }

    function admin_resetUnrespond() onlyOwner() public {
        _resetUnrespond();
    }

    function admin_setNewVersion(address _newAddr) onlyOwner() public {
        _setNewVersion(_newAddr);
    }

    function admin_withdraw() onlyOwner() public {
        _withdraw();
    }

    // user functions
    function user1_request(
        //int _contractDay,
        int _settlementDuration,
        int _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        int _baseAmt
        ) available() orderlyConnected() public payable {

        _request(_settlementDuration, _expireDuration, _receiverAddr, _senderAddr, _baseAmt);
    }

    function user2_deposit(int _fwdId) orderlyConnected() available() public payable {

        _deposit(_fwdId);
    }

    function user3_withdrawConfirm(int _fwdId) orderlyConnected() available() public payable {

        _withdrawConfirm(_fwdId);
    }

    function user4_withdraw(int _fwdId) orderlyConnected() available() public {
        // withdraw depositted asset
        _withdrawFwd(_fwdId);
    }

    function user_cancel(int64 _fwdId) orderlyConnected() available() onlyParty(_fwdId) public payable {
        // if fxRate is not fetch yet, refund fee.
        if (fwdIndexToFwdState[_fwdId] == fwdStates[0]) {
            _deleteRequest(_fwdId);
        }
        _cancelFwd(_fwdId);
    }

    function user_emergencyCancel(int64 _fwdId) orderlyConnected() available() onlyOwner() public payable {

        _emergencyCancel(_fwdId);
    }

    function user_cancelConfirm(int _fwdId) orderlyConnected() available() onlyParty(_fwdId) public payable {

        _cancelConfirm(_fwdId);
    }

    function user_emergencyConfirm(int _fwdId) orderlyConnected() available() public payable {

        _emergencyConfirm(_fwdId);
    }

    function response(
        int _requestId,
        int _error,
        int _respData
    ) available() orderlyConnected() external {

        _response(_requestId, _error, _respData);
    }
}
