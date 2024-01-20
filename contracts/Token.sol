// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8.20;

contract Token is ERC20 {
    uint8 private tokenDecimal;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _tokenDecimal
    ) ERC20(_name, _symbol) {
        tokenDecimal = _tokenDecimal;
    }

    function mint(address _account, uint256 _amount) public {
        _mint(_account, _amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimal;
    }
}
