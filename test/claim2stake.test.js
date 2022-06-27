const { accounts, contract } = require('@openzeppelin/test-environment');

const {
    BN,           // Big Number support
    constants,
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
    time,   // for blockchain timestamp manipulations
} = require('@openzeppelin/test-helpers');

const { MAX_UINT256 } = constants;
const { toWei } = require('web3-utils');

const { expect } = require('chai');

const Erc20 = contract.fromArtifact('LLT');
const Vesting = contract.fromArtifact("Vesting");
const Stake = contract.fromArtifact("Stake");

const day = Number(time.duration.days(1))
const week = Number(time.duration.days(7))

const one = toWei('1', 'ether');
const two = toWei('2', 'ether');
const ten = toWei('10', 'ether');
const sto = toWei('100', 'ether');
const tho = toWei('1000', 'ether');
const zero = new BN('0')

describe('claim2stake test', function () {
    const [owner, user1] = accounts;

    const name = 'Lopes';
    const symbol = 'LOPES';

    let token;
    let vesting;
    let stake;

    before(async function () {
        token = await Erc20.new(name, symbol, "1", tho, { from: owner });
        vesting = await Vesting.new(token.address, { from: owner })
        stake = await Stake.new(token.address, vesting.address, { from: owner })
    });

    describe('deploy configure/check', function () {
        it('throw when non-owner configure', async function () {
            await expectRevert(vesting.setStakeAddress(stake.address, { from: user1 })
                , "Only for Owner")
        })
        it('configures correctly', async function () {
            expect(await stake.tokenAddress()).to.eql(token.address);
            expect(await stake.vestingAddress()).to.eql(vesting.address);
            await vesting.setStakeAddress(stake.address, { from: owner });
            expect(await vesting.stakeAddress()).to.eql(stake.address);
            expect(await token.allowance(vesting.address, stake.address)).to.be.bignumber.eq(MAX_UINT256)
        })
    })
    describe('claim2stake check', function () {
        it('throws when no stakes', async function () {
            await expectRevert(vesting.claim2stake(0, { from: user1 })
                , "No locks")
        })
        it('stakes correctly', async function () {
            // create vest
            await token.approve(vesting.address, sto, { from: owner })
            startTime = Number(await time.latest())
            await vesting.createVest(user1, startTime + day, startTime + week, zero, two, { from: owner });

            // create stake pool
            await token.approve(stake.address, MAX_UINT256, { from: owner })
            await stake.addStakePool(
                one, two, startTime + day, startTime + week, 10, week, ten
                , { from: owner });

            // advance blockchain
            await time.increaseTo(startTime + (day * 4))
            // claim2stake
            let ret = await vesting.claim2stake(0, { from: user1 })
            expectEvent(ret, "Claimed", {
                user: user1,
                amount: toWei('1', 'ether') // 3/6 days from 2 tokens
            })
            // check balance => 1+1% reward
            expect(await stake.totalStakedTokens()).to.be.bignumber.eq(toWei('1.01', 'ether'))
        })
    })
})
