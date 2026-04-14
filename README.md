# Project C DTT Contracts

Project C DTT 是一套基于 Hardhat 的 Solidity 合约工程，包含以下几类核心模块：

- `DTTERC20`：可授权铸造、支持 Permit 的 ERC20 资产代币
- `RORERC721`：用于表示 Right of Receive 的 ERC721 资产
- `DigitalTokenTradeDiamond`：基于 Diamond Pattern 的 DTT 主交易合约
- `Encash`：兑付与结算相关逻辑
- `RorEnhancement`、`RorMarket`：ROR 扩展与流转市场
- `UserPermission`、`Config`：权限与全局配置管理
- `TransactionIDFactory`：业务流水号/交易 ID 生成器

## 目录结构

```text
contracts/
  dtt/           Diamond 主体及各 Facet
  kyc/           配置与权限
  ror/           ROR 市场与增强逻辑
  token/         ERC20 / ERC721 / Encash
  utils/         工具合约
scripts/
  deploys/       部署脚本、部署模板、地址记录
  flowCli/       部署/升级底层工具
  others/        初始化配置、验证、查看存储等辅助脚本
  upgrades/      升级入口
test/            Hardhat 测试
```

## 环境要求

- Node.js 18 或更高版本
- npm 9 或更高版本

项目使用：

- `hardhat@2.22.0`
- `solc 0.8.20`
- OpenZeppelin UUPS Upgrade 插件
- Diamond ABI / storage layout / verify 等 Hardhat 插件

## 安装依赖

项目已包含 `package-lock.json`，直接执行：

```bash
npm install
```

该步骤会通过 `patch-package` 应用 `patches/` 目录下的补丁。

## 网络配置

当前网络配置位于 [hardhat.config.js](/usr/src/solidity/projectc-dtt/hardhat.config.js)，默认包含：

- `hardhat`：本地测试网络

## 常用命令

```bash
# 运行全部测试
npx hardhat test

# 运行单个测试文件
npx hardhat test test/erc20_core.test.js
```

## 测试说明

测试位于 `test/` 目录，当前覆盖了以下主要场景：

- `erc20_core.test.js`：ERC20 的 mint / transfer / burn
- `dtt_settle.test.js`：DTT 交易结算
- `dtt_send_partial.test.js`：部分发送 / 分批处理
- `dtt_condition_actions.test.js`：条件动作处理
- `dtt_condition_diversity_branch.test.js`：条件分支多样性
- `encash_flow.test.js`：兑付流程
- `ror_erc721_flow.test.js`：ROR ERC721 流程
- `ror_market_flow.test.js`：ROR 市场转让、接受、拒绝、过期
- `user_permission.test.js`：权限控制
- `yield_stablecoin.test.js`：稳定币 / 收益相关流程
- `branch_coverage.test.js`：分支覆盖补充

测试夹具位于 [test/helpers/projectContracts.js](/usr/src/solidity/projectc-dtt/test/helpers/projectContracts.js)，会在本地自动完成以下动作：

- 部署 UUPS 合约
- 部署 Diamond 与 Facet
- 绑定 `Config`
- 设置 `Issuer`、`MintLimit`、权限等初始化数据


## 部署前需要了解的 3 个配置文件

部署脚本依赖以下文件：

- [scripts/paramConfig.json](/usr/src/solidity/projectc-dtt/scripts/paramConfig.json)
  用于配置部署后的业务参数，例如：
  - `issuer`
  - `suspenseAccount`
  - `tokenMintLicensor`
  - `activeUsers`

- [scripts/deploys/redeployParam.json](/usr/src/solidity/projectc-dtt/scripts/deploys/redeployParam.json)
  用于定义部署顺序、工厂名、初始化参数和合约类型（`uups` / `normal` / `diamond`）。

- [scripts/deploys/address.json](/usr/src/solidity/projectc-dtt/scripts/deploys/address.json)
  用于保存部署结果，包括代理地址、Diamond Facet 地址、区块高度等。

注意：

- `deployContracts()` 会直接写入 `address[contractName].address`。
- 因此 `address.json` 不能随意改成空对象 `{}`。
- 如果要重新部署，建议保留当前 JSON 的键结构，只清空各合约的 `address`、区块号和 Facet 地址，或者先基于现有文件另存一份模板。

## 部署流程

### 1. 检查部署参数

先确认：

- [scripts/paramConfig.json](/usr/src/solidity/projectc-dtt/scripts/paramConfig.json)
- [scripts/deploys/redeployParam.json](/usr/src/solidity/projectc-dtt/scripts/deploys/redeployParam.json)
- [scripts/deploys/address.json](/usr/src/solidity/projectc-dtt/scripts/deploys/address.json)

部署脚本依赖以下文件：

- [scripts/paramConfig.json](/usr/src/solidity/projectc-dtt/scripts/paramConfig.json)
  用于配置部署后的业务参数，例如：
  - `issuer`
  - `suspenseAccount`
  - `tokenMintLicensor`
  - `activeUsers`

- [scripts/deploys/redeployParam.json](/usr/src/solidity/projectc-dtt/scripts/deploys/redeployParam.json)
  用于定义部署顺序、工厂名、初始化参数和合约类型（`uups` / `normal` / `diamond`）。

- [scripts/deploys/address.json](/usr/src/solidity/projectc-dtt/scripts/deploys/address.json)
  用于保存部署结果，包括代理地址、Diamond Facet 地址、区块高度等。

注意：

- `deployContracts()` 会直接写入 `address[contractName].address`。
- 因此 `address.json` 不能随意改成空对象 `{}`。
- 如果要重新部署，建议保留当前 JSON 的键结构，只清空各合约的 `address`、区块号和 Facet 地址，或者先基于现有文件另存一份模板。


其中 `redeployParam.json` 当前默认部署顺序大致为：

1. `DTTERC20`：`GLSGD`
2. `DTTERC20`：`GLUSD`
3. `TransactionIDFactory`
4. `DigitalTokenTradeDiamond`
5. `Encash`
6. `RORERC721`
7. `RorEnhancement`
8. `RorMarket`
9. `UserPermission`
10. `Config`

### 2. 执行部署


指定网络部署：

```bash
npx hardhat run scripts/deploys/deploy.js --network sepolia
```

部署入口位于 [scripts/deploys/deploy.js](/usr/src/solidity/projectc-dtt/scripts/deploys/deploy.js)，其内部会调用 `scripts/flowCli/utl.js` 中的 `deployContracts()`。

### 3. 执行初始化配置

部署完成后，需要执行合约初始化配置：

```bash
npx hardhat run scripts/others/setConfig.js --network sepolia
```

本地调试时使用 `localhost`，链上环境使用目标网络，例如 `sepolia`。

该脚本会做以下事情：

- 为 `GLSGD`、`GLUSD`、`Encash`、`TransactionIDFactory`、`RORERC721`、`RorEnhancement`、`RorMarket`、`SendFacet` 绑定 `Config`
- 调用 `Config.setSuspense()` 设置稳定币 suspense account
- 给 `UserPermission` 授予 `ISSUER_ROLE`
- 为 `GLSGD`、`GLUSD`、`RORERC721` 设置 `Issuer`
- 为 `GLSGD`、`GLUSD` 设置 `MintLimit`
- 为 `GLSGD`、`GLUSD` 设置 `TokenMintLicensor`

### 4. 可选：设置 ROR Token 元数据

如果需要为 `RORERC721` 设置描述和 SVG 模板，可执行：

```bash
npx hardhat run scripts/others/setTokenURI.js --network localhost
npx hardhat run scripts/others/setTokenURI.js --network sepolia
```

### 5. 可选：区块浏览器验证

验证脚本入口：

```bash
npx hardhat run scripts/others/verify.js --network sepolia
```

脚本会读取 [scripts/others/verify.json](/usr/src/solidity/projectc-dtt/scripts/others/verify.json) 和 `address.json` 中的部署结果。

## 升级流程

升级入口位于 [scripts/upgrades/upgrade.js](/usr/src/solidity/projectc-dtt/scripts/upgrades/upgrade.js)。

执行方式：

```bash
npx hardhat run scripts/upgrades/upgrade.js --network sepolia
```

注意当前实现：

- `upgrade.js` 中默认的 `contractsParam` 是空数组
- 也就是说，直接执行不会升级任何合约
- 真正升级前，需要先在脚本中填入需要升级的合约描述

`utl.js` 已支持两类升级：

- `uups` 合约升级：使用 `upgrades.upgradeProxy()`
- `diamond` 合约升级：先移除旧 selectors，再重新部署 Facet 并执行 `diamondCut`

## 其他辅助脚本

`scripts/others/` 下还包含一些辅助工具：

- `caculateContractSize.js`：查看合约大小
- `gencode.js`：生成代码相关工具
- `runGenerateDummyFromABI.js`：根据 ABI 生成 Dummy 合约
- `viewStorage.js`：查看存储布局

如果需要查看这些脚本的具体参数，建议直接阅读对应文件实现。

## 本地开发建议

推荐的日常开发顺序：

1. `npm install`
2. `npx hardhat test`
3. 修改合约或脚本
4. 再次执行相关测试


## 已知注意事项

- `package.json` 中的 `npm test` 目前是占位脚本，不能直接用于运行测试。
- 实际测试命令应使用 `npx hardhat test`。
- 部署脚本依赖 `address.json` 的既有键结构，直接清空整个文件会导致部署逻辑报错。

## 快速开始

如果你只是想快速跑通本地开发流程：

```bash
npm install
npx hardhat test
```

如果你要发到链上：

```bash
npm install
npx hardhat run scripts/deploys/deploy.js --network sepolia
npx hardhat run scripts/others/setConfig.js --network sepolia
npx hardhat run scripts/others/setTokenURI.js --network sepolia
```
