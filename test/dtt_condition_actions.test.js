const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  sc,
  cf,
  cs,
  signPermit,
  parseEvent,
  mintWithPermit,
  createAcceptPendingTrade,
} = require('./helpers/projectContracts')

describe('DTT Condition Action Methods', function () {
  it('should conditionAccept then settle', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 2000, 'MINT_CA_1')

    const { businessId, dttSend } = await createAcceptPendingTrade({
      erc20,
      diamond,
      sender: alice,
      receiver: bob,
      amount: 800,
    })

    const dttAction = await ethers.getContractAt('ConditionActionFacet', await diamond.getAddress())
    await dttAction.connect(alice).conditionAccept(businessId, `${businessId}_SC1`, 'accept', [])

    expect(await erc20.balanceOf(bob.address)).to.equal(800)
    const pendingRefIds = await dttSend.getPendingRefIds()
    expect(pendingRefIds).to.not.include(businessId)
  })

  it('should conditionReject and refund to sender', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1500, 'MINT_CR_1')

    const now = await time.latest()
    const timeStart = now + 3600
    const timeEnd = now + 7200
    const actionStart = now - 10
    const actionEnd = now + 3600
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())

    const scs = [
      sc('SC0', 'T4:v2', 'future time', [
        cf('END_DATE', String(timeEnd), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(timeStart), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'A3.4:v2', 'reject by sender', [
        cf('END_DATE', String(actionEnd), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(actionStart), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('REJECT', '', false, true, alice.address, actionStart, actionEnd, '', [])]),
    ]

    const css = [cs('CS1', ['SC1'], [], 0)]
    const permit = await signPermit(erc20, alice, await diamond.getAddress(), 500, now + 7200)

    const tx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      500,
      scs,
      css,
      'SC0',
      'CS1',
      false,
      ethers.ZeroAddress,
      '',
      now + 7200,
      500,
      '',
      permit.v,
      permit.r,
      permit.s
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId

    const dttAction = await ethers.getContractAt('ConditionActionFacet', await diamond.getAddress())
    await dttAction.connect(alice).conditionReject(businessId, `${businessId}_SC1`, 'reject', [])

    expect(await erc20.balanceOf(alice.address)).to.equal(1500)
    expect(await erc20.balanceOf(bob.address)).to.equal(0)
  })

  it('should conditionSetDate and settle', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1200, 'MINT_CSD_1')

    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T1', 'set date later', [cf('X', '0', false, false, ethers.ZeroAddress, 0, 0)], [
        cf('DATE', '', false, true, alice.address, 0, 253402243200, '', []),
      ]),
    ]

    const permit = await signPermit(erc20, alice, await diamond.getAddress(), 300, now + 7200)
    const tx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      300,
      scs,
      [],
      'SC0',
      '',
      false,
      ethers.ZeroAddress,
      '',
      now + 7200,
      300,
      '',
      permit.v,
      permit.r,
      permit.s
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId

    const dttAction = await ethers.getContractAt('ConditionActionFacet', await diamond.getAddress())
    await dttAction.connect(alice).conditionSetDate(businessId, `${businessId}_SC0`, String(now), 'set-date', [])

    expect(await erc20.balanceOf(bob.address)).to.equal(300)
  })

  it('should reject cross-trade scId pollution', async function () {
    const { erc20, diamond, issuer, alice, bob, carol } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 4000, 'MINT_CA_X1')

    const { businessId: businessIdA } = await createAcceptPendingTrade({
      erc20,
      diamond,
      sender: alice,
      receiver: bob,
      amount: 700,
    })
    const { businessId: businessIdB } = await createAcceptPendingTrade({
      erc20,
      diamond,
      sender: alice,
      receiver: carol,
      amount: 600,
    })

    const dttAction = await ethers.getContractAt('ConditionActionFacet', await diamond.getAddress())
    await expect(
      dttAction.connect(alice).conditionAccept(businessIdA, `${businessIdB}_SC1`, 'cross-trade', [])
    ).to.be.revertedWith('SCM_DTT_03_03')
  })
})
