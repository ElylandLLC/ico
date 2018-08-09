pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title Standard ERC20 token with auto-forwarding option
 */
contract AutoForwardableToken is StandardToken {
    using SafeMath for uint256;

    mapping (address => address) public autoForward;

    event SetupAutoForward(address address_, address oldReceiver_, address newReceiver_);

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
     * _v, _r, _s - sign of message {msg.sender, _to} with current _receiver (or _address if none) key
     *
     */
    function setupAutoForward(address _address, address _receiver, uint8 _v, bytes32 _r, bytes32 _s) public {
        address sigAddress = ecrecover(keccak256(abi.encodePacked("setup forward", this, _address, _receiver)), _v, _r, _s);
        address checkAddress = autoForward[_address];
        if (checkAddress == address(0)) {
            checkAddress = _address;
        }

        require(checkAddress == sigAddress);

        autoForward[_address] = _receiver;

        emit SetupAutoForward(_address, checkAddress, _receiver);
        if (_receiver != address(0)) {
            // transfer even if balance == 0 to enforce no-cycles
            doTransfer(_address, _receiver, balances[_address]);
        }
    }

}
