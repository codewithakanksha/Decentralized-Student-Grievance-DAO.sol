// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract StudentGrievanceDAO {
    enum Category { ACADEMIC, INFRASTRUCTURE, HOSTEL, OTHER }
    enum Status { PENDING, UNDER_REVIEW, RESOLVED, REJECTED }
    enum Role { STUDENT, WARDEN, CHAIRMAN, ADMIN }

    struct Complaint {
        uint256 id;
        string title;
        string description;
        address submittedBy;
        Category category;
        Status status;
        uint256 voteCount;
        uint256 submittedAt;
        address assignedTo;
        bool escalated;
    }

    struct Feedback {
        uint8 rating; // 1-5
        string comments;
    }

    uint256 public complaintCounter;
    uint256 public constant ESCALATION_TIME = 7 days;

    address public admin;
    mapping(address => Role) public roles;
    mapping(address => bool) public registeredStudents;
    mapping(uint256 => Complaint) public complaints;
    mapping(uint256 => address[]) public complaintVoters;
    mapping(address => uint256) public reputation;
    mapping(uint256 => Feedback[]) public feedbacks;

    modifier onlyStudent() {
        require(registeredStudents[msg.sender], "Not a registered student");
        _;
    }

    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.WARDEN || roles[msg.sender] == Role.CHAIRMAN || roles[msg.sender] == Role.ADMIN, "Not authorized");
        _;
    }

    constructor() {
        admin = msg.sender;
        roles[msg.sender] = Role.ADMIN;
    }

    function registerStudent() public {
        require(!registeredStudents[msg.sender], "Already registered");
        registeredStudents[msg.sender] = true;
        roles[msg.sender] = Role.STUDENT;
    }

    function submitComplaint(string memory _title, string memory _description, Category _category) public onlyStudent {
        complaintCounter++;
        complaints[complaintCounter] = Complaint({
            id: complaintCounter,
            title: _title,
            description: _description,
            submittedBy: msg.sender,
            category: _category,
            status: Status.PENDING,
            voteCount: 1,
            submittedAt: block.timestamp,
            assignedTo: admin,
            escalated: false
        });
        complaintVoters[complaintCounter].push(msg.sender);
    }

    function vote(uint256 _id) public onlyStudent {
        require(_id <= complaintCounter, "Invalid ID");
        address[] storage voters = complaintVoters[_id];
        for (uint i = 0; i < voters.length; i++) {
            require(voters[i] != msg.sender, "Already voted");
        }
        complaints[_id].voteCount++;
        voters.push(msg.sender);
    }

    function escalateIfOverdue(uint256 _id) public {
        Complaint storage comp = complaints[_id];
        require(comp.status == Status.PENDING, "Not pending");
        require(block.timestamp > comp.submittedAt + ESCALATION_TIME, "Not overdue");
        comp.assignedTo = admin;
        comp.escalated = true;
    }

    function resolveComplaint(uint256 _id, bool accepted) public onlyAdmin {
        Complaint storage comp = complaints[_id];
        require(comp.status == Status.PENDING || comp.status == Status.UNDER_REVIEW, "Already resolved");
        comp.status = accepted ? Status.RESOLVED : Status.REJECTED;
    }

    function submitFeedback(uint256 _id, uint8 _rating, string memory _comment) public onlyStudent {
        require(_rating >= 1 && _rating <= 5, "Invalid rating");
        Complaint storage comp = complaints[_id];
        require(comp.status == Status.RESOLVED || comp.status == Status.REJECTED, "Not closed yet");
        require(comp.submittedBy == msg.sender, "Only complainant can rate");

        feedbacks[_id].push(Feedback(_rating, _comment));
        reputation[comp.assignedTo] += _rating;
    }

    function getComplaint(uint256 _id) public view returns (string memory, string memory, Status, uint256) {
        Complaint storage comp = complaints[_id];
        return (comp.title, comp.description, comp.status, comp.voteCount);
    }
}
