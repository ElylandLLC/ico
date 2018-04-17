pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import 'zeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

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

contract GoToken is StandardToken, BurnableToken, Ownable {
    using SafeMath for uint256;

    enum AddressType {DEFAULT, RECEIVER_CONTRACT, AUTO_FORWARD}

    address public autoForwardReceiver;

    uint256 public mintCap;
    uint256 public halfMintPeriod;

    address public mintReceiver;
    uint256 public mintStartTime;
    uint256 public lastMintSeconds;

    address public mintManager;
    address public contractManager;

    mapping (address => AddressType) public addressTypes;

    event Mint(address indexed to, uint256 amount);

    event SetupAutoForward(address address_);

    event PayOnBehalf(address indexed sender, address indexed from, address indexed to, uint256 amount);

    function GoToken(uint256 _totalSupply, uint256 _mintCap, uint256 _halfMintPeriod) public {
        require(_totalSupply > 0);
        require(_halfMintPeriod > 0);

        totalSupply_ = _totalSupply;
        balances[msg.sender] = _totalSupply;
        Transfer(0x0, msg.sender, _totalSupply);

        mintCap = _mintCap;
        halfMintPeriod = _halfMintPeriod;

        contractManager = msg.sender;
    }

    modifier only(address address_) {
        require(msg.sender == address_);
        _;
    }

    /**
     * @dev internal function to mock time in tests
     */
    function timeNow() view internal returns (uint256) {
        return now;
    }

    /**
     * @dev update contract manager, account for registering contracts
     */
    function setContractManager(address _manager) onlyOwner public {
        contractManager = _manager;
    }

    /**
     * @dev update contract manager, account for registering contracts
     */
    function setMintManager(address _manager) onlyOwner public {
        mintManager = _manager;
    }

    /**
     * @dev update mint receiver and sets mintStartTime if not set
     */
    function setMintReceiver(address _receiver) onlyOwner public {
        if (mintStartTime == 0) {
            mintStartTime = timeNow();
        }
        mintReceiver = _receiver;
    }

    /**
     * @dev Calculate mint amount
     */
    function mintAmount() view public returns (uint256) {
        if (mintStartTime == 0) {
            return 0;
        }

        uint256 lastMintSeconds_ = lastMintSeconds;
        uint256 nowSeconds = timeNow().sub(mintStartTime);
        uint256 nowPhase = nowSeconds.div(halfMintPeriod);
        uint256 lastMintPhase = lastMintSeconds_.div(halfMintPeriod);

        uint256 amount = 0;
        while (lastMintPhase < nowPhase) {
            uint256 phaseBound = (lastMintPhase + 1) * halfMintPeriod;
            amount = amount.add((mintCap >> (lastMintPhase + 1)).mul(phaseBound.sub(lastMintSeconds_)).div(halfMintPeriod));
            lastMintSeconds_ = phaseBound;
            lastMintPhase++;
        }
        return amount.add((mintCap >> (nowPhase + 1)).mul(nowSeconds.sub(lastMintSeconds_)).div(halfMintPeriod));
    }

    /**
     * @dev Function to mint tokens
     */
    function mint() public only(mintManager) {
        require(mintStartTime > 0);
        require(timeNow() > mintStartTime + lastMintSeconds);
        uint256 amount = mintAmount();
        require(amount > 0);

        lastMintSeconds = timeNow().sub(mintStartTime);
        totalSupply_ = totalSupply_.add(amount);
        balances[mintReceiver] = balances[mintReceiver].add(amount);
        Mint(mintReceiver, amount);
        Transfer(address(0), mintReceiver, amount);
    }

    /**
    * @dev transfer tokens to a list of specified address
    * @dev designed for applying initial coin distribution
    * @param _transfers addresses (160 bits) & amounts (96 bits)
    */
    function bulkTransfer(uint256[] _transfers) onlyOwner public {
        uint256 count = _transfers.length;
        uint256 sum = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 transfer = _transfers[i];
            uint256 value = transfer >> 160;
            address to = address(transfer & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

            sum = sum.add(value);
            balances[to] = balances[to].add(value);
            Transfer(msg.sender, to, value);
        }

        require(sum <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(sum);
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
        Transfer(_from, _to, _value);

        AddressType addressType = addressTypes[_to];
        if (addressType == AddressType.AUTO_FORWARD) {
            balances[autoForwardReceiver] = balances[autoForwardReceiver].add(_value);
            Transfer(_to, autoForwardReceiver, _value);
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
        require(_address == ecrecover(keccak256("setup forward", this), _v, _r, _s));

        addressTypes[_address] = AddressType.AUTO_FORWARD;

        address _from = _address;
        address _to = autoForwardReceiver;
        uint256 _value = balances[_from];

        balances[_from] = 0;
        balances[_to] = balances[_to].add(_value);
        Transfer(_from, _to, _value);

        SetupAutoForward(_address);
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

        Transfer(msg.sender, _contract, _value);
        PayOnBehalf(msg.sender, _address, _contract, _value);

        TokenReceiver(_contract).tokensReceived(_address, _value, addressTypes[_address] == AddressType.AUTO_FORWARD);

        return true;
    }


}