//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/// @title Voting
contract Voting is Ownable {
    //Workflow status
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //Type to keep track of General infos for the session
    struct VotingGenInfos {
        uint256 nbVoters;
        uint256 nbProposal;
        uint256 nbVoting;
        uint256 indexSession;
        WorkflowStatus sessionStatus;
    }

    //Type for a registered voter
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    //Type for a proposal
    struct Proposal {
        string description;
        uint256 voteCount;
    }

    uint256 winningProposalId; //Possible to have it in VotingGenInfos but to respect Cyril instructions!
    VotingGenInfos public votingInfos; //General info about each session
    mapping(address => Voter) voters; //Mapping voter address to type Voter
    mapping(uint256 => address) votersProposal; //To link proposal id to voter Address , not asked by Cyril!
    uint256[] winners; //List of winners in case of equality of voting
    Proposal[] public proposals; //Array of proposals

    event VoterRegisterationStarted(uint256 _indexSession);
    event VoterRegisterationEnded(uint256 _indexSession);
    event VoterUnRegistered(address voterAddress);
    event ProposalRegisterationStarted(uint256 _indexSession);
    event ProposalRegisterationEnded(uint256 _indexSession);
    event VotingRegisterationStarted(uint256 _indexSession);
    event VotingRegisterationEnded(uint256 _indexSession);
    event VoterRegistered(address voterAddress); //required by Cyril
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    ); //required by Cyril
    event ProposalRegistered(uint256 proposalId); //required by Cyril
    event Voted(address voter, uint256 proposalId); //required by Cyril

    /**************************************************************/
    /***********************    Modifiers   **********************/
    /*************************************************************/

    // Check if voter has been already added
    modifier newVoter(address _address) {
        //Voter has not been already added
        _;
    }

    // Check if voter address is 0
    modifier notZeroAdress(address _address) {
        require(_address != address(0), "Address 0 canno't be a voter!");
        _;
    }

    //Check if actuall caller is a Voter
    modifier onlyVoter() {
        require(voters[msg.sender].isRegistered, "Not a registered Voter!");
        _;
    }
    // check if voter is registered, no need to register again
    modifier voterNotRegistered(address _address) {
        require(!voters[_address].isRegistered, "Voter registered!");
        _;
    }

    // check if voter is Unregistered, no need to unregister again
    modifier voterRegistered(address _address) {
        require(voters[_address].isRegistered, "Voter Unregistered!");
        _;
    }

    // check if voter address is owner/admin adress
    modifier notAdminAdress(address _address) {
        require(_address != owner(), "Admin canno't be a voter!");
        _;
    }

    //check if the caller has already voted, to avoid more than 1 vote
    modifier hasNotVoted() {
        require(!voters[msg.sender].hasVoted, "Already voted!");
        _;
    }

    //Check if the the proposalId voted is valid
    modifier validProposalID(uint256 _idProposal) {
        require(
            _idProposal >= 0 && _idProposal < proposals.length, //valids : from 0 to lenght - 1
            "Not a valid proposal ID!"
        );
        _;
    }

    //Check if proposal description is not empty
    modifier validProposalDescription(string memory _description) {
        require(
            bytes(_description).length > 0,
            "Not a valid Proposal description!"
        );
        _;
    }

    //Check if we have at least one proposal to be voted
    modifier proposalsNotEmpty() {
        require(proposals.length > 0, "No proposal found!");
        _;
    }

    //Check if we have at least one voter
    modifier votersNotEmpty() {
        require(votingInfos.nbVoters > 0, "No Voters were registered!");
        _;
    }

    //check if at least we have 1 vote
    modifier votingNotEmpty() {
        require(votingInfos.nbVoting > 0, "No Voting was done!");
        _;
    }

    //Check if we can register proposal
    modifier ProposalsRegistrationOngoing() {
        require(
            votingInfos.sessionStatus ==
                WorkflowStatus.ProposalsRegistrationStarted,
            "Proposal Registration not ongoing!"
        );
        _;
    }

    //Check if we can vote
    modifier VotingSessionOngoing() {
        require(
            votingInfos.sessionStatus == WorkflowStatus.VotingSessionStarted,
            "Voting session not ongoing!"
        );
        _;
    }

    //Check if we votes tallied
    modifier VotesTallied() {
        require(
            votingInfos.sessionStatus == WorkflowStatus.VotesTallied,
            "Votes not yetTallied!"
        );
        _;
    }

    //check if proposal registration ended
    modifier ProposalsRegistrationEnded() {
        require(
            votingInfos.sessionStatus ==
                WorkflowStatus.ProposalsRegistrationEnded,
            "Proposal Registration has not ended yet!"
        );
        _;
    }

    //check if voting ended
    modifier VotingSessionEnded() {
        require(
            votingInfos.sessionStatus == WorkflowStatus.VotingSessionEnded,
            "Voting session has not ended yet!"
        );
        _;
    }

    constructor() {
        /*
        // Used constructor to test after seeing Cyril remark on teh Discord :), thanks @Cyril
        startRegisteringVoters(); //OnlyOwner
       // vote(1); // throw an error , not a voter
        // registerVoter(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4); //test cannot add Owner
        registerVoter(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2); //proposition 1 VOTE 1
        registerVoter(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db); //proposition 2 VOTE 1
        registerVoter(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB); //proposition 3 VOTE 2
        registerVoter(0x617F2E2fD72FD9D5503197092aC168c91465E7f2); //proposition 4 VOTE 2
        endRegisteringVoters(); //OnlyOwner
        //Proposal memory _proposalRejected =  ["proposal 1",0]
        propose("poposal 1"); // 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 //should throw an error, registering has not started
        startProposalRegisteration(); //OnlyOwner
        propose("poposal 1"); // -> should be done by 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2  
        propose("poposal 2"); // -> should be done by 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
        propose("poposal 3"); // -> should be done by 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
        //vote(1); // throw an error , sessionVoting Has not started
        endProposalRegisteration(); //OnlyOwner
         //vote(1); // throw an error , sessionVoting Has not started
         startVotingSession(); //OnlyOwner
         vote(1); // -> should be done by 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
         vote(1); // -> should be done by 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
         vote(2); // -> should be done by 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
         endVotingSession(); //OnlyOwner
         */
    }

    /*************************************************************/
    /***********************    Functions   **********************/
    /*************************************************************/

    //*********** Registering voters functions ***********//

    //First session ever, will be by default in 'RegisteringVoters', use this to reset status for the upcoming sessions
    function startRegisteringVoters() public onlyOwner {
        votingInfos.indexSession++;
        votingInfos.sessionStatus = WorkflowStatus.RegisteringVoters;
        emit VoterRegisterationStarted(votingInfos.indexSession);
    }

    function endRegisteringVoters() public onlyOwner {
        //no status to be set as per the instructions, we have only one status RegisteringVoters
        emit VoterRegisterationEnded(votingInfos.indexSession);
    }

    //Add voter only while in step registeringVoters
    function registerVoter(address _address)
        public
        onlyOwner
        notZeroAdress(_address)
        voterNotRegistered(_address)
        notAdminAdress(_address)
    {
        require(
            votingInfos.sessionStatus == WorkflowStatus.RegisteringVoters,
            "registering Voters not ongoing!"
        );
        voters[_address].isRegistered = true;
        votingInfos.nbVoters++;
        emit VoterRegistered(_address);
    }

    //Remove voter only while in step registeringVoters
    function unregisterVoter(address _address)
        public
        onlyOwner
        voterRegistered(_address)
    {
        require(
            votingInfos.sessionStatus == WorkflowStatus.RegisteringVoters,
            "registering Voters not ongoing!"
        );
        voters[_address].isRegistered == false;
        votingInfos.nbVoters--;
        emit VoterUnRegistered(_address);
    }

    function isVoter(address _address) public view returns (bool) {
        return voters[_address].isRegistered;
    }

    //*********** Proposal session functions ***********//
    function startProposalRegisteration() public onlyOwner {
        emit WorkflowStatusChange(
            votingInfos.sessionStatus,
            WorkflowStatus.ProposalsRegistrationStarted
        );
        votingInfos.sessionStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit VoterRegisterationStarted(votingInfos.indexSession);
    }

    function endProposalRegisteration() public onlyOwner {
        votingInfos.sessionStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit VoterRegisterationEnded(votingInfos.indexSession);
    }

    //NO limit to number of proposals by address
    function propose(string memory _description)
        public
        votersNotEmpty
        onlyVoter
        validProposalDescription(_description)
        ProposalsRegistrationOngoing
    {
        uint256 _indexProposal;
        Proposal memory _proposal;
        _proposal.description = _description; //voteCount by default is 0
        proposals.push(_proposal);
        _indexProposal = proposals.length - 1;
        votersProposal[_indexProposal] = msg.sender; //even if not asked, to keep link to Poposal origin Adress/voter
        votingInfos.nbProposal++;
        emit ProposalRegistered(_indexProposal);
    }

    //*********** Voting session functions ***********//
    function startVotingSession() public onlyOwner ProposalsRegistrationEnded {
        emit WorkflowStatusChange(
            votingInfos.sessionStatus,
            WorkflowStatus.VotingSessionStarted
        );
        votingInfos.sessionStatus = WorkflowStatus.VotingSessionStarted;
        emit VotingRegisterationStarted(votingInfos.indexSession);
    }

    function endVotingSession() public onlyOwner {
        emit WorkflowStatusChange(
            votingInfos.sessionStatus,
            WorkflowStatus.VotingSessionEnded
        );
        votingInfos.sessionStatus = WorkflowStatus.VotingSessionEnded;
        emit VotingRegisterationEnded(votingInfos.indexSession);
    }

    //Only one vote for registered Voters
    function vote(uint256 _idProposal)
        public
        onlyVoter
        hasNotVoted
        proposalsNotEmpty
        validProposalID(_idProposal)
        VotingSessionOngoing
    {
        emit Voted(msg.sender, _idProposal);
        proposals[_idProposal].voteCount++;
        votingInfos.nbVoting++;
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _idProposal;
    }

    //*********** Results session functions ***********//
    function accountVotes()
        public
        onlyOwner
        VotingSessionEnded
        votingNotEmpty
        returns (uint256)
    {
        uint256 _nbVoteMax;
        uint256 _randomIndexEquality;

        for (uint256 i = 0; i < proposals.length; i++) {
            if (_nbVoteMax < proposals[i].voteCount) {
                _nbVoteMax = proposals[i].voteCount;
                winningProposalId = i;
            }
        }

        //Extra code in case of equality, we will pick randomly a winner between the winners
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount == _nbVoteMax) {
                winners.push(i);
            }
        }

        if (winners.length > 1) {
            _randomIndexEquality = getRandom(winners.length);
            _randomIndexEquality--; //to correspond to array index starting from zero
            winningProposalId = winners[_randomIndexEquality];
        }

        emit WorkflowStatusChange(
            votingInfos.sessionStatus,
            WorkflowStatus.VotesTallied
        );
        votingInfos.sessionStatus = WorkflowStatus.VotesTallied;

        return winningProposalId;
    }

    function getWinner() public view VotesTallied returns (uint256) {
        return (winningProposalId);
    }

    function getWinnerDescription()
        public
        view
        VotesTallied
        returns (string memory)
    {
        return (proposals[winningProposalId].description);
    }

    function getWinningProposalAdress()
        public
        view
        VotesTallied
        returns (address)
    {
        return (votersProposal[winningProposalId]);
    }

    function resetAll() public onlyOwner {
        votingInfos.nbProposal = 0;
        votingInfos.nbVoting = 0;
        votingInfos.sessionStatus = WorkflowStatus.RegisteringVoters;

        for (uint256 i = 0; i < proposals.length; i++) {
            delete proposals[i];
        }
    }

    //*********** Utilities ***********//
    function getRandom(uint256 _nbWinners) public view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(block.timestamp))) %
            _nbWinners);
    }
}
