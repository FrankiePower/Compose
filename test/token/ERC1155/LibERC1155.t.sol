// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC1155Harness} from "./harnesses/LibERC1155Harness.sol";
import {LibERC1155} from "../../../src/token/ERC1155/LibERC1155.sol";

contract LibERC1155Test is Test {
    LibERC1155Harness public harness;

    address public alice;
    address public bob;
    address public charlie;

    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant TOKEN_ID_3 = 3;
    uint256 constant AMOUNT_100 = 100;
    uint256 constant AMOUNT_75 = 75;
    uint256 constant AMOUNT_50 = 50;
    uint256 constant AMOUNT_25 = 25;

    string constant BASE_URI = "https://example.com/api/token/{id}.json";

    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values
    );

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new LibERC1155Harness();
        harness.initialize(BASE_URI);
    }

    // ============================================
    // URI Tests
    // ============================================

    function test_Uri() public view {
        assertEq(harness.uri(), BASE_URI);
    }

    // ============================================
    // Mint Tests
    // ============================================

    function test_Mint() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_Mint_Multiple() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(bob, TOKEN_ID_1, AMOUNT_50);
        harness.mint(alice, TOKEN_ID_2, AMOUNT_25);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), AMOUNT_50);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), AMOUNT_25);
    }

    function test_Mint_SameTokenToSameAddress() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_50);
        harness.mint(alice, TOKEN_ID_1, AMOUNT_50);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_Mint_ZeroAmount() public {
        harness.mint(alice, TOKEN_ID_1, 0);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function testFuzz_Mint(address to, uint256 id, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount < type(uint256).max / 2);

        harness.mint(to, id, amount);

        assertEq(harness.balanceOf(to, id), amount);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(0)));
        harness.mint(address(0), TOKEN_ID_1, AMOUNT_100);
    }

    // ============================================
    // MintBatch Tests
    // ============================================

    function test_MintBatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_100;
        amounts[1] = AMOUNT_50;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), alice, ids, amounts);
        harness.mintBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), AMOUNT_50);
    }

    function test_MintBatch_EmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        harness.mintBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_MintBatch_SingleToken() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_100;

        harness.mintBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_MintBatch_SameTokenMultipleTimes() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_1;
        ids[2] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;
        amounts[2] = AMOUNT_50;

        harness.mintBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_50); // 25 + 25
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), AMOUNT_50);
    }

    function test_MintBatch_AccumulatesWithPreviousMints() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_50);

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_50;

        harness.mintBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_RevertWhen_MintBatchToZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_100;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidReceiver.selector, address(0)));
        harness.mintBatch(address(0), ids, amounts);
    }

    function test_RevertWhen_MintBatchArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = AMOUNT_100;
        amounts[1] = AMOUNT_50;
        amounts[2] = AMOUNT_25;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidArrayLength.selector, 2, 3));
        harness.mintBatch(alice, ids, amounts);
    }

    // ============================================
    // Burn Tests
    // ============================================

    function test_Burn() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), TOKEN_ID_1, AMOUNT_25);
        harness.burn(alice, TOKEN_ID_1, AMOUNT_25);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
    }

    function test_Burn_EntireBalance() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.burn(alice, TOKEN_ID_1, AMOUNT_100);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_Burn_ZeroAmount() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.burn(alice, TOKEN_ID_1, 0);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_Burn_Multiple() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.burn(alice, TOKEN_ID_1, AMOUNT_25);
        harness.burn(alice, TOKEN_ID_1, AMOUNT_25);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_50);
    }

    function testFuzz_Burn(address account, uint256 id, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(account != address(0));
        vm.assume(mintAmount < type(uint256).max / 2);
        vm.assume(burnAmount <= mintAmount);

        harness.mint(account, id, mintAmount);
        harness.burn(account, id, burnAmount);

        assertEq(harness.balanceOf(account, id), mintAmount - burnAmount);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidSender.selector, address(0)));
        harness.burn(address(0), TOKEN_ID_1, AMOUNT_25);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_50);

        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, AMOUNT_50, AMOUNT_100, TOKEN_ID_1)
        );
        harness.burn(alice, TOKEN_ID_1, AMOUNT_100);
    }

    function test_RevertWhen_BurnZeroBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 0, 1, TOKEN_ID_1)
        );
        harness.burn(alice, TOKEN_ID_1, 1);
    }

    // ============================================
    // BurnBatch Tests
    // ============================================

    function test_BurnBatch() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(alice, TOKEN_ID_2, AMOUNT_50);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), alice, address(0), ids, amounts);
        harness.burnBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), AMOUNT_50 - AMOUNT_25);
    }

    function test_BurnBatch_EmptyArrays() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);

        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        harness.burnBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_BurnBatch_SingleToken() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        harness.burnBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
    }

    function test_BurnBatch_EntireBalances() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(alice, TOKEN_ID_2, AMOUNT_50);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_100;
        amounts[1] = AMOUNT_50;

        harness.burnBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), 0);
    }

    function test_BurnBatch_SameTokenMultipleTimes() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;

        harness.burnBatch(alice, ids, amounts);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_50); // 100 - 25 - 25
    }

    function test_RevertWhen_BurnBatchFromZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidSender.selector, address(0)));
        harness.burnBatch(address(0), ids, amounts);
    }

    function test_RevertWhen_BurnBatchArrayLengthMismatch() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;
        amounts[2] = AMOUNT_25;

        vm.expectRevert(abi.encodeWithSelector(LibERC1155.ERC1155InvalidArrayLength.selector, 2, 3));
        harness.burnBatch(alice, ids, amounts);
    }

    function test_RevertWhen_BurnBatchInsufficientBalance() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(alice, TOKEN_ID_2, AMOUNT_25);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_50; // More than alice has for TOKEN_ID_2

        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, AMOUNT_25, AMOUNT_50, TOKEN_ID_2)
        );
        harness.burnBatch(alice, ids, amounts);
    }

    function test_RevertWhen_BurnBatchZeroBalance() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(
            abi.encodeWithSelector(LibERC1155.ERC1155InsufficientBalance.selector, alice, 0, 1, TOKEN_ID_1)
        );
        harness.burnBatch(alice, ids, amounts);
    }

    // ============================================
    // Storage Interaction Tests
    // ============================================

    function test_BalanceOf_AfterMultipleOperations() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(alice, TOKEN_ID_1, AMOUNT_50);
        harness.burn(alice, TOKEN_ID_1, AMOUNT_25);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 + AMOUNT_50 - AMOUNT_25);
    }

    function test_IsApprovedForAll_DefaultFalse() public view {
        assertFalse(harness.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll() public {
        harness.setApprovalForAll(alice, bob, true);
        assertTrue(harness.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll_Revoke() public {
        harness.setApprovalForAll(alice, bob, true);
        harness.setApprovalForAll(alice, bob, false);
        assertFalse(harness.isApprovedForAll(alice, bob));
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintBurnCycle() public {
        // Mint tokens
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);

        // Burn some tokens
        harness.burn(alice, TOKEN_ID_1, AMOUNT_25);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_75);

        // Mint more tokens
        harness.mint(alice, TOKEN_ID_1, AMOUNT_25);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);

        // Burn all tokens
        harness.burn(alice, TOKEN_ID_1, AMOUNT_100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_MintBatchBurnBatchCycle() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = AMOUNT_100;
        mintAmounts[1] = AMOUNT_50;

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = AMOUNT_25;
        burnAmounts[1] = AMOUNT_25;

        // Mint batch
        harness.mintBatch(alice, ids, mintAmounts);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), AMOUNT_50);

        // Burn batch
        harness.burnBatch(alice, ids, burnAmounts);
        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_75);
        assertEq(harness.balanceOf(alice, TOKEN_ID_2), AMOUNT_25);
    }

    function test_MultipleAccounts() public {
        harness.mint(alice, TOKEN_ID_1, AMOUNT_100);
        harness.mint(bob, TOKEN_ID_1, AMOUNT_50);
        harness.mint(charlie, TOKEN_ID_2, AMOUNT_25);

        assertEq(harness.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        assertEq(harness.balanceOf(bob, TOKEN_ID_1), AMOUNT_50);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_1), 0);
        assertEq(harness.balanceOf(charlie, TOKEN_ID_2), AMOUNT_25);
    }
}