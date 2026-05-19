// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IncentivesConfig
/// @notice Per-asset supply/borrow emission weights for Velkonix incentives.
/// @dev Weights are keyed by underlying asset address. The sum of `supplyBps + borrowBps`
///      across all configured assets must equal `WEIGHT_BPS` (10_000 = 100%).
///      Supply/borrow split is per-asset — different assets can use different ratios.
///      Storage is an append-only list of assets plus an index mapping; `setWeights` replaces
///      the whole set atomically.
contract IncentivesConfig {
    /// @notice Caller is not `admin`.
    error Unauthorized();
    /// @notice `newAdmin` or constructor `initialAdmin` was zero.
    error InvalidAdmin();
    /// @notice Sum of `supplyBps + borrowBps` across weights did not equal `WEIGHT_BPS`.
    error InvalidWeightsSum();
    /// @notice `setWeights` received an empty array.
    error InvalidWeightsLength();
    /// @notice Weight row used zero `asset`.
    error ZeroAsset();
    /// @notice Duplicate underlying in the same `setWeights` batch.
    /// @param asset Repeated asset address.
    error DuplicateAsset(address asset);

    /// @notice Emitted when `admin` is rotated.
    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    /// @notice Emitted after `setWeights` replaces the stored weight vector.
    event WeightsUpdated(AssetWeight[] weights);

    uint256 public constant WEIGHT_BPS = 10_000;

    /// @notice Total Velkonix emitted in year one (25M tokens, 18 decimals).
    uint256 public constant YEAR1_TOTAL = 25_000_000e18;
    /// @notice Total Velkonix emitted in year two (10M tokens, 18 decimals).
    uint256 public constant YEAR2_TOTAL = 10_000_000e18;
    /// @notice Total Velkonix emitted in year three (5M tokens, 18 decimals).
    uint256 public constant YEAR3_TOTAL = 5_000_000e18;

    address public admin;

    /// @notice Per-asset share of the yearly budget.
    /// @param asset Underlying asset address (key).
    /// @param supplyBps Share allocated to the asset's aToken holders.
    /// @param borrowBps Share allocated to the asset's variableDebtToken holders.
    struct AssetWeight {
        address asset;
        uint256 supplyBps;
        uint256 borrowBps;
    }

    /// @notice Emission rate snapshot for a single reserve, derived from a stored weight.
    struct EmissionConfig {
        address asset;
        uint88 supplyEmissionPerSecond;
        uint88 borrowEmissionPerSecond;
        uint256 supplyBps;
        uint256 borrowBps;
    }

    AssetWeight[] private weights;

    /// @notice Sets `admin` to `initialAdmin` with an empty weight list.
    /// @param initialAdmin Non-zero governance key.
    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert InvalidAdmin();
        admin = initialAdmin;
    }

    /// @notice Restricts mutating calls to `admin`.
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /// @notice Transfers admin to `newAdmin`.
    /// @param newAdmin Non-zero successor address.
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAdmin();
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(previousAdmin, newAdmin);
    }

    /// @notice Replaces the per-asset weights atomically.
    /// @param newWeights Flat list of `(asset, supplyBps, borrowBps)`. Sum must equal `WEIGHT_BPS`.
    function setWeights(AssetWeight[] calldata newWeights) external onlyAdmin {
        if (newWeights.length == 0) revert InvalidWeightsLength();

        uint256 sum = 0;
        for (uint256 i = 0; i < newWeights.length; ++i) {
            address a = newWeights[i].asset;
            if (a == address(0)) revert ZeroAsset();
            for (uint256 j = 0; j < i; ++j) {
                if (newWeights[j].asset == a) revert DuplicateAsset(a);
            }
            sum += newWeights[i].supplyBps + newWeights[i].borrowBps;
        }
        if (sum != WEIGHT_BPS) revert InvalidWeightsSum();

        weights = newWeights;
        emit WeightsUpdated(newWeights);
    }

    /// @notice Returns a memory copy of all stored weights in order.
    /// @return out Flat list of per-asset bps weights.
    function getWeights() external view returns (AssetWeight[] memory out) {
        uint256 n = weights.length;
        out = new AssetWeight[](n);
        for (uint256 i = 0; i < n; ++i) {
            out[i] = weights[i];
        }
    }

    /// @notice Returns how many weight rows are stored.
    /// @return Length of the internal weight vector.
    function weightCount() external view returns (uint256) {
        return weights.length;
    }

    /// @notice Derives per-second emission rates for every stored weight.
    /// @param yearlyTotal Total Velkonix emitted during the year (e.g. `YEAR1_TOTAL`).
    function getEmissionConfigs(uint256 yearlyTotal) external view returns (EmissionConfig[] memory configs) {
        uint256 n = weights.length;
        configs = new EmissionConfig[](n);
        for (uint256 i = 0; i < n; ++i) {
            AssetWeight memory w = weights[i];
            uint256 supplyYearly = (yearlyTotal * w.supplyBps) / WEIGHT_BPS;
            uint256 borrowYearly = (yearlyTotal * w.borrowBps) / WEIGHT_BPS;
            configs[i] = EmissionConfig({
                asset: w.asset,
                supplyEmissionPerSecond: uint88(supplyYearly / 365 days),
                borrowEmissionPerSecond: uint88(borrowYearly / 365 days),
                supplyBps: w.supplyBps,
                borrowBps: w.borrowBps
            });
        }
    }
}
