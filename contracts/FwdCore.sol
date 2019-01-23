pragma solidity ^0.4.24;

//import "./FwdContRequest.sol";
import "./FwdContProcess.sol";
//import "./fees/Fees.sol";

contract FwdCore is FwdContProcess {

    function adminGetContractBalance() onlyOwner() view public returns(uint256) {
        return address(this).balance;
    }

    function adminGetFlags() onlyOwner() view public returns(
        uint256,
        uint256,
        uint256,
        bool,
        uint256,
        bool,
        uint256){
        return(
            CANCELLED_FEE_FLAG,
            DELIVERED_FEE_FLAG,
            FAIL_FLAG,
            killswitch,
            newVersion,
            paused,
            SUCCESS_FLAG
            );
    }

    function adminGetFwdRequest(uint256 _fwdId) onlyOwner() view public returns(
        bool,
        bool,
        uint256,
        bytes32) {
        return(
            cancelRequestSender[_fwdId],
            cancelRequestReceiver[_fwdId],
            fwdDeposits[_fwdId],
            fwdIndexToFwdState[_fwdId]);
    }

    function adminGetFees() onlyOwner() view public returns(uint256) {
        return (processFee);
    }

    function adminSetFees(
        uint256 _processFee) onlyOwner() public {
        _setFees(_processFee);
    }

    function adminResetKillswitch() onlyOwner() public {
        _resetKillswitch();
    }

    function adminSetNewVersion(address _newAddr) onlyOwner() public {
        _setNewVersion(_newAddr);
    }

    function adminWithdraw() onlyOwner() public {
        //_withdraw();
        owner.transfer(address(this).balance);
        emit AdminWithdrawFwd(owner, address(this).balance);
    }

    function adminEmergencyCancel(uint256 _fwdId) available() onlyOwner() public payable {

        _emergencyCancel(_fwdId);
    }

    // user functions
    function request (
        //uint256 _contractDay,
        uint256 _settlementDuration,
        //uint256 _expireDuration,
        address _receiverAddr,
        address _senderAddr
        //uint256 _baseAmt
        ) available() public payable {

        _createFwd(msg.sender, now, _settlementDuration, _receiverAddr, _senderAddr, fwdCnt);
    }

    function deposit(uint256 _fwdId) available() public payable {

        _deposit(_fwdId);
    }

    function hedge(uint256 _fwdId) available() public payable {

        _hedge(_fwdId);
    }

    function confirmWithdraw(uint256 _fwdId) available() public payable {

        _confirmWithdraw(_fwdId);
    }

    function withdraw(uint256 _fwdId) available() public {
        // withdraw depositted asset
        _withdraw(_fwdId);
    }

    function cancelRequest(uint256 _fwdId, uint256 _reasonIndex) available() onlyParty(_fwdId) public payable {
        // confirm both cancel flag is established
        require(cancelRequestSender[_fwdId] == true && cancelRequestReceiver[_fwdId] == true);
        // if fxRate is not fetch yet, refund fee.
        if (fwdIndexToFwdState[_fwdId] == fwdStates[0]) {
            _deleteFwd(_fwdId);
        }
        _cancelRequestFwd(_fwdId, _reasonIndex);
    }

    function cancel(uint256 _fwdId) available() onlyParty(_fwdId) public payable {

        _cancel(_fwdId);
    }

    function emergencyRequest(uint256 _fwdId, uint256 _reasonIndex) available() public payable {

        _emergencyRequestFwd(_fwdId, _reasonIndex);
    }

    function getFwdRequest(uint256 _fwdId) view public returns(
            address,
            uint256,
            uint256,
            address,
            address) {
            return(
                fwdRequests[_fwdId].fwdOwner,
                fwdRequests[_fwdId].contractDay,
                fwdRequests[_fwdId].settlementDuration,
                fwdRequests[_fwdId].receiverAddr,
                fwdRequests[_fwdId].senderAddr
            );
        }

    function getFwdRequestInput(uint256 _fwdId) view public returns(
            uint256,
            bytes32) {
        return(
            fwdDeposits[_fwdId],
            fwdIndexToFwdState[_fwdId]
        );
    }
}
