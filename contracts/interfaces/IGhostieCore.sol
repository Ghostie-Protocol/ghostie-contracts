// SPDX-License-Identifier: MIT
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
        uint256 prizePot;
        uint256 totalYourTicket;
        string winningNumber;
        uint256 ticketAmount;
        uint256 totalPlayer;
        uint256 totalBalance;
        address[] matchAll;
        address[] match5d;
        address[] match4d;
        address[] match3d;
    }

    struct WinnerDetail {
        string number;
        WinnerPrice winnerType;
        address investorAddress;
        uint256 share;
        bool isClaim;
    }

    struct UserTicketDetail {
        uint256 ticketId;
        string[] numbers;
        WinnerPrice[] winnerType;
        uint256 totalBalance;
    }

    event BuyTicketSuccess(
        address indexed userAddress,
        uint256 totalPrice,
        uint256 round,
        uint256 ticketId
    );
    event BorrowSuccess(address indexed userAddress, uint256 amount);
    event RepaySuccess(address indexed userAddress);
    event StartNewRound(
        address indexed adminAddress,
        uint256 currentRound,
        uint256 startDate,
        uint256 endDate
    );
    event CloseRound(address indexed adminAddress, uint256 closeRound);
    event UpdateWinnigNumber(address indexed vrfAddress);
    event ClaimSuccess(address indexed userAddress, uint256 ticketId);

    function startLottoRound(
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256);

    function closeLottoRound(uint256 round) external;

    function buyTicket(string[] memory _numbers) external;

    function updateHandlerContract(address handlerAddress) external;

    function claim(uint256 round, uint256 _ticketId) external;

    function checkWinningDrawPrice() external;

    function borrow(
        uint256 _round,
        uint256 _ticketId,
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

    function updateWinningNumber(uint256 winningNumber, uint256 round) external;

    function updateRoundTime(uint256 time) external;
}
