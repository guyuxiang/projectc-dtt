# Project C DTT Contracts

Project C DTT 是一套基于 Hardhat 的 Solidity 合约工程，包含以下几类核心模块。  
Project C DTT is a Hardhat-based Solidity contract project with the following core modules.

- `DTTERC20`：可授权铸造、支持 Permit 的 ERC20 资产代币  
  `DTTERC20`: ERC20 asset tokens with authorized minting and Permit support
- `RORERC721`：用于表示 Right of Receive 的 ERC721 资产  
  `RORERC721`: ERC721 assets representing Right of Receive
- `DigitalTokenTradeDiamond`：基于 Diamond Pattern 的 DTT 主交易合约  
  `DigitalTokenTradeDiamond`: the main DTT trading contract built with the Diamond Pattern
- `Encash`：兑付与结算相关逻辑  
  `Encash`: encashment and settlement logic
- `RorEnhancement`、`RorMarket`：ROR 扩展与流转市场  
  `RorEnhancement`, `RorMarket`: ROR extensions and secondary market logic
- `UserPermission`、`Config`：权限与全局配置管理  
  `UserPermission`, `Config`: permission control and global configuration management
- `TransactionIDFactory`：业务流水号 / 交易 ID 生成器  
  `TransactionIDFactory`: business serial number / transaction ID generator

## 目录结构 | Project Structure

```text
contracts/
  dtt/           Diamond 主体及各 Facet | Diamond core and facets
  kyc/           配置与权限 | Configuration and permissions
  ror/           ROR 市场与增强逻辑 | ROR market and enhancement logic
  token/         ERC20 / ERC721 / Encash
  utils/         工具合约 | Utility contracts
scripts/
  deploys/       部署脚本、部署模板、地址记录 | Deployment scripts, templates, address records
  flowCli/       部署 / 升级底层工具 | Low-level deployment / upgrade helpers
  others/        初始化配置、验证、查看存储等辅助脚本 | Init, verification, storage inspection, and helper scripts
  upgrades/      升级入口 | Upgrade entrypoint
test/            Hardhat 测试 | Hardhat tests
```

## 环境要求 | Requirements

- Node.js 18 或更高版本  
  Node.js 18 or later
- npm 9 或更高版本  
  npm 9 or later

项目使用：  
The project uses:

- `hardhat@2.22.0`
- `solc 0.8.20`
- OpenZeppelin UUPS Upgrade 插件  
  OpenZeppelin UUPS Upgrade plugin
- Diamond ABI / storage layout / verify 等 Hardhat 插件  
  Hardhat plugins for Diamond ABI, storage layout, verification, and related tasks

## 安装依赖 | Install Dependencies

项目已包含 `package-lock.json`，直接执行：  
The repository already includes `package-lock.json`, so you can run:

```bash
npm install
```

该步骤会通过 `patch-package` 应用 `patches/` 目录下的补丁。  
This step also applies patches under `patches/` via `patch-package`.

## 网络配置 | Network Configuration

当前网络配置位于 [hardhat.config.js](/usr/src/solidity/projectc-dtt/hardhat.config.js)，默认包含：  
The current network configuration is defined in [hardhat.config.js](/usr/src/solidity/projectc-dtt/hardhat.config.js), which currently includes:

- `hardhat`：本地测试网络  
  `hardhat`: local testing network

## 常用命令 | Common Commands

```bash
# 运行全部测试 | Run all tests
npx hardhat test

# 运行单个测试文件 | Run a single test file
npx hardhat test test/erc20_core.test.js
```

## 测试说明 | Test Coverage

测试位于 `test/` 目录，当前覆盖了以下主要场景：  
Tests are located in `test/` and currently cover the following major scenarios:

- `erc20_core.test.js`：ERC20 的 mint / transfer / burn  
  `erc20_core.test.js`: ERC20 mint / transfer / burn
- `dtt_settle.test.js`：DTT 交易结算  
  `dtt_settle.test.js`: DTT settlement flow
- `dtt_send_partial.test.js`：部分发送 / 分批处理  
  `dtt_send_partial.test.js`: partial send / batch processing
- `dtt_condition_actions.test.js`：条件动作处理  
  `dtt_condition_actions.test.js`: conditional action handling
- `dtt_condition_diversity_branch.test.js`：条件分支多样性  
  `dtt_condition_diversity_branch.test.js`: diverse conditional branching
- `encash_flow.test.js`：兑付流程  
  `encash_flow.test.js`: encashment flow
- `ror_erc721_flow.test.js`：ROR ERC721 流程  
  `ror_erc721_flow.test.js`: ROR ERC721 flow
- `ror_market_flow.test.js`：ROR 市场转让、接受、拒绝、过期  
  `ror_market_flow.test.js`: ROR market transfer, accept, reject, and expiry flows
- `user_permission.test.js`：权限控制  
  `user_permission.test.js`: permission control
- `yield_stablecoin.test.js`：稳定币 / 收益相关流程  
  `yield_stablecoin.test.js`: stablecoin / yield-related flows
- `branch_coverage.test.js`：分支覆盖补充  
  `branch_coverage.test.js`: supplemental branch coverage

测试夹具位于 [test/helpers/projectContracts.js](/usr/src/solidity/projectc-dtt/test/helpers/projectContracts.js)，会在本地自动完成以下动作：  
The test fixture is defined in [test/helpers/projectContracts.js](/usr/src/solidity/projectc-dtt/test/helpers/projectContracts.js), and it automatically performs the following setup locally:

- 部署 UUPS 合约  
  Deploy UUPS contracts
- 部署 Diamond 与 Facet  
  Deploy the Diamond contract and facets
- 绑定 `Config`  
  Bind `Config`
- 设置 `Issuer`、`MintLimit`、权限等初始化数据  
  Initialize `Issuer`, `MintLimit`, permissions, and related config

## 部署前需要了解的 3 个配置文件 | Three Config Files to Understand Before Deployment

部署脚本依赖以下文件：  
The deployment scripts depend on the following files:

- [scripts/paramConfig.json](/usr/src/solidity/projectc-dtt/scripts/paramConfig.json)  
  用于配置部署后的业务参数，例如：  
  Used to configure post-deployment business parameters, such as:
  - `issuer`
  - `suspenseAccount`
  - `tokenMintLicensor`
  - `activeUsers`

- [scripts/deploys/redeployParam.json](/usr/src/solidity/projectc-dtt/scripts/deploys/redeployParam.json)  
  用于定义部署顺序、工厂名、初始化参数和合约类型（`uups` / `normal` / `diamond`）。  
  Used to define deployment order, factory names, initialization parameters, and contract types (`uups` / `normal` / `diamond`).

- [scripts/deploys/address.json](/usr/src/solidity/projectc-dtt/scripts/deploys/address.json)  
  用于保存部署结果，包括代理地址、Diamond Facet 地址、区块高度等。  
  Used to store deployment results, including proxy addresses, Diamond facet addresses, block heights, and related metadata.

注意：  
Notes:

- `deployContracts()` 会直接写入 `address[contractName].address`。  
  `deployContracts()` writes directly to `address[contractName].address`.
- 因此 `address.json` 不能随意改成空对象 `{}`。  
  For that reason, `address.json` must not be replaced with an empty object `{}`.
- 如果要重新部署，建议保留当前 JSON 的键结构，只清空各合约的 `address`、区块号和 Facet 地址，或者先基于现有文件另存一份模板。  
  If you need to redeploy, keep the existing JSON key structure and only clear contract `address`, block numbers, and facet addresses, or first save a template based on the current file.

## 部署流程 | Deployment Flow

### 1. 检查部署参数 | Check Deployment Parameters

先确认以下文件：  
First, verify the following files:

- [scripts/paramConfig.json](/usr/src/solidity/projectc-dtt/scripts/paramConfig.json)
- [scripts/deploys/redeployParam.json](/usr/src/solidity/projectc-dtt/scripts/deploys/redeployParam.json)
- [scripts/deploys/address.json](/usr/src/solidity/projectc-dtt/scripts/deploys/address.json)

其中 `redeployParam.json` 当前默认部署顺序大致为：  
The current default deployment order in `redeployParam.json` is roughly:

1. `DTTERC20`：`GLSGD`  
   `DTTERC20`: `GLSGD`
2. `DTTERC20`：`GLUSD`  
   `DTTERC20`: `GLUSD`
3. `TransactionIDFactory`
4. `DigitalTokenTradeDiamond`
5. `Encash`
6. `RORERC721`
7. `RorEnhancement`
8. `RorMarket`
9. `UserPermission`
10. `Config`

### 2. 执行部署 | Run Deployment

指定网络部署：  
Deploy to a specific network:

```bash
npx hardhat run scripts/deploys/deploy.js --network sepolia
```

部署入口位于 [scripts/deploys/deploy.js](/usr/src/solidity/projectc-dtt/scripts/deploys/deploy.js)，其内部会调用 `scripts/flowCli/utl.js` 中的 `deployContracts()`。  
The deployment entrypoint is [scripts/deploys/deploy.js](/usr/src/solidity/projectc-dtt/scripts/deploys/deploy.js), which internally calls `deployContracts()` from `scripts/flowCli/utl.js`.

### 3. 执行初始化配置 | Run Post-Deployment Initialization

部署完成后，需要执行合约初始化配置：  
After deployment, run the contract initialization script:

```bash
npx hardhat run scripts/others/setConfig.js --network sepolia
```

本地调试时使用 `localhost`，链上环境使用目标网络，例如 `sepolia`。  
Use `localhost` for local debugging, and the target network such as `sepolia` for on-chain environments.

该脚本会做以下事情：  
This script performs the following actions:

- 为 `GLSGD`、`GLUSD`、`Encash`、`TransactionIDFactory`、`RORERC721`、`RorEnhancement`、`RorMarket`、`SendFacet` 绑定 `Config`  
  Bind `Config` to `GLSGD`, `GLUSD`, `Encash`, `TransactionIDFactory`, `RORERC721`, `RorEnhancement`, `RorMarket`, and `SendFacet`
- 调用 `Config.setSuspense()` 设置稳定币 suspense account  
  Call `Config.setSuspense()` to configure the stablecoin suspense account
- 给 `UserPermission` 授予 `ISSUER_ROLE`  
  Grant `ISSUER_ROLE` to `UserPermission`
- 为 `GLSGD`、`GLUSD`、`RORERC721` 设置 `Issuer`  
  Set `Issuer` for `GLSGD`, `GLUSD`, and `RORERC721`
- 为 `GLSGD`、`GLUSD` 设置 `MintLimit`  
  Set `MintLimit` for `GLSGD` and `GLUSD`
- 为 `GLSGD`、`GLUSD` 设置 `TokenMintLicensor`  
  Set `TokenMintLicensor` for `GLSGD` and `GLUSD`

### 4. 可选：设置 ROR Token 元数据 | Optional: Set ROR Token Metadata

如果需要为 `RORERC721` 设置描述和 SVG 模板，可执行：  
If you need to configure the description and SVG template for `RORERC721`, run:

```bash
npx hardhat run scripts/others/setTokenURI.js --network localhost
npx hardhat run scripts/others/setTokenURI.js --network sepolia
```

### 5. 可选：区块浏览器验证 | Optional: Block Explorer Verification

验证脚本入口：  
Verification entrypoint:

```bash
npx hardhat run scripts/others/verify.js --network sepolia
```

脚本会读取 [scripts/others/verify.json](/usr/src/solidity/projectc-dtt/scripts/others/verify.json) 和 `address.json` 中的部署结果。  
The script reads deployment results from [scripts/others/verify.json](/usr/src/solidity/projectc-dtt/scripts/others/verify.json) and `address.json`.

## 升级流程 | Upgrade Flow

升级入口位于 [scripts/upgrades/upgrade.js](/usr/src/solidity/projectc-dtt/scripts/upgrades/upgrade.js)。  
The upgrade entrypoint is [scripts/upgrades/upgrade.js](/usr/src/solidity/projectc-dtt/scripts/upgrades/upgrade.js).

执行方式：  
Run it with:

```bash
npx hardhat run scripts/upgrades/upgrade.js --network sepolia
```

注意当前实现：  
Notes about the current implementation:

- `upgrade.js` 中默认的 `contractsParam` 是空数组  
  The default `contractsParam` in `upgrade.js` is an empty array
- 也就是说，直接执行不会升级任何合约  
  That means running it directly will not upgrade any contract
- 真正升级前，需要先在脚本中填入需要升级的合约描述  
  Before performing a real upgrade, you need to fill in the contract descriptors to upgrade inside the script

`utl.js` 已支持两类升级：  
`utl.js` currently supports two upgrade modes:

- `uups` 合约升级：使用 `upgrades.upgradeProxy()`  
  `uups` contract upgrade: uses `upgrades.upgradeProxy()`
- `diamond` 合约升级：先移除旧 selectors，再重新部署 Facet 并执行 `diamondCut`  
  `diamond` contract upgrade: removes old selectors first, then redeploys the facet and executes `diamondCut`

## 其他辅助脚本 | Other Helper Scripts

`scripts/others/` 下还包含一些辅助工具：  
The `scripts/others/` directory also includes several helper tools:

- `caculateContractSize.js`：查看合约大小  
  `caculateContractSize.js`: inspect contract size
- `gencode.js`：生成代码相关工具  
  `gencode.js`: code generation helper
- `runGenerateDummyFromABI.js`：根据 ABI 生成 Dummy 合约  
  `runGenerateDummyFromABI.js`: generate dummy contracts from ABI
- `viewStorage.js`：查看存储布局  
  `viewStorage.js`: inspect storage layout

如果需要查看这些脚本的具体参数，建议直接阅读对应文件实现。  
If you need the exact parameters for these scripts, read the corresponding implementation files directly.

## 本地开发建议 | Local Development Recommendation

推荐的日常开发顺序：  
Recommended day-to-day development flow:

1. `npm install`
2. `npx hardhat test`
3. 修改合约或脚本  
   Modify contracts or scripts
4. 再次执行相关测试  
   Run the relevant tests again

## 已知注意事项 | Known Notes

- `package.json` 中的 `npm test` 目前是占位脚本，不能直接用于运行测试。  
  The `npm test` script in `package.json` is currently a placeholder and should not be used to run tests directly.
- 实际测试命令应使用 `npx hardhat test`。  
  Use `npx hardhat test` as the actual test command.
- 部署脚本依赖 `address.json` 的既有键结构，直接清空整个文件会导致部署逻辑报错。  
  The deployment scripts rely on the existing key structure in `address.json`; clearing the entire file will break deployment logic.

## 快速开始 | Quick Start

如果你只是想快速跑通本地开发流程：  
If you only want to run the local development flow quickly:

```bash
npm install
npx hardhat test
```

如果你要发到链上：  
If you want to deploy on-chain:

```bash
npm install
npx hardhat run scripts/deploys/deploy.js --network sepolia
npx hardhat run scripts/others/setConfig.js --network sepolia
npx hardhat run scripts/others/setTokenURI.js --network sepolia
```
