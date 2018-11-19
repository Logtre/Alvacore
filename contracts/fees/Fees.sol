pragma solidity ^0.4.24;

import "https://github.com/Logtre/Alvacore/contracts/math/SafeMath.sol";

contract Fees {

    event SetFees(
        uint256 minGas,
        uint256 gasPrice,
        uint256 cancellationGas,
        uint256 externalGas,
        uint256 txGasPrice
    );

    uint256 internal minGas = 300000;
    uint256 internal gasPrice = 5 * 10**10;
    uint256 internal cancellationGas = 250000; // charged when the requester cancels a request that is not responded
    uint256 internal externalGas = 50000;
    uint256 internal txGasPrice = 10; //10Wei for Rinkeby

    constructor() public {
    }

    /**
        @dev _setFees set contract's fees.
        @param _gasPrice gasprice which is set when user create transactions.
        @param _minGas minimum gasprice which is set when user create transactions.
        @param _externalGas minimum gasprice which is set when user create external transactions.
        @param _cancellationGas gasprice which is needed when cancel order.
        @param _txGasPrice gasprice which is needed when order to contract.
    */
    function _setFees(uint256 _gasPrice, uint256 _minGas, uint256 _cancellationGas, uint256 _externalGas, uint256 _txGasPrice) internal {
        gasPrice = _gasPrice;
        minGas = _minGas;
        cancellationGas = _cancellationGas;
        externalGas = _externalGas;
        txGasPrice = _txGasPrice;

        emit setFees(minGas, gasPrice, cancellationGas, externalGas, txGasPrice);
    }
}
