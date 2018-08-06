pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title Standard ERC20 token with limited minting
 */
contract HalfMintableToken is StandardToken, Ownable {
    using SafeMath for uint256;

    uint256 public mintCap;
    uint256 public halfMintPeriod;

    address public mintReceiver;
    uint256 public mintStartTime;
    uint256 public lastMintSeconds;

    address public mintManager;

    event Mint(address indexed to, uint256 amount);

    constructor(uint256 _mintCap, uint256 _halfMintPeriod) public {
        require(_halfMintPeriod > 0);
        mintCap = _mintCap;
        halfMintPeriod = _halfMintPeriod;
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
    function mint() public {
        require(msg.sender == mintManager);
        require(mintStartTime > 0);
        require(timeNow() > mintStartTime + lastMintSeconds);
        uint256 amount = mintAmount();
        if (amount > 0) {
            lastMintSeconds = timeNow().sub(mintStartTime);
            totalSupply_ = totalSupply_.add(amount);
            balances[mintReceiver] = balances[mintReceiver].add(amount);
            emit Mint(mintReceiver, amount);
            emit Transfer(address(0), mintReceiver, amount);
        }
    }

}
