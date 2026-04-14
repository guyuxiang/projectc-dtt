const { expect } = require('chai')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  signMintPermit,
  signPermit,
  parseEvent,
} = require('./helpers/projectContracts')

describe('Encash Methods', function () {
  it('should encash then accept and reject', async function () {
    const { erc20, encash, issuer, alice } = await loadFixture(deployFixture)

    const mintSig = await signMintPermit(erc20, issuer, alice.address, 2000, 'MINT_2')
    await erc20.connect(issuer).mint(alice.address, 2000, 'MINT_2', mintSig)

    const deadline = (await time.latest()) + 3600

    const permit1 = await signPermit(erc20, alice, await encash.getAddress(), 500, deadline)
    const encashTx = await encash.connect(alice).encash(
      await erc20.getAddress(),
      500,
      deadline,
      permit1.v,
      permit1.r,
      permit1.s,
      'ext'
    )
    const receipt1 = await encashTx.wait()
    const ev1 = await parseEvent(receipt1, encash.interface, 'EncashEvent')
    await encash.connect(issuer).accept(ev1.args.businessId, 'accept')
    expect((await encash.encashInfos(ev1.args.businessId)).state).to.equal('ACCEPT')

    const permit2 = await signPermit(erc20, alice, await encash.getAddress(), 300, deadline)
    const encashTx2 = await encash.connect(alice).encash(
      await erc20.getAddress(),
      300,
      deadline,
      permit2.v,
      permit2.r,
      permit2.s,
      'ext2'
    )
    const receipt2 = await encashTx2.wait()
    const ev2 = await parseEvent(receipt2, encash.interface, 'EncashEvent')
    await encash.connect(issuer).reject(ev2.args.businessId, 'reject')
    expect((await encash.encashInfos(ev2.args.businessId)).state).to.equal('REJECT')
  })
})
