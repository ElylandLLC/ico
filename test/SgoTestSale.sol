pragma solidity ^0.4.18;

import './SgoSubToken.sol';

contract SgoTestSale is TokenReceiver, Ownable {

    GoToken public mainToken;
    SgoSubToken public token;

    function SgoTestSale(GoToken mainToken_) public {
        mainToken = mainToken_;
    }

    function setToken(SgoSubToken token_) onlyOwner public {
        token = token_;
    }

    function tokensReceived(address _from, uint _value, bool _autoForward) external {
        require(msg.sender == address(mainToken));

        uint256 subValue = _value * 10;
        if (_autoForward) {
            token.transferAndSetAutoForward(_from, subValue);
        } else {
            token.transfer(_from, subValue);
        }
    }
}
