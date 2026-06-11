// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract FreelanceEscrow {
    IERC20 public immutable usdc;

    struct Job {
        address client;
        address freelancer;
        uint256 totalAmount;
        uint256 released;
        uint256 milestones;
        uint256 milestonesApproved;
        bool cancelled;
    }
    Job[] public jobs;

    event JobCreated(uint256 indexed id, address client, address freelancer, uint256 total, uint256 milestones);
    event MilestoneApproved(uint256 indexed id, uint256 milestone, uint256 payout);
    event JobCancelled(uint256 indexed id, uint256 refunded);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
    }

    function createJob(address freelancer, uint256 totalAmount, uint256 milestones) external returns (uint256) {
        require(freelancer != address(0) && totalAmount > 0 && milestones > 0, "BAD_PARAMS");
        require(usdc.transferFrom(msg.sender, address(this), totalAmount), "DEPOSIT_FAILED");
        jobs.push(Job(msg.sender, freelancer, totalAmount, 0, milestones, 0, false));
        emit JobCreated(jobs.length - 1, msg.sender, freelancer, totalAmount, milestones);
        return jobs.length - 1;
    }

    function approveMilestone(uint256 id) external {
        Job storage j = jobs[id];
        require(msg.sender == j.client && !j.cancelled, "CANNOT");
        require(j.milestonesApproved < j.milestones, "ALL_DONE");
        j.milestonesApproved++;
        uint256 payout = j.totalAmount / j.milestones;
        j.released += payout;
        require(usdc.transfer(j.freelancer, payout), "PAY_FAILED");
        emit MilestoneApproved(id, j.milestonesApproved, payout);
    }

    function cancel(uint256 id) external {
        Job storage j = jobs[id];
        require(msg.sender == j.client && !j.cancelled, "CANNOT");
        j.cancelled = true;
        uint256 refund = j.totalAmount - j.released;
        if (refund > 0) require(usdc.transfer(j.client, refund), "REFUND_FAILED");
        emit JobCancelled(id, refund);
    }
}
