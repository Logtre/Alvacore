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
        int requestState; // the state of the request
        bytes32[] requestData; // the request data
    }

    event Upgrade(address newAddr);
    event Reset(uint gas_price, uint min_fee, uint cancellation_fee);
    event RequestInfo(uint64 id, uint8 requestType, address requester, uint fee, address callbackAddr, bytes32 paramsHash, uint timestamp, bytes32[] requestData); // log of requests, the Town Crier server watches this event and processes requests
    event DeliverInfo(uint64 requestId, uint fee, uint gasPrice, uint gasLeft, uint callbackGas, bytes32 paramsHash, uint64 error, bytes32 respData); // log of responses
    event Cancel(uint64 requestId, address canceller, address requester, uint fee, int flag); // log of cancellations

    address public constant ALVC_ADDRESS = 0xAB1eE2947091b6af01157E0373eA4966b7bd2045;// address of the ALVC account@TestNet

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

    int public newVersion = 0;

    // Contracts that receive Ether but do not define a fallback function throw
    // an exception, sending back the Ether (this was different before Solidity
    // v0.4.0). So if you want your contract to receive Ether, you have to
    // implement a fallback function.
    function () public {}

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
    }

    function upgrade(address newAddr) public {
        if (msg.sender == requests[0].requester && unrespondedCnt == 0) {
            newVersion = -int(newAddr);
            killswitch = true;
            emit Upgrade(newAddr);
        }
    }

    function resetfees(uint price, uint minGas, uint cancellationGas) public {
        if (msg.sender == requests[0].requester && unrespondedCnt == 0) {
            GAS_PRICE = price;
            MIN_FEE = price * minGas;
            CANCELLATION_FEE = price * cancellationGas;
            emit Reset(GAS_PRICE, MIN_FEE, CANCELLATION_FEE);
        }
    }

    function resetunrespond() public {
        if (msg.sender == requests[0].requester) {
            unrespondedCnt = 0;
        }
    }

    function suspend() public {
        if (msg.sender == requests[0].requester) {
            killswitch = true;
        }
    }

    function restart() public {
        if (msg.sender == requests[0].requester && newVersion == 0) {
            killswitch = false;
        }
    }

    function withdraw() public {
        if (msg.sender == requests[0].requester && unrespondedCnt == 0) {
            if (!requests[0].requester.call.value(address(this).balance)()) {
                revert();
            }
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
            requests[requestId].requestState = 1;
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
            return;
        }

        uint fee = requests[requestId].fee;
        if (requests[requestId].paramsHash != paramsHash) {
            // If the hash of request parameters in the response is not
            // correct, discard the response for security concern.
            return;
        } else if (fee == CANCELLED_FEE_FLAG) {
            // If the request is cancelled by the requester, cancellation
            // fee goes to the SGX account and set the request as having
            // been responded to.
            ALVC_ADDRESS.transfer(CANCELLATION_FEE);
            requests[requestId].fee = DELIVERED_FEE_FLAG;
            unrespondedCnt--;
            return;
        }

        requests[requestId].fee = DELIVERED_FEE_FLAG;
        unrespondedCnt--;

        if (error < 2) {
            // Either no error occurs, or the requester sent an invalid query.
            // Send the fee to the SGX account for its delivering.
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
        externalCallFlag = false;
    }

    function getRequestData(uint64 _requestId) public view returns (uint, uint8, uint, int, bytes32[]) {
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
            emit Cancel(requestId, msg.sender, requests[requestId].requester, requests[requestId].fee, 1);
            return SUCCESS_FLAG;
        } else {
            emit Cancel(requestId, msg.sender, requests[requestId].requester, fee, -1);
            return FAIL_FLAG;
        }
    }
}
