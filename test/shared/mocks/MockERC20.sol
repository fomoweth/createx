// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockERC20 {
	event Approval(address indexed owner, address indexed spender, uint256 amount);
	event Transfer(address indexed from, address indexed to, uint256 amount);

	mapping(address => mapping(address => uint256)) public allowance;

	mapping(address => uint256) public balanceOf;

	mapping(address => uint256) public nonces;

	uint256 public totalSupply;

	string public name;

	string public symbol;

	uint8 public immutable decimals;

	uint256 internal immutable INITIAL_CHAIN_ID;

	bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

	constructor(string memory _name, string memory _symbol, uint8 _decimals) {
		name = _name;
		symbol = _symbol;
		decimals = _decimals;

		INITIAL_CHAIN_ID = block.chainid;
		INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
	}

	function mint(address to, uint256 amount) public virtual {
		totalSupply += amount;

		// Cannot overflow because the sum of all user
		// balances can't exceed the max uint256 value.
		unchecked {
			balanceOf[to] += amount;
		}

		emit Transfer(address(0), to, amount);
	}

	function burn(address from, uint256 amount) public virtual {
		balanceOf[from] -= amount;

		// Cannot underflow because a user's balance
		// will never be larger than the total supply.
		unchecked {
			totalSupply -= amount;
		}

		emit Transfer(from, address(0), amount);
	}

	function approve(address spender, uint256 amount) public virtual returns (bool) {
		allowance[msg.sender][spender] = amount;

		emit Approval(msg.sender, spender, amount);

		return true;
	}

	function transfer(address to, uint256 amount) public virtual returns (bool) {
		balanceOf[msg.sender] -= amount;

		// Cannot overflow because the sum of all user
		// balances can't exceed the max uint256 value.
		unchecked {
			balanceOf[to] += amount;
		}

		emit Transfer(msg.sender, to, amount);

		return true;
	}

	function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
		uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

		if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

		balanceOf[from] -= amount;

		// Cannot overflow because the sum of all user
		// balances can't exceed the max uint256 value.
		unchecked {
			balanceOf[to] += amount;
		}

		emit Transfer(from, to, amount);

		return true;
	}

	function permit(
		address owner,
		address spender,
		uint256 value,
		uint256 deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public virtual {
		require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

		// Unchecked because the only math done is incrementing
		// the owner's nonce which cannot realistically overflow.
		unchecked {
			address recoveredAddress = ecrecover(
				keccak256(
					abi.encodePacked(
						"\x19\x01",
						DOMAIN_SEPARATOR(),
						keccak256(
							abi.encode(
								keccak256(
									"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
								),
								owner,
								spender,
								value,
								nonces[owner]++,
								deadline
							)
						)
					)
				),
				v,
				r,
				s
			);

			require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

			allowance[recoveredAddress][spender] = value;
		}

		emit Approval(owner, spender, value);
	}

	function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
		return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
	}

	function computeDomainSeparator() internal view virtual returns (bytes32) {
		return
			keccak256(
				abi.encode(
					keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
					keccak256(bytes(name)),
					keccak256("1"),
					block.chainid,
					address(this)
				)
			);
	}
}
