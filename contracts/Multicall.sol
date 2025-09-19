// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IRaffleFactory {
    function index() external view returns (uint256);
    function index_Raffle(uint256 index) external view returns (address);
}

interface IRaffle {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function sponsor() external view returns (address);
    function treasury() external view returns (address);
    function entropy() external view returns (address);
    function quote() external view returns (address);
    function prizeToken() external view returns (address);
    function prizeId() external view returns (uint256);
    function ticketPrice() external view returns (uint256);
    function minimumTickets() external view returns (uint256);
    function endTimestamp() external view returns (uint256);
    function winnerTicketId() external view returns (uint256);
    function nextTicketId() external view returns (uint256);
    function getEntropyFee() external view returns (uint256);
}

contract Multicall {

    address public immutable raffleFactory;

    struct Raffle {
        string name;
        string symbol;

        address sponsor;
        address treasury;
        address entropy;
        address quote;
        address prizeToken;
        uint256 prizeId;

        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 endTimestamp;
        uint256 entropyFee;

        uint256 winnerTicketId;
        uint256 nextTicketId;

        bool drawn;
        bool settled;

        uint256 accountQuoteBalance;
        uint256 accountTicketBalance;
        uint256[] accountTicketIds;
        bool accountWinner;
    }

    constructor(address _raffleFactory) {
        raffleFactory = _raffleFactory;
    }
 
    function getRafffleData(uint256 index) external view returns (Raffle memory data) {
        address raffle = IRaffleFactory(raffleFactory).index_Raffle(index);

        data.name = IRaffle(raffle).name();
        data.symbol = IRaffle(raffle).symbol();

        data.sponsor = IRaffle(raffle).sponsor();
        data.treasury = IRaffle(raffle).treasury();
        data.entropy = IRaffle(raffle).entropy();
        data.quote = IRaffle(raffle).quote();
        data.prizeToken = IRaffle(raffle).prizeToken();
        data.prizeId = IRaffle(raffle).prizeId();

        data.ticketPrice = IRaffle(raffle).ticketPrice();
        data.minimumTickets = IRaffle(raffle).minimumTickets();
        data.endTimestamp = IRaffle(raffle).endTimestamp();
        data.entropyFee = IRaffle(raffle).getEntropyFee();

        data.winnerTicketId = IRaffle(raffle).winnerTicketId();
        data.nextTicketId = IRaffle(raffle).nextTicketId();

        data.drawn = data.winnerTicketId != 0;
        data.settled = IERC721(data.prizeToken).balanceOf(address(raffle)) == 0 ? true : false;

        data.accountQuoteBalance = IERC20(data.quote).balanceOf(address(this));
        data.accountTicketBalance = IERC721(data.prizeToken).balanceOf(address(this));
        data.accountTicketIds = new uint256[](data.accountTicketBalance);
        for (uint256 i = 0; i < data.accountTicketBalance; i++) {
            data.accountTicketIds[i] = IERC721Enumerable(data.prizeToken).tokenOfOwnerByIndex(address(this), i);
            if (data.accountTicketIds[i] == data.winnerTicketId) {
                data.accountWinner = true;
            }
        }
    }

}

