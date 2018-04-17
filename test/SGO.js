'use strict';

require('chai/register-expect');  // Using Expect style
require('truffle-test-utils').init();

const Account = require("eth-lib/lib/account");
const Hash = require("eth-lib/lib/hash");

const SGO = artifacts.require("./SgoTestToken.sol");
const SgoTestSale = artifacts.require("./SgoTestSale.sol");
const SgoSubToken = artifacts.require("./SgoSubToken.sol");

contract('SGO', function (accounts) {
    let instance;
    beforeEach(function () {
        return SGO.new().then(function (_instance) {
            instance = _instance;
        });
    });

    let expectRevert = async promise => {
        try {
            await promise;
        } catch (error) {
            if (error.message.search('revert') >= 0) {
                return;
            }
        }
        assert.fail(null, null, 'Expected revert not received');
    };

    const COIN = 1e18;

    const MINT_CAP = 21000000 * COIN;
    const TOTAL_SUPPLY = 179000000 * COIN;
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

    it("auto forward check", async function () {
        await instance.setAutoForwardReceiver(accounts[1]);
        assert.equal(accounts[1], (await instance.autoForwardReceiver()).valueOf(), "autoForwardReceiver is set check");

        let fwdAccount = Account.fromPrivate("0x0000000000000000000000000000000000000000000000000000000000000001");
        let fwd = fwdAccount.address.toLowerCase();
        let signData = Buffer.concat([Buffer.from("setup forward"), Buffer.from(instance.address.slice(2), 'hex')]);
        let vrs = Account.decodeSignature(Account.sign(Hash.keccak256s(signData), fwdAccount.privateKey));

        await instance.transfer(fwd, 1000 * COIN);
        assert.equal(1000 * COIN, (await instance.balanceOf(fwd)).valueOf(), "fwd balance before auto forward setup check");
        assert.equal(0, (await instance.balanceOf(accounts[1])).valueOf(), "receiver balance before auto forward setup check");

        let setupResult = await instance.setupAutoForward(fwd, vrs[0], vrs[1], vrs[2]);

        assert.equal(0, (await instance.balanceOf(fwd)).valueOf(), "fwd balance after auto forward setup check");
        assert.equal(1000 * COIN, (await instance.balanceOf(accounts[1])).valueOf(), "receiver balance after auto forward setup check");

        expect.web3Events(setupResult, [
            {
                event: 'Transfer',
                args: {
                    from: fwd,
                    to: accounts[1],
                    value: 1000 * COIN
                }
            },
            {
                event: 'SetupAutoForward',
                args: {
                    address_: fwd,
                }
            },

        ], 'events');

        let transferResult = await instance.transfer(fwd, 42 * COIN);
        assert.equal(0, (await instance.balanceOf(fwd)).valueOf(), "fwd balance after transfer check");
        assert.equal(1042 * COIN, (await instance.balanceOf(accounts[1])).valueOf(), "receiver balance after transfer check");

        expect.web3Events(transferResult, [
            {
                event: 'Transfer',
                args: {
                    from: accounts[0],
                    to: fwd,
                    value: 42 * COIN
                }
            },
            {
                event: 'Transfer',
                args: {
                    from: fwd,
                    to: accounts[1],
                    value: 42 * COIN
                }
            },

        ], 'events are emitted');
    });

    it("sale with transfer check", async function () {
        await instance.registerReceiverContract(accounts[1]);

        // transfer to non-contract should fail
        expectRevert(instance.transfer(accounts[1], COIN));

        let sale = (await SgoTestSale.new(instance.address));
        let sub = (await SgoSubToken.new(sale.address));
        await sale.setToken(sub.address);
        await sub.transfer(sale.address, 1000 * COIN);

        assert.equal(1000 * COIN, (await sub.totalSupply()).valueOf(), "subCoin total supply check");
        assert.equal(1000 * COIN, (await sub.balanceOf(sale.address)).valueOf(), "subCoin sale initial balance check");
        assert.equal(0, (await sub.balanceOf(accounts[0])).valueOf(), "subCoin a0 initial balance check");

        await instance.registerReceiverContract(sale.address);

        let transferResult = await instance.transfer(sale.address, COIN);

        assert.equal(1000 * COIN, (await sub.totalSupply()).valueOf(), "subCoin total supply check");
        assert.equal(990 * COIN, (await sub.balanceOf(sale.address)).valueOf(), "subCoin sale initial balance check");
        assert.equal(10 * COIN, (await sub.balanceOf(accounts[0])).valueOf(), "subCoin a0 balance check");

        expect.web3Events(transferResult, [
            {
                event: 'Transfer',
                args: {
                    from: accounts[0],
                    to: sale.address,
                    value: COIN
                }
            },
            {
                event: 'Transfer',
                args: {
                    from: sale.address,
                    to: accounts[0],
                    value: 10 * COIN
                }
            },
        ], 'events are emitted');
    });

    it("sale with PayOnBehalf check", async function () {
        let sale = (await SgoTestSale.new(instance.address));
        let sub = (await SgoSubToken.new(sale.address));
        await sale.setToken(sub.address);
        await sub.transfer(sale.address, 1000 * COIN);

        assert.equal(1000 * COIN, (await sub.totalSupply()).valueOf(), "subCoin total supply check");
        assert.equal(1000 * COIN, (await sub.balanceOf(sale.address)).valueOf(), "subCoin sale initial balance check");
        assert.equal(0, (await sub.balanceOf(accounts[0])).valueOf(), "subCoin a0 initial balance check");

        // attempt to pay before contract is registered
        expectRevert(instance.payToContractOnBehalf(accounts[1], sale.address, 2 * COIN));

        await instance.registerReceiverContract(sale.address);

        let payResult = await instance.payToContractOnBehalf(accounts[1], sale.address, 2 * COIN);

        assert.equal(1000 * COIN, (await sub.totalSupply()).valueOf(), "subCoin total supply check");
        assert.equal(980 * COIN, (await sub.balanceOf(sale.address)).valueOf(), "subCoin sale balance check");
        assert.equal(20 * COIN, (await sub.balanceOf(accounts[1])).valueOf(), "subCoin a1 balance check");

        expect.web3Events(payResult, [
            {
                event: 'Transfer',
                args: {
                    from: accounts[0],
                    to: sale.address,
                    value: 2 * COIN
                }
            },
            {
                event: 'PayOnBehalf',
                args: {
                    sender: accounts[0],
                    from: accounts[1],
                    to: sale.address,
                    amount: 2 * COIN
                }
            },
            {
                event: 'Transfer',
                args: {
                    from: sale.address,
                    to: accounts[1],
                    value: 20 * COIN
                }
            },
        ], 'events are emitted');
    });

    it("payOnBehalf with auto forward check", async function () {
        let sale = (await SgoTestSale.new(instance.address));
        let sub = (await SgoSubToken.new(sale.address));
        await sale.setToken(sub.address);
        await sub.transfer(sale.address, 1000 * COIN);

        assert.equal(1000 * COIN, (await sub.totalSupply()).valueOf(), "subCoin total supply check");
        assert.equal(1000 * COIN, (await sub.balanceOf(sale.address)).valueOf(), "subCoin sale initial balance check");
        assert.equal(0, (await sub.balanceOf(accounts[0])).valueOf(), "subCoin a0 initial balance check");
        assert.equal(0, (await sub.balanceOf(accounts[1])).valueOf(), "subCoin a1 initial balance check");

        await instance.registerReceiverContract(sale.address);

        let fwdAccount = Account.fromPrivate("0x0000000000000000000000000000000000000000000000000000000000000001");
        let fwd = fwdAccount.address.toLowerCase();
        let signData = Buffer.concat([Buffer.from("setup forward"), Buffer.from(instance.address.slice(2), 'hex')]);
        let vrs = Account.decodeSignature(Account.sign(Hash.keccak256s(signData), fwdAccount.privateKey));

        await instance.setupAutoForward(fwd, vrs[0], vrs[1], vrs[2]);
        await instance.setAutoForwardReceiver(accounts[1]);
        await sub.setAutoForwardReceiver(accounts[1]);

        let result = await instance.payToContractOnBehalf(fwd, sale.address, 2 * COIN);

        assert.equal(980 * COIN, (await sub.balanceOf(sale.address)).valueOf(), "subCoin sale balance check");
        assert.equal(0, (await sub.balanceOf(fwd)).valueOf(), "subCoin fwd balance check");
        assert.equal(0, (await sub.balanceOf(accounts[0])).valueOf(), "subCoin a0 balance check");
        assert.equal(20 * COIN, (await sub.balanceOf(accounts[1])).valueOf(), "subCoin a1 balance check");

        expect.web3Events(result, [
            {
                event: 'Transfer',
                args: {
                    from: accounts[0],
                    to: sale.address,
                    value: 2 * COIN
                }
            },
            {
                event: 'PayOnBehalf',
                args: {
                    sender: accounts[0],
                    from: fwd,
                    to: sale.address,
                    amount: 2 * COIN
                }
            },
            {
                event: 'Transfer',
                args: {
                    from: sale.address,
                    to: fwd,
                    value: 20 * COIN
                }
            },
            {
                event: 'SetupAutoForward',
                args: {
                    address_: fwd,
                }
            },
            {
                event: 'Transfer',
                args: {
                    from: fwd,
                    to: accounts[1],
                    value: 20 * COIN
                }
            },

        ], 'events are emitted');
    });


});
