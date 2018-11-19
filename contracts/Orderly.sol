pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/lifecycle/Pausable.sol";
import "https://github.com/Logtre/Alvacore/contracts/utils/Utils.sol";
import "https://github.com/Logtre/Alvacore/contracts/fees/Fees.sol";
//import "https://github.com/Logtre/Alvacore/math/SafeMath.sol";


contract Orderly is Pausable {

    event RequestInfo(
        uint256 requestId,
        bytes4 requestType,
        address requester,
        uint256 fee,
        bytes32 paramsHash,
        uint256 timestamp,
        bytes32 _requestState,
        bytes32 requestData
    ); // log of requests, the Town Crier server watches this event and processes requests
    event DeliverInfo(
        uint256 requestId,
        uint256 fee,
        uint256 gasPrice,
        uint256 gasLeft,
        uint256 callbackGas,
        bytes32 paramsHash,
        uint256 error,
        uint256 respData
    ); // log of responses
    event CheckFee(
        uint256 msgValue,
        uint256 minFee,
        address msgSnder
    );
    event RequestCancel(
        uint256 requestId,
        address canceller,
        uint256 flag
    );
    event RequestDelete(uint256 requestId);
    event RequestState(uint256 requestId, bytes32 requestState);
    event setAlvcAddress(address alvcAddress);
    event setAlvcWallet(address alvcWallet);

    struct Request { // the data structure for each request
        address requester;
        uint256 fee; // the amount of wei the requester pays for the request
        bytes4 callbackFID; // the specification of the callback function
        bytes32 paramsHash; // the hash of the request parameters
        uint256 timestamp; // the timestamp of the request emitted
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

    address public alvcAddress; // address of the ALVC ADDRESS @TestNet
    address public alvcWallet; // address of the ALVC WALLET @TestNet

    //bytes32 public constant KEYWORD = "FWD";

    mapping (uint256 => Request) public requests;
    mapping (bool => Request) public cancelFlag;
    mapping (uint256 => bytes32) public requestIndexToState;

    uint256 public requestCnt;
    uint256 internal unrespondedCnt;

    constructor() public {
        // Start request IDs at 1 for two reasons:
        //   1. We can use 0 to denote an invalid request (ids are unsigned)
        //   2. Storage is more expensive when changing something from zero to non-zero,
        //      so this means the first request isn't randomly more expensive.
        _createRequest(msg.sender, 0, "", "", int(now), "", 0);
        //requestCnt = 1;
        owner = msg.sender;
        killswitch = false;
        //cancelFlag = false;
        unrespondedCnt = 0;
    }

    function _addRequest(uint256 _requestId, Request _request) private {
        requests[_requestId] = _request;
        cancelFlag[_requestId] = false;
        requestIndexToState[_requestId] = requestStates[0];
        requestCnt ++;
    }

    function _createRequest(
        address _requester,
        uint256 _fee,
        bytes4 _callbackFID,
        bytes32 _paramsHash,
        uint256 _timestamp,
        bytes32 _requestData,
        uint256 _requestCnt
        ) internal returns(uint256) {
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
        emit setAlvcWallet(_newAlvcWallet);
    }

    function _setAlvcAddress(address _newAlvcAddress) internal {
        alvcAddress = _newAlvcAddress;
        emit setAlvcAddress(_newAlvcAddress);
    }

    function getRequestIndex() public view returns(int) {
        uint256 requestsLength = requestCnt;

        for (uint256 i=1; i<requestsLength; i++) {
            if (requestIndexToState[i] == requestStates[0]) {
                return (i);
            }
        }
        // there is request to match requestState
        return 0;
    }

    function _cancel(uint256 _requestId, uint256 _value) internal {
        // return value and delete request
        _deleteRequest(_requestId, msg.sender, _value);
        // emit event
        emit RequestCancel(_requestId, msg.sender, SUCCESS_FLAG);
    }

    function _deleteRequest(uint256 _requestId, address _to, uint256 _value) internal {
        // escape Request another struct
        Request memory targetRequest = requests[_requestId];
        // delete request
        delete requests[_requestId];
        cancelFlag[_requestId] = true;
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

    function _setRequestState(uint256 _requestId, uint256 _index) internal {
        requestIndexToState[_requestId] = requestStates[_index];

        emit RequestState(_requestId, requestStates[_index]);
    }

    function _isRequester(uint256 _requestId) view internal {
         require (msg.sender == requests[_requestId].requester);
    }

    function _isALVC(address _from) view internal {
        require (_from == alvcWallet);
    }
}
