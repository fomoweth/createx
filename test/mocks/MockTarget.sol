// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockTarget {
	uint256 private _value;

	bytes32 public immutable key;

	constructor(bytes32 _key) payable {
		key = _key;
	}

	function setValue(uint256 value) public {
		_value = value;
	}

	function getValue() public view returns (uint256) {
		return _value;
	}
}
