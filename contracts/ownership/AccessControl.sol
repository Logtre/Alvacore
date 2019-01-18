pragma solidity ^0.4.24;


/**
    AccessControl define contract owner's authority
*/
contract AccessControl {

    address public owner;

    bool public paused = false;
    /**
        @dev onlyOwner
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
        @dev whenNotPaused revert tx. If paused flag is effective.
    */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
        @dev whenPaused revert tx. If paused flag is not effective.
    */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
        @dev adminSetOwner change contract's owner.
    */
    function adminSetOwner(address _newOwner) external onlyOwner() {
        require(_newOwner != address(0));

        owner = _newOwner;
    }

    /**
        @dev adminPause set pause flag.
    */
    function adminPause() external onlyOwner() whenNotPaused() {
        paused = true;
    }

    /**
        @dev adminUnpause release pause flag.
    */
    function adminUnpause() public onlyOwner() whenPaused() {
        paused = false;
    }
}
