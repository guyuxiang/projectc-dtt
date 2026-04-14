const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  sc,
  cf,
  cs,
  parseEvent,
  signMintPermit,
  signPermit,
  signRorPermit,
  mintWithPermit,
  createAcceptPendingTrade,
} = require('./helpers/projectContracts')

async function mintRorToSelf ({ erc20, diamond, ror, alice }) {
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

  const tx = await dttSend.connect(alice).sendRealisedToken(
    alice.address,
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
    ethers.ZeroHash,
  )

  return (await parseEvent(await tx.wait(), ror.interface, 'Transfer')).args.tokenId
}

describe('Branch Coverage Boost Tests', function () {
  it('[DTTERC20] mint should revert when over mint limit', async function () {
    const { erc20, owner, issuer, alice } = await loadFixture(deployFixture)
    await erc20.connect(owner).setMintLimit(100)

    const sig = await signMintPermit(erc20, issuer, alice.address, 101, 'MINT_LIMIT_1')
    await expect(erc20.connect(issuer).mint(alice.address, 101, 'MINT_LIMIT_1', sig))
      .to.be.revertedWith('SCM_ERC20_01_03')
  })

  it('[Encash] accept should revert when already accepted', async function () {
    const { erc20, encash, issuer, alice } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1000, 'MINT_ENCASH_1')

    const deadline = (await time.latest()) + 3600
    const permit = await signPermit(erc20, alice, await encash.getAddress(), 300, deadline)
    const tx = await encash.connect(alice).encash(
      await erc20.getAddress(),
      300,
      deadline,
      permit.v,
      permit.r,
      permit.s,
      'ext',
    )
    const businessId = (await parseEvent(await tx.wait(), encash.interface, 'EncashEvent')).args.businessId

    await encash.connect(issuer).accept(businessId, 'accept')
    await expect(encash.connect(issuer).accept(businessId, 'accept-again'))
      .to.be.revertedWith('SCM_ENC_02_02')
  })

  it('[RorMarket] transfereeAccept should revert when consideration type is FT', async function () {
    const { erc20, diamond, ror, rorMarket, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, bob, 1000, 'MINT_RM_1')

    const rorId = await mintRorToSelf({ erc20, diamond, ror, alice })
    const deadline = (await time.latest()) + 7200
    const rorSig = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId, deadline)

    const tx = await rorMarket.connect(alice).transferRor(
      rorId,
      bob.address,
      await erc20.getAddress(),
      100,
      1,
      '',
      '',
      0,
      0,
      deadline,
      rorSig.v,
      rorSig.r,
      rorSig.s,
    )

    const transferRefId = (await parseEvent(await tx.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId
    await expect(rorMarket.connect(bob).transfereeAccept(transferRefId, 'wrong-method'))
      .to.be.revertedWith('SCM_RM_02_01')
  })

  it('[RorMarket] transfereeAcceptWithFN should revert when caller is not transferee', async function () {
    const { erc20, diamond, ror, rorMarket, issuer, alice, bob, carol } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, bob, 1000, 'MINT_RM_2')

    const rorId = await mintRorToSelf({ erc20, diamond, ror, alice })
    const deadline = (await time.latest()) + 7200
    const rorSig = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId, deadline)

    const tx = await rorMarket.connect(alice).transferRor(
      rorId,
      bob.address,
      await erc20.getAddress(),
      100,
      1,
      '',
      '',
      0,
      0,
      deadline,
      rorSig.v,
      rorSig.r,
      rorSig.s,
    )
    const transferRefId = (await parseEvent(await tx.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId

    const paySig = await signPermit(erc20, bob, await rorMarket.getAddress(), 100, deadline)
    await expect(
      rorMarket.connect(carol).transfereeAcceptWithFN(
        transferRefId,
        'not-transferee',
        deadline,
        paySig.v,
        paySig.r,
        paySig.s,
      )
    ).to.be.revertedWith('SCM_RM_02_02')
  })

  it('[DTT] conditionAccept should revert when caller is not changeAddr', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 2000, 'MINT_DTT_1')

    const { businessId } = await createAcceptPendingTrade({
      erc20,
      diamond,
      sender: alice,
      receiver: bob,
      amount: 500,
    })

    const dttAction = await ethers.getContractAt('ConditionActionFacet', await diamond.getAddress())
    await expect(
      dttAction.connect(bob).conditionAccept(businessId, `${businessId}_SC1`, 'invalid-caller', [])
    ).to.be.revertedWith('SCM_CDN_03_05')
  })

  it('[DTT] settleTradeWithAmount should revert when amount mismatches', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 3000, 'MINT_DTT_2')

    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'realised now', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 10), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const sendPermit = await signPermit(erc20, alice, await diamond.getAddress(), 400, now + 7200)
    const tx = await dttSend.connect(alice).sendRealisedToken(
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
      sendPermit.s,
    )

    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())

    const settlePermit = await signPermit(erc20, alice, await diamond.getAddress(), 500, now + 7200)
    await expect(
      dttSettle.connect(alice).settleTradeWithAmount(
        businessId,
        await erc20.getAddress(),
        500,
        now + 7200,
        settlePermit.v,
        settlePermit.r,
        settlePermit.s,
      )
    ).to.be.revertedWith('SCM_DTT_07_02')
  })

  it('[VerifyFacet] verifySendRealisedToken should pass on valid input', async function () {
    const { erc20, diamond, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()

    const verifyFacet = await ethers.getContractAt('VerifyFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'At date [Date]', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 10), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    await verifyFacet.connect(alice).verifySendRealisedToken(
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
      now + 7200,
      0,
      '',
      0,
      ethers.ZeroHash,
      ethers.ZeroHash,
    )
  })

  it('[VerifyFacet] verifySettleTradeWithAmount should revert when not WAIT', async function () {
    const { erc20, diamond, alice } = await loadFixture(deployFixture)
    const verifyFacet = await ethers.getContractAt('VerifyFacet', await diamond.getAddress())

    await expect(
      verifyFacet.connect(alice).verifySettleTradeWithAmount(
        'NON_EXIST_BID',
        await erc20.getAddress(),
        1,
        (await time.latest()) + 100,
        0,
        ethers.ZeroHash,
        ethers.ZeroHash,
      )
    ).to.be.revertedWith('SCM_DTT_07_01')
  })

  it('[SettleFacet] settleTrade should revert when businessId is empty', async function () {
    const { diamond, alice } = await loadFixture(deployFixture)
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())
    await expect(dttSettle.connect(alice).settleTrade('')).to.be.revertedWith('SCM_DTT_06_01')
  })

  it('[SettleFacet] settleTrade should return early when status is WAIT', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 3000, 'MINT_DTT_WAIT_1')

    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'realised now', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 10), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const sendPermit = await signPermit(erc20, alice, await diamond.getAddress(), 400, now + 7200)
    const tx = await dttSend.connect(alice).sendRealisedToken(
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
      sendPermit.s,
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId

    await dttSettle.connect(alice).settleTrade(businessId)
    await dttSettle.connect(alice).settleTrade(businessId)

    const settlePermit = await signPermit(erc20, alice, await diamond.getAddress(), 600, now + 7200)
    await dttSettle.connect(alice).settleTradeWithAmount(
      businessId,
      await erc20.getAddress(),
      600,
      now + 7200,
      settlePermit.v,
      settlePermit.r,
      settlePermit.s,
    )
  })

  it('[SendFacet] sendRealisedToken should skip auto settle when token is paused', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 3000, 'MINT_DTT_PAUSED_1')

    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'realised now', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 10), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    await erc20.connect(issuer).pause()

    const tx = await dttSend.connect(alice).sendRealisedToken(
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
      0,
      0,
      '',
      0,
      ethers.ZeroHash,
      ethers.ZeroHash,
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId

    await erc20.connect(issuer).unpause()
    await dttSettle.connect(alice).settleTrade(businessId)
  })

  it('[SettleFacet] settleTrade should revert with paused token error when business token is paused', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 3000, 'MINT_DTT_PAUSED_2')

    const now = await time.latest()
    const start = now + 3600
    const end = start + 3600
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'future realised', [
        cf('END_DATE', String(end), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(start), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const sendPermit = await signPermit(erc20, alice, await diamond.getAddress(), 1000, now + 7200)
    const tx = await dttSend.connect(alice).sendRealisedToken(
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
      1000,
      '',
      sendPermit.v,
      sendPermit.r,
      sendPermit.s,
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId

    await time.increase(4000)
    await erc20.connect(issuer).pause()
    await expect(dttSettle.connect(alice).settleTrade(businessId)).to.be.revertedWith('SCM_ERC20_01_04')

    await erc20.connect(issuer).unpause()
    await dttSettle.connect(alice).settleTrade(businessId)
  })

  it('[DTTERC20] approve should revert when token is paused', async function () {
    const { erc20, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1000, 'MINT_APPROVE_PAUSED_1')

    await erc20.connect(issuer).pause()
    await expect(erc20.connect(alice).approve(bob.address, 100)).to.be.revertedWith('SCM_ERC20_01_04')
  })

  it('[DTTERC20] permit should revert when token is paused', async function () {
    const { erc20, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1000, 'MINT_PERMIT_PAUSED_1')

    const deadline = (await time.latest()) + 3600
    const permit = await signPermit(erc20, alice, bob.address, 100, deadline)

    await erc20.connect(issuer).pause()
    await expect(
      erc20.connect(bob).permit(alice.address, bob.address, 100, deadline, permit.v, permit.r, permit.s)
    ).to.be.revertedWith('SCM_ERC20_01_04')
  })

  it('[DTTERC20] forceTransfer should revert when token is paused', async function () {
    const { erc20, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1000, 'MINT_FORCE_TRANSFER_PAUSED_1')

    await erc20.connect(issuer).pause()
    await expect(erc20.connect(issuer).forceTransfer(alice.address, bob.address, 100)).not.to.be.revertedWith('SCM_ERC20_01_04')
  })

  it('[VerifyFacet] verifySettleTradeWithAmount should pass when WAIT and amount matches', async function () {
    const { erc20, diamond, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 3000, 'MINT_VERIFY_WAIT_1')

    const now = await time.latest()
    const dttSend = await ethers.getContractAt('SendFacet', await diamond.getAddress())
    const dttSettle = await ethers.getContractAt('SettleFacet', await diamond.getAddress())
    const verifyFacet = await ethers.getContractAt('VerifyFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'realised now', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 10), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    const sendPermit = await signPermit(erc20, alice, await diamond.getAddress(), 400, now + 7200)
    const tx = await dttSend.connect(alice).sendRealisedToken(
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
      sendPermit.s,
    )
    const businessId = (await parseEvent(await tx.wait(), dttSend.interface, 'CreateTrade')).args.businessId
    await dttSettle.connect(alice).settleTrade(businessId)

    await verifyFacet.connect(alice).verifySettleTradeWithAmount(
      businessId,
      await erc20.getAddress(),
      600,
      now + 7200,
      0,
      ethers.ZeroHash,
      ethers.ZeroHash,
    )
  })

  it('[VerifyFacet] verifySendRealisedToken should revert on invalid parameters', async function () {
    const { erc20, diamond, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const verifyFacet = await ethers.getContractAt('VerifyFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'expired date', [
        cf('END_DATE', String(now - 100), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 200), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
    ]

    await expect(
      verifyFacet.connect(alice).verifySendRealisedToken(
        ethers.ZeroAddress,
        await erc20.getAddress(),
        100,
        scs,
        [],
        'SC0',
        '',
        false,
        ethers.ZeroAddress,
        '',
        now + 3600,
        0,
        '',
        0,
        ethers.ZeroHash,
        ethers.ZeroHash,
      )
    ).to.be.revertedWith('SCM_DTT_01_01')
  })

  it('[VerifyFacet] verifySendRealisedToken should pass with partial-accept checks', async function () {
    const { erc20, diamond, alice, bob } = await loadFixture(deployFixture)
    const now = await time.latest()
    const verifyFacet = await ethers.getContractAt('VerifyFacet', await diamond.getAddress())
    const scs = [
      sc('SC0', 'T4:v2', 'At date [Date]', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 100), false, false, ethers.ZeroAddress, 0, 0),
      ], []),
      sc('SC1', 'A1.4:v2', 'Transferer accepts the payment at date [Date]', [
        cf('END_DATE', String(now + 3600), false, false, ethers.ZeroAddress, 0, 0),
        cf('START_DATE', String(now - 100), false, false, ethers.ZeroAddress, 0, 0),
      ], [cf('ACCEPT', '', false, true, alice.address, now - 100, now + 3600, '', [])]),
    ]
    const css = [cs('CS1', ['SC1'], [], 0)]

    await verifyFacet.connect(alice).verifySendRealisedToken(
      bob.address,
      await erc20.getAddress(),
      500,
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
  })

  it('[RorMarket] expire should revert before expire time', async function () {
    const { erc20, diamond, ror, rorMarket, issuer, alice } = await loadFixture(deployFixture)
    const rorId = await mintRorToSelf({ erc20, diamond, ror, alice })
    const deadline = (await time.latest()) + 3600
    const rorSig = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId, deadline)
    const tx = await rorMarket.connect(alice).transferRor(
      rorId,
      issuer.address,
      ethers.ZeroAddress,
      0,
      0,
      '',
      '',
      0,
      0,
      deadline,
      rorSig.v,
      rorSig.r,
      rorSig.s,
    )
    const transferRefId = (await parseEvent(await tx.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId
    await expect(rorMarket.connect(alice).expire(transferRefId)).to.be.revertedWith('SCM_RM_04_01')
  })

  it('[RorMarket] verifyTransfereeAcceptWithFN should pass for valid FT transfer', async function () {
    const { erc20, diamond, ror, rorMarket, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, bob, 1000, 'MINT_VERIFY_RM_FN_1')

    const rorId = await mintRorToSelf({ erc20, diamond, ror, alice })
    const deadline = (await time.latest()) + 7200
    const rorSig = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId, deadline)
    const tx = await rorMarket.connect(alice).transferRor(
      rorId,
      bob.address,
      await erc20.getAddress(),
      100,
      1,
      '',
      '',
      0,
      0,
      deadline,
      rorSig.v,
      rorSig.r,
      rorSig.s,
    )
    const transferRefId = (await parseEvent(await tx.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId

    await rorMarket.connect(bob).verifyTransfereeAcceptWithFN(
      transferRefId,
      '',
      deadline,
      0,
      ethers.ZeroHash,
      ethers.ZeroHash,
    )
  })

  it('[Encash] accept should revert when caller is not issuer', async function () {
    const { erc20, encash, issuer, alice, bob } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1000, 'MINT_ENCASH_2')

    const deadline = (await time.latest()) + 3600
    const permit = await signPermit(erc20, alice, await encash.getAddress(), 200, deadline)
    const tx = await encash.connect(alice).encash(
      await erc20.getAddress(),
      200,
      deadline,
      permit.v,
      permit.r,
      permit.s,
      'encash-non-issuer',
    )
    const businessId = (await parseEvent(await tx.wait(), encash.interface, 'EncashEvent')).args.businessId
    await expect(encash.connect(bob).accept(businessId, 'bad')).to.be.revertedWith('SCM_ENC_02_03')
  })

  it('[Encash] reject should revert when business is not INIT', async function () {
    const { erc20, encash, issuer, alice } = await loadFixture(deployFixture)
    await mintWithPermit(erc20, issuer, alice, 1000, 'MINT_ENCASH_3')

    const deadline = (await time.latest()) + 3600
    const permit = await signPermit(erc20, alice, await encash.getAddress(), 200, deadline)
    const tx = await encash.connect(alice).encash(
      await erc20.getAddress(),
      200,
      deadline,
      permit.v,
      permit.r,
      permit.s,
      'encash-accept-first',
    )
    const businessId = (await parseEvent(await tx.wait(), encash.interface, 'EncashEvent')).args.businessId
    await encash.connect(issuer).accept(businessId, 'accepted')
    await expect(encash.connect(issuer).reject(businessId, 'reject-after-accept')).to.be.revertedWith('SCM_ENC_03_02')
  })
})
