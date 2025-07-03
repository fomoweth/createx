// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockTarget {
	error InitializedAlready();

	event Initialized(address indexed msgSender, uint256 indexed msgValue, uint256 indexed value);

	bool private _initialized;

	uint256 private _value;

	bytes32 public immutable key;

	constructor(bytes32 _key) payable {
		key = _key;
	}

	function initialize(uint256 value) external payable {
		if (_initialized) revert InitializedAlready();

		_value = value;
		_initialized = true;

		emit Initialized(msg.sender, msg.value, value);
	}

	function setValue(uint256 value) public {
		_value = value;
	}

	function getValue() public view returns (uint256) {
		return _value;
	}

	function isInitialized() public view returns (bool) {
		return _initialized;
	}

	receive() external payable {}
}
