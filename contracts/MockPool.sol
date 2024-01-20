// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHandler.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

pragma solidity ^0.8.20;

contract MockPool is IPool {
    mapping(address => uint256) private supplyAmount;
    mapping(address => uint256) private withDrawAmount;
    mapping(address => uint16) private refferalcode;

    address private aToken;

    constructor(address _aToken) {
        aToken = _aToken;
    }

    function getSupplyAmount(address _address) public view returns (uint256) {
        return supplyAmount[_address];
    }

    function getWithDrawAmount(address _address) public view returns (uint256) {
        return withDrawAmount[_address];
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external override {
        supplyAmount[msg.sender] += amount;
        withDrawAmount[msg.sender] += amount + (amount / 20); // 5%
        refferalcode[msg.sender] = referralCode;

        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(aToken).mint(onBehalfOf, amount + (amount / 20)); // 5%
    }

    function withdraw(
        address asset,
        uint256 amount,
        address handler,
        address to
    ) external override returns (uint256) {
        require(
            amount <= withDrawAmount[handler],
            "Can't withdraw over amount"
        );

        withDrawAmount[msg.sender] -= amount; // 5%

        IERC20(aToken).transferFrom(handler, address(this), amount);
        IERC20(asset).transfer(to, amount);

        return amount;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external override {}
}
