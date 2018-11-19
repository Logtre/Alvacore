pragma solidity ^0.4.24;

/*
    Utilities & Common Modifiers
*/
contract Utils {
    /**
        constructor
    */
    constructor() public {
    }

    // verifies that an amount is greater than zero
    modifier greaterThanZero(uint256 _amount) {
        require(_amount > 0);
        _;
    }

    // validates an address - currently only checks that it isn't null
    modifier validAddress(address _address) {
        require(_address != address(0));
        _;
    }

    // verifies that the address is different than this contract address
    modifier notThis(address _address) {
        require(_address != address(this));
        _;
    }

    /**
        @dev _convertBytesToBytes8 change from multi-bytes text data to 8byte text data.
    */
    function _convertBytesToBytes8(bytes inBytes) internal pure returns (bytes8 outBytes8) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes8 := mload(add(inBytes, 8))
        }
    }

    /**
        @dev _convertBytesToBytes32 change from multi-bytes text data to 32byte text data.
    */
    function _convertBytesToBytes32(bytes inBytes) internal pure returns (bytes32 outBytes32) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes32 := mload(add(inBytes, 32))
        }
    }
}
