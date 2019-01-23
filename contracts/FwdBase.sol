pragma solidity ^0.4.24;

import "./ownership/AccessControl.sol";
//import "../ownership/Ownable.sol";
//import "../math/SafeMath.sol";
//import "openzeppelin-solidity/contracts/utils/Address.sol";
//import "openzeppelin-solidity/contracts/utils/Arrays.sol";
//import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

/**
    @dev FwdBase defines available and pausable functions
*/
contract FwdBase is AccessControl {

    event Upgrade(address newAddr);
    event Killswitch(bool killswitch);

    uint256 public processFee = 2 finney;

    //uint256 internal constant CANCELLED_FEE_FLAG = 1;
    //uint256 internal constant DELIVERED_FEE_FLAG = 0;
    //uint256 internal constant FAIL_FLAG = 0;
    //uint256 internal constant SUCCESS_FLAG = 1;

    bool public killswitch;
    uint256 public newVersion;

    /**
        @dev if killswitch flag and newVersion flag are set, tx can be reverted.
    */
    modifier available() {
        require(killswitch == false && newVersion == 0);
        _;
    }

    /**
        @dev if killswitch isn't set, tx cannot be reverted.
    */
    modifier noKillswitch() {
        require(killswitch == false);
        _;
    }

    /**
        @dev if noCancelflag is set, tx can be reverted.
    */
    //modifier noCancelFlag() {
    //    require(cancelFlag == false);
    //    _;
    //}

    /**
        @dev if newVersion flag is set, tx can be reverted.
    */
    modifier noNewVersion() {
        require(newVersion == 0);
        _;
    }

    /**
        @dev constructor
    */
    constructor() public {
        killswitch = false;
        //cancelFlag = false;
        //unrespondedCnt = 0;
        newVersion = 0;
    }

    /**
        @dev _withdraw send all asset in contract to owner's address.
    */
    //function _withdraw() internal {
    //    if (!owner.call.value(address(this).balance)()) {
    //        revert();
    //    }
    //}

    /**
        @dev _upgrade change contract's version.

        @param _newAddr  address of new contract
    */
    function _upgrade(address _newAddr) internal {
        newVersion = uint256(_newAddr);
        killswitch = true;
        emit Upgrade(_newAddr);
    }

    /**
        @dev _restart change newVersion flag.
    */
    function _restart() internal {
        if (newVersion == 0) {
            killswitch = false;
            emit Killswitch(killswitch);
        }
    }

    /**
        @dev _resetKillswitch release killswitch flag.
    */
    function _resetKillswitch() internal {
        killswitch = false;
        emit Killswitch(killswitch);
    }

    /**
        @dev _setNewVersion set newVersion flag.

        @param _newAddr  address of new contract
    */
    function _setNewVersion(address _newAddr) internal {
        newVersion = uint256(_newAddr);
        emit Upgrade(_newAddr);
    }

    /**
        @dev _setAllCancel set cancelFlag.
    */
    //function _setAllCancel(bool _flag) internal {
    //    cancelFlag = _flag;
    //}
}
