const { expect } = require('chai')
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
const { deployFixture } = require('./helpers/projectContracts')

describe('UserPermission Methods', function () {
  it('should set and query permission', async function () {
    const { userPermission, issuer, alice } = await loadFixture(deployFixture)
    await userPermission.connect(issuer).setPermission(issuer.address, alice.address, 9999999, 'set')
    const perm = await userPermission.getPermission(issuer.address, alice.address)
    expect(perm).to.equal(9999999)
  })
})
