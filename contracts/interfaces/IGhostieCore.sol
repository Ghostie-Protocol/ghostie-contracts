// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IGhostieCore {
    event BuyTicketSuccess(uint256 totalPrice, uint256 round);

    function buyTicket(string[] memory _numbers) external;
}
