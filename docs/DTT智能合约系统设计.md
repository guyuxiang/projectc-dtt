# 智能合约系统设计文档

- 项目：`project-contracts`
- 版本基线：当前 `main` 工作区代码
- 文档日期：2026-03-05
- 适用网络：Hardhat 本地网络、Polygon 系列网络（见 `hardhat.config.js`）

## 1. 设计目标

本系统面向“数字贸易资产（DTT）+ 稳定币（DTTERC20）+ 权益凭证（RORERC721）”业务，目标是：

1. 支持条件化交易发送、状态推进与结算。
2. 支持 ROR NFT 的二级转让与对价交付。
3. 提供可配置的 KYC/权限门禁（UserPermission + Permission 位掩码）。
4. 提供可升级能力（UUPS + Diamond），保障长期演进。
5. 提供可审计事件与可回放业务 ID（TransactionIDFactory）。

## 2. 总体架构

### 2.1 分层结构

1. **权限与配置层（KYC）**
- `UserPermission.sol`
- `Permission.sol`
- `Config.sol`

2. **Token 层**
- `DTTERC20.sol`（稳定币）
- `RORERC721.sol`（权益 NFT）
- `Encash.sol`（兑付流程）

3. **DTT 业务层（Diamond）**
- `DigitalTokenTradeDiamond.sol`
- Facets：`SendFacet`、`ConditionActionFacet`、`ConditionCalculateFacet`、`ConditionCreateFacet`、`SettleFacet`、`TradeStatusFacet`、`VerifyFacet`、`Diamond*Facet`
- 存储：`DTTStorage.sol`

4. **ROR 业务层**
- `RorEnhancement.sol`
- `RorMarket.sol`

5. **治理与辅助层**
- `TransactionIDFactory.sol`
- `govern/*`（治理代币与 timelock）

### 2.2 升级模式

1. **UUPS Proxy**：`DTTERC20`、`RORERC721`、`Encash`、`RorEnhancement`、`RorMarket`、`TransactionIDFactory` 等。
2. **Diamond（EIP-2535 风格）**：`DigitalTokenTradeDiamond` + 多 Facet。

## 3. 核心合约职责

## 3.1 KYC 与配置

### `UserPermission`
- 角色：`DEFAULT_ADMIN_ROLE`、`OPERATOR`、`ISSUER_ROLE`
- 核心方法：
  - `setPermission(...)`
  - `getPermission(...)`
  - `grantRoles(...)`

### `Permission`
- 通过数值位控制门禁（ERC20 入账/出账、DTT 发送、NFT 转入转出等）。

### `Config`
- 全局地址注册中心：`userPermission`、`dtt`、`encash`、`rorEnhancement`、`rorMarket`、`rorAddress`、`idFactoryAddress`、`governorAddress`
- `tokenSuspense` 兜底地址管理：`setSuspense/getSuspense`

## 3.2 Token 与兑付

### `DTTERC20`
- 核心能力：`mint`（带 MintPermit 签名）、`transfer`、`transferFrom`、`burn`
- 治理配置：`setIssuer`、`setTokenMintLicensor`、`setMintLimit`、`setConfig`
- 风控：`pause/unpause`、`verify*Door`

### `RORERC721`
- 核心能力：`mint`（仅 RorEnhancement 调用）、`permit`、`transferFrom`、`tokenURI`
- 治理配置：`setIssuer`、`setConfig`、SVG/描述配置

### `Encash`
- 核心流程：`encash -> accept/reject`
- 使用 ERC20 Permit 做资金授权拉取

## 3.3 DTT（Diamond）

### `SendFacet`
- `sendRealisedToken(...)`：创建交易、创建条件、处理担保金、铸造 ROR
- `conditionPartialAccept(...)`：部分接受，分拆子交易并同步 ROR
- `getPendingRefIds()`：待处理业务 ID 集

### `ConditionActionFacet`
- `conditionAccept(...)`
- `conditionReject(...)`
- `conditionSetDate(...)`
- 修改条件后，若达到可结算状态会触发 `settleTrade`

### `ConditionCalculateFacet`
- 条件状态计算：`querySCStatus/queryCSStatus`
- 时间窗口计算：`calculateTimeRange`
- 因子检索：`queryFactor/queryFactorIndex`

### `ConditionCreateFacet`
- 条件创建/复制/重构，供发送与 partial accept 复用。

### `TradeStatusFacet`
- `tradeStatus(businessId)` 产出 `Unrealised/Confirmed/Realised/Void`

### `SettleFacet`
- `settleTrade(businessId)`：正常结算或退款结算
- `settleTradeWithAmount(...)`：`WAIT` 状态补款后结算
- `settleExpire(...)`：批量触发结算

### `VerifyFacet`
- `verifySendRealisedToken(...)`
- `verifySettleTradeWithAmount(...)`
- 用于链上预检查路径

## 3.4 ROR 相关

### `RorEnhancement`
- 维护 `sendRefId -> ror` 映射
- `send(...)`：发送交易时铸造 ROR
- `partialAccept(...)`：部分接受时做 ROR 拆分与关联迁移
- `settle(...)`：结算时输出 ROR 分账清单

### `RorMarket`
- `transferRor(...)`：创建 ROR 转让单
- `transfereeAccept(...)`：无对价接受
- `transfereeAcceptWithFN(...)`：FT 对价接受
- `transfereeReject(...)`、`expire(...)`
- `getPendingRefIds()`：待处理转让单

## 4. 关键数据结构与状态机

## 4.1 DTT 存储（`DTTStorage`）

### 核心结构
- `RealisedTokenTrade`
- `RealisedTokenTradeExpand`（`guaranteeAmount`）
- `SingleCondition` / `ConditionSet` / `ConditionFactor`

### 状态枚举
- `TradeStatus`：`Unrealised` / `Confirmed` / `Realised` / `Void`
- `SettleStatus`：`INIT` / `SEND` / `REFUND` / `WAIT`
- `ConditionStatus`：`Met` / `RightNowMet` / `RightNowNotMet` / `NotMet`

## 4.2 ROR 转让状态（`RorMarket.TransferStatus`）
- `INIT` / `ACCEPTED` / `REJECTED` / `EXPIRED` / `ROR_BURN`

## 5. 业务流程设计

## 5.1 DTT 发送与条件结算主流程

1. 发送方准备 ERC20 Permit。
2. 调用 `sendRealisedToken`：
   - 校验参数与权限。
   - 锁定担保金（`guaranteeAmount`）。
   - 生成 `businessId`，创建条件与交易。
   - 生成 ROR（`RorEnhancement.send`）。
3. 若条件已满足，直接 `settleTrade`；否则进入待条件推进。
4. 通过 `conditionAccept/reject/setDate` 推进状态。
5. `SettleFacet` 按 `Realised/Void` 分别走付款或退款路径。

## 5.2 WAIT 补款结算流程

触发条件：`trade.amount != guaranteeAmount`，`settleTrade` 将状态置 `WAIT`。

1. 付款方调用 `settleTradeWithAmount` 并附 ERC20 Permit。
2. 合约补齐差额后按 ROR 分账清单执行转账。
3. 交易状态进入 `SEND`。

## 5.3 ROR 市场流程

1. ROR 持有人调用 `transferRor` 创建转让单（可设置对价 Token 与金额）。
2. 受让方：
   - 无对价：`transfereeAccept`
   - 有对价：`transfereeAcceptWithFN`（Permit + transferFrom）
3. 或执行 `transfereeReject` / 超时 `expire`。

## 6. 权限与安全设计

## 6.1 角色控制

1. **Governor（Config.governorAddress）**：核心配置变更、issuer 设置、pause/unpause。
2. **Owner（UUPS / Diamond 管理者）**：升级权限。
3. **ISSUER_ROLE**：可给业务账户赋权限。

## 6.2 门禁位控制（`Permission.sol`）

通过 `uint256` 位值控制不同业务门禁（ERC20、DTT、NFT 入出账等）。

## 6.3 资金安全机制

1. 广泛使用 Permit，减少显式 approve 操作面。
2. `suspense` 兜底账号处理接收权限不足场景。
3. `pause/unpause` 支持紧急熔断。
4. 异常路径使用统一错误码（`libraries/Constants.sol`）。

## 6.4 主要风险点与治理建议

1. **升级治理风险**：建议多签 + timelock + 审批流。
2. **权限配置风险**：建议链上脚本自动校验 `permission` 位。
3. **分支覆盖不足风险**：当前失败路径覆盖低于成功路径，应持续补测。
4. **时间条件复杂度**：建议对 `conditionSetDate`、`calculateTimeRange` 增加边界测试。

## 7. 测试设计与现状

当前已拆分测试文件（`test/*.test.js`）：

1. `user_permission.test.js`
2. `erc20_core.test.js`
3. `encash_flow.test.js`
4. `ror_erc721_flow.test.js`
5. `ror_market_flow.test.js`
6. `dtt_send_partial.test.js`
7. `dtt_settle.test.js`
8. `dtt_condition_actions.test.js`

覆盖的关键方法包括：
- `conditionAccept/conditionReject/conditionSetDate`
- `conditionPartialAccept`
- `settleTrade/settleTradeWithAmount`
- `sendRealisedToken`
- `transfereeAccept/transfereeAcceptWithFN/transfereeReject/expire`

最近一次覆盖率统计（`npx hardhat coverage`）：
- Statements: `58.11%`
- Branches: `36.40%`
- Functions: `51.49%`
- Lines: `59.15%`

## 8. 部署与初始化顺序（建议）

1. 部署基础合约：`TransactionIDFactory`、`Encash`、`DTTERC20`、`RORERC721`、`RorEnhancement`、`RorMarket`。
2. 部署 Diamond 与 Facets，执行 `diamondCut`。
3. 部署 `UserPermission`、`Config`。
4. 对所有业务合约执行 `setConfig`。
5. 配置 `issuer`、`tokenMintLicensor`、`mintLimit`、`suspense`。
6. 赋权 `ISSUER_ROLE`，下发业务账号权限。
7. 回归测试：`npx hardhat test`、`npx hardhat coverage`。

## 9. 运维与审计建议

1. 所有 `setConfig/setIssuer/grantRoles` 操作保留链上交易清单。
2. 关键事件（CreateTrade、SettleTrade、RorTransferStatusChange）建立离线索引。
3. 升级前执行：
   - 存储布局检查（如使用 storage-layout 工具）
   - 全量回归 + 覆盖率对比
4. 建议引入 CI 门禁：
   - `npx hardhat test` 必须通过
   - 核心目录最低覆盖阈值（尤其 Branch）

## 10. 附录：核心业务 ID 规则

`TransactionIDFactory` 负责生成业务号，典型格式由日期、token 标识、交易类型和序列组成，用于：
- DTT 发送单（`SEND`）
- ROR 转让单（`TRSF`）
- Encash 业务单等

该 ID 是跨合约关联主键，应保证：
- 业务唯一性
- 可审计可回放
- 事件索引稳定

---

如需进一步细化，可在此文档上继续拆出 3 份子文档：
1. `DTT 条件引擎设计`
2. `ROR 市场撮合与清结算设计`
3. `权限与治理（生产运维手册）`
