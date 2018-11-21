pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/ownership/AccessControl.sol";
//import "https://github.com/Logtre/Alvacore/contracts/ownership/Ownable.sol";
//import "https://github.com/Logtre/Alvacore/contracts/math/SafeMath.sol";
//import "openzeppelin-solidity/contracts/utils/Address.sol";
//import "openzeppelin-solidity/contracts/utils/Arrays.sol";
//import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

/**
    Pausable defines lifecycle function
*/
contract Pausable is AccessControl {

    event Upgrade(address newAddr);
    event Killswitch(bool killswitch);

    uint256 internal minGas = 300000;
    uint256 internal gasPrice = 5 * 10**10;
    uint256 internal cancellationGas = 250000; // charged when the requester cancels a request that is not responded
    uint256 internal externalGas = 50000;
    uint256 internal txGasPrice = 10; //10Wei for Rinkeby

    uint256 internal constant CANCELLED_FEE_FLAG = 1;
    uint256 internal constant DELIVERED_FEE_FLAG = 0;
    uint256 internal constant FAIL_FLAG = -2 ** 250;
    uint256 internal constant SUCCESS_FLAG = 1;

    bool public killswitch;
    //bool public cancelFlag;
    uint256 internal unrespondedCnt;
    uint256 public newVersion;

    /**
        @dev available revert tx, if killswitch flag is set, and newVersion flag is set.
    */
    modifier available() {
        require(killswitch == false && newVersion == 0);
        _;
    }

    /**
        @dev noKillswitch revert tx, if killswitch flag is set.
    */
    modifier noKillswitch() {
        require(killswitch == false);
        _;
    }

    /**
        @dev noCancelFlag revert tx, if cancelFlag is set.
    */
    //modifier noCancelFlag() {
    //    require(cancelFlag == false);
    //    _;
    //}

    /**
        @dev noNewVersion revert tx, if newVersion flag is set.
    */
    modifier noNewVersion() {
        require(newVersion == 0);
        _;
    }

    constructor() public {
        killswitch = false;
        //cancelFlag = false;
        unrespondedCnt = 0;
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
        }
    }

    /**
        @dev _resetKillswitch release killswitch flag.
    */
    function _resetKillswitch() internal {
        killswitch = false;
    }

    /**
        @dev _resetUnrespond release unrespondedCnt.
    */
    function _resetUnrespond() internal {
        unrespondedCnt = 0;
    }

    /**
        @dev _setNewVersion set newVersion flag.
    */
    function _setNewVersion(address _newAddr) internal {
        newVersion = uint256(_newAddr);
    }

    /**
        @dev _setAllCancel set cancelFlag.
    */
    //function _setAllCancel(bool _flag) internal {
    //    cancelFlag = _flag;
    //}
}
