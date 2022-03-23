// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract Storage {
    uint256 number;
    string name;

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        number = num;
    }

    /**
     * @dev Return value
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256) {
        return number;
    }

    function setName(string memory _name) public {
        name = _name;
    }

    function getName() public view returns (string memory) {
        return name;
    }

    function sumNumbersBySolidity(uint256[] memory _numbers)
        public
        pure
        returns (uint256 result)
    {
        for (uint256 index = 0; index < _numbers.length; index++) {
            result += _numbers[index];
        }
    }

    function sumNumbersByAssembly(string[] memory _numbers)
        public
        pure
        returns (uint256 result)
    {
        for (uint256 i = 0; i < _numbers.length; i++) {
            assembly {
                result := add(
                    result,
                    mload(add(add(_numbers, 0x20), mul(i, 0x20)))
                )
            }
        }
    }
}
