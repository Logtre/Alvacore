pragma solidity ^0.4.24;

//import "./FwdContRequest.sol";
import "./FwdContProcess.sol";
//import "./fees/Fees.sol";

contract FwdCore is FwdContProcess {

    /**
        @dev    get all fwd balance
    */
    function adminGetContractBalance() onlyOwner() view public returns(uint256) {
        return address(this).balance;
    }

    /**
        @dev    check contract's flag
    */
    function adminGetFlags() onlyOwner() view public returns(
        //uint256,
        //uint256,
        //uint256,
        bool,
        uint256,
        bool) {
        //uint256){
        return(
            //CANCELLED_FEE_FLAG,
            //DELIVERED_FEE_FLAG,
            //FAIL_FLAG,
            killswitch,
            newVersion,
            paused
            //SUCCESS_FLAG
            );
    }

    /**
        @dev    get specific fwd financial information
        @param  _fwdId  fwd id
    */
    function adminGetFwdInfo(uint256 _fwdId) onlyOwner() view public returns(
        bool,
        bool,
        uint256,
        bytes32,
        uint256,
        bytes32,
        bytes32) {
        return(
            cancelRequestSender[_fwdId],
            cancelRequestReceiver[_fwdId],
            fwdDeposits[_fwdId],
            fwdIndexToFwdState[_fwdId],
            fwdHedges[_fwdId],
            fwdIndexToHedgeState[_fwdId],
            fwdIndexToHedgeSign[_fwdId]);
    }

    /**
        @dev    get process fee
    */
    function adminGetFees() onlyOwner() view public returns(uint256) {
        return (processFee);
    }

    /**
        @dev    set contract's fee
        @param  _processFee amount of fee
    */
    function adminSetFees(uint256 _processFee) onlyOwner() public {
        _setFees(_processFee);
    }

    /**
        @dev    reset killswitch
    */
    function adminResetKillswitch() onlyOwner() public {
        _resetKillswitch();
    }

    /**
        @dev    set newversion flag
    */
    function adminSetNewVersion(address _newAddr) onlyOwner() public {
        _setNewVersion(_newAddr);
    }

    /**
        @dev    withdraw pooled contract's balance
    */
    function adminWithdraw() onlyOwner() public {
        //_withdraw();
        owner.transfer(address(this).balance);
        emit AdminWithdrawFwd(owner, address(this).balance);
    }

    /**
        @dev    supply amount to contract
        @param  _supplyAmt amount of supply
    */
    function adminSupplyBalance(uint256 _supplyAmt) onlyOwner() payable public {
        address(this).transfer(_supplyAmt);
        emit AdminSupplyBalance(owner, address(this).balance);
    }

    /**
        @dev    emergency cancel
        @param  _fwdId  fwd id
    */
    function adminEmergencyCancel(uint256 _fwdId) available() onlyOwner() public payable {
        // emergency operation
        _emergencyCancel(_fwdId);
    }

    /**
        @dev    execute request operation
        @param  _settlementDuration duration untill settlementDay
        @param  _receiverAddr       receiver's address
        @param  _senderAddr         sender's address
    */
    function request (
        //uint256 _contractDay,
        uint256 _settlementDuration,
        //uint256 _expireDuration,
        address _receiverAddr,
        address _senderAddr
        //uint256 _baseAmt
        ) available() public returns(uint256) {
        // request operation
        _createFwd(msg.sender, now, _settlementDuration, _receiverAddr, _senderAddr, fwdCnt);
    }

    /**
        @dev    execute deposit operation
        @param  _fwdId  fwd id
    */
    function deposit(uint256 _fwdId) available() noHedge(_fwdId) public payable returns(uint256) {
        // deposit operation
        _deposit(_fwdId);
    }

    /**
        @dev    execute hedge operation
        @param  _fwdId  fwd id
    */
    function hedge(uint256 _fwdId) available() onlyOwner() public {
        // hedge operation
        _hedge(_fwdId);
    }

    /**
        @dev    confirm hedge amount
        @param  _fwdId      fwd id
        @param  _hedgeAmt   absolute amount of reprenish
        @param  _signIndex  index of sign(1: positive, 2: negative)
    */
    function confirmHedge(uint256 _fwdId, uint256 _hedgeAmt, uint256 _signIndex) available() onlyOwner() public {
        // hedge operation
        _confirmHedge(_fwdId, _hedgeAmt, _signIndex);
    }

    /**
        @dev    confirm hedge amount
        @param  _fwdId      fwd id
    */
    function replenish(uint256 _fwdId) available() onlyOwner() public {
        // replenish operation
        _replenishHedge(_fwdId);
    }

    /**
        @dev    confirm linked fwd
        @param  _fwdId  fwd id
    */
    function confirmWithdraw(uint256 _fwdId) available() public {
        // confirm operation
        _confirmWithdraw(_fwdId);
    }

    /**
        @dev    withdraw depositted asset
        @param  _fwdId  fwd id
    */
    function withdraw(uint256 _fwdId) available() public {
        // withdraw depositted asset
        _withdraw(_fwdId);
        // delete storage
        _deleteHedge(_fwdId);
    }

    /**
        @dev    emit cancel request
        @param  _fwdId          fwd id
        @param  _reasonIndex    index number linked with cancelReasons list
    */
    function cancelRequest(uint256 _fwdId, uint256 _reasonIndex) available() onlyParty(_fwdId) public {
        // confirm both cancel flag is established
        require(cancelRequestSender[_fwdId] == true && cancelRequestReceiver[_fwdId] == true);
        // if fxRate is not fetch yet, refund fee.
        if (fwdIndexToFwdState[_fwdId] == fwdStates[0]) {
            _deleteFwd(_fwdId);
        }
        // cancel request operation
        _cancelRequestFwd(_fwdId, _reasonIndex);
    }

    /**
        @dev    cancel fwd
        @param  _fwdId   fwd id
    */
    function cancel(uint256 _fwdId) available() onlyParty(_fwdId) public {
        // cancel operation
        _cancel(_fwdId);
    }

    /**
        @dev    emit emergency request
        @param  _fwdId          fwd id
        @param  _reasonIndex    index number linked with cancelReasons list
    */
    function emergencyRequest(uint256 _fwdId, uint256 _reasonIndex) available() public {
        // emergency request operation
        _emergencyRequestFwd(_fwdId, _reasonIndex);
    }

    /**
        @dev    get fwd non-financial information
        @param  _fwdId   fwd id
    */
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

        /**
            @dev    get fwd financial info
            @param  _fwdId   fwd id
        */
    function getFwdInfo(uint256 _fwdId) view onlyParty(_fwdId) public returns(
            uint256,
            bytes32,
            uint256,
            bytes32,
            bytes32) {
        return(
            fwdDeposits[_fwdId],
            fwdIndexToFwdState[_fwdId],
            fwdHedges[_fwdId],
            fwdIndexToHedgeState[_fwdId],
            fwdIndexToHedgeSign[_fwdId]
        );
    }
}
