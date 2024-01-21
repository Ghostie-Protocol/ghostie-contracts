// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IGhostieCore {
    enum WinnerPrice {
        JACKPOT,
        LAST_FIVE_DIGITS,
        LAST_FOUR_DIGITS,
        LAST_THREE_DIGITS,
        ZERO
    }

    struct HistoryDetail {
        uint256 round;
        uint256 startDate;
        uint256 endDate;
        uint256 drawDate;
        uint256 pricePot;
        uint256 totalYourTicket;
        string winningNumber;
        address[] matchAll;
        address[] match5d;
        address[] match4d;
        address[] match3d;
    }

    struct WinnerDetail {
        string number;
        WinnerPrice winnerType;
        address investorAddress;
        bool isClaim;
    }

    struct UserTicketDetail {
        uint256 ticketId;
        string[] numbers;
        WinnerPrice[] winnerType;
        uint256 totalBalance;
    }

    event BuyTicketSuccess(
        address userAddress,
        uint256 totalPrice,
        uint256 round,
        uint256 ticketId
    );

    event StartNewRound(
        uint256 currentRound,
        uint256 startDate,
        uint256 endDate
    );

    function startLottoRound(
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256);

    function closeLottoRound() external;

    function buyTicket(string[] memory _numbers) external;

    function updateHandlerContract(address handlerAddress) external;

    function claim(uint256 round, uint256 _ticketId) external;

    function checkWinningDrawPrice() external;

    function borrow(
        uint256 _round,
        uint256 _ticketId,
        address _borrower,
        uint256 _amount
    ) external;

    function history() external view returns (HistoryDetail[] memory);

    function forceUpdate(string memory fouceWinner, uint256 round) external;

    function getTicket(
        uint256 round,
        uint256 ticketId
    ) external view returns (WinnerDetail[] memory);

    function getAllTicketsPerRound(
        uint256 round
    ) external view returns (UserTicketDetail[] memory);
}
