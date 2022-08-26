const { accounts, contract } = require('@openzeppelin/test-environment');

const {
    BN,           // Big Number support
    constants,
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
    time   // for blockchain timestamp manipulations
} = require('@openzeppelin/test-helpers');

const { ZERO_ADDRESS, MAX_UINT256 } = constants;
const { toWei } = require('web3-utils');

const { expect } = require('chai');

const Erc20 = contract.fromArtifact('LLT');
const Vesting = contract.fromArtifact("Vesting");

let day = Number(time.duration.days(1))
let week = Number(time.duration.days(7))

let one = toWei('1', 'ether');
let two = toWei('2', 'ether');
let ten = toWei('10', 'ether');
let sto = toWei('100', 'ether');
let tho = toWei('1000', 'ether');
let zero = new BN('0')

describe('ClaimFor/ClaimOne checks', function () {
    const [owner, user1, user2, user3, user4, user5, payer] = accounts;

    let token;
    let vesting;
    let startTime;

    before(async function () {
        token = await Erc20.new("name", "symbol", "1", tho, { from: owner });
        vesting = await Vesting.new(token.address, { from: owner })

        startTime = Number(await time.latest())
        await token.approve(vesting.address, sto, { from: owner })
        const la = [user2, user2, user2, user3, user3, user3, user5]
        const sa = [0, 0, 0, 0, 0, 0, 0]
        const ta = [toWei('1', 'ether'), toWei('0.8', 'ether'), toWei('0.5', 'ether')
            , toWei('0.5', 'ether'), toWei('0.5', 'ether'), toWei('0.5', 'ether'), toWei('1', 'ether')]
        const sd = [String(startTime + day), String(startTime + (day * 10)), String(startTime + (day * 30))
            , String(startTime + day), String(startTime + (day * 20)), String(startTime + (day * 60)), String(startTime + (day * 60))]
        const ed = [String(startTime + (day * 10)), String(startTime + (day * 30)), String(startTime + (day * 130))
            , String(startTime + (day * 20)), String(startTime + (day * 60)), String(startTime + (day * 140)), String(startTime + (day * 140))]

        await vesting.massCreateVest(la, sd, ed, sa, ta, { from: owner })
    });

    it('Throws when nothing to claim', async function () {
        // no vestings
        await expectRevert(vesting.claimOneFor(user1, '0', { from: payer }), "Index out of bounds")
        // vesting index too high
        await expectRevert(vesting.claimOneFor(user2, '3', { from: payer }), "Index out of bounds")
        // nothing to claim yet
        await expectRevert(vesting.claimOneFor(user2, '0', { from: payer }), "Nothing to claim")
        // no vestings
        await expectRevert(vesting.claimFor(user1, { from: payer }), "No locks for user")
        // nothing to claim yet
        await expectRevert(vesting.claimFor(user2, { from: payer }), "Nothing to claim")
    })
    it('Can claim one vesting', async function () {
        // go to end of all vestings
        time.increaseTo(startTime + day * 365)
        const ret = await vesting.claimOneFor(user2, '1', { from: payer })
        expectEvent(ret, 'Claimed', {
            user: user2,
            amount: toWei('0.8', 'ether')
        })
    })
    it('Can claim for someone', async function () {
        const ret = await vesting.claimFor(user3, { from: payer })
        expectEvent(ret, 'Claimed', {
            user: user3,
            amount: toWei('1.5', 'ether')
        })
    })
})
