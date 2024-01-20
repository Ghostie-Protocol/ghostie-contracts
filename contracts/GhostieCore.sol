// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IGhostieCore.sol";
import "./interfaces/IVRF.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";
import "./interfaces/IHandler.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GhostieCore is IGhostieCore, Ownable {
    using Strings for string;

    IVRF private vrfCore;
    IERC20 immutable usdc;
    ITickets immutable ticket;
    IHandler handler;

    struct RoundDetail {
        uint256 startDate;
        uint256 endDate;
        uint256 drawDate;
        string winningNumber;
        uint256 randomRequestId;
        uint256 ticketPrice;
        uint256 totalBalance;
        bool isCalWinner;
        address[] matchAll;
        address[] match5d;
        address[] match4d;
        address[] match3d;
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

    struct UserTicketDetail {
        uint256 ticketId;
        string[] numbers;
        WinnerPrice[] winnerType;
        uint256 totalBalance;
    }

    receive() external payable {}

    uint256 public currentRound;
    uint256 public ticketPrice;
    uint256 public roundTime;
    uint256 public usdcDecimals;

    mapping(uint256 => RoundDetail) public rounds;

    enum WinnerPrice {
        JACKPOT,
        LAST_FIVE_DIGITS,
        LAST_FOUR_DIGITS,
        LAST_THREE_DIGITS,
        ZERO
    }

    struct WinnerDetail {
        uint256 ticketId;
        string number;
        WinnerPrice winnerType;
        address investorAddress;
    }

    mapping(uint256 round => address[]) totalInvestor;
    mapping(uint256 round => mapping(address => bool)) isRoundInvestor;
    mapping(uint256 round => WinnerDetail[]) roundWinner;

    mapping(address userAddr => mapping(uint256 round => uint256[])) investorTickets;
    // mapping(address userAddr => mapping(uint256 round => string[])) investorNumbers;
    mapping(address userAddr => mapping(uint256 round => mapping(uint256 => string[]))) numbersOfTicket;
    // mapping(address userAddr => mapping(uint256 round => mapping(uint256 => WinnerPrice[]))) numbersWinType;
    mapping(address userAddr => mapping(uint256 round => uint256)) investorRoundBalance;

    constructor(address _usdc, address _ticket, address _vrfAddress) Ownable() {
        usdc = IERC20(_usdc);
        ticket = ITickets(_ticket);
        vrfCore = IVRF(_vrfAddress);

        usdcDecimals = uint256(usdc.decimals());
        ticketPrice = 10 * 10 ** usdcDecimals;
        roundTime = 10 minutes;
    }

    function startLottoRound(
        uint256 startDate,
        uint256 endDate
    ) external onlyOwner returns (uint256) {
        RoundDetail memory _roundDetail;

        if (
            rounds[currentRound].endDate >= block.timestamp && currentRound != 0
        ) {
            revert(
                "Cannot start a new round, the current round has not expired."
            );
        }

        if (currentRound > 1) {
            uint256 roundBefore = currentRound - 1;
            RoundDetail memory roundDetailBefore = rounds[roundBefore];
            handler.farm(roundBefore, roundDetailBefore.totalBalance);
        }

        currentRound++;

        _roundDetail.startDate = startDate;
        _roundDetail.endDate = endDate;
        _roundDetail.drawDate = endDate + roundTime;
        _roundDetail.ticketPrice = ticketPrice;

        rounds[currentRound] = _roundDetail;

        emit StartNewRound(currentRound, startDate, endDate);
        return (currentRound);
    }

    function closeLottoRound() external {
        RoundDetail memory _roundDetail = rounds[currentRound];
        require(
            _roundDetail.endDate <= block.timestamp,
            "The sale time has not yet expired."
        );

        require(
            _roundDetail.drawDate <= block.timestamp,
            "It's not yet time to close the farming round."
        );

        uint256 requestId = vrfCore.requestRandomWords();
        rounds[currentRound].randomRequestId = requestId;
    }

    function buyTicket(string[] memory _numbers) external {
        RoundDetail memory currRound = rounds[currentRound];

        require(
            currRound.startDate <= block.timestamp &&
                currRound.endDate >= block.timestamp,
            "Not at the time of ticket purchase"
        );

        uint256 tokenAllowance = usdc.allowance(msg.sender, address(this));
        uint256 userBalance = usdc.balanceOf(msg.sender);
        uint256 totalTicketPrice = _numbers.length * ticketPrice;

        require(tokenAllowance > 0, "Approve token is not enough!");
        require(userBalance >= totalTicketPrice, "Your balance is not enough!");

        usdc.transferFrom(msg.sender, address(this), totalTicketPrice);

        uint256 ticketId = ticket.mint(msg.sender, totalTicketPrice, _numbers);
        investorTickets[msg.sender][currentRound].push(ticketId);

        numbersOfTicket[msg.sender][currentRound][ticketId] = _numbers;

        rounds[currentRound].totalBalance += totalTicketPrice;

        investorRoundBalance[msg.sender][currentRound] += totalTicketPrice;

        if (!isRoundInvestor[currentRound][msg.sender]) {
            isRoundInvestor[currentRound][msg.sender] = true;
            totalInvestor[currentRound].push(msg.sender);
        }

        emit BuyTicketSuccess(totalTicketPrice, currentRound, ticketId);
    }

    function updateWinningNumber(uint256 winningNumber) external {
        string memory winNumber = uint256ToString(winningNumber);

        winNumber = zeroDigit(winNumber);
        rounds[currentRound].winningNumber = winNumber;

        // checkWinningDrawPrice();
    }

    function updateHandlerContract(address handlerAddress) external {
        handler = IHandler(handlerAddress);
    }

    function claim(uint256 round, uint256 _ticketId) external {
        uint256 cliamState = rounds[round].drawDate - block.timestamp;

        require(
            address(handler) != address(0),
            "Handler conntract is not defind!"
        );

        if (cliamState > 0) {
            // interest claim
            handler.claim(round, _ticketId, msg.sender);
        } else {
            // total cliam
            RoundDetail memory _round = rounds[round];

            address[] memory matchAll = _round.matchAll;
            address[] memory match5d = _round.match5d;
            address[] memory match4d = _round.match4d;
            address[] memory match3d = _round.match3d;

            for (uint i = 0; i < matchAll.length; i++) {
                if (matchAll[i] == msg.sender) {
                    handler.withdraw(_ticketId, msg.sender);
                }
            }
            for (uint i = 0; i < match5d.length; i++) {
                if (match5d[i] == msg.sender) {}
            }
            for (uint i = 0; i < match4d.length; i++) {
                if (match4d[i] == msg.sender) {}
            }
            for (uint i = 0; i < match3d.length; i++) {
                if (match3d[i] == msg.sender) {}
            }
        }
    }

    function checkWinningDrawPrice() external {
        RoundDetail memory roundDetail = rounds[currentRound];

        string memory jackpotResult = roundDetail.winningNumber;
        string memory match5dResult = substring(jackpotResult, 1, 6);
        string memory match4dResult = substring(jackpotResult, 2, 6);
        string memory match3dResult = substring(jackpotResult, 3, 6);

        address[] memory investors = totalInvestor[currentRound];

        for (uint i = 0; i < investors.length; i++) {
            address currInvertor = investors[i];

            uint256[] memory tickets = investorTickets[currInvertor][
                currentRound
            ];

            for (uint j = 0; j < tickets.length; j++) {
                uint256 ticketId = tickets[j];
                string[] memory _numbers = numbersOfTicket[currInvertor][
                    currentRound
                ][ticketId];

                // WinnerPrice[] memory winTypes = new WinnerPrice[](
                //     numbersWinType[currInvertor][currentRound][ticketId].length
                // );

                calWinnerPrice(
                    _numbers,
                    // winTypes,
                    jackpotResult,
                    match5dResult,
                    match4dResult,
                    match3dResult,
                    currInvertor,
                    ticketId
                );
            }
        }
    }

    function calWinnerPrice(
        string[] memory _numbers,
        // WinnerPrice[] memory winTypes,
        string memory jackpotResult,
        string memory match5dResult,
        string memory match4dResult,
        string memory match3dResult,
        address sender,
        uint256 ticketId
    ) internal {
        for (uint k = 0; k < _numbers.length; k++) {
            string memory number5d = substring(_numbers[k], 1, 6);
            string memory number4d = substring(_numbers[k], 2, 6);
            string memory number3d = substring(_numbers[k], 3, 6);

            WinnerDetail memory winnerDetail;

            winnerDetail.investorAddress = sender;
            winnerDetail.number = _numbers[k];
            winnerDetail.ticketId = ticketId;

            if (stringsEqual(_numbers[k], jackpotResult)) {
                rounds[currentRound].matchAll.push(sender);
                winnerDetail.winnerType = WinnerPrice.JACKPOT;

                // winTypes[k] = WinnerPrice.JACKPOT;
            } else if (stringsEqual(number5d, match5dResult)) {
                rounds[currentRound].match5d.push(sender);
                winnerDetail.winnerType = WinnerPrice.LAST_FIVE_DIGITS;

                // winTypes[k] = WinnerPrice.LAST_FIVE_DIGITS;
            } else if (stringsEqual(number4d, match4dResult)) {
                rounds[currentRound].match4d.push(sender);
                winnerDetail.winnerType = WinnerPrice.LAST_FOUR_DIGITS;

                // winTypes[k] = WinnerPrice.LAST_FOUR_DIGITS;
            } else if (stringsEqual(number3d, match3dResult)) {
                rounds[currentRound].match3d.push(sender);
                winnerDetail.winnerType = WinnerPrice.LAST_THREE_DIGITS;

                // winTypes[k] = WinnerPrice.LAST_THREE_DIGITS;
            } else {
                winnerDetail.winnerType = WinnerPrice.ZERO;

                // winTypes[k] = WinnerPrice.ZERO;
            }

            roundWinner[currentRound].push(winnerDetail);
        }

        // numbersWinType[sender][currentRound][ticketId] = winTypes;
    }

    function history() external view returns (HistoryDetail[] memory) {
        HistoryDetail[] memory allHistory = new HistoryDetail[](currentRound);

        for (uint i = 1; i <= currentRound; i++) {
            RoundDetail memory round = rounds[i];
            HistoryDetail memory currentHistory;

            uint256 totalTicket = investorTickets[msg.sender][i].length;

            currentHistory.round = i;
            currentHistory.startDate = round.startDate;
            currentHistory.endDate = round.endDate;
            currentHistory.drawDate = round.drawDate;
            currentHistory.totalYourTicket = totalTicket;
            currentHistory.winningNumber = round.winningNumber;
            currentHistory.matchAll = round.matchAll;
            currentHistory.match5d = round.match5d;
            currentHistory.match4d = round.match4d;
            currentHistory.match3d = round.match3d;

            allHistory[i - 1] = currentHistory;
        }

        return allHistory;
    }

    function getTicketsPerRound(
        uint256 round
    ) external view returns (UserTicketDetail[] memory) {
        uint256[] memory tickets = investorTickets[msg.sender][round];

        UserTicketDetail[] memory totalTicket = new UserTicketDetail[](
            tickets.length
        );

        for (uint i = 0; i < tickets.length; i++) {
            string[] memory _numbers = numbersOfTicket[msg.sender][round][
                tickets[i]
            ];
            // WinnerPrice[] memory winTypes = numbersWinType[msg.sender][round][
            //     tickets[i]
            // ];
            uint256 totalBalance = investorRoundBalance[msg.sender][round];

            UserTicketDetail memory ticketsDetail;

            ticketsDetail.ticketId = tickets[i];
            ticketsDetail.numbers = _numbers;
            // ticketsDetail.winnerType = winTypes;
            ticketsDetail.totalBalance = totalBalance;

            totalTicket[i] = ticketsDetail;
        }
        return totalTicket;
    }

    function zeroDigit(string memory s) public pure returns (string memory) {
        while (bytes(s).length < 6) {
            s = concatenateStrings("0", s);
        }
        return s;
    }

    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function concatenateStrings(
        string memory a,
        string memory b
    ) public pure returns (string memory) {
        bytes memory concatenatedBytes = abi.encodePacked(a, b);
        return string(concatenatedBytes);
    }

    function stringsEqual(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function uint256ToString(uint256 _num) public pure returns (string memory) {
        if (_num == 0) {
            return "0";
        }

        uint256 temp = _num;
        uint256 digits;

        while (temp != 0) {
            temp /= 10;
            digits++;
        }

        bytes memory buffer = new bytes(digits);

        while (_num != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (_num % 10)));
            _num /= 10;
        }

        return string(buffer);
    }
}
