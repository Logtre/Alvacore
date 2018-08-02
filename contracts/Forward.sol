pragma solidity ^0.4.9;

contract FwdOrderly {
    struct Request { // the data structure for each request
        uint requestId; // the id of request
        uint8 requestType; // the type of request
        address requester; // the address of the requester
        uint fee; // the amount of wei the requester pays for the request
        address callbackAddr; // the address of the contract to call for delivering response
        bytes4 callbackFID; // the specification of the callback function
        bytes32 paramsHash; // the hash of the request parameters
        uint timestamp; // the timestamp of the request emitted
        bytes32 requestState; // the state of the request
        bytes32[] requestData; // the request data
    }

    event Upgrade(address newAddr);
    event Reset(uint gas_price, uint min_fee, uint cancellation_fee);
    event RequestInfo(uint64 id, uint8 requestType, address requester, uint fee, address callbackAddr, bytes32 paramsHash, uint timestamp, bytes32[] requestData); // log of requests, the Town Crier server watches this event and processes requests
    event DeliverInfo(uint64 requestId, uint fee, uint gasPrice, uint gasLeft, uint callbackGas, bytes32 paramsHash, uint64 error, bytes32 respData); // log of responses
    event Cancel(uint64 requestId, address canceller, address requester, uint fee, int flag); // log of cancellations

    address public constant ALVC_ADDRESS = 0xAb1ee2947091B6AF01157E0373EA4966b7Bd2045;// address of the ALVC account@TestNet

    uint public GAS_PRICE = 50 * 10**10;
    uint public MIN_FEE = 30000 * GAS_PRICE; // minimum fee required for the requester to pay such that SGX could call deliver() to send a response
    uint public CANCELLATION_FEE = 25000 * GAS_PRICE; // charged when the requester cancels a request that is not responded

    uint public constant CANCELLED_FEE_FLAG = 1;
    uint public constant DELIVERED_FEE_FLAG = 0;
    int public constant FAIL_FLAG = -2 ** 250;
    int public constant SUCCESS_FLAG = 1;

    bool public killswitch;

    bool public externalCallFlag;

    uint64 public requestCnt;
    uint64 public unrespondedCnt;
    mapping (int => Request) public requests;
    mapping (int => bytes32) public requestStates;

    int public newVersion = 0;

    // Contracts that receive Ether but do not define a fallback function throw
    // an exception, sending back the Ether (this was different before Solidity
    // v0.4.0). So if you want your contract to receive Ether, you have to
    // implement a fallback function.
    function () public {}

    modifier onlyOwner() {
        require(msg.sender == requests[0].requester);
        _;
    }

    modifier noUnresponse() {
        require(unrespondedCnt == 0);
        _;
    }

    modifier noNewVersion() {
        require(newVersion == 0);
        _;
    }

    constructor() public {
        // Start request IDs at 1 for two reasons:
        //   1. We can use 0 to denote an invalid request (ids are unsigned)
        //   2. Storage is more expensive when changing something from zero to non-zero,
        //      so this means the first request isn't randomly more expensive.
        requestCnt = 1;
        requests[0].requester = msg.sender;
        killswitch = false;
        unrespondedCnt = 0;
        externalCallFlag = false;

        requestStates[-1] = "error";
        requestStates[0] = "requesting";
        requestStates[1] = "delivering";
        requestStates[2] = "canceled";
        requestStates[99] = "pendingFromOwner";
    }

    function upgrade(address newAddr) onlyOwner() noUnresponse() public {
        newVersion = -int(newAddr);
        killswitch = true;
        emit Upgrade(newAddr);
    }

    function resetfees(uint price, uint minGas, uint cancellationGas) onlyOwner() noUnresponse() public {
        GAS_PRICE = price;
        MIN_FEE = price * minGas;
        CANCELLATION_FEE = price * cancellationGas;
        emit Reset(GAS_PRICE, MIN_FEE, CANCELLATION_FEE);
    }

    function resetunrespond() onlyOwner() public {
        unrespondedCnt = 0;
    }

    function suspend() onlyOwner() public {
        killswitch = true;
    }

    function restart() onlyOwner() noNewVersion() public {
        killswitch = false;
    }

    function withdraw() onlyOwner() noUnresponse() public {
        if (!requests[0].requester.call.value(address(this).balance)()) {
            revert();
        }
    }

    function request(uint8 requestType, address callbackAddr, bytes4 callbackFID, uint timestamp, bytes32[] requestData) public payable returns (int) {
        if (externalCallFlag) {
            revert();
        }

        if (killswitch) {
            externalCallFlag = true;
            if (!msg.sender.call.value(msg.value)()) {
                revert();
            }
            externalCallFlag = false;
            return newVersion;
        }

        if (msg.value < MIN_FEE) {
            externalCallFlag = true;
            // If the amount of ether sent by the requester is too little or
            // too much, refund the requester and discard the request.
            if (!msg.sender.call.value(msg.value)()) {
                revert();
            }
            externalCallFlag = false;
            return FAIL_FLAG;
        } else {
            // Record the request.
            uint64 requestId = requestCnt;
            requestCnt++;
            unrespondedCnt++;

            bytes32 paramsHash = keccak256(abi.encodePacked(requestType, requestData));

            requests[requestId].requestId = requestId;
            requests[requestId].requestType = requestType;
            requests[requestId].requester = msg.sender;
            requests[requestId].fee = msg.value;
            requests[requestId].callbackAddr = callbackAddr;
            requests[requestId].callbackFID = callbackFID;
            requests[requestId].paramsHash = paramsHash;
            requests[requestId].timestamp = timestamp;
            requests[requestId].requestState = requestStates[0];
            requests[requestId].requestData = requestData;

            // Log the request for the Town Crier server to process.
            emit RequestInfo(requestId, requestType, msg.sender, msg.value, callbackAddr, paramsHash, timestamp, requestData);
            return requestId;
        }
    }

    function deliver(uint64 requestId, bytes32 paramsHash, uint64 error, bytes32 respData) public {
        if (msg.sender != ALVC_ADDRESS ||
                requestId <= 0 ||
                requests[requestId].requester == 0 ||
                requests[requestId].fee == DELIVERED_FEE_FLAG) {
            // If the response is not delivered by the SGX account or the
            // request has already been responded to, discard the response.
            requests[requestId].requestState = requestStates[-1];
            return;
        }

        uint fee = requests[requestId].fee;
        if (requests[requestId].paramsHash != paramsHash) {
            // If the hash of request parameters in the response is not
            // correct, discard the response for security concern.
            requests[requestId].requestState = requestStates[-1];
            return;
        } else if (fee == CANCELLED_FEE_FLAG) {
            // If the request is cancelled by the requester, cancellation
            // fee goes to the SGX account and set the request as having
            // been responded to.
            ALVC_ADDRESS.transfer(CANCELLATION_FEE);
            requests[requestId].fee = DELIVERED_FEE_FLAG;
            requests[requestId].requestState = requestStates[99];
            unrespondedCnt--;
            return;
        }

        requests[requestId].fee = DELIVERED_FEE_FLAG;
        unrespondedCnt--;

        if (error < 2) {
            // Either no error occurs, or the requester sent an invalid query.
            // Send the fee to the SGX account for its delivering.
            requests[requestId].requestState = requestStates[-1];
            ALVC_ADDRESS.transfer(fee);
        } else {
            // Error in TC, refund the requester.
            externalCallFlag = true;
            if(!requests[requestId].requester.call.gas(2300).value(fee)()) {
                revert();
            }
            externalCallFlag = false;
        }

        uint callbackGas = (fee - MIN_FEE) / tx.gasprice; // gas left for the callback function
        emit DeliverInfo(requestId, fee, tx.gasprice, gasleft(), callbackGas, paramsHash, error, respData); // log the response information
        if (callbackGas > gasleft() - 5000) {
            callbackGas = gasleft() - 5000;
        }

        externalCallFlag = true;
        if(!requests[requestId].callbackAddr.call.gas(callbackGas)(requests[requestId].callbackFID, requestId, error, respData)) { // call the callback function in the application contract
            revert();
        }
        requests[requestId].requestState = requestStates[1];
        externalCallFlag = false;
    }

    function getRequestData(uint64 _requestId) public view returns (uint, uint8, uint, bytes32, bytes32[]) {
        Request storage req = requests[_requestId];
        return (req.requestId, req.requestType, req.timestamp, req.requestState, req.requestData);
    }

    function cancel(uint64 requestId) public returns (int) {
        if (externalCallFlag) {
            revert();
        }

        if (killswitch) {
            return 0;
        }

        uint fee = requests[requestId].fee;
        if (requests[requestId].requester == msg.sender && fee >= CANCELLATION_FEE) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            requests[requestId].fee = CANCELLED_FEE_FLAG;
            externalCallFlag = true;
            if (!msg.sender.call.value(fee - CANCELLATION_FEE)()) {
                revert();
            }
            externalCallFlag = false;
            requests[requestId].requestState = requestStates[2];
            emit Cancel(requestId, msg.sender, requests[requestId].requester, requests[requestId].fee, 1);
            return SUCCESS_FLAG;
        } else {
            emit Cancel(requestId, msg.sender, requests[requestId].requester, fee, -1);
            return FAIL_FLAG;
        }
    }
}

contract Forward {
    struct FwdCont { // the data struct for forward contract
        address fwdOwner;
        bytes32 fwdState;
        uint contractDay; // the date when conclude the trade contract
        uint settlementDay; // the date when money will be moved
        uint expireDay; // the date when contract will expire
        address receiverAddr; // the address whose owner will receive money
        address senderAddr; // the address whose owner will send money
        uint fwdFee;
        uint64 baseAmt; // the amount of money calculated on a USD base
        uint64 fxRate; // the FX rate among ETH and USD
        uint depositAmt; // the amount of deposit money which is depositted from sender
    }

    event Upgrade(address newAddr);
    event Reset(uint gasPrice, uint minFee, uint cancellationFee);
    event ForwardInfo(int64 fwdId, address fwdOwner, bytes32 fwdState, uint contractDay, uint settlementDay, uint expireDay, address receiverAddr, address senderAddr, uint64 fee, uint64 baseAmt, uint64 fxRate, int64 depositAmt); // log for
    event Request(int64 requestId, address requester, uint dataLength, bytes32[] data); // log for requests
    event Response(int64 requestId, address requester, uint64 error, uint data); // log for responses
    event Cancel(uint64 requestId, address requester, bool success); // log for cancellations

    uint minGas = 30000 + 20000; // minimum gas required for a query
    uint gasPrice = 5 * 10 ** 10;
    uint minFee = 30000 * gasPrice;
    uint alvcFee = minGas * gasPrice;
    uint cancellationFee = 25000 * gasPrice;

    uint constant CANCELLED_FEE_FLAG = 1;
    uint constant DELIVERED_FEE_FLAG = 0;
    int constant FAIL_FLAG = -2 ** 250;
    int constant SUCCESS_FLAG = 1;

    bytes4 constant FWD_CALLBACK_FID = bytes4(keccak256("response(uint64,uint64,bytes32)"));

    FwdOrderly public FWDO_CONTRACT;

    uint fwdGas = 30000 + 20000;
    uint fwdFee = fwdGas * gasPrice;
    uint fwdCancellationFee = cancellationFee;

    uint8 requestType;
    bytes32[] requestData;

    bool public killswitch;

    bool public externalCallFlag;

    int64 fwdCnt;
    int64 fwdId;

    mapping (int => bytes32) fwdStates;
    mapping (int => FwdCont) public fwdConts; // the mapping to link fwdId and FwdCont (key:fwdID)
    mapping (uint64 => int64) fwdRequests; // the mapping to link requestId and fwdId (key:requestId)
    mapping (uint64 => uint) requestFees; // the mapping to link requestId and fee (key:requestId)

    int public newVersion = 0;

    modifier onlyOwner() {
        require(msg.sender == fwdConts[0].fwdOwner);
        _;
    }

    modifier onlySender(uint64 _fwdId) {
        require(msg.sender == fwdConts[_fwdId].senderAddr);
        _;
    }

    modifier onlyReceiver(uint64 _fwdId) {
        require(msg.sender == fwdConts[_fwdId].receiverAddr);
        _;
    }

    modifier onlyAuthorized(uint64 _fwdId) {
        require(msg.sender == fwdConts[_fwdId].senderAddr || msg.sender == fwdConts[_fwdId].receiverAddr);
        _;
    }

    constructor(FwdOrderly _fwdOCont, uint8 _requestType, bytes32[] _requestData) public { // constractor
        FWDO_CONTRACT = _fwdOCont; // storing the address of the FWDO_CONTRACT Contract
        fwdCnt = 1;

        fwdStates[-1] = "error";
        fwdStates[0] = "requesting";
        fwdStates[1] = "getFxRate";
        fwdStates[2] = "setDeposit";
        fwdStates[3] = "confirmWithdraw";
        fwdStates[4] = "completeWithdraw";
        fwdStates[11] = "confirmCancel";
        fwdStates[12] = "canceled";
        fwdStates[21] = "confirmEmergency";
        fwdStates[22] = "emergencyCanceled";

        fwdConts[0].fwdOwner = msg.sender;

        requestType = _requestType;
        requestData = _requestData;

        killswitch = false;
        externalCallFlag = false;
    }

    function createFwd(uint _contractDay, uint _settlementDay, uint _expireDay, address _receiverAddr, address _senderAddr, uint64 _baseAmt) public payable {
        if (externalCallFlag) {
            revert();
        }

        if (killswitch) {
            externalCallFlag = true;
            if (!(msg.sender.send(msg.value))) {
                revert();
            }
            externalCallFlag = false;
        }

        fwdId = fwdCnt;
        fwdCnt++;

        fwdConts[fwdId].fwdOwner = msg.sender;
        fwdConts[fwdId].fwdState = fwdStates[0];
        fwdConts[fwdId].contractDay = _contractDay;
        fwdConts[fwdId].settlementDay = _settlementDay;
        fwdConts[fwdId].expireDay = _expireDay;
        fwdConts[fwdId].receiverAddr = _receiverAddr;
        fwdConts[fwdId].senderAddr = _senderAddr;
        fwdConts[fwdId].fwdFee = msg.value;
        fwdConts[fwdId].baseAmt = _baseAmt;
        fwdConts[fwdId].fxRate = 0;
        fwdConts[fwdId].depositAmt = 0;

        //uint timestamp = fwdData.contractDay; // store contractDay as timestamp

        //int requestId = request(fwdId, REQUESTTYPE, timestamp, REQUESTDATA); // calling request() in the Forward Contract

        if (msg.value < alvcFee + fwdFee) {
            // The requester paid less fee than required.
            // Reject the request and refund the requester.
            if (!msg.sender.send(msg.value)) {
                revert();
            }
            emit Request(-1, msg.sender, requestData.length, requestData);
            return;
        }

        int requestId = FWDO_CONTRACT.request.value(msg.value - fwdFee)(requestType, fwdConts[fwdId].receiverAddr, FWD_CALLBACK_FID, 0, requestData); // calling request() in the FWDO_CONTRACT Contract
        if (requestId <= 0) {
            // The request fails.
            // Refund the requester.
            if (!msg.sender.send(msg.value)) {
                revert();
            }
            emit Request(-2, msg.sender, requestData.length, requestData);
            return;
        }

        // Successfully sent a request to TC.
        // Record the request.
        fwdRequests[uint64(requestId)] = fwdId; // Linkage requestId and fwdId
        requestFees[uint64(requestId)] = msg.value; // Linkage requestId and fwdId
        fwdConts[fwdId].fwdFee = fwdFee;

        fwdConts[fwdId].fwdState = fwdStates[1];

        emit Request(int64(requestId), msg.sender, requestData.length, requestData);
        emit ForwardInfo(int64(fwdId),
            fwdConts[fwdId].fwdOwner,
            fwdConts[fwdId].fwdState,
            uint(fwdConts[fwdId].contractDay),
            uint(fwdConts[fwdId].settlementDay),
            uint(fwdConts[fwdId].expireDay),
            fwdConts[fwdId].receiverAddr,
            fwdConts[fwdId].senderAddr,
            uint64(fwdConts[fwdId].fwdFee),
            fwdConts[fwdId].baseAmt,
            fwdConts[fwdId].fxRate,
            int64(fwdConts[fwdId].depositAmt));
        return;
    }

    function getFwdData(uint64 _fwdId) public view returns (int64, address) {
        return (int64(_fwdId), fwdConts[_fwdId].fwdOwner);
    }

    function getFwdDetail(uint64 _fwdId) public view returns (bytes32, uint, uint, uint) {
        return (fwdConts[_fwdId].fwdState,
            fwdConts[_fwdId].contractDay,
            fwdConts[_fwdId].settlementDay,
            fwdConts[_fwdId].expireDay);
    }

    function getFwdSenseData(uint64 _fwdId) public view returns (address, address, uint64, uint64, uint64, int64) {
        return (fwdConts[_fwdId].receiverAddr,
            fwdConts[_fwdId].senderAddr,
            uint64(fwdConts[_fwdId].fwdFee),
            fwdConts[_fwdId].baseAmt,
            fwdConts[_fwdId].fxRate,
            int64(fwdConts[fwdId].depositAmt));
    }

    function depositFwd(uint64 _fwdId) onlySender(_fwdId) public payable {
        if (externalCallFlag) {
            revert();
        }

        if (killswitch) {
            externalCallFlag = true;
            if (!msg.sender.send(msg.value)) {
                revert();
            }
            externalCallFlag = false;
        }

        if (msg.value < fwdConts[_fwdId].depositAmt + fwdConts[_fwdId].fwdFee) {
            // The requester paid less fee than required.
            // Reject the request and refund the requester.
            if (!msg.sender.send(msg.value)) {
                revert();
            }
            fwdConts[_fwdId].fwdState = fwdStates[-1];
            emit ForwardInfo(int64(_fwdId),
                fwdConts[_fwdId].fwdOwner,
                fwdConts[_fwdId].fwdState,
                fwdConts[_fwdId].contractDay,
                fwdConts[_fwdId].settlementDay,
                fwdConts[_fwdId].expireDay,
                fwdConts[_fwdId].receiverAddr,
                fwdConts[_fwdId].senderAddr,
                uint64(fwdConts[_fwdId].fwdFee),
                fwdConts[_fwdId].baseAmt,
                fwdConts[_fwdId].fxRate,
                int64(fwdConts[fwdId].depositAmt));
            return;
        }

        fwdConts[_fwdId].depositAmt = msg.value - fwdFee;
        fwdConts[_fwdId].fwdState = fwdStates[2];
        fwdConts[_fwdId].fwdFee += fwdFee;

        emit ForwardInfo(int64(_fwdId),
                fwdConts[_fwdId].fwdOwner,
                fwdConts[_fwdId].fwdState,
                uint(fwdConts[_fwdId].contractDay),
                uint(fwdConts[_fwdId].settlementDay),
                uint(fwdConts[_fwdId].expireDay),
                fwdConts[_fwdId].receiverAddr,
                fwdConts[_fwdId].senderAddr,
                uint64(fwdConts[_fwdId].fwdFee),
                fwdConts[_fwdId].baseAmt,
                fwdConts[_fwdId].fxRate,
                int64(fwdConts[fwdId].depositAmt));
        return;
    }

    function withdrawFwd_confirm(uint64 _fwdId) onlySender(_fwdId) public {

        emit ForwardInfo(int64(_fwdId),
                fwdConts[_fwdId].fwdOwner,
                fwdConts[_fwdId].fwdState,
                uint(fwdConts[_fwdId].contractDay),
                uint(fwdConts[_fwdId].settlementDay),
                uint(fwdConts[_fwdId].expireDay),
                fwdConts[_fwdId].receiverAddr,
                fwdConts[_fwdId].senderAddr,
                uint64(fwdConts[_fwdId].fwdFee),
                fwdConts[_fwdId].baseAmt,
                fwdConts[_fwdId].fxRate,
                int64(fwdConts[fwdId].depositAmt));
        return;
    }

    function withdrawFwd(uint64 _fwdId) onlyReceiver(_fwdId) public {
        require(fwdConts[_fwdId].fwdState == "confirmWithdraw");

        if (fwdConts[_fwdId].depositAmt == 0) {
            emit ForwardInfo(int64(_fwdId),
                fwdConts[_fwdId].fwdOwner,
                fwdConts[_fwdId].fwdState,
                uint(fwdConts[_fwdId].contractDay),
                uint(fwdConts[_fwdId].settlementDay),
                uint(fwdConts[_fwdId].expireDay),
                fwdConts[_fwdId].receiverAddr,
                fwdConts[_fwdId].senderAddr,
                uint64(fwdConts[_fwdId].fwdFee),
                fwdConts[_fwdId].baseAmt,
                fwdConts[_fwdId].fxRate,
                int64(fwdConts[fwdId].depositAmt));
            revert();
        }

        uint amount = fwdConts[_fwdId].depositAmt;

        fwdConts[_fwdId].depositAmt = 0;

        externalCallFlag = true;
        if (!fwdConts[_fwdId].receiverAddr.send(amount)) {
            revert();
        }
        externalCallFlag = false;

        emit ForwardInfo(int64(_fwdId),
            fwdConts[_fwdId].fwdOwner,
            fwdConts[_fwdId].fwdState,
            uint(fwdConts[_fwdId].contractDay),
            uint(fwdConts[_fwdId].settlementDay),
            uint(fwdConts[_fwdId].expireDay),
            fwdConts[_fwdId].receiverAddr,
            fwdConts[_fwdId].senderAddr,
            uint64(fwdConts[_fwdId].fwdFee),
            fwdConts[_fwdId].baseAmt,
            fwdConts[_fwdId].fxRate,
            int64(fwdConts[fwdId].depositAmt));
        return;
    }

    function cancelFwd_confirm(uint64 _fwdId) onlyAuthorized(_fwdId) public {
        fwdConts[_fwdId].fwdState = fwdStates[11];

        emit ForwardInfo(int64(_fwdId),
            fwdConts[_fwdId].fwdOwner,
            fwdConts[_fwdId].fwdState,
            uint(fwdConts[_fwdId].contractDay),
            uint(fwdConts[_fwdId].settlementDay),
            uint(fwdConts[_fwdId].expireDay),
            fwdConts[_fwdId].receiverAddr,
            fwdConts[_fwdId].senderAddr,
            uint64(fwdConts[_fwdId].fwdFee),
            fwdConts[_fwdId].baseAmt,
            fwdConts[_fwdId].fxRate,
            int64(fwdConts[fwdId].depositAmt));
        return;
    }

    function cancelFwd(uint64 _fwdId) onlyAuthorized(_fwdId) public returns (int) {
        if (externalCallFlag) {
            revert();
        }

        if (killswitch) {
            return 0;
        }

        require(fwdConts[_fwdId].fwdState == fwdStates[11]);

        uint fee = fwdConts[_fwdId].fwdFee;
        if (fee >= cancellationFee) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            fwdConts[_fwdId].fwdFee = CANCELLED_FEE_FLAG;

            externalCallFlag = true;
            if (!fwdConts[_fwdId].receiverAddr.send(fwdConts[_fwdId].depositAmt)) {
                revert();
            }
            externalCallFlag = false;

            emit Cancel(_fwdId, msg.sender, true);
            return SUCCESS_FLAG;
        } else {
            emit Cancel(_fwdId, msg.sender, false);
            return FAIL_FLAG;
        }
    }

    function emergencyFwd_confirm(uint64 _fwdId) onlySender(_fwdId) public {
        fwdConts[_fwdId].fwdState = fwdStates[21];

        emit ForwardInfo(int64(_fwdId),
            fwdConts[_fwdId].fwdOwner,
            fwdConts[_fwdId].fwdState,
            uint(fwdConts[_fwdId].contractDay),
            uint(fwdConts[_fwdId].settlementDay),
            uint(fwdConts[_fwdId].expireDay),
            fwdConts[_fwdId].receiverAddr,
            fwdConts[_fwdId].senderAddr,
            uint64(fwdConts[_fwdId].fwdFee),
            fwdConts[_fwdId].baseAmt,
            fwdConts[_fwdId].fxRate,
            int64(fwdConts[fwdId].depositAmt));
        return;
    }

    function emergencyFwd(uint64 _fwdId) onlyOwner() public payable {
        require(fwdConts[_fwdId].fwdState == fwdStates[21]);

        uint fee = fwdConts[_fwdId].fwdFee + msg.value;
        if (fee >= cancellationFee) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            //fwdData.fwdFee = CANCELLED_FEE_FLAG;
            uint emergencyReturnAmt = fwdConts[_fwdId].depositAmt * 9 / 10;

            if (emergencyReturnAmt > cancellationFee) {
                uint emergencyFee = emergencyReturnAmt - cancellationFee;
            } else {
                revert();
            }
            //uint emergencyFee = fwdData.depositAmt / 10;

            externalCallFlag = true;
            if (!fwdConts[_fwdId].receiverAddr.send(emergencyFee)) {
                revert();
            }
            externalCallFlag = false;

            emit Cancel(_fwdId, msg.sender, true);
            //return SUCCESS_FLAG;
        } else {
            emit Cancel(_fwdId, msg.sender, false);
            //return FAIL_FLAG;
        }

    }

    function upgrade(address _newAddr) onlyOwner() public {
        if (msg.sender == fwdConts[0].fwdOwner && externalCallFlag == false) {
            newVersion = -int(_newAddr);
            killswitch = true;
            emit Upgrade(_newAddr);
        }
    }

    function reset(uint _price, uint _minGas, uint _cancellationGas) onlyOwner() public {
        if (msg.sender == fwdConts[0].fwdOwner && externalCallFlag == false) {
            gasPrice = _price;
            minFee = _price * _minGas;
            cancellationFee = _price * _cancellationGas;
            emit Reset(gasPrice, minFee, cancellationFee);
        }
    }

    function withdraw_fee() onlyOwner() public {
        if (msg.sender == fwdConts[0].fwdOwner) {
            for (int targetFwd=1; targetFwd <= fwdCnt; targetFwd++) {
                if (!fwdConts[0].fwdOwner.send(fwdConts[targetFwd].fwdFee)) {
                    revert();
                }
            }
        }
    }

    function suspend() onlyOwner() public {
        if (msg.sender == fwdConts[0].fwdOwner) {
            killswitch = true;
        }
    }

    function restart() onlyOwner() public {
        if (msg.sender == fwdConts[0].fwdOwner && newVersion == 0) {
            killswitch = false;
        }
    }

    /*function request(uint64 _fwdId, uint8 _requestType, uint _timestamp, bytes32 _requestData) public payable {
        if (msg.value < TC_FEE) {
            // The requester paid less fee than required.
            // Reject the request and refund the requester.
            if (!msg.sender.call.value(msg.value)()) {
                revert();
            }
            emit Request(-1, msg.sender, _requestData.length, _requestData);
            return -1;
        }

        int requestId = FWDO_CONTRACT.request.value(msg.value)(_requestType, this, FWD_CALLBACK_FID, _timestamp, _requestData); // calling request() in the FWDO_CONTRACT Contract
        if (requestId <= 0) {
            // The request fails.
            // Refund the requester.
            if (!msg.sender.call.value(msg.value)()) {
                revert();
            }
            emit Request(-2, msg.sender, _requestData.length, _requestData);
            return -2;
        }

        // Successfully sent a request to TC.
        // Record the request.
        //FwdCont fwdData = fwdConts[_fwdId]; // Linkage fwdId and FwdCont
        //fwdData.requesters[requestId] = msg.sender;
        //fwdData.fee[fwdData.requesters[requestId]] = msg.value;
        fwdRequests[uint(requestId)] = _fwdId; // Linkage requestId and fwdId
        requestFees[uint(requestId)] = msg.value; // Linkage requestId and fwdId

        emit Request(int64(requestId), msg.sender, _requestData.length, _requestData);
        return requestId;
    }*/

    function response(uint64 _requestId, uint64 _error, bytes32 _respData) external {
        if (msg.sender != address(FWDO_CONTRACT)) {
            // If the message sender is not the FWDO_CONTRACT Contract,
            // discard the response.
            emit Response(-1, msg.sender, 0, 0);
            return;
        }

        fwdId = fwdRequests[_requestId];

        fwdConts[fwdId].fxRate = uint64(_respData);

        address requester = fwdConts[fwdId].fwdOwner; // Linkage requestId and FwdCont
        //address requester = fwdData.fwdOwner;
        uint requestfee = requestFees[_requestId];

        //requesters[requestId] = 0; // set the request as responded

        if (_error < 2) {
            emit Response(int64(_requestId), requester, _error, uint(_respData));
        } else {
            requester.transfer(requestfee);
            emit Response(int64(_requestId), msg.sender, _error, 0);
        }
    }
}
