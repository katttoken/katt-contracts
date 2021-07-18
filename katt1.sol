pragma solidity 0.6.4;

library SafeMath { 
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}

enum BetStatus { IN_PROGRESS, ENDED }

struct Gambler
{
    uint256 option;
    uint256 amount;
    bool withdrawn;
}

struct Bet
{
    uint256 expirationTime;
    string description;
	BetStatus status;
    address creator;
    uint jackpot;
    mapping(uint => string) options;
    uint optionCount;
    mapping(uint => uint) mapOption_SumAmount;
    uint winOption;
    address[] gamblers;
    mapping(address => Gambler) gamblerInfo;
}

contract KattToken {
    using SafeMath for uint;

    // ERC-20 Parameters
    string public name;
    string public symbol;
    uint public decimals;
    uint public totalSupply_;

    // ERC-20 Mappings
    mapping(address => uint) private balances_;
    mapping(address => mapping(address => uint)) private allowances_;

    // Emission Public Parameters
    uint public coin; uint public emission;
    uint public currentEra; uint public currentDay;
    uint public daysPerEra; uint public secondsPerDay;
    uint public upgradeHeight; uint public upgradedAmount;
    uint public genesis; uint public nextEraTime; uint public nextDayTime;
    uint public totalEmitted; address deployer;

    // Emission Public Mappings
    mapping(uint=>uint) public mapEra_Emission;
    mapping(uint=>mapping(uint=>mapping(address=>uint))) public mapEraDayMember_LotteryShares;
    mapping(uint=>mapping(uint=>uint)) public mapEraDay_SharesRemaining;
    mapping(uint=>mapping(uint=>uint)) public mapEraDay_EmissionRemaining;
    mapping(uint=>mapping(uint=>address[])) public mapEraDay_LotteryMembers;
    mapping(uint=>mapping(uint=>uint)) public mapEraDay_LotteryMemberCount;
    mapping(uint=>mapping(uint=>uint)) public mapEraDay_LotteryTotalShares;
    mapping(address=>mapping(uint=>uint[])) public mapMemberEra_LotteryDays;  

    // Emission Events
    event NewEra(uint era, uint emission, uint time);
    event NewDay(uint era, uint day, uint time);
    event Withdrawal(address indexed caller, address indexed member, uint era, uint day, uint value, uint emissionRemaining);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);

    // Betting Public Parameters
    uint public betCount;
    mapping(uint256 => Bet) public bets_;
    mapping(address=>uint[]) public mapMember_BetsJoined;
    mapping(address=>uint) public mapMember_BetsJoinedCount;
    mapping(address=>uint[]) public mapMember_BetsCreated;
    mapping(address=>uint) public mapMember_BetsCreatedCount;

    // Betting Events
    event betCreated(address creator, uint256 betID, string description, uint256 betDurationInHours);
    event betStatusUpdate(uint256 betID, BetStatus status);
    event BetWithdrawal(address indexed caller, address indexed member, uint value, uint betID);
    event BetPlaced(address indexed caller, uint256 betID, uint256 option, uint256 amount);

    constructor() public {
        name = "KattToken";
        symbol = "KATT";
        decimals = 18;
        coin = 1*10**decimals;
        totalSupply_ = 1000000*coin;
        emission = 2048*coin;
        currentEra = 1; currentDay = 1;
        daysPerEra = 244; secondsPerDay = 84200;
        balances_[address(this)] = totalSupply_;
        emit Transfer(address(0), address(this), totalSupply_);
        // testing
        // balances_[address(this)] -= 1000*coin;
        // balances_[msg.sender] = 1000*coin;
        // emit Transfer(address(this), msg.sender, 1000*coin);
        // secondsPerDay = 1;
        // end testing
        genesis = now;
        nextEraTime = genesis + (secondsPerDay * daysPerEra);
        nextDayTime = genesis + secondsPerDay;
        mapEra_Emission[currentEra] = emission;
        mapEraDay_EmissionRemaining[currentEra][currentDay] = emission;
        deployer = msg.sender;
    }

    function totalSupply() public view returns (uint256) {
	    return totalSupply_;
    }
    
    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances_[tokenOwner];
    }

    function transfer(address receiver, uint numTokens) public returns (bool) {
        _transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) public returns (bool) {
        allowances_[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) public view returns (uint) {
        return allowances_[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        require(numTokens <= allowances_[owner][msg.sender]);
        allowances_[owner][msg.sender] = allowances_[owner][msg.sender].sub(numTokens);

        _transfer(owner, buyer, numTokens);
        return true;
    }

    function _transfer(address _from, address _to, uint _value) private {
        require(_value <= balances_[_from], 'Must not send more than balance');
        require(balances_[_to] + _value >= balances_[_to], 'Balance overflow');
        balances_[_from] = balances_[_from].sub(_value);
        balances_[_to] = balances_[_to].add(_value);
        emit Transfer(_from, _to, _value);
    }

    //======================================LOTTERY=========================================//
    function getNumDaysLotteryJoined(address _member, uint _era) external view returns(uint) {
        return mapMemberEra_LotteryDays[_member][_era].length;
    }
    
    function getDaysLotteryJoined(address _member, uint _era) external view returns(uint[] memory, uint[] memory) {
        uint[] memory _days = mapMemberEra_LotteryDays[_member][_era];
        uint[] memory _remainingShares = new uint[](_days.length);
        for (uint i = 0; i < _days.length; i++) {
            _remainingShares[i] = mapEraDayMember_LotteryShares[_era][_days[i]][_member];
        }
        return (mapMemberEra_LotteryDays[_member][_era], _remainingShares);
    }

    function joinLottery() external returns(bool) {
        if (mapEraDayMember_LotteryShares[currentEra][currentDay][msg.sender] > 0) {
            _updateEmission();
            return false;
        } else {
            uint _now = now;
            uint randomShareAmount = (_now%10) + 1;
            mapEraDayMember_LotteryShares[currentEra][currentDay][msg.sender] = randomShareAmount;
            mapEraDay_LotteryTotalShares[currentEra][currentDay] += randomShareAmount;
            mapEraDay_SharesRemaining[currentEra][currentDay] += randomShareAmount;
            mapMemberEra_LotteryDays[msg.sender][currentEra].push(currentDay);
            mapEraDay_LotteryMemberCount[currentEra][currentDay] += 1;
            mapEraDay_LotteryMembers[currentEra][currentDay].push(msg.sender);
            _updateEmission();
            return true;
        }
    }

    function withdrawAllLotteryWins(uint era) external returns (uint value) {
        uint numDays = mapMemberEra_LotteryDays[msg.sender][era].length;
        value = 0;
        for(uint i = 0; i < numDays; i++){
            uint day = mapMemberEra_LotteryDays[msg.sender][era][i];
            value += _withdrawShare(era, day, msg.sender);
        }
    }

    function withdrawLottery(uint era, uint day) external returns (uint value) {
        value = _withdrawShare(era, day, msg.sender);                           
    }

    function _withdrawShare(uint _era, uint _day, address _member) private returns (uint value) {
        _updateEmission();
        if (_era < currentEra) {                                                            // Allow if in previous Era
            value = _processWithdrawal(_era, _day, _member);                                // Process Withdrawal
        } else if (_era == currentEra) {                                                    // Handle if in current Era
            if (_day < currentDay) {                                                        // Allow only if in previous Day
                value = _processWithdrawal(_era, _day, _member);                            // Process Withdrawal
            }
        }  
        return value;
    }

    function _processWithdrawal(uint _era, uint _day, address _member) private returns (uint value) {
        uint memberShares = mapEraDayMember_LotteryShares[_era][_day][_member];                      // Get Member Units
        if (memberShares == 0) { 
            value = 0;                                                                      // Do nothing if 0 (prevents revert)
        } else {
            value = getMemberLotteryWin(_era, _day, _member);                               // Get the emission Share for Member
            mapEraDayMember_LotteryShares[_era][_day][_member] = 0;                         // Set to 0 since it will be withdrawn
            mapEraDay_SharesRemaining[_era][_day] = mapEraDay_SharesRemaining[_era][_day].sub(memberShares);  // Decrement Member Units
            mapEraDay_EmissionRemaining[_era][_day] = mapEraDay_EmissionRemaining[_era][_day].sub(value);     // Decrement emission
            totalEmitted += value;                                                          // Add to Total Emitted
            _transfer(address(this), _member, value);                                    // ERC20 transfer function
            emit Withdrawal(msg.sender, _member, _era, _day, value, mapEraDay_EmissionRemaining[_era][_day]);
        }
        return value;
    }

    function getMemberLotteryWin(uint era, uint day, address member) public view returns (uint value) {
        uint memberShares = mapEraDayMember_LotteryShares[era][day][member];
        if (memberShares == 0) {
            return 0;                                                                       // If 0, return 0
        } else {
            uint totalUnits = mapEraDay_SharesRemaining[era][day];                           // Get Total Units
            uint emissionRemaining = mapEraDay_EmissionRemaining[era][day];                 // Get emission remaining for Day
            uint balance = balances_[address(this)];                                        // Find remaining balance
            if (emissionRemaining > balance) { emissionRemaining = balance; }               // In case less than required emission
            value = (emissionRemaining * memberShares) / totalUnits;                         // Calculate share
            return value;                            
        }
    }

    //======================================EMISSION========================================//
    // Internal - Update emission function
    function _updateEmission() private {
        uint _now = now;                                                                    // Find now()
        if (_now >= nextDayTime) {                                                          // If time passed the next Day time
            if (currentDay >= daysPerEra) {                                                 // If time passed the next Era time
                currentEra += 1; currentDay = 0;                                            // Increment Era, reset Day
                nextEraTime = _now + (secondsPerDay * daysPerEra);                          // Set next Era time
                emission = getNextEraEmission();                                            // Get correct emission
                mapEra_Emission[currentEra] = emission;                                     // Map emission to Era
                emit NewEra(currentEra, emission, nextEraTime);                 // Emit Event
            }
            currentDay += 1;                                                                // Increment Day
            nextDayTime = _now + secondsPerDay;                                             // Set next Day time
            emission = getDayEmission();                                                    // Check daily Emission
            mapEraDay_EmissionRemaining[currentEra][currentDay] = emission;
            emit NewDay(currentEra, currentDay, nextDayTime);                // Emit Event
        }
    }
    // Calculate Era emission
    function getNextEraEmission() public view returns (uint) {
        if (emission > coin) {                                                              // Normal Emission Schedule
            return emission / 2;                                                            // Emissions: 2048 -> 1.0
        } else{                                                                             // Enters Fee Era
            return coin;                                                                    // Return 1.0 from fees
        }
    }
    // Calculate Day emission
    function getDayEmission() public view returns (uint) {
        uint balance = balances_[address(this)];                                            // Find remaining balance
        if (balance > emission) {                                                           // Balance is sufficient
            return emission;                                                                // Return emission
        } else {                                                                            // Balance has dropped low
            return balance;                                                                 // Return full balance
        }
    }


    //======================================GAMBLING=========================================//
    function createBet(string calldata _description, bytes32[] calldata _options, uint256 _betDurationInHours) external returns (uint256) {
        require(_betDurationInHours > 0, "The betting period cannot be 0.");
        betCount++;
        Bet storage curBet = bets_[betCount];
        curBet.creator = msg.sender;
        curBet.status = BetStatus.IN_PROGRESS;
        curBet.expirationTime = now + _betDurationInHours * 1 hours;
        curBet.description = _description;
        curBet.optionCount = _options.length;
        for (uint i = 0; i < curBet.optionCount; i++) {
            curBet.options[i] = bytes32ToStr(_options[i]);
        }
        mapMember_BetsCreated[msg.sender].push(betCount);
        mapMember_BetsCreatedCount[msg.sender] += 1;
        emit betCreated(msg.sender, betCount, _description, _betDurationInHours);
        return betCount;
	}

    function placeBet(uint256 _betID, uint _option, uint256 _betAmount) external validBet(_betID)
	{
        require(_betAmount > 0, "Bet size should be a positive number");
        require(_option > 0 && _option <= bets_[_betID].optionCount, "Option not in range");
        require(bets_[_betID].status == BetStatus.IN_PROGRESS, "Bet has expired.");
		require(bets_[_betID].gamblerInfo[msg.sender].amount == 0, "User has already voted.");
		require(bets_[_betID].expirationTime > now, "Bet has expired.");

        bets_[_betID].jackpot += _betAmount;
        bets_[_betID].mapOption_SumAmount[_option] += _betAmount;
        bets_[_betID].gamblers.push(msg.sender);
        bets_[_betID].gamblerInfo[msg.sender].option = _option;
        bets_[_betID].gamblerInfo[msg.sender].amount = _betAmount;

        transfer(address(this), _betAmount);

        mapMember_BetsJoined[msg.sender].push(_betID);
        mapMember_BetsJoinedCount[msg.sender] += 1;

        emit BetPlaced(msg.sender, _betID, _option, _betAmount);
    }

    function endBet(uint256 _betID, uint winOption) external validBet(_betID)
	{
        require(msg.sender == bets_[_betID].creator || msg.sender == deployer, "Permission denied.");
		require(bets_[_betID].status == BetStatus.IN_PROGRESS, "Bet has already ended.");
		require(now >= bets_[_betID].expirationTime, "Betting period has not expired");

        bets_[_betID].status = BetStatus.ENDED;
        bets_[_betID].winOption = winOption;

		emit betStatusUpdate(_betID, bets_[_betID].status);
	}

    function withdrawBet(uint256 _betID) external returns (uint value) {
        value = betWinWithdrawal(_betID, msg.sender);                           
    }

    function betWinWithdrawal(uint256 _betID, address _member) private validBet(_betID) returns (uint value) {
        value = getMemberBetWin(_betID, _member);
        if (value > 0) { 
            bets_[_betID].gamblerInfo[_member].withdrawn = true;
            _transfer(address(this), _member, value);
            emit BetWithdrawal(msg.sender, _member, value, _betID);
        }
        return value;
    }

    function getMemberBetWin(uint256 _betID, address _member) public view validBet(_betID) returns (uint value) {
        uint memberShares = bets_[_betID].gamblerInfo[_member].amount;
        bool memberShareWithdrawn = bets_[_betID].gamblerInfo[_member].withdrawn;
        if (memberShares == 0 || memberShareWithdrawn == true) {
            return 0;                                                                       // If 0, return 0
        } else {
            uint allWinnerInvestedUnits = bets_[_betID].mapOption_SumAmount[bets_[_betID].winOption];
            uint _jackpot = bets_[_betID].jackpot;
            uint balance = balances_[address(this)];
            if (_jackpot > balance) { _jackpot = balance; }
            value = (_jackpot * memberShares) / allWinnerInvestedUnits;
            return value;                            
        }
    }

    modifier validBet(uint256 _betID)
	{
		require(_betID > 0 && _betID <= betCount, "Not a valid bet Id.");
		_;
	}

    function bytes32ToStr(bytes32 _bytes32) public pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}
