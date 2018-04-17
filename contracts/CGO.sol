pragma solidity ^0.4.18;

import './GoToken.sol';

contract CGO is GoToken {
    string public name = "Clash & GO Token";
    string public symbol = "CGO";
    uint8 public decimals = 18;

    function CGO() GoToken(
        17900000 ether,
        2100000 ether,
        60 * 60 * 24 * 365 * 4 // 4 year
    ) public { }
}
