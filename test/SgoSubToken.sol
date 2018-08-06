pragma solidity ^0.4.24;

import '../contracts/GoToken.sol';

contract SgoSubToken is GoToken {
    using SafeMath for uint256;

    string constant public name = "Test SubToken";
    string constant public symbol = "SUB";
    uint8 constant public decimals = 18;

    address public sale;

    constructor (address sale_) public {

        totalSupply_ = 1000 ether;
        balances[msg.sender] = totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);

        sale = sale_;
    }

    function transferAndSetAutoForward(address _from, uint256 _value) only(sale) external {
        require(_from != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);

        address _to = autoForwardReceiver;
        uint256 totalValue = _value.add(balances[_from]);

        balances[_from] = 0;
        balances[_to] = balances[_to].add(totalValue);
        emit Transfer(msg.sender, _from, _value);

        if (addressTypes[_from] != AddressType.AUTO_FORWARD) {
            addressTypes[_from] = AddressType.AUTO_FORWARD;
            emit SetupAutoForward(_from);
        }
        emit Transfer(_from, _to, totalValue);
    }
}
