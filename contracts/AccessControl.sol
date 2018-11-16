pragma solidity ^0.4.24;


contract AccessControl {

    address internal owner;

    bool public paused = false;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    function adminSetOwner(address _newOwner) external onlyOwner() {
        require(_newOwner != address(0));

        owner = _newOwner;
    }

    function adminPause() external onlyOwner() whenNotPaused() {
        paused = true;
    }

    function adminUnpause() public onlyOwner() whenPaused() {
        paused = false;
    }
}
