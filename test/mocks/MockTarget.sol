// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockTarget {
	uint256 private _value;

	constructor() payable {}

	function setValue(uint256 value) public returns (uint256) {
		return _value = value;
	}

	function getValue() public view returns (uint256) {
		return _value;
	}
}
