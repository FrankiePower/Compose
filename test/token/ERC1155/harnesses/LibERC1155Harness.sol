// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibERC1155} from "../../../../src/token/ERC1155/LibERC1155.sol";

/// @title LibERC1155Harness
/// @notice Test harness that exposes LibERC1155's internal functions as external
/// @dev Required for testing since LibERC1155 only has internal functions
contract LibERC1155Harness {
    /// @notice Initialize the ERC1155 token storage
    /// @dev Only used for testing
    function initialize(string memory _uri) external {
        LibERC1155.ERC1155Storage storage s = LibERC1155.getStorage();
        s.uri = _uri;
    }

    /// @notice Exposes LibERC1155.mint as an external function
    function mint(address _to, uint256 _id, uint256 _value) external {
        LibERC1155.mint(_to, _id, _value);
    }

    /// @notice Exposes LibERC1155.mintBatch as an external function
    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values) external {
        LibERC1155.mintBatch(_to, _ids, _values);
    }

    /// @notice Exposes LibERC1155.burn as an external function
    function burn(address _from, uint256 _id, uint256 _value) external {
        LibERC1155.burn(_from, _id, _value);
    }

    /// @notice Exposes LibERC1155.burnBatch as an external function
    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) external {
        LibERC1155.burnBatch(_from, _ids, _values);
    }

    /// @notice Get storage values for testing
    function uri() external view returns (string memory) {
        return LibERC1155.getStorage().uri;
    }

    function balanceOf(address _account, uint256 _id) external view returns (uint256) {
        return LibERC1155.getStorage().balanceOf[_id][_account];
    }

    function isApprovedForAll(address _account, address _operator) external view returns (bool) {
        return LibERC1155.getStorage().isApprovedForAll[_account][_operator];
    }

    /// @notice Helper to set approval for testing
    function setApprovalForAll(address _owner, address _operator, bool _approved) external {
        LibERC1155.ERC1155Storage storage s = LibERC1155.getStorage();
        s.isApprovedForAll[_owner][_operator] = _approved;
    }
}