// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/aave/IDataProvider.sol";
import "./interfaces/aave/IAaveV3Incentives.sol";
import "./interfaces/aave/ILendingPool.sol";

contract SimpleStakingPool is Ownable, Pausable {
    // Tokens used
    address public token;
    address public aToken;

    // Third party contracts
    address public dataProvider;
    address public lendingPool;
    address public incentivesController;

    uint256 public lastHarvest;

    event Deposit(address indexed user);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        address _dataProvider,
        address _lendingPool,
        address _incentivesController,
        address _token
    ) Ownable(msg.sender) {
        token = _token;
        dataProvider = _dataProvider;
        lendingPool = _lendingPool;
        incentivesController = _incentivesController;

        (aToken, , ) = IDataProvider(dataProvider).getReserveTokensAddresses(
            token
        );

        _giveAllowances();
    }

    function deposit() public whenNotPaused {
        emit Deposit(msg.sender);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        ILendingPool(lendingPool).withdraw(token, _amount, address(this));
        emit Withdraw(msg.sender, _amount);
    }

    // return supply and borrow balance
    function userReserves() public view returns (uint256, uint256) {
        (uint256 supplyBal, , uint256 borrowBal, , , , , , ) = IDataProvider(
            dataProvider
        ).getUserReserveData(token, address(this));
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
        IERC20(token).approve(lendingPool, type(uint).max);
    }

    function _removeAllowances() internal {
        IERC20(token).approve(lendingPool, 0);
    }
}
