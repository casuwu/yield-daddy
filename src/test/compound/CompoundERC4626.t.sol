// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {CompoundERC4626} from "../../compound/CompoundERC4626.sol";
import {IComptroller} from "../../compound/external/IComptroller.sol";
import {CompoundERC4626Factory} from
    "../../compound/CompoundERC4626Factory.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}


interface IcToken {
  function mint(uint mintAmount) external returns (uint);
  function redeem(uint redeemTokens) external returns (uint);
  function borrow(uint borrowAmount) external returns (uint);
  function repayBorrow(uint repayAmount) external returns (uint);
  function borrowBalanceCurrent(address account) external returns (uint);
  function balanceOf(address owner) external view returns (uint);
} 

contract CompoundERC4626Test is Test {
    address constant rewardRecipient = address(0x01);

    ERC20 constant underlying = dai;
    IComptroller constant comptroller =
        IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    ERC20 constant dai = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant cDaiAddress = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    address constant cEtherAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    IERC20 constant compAddress = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    IcToken constant cToken = IcToken(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);


    CompoundERC4626 public vault;
    CompoundERC4626Factory public factory;

    function setUp() public {
        factory =
            new CompoundERC4626Factory(comptroller, cEtherAddress, rewardRecipient);
        vault = CompoundERC4626(address(factory.createERC4626(dai)));

        vm.label(address(dai), "DAI");
        vm.label(address(comptroller), "Comptroller");
        vm.label(address(0xABCD), "Alice");
        vm.label(address(0xDCBA), "Bob");
    }

    // function testFailDepositWithNotEnoughApproval() public {
    //     deal(address(underlying), address(this), 0.5e18);
    //     underlying.approve(address(vault), 0.5e18);
    //     assertEq(underlying.allowance(address(this), address(vault)), 0.5e18);

    //     vault.deposit(1e18, address(this), 0);
    // }

    // function testFailWithdrawWithNotEnoughUnderlyingAmount() public {
    //     deal(address(underlying), address(this), 0.5e18);
    //     underlying.approve(address(vault), 0.5e18);

    //     vault.deposit(0.5e18, address(this), 0);

    //     vault.withdraw(1e18, address(this), address(this));
    // }

    // function testFailRedeemWithNotEnoughShareAmount() public {
    //     deal(address(underlying), address(this), 0.5e18);
    //     underlying.approve(address(vault), 0.5e18);

    //     vault.deposit(0.5e18, address(this), 0);

    //     vault.redeem(1e18, address(this), address(this));
    // }

    // function testFailWithdrawWithNoUnderlyingAmount() public {
    //     vault.withdraw(1e18, address(this), address(this));
    // }

    // function testFailRedeemWithNoShareAmount() public {
    //     vault.redeem(1e18, address(this), address(this));
    // }

    // function testFailDepositWithNoApproval() public {
    //     vault.deposit(1e18, address(this), 0);
    // }

    // function testFailMintWithNoApproval() public {
    //     vault.mint(1e18, address(this));
    // }

    // function testFailDepositZero() public {
    //     vault.deposit(0, address(this), 0);
    // }

    // function testMintZero() public {
    //     vault.mint(0, address(this));

    //     assertEq(vault.balanceOf(address(this)), 0);
    //     assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
    //     assertEq(vault.totalSupply(), 0);
    //     assertEq(vault.totalAssets(), 0);
    // }

    // function testFailRedeemZero() public {
    //     vault.redeem(0, address(this), address(this));
    // }

    // function testWithdrawZero() public {
    //     vault.withdraw(0, address(this), address(this));

    //     assertEq(vault.balanceOf(address(this)), 0);
    //     assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
    //     assertEq(vault.totalSupply(), 0);
    //     assertEq(vault.totalAssets(), 0);
    // }

    function testFullRedeemWhenLooped() public {
        deal(address(underlying), address(this), 100e18);
        underlying.approve(address(vault), 100e18);

        vault.deposit(100e18, address(this), 2);
        //After 2 loop with 70% loop, user should have 219 cTokens (cDAI)
        assertEq(vault.balanceOf(address(this)) == 219e18, true);
        // After borrowing, the left over collateral(DAI) is still in the vault
        assertEq(underlying.balanceOf(address(vault)) == 49e18, true);
        vault.withdraw(1e18, address(this), address(this));
        // Make sure depositing acct has 0 after withdrawing
        assertEq(cToken.balanceOf(address(this)), 0);
    }
}
