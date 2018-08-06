pragma solidity ^0.4.24;

import './GoToken.sol';
import './HalfMintableToken.sol';
import './BulkTransferToken.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';

contract SGO is GoToken, HalfMintableToken, BulkTransferToken, BurnableToken {
    string public name = "Selfie GO Token";
    string public symbol = "SGO";
    uint8 public decimals = 18;

    constructor() HalfMintableToken(
        21000000 ether,
        4 * 365 days
    ) public {
        totalSupply_ = 179000000 ether;
        balances[msg.sender] = totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);
    }
}
