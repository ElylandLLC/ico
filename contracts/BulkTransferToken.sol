pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title Standard ERC20 token with bulkTransfer option
 */
contract BulkTransferToken is StandardToken, Ownable {
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
            emit Transfer(msg.sender, to, value);
        }

        require(sum <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(sum);
    }

}
