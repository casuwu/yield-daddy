// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {ICERC20} from "./external/ICERC20.sol";
import {LibCompound} from "./lib/LibCompound.sol";
import {IComptroller} from "./external/IComptroller.sol";

/// @title CompoundERC4626
/// @author zefram.eth
/// @notice ERC4626 wrapper for Compound Finance
contract CompoundERC4626 is ERC4626 {
    /// -----------------------------------------------------------------------
    /// Libraries usage
    /// -----------------------------------------------------------------------

    using LibCompound for ICERC20;
    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// @notice Thrown when a call to Compound returned an error.
    /// @param errorCode The error code returned by Compound
    error CompoundERC4626__CompoundError(uint256 errorCode);

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    uint256 internal constant NO_ERROR = 0;

    /// -----------------------------------------------------------------------
    /// Immutable params
    /// -----------------------------------------------------------------------

    /// @notice The COMP token contract
    ERC20 public immutable comp;

    /// @notice The Compound cToken contract
    ICERC20 public immutable cToken;

    /// @notice The address that will receive the liquidity mining rewards (if any)
    address public immutable rewardRecipient;

    /// @notice The Compound comptroller contract
    IComptroller public immutable comptroller;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        ERC20 asset_,
        ERC20 comp_,
        ICERC20 cToken_,
        address rewardRecipient_,
        IComptroller comptroller_
    ) payable
        ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        comp = comp_;
        cToken = cToken_;
        comptroller = comptroller_;
        rewardRecipient = rewardRecipient_;
    }

    /// -----------------------------------------------------------------------
    /// Compound liquidity mining
    /// -----------------------------------------------------------------------

    /// @notice Claims liquidity mining rewards from Compound and sends it to rewardRecipient
    function claimRewards() external returns(uint256) {
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        comptroller.claimComp(address(this), cTokens);
        comp.safeTransfer(rewardRecipient, comp.balanceOf(address(this)));
        comp.balanceOf(rewardRecipient);
    }

        /// @notice Claims liquidity mining rewards from Compound and sends it to rewardRecipient
    function borrow(uint256 amount) external returns(uint256) {
        cToken.borrow(amount);
    }

    function compRate() public returns(uint256) {
        uint256 globalComp = comptroller.compRate();
    }

    function compRatePerMarket() public returns(uint256 marketComp) {
        marketComp = comptroller.compSupplySpeeds(address(cToken));                                                                               
    }

    function compReceivable() public returns(uint256 rewards) {
        rewards = comptroller.compReceivable(msg.sender);                                                                               
    }

    /// -----------------------------------------------------------------------
    /// ERC4626 overrides
    /// -----------------------------------------------------------------------

    function totalAssets() public view virtual override returns (uint256) {
        return cToken.viewUnderlyingBalanceOf(address(this));
    }

    function beforeWithdraw(uint256 assets, uint256 /*shares*/ )
        internal
        virtual
        override
    {
        /// -----------------------------------------------------------------------
        /// Withdraw assets from Compound
        /// -----------------------------------------------------------------------

        uint256 errorCode = cToken.redeemUnderlying(assets);
        if (errorCode != NO_ERROR) {
            revert CompoundERC4626__CompoundError(errorCode);
        }
    }

    function afterDeposit(uint256 assets, uint256 iterations, address receiver)
        internal
        virtual
        override
    {
        
        // approve to cToken
         
       if(iterations < 1) {

        asset.safeApprove(address(cToken), assets);
        
        uint256 errorCode = cToken.mint(assets);

        if (errorCode != NO_ERROR)  revert CompoundERC4626__CompoundError(errorCode);

       } else {

            uint256 nextCollateralAmount = assets;
            // Once we've looped through
            // Transfer surplus DAI back to the user
            for(uint256 i = 0; i < iterations;) {
                // just do a max approve once, save some gas?
                asset.safeApprove(address(cToken), nextCollateralAmount);

                uint256 errorCode = cToken.mint(nextCollateralAmount);
                if (errorCode != NO_ERROR)  revert CompoundERC4626__CompoundError(errorCode);

                nextCollateralAmount = (nextCollateralAmount * 70) / 100;

                uint256 borrowErrorCode = cToken.borrow(nextCollateralAmount);
                _mint(receiver, nextCollateralAmount);
                // emit Deposit(msg.sender, receiver, assets, shares);

                if (borrowErrorCode != NO_ERROR) {
                    revert CompoundERC4626__CompoundError(errorCode);
                }

                unchecked {++i;}
            }
        }
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) return 0;
        return type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) return 0;
        return type(uint256).max;
    }

    function maxWithdraw(address owner)
        public
        view
        override
        returns (uint256)
    {
        uint256 cash = cToken.getCash();
        uint256 assetsBalance = convertToAssets(balanceOf[owner]);
        return cash < assetsBalance ? cash : assetsBalance;
    }

    function maxRedeem(address owner)
        public
        view
        override
        returns (uint256)
    {
        uint256 cash = cToken.getCash();
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }

    /// -----------------------------------------------------------------------
    /// ERC20 metadata generation
    /// -----------------------------------------------------------------------

    function _vaultName(ERC20 asset_)
        internal
        view
        virtual
        returns (string memory vaultName)
    {
        vaultName = string.concat("ERC4626-Wrapped Compound ", asset_.symbol());
    }

    function _vaultSymbol(ERC20 asset_)
        internal
        view
        virtual
        returns (string memory vaultSymbol)
    {
        vaultSymbol = string.concat("wc", asset_.symbol());
    }
}