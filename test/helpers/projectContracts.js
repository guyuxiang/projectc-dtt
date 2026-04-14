const { ethers, upgrades } = require('hardhat')
const { time } = require('@nomicfoundation/hardhat-network-helpers')

function getSelectors (contract) {
  const selectors = []
  for (const fragment of contract.interface.fragments) {
    if (fragment.type !== 'function') continue
    if (fragment.name === 'init') continue
    selectors.push(contract.interface.getFunction(fragment.format()).selector)
  }
  return selectors
}

function cf (name, value, changeFlag, changeAble, changeAddr, beginTime, endTime, commentsHash = '', filesHash = []) {
  return [name, value, changeFlag, changeAble, changeAddr, beginTime, endTime, commentsHash, filesHash]
}

function sc (id, conditionType, description, fixFactors, dynamicFactors) {
  return [id, conditionType, description, fixFactors, dynamicFactors]
}

function cs (id, scIDs, csIDs, join) {
  return [id, scIDs, csIDs, join]
}

async function signPermit (token, owner, spender, value, deadline) {
  const nonce = await token.nonces(owner.address)
  const chainId = (await ethers.provider.getNetwork()).chainId
  const domain = {
    name: await token.name(),
    version: '1',
    chainId,
    verifyingContract: await token.getAddress(),
  }
  const types = {
    Permit: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  }
  const signature = await owner.signTypedData(domain, types, {
    owner: owner.address,
    spender,
    value,
    nonce,
    deadline,
  })
  const sig = ethers.Signature.from(signature)
  return { v: sig.v, r: sig.r, s: sig.s }
}

async function signMintPermit (token, licensor, to, amount, bid) {
  const chainId = (await ethers.provider.getNetwork()).chainId
  const domain = {
    name: await token.name(),
    version: '1',
    chainId,
    verifyingContract: await token.getAddress(),
  }
  const types = {
    MintPermit: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'bid', type: 'string' },
    ],
  }
  return licensor.signTypedData(domain, types, { to, amount, bid })
}

async function signRorPermit (ror, owner, spender, tokenId, deadline) {
  const chainId = (await ethers.provider.getNetwork()).chainId
  const domain = {
    name: await ror.name(),
    version: '1',
    chainId,
    verifyingContract: await ror.getAddress(),
  }
  const types = {
    Permit: [
      { name: 'spender', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  }
  const nonce = await ror.nonces(tokenId)
  const signature = await owner.signTypedData(domain, types, {
    spender,
    tokenId,
    nonce,
    deadline,
  })
  const sig = ethers.Signature.from(signature)
  return { v: sig.v, r: sig.r, s: sig.s }
}

async function parseEvent (receipt, iface, eventName) {
  for (const log of receipt.logs) {
    try {
      const parsed = iface.parseLog(log)
      if (parsed.name === eventName) {
        return parsed
      }
    } catch (err) {
      // ignore
    }
  }
  throw new Error(`Event ${eventName} not found`)
}

async function deployFixture () {
  const [owner, alice, bob, carol, issuer, suspense] = await ethers.getSigners()

  const TransactionIDFactory = await ethers.getContractFactory('TransactionIDFactory')
  const idFactory = await upgrades.deployProxy(TransactionIDFactory, [], {
    initializer: 'initialize',
    kind: 'uups',
  })

  const Encash = await ethers.getContractFactory('Encash')
  const encash = await upgrades.deployProxy(Encash, [await idFactory.getAddress()], {
    initializer: 'initialize',
    kind: 'uups',
  })

  const DTTERC20 = await ethers.getContractFactory('DTTERC20')
  const erc20 = await upgrades.deployProxy(DTTERC20, ['LDA', 'LDA'], {
    initializer: 'initialize',
    kind: 'uups',
  })

  const RORERC721 = await ethers.getContractFactory('RORERC721')
  const ror = await upgrades.deployProxy(RORERC721, ['ROR', 'ROR', '1'], {
    initializer: 'initialize',
    kind: 'uups',
  })

  const RorEnhancement = await ethers.getContractFactory('RorEnhancement')
  const rorEnhancement = await upgrades.deployProxy(RorEnhancement, [await ror.getAddress()], {
    initializer: 'initialize',
    kind: 'uups',
  })

  const RorMarket = await ethers.getContractFactory('RorMarket')
  const rorMarket = await upgrades.deployProxy(
    RorMarket,
    [await idFactory.getAddress(), await rorEnhancement.getAddress(), await ror.getAddress()],
    { initializer: 'initialize', kind: 'uups' }
  )

  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
  const diamondCutFacet = await DiamondCutFacet.deploy()
  await diamondCutFacet.waitForDeployment()

  const DigitalTokenTradeDiamond = await ethers.getContractFactory('DigitalTokenTradeDiamond')
  const diamond = await DigitalTokenTradeDiamond.deploy(owner.address, await diamondCutFacet.getAddress())
  await diamond.waitForDeployment()

  const facetNames = [
    'DiamondLoupeFacet',
    'ConditionActionFacet',
    'ConditionCalculateFacet',
    'ConditionCreateFacet',
    'SendFacet',
    'SettleFacet',
    'TradeStatusFacet',
    'VerifyFacet',
  ]

  const cut = []
  for (const name of facetNames) {
    const Facet = await ethers.getContractFactory(name)
    const facet = await Facet.deploy()
    await facet.waitForDeployment()
    cut.push({
      facetAddress: await facet.getAddress(),
      action: 0,
      functionSelectors: getSelectors(facet),
    })
  }

  const diamondCut = await ethers.getContractAt('IDiamondCut', await diamond.getAddress())
  const cutTx = await diamondCut.diamondCut(cut, ethers.ZeroAddress, '0x')
  await cutTx.wait()

  const UserPermission = await ethers.getContractFactory('UserPermission')
  const userPermission = await UserPermission.deploy(owner.address, issuer.address, [
    await encash.getAddress(),
    await diamond.getAddress(),
    suspense.address,
    await rorMarket.getAddress(),
    await rorEnhancement.getAddress(),
  ])

  const Config = await ethers.getContractFactory('Config')
  const config = await Config.deploy(
    await userPermission.getAddress(),
    await diamond.getAddress(),
    await encash.getAddress(),
    await rorEnhancement.getAddress(),
    await rorMarket.getAddress(),
    await ror.getAddress(),
    await idFactory.getAddress(),
    owner.address
  )

  await erc20.connect(owner).setConfig(await config.getAddress())
  await encash.connect(owner).setConfig(await config.getAddress())
  await ror.connect(owner).setConfig(await config.getAddress())
  await rorEnhancement.connect(owner).setConfig(await config.getAddress())
  await rorMarket.connect(owner).setConfig(await config.getAddress())
  await idFactory.connect(owner).setConfig(await config.getAddress())

  const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
  await dttSend.connect(owner).setConfig(await config.getAddress())

  await erc20.connect(owner).setIssuer(issuer.address)
  await ror.connect(owner).setIssuer(issuer.address)
  await erc20.connect(owner).setTokenMintLicensor(issuer.address)
  await erc20.connect(owner).setMintLimit(1_000_000_000)
  await config.connect(owner).setSuspense(await erc20.getAddress(), suspense.address)

  const ISSUER_ROLE = await userPermission.ISSUER_ROLE()
  await userPermission.connect(owner).grantRoles(ISSUER_ROLE, issuer.address)

  const permissionValue = 9999999
  const permTargets = [
    owner.address,
    alice.address,
    bob.address,
    carol.address,
    suspense.address,
    await encash.getAddress(),
    await diamond.getAddress(),
    await rorMarket.getAddress(),
    await rorEnhancement.getAddress(),
  ]

  for (const target of permTargets) {
    await userPermission.connect(issuer).setPermission(issuer.address, target, permissionValue, '')
  }

  return {
    owner,
    alice,
    bob,
    carol,
    issuer,
    suspense,
    idFactory,
    encash,
    erc20,
    ror,
    rorEnhancement,
    rorMarket,
    diamond,
    userPermission,
    config,
  }
}

async function mintWithPermit (erc20, issuer, to, amount, txId) {
  const mintSig = await signMintPermit(erc20, issuer, to.address, amount, txId)
  await erc20.connect(issuer).mint(to.address, amount, txId, mintSig)
}

async function createAcceptPendingTrade ({ erc20, diamond, sender, receiver, amount }) {
  const now = await time.latest()
  const start = now - 3600
  const end = now + 3600
  const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
  const permit = await signPermit(erc20, sender, await diamond.getAddress(), amount, now + 7200)
  const scs = [
    sc('SC0', 'T4:v2', 'At date [Date]', [
      cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
      cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
    ], []),
    sc('SC1', 'A1.4:v2', 'Transferer accepts the payment at date [Date]', [
      cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
      cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
    ], [cf('ACCEPT', '', false, true, sender.address, start, end, '', [])]),
  ]
  const css = [cs('CS1', ['SC1'], [], 0)]
  const tx = await dttSend.connect(sender).sendRealisedToken(
    receiver.address,
    await erc20.getAddress(),
    amount,
    scs,
    css,
    'SC0',
    'CS1',
    false,
    ethers.ZeroAddress,
    '',
    now + 7200,
    amount,
    '',
    permit.v,
    permit.r,
    permit.s
  )
  const receipt = await tx.wait()
  const ev = await parseEvent(receipt, dttSend.interface, 'CreateTrade')
  return { businessId: ev.args.businessId, dttSend }
}

module.exports = {
  cf,
  sc,
  cs,
  parseEvent,
  signPermit,
  signMintPermit,
  signRorPermit,
  deployFixture,
  mintWithPermit,
  createAcceptPendingTrade,
}
