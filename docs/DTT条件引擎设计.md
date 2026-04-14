# DTT 条件引擎设计

- 文档范围：`contracts/dtt/ConditionCreateFacet.sol`、`ConditionCalculateFacet.sol`、`ConditionActionFacet.sol`、`TradeStatusFacet.sol`、`SendFacet.sol`、`SettleFacet.sol`
- 文档版本：2026-03-05

## 1. 设计目标

DTT 条件引擎用于把“交易是否可结算”从硬编码逻辑中抽离为可配置条件，支持：

1. 条件建模（SingleCondition / ConditionSet）
2. 条件求值（RightNowMet/NotMet 等）
3. 条件驱动动作（Accept/Reject/SetDate）
4. 条件与结算联动（Realised -> SEND / Void -> REFUND）

## 2. 条件模型

## 2.1 数据结构（`DTTStorage`）

### `SingleCondition`
- `id`
- `conditionType`
- `description`
- `fixFactors[]`
- `dynamicFactors[]`

### `ConditionSet`
- `id`
- `scIDs[]`
- `csIDs[]`
- `join`（AND/OR）

### `ConditionFactor`
- `name` / `value`
- `changeFlag`（是否已修改）
- `changeAble`（当前是否可改）
- `changeAddr`（允许操作地址）
- `beginTime/endTime`
- `commentsHash/filesHash`

## 2.2 交易关联字段

`RealisedTokenTrade` 中条件相关字段：
- `timeScId`：交易时间条件
- `conditionSetId`：业务条件集合
- `partialAcceptScId`：部分接受条件

## 3. 条件类型语义

`ConditionCalculateFacet.querySCStatus` 按 `conditionType` 前缀分支：

1. `T*`：时间条件
2. `A1/A2`：接受型条件（依赖动态因子 `ACCEPT`）
3. `A3/A4`：拒绝型条件（依赖动态因子 `REJECT`）
4. `*v2`：固定窗口型时间，使用 `START_DATE` / `END_DATE`

## 3.1 时间范围计算（`calculateTimeRange`）

1. `v2`：
- begin = `START_DATE`
- end = `END_DATE + 1 day`

2. `T1` / `.1`：
- 依赖动态 `DATE`（未设置则无时间窗）
- begin = `DATE + X*1day`
- end = begin + 1 day

3. `T2` / `.2`：`[0, DATE + 1 day]`
4. `T3` / `.3`：`[DATE, DATE + 1 day]`
5. `T4` / `.4`：`[DATE, max]`

## 4. 状态体系

## 4.1 条件状态

`ConditionStatus`（优先级用于集合归并）：
- `Met`
- `RightNowMet`
- `RightNowNotMet`
- `NotMet`

AND 取“更严格”状态，OR 取“更宽松”状态。

## 4.2 交易状态

`TradeStatusFacet.tradeStatus` 输出：
- `Unrealised`
- `Confirmed`
- `Realised`
- `Void`

`SettleStatus` 输出：
- `INIT` / `SEND` / `REFUND` / `WAIT`

映射关系：
- `SEND -> Realised`
- `REFUND -> Void`
- `INIT -> 按条件动态计算`

## 5. 关键流程

## 5.1 创建流程（`SendFacet.sendRealisedToken`）

1. 校验参数与权限
2. 生成 `businessId`
3. 条件 ID 重构：`businessId_*`
4. 通过 `ConditionCreateFacet.create` 持久化
5. 计算 `tradeStatus`
6. mint ROR（`RorEnhancement.send`）
7. 若 `Realised`，直接调用 `settleTrade`

## 5.2 条件创建校验（`ConditionCreateFacet.create`）

1. `txTimeScID` 必须存在于 `scSet`
2. 交易时间窗结束时间必须晚于当前时间
3. `fixFactors/dynamicFactors` 非空性校验
4. `v2` 下 `START_DATE <= END_DATE`
5. 动态因子若可改，需满足：
- `endTime > now`
- 若交易时间窗存在，`beginTime <= txTimeEnd`
6. `ConditionSet` 去重、非空、join 合法

## 5.3 条件动作流程（`ConditionActionFacet`）

支持动作：
- `conditionAccept`
- `conditionReject`
- `conditionSetDate`

共性前置：
1. 交易 `SettleStatus == INIT`
2. `tradeStatus == Unrealised`
3. 调用者具备 DTT Action 门禁

动作后：
- 重新计算 `tradeStatus`
- 若 `Realised` 或 `Void`，自动 `settleTrade`

## 5.4 `changeFactor` 核心规则

1. 因子存在且索引合法
2. `changeAble == true`
3. `changeFlag == false`
4. `changeAddr == 调用者`
5. 当前时间在 `[beginTime, endTime]`
6. 若是 DATE 设置场景，会刷新同条件下其他动态因子的可改窗口

## 5.5 部分接受（`conditionPartialAccept`）

1. 仅 `partialAcceptAddress` 可调用
2. 父交易需 `INIT` 且 `Unrealised`
3. 生成子交易 `subBusinessId`
4. 复制条件集并对 `partialAcceptScId` 的 `ACCEPT` 自动置位
5. 更新父交易金额与担保金
6. 同步 ROR 关系（`RorEnhancement.partialAccept`）

## 5.6 结算联动（`SettleFacet`）

1. `settleTrade` 仅允许 `INIT` 且 `Realised/Void`
2. `Realised`：
- 若 `amount != guaranteeAmount` -> `WAIT`
- 否则按 ROR 分账转移并置 `SEND`
3. `Void`：退款并置 `REFUND`
4. `settleTradeWithAmount`：仅 `WAIT` 可调用，补款后完成 `SEND`

## 6. 与 ROR/市场的协同

1. `sendRealisedToken` 时铸造 ROR 并绑定 `sendRefId`
2. `partialAccept` 可能触发 ROR 拆分与送达关系重写
3. 结算时通过 `RorEnhancement.settle(sendRefId)` 生成分账清单

## 7. 失败处理与错误码

条件引擎错误码前缀：`SCM_CDN_*`（见 `libraries/Constants.sol`）

高频错误类别：
1. 创建阶段：`SCM_CDN_create_*`
2. 动作阶段：`SCM_CDN_changeFactor_*`
3. 计算阶段：`SCM_CDN_querySCStatus_*`、`SCM_CDN_calculateTimeRange_*`
4. 部分接受：`SCM_CDN_changeFactorWhenPartialAccept_*`

## 8. 测试覆盖映射（当前）

现有测试已覆盖：
1. `conditionAccept`
2. `conditionReject`
3. `conditionSetDate`
4. `conditionPartialAccept`
5. `settleTrade`
6. `settleTradeWithAmount`

对应文件：
- `test/dtt_condition_actions.test.js`
- `test/dtt_send_partial.test.js`
- `test/dtt_settle.test.js`

## 9. 设计约束与改进建议

1. `conditionType` 目前为字符串规则，建议后续引入显式枚举与 schema 校验。
2. 时间因子高度依赖字符串转数字，建议增加更严格输入规范（UTC 秒级）。
3. `ConditionSet` 深层嵌套下链上计算成本较高，建议增加复杂度上限。
4. 建议补充失败路径测试（无权限、窗口过期、错误因子名、非法 join）。

---

该文档定位为“实现对齐版设计说明”。
如需用于审计交付，建议追加：
- 威胁模型
- 状态不变量（Invariant）
- 攻击路径与缓解矩阵

## 10. 条件类型规范表（对接版）

下表用于前后端与合约对接时统一语义。`conditionType` 按字符串包含关系识别（见 `ConditionCalculateFacet.querySCStatus/calculateTimeRange`）。

| 类型 | 语义 | 状态判定关键因子 | 时间窗来源 |
|---|---|---|---|
| `T1` / `.1` | 基于动态日期 + 偏移日数的时间条件 | `DATE`（dynamic）+ `X`（fix） | `[DATE + X*1d, DATE + X*1d + 1d]` |
| `T2` / `.2` | 在某日期前有效 | `DATE`（fix） | `[0, DATE + 1d]` |
| `T3` / `.3` | 在某日期当天有效 | `DATE`（fix） | `[DATE, DATE + 1d]` |
| `T4` / `.4` | 在某日期后持续有效 | `DATE`（fix） | `[DATE, MAX]` |
| `*v2` | 固定起止窗口模式 | `START_DATE` / `END_DATE`（fix） | `[START_DATE, END_DATE + 1d]` |
| `A1` / `A2` | 接受型动作条件 | `ACCEPT`（dynamic） | 动作时窗来自 `beginTime/endTime` |
| `A3` / `A4` | 拒绝型动作条件 | `REJECT`（dynamic） | 动作时窗来自 `beginTime/endTime` |

补充说明：
1. `A1/A2`：`ACCEPT.changeFlag=true` 时 `Met`，否则依据未来可改性判断 `RightNowNotMet/NotMet`。
2. `A3/A4`：`REJECT.changeFlag=true` 时 `NotMet`，否则依据未来可改性判断 `RightNowMet/Met`。
3. `*v2` 是当前测试主要使用模式，推荐业务优先采用。

## 11. `sendRealisedToken` 请求模板（JSON）

以下为前端/服务端构造交易参数的对接模板，字段与 `SendFacet.sendRealisedToken` 一一对应。

注意：
1. 所有时间字段使用 Unix 秒时间戳字符串（与现有合约处理保持一致）。
2. 业务提交前应先离线完成 Permit 签名（ERC20 EIP-2612）。
3. `sc.id`、`cs.id` 在链上会被自动重写为 `businessId_*`。

```json
{
  "to": "0xReceiverAddress",
  "erc20Address": "0xDTTERC20Address",
  "amount": 1000,
  "scs": [
    {
      "id": "SC0",
      "conditionType": "T4:v2",
      "description": "At date [Date]",
      "fixFactors": [
        {
          "name": "END_DATE",
          "value": "1767225600",
          "changeFlag": false,
          "changeAble": false,
          "changeAddr": "0x0000000000000000000000000000000000000000",
          "beginTime": 0,
          "endTime": 0,
          "commentsHash": "",
          "filesHash": []
        },
        {
          "name": "START_DATE",
          "value": "1767139200",
          "changeFlag": false,
          "changeAble": false,
          "changeAddr": "0x0000000000000000000000000000000000000000",
          "beginTime": 0,
          "endTime": 0,
          "commentsHash": "",
          "filesHash": []
        }
      ],
      "dynamicFactors": []
    },
    {
      "id": "SC1",
      "conditionType": "A1.4:v2",
      "description": "Transferer accepts the payment at date [Date]",
      "fixFactors": [
        {
          "name": "END_DATE",
          "value": "1767225600",
          "changeFlag": false,
          "changeAble": false,
          "changeAddr": "0x0000000000000000000000000000000000000000",
          "beginTime": 0,
          "endTime": 0,
          "commentsHash": "",
          "filesHash": []
        },
        {
          "name": "START_DATE",
          "value": "1767139200",
          "changeFlag": false,
          "changeAble": false,
          "changeAddr": "0x0000000000000000000000000000000000000000",
          "beginTime": 0,
          "endTime": 0,
          "commentsHash": "",
          "filesHash": []
        }
      ],
      "dynamicFactors": [
        {
          "name": "ACCEPT",
          "value": "",
          "changeFlag": false,
          "changeAble": true,
          "changeAddr": "0xSenderAddress",
          "beginTime": 1767139200,
          "endTime": 1767225600,
          "commentsHash": "",
          "filesHash": []
        }
      ]
    }
  ],
  "css": [
    {
      "id": "CS1",
      "scIDs": ["SC1"],
      "csIDs": [],
      "join": 0
    }
  ],
  "timeScId": "SC0",
  "csId": "CS1",
  "partialAcceptEnable": true,
  "partialAcceptAddress": "0xSenderAddress",
  "partialAcceptScId": "SC1",
  "deadline": 1767312000,
  "guaranteeAmount": 1000,
  "extension": "biz-ext",
  "permit": {
    "v": 27,
    "r": "0x...",
    "s": "0x..."
  }
}
```

### 11.1 对应 Solidity 调用参数顺序

```solidity
sendRealisedToken(
  to,
  erc20Address,
  amount,
  scs,
  css,
  timeScId,
  csId,
  partialAcceptEnable,
  partialAcceptAddress,
  partialAcceptScId,
  deadline,
  guaranteeAmount,
  extension,
  v,
  r,
  s
)
```

### 11.2 动作接口模板

1. `conditionAccept(businessId, scId, commentsHash, filesHash[])`
2. `conditionReject(businessId, scId, commentsHash, filesHash[])`
3. `conditionSetDate(businessId, scId, dateString, commentsHash, filesHash[])`

其中 `scId` 需要传重写后的 ID，例如：`{businessId}_SC1`。
