pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/Orderly.sol";
import "https://github.com/Logtre/Alvacore/contracts/FwdCharacteristic.sol";
import "https://github.com/Logtre/Alvacore/contracts/utils/Utils.sol";
import "https://github.com/Logtre/Alvacore/contracts/fees/Fees.sol";
import "https://github.com/Logtre/Alvacore/contracts/math/SafeMath.sol";

contract FwdOrderlyRequest is Orderly, FwdCharacteristic, Utils, Fees {
    using SafeMath for uint256;

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
        uint256 _timestamp,
        bytes32 _requestData
        ) whenNotPaused() available() public payable returns (int) {

        //int _requestCnt = requestCnt;

        _correctBusiness(_requestType);

        if (int(msg.value) < minGas.mul(gasPrice)) {
            //emit CheckFee(msg.value, minGas * gasPrice, msg.sender);
            //_externalCall(msg.sender, msg.value);
            //return FAIL_FLAG;
            revert();
        } else {
            uint256 requestId = _createRequest(
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

    function getRequest(uint256 _requestId) view public returns(bytes32, int, bytes32, bytes32) {
        bytes32 _requestType = KEYWORD;
        uint256 _timestamp = requests[_requestId].timestamp;
        bytes32 _requestState = requestIndexToState[_requestId];
        bytes32 _requestData = requests[_requestId].requestData;

        return(_requestType, _timestamp, _requestState, _requestData);
    }

    function requestCancel(
        uint256 _requestId,
        uint256 _value
        ) public  whenNotPaused() available() {
        // primise: this function is called by FwdCont
        // only requester can execute
        _isRequester(_requestId);

        _cancel(_requestId, _value);
    }

    function deliver(uint256 _requestId, bytes _paramsHash, uint256 _error, uint256 _respData) whenNotPaused() available() public {
        uint256 _callbackGas = (requests[_requestId].fee - minGas * gasPrice) / txGasPrice; // gas left for the callback function
        bytes32 _paramsHash32bytes = _convertBytesToBytes32(_paramsHash);

        _isALVC(msg.sender);

        if (_requestId <= 0 ||
            _paramsHash32bytes != requests[_requestId].paramsHash) {
            // error
            _setRequestState(_requestId, 4);
        } else if (cancelFlag[_requestId]) {
            // If the request is cancelled by the requester, cancellation
            // fee goes to the SGX account and set the request as having
            // been responded to.
            //_transfer(alvcAddress, cancellationGas.mul(gasPrice));
            alvcAddress.transfer(cancellationGas.mul(gasPrice));
            // canceled
            _setRequestState(_requestId, 2);
            return;
        }

        if (_error < 2) {
            // Either no error occurs, or the requester sent an invalid query.
            // Send the fee to the SGX account for its delivering.
            //_transfer(alvcAddress, requests[_requestId].fee);
            alvcAddress.transfer(requests[_requestId].fee);
        } else {
            // Error in TC, refund the requester.
            //_transfer(requests[_requestId].requester, requests[_requestId].fee);
            requests[_requestId].transfer(requests[_requestId].fee);

            _setRequestState(_requestId, 5);
        }

        emit DeliverInfo(_requestId, requests[_requestId].fee, int(tx.gasprice), int(gasleft()), _callbackGas, _paramsHash32bytes, _error, _respData); // log the response information

        if (_callbackGas > int(gasleft().div(tx.gasprice)) - externalGas) {
            _callbackGas = int(gasleft().div(tx.gasprice)) - externalGas;
        }

        if(!requests[_requestId].requester.call.gas(uint(_callbackGas.mul(gasPrice)))(
            requests[_requestId].callbackFID,
            _requestId,
            _error,
            _respData)) { // call the callback function in the application contract
            revert();
        }

        _setRequestState(_requestId, 1);

        _deleteRequest(_requestId, alvcAddress, minGas.mul(gasPrice).mul(80).div(100));
    }

    //function setAllCancel(bool _flag) onlyOwner() public {
    //    _setAllCancel(_flag);
    //}

    function setAlvcWallet(address _newAlvcWallet) onlyOwner() public {
        _setAlvcWallet(_newAlvcWallet);
    }

    function setAlvcAddress(address _newAlvcAddress) onlyOwner() public {
        _setAlvcAddress(_newAlvcAddress);
    }

    function setFees(uint256 _gasPrice, uint256 _minGas, uint256 _cancellationGas, uint256 _externalGas, uint256 _txGasPrice) onlyOwner() public {
        _setFees(_gasPrice, _minGas, _cancellationGas, _externalGas, _txGasPrice);
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

    function setRequestState(uint256 _requestId, uint256 _index) onlyOwner() public {
        _setRequestState(_requestId, _index);
    }
}
