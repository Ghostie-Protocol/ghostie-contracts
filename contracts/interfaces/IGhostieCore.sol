// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IGhostieCore {
    event BuyTicketSuccess(uint256 totalPrice, uint256 round, uint256 ticketId);

    event StartNewRound(uint256 currentRound, uint256 startDate, uint256 endDate);

    function buyTicket(string[] memory _numbers) external;

    function updateWinningNumber(uint256 winningNumber) external;
}
