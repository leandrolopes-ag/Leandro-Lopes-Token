const { accounts, contract } = require('@openzeppelin/test-environment');

const {
    BN,           // Big Number support
    expectEvent,  // Assertions for emitted events
} = require('@openzeppelin/test-helpers');

const { expect } = require('chai');

const basicErc20 = contract.fromArtifact('LLT');

describe('ERC20-test', function () {
    const [owner, user1, user2, user3] = accounts;

    const name = 'LenardoLopes';
    const symbol = 'LLT';

    const tentho = new BN(10000);
    const sto = new BN(100);
    const ten = new BN(10);
    const one = new BN(1)

    let token;

    before(async function () {
        token = await basicErc20.new(name, symbol, '1', tentho, { from: owner });
    });

    it('has a name', async function () {
        expect(await token.name()).to.equal(name);
    });

    it('has a symbol', async function () {
        expect(await token.symbol()).to.equal(symbol);
    });

    it('has 18 decimals', async function () {
        expect(await token.decimals()).to.be.bignumber.equal(new BN(18));
    });

    it('has initial balance', async function () {
        expect(await token.totalSupply()).to.be.bignumber.equal(tentho);
    });

    describe('Transfer', function () {
        it('can transfer', async function () {
            ret = await token.transfer(user1, sto, { from: owner });
            expectEvent(ret, 'Transfer', {
                from: owner,
                to: user1,
                value: sto
            })
        })
    })

    describe('Approve/allowance', function () {
        it('Set allowance', async function () {
            expectEvent(await token.approve(user2, ten, { from: user1 }),
                'Approval', {
                owner: user1,
                spender: user2,
                value: ten,
            })
        })
        it('Use TransferFrom', async function () {
            ret = await token.transferFrom(user1, user3, one, { from: user2 });
            expectEvent(ret,
                'Transfer', {
                from: user1,
                to: user3,
                value: one,
            })
        })
    })

});
