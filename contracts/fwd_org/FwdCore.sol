pragma solidity ^0.4.24;

import "./FwdContRequest.sol";
import "./FwdContProcess.sol";
import "../fees/Fees.sol";

contract FwdCore is FwdContRequest, FwdContProcess, Fees {
    function calculateFxAmtFromId(uint256 _fwdId) orderlyConnected() available() onlyParty(_fwdId) view public returns(uint256) {
        return _calculateFxAmtFromId(_fwdId);
    }

    // Admin Functions
    /*function adminSetAllCancel(bool _flag) onlyOwner() public {
        _setAllCancel(_flag);
    }*/

    function adminGetContractBalance() onlyOwner() view public returns(uint256) {
        return address(this).balance;
    }

    function adminGetFlags() onlyOwner() view public returns(
        //bool,
        uint256,
        uint256,
        uint256,
        bool,
        uint256,
        bool,
        uint256,
        uint256) {
        return(
            //cancelFlag,
            CANCELLED_FEE_FLAG,
            DELIVERED_FEE_FLAG,
            FAIL_FLAG,
            killswitch,
            newVersion,
            paused,
            SUCCESS_FLAG,
            unrespondedCnt
            );
    }

    function adminGetFwdRequest(uint256 _fwdId) onlyOwner() view public returns(
        bool,
        bool,
        uint256,
        uint256,
        bytes32,
        uint256,
        uint256) {
        return(
            cancelRequestSender[_fwdId],
            cancelRequestReceiver[_fwdId],
            fwdDeposits[_fwdId],
            fwdIndexToFees[_fwdId],
            fwdIndexToFwdState[_fwdId],
            fwdIndexToFxRate[_fwdId],
            fwdIndexToRequests[_fwdId]
            );
    }

    function adminGetFees() onlyOwner() view public returns(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256) {
        return (
            gasPrice,
            minGas,
            cancellationGas,
            externalGas,
            reqGas
            );
    }

    function adminSetFees(
        uint256 _gasPrice,
        uint256 _minGas,
        uint256 _cancellationGas,
        uint256 _externalGas,
        uint256 _txGasPrice,
        uint256 _reqGas) onlyOwner() public {
        _setFees(_gasPrice, _minGas, _cancellationGas, _externalGas, _txGasPrice);

        _setReqFee(_reqGas);
    }

    function adminResetKillswitch() onlyOwner() public {
        _resetKillswitch();
    }

    function adminResetUnrespond() onlyOwner() public {
        _resetUnrespond();
    }

    function adminSetNewVersion(address _newAddr) onlyOwner() public {
        _setNewVersion(_newAddr);
    }

    function adminWithdraw() onlyOwner() public {
        //_withdraw();
        owner.transfer(address(this).balance);
        emit AdminWithdraw(owner, address(this).balance);
    }

    function adminEmergencyCancel(uint256 _fwdId) orderlyConnected() available() onlyOwner() public payable {

        _emergencyCancel(_fwdId);
    }

    // user functions
    function request (
        //uint256 _contractDay,
        uint256 _settlementDuration,
        uint256 _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        uint256 _baseAmt
        ) available() orderlyConnected() public payable {

        _request(_settlementDuration, _expireDuration, _receiverAddr, _senderAddr, _baseAmt);
    }

    function deposit(uint256 _fwdId) orderlyConnected() available() public payable {

        _deposit(_fwdId);
    }

    function withdrawConfirm(uint256 _fwdId) orderlyConnected() available() public payable {

        _withdrawConfirm(_fwdId);
    }

    function withdraw(uint256 _fwdId) orderlyConnected() available() public {
        // withdraw depositted asset
        _withdrawFwd(_fwdId);
    }

    function cancel(uint256 _fwdId) orderlyConnected() available() onlyParty(_fwdId) public payable {
        // set cancelflag
        _setCancelFlag(_fwdId);
        // confirm both cancel flag is established
        require(cancelRequestSender[_fwdId] == true && cancelRequestReceiver[_fwdId] == true);
        // if fxRate is not fetch yet, refund fee.
        if (fwdIndexToFwdState[_fwdId] == fwdStates[0]) {
            _deleteRequest(_fwdId);
        }
        _cancelFwd(_fwdId);
    }

    function cancelConfirm(uint256 _fwdId) orderlyConnected() available() onlyParty(_fwdId) public payable {

        _cancelConfirm(_fwdId);
    }

    function emergencyConfirm(uint256 _fwdId) orderlyConnected() available() public payable {

        _emergencyConfirm(_fwdId);
    }

    function response(
        uint256 _requestId,
        uint256 _error,
        uint256 _respData
    ) available() orderlyConnected() external {

        _response(_requestId, _error, _respData);
    }

    function getFwdRequest(uint256 _fwdId) view public returns(
            address,
            uint256,
            uint256,
            uint256,
            address,
            address,
            uint256
        ) {
            return(
                fwdRequests[_fwdId].fwdOwner,
                fwdRequests[_fwdId].contractDay,
                fwdRequests[_fwdId].settlementDuration,
                fwdRequests[_fwdId].expireDuration,
                fwdRequests[_fwdId].receiverAddr,
                fwdRequests[_fwdId].senderAddr,
                fwdRequests[_fwdId].baseAmt
            );
        }

    function getFwdRequestInput(uint256 _fwdId) view public returns(
            uint256,
            uint256,
            bytes32,
            uint256         ) {
        return(
            fwdDeposits[_fwdId],
            fwdIndexToFees[_fwdId],
            fwdIndexToFwdState[_fwdId],
            fwdIndexToFxRate[_fwdId]
        );
    }
}
