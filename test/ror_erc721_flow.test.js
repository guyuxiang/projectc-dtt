const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const { deployFixture, sc, cf, parseEvent } = require('./helpers/projectContracts')

describe('RORERC721 Methods', function () {
  it('should mint by send flow and transfer nft', async function () {
    const { erc20, diamond, ror, alice, bob } = await loadFixture(deployFixture)

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

    const sendTx = await dttSend.connect(alice).sendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      100,
      scs,
      [],
      'SC0',
      '',
      false,
      ethers.ZeroAddress,
      '',
      0,
      0,
      '',
      0,
      ethers.ZeroHash,
      ethers.ZeroHash
    )

    const receipt = await sendTx.wait()
    const transferEvent = await parseEvent(receipt, ror.interface, 'Transfer')
    const rorId = transferEvent.args.tokenId

    await ror.connect(bob).transferFrom(bob.address, alice.address, rorId)
    expect(await ror.ownerOf(rorId)).to.equal(alice.address)
  })
})
