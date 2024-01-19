// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ITicket {
    function mint(address _to, uint256 _value) external returns (uint);
}
