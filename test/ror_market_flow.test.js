const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')
const {
  deployFixture,
  sc,
  cf,
  parseEvent,
  signRorPermit,
  signMintPermit,
  signPermit,
} = require('./helpers/projectContracts')

describe('RorMarket Methods', function () {
  it('should cover transfer accept reject and expire', async function () {
    const { erc20, diamond, ror, rorMarket, issuer, alice, bob, carol } = await loadFixture(deployFixture)

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
      ethers.ZeroHash
    )
    const sendReceipt = await sendTx.wait()
    const transferEvent = await parseEvent(sendReceipt, ror.interface, 'Transfer')
    const rorId = transferEvent.args.tokenId

    const deadline = now + 7200
    const rorPermit = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId, deadline)

    const transferTx = await rorMarket.connect(alice).transferRor(
      rorId,
      bob.address,
      ethers.ZeroAddress,
      0,
      0,
      '',
      '',
      0,
      0,
      deadline,
      rorPermit.v,
      rorPermit.r,
      rorPermit.s
    )
    const transferReceipt = await transferTx.wait()
    const transferEvent1 = await parseEvent(transferReceipt, rorMarket.interface, 'RorTransferStatusChange')
    await rorMarket.connect(bob).transfereeAccept(transferEvent1.args.transferRefId, 'accept')

    const mintSig = await signMintPermit(erc20, issuer, bob.address, 1000, 'MINT_3')
    await erc20.connect(issuer).mint(bob.address, 1000, 'MINT_3', mintSig)

    const sendTx2 = await dttSend.connect(alice).sendRealisedToken(
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
      ethers.ZeroHash
    )
    const sendReceipt2 = await sendTx2.wait()
    const rorId2 = (await parseEvent(sendReceipt2, ror.interface, 'Transfer')).args.tokenId
    const rorPermit2 = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId2, deadline)

    const transferTx2 = await rorMarket.connect(alice).transferRor(
      rorId2,
      bob.address,
      await erc20.getAddress(),
      500,
      1,
      '',
      '',
      0,
      0,
      deadline,
      rorPermit2.v,
      rorPermit2.r,
      rorPermit2.s
    )
    const transferRefId2 = (await parseEvent(await transferTx2.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId

    const permitFt = await signPermit(erc20, bob, await rorMarket.getAddress(), 500, deadline)
    await rorMarket.connect(bob).transfereeAcceptWithFN(transferRefId2, 'accept-fn', deadline, permitFt.v, permitFt.r, permitFt.s)

    const sendTx3 = await dttSend.connect(alice).sendRealisedToken(
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
      ethers.ZeroHash
    )
    const rorId3 = (await parseEvent(await sendTx3.wait(), ror.interface, 'Transfer')).args.tokenId
    const rorPermit3 = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId3, deadline)
    const transferTx3 = await rorMarket.connect(alice).transferRor(
      rorId3,
      carol.address,
      ethers.ZeroAddress,
      0,
      0,
      '',
      '',
      0,
      0,
      deadline,
      rorPermit3.v,
      rorPermit3.r,
      rorPermit3.s
    )
    const transferRefId3 = (await parseEvent(await transferTx3.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId
    await rorMarket.connect(carol).transfereeReject(transferRefId3, 'reject')

    const sendTx4 = await dttSend.connect(alice).sendRealisedToken(
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
      ethers.ZeroHash
    )
    const rorId4 = (await parseEvent(await sendTx4.wait(), ror.interface, 'Transfer')).args.tokenId
    const rorPermit4 = await signRorPermit(ror, alice, await rorMarket.getAddress(), rorId4, deadline)
    const transferTx4 = await rorMarket.connect(alice).transferRor(
      rorId4,
      bob.address,
      ethers.ZeroAddress,
      0,
      0,
      '',
      '',
      0,
      0,
      deadline,
      rorPermit4.v,
      rorPermit4.r,
      rorPermit4.s
    )
    const transferRefId4 = (await parseEvent(await transferTx4.wait(), rorMarket.interface, 'RorTransferStatusChange')).args.transferRefId

    await time.increase(86401)
    await rorMarket.connect(bob).expire(transferRefId4)
  })
})
