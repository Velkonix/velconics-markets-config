# K613 Markets Config — MegaETH Mainnet

Configuration for the **K613 lending market** — an Aave v3–compatible money market deployed on top of [K613-Protocol](lib/velkonix-contracts/). This repo does not deploy the core protocol. It declares **which assets are listed**, **what price feeds are used**, **how collateral and interest behave**, and **how reward incentives are distributed** — all as one-shot payloads that `delegatecall` the deployed `AaveV3ConfigEngine`.

<p align="center">
  <img src="image/image.png" alt="Overview" />
</p>

For operational runbooks (deploy / freeze / role rotation), see [DEPLOYMENT.md](DEPLOYMENT.md).

---

## Supported network

| Network         | Chain ID | Market     | Status         |
|-----------------|----------|------------|----------------|
| MegaETH Mainnet | 4326     | `Velkonix` | Primary target |

Oracle decimals `8`, price-feed staleness `3600s`, wrapped native = `WETH` predeploy `0x4200…0006` (native token is ETH — no chain-native LSTs). Canonical protocol addresses (Pool, PoolConfigurator, Oracle, ACLManager, `AaveV3ConfigEngine`, EmissionManager, …) live in [`src/networks/MegaEthMainnet.sol`](src/networks/MegaEthMainnet.sol), parsed from the core deployment broadcast.

> ⚠️ **Price feeds pending.** Only `WETH` has a resolved feed (the network ETH/USD aggregator). `USDm`, `USDe`, `USDT0`, `BTC.b`, `wstETH` carry `*_FEED_PENDING` placeholders in [`K613MegaEth_InitialListing`](src/payloads/K613MegaEth_InitialListing.sol) and **must** be replaced with real aggregators before broadcast. `wstETH` is priced via an `ExchangeRateAdapter` (wstETH/ETH × ETH/USD). `K613MegaEth_InitialListing.hasPendingPriceFeeds()` returns `true` while placeholders remain.

---

## Listed reserves (6 assets)

Initial listing is declared in a single payload, [`K613MegaEth_InitialListing`](src/payloads/K613MegaEth_InitialListing.sol). Every reserve is borrow-enabled, flashloanable, and uses the same liquidation protocol fee (10%). Debt ceiling is zero (no isolation mode on any listing).

### Stablecoins

| Asset | LTV | LT  | LB  | RF  | Borrow cap | Supply cap | Rate curve |
|-------|-----|-----|-----|-----|-----------:|-----------:|------------|
| USDm  | 80% | 83% | 5%  | 25% | 35,000,000 | 40,000,000 | Stablecoin |
| USDe  | 80% | 83% | 5%  | 25% | 25,000,000 | 30,000,000 | Stablecoin |
| USDT0 | 80% | 83% | 5%  | 25% |  8,000,000 | 10,000,000 | Stablecoin |

All three are `borrowableInIsolation = true`. Caps are in whole units of the underlying.

### Blue-chip collateral

| Asset  | LTV | LT  | LB  | RF  | Borrow cap | Supply cap | Rate curve |
|--------|-----|-----|-----|-----|-----------:|-----------:|------------|
| BTC.b  | 68% | 73% | 7%  | 25% |         15 |         20 | Blue-chip  |
| wstETH | 75% | 79% | 6%  | 25% |      2,500 |      3,000 | Blue-chip  |
| WETH   | 78% | 81% | 6%  | 25% |      3,500 |      4,000 | Blue-chip  |

wstETH runs at tighter LTV/LT than WETH to price in LST/ETH basis risk. wstETH has no direct USD Chainlink-style feed — it is priced via [`ExchangeRateAdapter`](src/adapters/ExchangeRateAdapter.sol), which composes `wstETH/ETH × ETH/USD` on the fly and returns `min(updatedAt)` of both sources. The adapter is deployed once by [`DeployAdapters.s.sol`](script/deploy/DeployAdapters.s.sol) and referenced by the listing payload.

### Risk-parameter legend

- **LTV** — max loan-to-value at origination (user's borrow cannot push the ratio above this).
- **LT** — liquidation threshold; positions crossing this are open to liquidation.
- **LB** — liquidation bonus kept by the liquidator (in addition to principal).
- **RF** — reserve factor, share of borrow interest routed to the treasury.
- **Caps** — hard ceilings on total outstanding supply / borrow.

Invariant enforced across every listing: `LTV < LT` and `LT × (1 + LB) ≤ 100%` (no insolvent liquidation path).

### Health factor

`LT` per asset feeds into the portfolio-level **Health Factor (HF)** — the single number that decides whether a position can be liquidated:

```
HF = Σ (collateral_i × price_i × LT_i)  /  Σ (debt_j × price_j)
```

- `HF > 1` — position is healthy.
- `HF = 1` — at the liquidation line.
- `HF < 1` — any keeper can call `liquidationCall` and seize up to 50% (or 100% in close-factor-max regime) of the debt, paying out collateral plus the per-asset `LB`.

Raising a reserve's **supply cap** or **LTV** increases user borrowing power; raising **LT** lets existing positions sag further before liquidation. Because HF is a weighted average, adding a low-LT collateral to a position drags the whole HF down, not just the new asset's slice. eMode (below) rewrites the `LT_i` used in the numerator to the category's LT for every in-category asset — which is why `EMODE_ETH` / `EMODE_STABLE` at `LT = 95%` lets users lever up much higher than the per-asset `LT = 79 – 83%` would allow.

Live HF for any address is dumped by [`UserPosition.s.sol`](script/monitoring/UserPosition.s.sol).

---

## Interest rate curves

Two `DefaultReserveInterestRateStrategy` profiles, keyed on the asset's volatility and liquidity depth.

| Profile    | Optimal U | Base | Slope₁ | Slope₂ | Assets               |
|------------|-----------|------|--------|--------|----------------------|
| Stablecoin | 90%       | 1%   | 4%     | 75%    | USDm, USDe, USDT0    |
| Blue-chip  | 80%       | 1%   | 3.5%   | 80%    | BTC.b, wstETH, WETH  |

Below the optimal utilization the borrow APR rises linearly along `slope₁`; past it the second slope takes over to defend available liquidity. Utilization `U = totalBorrow / totalSupply`.

---

## eMode categories

Declared in [`K613MegaEth_ConfigureEModes`](src/payloads/K613MegaEth_ConfigureEModes.sol). When a user opts into a category, their positions within the category use the **category's** LTV/LT/LB — which are substantially looser than the per-asset defaults — and become capital-efficient for the target trade (leveraged ETH, stablecoin looping). Positions outside the category are rejected while opted in.

| ID | Category       | LTV | LT  | LB  | Members             |
|----|----------------|-----|-----|-----|---------------------|
| 1  | ETH correlated | 93% | 95% | 1%  | WETH, wstETH        |
| 2  | Stablecoins    | 93% | 95% | 1%  | USDm, USDe, USDT0   |

Both categories enable the asset as both collateral and borrowable within the category. `BTC.b` is intentionally left out of every eMode category.

---

## Reward incentives — economics

Supply and borrow emissions are distributed through Aave's `RewardsController` / `EmissionManager`. Per-second emission rates are derived from on-chain weights stored in [`IncentivesConfig`](src/incentives/IncentivesConfig.sol). The reward token is the protocol's own token (an xK613-style governance/reward token); its address is supplied at runtime via `INCENTIVES_REWARD_TOKEN`.

### Yearly budget

| Period    | Total reward tokens | Source constant |
|-----------|---------------------|-----------------|
| Year 1    | 25,000,000          | `YEAR1_TOTAL`   |
| Year 2    | 10,000,000          | `YEAR2_TOTAL`   |
| Year 3    |  5,000,000          | `YEAR3_TOTAL`   |
| **Total** | **40,000,000**      |                 |

For each asset and each side (supply / borrow), the per-second rate is

```
emissionPerSecond = (yearlyTotal × bps) / 10_000 / 365 days
```

truncated to `uint88`. Budget figures are inherited from the prior deployment; retune the `YEAR*_TOTAL` constants if the MegaETH program differs.

### Supply / borrow split

Global split is **65% supply / 35% borrow** across the 6 assets. Supply side is heavier because passive liquidity is what bootstraps a new market; borrowers are additionally compensated by the organic borrow APR, so they need less direct subsidy.

### Per-asset weights (bps of 10,000)

| Asset  | Supply bps | Borrow bps | Total bps | Share of budget |
|--------|-----------:|-----------:|----------:|----------------:|
| USDm   | 1700       | 900        | 2600      | 26.0%           |
| USDe   | 1200       | 700        | 1900      | 19.0%           |
| BTC.b  | 1200       | 600        | 1800      | 18.0%           |
| WETH   |  800       | 500        | 1300      | 13.0%           |
| USDT0  |  800       | 400        | 1200      | 12.0%           |
| wstETH |  800       | 400        | 1200      | 12.0%           |
| **Σ**  | **6500**   | **3500**   | **10000** | **100%**        |

Weights are canonical in [`SetIncentivesWeights.s.sol`](script/incentives/SetIncentivesWeights.s.sol) and written atomically via `IncentivesConfig.setWeights`. Retuning = edit the constants, re-run the script, re-run `ConfigureSupplyIncentives` to push the new per-second rates.

### Constraints enforced on-chain

- `Σ (supplyBps + borrowBps) = 10,000`.
- No duplicate `asset` in a single `setWeights` batch.
- Only `admin` (initially the deployer, rotate to multisig post-launch) can call `setWeights` or `setAdmin`.
- Zero `asset` address is rejected.

### Reward oracle (APR display only)

The reward token has no market price at launch. [`StaticRewardPriceFeed`](src/incentives/StaticRewardPriceFeed.sol) is a fixed-price `AggregatorInterface` used by the UI to render an APR estimate (`INCENTIVES_REWARD_ORACLE_ANSWER` / `_DECIMALS`). It does **not** affect distribution: rewards are paid in whole reward tokens per second regardless of the oracle value. When the reward token lists on a market, swap this for a live feed via `EmissionManager.setRewardOracle`.

---

## Architecture

```
src/
├── networks/
│   ├── NetworkConfig.sol               # Shared Addresses struct + resolvers
│   └── MegaEthMainnet.sol              # Canonical deployed addresses for chain 4326
├── adapters/
│   └── ExchangeRateAdapter.sol         # asset/base × base/USD → USD aggregator
├── incentives/
│   ├── IncentivesConfig.sol            # On-chain (supplyBps, borrowBps) weights, yearly budgets
│   └── StaticRewardPriceFeed.sol       # Fixed-price aggregator for reward token (APR display)
└── payloads/
    ├── K613PayloadMegaEth.sol          # Abstract base wired to MegaEthMainnet.CONFIG_ENGINE
    ├── K613MegaEth_InitialListing.sol  # One-shot payload listing the 6 reserves
    └── K613MegaEth_ConfigureEModes.sol # Blue-chip / stablecoin eMode categories

script/
├── deploy/            DeployAdapters.s.sol                 # wstETH/USD ExchangeRateAdapter
├── operations/        ExecutePayload.s.sol                 # Temp-grants POOL_ADMIN, execute()s, revokes
│                      AdminOps.s.sol                       # One-call PoolConfigurator tweaks
│                      ExecuteEmergencyPayload.s.sol        # setReserveFreeze / setReservePause
├── incentives/        SetIncentivesWeights.s.sol           # Writes the 6-asset 65/35 split
│                      ConfigureSupplyIncentives.s.sol      # Registers aToken + vDebtToken emissions
├── monitoring/        ReserveStatus / HealthCheck / …      # Read-only dashboards
└── admin/             GrantRoles.s.sol                     # Multisig role migration (grant / revoke)
```

### Payload lifecycle

Each payload is a stateless, execute-once contract inheriting `AaveV3Payload`. Its `execute()` `delegatecall`s the deployed `AaveV3ConfigEngine`, which applies every declared change — listings, oracles, collateral parameters, rate strategies, caps, eMode categories — in one transaction. No config contract needs redeploying between payloads, and the engine instance is reused forever.

To apply changes, the caller temporarily grants `POOL_ADMIN` on the MegaETH `ACLManager` to the deployed payload, calls `execute()`, and revokes — all handled by [`ExecutePayload.s.sol`](script/operations/ExecutePayload.s.sol).

---

## Deployment

Full runbook with simulate / broadcast / verify commands per step: **[DEPLOYMENT.md](DEPLOYMENT.md)**.

High-level order:

1. Resolve real price feeds for `USDm`, `USDe`, `USDT0`, `BTC.b`, and the `wstETH/ETH` rate feed.
2. Deploy `ExchangeRateAdapter` for `wstETH` via `DeployAdapters.s.sol`; copy its address into the listing payload.
3. Fill the remaining `*_FEED_PENDING` placeholders in `K613MegaEth_InitialListing` (`hasPendingPriceFeeds()` must return `false`).
4. Execute `K613MegaEth_InitialListing` payload.
5. Execute `K613MegaEth_ConfigureEModes` payload.
6. Deploy `IncentivesConfig`, run `SetIncentivesWeights` (65/35 split).
7. Run `ConfigureSupplyIncentives` (registers emissions on every aToken + variableDebtToken).
8. Grant roles to multisigs, revoke deployer.
9. Rotate `DEFAULT_ADMIN_ROLE` to the main multisig.

---

## Tests

```bash
forge test -vvv
```

Coverage includes:

- **Listing invariants** — `LT × (1 + LB) ≤ 100%`, `LTV < LT`, optimal usage bounded, borrow cap ≤ supply cap, uniform liquidation fee, no duplicate eMode categories.
- **`ExchangeRateAdapter` adversarial** — int256 overflow, `int256.min` guard, extreme decimals (0, 18, 38, 255), mid-flight sign flips.
- **`IncentivesConfig` adversarial** — admin escalation, duplicate assets, zero-sum rejection, `uint88` emission truncation, atomic replacement.

---

## Commands

| Command          | Description       |
|------------------|-------------------|
| `forge build`    | Compile contracts |
| `forge test`     | Run tests         |
| `forge fmt`      | Format Solidity   |
| `forge snapshot` | Gas snapshots     |

## License

MIT
