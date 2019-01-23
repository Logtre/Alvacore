pragma solidity ^0.4.24;

import "../math/SafeMath.sol";

contract Fees {
    using SafeMath for uint256;

    event SetFees(
        uint256 processFee
    );

    uint256 public processFee = 2 finney;

    constructor() public {
    }

    /**
        @dev _setFees set contract's fees.
        @param _processFee  new process fee
    */
    function _setFees(uint256 _processFee) internal {
        processFee = _processFee.mul(1 finney);

        emit SetFees(processFee);
    }
}
