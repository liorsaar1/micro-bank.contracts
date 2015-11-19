import "std.sol";
import "set.sol";

contract MicroBank is abstract, owned, administrated, named("ether-camp/micro-bank"), SetUtil {

    struct Debtor {
        bytes32 nick; 
        address account;
        mapping(bytes32 => string) publicProfiles;
        mapping(bytes32 => string) additionalInfo;
        Set_ui32  askIds;
        Set_ui32  activeAskIds;
        Set_ui32  completedAskIds;
    }
    
    struct Creditor {
        bytes32 nick; 
        address account;
        uint    balance;
        mapping(bytes32 => string) additionalInfo;
        Set_ui32  bidIds;
        Set_ui32  activeBidIds;
        Set_ui32  completedBidIds;
    }
    
    struct Ask {
        uint  createTime;
        address debtor;
        uint    amount;
        uint32  creditDays;
        string  comment;
        // auto accept %%
        Set_ui32  bidIds; 
    }
    
    struct Bid {
        uint  createTime;
        address creditor;
        uint32  askId;
        uint    amount;
        uint32  percentsPerDay;  // N% * 1000;
        uint32  dealId;
    }
    
    struct Deal {
        uint createTime;
        uint32  bidId;
        uint    amount;
        uint lastRefundTime;
        uint remainingAmount;
        Refund[] refunds;
    }
    
    struct Refund {
        uint  time;
        uint  amount;
        uint  interest;
    }
    
    address[] debtorList;
    Set_addr creditorList;
    mapping(address => Debtor) debtors;
    mapping(address => Creditor) creditors;
    mapping(uint32 => Bid) bids;
    mapping(uint32 => Ask) asks;
    mapping(uint32 => Deal) deals;
    
    // for testing
    function resetAll() onlyowner;
    
    function isCreditor() constant returns (bool res) { return creditors[msg.sender].account != 0; } 
    function isDebtor() constant returns (bool res) { return debtors[msg.sender].account != 0; } 

    // accounts management
    function debtorRegister(bytes32 nick); 
    function debtorConfirmPublicProfile(address debtor, bytes32 profileName, string url) onlyadmin; 
    function debtorRemovePublicProfile(bytes32 profileName); 
    function debtorUpdateInfo(bytes32 infoField, string info);
    
    function creditorUpdateNick(bytes32 nick); 
    function creditorUpdateInfo(bytes32 infoField, string info);
    function creditorDeposit(); 
    function creditorWithdraw(uint amount) returns (string error);
    function creditorWithdrawAll();
    
    // // bids/asks
    function debtorAddAsk(uint amount, uint32 creditDays, string comment) returns (uint32 askId);
    function debtorCancelAsk(uint32 askId) returns (bytes32 error);
    function debtorAcceptBid(uint32 bidId, uint amount) returns (uint32 dealId);
    // function debtorRefund();
    
    function creditorAddBid(uint32 askId, uint amount, uint32 percentsPerDay) returns (uint32 bidId);
    function creditorCancelBid(uint32 bidId) returns (bytes32 error);
    
    // // query debtor data
    function getDebtors() constant returns (address[] debtor) { return debtorList;} 
    function getActiveDebtorsCount() constant returns (uint);
    function getActiveDebtor(uint idx) constant returns (address debtor);
    function getDebtorAsksCount(address debtor) constant returns (uint) { return setCompact(debtors[debtor].askIds);}
    function getDebtorAsk(address debtor, uint idx) constant returns (uint32) {return debtors[debtor].askIds.arr[idx];}
    function getDebtorAsks(address debtor) constant returns (uint32[]) {return debtors[debtor].askIds.arr;}
    function getDebtorActiveAsksCount(address debtor) constant returns (uint) { return setCompact(debtors[debtor].activeAskIds);}
    function getDebtorActiveAsk(address debtor, uint idx) constant returns (uint32) {return debtors[debtor].activeAskIds.arr[idx];}
    function getDebtorActiveAsks(address debtor) constant returns (uint32[]) {return debtors[debtor].activeAskIds.arr;}
    function getDebtorNick(address debtor) constant returns (bytes32 nick) { return debtors[debtor].nick; }
    function getDebtorPublicProfile(address debtor, bytes32 profileName) constant returns (string url) { return debtors[debtor].publicProfiles[profileName]; }
    function getDebtorInfo(address debtor, bytes32 infoField) constant returns (string info) { return debtors[debtor].additionalInfo[infoField]; }
    
    // // query creditor data
    function getCreditors() constant returns (address[]) { return creditorList.arr;} 
    function getCreditorBidCount(address creditor) constant returns (uint) { return creditors[creditor].bidIds.arr.length;}
    function getCreditorBidId(address creditor, uint idx) constant returns (uint32) { return creditors[creditor].bidIds.arr[idx];}
    function getCreditorBidIds(address creditor) constant returns (uint32[]) { return creditors[creditor].bidIds.arr;}
    function getCreditorActiveBidCount(address creditor) constant returns (uint) { return creditors[creditor].activeBidIds.arr.length;}
    function getCreditorActiveBidId(address creditor, uint idx) constant returns (uint32) { return creditors[creditor].activeBidIds.arr[idx];}
    function getCreditorActiveBidIds(address creditor) constant returns (uint32[]) { return creditors[creditor].activeBidIds.arr;}
    function getCreditorNick(address creditor) constant returns (bytes32 nick) { return creditors[creditor].nick; }
    function getCreditorBalance(address creditor) constant returns (uint balance) { return creditors[creditor].balance; }
    function getCreditorInfo(address creditor, bytes32 infoField) constant returns (string info) { return creditors[creditor].additionalInfo[infoField]; }
    
    // // query other structs
    function getAskDebtor(uint32 askId) constant returns (address) {return asks[askId].debtor; }
    function getAskTime(uint32 askId) constant returns (uint) {return asks[askId].createTime; }
    function getAskAmount(uint32 askId) constant returns (uint) {return asks[askId].amount; }
    function getAskCreditDays(uint32 askId) constant returns (uint32) {return asks[askId].creditDays; }
    function getAskComment(uint32 askId) constant returns (string) {return asks[askId].comment; }
    function getAskBidsCount(uint32 askId) constant returns (uint) {return setCompact(asks[askId].bidIds); }
    function getAskBidId(uint32 askId, uint idx) constant returns (uint32) {return asks[askId].bidIds.arr[idx]; }
    function getAskBidIds(uint32 askId) constant returns (uint32[]) {setCompact(asks[askId].bidIds); return asks[askId].bidIds.arr; }
    function getAskRemainingAmount(uint32 askId) constant returns (uint amount);
    
    function getBidCreditor(uint32 bidId) constant returns (address) {return bids[bidId].creditor; }
    function getBidTime(uint32 bidId) constant returns (uint) {return bids[bidId].createTime; }
    function getBidAmount(uint32 bidId) constant returns (uint) {return bids[bidId].amount; }
    function getBidPercents(uint32 bidId) constant returns (uint32) {return bids[bidId].percentsPerDay; }
    function getBidDeal(uint32 bidId) constant returns (uint32 dealId) {return bids[bidId].dealId; }
    function getBidRemainingAmount(uint32 bidId) constant returns (uint amount);
}