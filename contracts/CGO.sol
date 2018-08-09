pragma solidity ^0.4.24;

import './HalfMintableToken.sol';
import './BulkTransferToken.sol';
import "./AutoForwardableToken.sol";
import 'openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';

contract CGO is AutoForwardableToken, HalfMintableToken, BulkTransferToken, BurnableToken {
    string public name = "Clash & GO Token";
    string public symbol = "CGO";
    uint8 public decimals = 18;

    constructor() HalfMintableToken(
        2100000 ether,
        4 * 365 days
    ) public {
        totalSupply_ = 17900000 ether;
        balances[msg.sender] = totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);
    }
}
