const { expect } = require('chai')
const { ethers, upgrades } = require('hardhat')
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
const { signMintPermit } = require('./helpers/projectContracts')

async function deployYieldStablecoinFixture () {
  const [owner, alice, bob, issuer, oracle, suspense] = await ethers.getSigners()

  const UserPermission = await ethers.getContractFactory('UserPermission')
  const userPermission = await UserPermission.deploy(owner.address, issuer.address, [])

  const Config = await ethers.getContractFactory('Config')
  const config = await Config.deploy(
    await userPermission.getAddress(),
    ethers.ZeroAddress,
    ethers.ZeroAddress,
    ethers.ZeroAddress,
    ethers.ZeroAddress,
    ethers.ZeroAddress,
    ethers.ZeroAddress,
    owner.address
  )

  const YieldStablecoin = await ethers.getContractFactory('YieldStablecoin')
  const token = await upgrades.deployProxy(
    YieldStablecoin,
    ['Yield USD', 'yUSD', oracle.address, 2000],
    { initializer: 'initialize', kind: 'uups' }
  )

  await token.connect(owner).setConfig(await config.getAddress())
  await token.connect(owner).setIssuer(issuer.address)
  await token.connect(owner).setTokenMintLicensor(issuer.address)
  await token.connect(owner).setMintLimit(1_000_000_000)
  await config.connect(owner).setSuspense(await token.getAddress(), suspense.address)

  const ISSUER_ROLE = await userPermission.ISSUER_ROLE()
  await userPermission.connect(owner).grantRoles(ISSUER_ROLE, issuer.address)

  const permissionValue = 9999999
  const permTargets = [
    owner.address,
    alice.address,
    bob.address,
    issuer.address,
    oracle.address,
    suspense.address
  ]

  for (const target of permTargets) {
    await userPermission.connect(issuer).setPermission(issuer.address, target, permissionValue, '')
  }

  return {
    owner,
    alice,
    bob,
    issuer,
    oracle,
    token
  }
}

describe('YieldStablecoin', function () {
  it('rebases balances after oracle submits daily interest', async function () {
    const { token, issuer, alice, bob, oracle } = await loadFixture(deployYieldStablecoinFixture)

    const aliceSig = await signMintPermit(token, issuer, alice.address, 1000, 'MINT_A')
    const bobSig = await signMintPermit(token, issuer, bob.address, 500, 'MINT_B')

    await token.connect(issuer).mint(alice.address, 1000, 'MINT_A', aliceSig)
    await token.connect(issuer).mint(bob.address, 500, 'MINT_B', bobSig)

    await token.connect(oracle).submitDailyInterest(86400, 150, ethers.id('bank-report-1'))

    expect(await token.totalSupply()).to.equal(1650)
    expect(await token.balanceOf(alice.address)).to.equal(1100)
    expect(await token.balanceOf(bob.address)).to.equal(550)
  })

  it('supports transfer after a rebase without breaking accounting', async function () {
    const { token, issuer, alice, bob, oracle } = await loadFixture(deployYieldStablecoinFixture)

    const aliceSig = await signMintPermit(token, issuer, alice.address, 1000, 'MINT_A')
    const bobSig = await signMintPermit(token, issuer, bob.address, 1000, 'MINT_B')

    await token.connect(issuer).mint(alice.address, 1000, 'MINT_A', aliceSig)
    await token.connect(issuer).mint(bob.address, 1000, 'MINT_B', bobSig)
    await token.connect(oracle).submitDailyInterest(86400, 200, ethers.id('bank-report-2'))

    await token.connect(alice).transfer(bob.address, 110)

    expect(await token.balanceOf(alice.address)).to.equal(990)
    expect(await token.balanceOf(bob.address)).to.equal(1210)
    expect(await token.totalSupply()).to.equal(2200)
  })

  it('rejects out-of-sequence oracle business days', async function () {
    const { token, issuer, alice, oracle } = await loadFixture(deployYieldStablecoinFixture)

    const aliceSig = await signMintPermit(token, issuer, alice.address, 1000, 'MINT_A')
    await token.connect(issuer).mint(alice.address, 1000, 'MINT_A', aliceSig)

    await token.connect(oracle).submitDailyInterest(86400, 10, ethers.id('bank-report-3'))

    await expect(
      token.connect(oracle).submitDailyInterest(86400 * 3, 10, ethers.id('bank-report-4'))
    ).to.be.reverted
  })
})
