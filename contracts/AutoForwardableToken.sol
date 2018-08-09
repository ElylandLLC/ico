pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title Standard ERC20 token with auto-forwarding option
 * @dev Current owner of address may transfer ownership by setting up auto forward
 * @dev current balance and all future transfers to address will be forwarded to new owner
 *
 * @dev AutoForward may be set either set by current owner directly (@see setupAutoForward) or by passing
 * @dev signed by owner of keccak256("setup forward", _tokenAddress, _address, _newOwner) (@see setupAutoForwardVRS)
 */
contract AutoForwardableToken is StandardToken {
    using SafeMath for uint256;

    mapping (address => address) public autoForward;

    event SetupAutoForward(address address_, address oldOwner_, address newOwner_);

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
     * @dev return real owner of address
     */
    function ownerOf(address _address, address _currentOwner) view public returns (address) {
        while (_currentOwner != address(0)) {
            _address = _currentOwner;
            _currentOwner = autoForward[_address];
        }
        return _address;
    }

    /**
     * @dev setup auto-forward address
     * @dev and send _address balance to _receiver
     *
     * _address - address to setup auto forward from
     * _receiver - receiver of auto-forwarded tokens
     *
     */
    function doSetupAutoForward(address _sender, address _address, address _receiver) private {
        address currentOwner = autoForward[_address];
        require(_sender == ownerOf(_address, currentOwner));

        autoForward[_address] = _receiver;
        emit SetupAutoForward(_address, currentOwner, _receiver);
        if (_receiver != address(0)) {
            // transfer even if balance == 0 to enforce no-cycles
            doTransfer(_address, _receiver, balances[_address]);
        }
    }

    /**
     * @dev setup auto-forward address
     * @dev and send _address balance to _receiver
     *
     * _address - address to setup auto forward from
     * _receiver - receiver of auto-forwarded tokens
     *
     */
    function setupAutoForward(address _address, address _receiver) public {
        doSetupAutoForward(msg.sender, _address, _receiver);
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
    function setupAutoForwardVRS(address _address, address _receiver, uint8 _v, bytes32 _r, bytes32 _s) public {
        doSetupAutoForward(ecrecover(keccak256(abi.encodePacked("setup forward", this, _address, _receiver)), _v, _r, _s), _address, _receiver);
    }

}
