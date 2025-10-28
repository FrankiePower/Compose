// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1155Facet} from "../../../src/token/ERC1155/ERC1155Facet.sol";
import {ERC1155FacetHarness} from "./harnesses/ERC1155FacetHarness.sol";

contract ERC1155Receiver {
    bytes4 public constant ERC1155_RECEIVED = 0xf23a6e61;
    bytes4 public constant ERC1155_BATCH_RECEIVED = 0xbc197c81;

    bool public shouldReject;
    bool public shouldRevert;
    string public revertMessage;

    function setShouldReject(bool _shouldReject) external {
        shouldReject = _shouldReject;
    }

    function setShouldRevert(bool _shouldRevert, string memory _message) external {
        shouldRevert = _shouldRevert;
        revertMessage = _message;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        if (shouldRevert) {
            revert(revertMessage);
        }
        if (shouldReject) {
            return 0xffffffff;
        }
        return ERC1155_RECEIVED;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        view
        returns (bytes4)
    {
        if (shouldRevert) {
            revert(revertMessage);
        }
        if (shouldReject) {
            return 0xffffffff;
        }
        return ERC1155_BATCH_RECEIVED;
    }
}

contract ERC1155FacetTest is Test {
    ERC1155FacetHarness public token;

    address public alice;
    address public bob;
    address public charlie;
    address public operator;

    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant TOKEN_ID_3 = 3;
    uint256 constant AMOUNT_100 = 100;
    uint256 constant AMOUNT_50 = 50;
    uint256 constant AMOUNT_25 = 25;

    string constant BASE_URI = "https://example.com/api/token/{id}.json";

    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values
    );
    event ApprovalForAll(address indexed _account, address indexed _operator, bool _approved);
    event URI(string _value, uint256 indexed _id);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        operator = makeAddr("operator");

        token = new ERC1155FacetHarness();
        token.initialize(BASE_URI);

        // Mint initial tokens to alice
        token.mint(alice, TOKEN_ID_1, AMOUNT_100, "");
        token.mint(alice, TOKEN_ID_2, AMOUNT_50, "");
    }

    // ============================================
    // URI Tests
    // ============================================

    function test_Uri() public view {
        assertEq(token.uri(TOKEN_ID_1), BASE_URI);
        assertEq(token.uri(TOKEN_ID_2), BASE_URI);
        assertEq(token.uri(999), BASE_URI); // Same URI for all tokens
    }

    // ============================================
    // Balance Tests
    // ============================================

    function test_BalanceOf() public view {
        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), AMOUNT_50);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function test_BalanceOfBatch() public view {
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = alice;
        accounts[2] = bob;

        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_1;

        uint256[] memory balances = token.balanceOfBatch(accounts, ids);

        assertEq(balances[0], AMOUNT_100);
        assertEq(balances[1], AMOUNT_50);
        assertEq(balances[2], 0);
    }

    function test_RevertWhen_BalanceOfBatchArrayLengthMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        uint256[] memory ids = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidArrayLength.selector, 3, 2));
        token.balanceOfBatch(accounts, ids);
    }

    // ============================================
    // Approval Tests
    // ============================================

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, operator, true);
        token.setApprovalForAll(operator, true);

        assertTrue(token.isApprovedForAll(alice, operator));
    }

    function test_SetApprovalForAll_Revoke() public {
        vm.prank(alice);
        token.setApprovalForAll(operator, true);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, operator, false);
        token.setApprovalForAll(operator, false);

        assertFalse(token.isApprovedForAll(alice, operator));
    }

    function test_RevertWhen_SetApprovalForAll_ZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidOperator.selector, address(0)));
        token.setApprovalForAll(address(0), true);
    }

    function test_IsApprovedForAll_Default() public view {
        assertFalse(token.isApprovedForAll(alice, operator));
    }

    // ============================================
    // SafeTransferFrom Tests
    // ============================================

    function test_SafeTransferFrom() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, TOKEN_ID_1, AMOUNT_25);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, AMOUNT_25, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), AMOUNT_25);
    }

    function test_SafeTransferFrom_ToSelf() public {
        vm.prank(alice);
        token.safeTransferFrom(alice, alice, TOKEN_ID_1, AMOUNT_25, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_SafeTransferFrom_ZeroAmount() public {
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 0, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function test_SafeTransferFrom_EntireBalance() public {
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, AMOUNT_100, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), AMOUNT_100);
    }

    function test_SafeTransferFrom_WithOperator() public {
        vm.prank(alice);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(operator, alice, bob, TOKEN_ID_1, AMOUNT_25);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, AMOUNT_25, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), AMOUNT_25);
    }

    function test_SafeTransferFrom_WithData() public {
        bytes memory data = "test data";

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, AMOUNT_25, data);

        assertEq(token.balanceOf(bob, TOKEN_ID_1), AMOUNT_25);
    }

    function test_SafeTransferFrom_ToContract() public {
        ERC1155Receiver receiver = new ERC1155Receiver();

        vm.prank(alice);
        token.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, AMOUNT_25, "");

        assertEq(token.balanceOf(address(receiver), TOKEN_ID_1), AMOUNT_25);
    }

    function testFuzz_SafeTransferFrom(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0); // EOA only for fuzzing
        vm.assume(amount <= AMOUNT_100);

        vm.prank(alice);
        token.safeTransferFrom(alice, to, TOKEN_ID_1, amount, "");

        if (to == alice) {
            assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
        } else {
            assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - amount);
            assertEq(token.balanceOf(to, TOKEN_ID_1), amount);
        }
    }

    function test_RevertWhen_SafeTransferFrom_ZeroAddressReceiver() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        token.safeTransferFrom(alice, address(0), TOKEN_ID_1, AMOUNT_25, "");
    }

    function test_RevertWhen_SafeTransferFrom_ZeroAddressSender() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        token.safeTransferFrom(address(0), bob, TOKEN_ID_1, AMOUNT_25, "");
    }

    function test_RevertWhen_SafeTransferFrom_InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, AMOUNT_100, AMOUNT_100 + 1, TOKEN_ID_1)
        );
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, AMOUNT_100 + 1, "");
    }

    function test_RevertWhen_SafeTransferFrom_NotApproved() public {
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155MissingApprovalForAll.selector, operator, alice));
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, AMOUNT_25, "");
    }

    function test_RevertWhen_SafeTransferFrom_ContractRejectsTransfer() public {
        ERC1155Receiver receiver = new ERC1155Receiver();
        receiver.setShouldReject(true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(receiver)));
        token.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, AMOUNT_25, "");
    }

    function test_RevertWhen_SafeTransferFrom_ContractRevertsWithMessage() public {
        ERC1155Receiver receiver = new ERC1155Receiver();
        receiver.setShouldRevert(true, "Custom revert reason");

        vm.prank(alice);
        vm.expectRevert("Custom revert reason");
        token.safeTransferFrom(alice, address(receiver), TOKEN_ID_1, AMOUNT_25, "");
    }

    // ============================================
    // SafeBatchTransferFrom Tests
    // ============================================

    function test_SafeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, amounts);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), AMOUNT_50 - AMOUNT_25);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), AMOUNT_25);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), AMOUNT_25);
    }

    function test_SafeBatchTransferFrom_EmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100);
    }

    function test_SafeBatchTransferFrom_WithOperator() public {
        vm.prank(alice);
        token.setApprovalForAll(operator, true);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;

        vm.prank(operator);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(bob, TOKEN_ID_1), AMOUNT_25);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), AMOUNT_25);
    }

    function test_SafeBatchTransferFrom_ToContract() public {
        ERC1155Receiver receiver = new ERC1155Receiver();

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, address(receiver), ids, amounts, "");

        assertEq(token.balanceOf(address(receiver), TOKEN_ID_1), AMOUNT_25);
        assertEq(token.balanceOf(address(receiver), TOKEN_ID_2), AMOUNT_25);
    }

    function test_RevertWhen_SafeBatchTransferFrom_ZeroAddressReceiver() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        token.safeBatchTransferFrom(alice, address(0), ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_ZeroAddressSender() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        token.safeBatchTransferFrom(address(0), bob, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_ArrayLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = AMOUNT_25;
        amounts[1] = AMOUNT_25;
        amounts[2] = AMOUNT_25;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidArrayLength.selector, 2, 3));
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_InsufficientBalance() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = AMOUNT_100;
        amounts[1] = AMOUNT_50 + 1; // More than alice has

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, AMOUNT_50, AMOUNT_50 + 1, TOKEN_ID_2)
        );
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_NotApproved() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155MissingApprovalForAll.selector, operator, alice));
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_ContractRejectsTransfer() public {
        ERC1155Receiver receiver = new ERC1155Receiver();
        receiver.setShouldReject(true);

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(receiver)));
        token.safeBatchTransferFrom(alice, address(receiver), ids, amounts, "");
    }

    function test_RevertWhen_SafeBatchTransferFrom_ContractRevertsWithMessage() public {
        ERC1155Receiver receiver = new ERC1155Receiver();
        receiver.setShouldRevert(true, "Batch transfer rejected");

        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = AMOUNT_25;

        vm.prank(alice);
        vm.expectRevert("Batch transfer rejected");
        token.safeBatchTransferFrom(alice, address(receiver), ids, amounts, "");
    }

    // ============================================
    // Mint Tests (Harness Only)
    // ============================================

    function test_Mint() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), charlie, TOKEN_ID_3, AMOUNT_100);
        token.mint(charlie, TOKEN_ID_3, AMOUNT_100, "");

        assertEq(token.balanceOf(charlie, TOKEN_ID_3), AMOUNT_100);
    }

    function test_RevertWhen_Mint_ZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidReceiver.selector, address(0)));
        token.mint(address(0), TOKEN_ID_1, AMOUNT_100, "");
    }

    // ============================================
    // Burn Tests (Harness Only)
    // ============================================

    function test_Burn() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), TOKEN_ID_1, AMOUNT_25);
        token.burn(alice, TOKEN_ID_1, AMOUNT_25);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), AMOUNT_100 - AMOUNT_25);
    }

    function test_RevertWhen_Burn_InsufficientBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155Facet.ERC1155InsufficientBalance.selector, alice, AMOUNT_100, AMOUNT_100 + 1, TOKEN_ID_1)
        );
        token.burn(alice, TOKEN_ID_1, AMOUNT_100 + 1);
    }

    function test_RevertWhen_Burn_ZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Facet.ERC1155InvalidSender.selector, address(0)));
        token.burn(address(0), TOKEN_ID_1, AMOUNT_25);
    }
}