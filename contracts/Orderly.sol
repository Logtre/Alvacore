pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/Base.sol";


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

    address public alvcAddress = 0xD7E2b2857fA34F08Db2262Fb684A3782BC750e70; // address of the ALVC ADDRESS @TestNet
    address public alvcWallet = 0x0115b95cdF80C0463c60190efC965Ba857F2F8B7; // address of the ALVC WALLET @TestNet

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
        alvcWallet = _newAlvcWallet;
    }

    function _setAlvcAddress(address _newAlvcAddress) internal {
        alvcAddress = _newAlvcAddress;
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
        require (_from == alvcWallet);
    }
}
