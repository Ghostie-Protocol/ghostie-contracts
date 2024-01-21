// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IHandler {
    struct FarmConfig {
        address coreContract;
        address operator;
        address poolAddress;
        address borrowTokenAddress;
        address aTokenAddress;
        address tokenAddress;
        address ticketAddress;
    }

    event Farm(uint256 indexed _round, address _poolAddress, uint256 _amount);
    event Claim(uint256 indexed _round, uint256 indexed _ticketId, address _to);

    function getTicketYield(
        uint256 _round,
        uint256 _ticketId
    ) external view returns (uint256);

    function farm(uint256 _round, uint256 _amount) external;

    function claim(uint256 _round, uint256 _ticketId, address _to) external;

    function withdraw(
        uint256 _round,
        uint256 _ticketId,
        address _to,
        uint256 _prize
    ) external;
}
