pragma solidity ^0.4.18;

import "truffle/Assert.sol";
import "./SgoTestToken.sol";

contract SgoTokenTest {

    function testEmission() public {
        SgoTestToken token = new SgoTestToken();

        Assert.equal(token.totalSupply(), 179000000 ether, "totalSupply is 179000000 Coin initially");
        Assert.equal(token.balanceOf(this), 179000000 ether, "Owner should have 179000000 Coin initially");

        Assert.equal(token.mintAmount(), 0, "initial mintAmount should be 0");

        token.setBlockTime(now);
        Assert.equal(token.mintAmount(), 0, "mintAmount should be 0 (receiver is not set)");
        token.setMintReceiver(address(1));
        Assert.equal(token.mintAmount(), 0, "mintAmount for 0 sec");
        token.setBlockTime(now + 1);
        Assert.equal(token.mintAmount(), token.mintCap() / 2 / token.halfMintPeriod(), "mintAmount for 1 sec");

        token.setBlockTime(now + token.halfMintPeriod());
        Assert.equal(token.mintAmount(), token.mintCap() / 2, "mintAmount for 4 yr");

        token.setBlockTime(now + token.halfMintPeriod() * 2);
        Assert.equal(token.mintAmount(), token.mintCap() * 3 / 4, "mintAmount for 8 yr");

        token.setBlockTime(now + token.halfMintPeriod() * 3);
        Assert.equal(token.mintAmount(), token.mintCap() * 7 / 8, "mintAmount for 16 yr");
    }

}
