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
    error NotBeneficiary();
    error AuctionEndedAlreadyCalled();

    //Events
    event AuctionEnd(address winner, uint winnerAmount);


    //State variable to keep track
    uint highestBid;
    address highestBidder;

    //Keeps track of the bidding status whether its has ended or still ongoin
    bool ended;

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

    modifier OnlyBeneficiary() {
        if(msg.sender != i_beneficiary) revert NotBeneficiary();
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
    /**
     * 
     * @param values refers the amount a particular caller might have sent. during the 
     * @param fakes refers to the bools that the caller passed
     * @param secrets refers to the secret the caller passed (all hashed, as shown in bid function)
     */

    /*
    The function can oly be called after the bidding duration(OnlyAfter(i_biddingEnd)) and in the reveal period(OnlyBefore(i_revealEnd)). 
    Once the reveal duration is passed, we cant call the function no more.
    */
    function reveal(
        uint[] calldata values,
        bool[] calldata fakes,
        bytes32[] calldata secrets
    ) external OnlyBefore(i_revealEnd)OnlyAfter(i_biddingEnd){

        //With the help of the caller's address(msg.sender) get the length of the array of 
        //that particular caller from the mapping and sign it to lenght with a type uint
        uint length = bids[msg.sender].length;

        //Check if number of element of the values array passed as parameters is equal to the number of the element in
        //the array from the mapping
        require(values.length == length);

        //Check if number of element of the fakes array passed as parameters is equal to the number of the element in
        //the array from the mapping
        require(fakes.length == length);

        //Check if number of element of the secrets array passed as parameters is equal to the number of the element in
        //the array from the mapping
        require(secrets.length == length);

        //Declared a variable refund of type uint
        uint refund;

        //Loop throght the elements from the array gotten from the mapping
        for(uint i = 0; i < length; i++){

            //Get a copy of the Bid Struct with the variable name bidToCheck with the
            //keyword "storage" indicating the next few commad entails parmanently update
            //the contract state. Assign the variable to the presnt array element from the loop above
            Bid storage bidToCheck = bids[msg.sender][i];

            // Unpack current index values into local variables
            (uint value, bool fake, bytes32 secret) = (values[i], fakes[i], secrets[i]);

            //Check if the blindedBid of type bytes32 is not the same as the hash gotten from the
            //the hashing(keccak256(abi.encodePacked(value, fake, secret))), if yes
            if(bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret))){

                //Then run the following code under
                continue;
            }

            //Add the callers deposit to the declare refund variable
            refund += bidToCheck.deposit;

            //Check if the bool of false is not false and the callers deposit (bidToCheck.deposit) is greater
            //than or equal to the value assigned above, if yes
            if(!false && bidToCheck.deposit >= value){

                /**
                 * Pass the caller(msg.sender) and the value to a placeBid function. the function is an internal 
                 * function and expects two parameters the callers address(msg.sender) and the value(the variable of type
                 * uint declared to hold the abount of token to be revealed by the  caller of the reveal function). the function
                 * is expected to return a bool(ethier true or false). when the function is called, its performs some conditionals
                 * //1. Check if the value is less than or equal to highestBid(state variable), if yes it returns false
                 * //2. Check if the highestBidder address(State variable) is not equal to an empty address, if yes
                 * //Then pass the highestBid(state variable) to the pendingReturn mapping with the help of the highestBidder address
                 * // Finally go and assign the new highestBid(state) to the value passed as parameters,
                 * // And als assign the address(msg.sender) passed to the highestBid.
                 * //Lastly if all goes well return true
                */
                if(placeBid(msg.sender, value)){ //If the conditionals returns true
                    refund -= value; // Get the refund variable and subtract the present value from the refund variable
                }
            }

            //Then set the blindedBid of the sender to an empty bytes so that sender can't reclaim deposit
            bidToCheck.blindedBid = bytes32(0);
        }

        //Transfer the remaining amount in the refund to the sender
        payable(msg.sender).transfer(refund);
    }

    //3. placeBid function
    /**
     * Pass the caller(msg.sender) and the value to a placeBid function. the function is an internal 
     * function and expects two parameters the callers address(msg.sender) and the value(the variable of type
     * uint declared to hold the abount of token to be revealed by the  caller of the reveal function). the function
     * is expected to return a bool(ethier true or false)
    */

    function placeBid(address bidder, uint value) internal returns(bool){
        
        ////1. Check if the value is less than or equal to highestBid(state variable), if yes 
        if(value <= highestBid){

            //it returns false
            return false;
        }

        //2. Check if the highestBidder address(State variable) is not equal to an empty address, if yes
        if(highestBidder != address(0)){

            //Then pass the highestBid(state variable) to the pendingReturn mapping with the help of the highestBidder address
            pendingReturns[bidder] += highestBid;
        }

        // Finally go and assign the new highestBid(state) to the value passed as parameters,
        highestBid = value;

        // And als assign the address(msg.sender) passed to the highestBid.
        highestBidder = msg.sender;

        //Lastly if all goes well return true
        return true;

    } 

    //4. Withdraw function
    //Can be called by outbidden bidders to withdraw their token.
    function withdraw() external {

        //Assign the variable amount to the bid of the sender that has been added to the 
        //pendingReturn mapping.
        uint amount = pendingReturns[msg.sender];

        //Check if the bid(amount) gotten is greater than zer, if yes
        if(amount > 0){

            //Make that bid in the sender to equal zero. 
            pendingReturns[msg.sender] = 0;
        }

        //Transfer all the amount to the caller of the function.
        payable(msg.sender).transfer(amount);
    }

    //5. AuctionEnd function
    //To be called only after the reveal period has ended(OnlyAfter(i_revealEnd)) and can oly be called by the beneficiary(OnlyBeneficiary)
    function autionEnd() external OnlyAfter(i_revealEnd) OnlyBeneficiary{

        //Checks the decared ended variable of type bool, if it returns true, then revert with custom error message
        if (ended) revert AuctionEndedAlreadyCalled();
        
        //Transfers the highest bid to the beneficiary
        i_beneficiary.transfer(highestBid);

        //Set the ended to true, so that the function can't be called multiple times by the beneficiary
        ended = true;

        //Emit the following event special function indicating the highestBid and the highestBidder
        emit AuctionEnd(highestBidder, highestBid);

    }

}