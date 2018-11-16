pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/AccessControl.sol";


contract Base is AccessControl {

    event Upgrade(address newAddr);

    int internal minGas = 300000;
    int internal gasPrice = 5 * 10**10;
    int internal cancellationGas = 250000; // charged when the requester cancels a request that is not responded
    int internal externalGas = 50000;
    int internal txGasPrice = 10; //10Wei for Rinkeby

    int internal constant CANCELLED_FEE_FLAG = 1;
    int internal constant DELIVERED_FEE_FLAG = 0;
    int internal constant FAIL_FLAG = -2 ** 250;
    int internal constant SUCCESS_FLAG = 1;

    bool public killswitch;
    bool public cancelFlag;
    int internal unrespondedCnt;
    int public newVersion;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier available() {
        require(killswitch == false && newVersion == 0);
        _;
    }

    modifier noKillswitch() {
        require(killswitch == false);
        _;
    }

    modifier noCancelFlag() {
        require(cancelFlag == false);
        _;
    }

    modifier noNewVersion() {
        require(newVersion == 0);
        _;
    }

    constructor() public {
        killswitch = false;
        cancelFlag = false;
        unrespondedCnt = 0;
        newVersion = 0;
    }

    function _convertBytesToBytes8(bytes inBytes) internal pure returns (bytes8 outBytes8) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes8 := mload(add(inBytes, 8))
        }
    }

    function _convertBytesToBytes32(bytes inBytes) internal pure returns (bytes32 outBytes32) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes32 := mload(add(inBytes, 32))
        }
    }

    function _withdraw() internal {
        if (!owner.call.value(address(this).balance)()) {
            revert();
        }
    }

    function _upgrade(address _newAddr) internal {
        newVersion = -int(_newAddr);
        killswitch = true;
        emit Upgrade(_newAddr);
    }

    function _restart() internal {
        if (newVersion == 0) {
            killswitch = false;
        }
    }

    function _setFees(int _gasPrice, int _minGas, int _cancellationGas, int _externalGas, int _txGasPrice) internal {
        gasPrice = _gasPrice;
        minGas = _minGas;
        cancellationGas = _cancellationGas;
        externalGas = _externalGas;
        txGasPrice = _txGasPrice;
    }
    function _resetKillswitch() internal {
        killswitch = false;
    }

    function _resetUnrespond() internal {
        unrespondedCnt = 0;
    }

    function _setNewVersion(address _newAddr) internal {
        newVersion = int(_newAddr);
    }

    function _externalCall(address _to, int _value) internal {
        // if transfer volume greater than balance,
        // set volume as 80% of balance.
        // if there is surplus asset, administor
        // withdraw via withdraw function.
        if (_value > int(address(this).balance)) {
            _value = int(address(this).balance * 80 / 100);
        }

        if (!_to.call.value(uint(_value))()) {
            revert();
        }
    }

    function _transfer(address _to, int _value) internal {
        // if transfer volume greater than balance,
        // set volume as 80% of balance.
        // if there is surplus asset, administor
        // withdraw via withdraw function.
        if (_value > int(address(this).balance)) {
            _value = int(address(this).balance * 80 / 100);
        }

        if (!_to.send(uint(_value))) {
            revert();
        }
    }

    function _setAllCancel(bool _flag) internal {
        cancelFlag = _flag;
    }
}
