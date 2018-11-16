pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/FwdContRequest.sol";
import "https://github.com/Logtre/Alvacore/contracts/FwdContProcess.sol";


contract FwdCore is FwdContRequest, FwdContProcess {
    function calculateFxAmtFromId(int _fwdId) orderlyConnected() available() onlyParty(_fwdId) view public returns(int) {
        return _calculateFxAmtFromId(_fwdId);
    }

    // Admin Functions
    function adminSetAllCancel(bool _flag) onlyOwner() public {
        _setAllCancel(_flag);
    }

    function adminGetContractBalance() onlyOwner() view public returns(uint) {
        return address(this).balance;
    }

    function adminGetFlags() onlyOwner() view public returns(bool, int, int, int, bool, int, bool, int, int) {
        return(
            cancelFlag,
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

    function adminGetFwdRequest(int _fwdId) onlyOwner() view public returns(bool, bool, int, int, bytes32, int, int) {
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

    function adminGetFees() onlyOwner() view public returns(int, int, int, int, int) {
        return (
            gasPrice,
            minGas,
            cancellationGas,
            externalGas,
            reqGas
            );
    }

    function adminSetFees(int _gasPrice, int _minGas, int _cancellationGas, int _externalGas, int _txGasPrice, int _reqGas) onlyOwner() public {
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
        _withdraw();
    }

    function adminEmergencyCancel(int64 _fwdId) orderlyConnected() available() onlyOwner() public payable {

        _emergencyCancel(_fwdId);
    }

    // user functions
    function request (
        //int _contractDay,
        int _settlementDuration,
        int _expireDuration,
        address _receiverAddr,
        address _senderAddr,
        int _baseAmt
        ) available() orderlyConnected() public payable {

        _request(_settlementDuration, _expireDuration, _receiverAddr, _senderAddr, _baseAmt);
    }

    function deposit(int _fwdId) orderlyConnected() available() public payable {

        _deposit(_fwdId);
    }

    function withdrawConfirm(int _fwdId) orderlyConnected() available() public payable {

        _withdrawConfirm(_fwdId);
    }

    function withdraw(int _fwdId) orderlyConnected() available() public {
        // withdraw depositted asset
        _withdrawFwd(_fwdId);
    }

    function cancel(int64 _fwdId) orderlyConnected() available() onlyParty(_fwdId) public payable {
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

    function cancelConfirm(int _fwdId) orderlyConnected() available() onlyParty(_fwdId) public payable {

        _cancelConfirm(_fwdId);
    }

    function emergencyConfirm(int _fwdId) orderlyConnected() available() public payable {

        _emergencyConfirm(_fwdId);
    }

    function response(
        int _requestId,
        int _error,
        int _respData
    ) available() orderlyConnected() external {

        _response(_requestId, _error, _respData);
    }

    function getFwdRequest(int _fwdId) view public returns(
            address,
            int,
            int,
            int,
            address,
            address,
            int
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

    function getFwdRequestInput(int _fwdId) view public returns(
            int,
            int,
            bytes32,
            int
        ) {
        return(
            fwdDeposits[_fwdId],
            fwdIndexToFees[_fwdId],
            fwdIndexToFwdState[_fwdId],
            fwdIndexToFxRate[_fwdId]
        );
    }
}
