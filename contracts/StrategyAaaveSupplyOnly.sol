// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/aave/IDataProvider.sol";
import "./interfaces/aave/IAaveV3Incentives.sol";
import "./interfaces/aave/ILendingPool.sol";

contract StrategyAaveSupplyOnly is Ownable, Pausable {
    // Tokens used
    address public want;
    address public aToken;

    // Third party contracts
    address public dataProvider;
    address public lendingPool;
    address public incentivesController;

    uint256 public lastHarvest;

    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _dataProvider,
        address _lendingPool,
        address _incentivesController,
        address _want
    ) Ownable(msg.sender) {
        want = _want;
        dataProvider = _dataProvider;
        lendingPool = _lendingPool;
        incentivesController = _incentivesController;

        (aToken, , ) = IDataProvider(dataProvider).getReserveTokensAddresses(
            want
        );

        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            ILendingPool(lendingPool).deposit(want, wantBal, address(this), 0);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 _amount) external {
        uint256 wantBal = balanceOfWant();
        if (wantBal < _amount) {
            ILendingPool(lendingPool).withdraw(
                want,
                _amount - wantBal,
                address(this)
            );
            wantBal = balanceOfWant();
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        emit Withdraw(balanceOf());
    }

    function beforeDeposit() external {
        _harvest();
    }

    function harvest() external virtual {
        _harvest();
    }

    function managerHarvest() external onlyOwner {
        _harvest();
    }

    // compounds earnings and charges performance fee
    function _harvest() internal whenNotPaused {
        address[] memory assets = new address[](1);
        assets[0] = aToken;
        IAaveV3Incentives(incentivesController).claimRewards(
            assets,
            type(uint).max,
            address(this),
            want
        );

        deposit();

        lastHarvest = block.timestamp;
    }

    // return supply and borrow balance
    function userReserves() public view returns (uint256, uint256) {
        (uint256 supplyBal, , uint256 borrowBal, , , , , , ) = IDataProvider(
            dataProvider
        ).getUserReserveData(want, address(this));
        return (supplyBal, borrowBal);
    }

    // returns the user account data across all the reserves
    function userAccountData()
        public
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return ILendingPool(lendingPool).getUserAccountData(address(this));
    }

    // calculate the total underlaying 'want' held by the strat.
    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view returns (uint256) {
        (uint256 supplyBal, uint256 borrowBal) = userReserves();
        return supplyBal - borrowBal;
    }

    // returns rewards unharvested
    function rewardsAvailable() public view returns (uint256) {
        address[] memory assets = new address[](1);
        assets[0] = aToken;
        return
            IAaveV3Incentives(incentivesController).getUserRewards(
                assets,
                address(this),
                want
            );
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        ILendingPool(lendingPool).withdraw(want, type(uint).max, address(this));
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyOwner {
        ILendingPool(lendingPool).withdraw(want, type(uint).max, address(this));
        pause();
    }

    function pause() public onlyOwner {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyOwner {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function _giveAllowances() internal {
        IERC20(want).approve(lendingPool, type(uint).max);
    }

    function _removeAllowances() internal {
        IERC20(want).approve(lendingPool, 0);
    }
}
