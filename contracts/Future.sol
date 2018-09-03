pragma solidity ^0.4.9;

contract AccessControl {

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

contract Base is AccessControl {

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

contract FutCharacteristic {
    bytes32 public constant KEYWORD = "FUT";
}

contract Orderly is Base {

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

    //bytes32 public constant KEYWORD = "FWD";

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

    function _isALVC(address _from) view internal {
        require (_from == ALVC_WALLET);
    }
}

contract FutOrderlyRequest is Orderly, FutCharacteristic {

    event RequestInfo(int requestId, bytes4 requestType, address requester, int fee, bytes32 paramsHash, int timestamp, bytes32 _requestState, bytes32 requestData); // log of requests, the Town Crier server watches this event and processes requests
    event DeliverInfo(int requestId, int fee, int gasPrice, int gasLeft, int callbackGas, bytes32 paramsHash, int error, int respData); // log of responses
    // for debug
    event CheckFee(int msgValue, int minFee, address msgSnder);

    function withdraw() onlyOwner() public {
        _withdraw();
    }

    function _correctBusiness(bytes32 _keyword) pure internal {
        require (keccak256(abi.encodePacked(_keyword)) == keccak256(abi.encodePacked(KEYWORD)));
    }

    function request(
        bytes32 _requestType,
        address _requester,
        bytes4 _callbackFID,
        int _timestamp,
        bytes32 _requestData
        ) whenNotPaused() available() noCancelFlag() public payable returns (int) {

        //int _requestCnt = requestCnt;

        _correctBusiness(_requestType);

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

    function getRequest(int _requestId) view public returns(bytes32, int, bytes32, bytes32) {
        bytes32 _requestType = KEYWORD;
        int _timestamp = requests[_requestId].timestamp;
        bytes32 _requestState = requestIndexToState[_requestId];
        bytes32 _requestData = requests[_requestId].requestData;

        return(_requestType, _timestamp, _requestState, _requestData);
    }

    function requestCancel(
        int _requestId,
        int _value
        ) public  whenNotPaused() available() {
        // primise: this function is called by FutCont
        // only requester can execute
        _isRequester(_requestId);

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



contract FutCont is Base {

    event FutRequestInfo(address futOwner, int contractDay, int settlementDuration, int expireDuration, address receiverAddr, address senderAddr, int baseAmt);
    event FutCancel(int futId, address canceller, int flag);
    event FutDelete(int futId);
    event SetFutState(int futId, bytes32 futState);
    event SetMarginState(int futId, bytes32 marginState);
    event SetFutFee(int storedFutFee);
    event SetFxRate(int futId, int fxRate);
    event WithdrawDeposit(int futId, address withdrawer, int amount);
    event OutOfDeposit(int futId, address sender, int Additional_certificate);

    struct FutRequest { // the data struct for forward contract
        address futOwner;
        int contractDay; // the date when conclude the trade contract
        int settlementDuration; // the date when money will be moved
        int expireDuration; // the date when contract will expire
        address receiverAddr; // the address whose owner will receive money
        address senderAddr; // the address whose owner will send money
        int baseAmt; // the amount of money calculated on a USD base
    }

    bytes32[] public marginFlags = [
        bytes32("beginner"), // marginRate: 100%
        bytes32("standard"), // marginRate: 50%
        bytes32("advanced"), // marginRate: 30%
        bytes32("expert") // marginRate: 3%
    ];

    int[] public marginRates = [
        100, // beginner
        50, // standard
        30, // advanced
        3 // expert
    ];

    bytes32[] public futStates = [
        bytes32("requesting"),
        bytes32("getFxRate"),
        bytes32("setDeposit"),
        bytes32("confirmWithdraw"),
        bytes32("completeWithdraw"),
        bytes32("confirmCancel"),
        bytes32("canceled"),
        bytes32("confirmEmergency"),
        bytes32("emergencyCanceled"),
        bytes32("error:FutOrderly"),
        bytes32("error:wrongData"),
        bytes32("error:ALVCServer")
    ];

    bytes32[] public marginStates = [
        bytes32("no_deposit"),
        bytes32("need_to_confirm_depositAmt"),
        bytes32("insufficient_deposit"),
        bytes32("sufficient_deposit"),
        bytes32("canceled")
    ];

    FutOrderlyRequest public requestOrderly;

    int public reqGas = 250000;

    bytes4 constant public FUT_CALLBACK_FID = bytes4(keccak256("response(int256,int256,int256)"));
    bytes4 constant public REQUESTTYPE = "FUT";
    bytes32 constant public SYMBOL = "ETH";

    int public futCnt;
    bool public setOrderly;

    mapping (int => FutRequest) public futRequests; // the mapping to link futId and FutCont (key:futID)
    mapping (int => int) public futIndexToRequests; // the mapping to link requestId and futId (key:requestId)
    mapping (int => int) public requestIndexToFees; // the mapping to link requestId and fee (key:requestId)
    mapping (int => int) public futIndexToFees; // the mapping to link futId and fee (key:futID)
    mapping (int => bytes32) public futIndexToFutState; // the mapping to link futId and futState (key:futID)
    mapping (int => bytes32) public futIndexToMarginState;
    mapping (int => int) public futIndexToFxRate1; // the mapping to link futId and fxRate (key:futID)
    mapping (int => int) public futIndexToFxRate2;
    mapping (int => int) public futDeposits; // the mapping to link futId and depositAmt (key:futID)
    mapping (int => int) public futIndexToMarginRate;
    mapping (int => bytes32) public futIndexToMarginFlag;

    mapping (int => bool) public cancelRequestSender;
    mapping (int => bool) public cancelRequestReceiver;


    modifier orderlyConnected() {
        require(setOrderly && address(requestOrderly) != 0x0000000000000000000000000000000000000000);
        _;
    }

    modifier onlyParty(int _futId) {
        require(msg.sender == futRequests[_futId].futOwner ||
            msg.sender == futRequests[_futId].receiverAddr ||
            msg.sender == futRequests[_futId].senderAddr);
            _;
    }

    constructor() public { // constractor
        _createFutRequest(
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
        //futCnt = 1;
        //futRequests[0].futOwner = msg.sender;
        owner = msg.sender;
        setOrderly = false;
    }

    function _setMarginRate(int _futId, int _index) internal {
        futIndexToMarginFlag[_futId] = marginFlags[uint(_index)];
        futIndexToMarginRate[_futId] = marginRates[uint(_index)];
    }

    function _addFutRequest(int _futId, FutRequest _futRequest, int _requestId, int _reqFee) private {
        futRequests[_futId] = _futRequest;
        futIndexToRequests[_futId] = _requestId;
        futIndexToFees[_futId] = int(msg.value) - _reqFee;
        futIndexToFutState[_futId] = futStates[0];
        futIndexToMarginState[_futId] = marginStates[0];
        futIndexToFxRate1[_futId] = 0;
        futIndexToFxRate2[_futId] = 0;
        futDeposits[_futId] = 0;
        _setMarginRate(_futId, 0);
        cancelRequestSender[_futId] = false;
        cancelRequestReceiver[_futId] = false;
        futCnt ++;
    }

    function _createFutRequest(
        address _futOwner,
        int _contractDay,
        int _settlementDuration,
        int _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        int _baseAmt,
        int _futCnt,
        int _requestId,
        int _reqFee
        ) internal returns(int) {
        FutRequest memory futRequest = FutRequest({
            futOwner: _futOwner,
            contractDay: _contractDay, // the date when conclude the trade contract
            settlementDuration: _settlementDuration, // the date when money will be moved
            expireDuration: _expireDuration, // the date when contract will expire
            receiverAddr: _receiverAddr, // the address whose owner will receive money
            senderAddr: _senderAddr, // the address whose owner will send money
            baseAmt: _baseAmt // the amount of money calculated on a USD base
        });

        _addFutRequest(_futCnt, futRequest, _requestId, _reqFee);

        emit FutRequestInfo(_futOwner, _contractDay, _settlementDuration, _expireDuration, _receiverAddr, _senderAddr, _baseAmt);
        emit SetFutFee(futIndexToFees[_futCnt]);

        return _futCnt;
    }

    function _setReqFee(int _reqGas) internal {
        reqGas = _reqGas;
    }

    function setOrderly(address _requestOrderly) onlyOwner() public {
        requestOrderly = FutOrderlyRequest(_requestOrderly);

        setOrderly = true;
    }

    function _cancel(int _futId) internal {
        // delete futRequest
        _deleteFutRequest(_futId);
    }

    function _deleteRequest(int _futId) internal {
        requestOrderly.requestCancel(futIndexToRequests[_futId], minGas * gasPrice * 80 / 100);
    }

    function _deleteFutRequest(int _futId) internal {
        // premise: withdrawing deposit asset is done
        // check wether deposit is refunded
        _noDeposit(_futId);
        // escape futRequest to another struct
        int _payedFeeAmt = futIndexToFees[_futId];
        // escape futOwner to another struct
        address _futOwner = futRequests[_futId].futOwner;
        // delete mappings about fut
        delete futRequests[_futId];
        delete futIndexToRequests[_futId];
        delete futIndexToFees[_futId];
        delete futIndexToFutState[_futId];
        delete futIndexToFxRate1[_futId];
        delete futIndexToFxRate2[_futId];
        delete marginFlags[uint(_futId)];
        delete marginRates[uint(_futId)];
        delete cancelRequestSender[_futId];
        delete cancelRequestReceiver[_futId];
        //delete futDeposits[_futId];
        // refund fee to futOwner
        _transfer(_futOwner, minGas * gasPrice);
        // refund surplus value to FutCont's owner
        if (_payedFeeAmt - minGas * gasPrice > 0) {
            _transfer(owner, _payedFeeAmt - minGas * gasPrice);
        }
        // emit event
        emit FutDelete(_futId);
    }

    function _noDeposit(int _futId) view internal {
        require (futDeposits[_futId] == 0);
    }

    function _refundPayedDeposit(int _futId) internal {
        // escape deposit to another struct
        int targetDeposit = futDeposits[_futId];
        // delete deposit
        delete futDeposits[_futId];
        // refund value to sender
        _transfer(futRequests[_futId].senderAddr, targetDeposit);
        // minus refund fee from futIndexToFees
        _setFutFee(_futId, futIndexToFees[_futId] - minGas * gasPrice);
        // emit event
        emit WithdrawDeposit(_futId, futRequests[_futId].senderAddr, targetDeposit);
    }

    function _withdrawDepositWithRate(int _futId, address _to, int _fxRate) internal {
        // calculate payment amount
        int _paymentAmt = _calculateFxAmt(futRequests[_futId].baseAmt, _fxRate);
        int tempDeposit = futDeposits[_futId];

        if (tempDeposit > _paymentAmt) {
            // sufficient deposit exist
            // refund exchanged deposit
            _transfer(_to, _paymentAmt);
            // refund surplus deposit
            _transfer(futRequests[_futId].senderAddr, futDeposits[_futId] - _paymentAmt - minGas * gasPrice);
            // delete deposit
            delete futDeposits[_futId];
            // emit event
            emit WithdrawDeposit(_futId, _to, _paymentAmt);
        } else {
            // insufficient deposit exist
            // refund all deposit amount
            _transfer(_to, futDeposits[_futId] - minGas * gasPrice);
            // update deposit amount
            futDeposits[_futId] = 0;
            // emit event
            emit OutOfDeposit(_futId, futRequests[_futId].senderAddr, _paymentAmt - tempDeposit);
        }
    }

    function _calculateFxAmt(int _baseAmt, int _fxRate) pure internal returns(int) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // unit is finney (=1/1000 ether)
        int unit = 1000 finney;
        int exchangedAmt = _baseAmt  * 1000 * unit / _fxRate;
        return exchangedAmt;
    }

    function _calculateMarginAmt(int _baseAmt, int _fxRate, int _marginRate) pure internal returns(int) {
        // Margin rate is percentage
        // uint finney
        int marginAmt = _calculateFxAmt(_baseAmt, _fxRate) * _marginRate / 100;
        return marginAmt;
    }

    function _calculateFxAmtFromId(int _futId, int _index) view internal returns(int) {
        // fxRate is [ETH/USD].
        // to calculate payment ether, devide baseAmt by fxRate.
        // fxrate is 1000times, so amaount provide 1000
        // unit is finney (=1/1000 ether)
        int unit = 1000 finney;
        if (_index == 1) {
            return futRequests[_futId].baseAmt * 1000 * unit / futIndexToFxRate1[_futId];
        } else if (_index == 2) {
            return futRequests[_futId].baseAmt * 1000 * unit / futIndexToFxRate2[_futId];
        } else {
            revert();
        }
    }

    function _getRestDepositAmt(int _futId, int _index) view internal returns(int) {
            // depositAmt must be payed
            require(futDeposits[_futId] > 0);
            // uint is finney
            int restDepositAmt = (_calculateFxAmtFromId(_futId, _index) - futDeposits[_futId]);

            if (restDepositAmt < 0) {
                restDepositAmt = 0;
            }

            return restDepositAmt;
    }

    function _calculateTotalFee(int _minGas, int _reqGas, int _gasPrice, int _buffer) view internal returns(int) {
        int futFetchRateFee = _minGas * _gasPrice;
        int futDepositFee = _minGas * _gasPrice;
        int futConfirmFee = _minGas * _gasPrice;
        int futWithdrawFee = _minGas * _gasPrice;
        int futCancellationFee = _reqGas * gasPrice;
        int totalFee = (futFetchRateFee + futDepositFee + futConfirmFee + futWithdrawFee + futCancellationFee) * _buffer / 100;

        return totalFee;
    }

    function _setFutState(int _futId, int _index) internal {
        futIndexToFutState[_futId] = futStates[uint(_index)];
        emit SetFutState(_futId, futStates[uint(_index)]);
    }

    function _setMarginState(int _futId, int _index) internal {
        futIndexToMarginState[_futId] = marginStates[uint(_index)];
        emit SetMarginState(_futId, marginStates[uint(_index)]);
    }

    function _setFxRate(int _futId, int _fxRate, int _index) internal {
        if (_index == 1) {
            futIndexToFxRate1[_futId] = _fxRate;
        } else if (_index == 2) {
            futIndexToFxRate2[_futId] = _fxRate;
        } else {
            revert();
        }

        emit SetFxRate(_futId, _fxRate);
    }

    function _setFutFee(int _futId, int _fee) internal {
        futIndexToFees[_futId] = _fee;
    }

    function _isOrderly(address _from) view internal {
        require(_from == address(requestOrderly));
    }

    function _isSender(int _futId) view internal {
        require(msg.sender == futRequests[_futId].senderAddr);
    }

    function _isReceiver(int _futId) view internal {
        require(msg.sender == futRequests[_futId].receiverAddr);
    }

    function _availSettlement(int _futId) view internal {
        require(int(now) >= futRequests[_futId].contractDay + futRequests[_futId].settlementDuration * 1 days);
    }

    function _isExpired(int _futId) view internal {
        require(int(now) >= futRequests[_futId].contractDay + futRequests[_futId].expireDuration * 1 days);
    }

    function _checkState(int _futId, int _index) view internal {
        require(futIndexToFutState[_futId] == futStates[uint(_index)]);
    }
}

contract FutContRequest is FutCont {

    event FutureInfo(int futId,
        address futOwner,
        bytes32 futState,
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

    //FutOrderlyRequest public requestOrderly;

    int buffer = 120;

    function _request(
        //int _contractDay,
        int _settlementDuration,
        int _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        int _baseAmt
        ) internal {

        //int _futCnt = futCnt;
        int _reqFee = minGas * gasPrice * buffer / 100;
        int _requiredFee = _calculateTotalFee(minGas, reqGas, gasPrice, buffer);

        if (int(msg.value) < _requiredFee) {
            revert();
        } else {
            // Record the request.

            int _requestId = requestOrderly.request.value(uint(_reqFee))(
                REQUESTTYPE,
                address(this),
                FUT_CALLBACK_FID,
                int(now),
                SYMBOL
            );

            int _futId = _createFutRequest(
                msg.sender,
                int(now),
                _settlementDuration,
                _expireDuration,
                _receiverAddr,
                _senderAddr,
                _baseAmt,
                futCnt,
                _requestId,
                _reqFee
            );
        }

        emit FutureInfo(
            _futId,
            tx.origin,
            futStates[0],
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

        int _futFetchRateFee = minGas * gasPrice;

        int _futId = futIndexToRequests[_requestId]; // Linkage requestId and FutCont

        if (_error < 2) {
            if (futStates[uint(_futId)] == futStates[0]) {
                // update fxRate
                _setFxRate(_futId, _respData, 1);
                // update futState
                _setFutState(_futId, 1);
                // payment
                _transfer(owner, futIndexToFees[_futId]);
            } else {
                _setFxRate(_futId, _respData, 2);
            }
            // emit event
            emit Response(int(_requestId), owner, _error, _respData);
        } else {
            // error in ALVC server
            // return fee
            _transfer(futRequests[_futId].futOwner, futIndexToFees[_futId] - _futFetchRateFee);
            // emit event
            emit Response(int(_requestId), futRequests[_futId].futOwner, _error, 0);
        }
    }
}


contract FutContProcess is FutCont {

    function _cancelFut(int64 _futId) internal {
        // futState = confirmCancel
        _checkState(_futId, 5);

        if (int(msg.value) + futIndexToFees[_futId] >= minGas * gasPrice) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            if (futDeposits[_futId] > 0) {
                // exist deposit asset
                // withdraw deposit
                _refundPayedDeposit(_futId);
                // cancel fut
                //_cancel(_futId, futRequests[_futId].receiverAddr, minGas * gasPrice);
                _cancel(_futId);
                // update futState
                _setFutState(_futId, 6);
                // update marginState
                _setMarginState(_futId, 4);
            } else {
                // no deposit, so need not to return deposit
                //_cancel(_futId, futRequests[_futId].receiverAddr, minGas * gasPrice);
                _cancel(_futId);
                // update futState
                _setFutState(_futId, 6);
                // update marginState
                _setMarginState(_futId, 4);
            }
        } else {
            // unsufficient fee
            revert();
        }
    }

    function _emergencyCancel(int64 _futId) internal {
        // futState = confirmEmergency
        _checkState(_futId, 7);

        if (int(msg.value) + futIndexToFees[_futId] >= minGas * gasPrice) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            if(futDeposits[_futId] > 0) {
                // exist deposit asset
                // withdraw deposit
                _refundPayedDeposit(_futId);
                // confirmCancel
                _setFutState(_futId, 8);
                // update marginState
                _setMarginState(_futId, 4);
                // cancel fut
                //_cancel(_futId, futRequests[_futId].receiverAddr, minGas * gasPrice);
                _cancel(_futId);
            } else {
                // confirmCancel
                _setFutState(_futId, 8);
                // update marginState
                _setMarginState(_futId, 4);
                // no deposit, so need not to return deposit
                //_cancel(_futId, futRequests[_futId].receiverAddr, minGas * gasPrice);
                _cancel(_futId);
            }
        } else {
            revert();
        }
    }

    function _withdrawFut(int _futId) internal {
        // if now time greater than settlementDuration,
        // function can execute
        _availSettlement(_futId);
        // only receiver can execute
        _isReceiver(_futId);
        // futState = confirmWithdraw
        _checkState(_futId, 3);

        if (futDeposits[_futId] > 0) {
            // exist deposit asset
            // withdraw deposit
            _withdrawDepositWithRate(_futId, futRequests[_futId].senderAddr, futIndexToFxRate2[_futId]);
            // update futState
            _setFutState(_futId, 4);

            _deleteFutRequest(_futId);
        } else {
            revert();
        }
    }

    function _additionalDeposit(int _futId) internal {

        _isSender(_futId);

        if (int(msg.value) < _getRestDepositAmt(_futId, 2) ) {
            // insufficient fee
            // revert
            revert();
        } else {
            // create deposit
            futDeposits[_futId] += int(msg.value);
            // update futState
            _setFutState(_futId, 3);
            // update marginState
            _setMarginState(_futId, 3);
            // update fee
            _setFutFee(_futId, futIndexToFees[_futId] - minGas * gasPrice);
        }
    }

    function _deposit(int _futId) internal {
        // only sender can execute
        _isSender(_futId);
        // unit finney
        if (int(msg.value) < _calculateMarginAmt(futRequests[_futId].baseAmt, futIndexToFxRate1[_futId], marginRates[uint(_futId)])) {
            // insufficient fee
            // revert
            revert();
        } else {
            // create deposit
            // unit
            futDeposits[_futId] = int(msg.value);
            // update futState
            _setFutState(_futId, 2);
            // update marginState
            _setMarginState(_futId, 1);
            // update fee
            _setFutFee(_futId, futIndexToFees[_futId] - minGas * gasPrice);
        }
    }

    function _withdrawConfirm(int _futId) internal {
        // only sender can execute
        _isSender(_futId);
        // futState = setDeposit
        _checkState(_futId, 2);

        if (int(msg.value) + futIndexToFees[_futId] > minGas * gasPrice) {
            // confirmWithdraw
            _setFutState(_futId, 3);
            // update fee balance
            _setFutFee(_futId, int(msg.value) + futIndexToFees[_futId] - minGas * gasPrice);
        }
    }

    function _setCancelFlag(int _futId) internal {
        if (msg.sender == futRequests[_futId].receiverAddr) {
            cancelRequestReceiver[_futId] = true;
        }

        if (msg.sender == futRequests[_futId].senderAddr) {
            cancelRequestSender[_futId] = true;
        }
    }

    function _cancelConfirm(int _futId) internal {
        // set cancelflag
        _setCancelFlag(_futId);
        // confirmCancel
        _setFutState(_futId, 5);

        _setFutFee(_futId, int(msg.value) + futIndexToFees[_futId] - minGas * gasPrice);
    }

    function _emergencyConfirm(int _futId) internal {
        // only sender can execute
        _isSender(_futId);
        // confirmCancel
        _setFutState(_futId, 7);

        _setFutFee(_futId, int(msg.value) + futIndexToFees[_futId] - minGas * gasPrice);
    }
}

contract FutCore is FutContRequest, FutContProcess {
    function calculateFxAmtFromId(int _futId, int _index) orderlyConnected() available() onlyParty(_futId) view public returns(int) {
        return _calculateFxAmtFromId(_futId, _index);
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

    function admin_emergencyCancel(int64 _futId) orderlyConnected() available() onlyOwner() public payable {

        _emergencyCancel(_futId);
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

    function user2_deposit(int _futId) orderlyConnected() available() public payable {

        _deposit(_futId);
    }

    function user3_withdrawConfirm(int _futId) orderlyConnected() available() public payable {
        // primise: sender pay rest depositAmt as msg.value after confirm additional depositAmt
        // it need to exceed settlement duration
        require(int(now) > futRequests[_futId].contractDay + futRequests[_futId].settlementDuration);
        // set margin state
        _setMarginState(_futId, 1);
        //
        _withdrawConfirm(_futId);
    }

    function user4_addiditonalDeposit(int _futId) orderlyConnected() available() public {
        _additionalDeposit(_futId);
    }

    function user5_withdraw(int _futId) orderlyConnected() available() public {
        // withdraw depositted asset
        _withdrawFut(_futId);
    }

    function user_cancel(int64 _futId) orderlyConnected() available() onlyParty(_futId) public payable {
        // set cancelflag
        _setCancelFlag(_futId);
        // confirm both cancel flag is established
        require(cancelRequestSender[_futId] == true && cancelRequestReceiver[_futId] == true);
        // if fxRate is not fetch yet, refund fee.
        if (futIndexToFutState[_futId] == futStates[0]) {
            _deleteRequest(_futId);
        }
        _cancelFut(_futId);
    }

    function user_cancelConfirm(int _futId) orderlyConnected() available() onlyParty(_futId) public payable {

        _cancelConfirm(_futId);
    }

    function user_emergencyConfirm(int _futId) orderlyConnected() available() public payable {

        _emergencyConfirm(_futId);
    }

    function response(
        int _requestId,
        int _error,
        int _respData
    ) available() orderlyConnected() external {

        _response(_requestId, _error, _respData);
    }
}
