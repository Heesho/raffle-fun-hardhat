// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IRaffleFactory {
    function index() external view returns (uint256);
    function index_Raffle(uint256 index) external view returns (address);
    function raffle_Index(address raffle) external view returns (uint256);

    function create(
        string memory name,
        string memory symbol,
        address sponsor,
        address prizeToken,
        uint256 prizeId,
        uint256 minimumTickets
    ) external returns (address);
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

    function buy(address raffle, address provider, uint256 amount) external;
    function draw() external payable;
    function settle() external;
}

contract Multicall is IERC721Receiver {

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

        uint256 raffleQuoteBalance;
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

    function create(
        string memory name,
        string memory symbol,
        address sponsor,
        address prizeToken,
        uint256 prizeId,
        uint256 minimumTickets
    ) external returns (address) {
        IERC721(prizeToken).safeTransferFrom(msg.sender, address(this), prizeId);
        IERC721(prizeToken).approve(raffleFactory, prizeId);

        return IRaffleFactory(raffleFactory).create(name, symbol, sponsor, prizeToken, prizeId, minimumTickets);
    }

    function buy(address raffle, address provider, uint256 amount) external {
        address quote = IRaffle(raffle).quote();
        uint256 totalCost = amount * IRaffle(raffle).ticketPrice();

        IERC20(quote).transferFrom(msg.sender, address(this), totalCost);
        IERC20(quote).approve(raffle, totalCost);
        IRaffle(raffle).buy(msg.sender, provider, amount);
    }
        
    function draw(address raffle) external payable {
        address entropy = IRaffle(raffle).entropy();

        if (entropy != address(0)) {
            uint256 entropyFee = IRaffle(raffle).getEntropyFee();
            require(msg.value >= entropyFee, "Insufficient ETH for entropy fee");
            IRaffle(raffle).draw{value: entropyFee}();
        } else {
            IRaffle(raffle).draw{value: 0}();
        }
    }

    function settle(address raffle) external {
        IRaffle(raffle).settle();
    }
 
    function getRaffle(address raffle, address account) external view returns (Raffle memory data) {
        data.name = IRaffle(raffle).name();
        data.symbol = IRaffle(raffle).symbol();

        data.sponsor = IRaffle(raffle).sponsor();
        data.treasury = IRaffle(raffle).treasury();
        data.entropy = IRaffle(raffle).entropy();
        data.quote = IRaffle(raffle).quote();
        data.prizeToken = IRaffle(raffle).prizeToken();
        data.prizeId = IRaffle(raffle).prizeId();

        data.raffleQuoteBalance = IERC20(data.quote).balanceOf(raffle);
        data.ticketPrice = IRaffle(raffle).ticketPrice();
        data.minimumTickets = IRaffle(raffle).minimumTickets();
        data.endTimestamp = IRaffle(raffle).endTimestamp();
        data.entropyFee = IRaffle(raffle).getEntropyFee();

        data.winnerTicketId = IRaffle(raffle).winnerTicketId();
        data.nextTicketId = IRaffle(raffle).nextTicketId();

        data.drawn = data.winnerTicketId != 0;
        data.settled = IERC721(data.prizeToken).balanceOf(raffle) == 0 ? true : false;

        data.accountQuoteBalance = IERC20(data.quote).balanceOf(account);
        data.accountTicketBalance = IERC721(raffle).balanceOf(account);
        data.accountTicketIds = new uint256[](data.accountTicketBalance);
        for (uint256 i = 0; i < data.accountTicketBalance; i++) {
            data.accountTicketIds[i] = IERC721Enumerable(raffle).tokenOfOwnerByIndex(account, i);
            if (data.accountTicketIds[i] == data.winnerTicketId) {
                data.accountWinner = true;
            }
        }
    }

    function getIndex() external view returns (uint256) {
        return IRaffleFactory(raffleFactory).index();
    }

    function getRaffleIndex(address raffle) external view returns (uint256) {
        return IRaffleFactory(raffleFactory).raffle_Index(raffle);
    }

    function getIndexRaffle(uint256 index) external view returns (address) {
        return IRaffleFactory(raffleFactory).index_Raffle(index);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

}

