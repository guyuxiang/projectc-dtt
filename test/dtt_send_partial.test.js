const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  sc,
  cf,
  cs,
  signMintPermit,
  signPermit,
  parseEvent,
} = require('./helpers/projectContracts')

describe('DTT Send And Partial Accept Methods', function () {
  it('should send and partial-accept by condition', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)

    const mintSig = await signMintPermit(erc20, issuer, alice.address, 5000, 'MINT_4')
    await erc20.connect(issuer).mint(alice.address, 5000, 'MINT_4', mintSig)

    const now = await time.latest()
    const start = now - 3600
    const end = now + 3600

    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'At date [Date]', [
        cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'A1.4:v2', 'Transferer accepts the payment at date [Date]', [
        cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('ACCEPT', '', false, true, alice.address, start, end, '', [])]),
    ]
    const css = [cs('CS1', ['SC1'], [], 0)]

    const deadline = now + 7200
    const permit = await signPermit(erc20, alice, await diamond.getAddress(), 1000, deadline)

    const sendTx = await dttSend.connect(alice).sendRealisedToken(
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
      deadline,
      1000,
      '',
      permit.v,
      permit.r,
      permit.s
    )

    const businessId = (await parseEvent(await sendTx.wait(), dttSend.interface, 'CreateTrade')).args.businessId
    await dttSend.connect(alice).conditionPartialAccept(businessId, 400, 400, 'comments', [])
  })
})
