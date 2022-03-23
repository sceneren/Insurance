// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 feePercent;

    constructor(uint256 initialSupply, uint256 _feePercent)
        ERC20("MyToken", "MT")
    {
        _mint(msg.sender, initialSupply);
        feePercent = _feePercent;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        uint256 fee = amount.mul(feePercent).div(100);

        _transfer(_msgSender(), address(this), fee);

        _transfer(_msgSender(), recipient, amount.sub(fee));

        return true;
    }

    function getFee() public view returns (uint256) {
        return feePercent;
    }
}
