// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralizedVoting {
    address public admin;
    uint public registrationDeadline;

    enum VoterStatus { NOT_REGISTERED, REGISTERED, VOTED, BLACKLISTED }

    struct Voter {
        VoterStatus status;
        uint vote; // Option they voted for
    }

    mapping(address => Voter) public voters;
    mapping(uint => uint) public votesCount; // Option to vote count mapping

    modifier onlyBeforeRegistrationDeadline() {
        require(block.timestamp < registrationDeadline, "Registration period is over");
        _;
    }

    modifier onlyRegistered() {
        require(voters[msg.sender].status == VoterStatus.REGISTERED, "You are not registered to vote");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this method");
        _;
    }

    constructor(uint _registrationPeriodInDays) {
        admin = msg.sender;
        registrationDeadline = block.timestamp + (_registrationPeriodInDays * 1 days);
    }

    function register() external onlyBeforeRegistrationDeadline {
        require(voters[msg.sender].status == VoterStatus.NOT_REGISTERED, "You are already registered or blacklisted");
        voters[msg.sender] = Voter({
            status: VoterStatus.REGISTERED,
            vote: 0
        });
    }

    function castVote(uint option) external onlyRegistered {
        Voter storage voter = voters[msg.sender];

        if (voter.status == VoterStatus.VOTED) {
            // If voter tries to vote again
            votesCount[voter.vote]--; // Remove previous vote
            voter.status = VoterStatus.BLACKLISTED; // Blacklist the voter
        } else {
            voter.status = VoterStatus.VOTED;
            voter.vote = option;
            votesCount[option]++;
        }
    }

    function getVotes(uint option) external view returns (uint) {
        return votesCount[option];
    }

    function isBlacklisted(address voterAddress) external view returns (bool) {
        return voters[voterAddress].status == VoterStatus.BLACKLISTED;
    }

    function isRegistered(address voterAddress) external view returns (bool) {
        return voters[voterAddress].status == VoterStatus.REGISTERED;
    }
}
