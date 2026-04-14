const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  sc,
  cf,
  cs,
  parseEvent,
} = require('./helpers/projectContracts')

async function sendWithConditions ({
  diamond,
  erc20,
  sender,
  receiver,
  amount,
  scs,
  css = [],
  timeScId = 'SC0',
  csId = '',
  partialAcceptEnable = false,
  partialAcceptAddress = ethers.ZeroAddress,
  partialAcceptScId = '',
}) {
  const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
  const now = await time.latest()
  const tx = await dttSend.connect(sender).sendRealisedToken(
    receiver.address,
    await erc20.getAddress(),
    amount,
    scs,
    css,
    timeScId,
    csId,
    partialAcceptEnable,
    partialAcceptAddress,
    partialAcceptScId,
    now + 3600,
    0,
    '',
    0,
    ethers.ZeroHash,
    ethers.ZeroHash,
  )
  const receipt = await tx.wait()
  return (await parseEvent(receipt, dttSend.interface, 'CreateTrade')).args.businessId
}

describe('DTT Condition Diversity Branch Tests', function () {
  it('should cover T1/T2/T3/T4 status branches in querySCStatus', async function () {
    const { diamond, erc20, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const start = now - 3600
    const end = now + 3600
    const condCalc = await ethers.getContractAt('ConditionCalculateFacet', await diamond.getAddress())

    const scs = [
      sc('SC0', 'T4:v2', 'time window', [
        cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'T1', 'date not set', [
        cf('X', '1', false, false, ethers.ZeroAddress, 0, 0),
      ], [
        cf('DATE', '', false, false, ethers.ZeroAddress, 0, 0),
      ]),
      sc('SC2', 'T2', 'already expired', [
        cf('DATE', String(now - 3 * 86400), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC3', 'T3', 'met today', [
        cf('DATE', String(now - 30), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC4', 'T4', 'future start', [
        cf('DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const businessId = await sendWithConditions({
      diamond,
      erc20,
      sender: alice,
      receiver: bob,
      amount: 100,
      scs,
      timeScId: 'SC0',
    })

    expect(await condCalc.querySCStatus(`${businessId}_SC1`)).to.equal(2n) // RightNowNotMet
    expect(await condCalc.querySCStatus(`${businessId}_SC2`)).to.equal(3n) // NotMet
    expect(await condCalc.querySCStatus(`${businessId}_SC3`)).to.equal(1n) // RightNowMet
    expect(await condCalc.querySCStatus(`${businessId}_SC4`)).to.equal(2n) // RightNowNotMet
  })

  it('should cover A1/A3 status branches in querySCStatus', async function () {
    const { diamond, erc20, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const condCalc = await ethers.getContractAt('ConditionCalculateFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'time window', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'A1.4:v2', 'accept future chance', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('ACCEPT', '', false, true, alice.address, now - 10, now + 1800, '', [])]),
      sc('SC2', 'A1.4:v2', 'accepted', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('ACCEPT', 'ACCEPT', true, false, alice.address, now - 3600, now + 3600, '', [])]),
      sc('SC3', 'A3.4:v2', 'reject future chance', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('REJECT', '', false, true, alice.address, now - 10, now + 1800, '', [])]),
    ]

    const businessId = await sendWithConditions({
      diamond,
      erc20,
      sender: alice,
      receiver: bob,
      amount: 100,
      scs,
      timeScId: 'SC0',
    })

    expect(await condCalc.querySCStatus(`${businessId}_SC1`)).to.equal(2n) // RightNowNotMet
    expect(await condCalc.querySCStatus(`${businessId}_SC2`)).to.equal(0n) // Met
    expect(await condCalc.querySCStatus(`${businessId}_SC3`)).to.equal(1n) // RightNowMet
  })

  it('should cover invalid factorFutureChangeChance path for A3/A4', async function () {
    const { diamond, erc20, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const condCalc = await ethers.getContractAt('ConditionCalculateFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'time window', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'A3.4:v2', 'invalid future-change branch', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('REJECT', '', false, false, alice.address, 0, 0, '', [])]),
    ]

    const businessId = await sendWithConditions({
      diamond,
      erc20,
      sender: alice,
      receiver: bob,
      amount: 100,
      scs,
      timeScId: 'SC0',
    })

    await expect(condCalc.querySCStatus(`${businessId}_SC1`)).to.be.revertedWith('SCM_CDN_07_01')
  })

  it('should cover nested OR/AND condition set merge branches', async function () {
    const { diamond, erc20, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const condCalc = await ethers.getContractAt('ConditionCalculateFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'time window', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'T2', 'not met', [
        cf('DATE', String(now - 3 * 86400), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC2', 'T3', 'right now met', [
        cf('DATE', String(now - 30), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC3', 'A1.4:v2', 'met', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('ACCEPT', 'ACCEPT', true, false, alice.address, now - 3600, now + 3600, '', [])]),
    ]
    const css = [
      cs('CS1', ['SC1', 'SC2'], [], 1), // OR => RightNowMet
      cs('CS2', ['SC1', 'SC3'], [], 0), // AND => NotMet
      cs('CS3', [], ['CS1', 'CS2'], 1), // OR => RightNowMet
    ]

    const businessId = await sendWithConditions({
      diamond,
      erc20,
      sender: alice,
      receiver: bob,
      amount: 100,
      scs,
      css,
      timeScId: 'SC0',
    })

    expect(await condCalc.queryCSStatus(`${businessId}_CS1`)).to.equal(1n)
    expect(await condCalc.queryCSStatus(`${businessId}_CS2`)).to.equal(3n)
    expect(await condCalc.queryCSStatus(`${businessId}_CS3`)).to.equal(1n)
  })

  it('should cover partial-accept condition validation error branch', async function () {
    const { diamond, erc20, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const verifyFacet = await ethers.getContractAt('VerifyFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'time window', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'T3', 'not action type', [
        cf('DATE', String(now - 10), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    await expect(
      verifyFacet.connect(alice).verifySendRealisedToken(
        bob.address,
        await erc20.getAddress(),
        100,
        scs,
        [],
        'SC0',
        '',
        true,
        alice.address,
        'SC1',
        now + 3600,
        0,
        '',
        0,
        ethers.ZeroHash,
        ethers.ZeroHash,
      )
    ).to.be.revertedWith('SCM_CDN_13_03')
  })

  it('should revert querySCStatus/queryCSStatus for invalid ids', async function () {
    const { diamond } = await loadFixture(deployFixture)
    const condCalc = await ethers.getContractAt('ConditionCalculateFacet', await diamond.getAddress())
    await expect(condCalc.querySCStatus('NO_SC')).to.be.revertedWith('SCM_CDN_05_01')
    await expect(condCalc.queryCSStatus('NO_CS')).to.be.revertedWith('SCM_CDN_04_01')
  })

  it('should cover conditionPartialAccept sender and amount guards', async function () {
    const { diamond, erc20, alice, bob, carol } = await loadFixture(deployFixture)
    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'At date [Date]', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'A1.4:v2', 'Transferer accepts payment', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('ACCEPT', '', false, true, alice.address, now - 10, now + 3600, '', [])]),
    ]
    const css = [cs('CS1', ['SC1'], [], 0)]

    const tx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      1000,
      scs,
      css,
      'SC0',
      'CS1',
      true,
      alice.address,
      'SC1',
      now + 3600,
      0,
      '',
      0,
      ethers.ZeroHash,
      ethers.ZeroHash,
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId

    await expect(
      dttSend.connect(carol).conditionPartialAccept(businessId, 100, 0, '', [])
    ).to.be.revertedWith('SCM_DTT_05_01')

    await expect(
      dttSend.connect(alice).conditionPartialAccept(businessId, 0, 0, '', [])
    ).to.be.revertedWith('SCM_DTT_05_03')
  })

  it('should revert conditionPartialAccept when partial-accept is disabled', async function () {
    const { diamond, erc20, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'At date [Date]', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 3600), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const tx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      100,
      scs,
      [],
      'SC0',
      '',
      false,
      alice.address,
      '',
      now + 3600,
      0,
      '',
      0,
      ethers.ZeroHash,
      ethers.ZeroHash,
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId
    await expect(
      dttSend.connect(alice).conditionPartialAccept(businessId, 10, 0, '', [])
    ).to.be.revertedWith('SCM_DTT_05_02')
  })

  it('should cover SendFacet bytes32ToString non-empty branch', async function () {
    const { diamond } = await loadFixture(deployFixture)
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const v = await dttSend.bytes32ToString(ethers.encodeBytes32String('ABC'))
    expect(v).to.equal('ABC')
  })
})
