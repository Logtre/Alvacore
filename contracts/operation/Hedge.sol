pragma solidity ^0.4.24;

import "../FwdCont.sol";
import "../fees/Fees.sol";
import "../math/SafeMath.sol";

/**
    @dev Hedge defines operation function and variable for Hedge.
*/
contract Hedge is FwdCont, Fees {
    using SafeMath for uint256;

    event HedgeFwd(
        uint256 fwdId,
        uint256 hedgeAmt,
        bytes32 hedgeState
    );

    event ConfirmHedge(
        uint256 fwdId,
        uint256 hedgeAmt,
        bytes32 hedgeState
    );

    event CancelHedge(
        uint256 fwdId,
        uint256 amount,
        bytes32 hedgeState
    );

    event DeleteHedge(
        uint256 fwdId
    );

    event ReplenishFwd(
        uint256 fwdId,
        uint256 replenishAmount,
        bytes32 hedgeState
    );

    /**
        @dev    create hedge
                premise: setting deposit asset is done
        @param  _fwdId  fwd id
    */
    function _setHedge(uint256 _fwdId) internal {
        // set fwdIndexToHedgeState as 'pending'
        _setHedgeState(_fwdId, 1);
        // set fwdHedges as fwdDeposit
        fwdHedges[_fwdId] = fwdDeposits[_fwdId];
        // emit event
        emit HedgeFwd(_fwdId, fwdHedges[_fwdId], fwdIndexToHedgeState[_fwdId]);
    }

    /**
        @dev    confirm hedge
                premise: after the settlementDay
        @param  _fwdId      fwd id
        @param  _hedgeAmt   confirmed hedge amount
    */
    function _confirmHedge(uint256 _fwdId, uint256 _hedgeAmt) internal {
        // confirm wether today is after settlementDay
        _availSettlement(_fwdId);
        // set fwdIndexToHedgeState as 'confirm'
        _setHedgeState(_fwdId, 2);
        // set fwdHedges as specific amount
        fwdHedges[_fwdId] = _hedgeAmt;
        // emit event
        emit ConfirmHedge(_fwdId, _hedgeAmt, fwdIndexToHedgeState[_fwdId]);
    }

    /**
        @dev    refund hedged asset to alva
        @param  _fwdId  fwd id
    */
    function _cancelHedge(uint256 _fwdId) internal {
        // set hedgeState as 'canceled'
        _setHedgeState(_fwdId, 4);
        // escape hedged amount to another struct with minus fee
        uint256 targetHedge = fwdHedges[_fwdId].sub(processFee);
        // escape hedgeState to temp valiable
        bytes32 hs = fwdIndexToHedgeState[_fwdId];
        // delete hedge
        _deleteHedge(_fwdId);
        // emit event
        emit CancelHedge(_fwdId, targetHedge, hs);
    }

    /**
        @dev    replenish hedged amount to deposit assets.
        @param  _fwdId  fwd id
    */
    function _replenishHedge(uint256 _fwdId) internal {
        // replenish
        fwdDeposits[_fwdId] = fwdDeposits[_fwdId].add(fwdHedges[_fwdId]);
        // update hedgeState as 'conplete'
        _setHedgeState(_fwdId, 3);
        // escape hedgeState to temp valiable
        bytes32 hs = fwdIndexToHedgeState[_fwdId];
        // delete storage
        _deleteHedge(_fwdId);
        // emit event
        emit ReplenishFwd(_fwdId, fwdDeposits[_fwdId], hs);
    }

    /**
        @dev    delete hedge assets linked specified fwdId
        @param  _fwdId  fwd id
    */
    function _deleteHedge(uint256 _fwdId) internal {
        // delete hedges
        delete fwdIndexToHedgeState[_fwdId];
        delete fwdHedges[_fwdId];
        // emit event
        emit DeleteHedge(_fwdId);
    }
}
