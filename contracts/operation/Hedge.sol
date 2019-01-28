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
        bytes32 hedgeState,
        bytes32 hedgeSign
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
        fwdHedges[_fwdId] = 0;
        // emit event
        emit HedgeFwd(_fwdId, fwdHedges[_fwdId], fwdIndexToHedgeState[_fwdId]);
    }

    /**
        @dev    confirm hedge
                premise: after the settlementDay
        @param  _fwdId      fwd id
        @param  _hedgeAmt   confirmed hedge amount
    */
    function _confirmHedge(uint256 _fwdId, uint256 _hedgeAmt, uint256 _signIndex) internal {
        // confirm wether today is after settlementDay
        _availSettlement(_fwdId);
        // set fwdIndexToHedgeState as 'confirm'
        _setHedgeState(_fwdId, 2);
        // set fwdIndexToHedgeSign as 'positive' or 'negative'
        _setHedgeSign(_fwdId, _signIndex);
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
        if (fwdIndexToHedgeSign[_fwdId] == hedgeSign[1]) { // hedge amount is positive
            // replenish
            fwdDeposits[_fwdId] = fwdDeposits[_fwdId].add(fwdHedges[_fwdId]);
        } else if (fwdIndexToHedgeSign[_fwdId] == hedgeSign[2]) { // hedge amount is negative
            // replenish
            fwdDeposits[_fwdId] = fwdDeposits[_fwdId].sub(fwdHedges[_fwdId]);
        }

        // replenish
        //fwdDeposits[_fwdId] = fwdDeposits[_fwdId].add(fwdHedges[_fwdId]);
        // update hedgeState as 'conplete'
        _setHedgeState(_fwdId, 3);
        // escape hedgeState to temp valiable
        bytes32 state = fwdIndexToHedgeState[_fwdId];
        // escape hedgeSign to temp valiable
        bytes32 sign = fwdIndexToHedgeSign[_fwdId];
        // delete storage
        //_deleteHedge(_fwdId);
        // emit event
        emit ReplenishFwd(_fwdId, fwdDeposits[_fwdId], state, sign);
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
