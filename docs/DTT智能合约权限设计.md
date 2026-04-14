# DTT智能合约权限设计

## 1. 角色模型

`UserPermission` 使用 OpenZeppelin `AccessControlEnumerable`，主要角色：

- `DEFAULT_ADMIN_ROLE`
  - 超级管理员，管理所有角色的授予与撤销。起初为合约部署者，合约部署完成后执行转让和销毁操作，由多签智能合约钱包控制。
- `ISSUER_ROLE`
  - 发行方角色，由DEFAULT_ADMIN_ROLE角色授予发行方钱包地址。

## 2. 业务权限

**数值编码设计**：`UserPermission` 以 `uint256` 数值编码权限，`Permission.sol` 通过不同“十进制位”实现门禁校验。

只有拥有`ISSUER_ROLE`角色的地址才能调用 `setPermission` 为普通企业设置权限。

> 判定规则：对应位 **<= 1** 时拒绝（revert），**>= 2** 允许。

| 权限位（十进制） | 取值来源 | 控制能力 |
|---|---|---|
| 1 位（个位） | `permission % 10` | ERC20 Transfer  In |
| 10 位（十位） | `permission / 10 % 10` | ERC20 Transfer Out |
| 100 位（百位） | `permission / 100 % 10` | Encash |
| 1000 位（千位） | `permission / 1000 % 10` | DTT RtSend |
| 10000 位（万位） | `permission / 10000 % 10` | DTT RtSendTradeAction |
| 100000 位（十万位） | `permission / 100000 % 10` | ERC721 Transfer  In |
| 1000000 位（百万位） | `permission / 1000000 % 10` | ERC721 Transfer  Out |

## 3. 运维权限

运维类权限不使用 `UserPermission` 的“数值编码”，而是由合约内的 **Owner ** 角色控制：

- 负责合约升级（UUPS / Diamond）

- 负责暂停/恢复
- 核心配置变更

在生产环境中，**Owner** 的权限由多签智能合约钱包控制，确保升级/暂停/配置等高危操作的安全性。
