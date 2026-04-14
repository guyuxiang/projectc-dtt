const { expect } = require('chai')
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
const { deployFixture, signMintPermit } = require('./helpers/projectContracts')

describe('DTTERC20 Methods', function () {
  it('should mint, transfer and burn', async function () {
    const { erc20, issuer, alice, bob } = await loadFixture(deployFixture)

    const mintTxId = 'MINT_1'
    const mintAmount = 1000
    const mintSig = await signMintPermit(erc20, issuer, alice.address, mintAmount, mintTxId)
    await erc20.connect(issuer).mint(alice.address, mintAmount, mintTxId, mintSig)

    await erc20.connect(alice).transfer(bob.address, 200)
    await erc20.connect(bob).burn(50, 'BURN_1')

    expect(await erc20.balanceOf(bob.address)).to.equal(150)
  })
})
