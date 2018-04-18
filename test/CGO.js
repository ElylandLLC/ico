'use strict';

const CGO = artifacts.require("./CgoTestToken.sol");

contract('CGO', function (accounts) {
    let instance;
    beforeEach(async function () {
        instance = await CGO.new();
    });

    const COIN = 1e18;

    const MINT_CAP = 2100000 * COIN;
    const TOTAL_SUPPLY = 17900000 * COIN;
    const HALF_MINT_PERIOD = 60 * 60 * 24 * 365 * 4;
    const DECIMALS = 18;

    it("initial setup check", async function () {
        assert.equal(TOTAL_SUPPLY, (await instance.balanceOf(accounts[0])).valueOf(), "first account balance check");
        assert.equal(TOTAL_SUPPLY, (await instance.totalSupply()).valueOf(), "total supply check");
        assert.equal(DECIMALS, (await instance.decimals()).valueOf(), "decimals check");
        assert.equal(MINT_CAP, (await instance.mintCap()).valueOf(), "mintCap check");
        assert.equal(HALF_MINT_PERIOD, (await instance.halfMintPeriod()).valueOf(), "halfMintPeriod check");
        assert.equal(accounts[0], (await instance.owner()).valueOf(), "owner check");
    });

    it("mint check", async function () {
        let start = Number((await instance.fakeNow()).valueOf());

        assert.equal(0, (await instance.mintReceiver()).valueOf(), "initial mintReceiver check");
        assert.equal(0, (await instance.mintAmount()).valueOf(), "initial mintAmount check");

        await instance.setMintManager(accounts[0]);
        await instance.setMintReceiver(accounts[1]);

        assert.equal(accounts[1], (await instance.mintReceiver()).valueOf(), "mintReceiver is set");
        assert.equal(0, (await instance.mintAmount()).valueOf(), "mintAmount before timeJump check");

        await instance.setBlockTime(start + HALF_MINT_PERIOD);

        assert.equal(MINT_CAP / 2, (await instance.mintAmount()).valueOf(), "mintAmount after timeJump check");
        assert.equal(0, (await instance.balanceOf(accounts[1])).valueOf(), "balance before mint");

        let result = await instance.mint();

        assert.equal(MINT_CAP / 2, (await instance.balanceOf(accounts[1])).valueOf(), "balance after mint");
        assert.equal(0, (await instance.mintAmount()).valueOf(), "mintAmount after mint");

        expect.web3Events(result, [
            {
                event: 'Mint',
                args: {
                    to: accounts[1],
                    amount: Number(MINT_CAP / 2)
                }
            },
            {
                event: 'Transfer',
                args: {
                    from: "0x0000000000000000000000000000000000000000",
                    to: accounts[1],
                    value: Number(MINT_CAP / 2)
                }
            },
        ], 'Events are emitted');
    });

});
