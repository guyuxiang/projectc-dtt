const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  sc,
  cf,
  signMintPermit,
  signPermit,
  parseEvent,
  mintWithPermit,
} = require('./helpers/projectContracts')

describe('DTT Settle Methods', function () {
  it('should settle trade after time condition met', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)

    const mintSig = await signMintPermit(erc20, issuer, alice.address, 5000, 'MINT_5')
    await erc20.connect(issuer).mint(alice.address, 5000, 'MINT_5', mintSig)

    const now = await time.latest()
    const start = now + 3600
    const end = start + 3600
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'At date [Date]', [
        cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const deadline = now + 7200
    const permit = await signPermit(erc20, alice, await diamond.getAddress(), 1000, deadline)

    const sendTx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      1000,
      scs,
      [],
      'SC0',
      '',
      false,
      ethers.ZeroAddress,
      '',
      deadline,
      1000,
      '',
      permit.v,
      permit.r,
      permit.s
    )

    const businessId = (await parseEvent(await sendTx.wait(), dttSend.interface, 'CreateTrade')).args.businessId
    await time.increase(4000)

    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())
    await dttSettle.connect(alice).settleTrade(businessId)

    expect(await erc20.balanceOf(bob.address)).to.equal(1000)
  })

  it('should settleTradeWithAmount from wait status', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 3000, 'MINT_SW_1')

    const now = await time.latest()
    const start = now - 10
    const end = now + 3600
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())

    const scs = [
      sc('SC0', 'T4:v2', 'realised now', [
        cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const sendPermit = await signPermit(erc20, alice, await diamond.getAddress(), 400, now + 7200)
    const sendTx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      1000,
      scs,
      [],
      'SC0',
      '',
      false,
      ethers.ZeroAddress,
      '',
      now + 7200,
      400,
      '',
      sendPermit.v,
      sendPermit.r,
      sendPermit.s
    )

    const businessId = (await parseEvent(await sendTx.wait(), dttSend.interface, 'CreateTrade')).args.businessId
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())

    const settlePermit = await signPermit(erc20, alice, await diamond.getAddress(), 600, now + 7200)
    await dttSettle.connect(alice).settleTradeWithAmount(
      businessId,
      await erc20.getAddress(),
      600,
      now + 7200,
      settlePermit.v,
      settlePermit.r,
      settlePermit.s
    )

    expect(await erc20.balanceOf(bob.address)).to.equal(1000)
  })
})
