pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

/**
 * @title Contract that handles incoming token transfers
 */
interface TokenReceiver {
    /**
     * @dev function to handle incoming token transfers.
     *
     * @param _from  Token sender address.
     * @param _value Amount of tokens.
     */
    function tokensReceived(address _from, uint _value, bool _autoForward) external;
}

contract GoToken is StandardToken, Ownable {
    using SafeMath for uint256;

    enum AddressType {DEFAULT, RECEIVER_CONTRACT, AUTO_FORWARD}

    address public autoForwardReceiver;

    address public contractManager;

    mapping (address => AddressType) public addressTypes;

    event SetupAutoForward(address address_);

    event PayOnBehalf(address indexed sender, address indexed from, address indexed to, uint256 amount);

    modifier only(address address_) {
        require(msg.sender == address_);
        _;
    }

    /**
     * @dev update contract manager, account for registering contracts
     */
    function setContractManager(address _manager) onlyOwner public {
        contractManager = _manager;
    }

    /**
     * @dev register receiver contract
     */
    function registerReceiverContract(address _receiver) only(contractManager) public {
        require(addressTypes[_receiver] == AddressType.DEFAULT);

        addressTypes[_receiver] = AddressType.RECEIVER_CONTRACT;
    }

    /**
     * @dev unregister receiver contract
     */
    function unregisterReceiverContract(address _receiver) onlyOwner public {
        require(addressTypes[_receiver] == AddressType.RECEIVER_CONTRACT);

        addressTypes[_receiver] = AddressType.DEFAULT;
    }

    /**
     * @dev transfer token
     */
    function doTransfer(address _from, address _to, uint256 _value) private {
        balances[_from] = balances[_from].sub(_value);
        emit Transfer(_from, _to, _value);

        AddressType addressType = addressTypes[_to];
        if (addressType == AddressType.AUTO_FORWARD) {
            balances[autoForwardReceiver] = balances[autoForwardReceiver].add(_value);
            emit Transfer(_to, autoForwardReceiver, _value);
        } else {
            balances[_to] = balances[_to].add(_value);
            if (addressType == AddressType.RECEIVER_CONTRACT) {
                TokenReceiver(_to).tokensReceived(_from, _value, false);
            }
        }
    }

    /**
     * @dev override ERC20.transferFrom with tokensReceived call
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
     * @dev override ERC20.transfer with tokensReceived call
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        doTransfer(msg.sender, _to, _value);

        return true;
    }

    /**
     * @dev update auto-forward receiver - account to forward tokens from auto-forward accounts
     */
    function setAutoForwardReceiver(address _receiver) onlyOwner public {
        autoForwardReceiver = _receiver;
    }

    /**
     * @dev set address type to AddressType.AUTO_FORWARD
     * @dev and send account balance to autoForwardReceiver
     *
     * _v, _r, _s - sign of message {msg.sender, _to} with _from key
     *
     */
    function setupAutoForward(address _address, uint8 _v, bytes32 _r, bytes32 _s) public {
        require(addressTypes[_address] == AddressType.DEFAULT);
        require(_address == ecrecover(keccak256(abi.encodePacked("setup forward", this)), _v, _r, _s));

        addressTypes[_address] = AddressType.AUTO_FORWARD;

        address _from = _address;
        address _to = autoForwardReceiver;
        uint256 _value = balances[_from];

        balances[_from] = 0;
        balances[_to] = balances[_to].add(_value);
        emit Transfer(_from, _to, _value);

        emit SetupAutoForward(_address);
    }

    /**
     * @dev pay tokens to contract on behalf of given address
     */
    function payToContractOnBehalf(address _address, address _contract, uint256 _value) public returns (bool) {
        require(_address != address(0));
        require(addressTypes[_contract] == AddressType.RECEIVER_CONTRACT);
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_contract] = balances[_contract].add(_value);

        emit Transfer(msg.sender, _contract, _value);
        emit PayOnBehalf(msg.sender, _address, _contract, _value);

        TokenReceiver(_contract).tokensReceived(_address, _value, addressTypes[_address] == AddressType.AUTO_FORWARD);

        return true;
    }


}