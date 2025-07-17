//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Blind Auction
 * @author Chukwuebuka Godsfavour
 * @notice Just like the simple auction but with a bit of update and regulation for the Auction period.
 */
contract BlindAuction{

    //Custom Error
    error TooLate();
    error TooEarly();


    //State variable to keep track
    uint highestBid;
    address highestBidder;

    //Struct for the bid padded durinhg the auction
    struct Bid{
        bytes32 blindedBid;
        uint deposit;
    }

    //Mapping 
    //1. To keep record of outbidden bidders.
    mapping(address bidder => uint bid) public pendingReturns;

    //2. To assign the address to each bider to their bid struct
    mapping(address bidder => Bid[]) public bids;


    //Immutable Variable(Assigned during deployment)
    uint i_biddingEnd;
    uint i_revealEnd;
    address payable i_beneficiary;

    //Modifiers
    modifier OnlyBefore(uint time) {
        if(block.timestamp >= time) revert TooLate();
        _;
    }

    modifier OnlyAfter(uint time) {
        if(block.timestamp <= time) revert TooEarly();
        _;
    }

    //Constructor(Whats needed for the contract to be deployed)
    constructor(uint biddingTime, uint revealTime){
        i_biddingEnd = block.timestamp + biddingTime;
        i_revealEnd = i_biddingEnd + revealTime;
        i_beneficiary = payable(msg.sender);
    }


    //Functions

    //1. Bid 
    /**
     * 
     * @param _blindedBid is expected to be a hash of bytes32 type, this makes the 
     * bid not known by anyone but the bidder. The hash include a combination of
     * a value of type uint, a fake of type boolean(defaulted to false) and a hashed secret
     * (only the bidder is to know this) of type bytes32
     * For example, let the value be 3(native token ETH), fake should be false(indicating that 
     * the bidder is serious) and let the secret be secretPass, thefore the hshed secret become:
     * 
     * bytes secretBytes = keccak256(abi.encodedPacked("secretPass")), this return a fixed size of type
     * bytes32, let assume 0x5b4707a1b6974a10788fa2ddb91cd5adbe17aa857a6d9143236ef4c7a5b981b5
     * 
     * Finally what ever the above returned shoud be passed like this
     * bytes32 hash = keccak256(abi.encodedPacked(uint256(3), false 0x5b4707a1b6974a10788fa2ddb91cd5adbe17aa857a6d9143236ef4c7a5b981b5))
     * 
     * Whatever the above returns should be passed as the param _blindedBid
     */

    /*
    The function is a payable function(it receives the native token in this case ETH) 
    and can only before the end of the allocated Time for the auction
    */
    function bid(bytes32 _blindedBid) external payable OnlyBefore(i_biddingEnd){

        //Get the full copy of the declared Bid struct temporarily with the variable name of newBid
        //store the parameter passed (_blindedBid) to the blindedBid property and the the token sent 
        //along side the blindedBid assign to the deposite property
        Bid memory newBid = Bid({blindedBid: _blindedBid, deposit: msg.value}); 

        //Then go to the bids mapping, with the help of the caller of this function(msg.sender) add
        //the newBid to the mapping.
        bids[msg.sender].push(newBid);
    }


    //2. Reveal Function
    // function reveal(
    //     uint[] values,
    //     bool[] fakes,
    //     bytes32[] secrets
    // ) external OnlyBefore(i_revealEnd)OnlyAfter(i_biddingEnd){

    // }

}