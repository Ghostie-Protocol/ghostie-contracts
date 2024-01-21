// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IGhostieCore.sol";
import "./interfaces/IVRF.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";
import "./interfaces/IHandler.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GhostieCore is IGhostieCore, Ownable {
    using Strings for string;
    using SafeMath for uint256;

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

    receive() external payable {}

    uint256 public currentRound;
    uint256 public ticketPrice;
    uint256 public roundTime;
    uint256 public usdcDecimals;

    mapping(uint256 => RoundDetail) public rounds;

    mapping(uint256 round => address[]) totalInvestor;
    mapping(uint256 round => mapping(address => bool)) isRoundInvestor;
    mapping(uint256 round => mapping(uint256 ticketId => WinnerDetail[])) roundWinner;

    mapping(address userAddr => mapping(uint256 round => uint256[])) investorTickets;
    mapping(address userAddr => mapping(uint256 round => mapping(uint256 ticketId => uint256 totalWin)))
        public ticketTotalWinShare;
    mapping(address userAddr => mapping(uint256 round => mapping(uint256 ticketId => bool isClaim)))
        public isClaimTotalWinShare;
    mapping(address userAddr => mapping(uint256 round => mapping(uint256 => string[]))) numbersOfTicket;
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

    function closeLottoRound() external onlyOwner {
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

        require(address(handler) != address(0), "Handler not defind!");

        uint256 tokenAllowance = usdc.allowance(msg.sender, address(this));
        uint256 userBalance = usdc.balanceOf(msg.sender);
        uint256 totalTicketPrice = _numbers.length * ticketPrice;

        require(tokenAllowance > 0, "Approve token is not enough!");
        require(userBalance >= totalTicketPrice, "Your balance is not enough!");

        usdc.transferFrom(msg.sender, address(handler), totalTicketPrice);

        uint256 ticketId = ticket.mint(msg.sender, totalTicketPrice, _numbers);
        investorTickets[msg.sender][currentRound].push(ticketId);

        numbersOfTicket[msg.sender][currentRound][ticketId] = _numbers;

        rounds[currentRound].totalBalance += totalTicketPrice;

        investorRoundBalance[msg.sender][currentRound] += totalTicketPrice;

        if (!isRoundInvestor[currentRound][msg.sender]) {
            isRoundInvestor[currentRound][msg.sender] = true;
            totalInvestor[currentRound].push(msg.sender);
        }

        emit BuyTicketSuccess(
            msg.sender,
            totalTicketPrice,
            currentRound,
            ticketId
        );
    }

    modifier onlyVRF() {
        require(address(msg.sender) == address(vrfCore));
        _;
    }

    function updateWinningNumber(uint256 winningNumber) external onlyVRF {
        string memory winNumber = uint256ToString(winningNumber);

        winNumber = zeroDigit(winNumber);
        rounds[currentRound].winningNumber = winNumber;
    }

    function updateHandlerContract(address handlerAddress) external onlyOwner {
        handler = IHandler(handlerAddress);
    }

    function borrow(
        uint256 _round,
        uint256 _ticketId,
        address _borrower,
        uint256 _amount
    ) external {
        // handler.borrow(_round, _ticketId, _borrower, _amount);
    }

    function claim(uint256 round, uint256 _ticketId) external {
        uint256 cliamState = rounds[round].drawDate - block.timestamp;

        require(
            address(handler) != address(0),
            "Handler conntract is not defind!"
        );

        if (cliamState > 0) {
            handler.claim(round, _ticketId, msg.sender);
        } else {
            RoundDetail memory _round = rounds[round];
            require(
                _round.isCalWinner,
                "Still cannot withdraw The system is processing the winnings."
            );

            WinnerDetail[] memory numbers = roundWinner[round][_ticketId];

            for (uint i = 0; i < numbers.length; i++) {
                roundWinner[round][_ticketId][i].isClaim = true;
            }

            uint256 totalShare = ticketTotalWinShare[msg.sender][round][
                _ticketId
            ];
            bool isClaim = isClaimTotalWinShare[msg.sender][round][_ticketId];

            require(!isClaim, "Already claim");

            isClaimTotalWinShare[msg.sender][round][_ticketId] = true;
            handler.withdraw(round, _ticketId, msg.sender, totalShare);
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

                calWinnerPrice(
                    _numbers,
                    jackpotResult,
                    match5dResult,
                    match4dResult,
                    match3dResult,
                    currInvertor,
                    ticketId
                );
            }
        }

        rounds[currentRound].isCalWinner = true;

        address[] memory matchAll = roundDetail.matchAll;
        address[] memory match5d = roundDetail.match5d;
        address[] memory match4d = roundDetail.match4d;
        address[] memory match3d = roundDetail.match3d;

        uint256 jackpotShare = uint256(70).div(100).div(matchAll.length).mul(
            10000
        );
        uint256 last5dShare = uint256(15).div(100).div(match5d.length).mul(
            10000
        );
        uint256 last4dShare = uint256(10).div(100).div(match4d.length).mul(
            10000
        );
        uint256 last3dShare = uint256(5).div(100).div(match3d.length).mul(
            10000
        );

        for (uint i = 0; i < investors.length; i++) {
            address currInvertor = investors[i];

            uint256[] memory tickets = investorTickets[currInvertor][
                currentRound
            ];

            for (uint j = 0; j < tickets.length; j++) {
                uint256 ticketId = tickets[j];
                WinnerDetail[] memory numbers = roundWinner[currentRound][
                    ticketId
                ];

                uint256 totalWin = calulateTicketShareWinPrice(
                    numbers,
                    jackpotShare,
                    last5dShare,
                    last4dShare,
                    last3dShare,
                    currentRound,
                    ticketId
                );

                ticketTotalWinShare[currInvertor][currentRound][
                    ticketId
                ] = totalWin;
            }
        }
    }

    function calulateTicketShareWinPrice(
        WinnerDetail[] memory numbers,
        uint256 jackpotShare,
        uint256 last5dShare,
        uint256 last4dShare,
        uint256 last3dShare,
        uint256 round,
        uint256 _ticketId
    ) internal returns (uint256) {
        uint256 totalShare;

        for (uint i = 0; i < numbers.length; i++) {
            uint256 numberShare;
            if (numbers[i].winnerType == WinnerPrice.JACKPOT) {
                numberShare = jackpotShare;
            } else if (numbers[i].winnerType == WinnerPrice.LAST_FIVE_DIGITS) {
                numberShare = last5dShare;
            } else if (numbers[i].winnerType == WinnerPrice.LAST_FOUR_DIGITS) {
                numberShare = last4dShare;
            } else if (numbers[i].winnerType == WinnerPrice.LAST_THREE_DIGITS) {
                numberShare = last3dShare;
            } else {
                numberShare = 0;
            }
            roundWinner[round][_ticketId][i].share = numberShare;
            totalShare += numberShare;
        }

        return totalShare;
    }

    function calWinnerPrice(
        string[] memory _numbers,
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

            if (stringsEqual(_numbers[k], jackpotResult)) {
                rounds[currentRound].matchAll.push(sender);
                winnerDetail.winnerType = WinnerPrice.JACKPOT;
            } else if (stringsEqual(number5d, match5dResult)) {
                rounds[currentRound].match5d.push(sender);
                winnerDetail.winnerType = WinnerPrice.LAST_FIVE_DIGITS;
            } else if (stringsEqual(number4d, match4dResult)) {
                rounds[currentRound].match4d.push(sender);
                winnerDetail.winnerType = WinnerPrice.LAST_FOUR_DIGITS;
            } else if (stringsEqual(number3d, match3dResult)) {
                rounds[currentRound].match3d.push(sender);
                winnerDetail.winnerType = WinnerPrice.LAST_THREE_DIGITS;
            } else {
                winnerDetail.winnerType = WinnerPrice.ZERO;
            }

            roundWinner[currentRound][ticketId].push(winnerDetail);
        }
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

    function forceUpdate(
        string memory fouceWinner,
        uint256 round
    ) external onlyOwner {
        rounds[round].winningNumber = fouceWinner;
    }

    function getTicket(
        uint256 round,
        uint256 ticketId
    ) external view returns (WinnerDetail[] memory) {
        return roundWinner[round][ticketId];
    }

    function getAllTicketsPerRound(
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
            uint256 totalBalance = investorRoundBalance[msg.sender][round];

            UserTicketDetail memory ticketsDetail;

            ticketsDetail.ticketId = tickets[i];
            ticketsDetail.numbers = _numbers;
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
