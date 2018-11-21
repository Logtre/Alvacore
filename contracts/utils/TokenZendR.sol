pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract TokenZendR is Ownable, Pausable {
    /**
    * @dev Details of each transfer
    * @param contract_ contract address of ER20 token to transfer
    * @param to_ receiving account
    * @param amount_ number of tokens to transfer to_ account
    * @param failed_ if transfer was successful or not
    */
    struct Transfer {
    address contract_;
    address to_;
    uint amount_;
    bool failed_;
    }

    event TransferSuccessful(address indexed from_, address indexed to_, uint256 amount_);
    event TransferFailed(address indexed from_, address indexed to_, uint256 amount_);

    ERC20 public ERC20Interface;
    Transfer[] public transactions;
    address public owner;

    mapping(address => uint[]) public transactionIndexesToSender;
    mapping(bytes32 => address) public tokens;

    constructor() public {
        owner = msg.sender;
    }

    /*
    @dev add address of token to list of supported tokens using token symbol_
     as identifier in mapping
    */
    function addNewToken(bytes32 symbol_, address address_) public onlyOwner returns(bool) {
        tokens[symbol_] = address_;

        return true;
    }

    /*
    @dev remove address of token we no more support
    */
    function removeToken(bytes32 symbol_) public onlyOwner returns(bool) {
        require(tokens[symbol_] != 0x0);

        delete(tokens[symbol_]);

        return true;
    }

    /*
    @dev method that handles transfer of ERC20 tokens to other address
     it assumes the calling address has approved this contract
     as spender
    @param symbol_ identifier mapping to a token contract address
    @param to_ beneficiary address
    @param amount_ numbers of transfer
    */
    function transferTokens(bytes32 symbol_, address to_, uint256 amount_) public whenNotPaused {
        require(tokens[symbol_] != 0x0);
        require(amount_ > 0);

        address contract_ = tokens[symbol_];
        address from_ = msg.sender;

        ERC20Interface = ERC20(contract_);

        // @dev linkage txID and transaction
        //  for tx fail, initial value of failed_ is "true"
        uint256 transactionId = transactions.push(
            Transfer({
                contract_: contract_,
                to_: to_,
                amount_: amount_,
                failed_: true
                })
            );
        // @dev linkage sender address and txID
        transactionIndexesToSender[from_].push(transactionId - 1);

        // @dev if sending amount is exceed token's allowance amount, revert tx.
        if(amount_ > ERC20Interface.allowance(from_, address(this))) {
            emit TransferFailed(from_, to_, amount_);
            revert();
        }
        // @dev if sending amount is not exceed allowance amount, broadcast tx.
        ERC20Interface.transferFrom(from_, to_, amount_);
        // @dev if tx is successful, failed value is changed "false"
        transactions[transactionId - 1].failed_ = false;

        emit TransferSuccessful(from_, to_, amount_);
    }

    /*
    @dev allow contract to receive funds
    */
    function() public payable {}

    /*
    @dev withdraw funds from this contract
    @param beneficiary address to receive ether
    */
    function withdraw(address beneficiary) public payable onlyOwner whenNotPaused {
        beneficiary.transfer(address(this).balance);
    }
}
