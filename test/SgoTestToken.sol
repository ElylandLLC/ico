pragma solidity ^0.4.18;

import '../contracts/SGO.sol';

contract SgoTestToken is SGO {
    uint256 public fakeNow = now;

    function setBlockTime(uint val) public {
        fakeNow = val;
    }

    function timeNow() view internal returns (uint256) {
        return fakeNow;
    }

}
