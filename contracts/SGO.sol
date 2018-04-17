pragma solidity ^0.4.18;

import './GoToken.sol';

contract SGO is GoToken {
    string public name = "Selfie GO Token";
    string public symbol = "SGO";
    uint8 public decimals = 18;

    function SGO() GoToken(
        179000000 ether,
        21000000 ether,
        60 * 60 * 24 * 365 * 4 // 4 year
    ) public { }
}
