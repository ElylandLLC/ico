pragma solidity ^0.4.24;

import '../contracts/CGO.sol';

contract CgoTestToken is CGO {
    uint256 public fakeNow = now;

    function setBlockTime(uint val) public {
        fakeNow = val;
    }

    function timeNow() view internal returns (uint256) {
        return fakeNow;
    }

}
