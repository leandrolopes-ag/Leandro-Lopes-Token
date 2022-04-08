const { accounts, contract } = require('@openzeppelin/test-environment');

const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const { ZERO_ADDRESS } = constants;

const { toWei } = require('web3-utils');

const Token = contract.fromArtifact('LLT');

describe('Non-ERC20 Token functions', function () {
    const [owner, minter, recipient, anotherAccount] = accounts;

    const name = 'LeandroLopes';
    const symbol = 'LLT';
    const supply = toWei('100000', 'ether');

    const sto = new BN(100);
    const ten = new BN(10);

    before(async function () {
        this.token = await Token.new(name, symbol, '1', supply, { from: owner });
    });

    describe('Approve/allowance', function () {
        it('Set allowance', async function () {
            await this.token.transfer(recipient, sto, { from: owner })
            expectEvent(await this.token.approve(minter, sto, { from: recipient }),
                'Approval', {
                owner: recipient,
                spender: minter,
                value: sto,
            })
        })
        it('Use transferFrom', async function () {
            let ret = await this.token.transferFrom(recipient, anotherAccount, ten, { from: minter });
            expectEvent(ret,
                'Transfer', {
                from: recipient,
                to: anotherAccount,
                value: ten,
            })
        })
        it('Use burnFrom', async function () {
            ret = await this.token.burnFrom(recipient, ten, { from: minter })
            expectEvent(ret, "Transfer", {
                from: recipient,
                to: ZERO_ADDRESS,
                value: ten,
            })
        })
        it('Throw when try more than allowace', async function () {
            await expectRevert(this.token.transferFrom(recipient, minter, sto, { from: minter })
                , "Allowance to low")
            await expectRevert(this.token.burnFrom(recipient, sto, { from: minter })
                , "Allowance to low")
        })
        it('Throw when no allowance', async function () {
            await expectRevert(this.token.transferFrom(minter, recipient, sto, { from: recipient })
                , "Allowance to low")
            await expectRevert(this.token.burnFrom(minter, sto, { from: recipient })
                , "Allowance to low")
        })
    })
});
