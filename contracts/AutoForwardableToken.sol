pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title Standard ERC20 token with auto-forwarding option
 */
contract AutoForwardableToken is StandardToken {
    using SafeMath for uint256;

    mapping (address => address) public autoForward;

    event SetupAutoForward(address address_, address receiver_);

    /**
     * @dev transfer token with autoForward handler
     */
    function doTransfer(address _from, address _to, uint256 _value) private {
        balances[_from] = balances[_from].sub(_value);

        address from = _from;
        address to = _to;
        do {
            emit Transfer(from, to, _value);
            from = to;
            to = autoForward[to];
        } while (to != address(0));

        balances[from] = balances[from].add(_value);
    }

    /**
     * @dev override ERC20.transferFrom with autoForward handler
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        doTransfer(_from, _to, _value);

        return true;
    }

    /**
     * @dev override ERC20.transfer with with autoForward handler
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        doTransfer(msg.sender, _to, _value);

        return true;
    }

    /**
     * @dev setup auto-forward address
     * @dev and send _address balance to _receiver
     *
     * _address - address to setup auto forward from
     * _receiver - receiver of auto-forwarded tokens
     * _v, _r, _s - sign of message {msg.sender, _to} with _from key
     *
     */
    function setupAutoForward(address _address, address _receiver, uint8 _v, bytes32 _r, bytes32 _s) public {
        require(_address == ecrecover(keccak256(abi.encodePacked("setup forward", this, _receiver)), _v, _r, _s));

        autoForward[_address] = _receiver;

        if (_receiver != address(0)) {
            address _from = _address;
            address _to = _receiver;
            uint256 _value = balances[_from];

            if (_value > 0) {
                balances[_from] = 0;
                balances[_to] = balances[_to].add(_value);
                emit Transfer(_from, _to, _value);
            }
        }

        emit SetupAutoForward(_address, _receiver);
    }

}
