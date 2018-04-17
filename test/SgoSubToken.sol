pragma solidity ^0.4.18;

import '../contracts/GoToken.sol';

contract SgoSubToken is GoToken {
    using SafeMath for uint256;

    string constant public name = "Test SubToken";
    string constant public symbol = "SUB";
    uint8 constant public decimals = 18;

    address public sale;

    function SgoSubToken(address sale_) GoToken (
        1000 ether,
        0,
        1
    ) public {
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
        Transfer(msg.sender, _from, _value);

        if (addressTypes[_from] != AddressType.AUTO_FORWARD) {
            addressTypes[_from] = AddressType.AUTO_FORWARD;
            SetupAutoForward(_from);
        }
        Transfer(_from, _to, totalValue);
    }
}
