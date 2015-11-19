import "std.sol";
import "set.sol";
import "MicroBank.sol";

contract MicroBankImpl is /*abstract,*/ MicroBank {
    
    uint32 idCounter = 1;
    
    Set_addr activeDebtors;
    bytes32 public lastError;


    // accounts management
    function debtorRegister(bytes32 nick) {
        if (debtors[msg.sender].account == 0) {
            debtors[msg.sender].account = msg.sender;
            debtors[msg.sender].nick = nick;
            debtorList.length += 1;
            debtorList[debtorList.length - 1] = msg.sender;
        } else {
            // log1("Account already registered: ", bytes32(debtors[msg.sender].account));
        }
    }


    function getString() constant returns (string) {
        return "This is a very long string: longer than 32 bytes";
    }
    
    uint[] arr;
    function getArray() constant returns (uint[]) {
        arr.length = 2;
        arr[0] = 0x111111111111;
        arr[1] = 0x222222222222;
        return arr;
    }




    function resetAll() onlyowner {
        
//         for (uint i = 0; i < debtorList.length; i++) { 
// //            debtors[debtorList[i]];
//         }
// //        delete(debtorList);
//         for (uint j = 0; j < creditorList.length; j++) {
// //            delete(creditors[creditorList[j]]);
//         }
// //        delete(debtorList);

//         for (uint32 k = 0; k < 100; k++) {
//             Bid storage bid = bids[k];
//             // delete(bid);
//             // delete(asks[k]);
//             // delete(deals[k]);
//         }
//         // delete(activeDebtors);
//         idCounter = 1;
//         testNow = 0;
    }

    
    function debtorConfirmPublicProfile(address debtor, bytes32 profileName, string url) onlyadmin {
        if (debtors[msg.sender].account == 0) {
            // log1("Debtor account not registered: ", bytes32(debtor));
        } else {
            debtors[debtor].publicProfiles[profileName] = url;
        }
    }
    function debtorRemovePublicProfile(bytes32 profileName) {
        debtors[msg.sender].publicProfiles[profileName] = "";
    }
    
    function debtorUpdateInfo(bytes32 infoField, string info) {
        debtors[msg.sender].additionalInfo[infoField] = info;
    }
    
    function creditorUpdateNick(bytes32 nick) {
        creditors[msg.sender].nick = nick;
        setAddUnique(creditorList, msg.sender);
    }
    
    function creditorUpdateInfo(bytes32 infoField, string info) {
        creditors[msg.sender].additionalInfo[infoField] = info;
        setAddUnique(creditorList, msg.sender);
    }
    
    event BalanceChanged(address indexed creditor, uint delta, uint current);
    event AskEvent(address indexed debtor, uint code, uint32 askId);
    event BidEvent(address indexed creditor, address indexed debtor, uint code, uint32 bidId, uint32 askId);
    
    function creditorDeposit() {
        creditors[msg.sender].balance += msg.value;
        setAddUnique(creditorList, msg.sender);
        
        BalanceChanged(msg.sender, msg.value, creditors[msg.sender].balance);
    }
    
    function getCreditorBalance(address creditor) constant returns (uint) {
        return creditors[creditor].balance;
    }
    
    function creditorWithdraw(uint amount) returns (string error) {
        if (creditors[msg.sender].balance < amount) return "Insufficient funds to withdraw.";
        // need to leave funds for active bids 
        uint32[] memory cBids = getCreditorActiveBids(msg.sender);
        uint maxBid = 0;
        for (uint i = 0; i < cBids.length; i++) {
            Bid storage bid = bids[cBids[i]];
            if (bid.amount > maxBid) maxBid = bid.amount;
        }
        uint available = creditors[msg.sender].balance - maxBid;
        if (available < amount) return "Need to cancel some bids.";
        if (msg.sender.send(amount)) {
            creditors[msg.sender].balance -= amount;
            BalanceChanged(msg.sender, -amount, creditors[msg.sender].balance);
        }
    } 
    
    function creditorWithdrawAll() {
        Set_ui32 cBids = creditors[msg.sender].bidIds;
        uint len = setCompact(cBids);   
        for (uint i = 0; i < len; i++) {
            creditorCancelBid(cBids.arr[i]);
        }
        if (msg.sender.send(creditors[msg.sender].balance)) {
            creditors[msg.sender].balance = 0;
        }
    }
    
    function debtorAddAsk(uint amount, uint32 creditDays, string comment) returns (uint32 askId) {
        if (debtors[msg.sender].account == 0) {
            // log0("Debtor not registered: ");
            return 0;
        }
        askId = idCounter++;
        Set_ui32 memory empty;
        asks[askId] = Ask(getNow(), msg.sender, amount, creditDays, comment, empty);
        setAdd(debtors[msg.sender].askIds, askId);
        setAddUnique(activeDebtors, msg.sender);
        
        AskEvent(msg.sender, 1, askId);
    }
    
    function debtorCancelAsk(uint32 askId) returns (bytes32 error) {
        lastError = "";
        if (debtors[msg.sender].account == 0) { lastError = "Debtor not registered"; return; }
        if (asks[askId].createTime == 0) { lastError = "Invalid askId"; return; }
        if (asks[askId].debtor != msg.sender) { lastError = "Not a sender ask"; return; }
        Debtor storage debtor = debtors[asks[askId].debtor];
        if (!setHas(debtor.askIds, askId)) { lastError = "Ask is not active anymore"; return; }
        Set_ui32 storage bidIds = asks[askId].bidIds;
        uint len = setCompact(bidIds);
        for (uint i = 0; i < len; i++) {
            if (bids[bidIds.arr[i]].dealId == 0) {
                creditorCancelBidInt(bidIds.arr[i]);
            }
        }
        setRemove(debtor.askIds, askId);
        if (setCompact(debtor.askIds) == 0) {
            setRemove(activeDebtors, msg.sender);
        }
        
        AskEvent(msg.sender, 2, askId);
    }
    
    function debtorAcceptBid(uint32 bidId, uint amount) returns (uint32 dealId) {
        if (debtors[msg.sender].account == 0) { /*log1(0x2001, "Debtor not registered");*/ return 0; }
        if (bids[bidId].createTime == 0) { /*log1(0x2002, "Invalid bidId");*/return 0; }
        if (asks[bids[bidId].askId].debtor != msg.sender) { /*log1(0x2003, "Sender is not ask owner");*/return 0; }
        if (amount <= 0 || amount > bids[bidId].amount)  { /*log1(0x2004, "Amount > creditor bid amount");*/return 0; }
        Creditor storage creditorRef = creditors[bids[bidId].creditor];
        if (amount > creditorRef.balance) { /*log1(0x2005, "Creditor has insuficient funds.");*/ return 0; }// shouldn't happen
        if (amount > asks[bids[bidId].askId].amount - getAcceptedAmount(bids[bidId].askId)) {
            // log2("Amount > ask - accepted amount", bytes32(asks[bids[bidId].askId].amount), bytes32(getAcceptedAmount(bids[bidId].askId))); 
            return 0;
        }
        if (msg.sender.send(amount)) {
            creditorRef.balance -= amount;
            BalanceChanged(bids[bidId].creditor, -amount, creditorRef.balance);
            
            uint32 id = idCounter++;
            deals[id].createTime = getNow();
            deals[id].bidId = bidId;
            deals[id].amount = amount;
            deals[id].lastRefundTime = getNow();
            deals[id].remainingAmount = amount;

            bids[bidId].dealId = id;
            setRemove(creditorRef.bidIds, bidId);
            setAdd(creditorRef.activeBidIds, bidId);
            
            setAddUnique(debtors[msg.sender].activeAskIds, bids[bidId].askId);
            if (asks[bids[bidId].askId].amount == getAcceptedAmount(bids[bidId].askId)) {
                // ask is completely filled 
                setRemove(debtors[msg.sender].askIds, bids[bidId].askId);
                
                if (setCompact(debtors[msg.sender].askIds) == 0) {
                    setRemove(activeDebtors, msg.sender);
                }
            }
            
            BidEvent(bids[bidId].creditor, msg.sender, 3, bidId, bids[bidId].askId);
            
            return id;
        } else {
            // log1(0x2006, "Error sending funds to debtor");
        }
    }

    function getDealInterest(uint32 dealId) constant returns (uint amount) {
        Deal storage deal = deals[dealId];
        Bid storage bid = bids[deal.bidId];
        uint dayCnt = (getNow() - deal.lastRefundTime) / (1 days); // 86400 seconds in a day
        amount  = dayCnt * bid.percentsPerDay * deal.remainingAmount / 100 / 1000; // /100: percents, /1000: decimal point
    }

    function getBidRemainingAmount(uint32 bidId) constant returns (uint amount) {
        Bid storage bid = bids[bidId];
        if (bid.dealId > 0) {
            Deal storage deal = deals[bid.dealId];
            amount += deal.remainingAmount + getDealInterest(bid.dealId);
        }
    }

    function getAskRemainingAmount(uint32 askId) constant returns (uint amount)  {
        Ask storage ask = asks[askId];
        uint len = setCompact(ask.bidIds);
        for (uint i = 0; i < len; i++) {
            amount += getBidRemainingAmount(ask.bidIds.arr[i]);
        }
    }

    function refundBid(uint32 bidId, uint amount) internal returns (uint mainDebtRefund) {
        Bid storage bid = bids[bidId];
        uint32 dealId = bid.dealId;
        if (dealId == 0) {/*log1(0x4001, "No deal for the bid");*/ return;}
        Deal storage deal = deals[dealId];
        uint interest = getDealInterest(dealId);
        // TODO interest > amount
        Refund memory refund = Refund(getNow(), amount - interest, interest);
        deal.refunds.length += 1;
        deal.refunds[deal.refunds.length - 1] = refund;
        deal.lastRefundTime = getNow();
        deal.remainingAmount -= refund.amount;
        mainDebtRefund += refund.amount;
        if (deal.remainingAmount == 0) { 
            // bid is completely refunded
            deal.remainingAmount = 0;
            Creditor storage creditor = creditors[bid.creditor];
            setRemove(creditor.activeBidIds, bidId);
            setAdd(creditor.completedBidIds, bidId);
        }
    }

    function debtorRefund() returns (uint mainDebtRefund) {
        if (debtors[msg.sender].account == 0) { /*log1(0x3001, "Debtor not registered");*/ return; }
        uint refAmount = msg.value;
        Debtor storage debtor = debtors[msg.sender];
        uint len = setCompact(debtor.activeAskIds);
        for (uint i = 0; i < len && refAmount > 0; i++) {
            // log1(0x11111111001, bytes32(len));
            uint32 askId = debtor.activeAskIds.arr[i];
            Ask storage ask = asks[askId];
            uint remain = getAskRemainingAmount(askId);
            uint returnFactor = refAmount * 1000000 / remain;
            if (refAmount > remain) returnFactor = 1000000;
            uint len1 = setCompact(ask.bidIds);
            uint refunded = 0;
            for (uint j = 0; j < len1; j++) {
                // log1(0x11111111002, bytes32(len1));
                uint32 bidId = ask.bidIds.arr[j];
                uint bidRefundAmount = getBidRemainingAmount(bidId) * returnFactor / 1000000;
                if (j == len1 - 1) {
                    bidRefundAmount = refAmount - refunded;
                }
                // log1(0x11111111003, bytes32(bidRefundAmount));
                mainDebtRefund += refundBid(bidId, bidRefundAmount); 
                refunded += bidRefundAmount;
            }
            if (refAmount > remain) {
                // ask is completely refunded
                setRemove(debtor.activeAskIds, askId);
                setAdd(debtor.completedAskIds, askId);
            }
        }
    }
    

    function getAcceptedAmount(uint32 askId) returns (uint amount){
        Set_ui32 bidIds = asks[askId].bidIds;
        uint len = setCompact(bidIds);
        for (uint i =0; i < len; i++) {
            if (bids[bidIds.arr[i]].dealId != 0) {
                amount += deals[bids[bidIds.arr[i]].dealId].amount;
            }
        }
    }
    
    function creditorAddBid(uint32 askId, uint amount, uint32 percentsPerDay) returns (uint32 bidId) {
        if (asks[askId].createTime == 0) { /*log1(0x1000, "Invalid askId");*/return 0; }
        if (creditors[msg.sender].balance < amount) { /*log1(0x1001, "Creditor has insuficient funds.");*/return 0; }
        if (!setHas(debtors[asks[askId].debtor].askIds, askId)) { /*log1(0x1002, "This ask is not active any more.");*/return 0; }
        bidId = idCounter++;
        bids[bidId] = Bid(getNow(), msg.sender, askId, amount, percentsPerDay, 0);
        setAdd(creditors[msg.sender].bidIds, bidId);
        setAdd(asks[askId].bidIds, bidId);
        
        BidEvent(msg.sender, asks[askId].debtor, 1, bidId, askId);
    }
    
    function creditorCancelBid(uint32 bidId) returns (bytes32 error) {
        if (bids[bidId].creditor != msg.sender) return ("Sender is not bid owner");
        if (bids[bidId].createTime == 0) return ("Invalid bidId");
        if (bids[bidId].dealId != 0) return ("The bid already accepted.");
        return creditorCancelBidInt(bidId);
    }
    
    function creditorCancelBidInt(uint32 bidId) internal returns (bytes32 error) {
        Creditor storage creditor = creditors[bids[bidId].creditor];
        if (!setHas(creditor.bidIds, bidId)) return ("The bid already accepted.");
        Ask storage ask = asks[bids[bidId].askId];
        setRemove(ask.bidIds, bidId);
        setRemove(creditor.bidIds, bidId);
        
        BidEvent(bids[bidId].creditor, ask.debtor, 2, bidId, bids[bidId].askId);
    }
    
    
    function getActiveDebtorsCount() constant returns (uint) {
        return setCompact(activeDebtors);
    }
    function getActiveDebtor(uint idx) constant returns (address debtor) {
        return activeDebtors.arr[idx];
    }
    
    function getCreditorActiveBids(address creditor) constant returns (uint32[] bidIds) {}
    
    uint testNow;
    function getNow() returns (uint) {
        if (testNow == 0) return now;
        return testNow;
    }
    
    function setNow(uint n) {
        testNow = n;
    }
}

// contract Debtor is abstract, util {
    
//     MicroBankImpl mb;
    
//     function Debtor(MicroBankImpl _mb) {
//         mb = _mb;
//     }
    
//     function reg() {
//         log0("Registering debtor...");
//         mb.debtorRegister("Debtor1");
//         // uint32[] memory asks = mb.getDebtorActiveAsks(this);
//     }

//     function addAsk(uint amount) returns (uint32 id) {
//         log0("Adding ask...");
//         id = mb.debtorAddAsk(amount, 7, "debtor comment");
//         log1("ID: ", bytes32(id));
//     }
    
//     function cancelAsk(uint32 id) returns (bytes32 s){
//         s = mb.debtorCancelAsk(id);
//         // log1("Cancel: ", s);
//     }

//     function acceptBid(uint32 bidId, uint amount) returns (uint32) {
//         return mb.debtorAcceptBid(bidId, amount);
//     }
    
//     function refund(uint amount) returns (uint){
//         return mb.debtorRefund.value(amount)();
//     }
    
// }

// contract Creditor is abstract, util {
    
//     MicroBankImpl mb;
    
//     function Creditor(MicroBankImpl _mb) {
//         mb = _mb;
//     }
    
//     function deposit(uint amount) {
//         mb.creditorDeposit.value(amount)();
//     }
    
//     function addBid(uint32 askId, uint amount, uint32 percentsPerDay) returns (uint32 bidId) {
//         return mb.creditorAddBid(askId, amount, percentsPerDay);
//     }
    
//     function cancelBid(uint32 bidId) returns (bytes32) {
//         return mb.creditorCancelBid(bidId);
//     }
    
// }

// contract Test is SetUtil, nameRegAware {
    
//     Debtor d1;
//     Creditor c1;
//     MicroBankImpl mb;
    
//     function init() {
//         log0("Creating bank...");
//         // mb = MicroBankImpl(named("ether-camp/micro-bank"));
//         mb = new MicroBankImpl();
//         log0("Creating debtor...");
//         d1 = new Debtor(mb);
//         log0("Creating creditor...");
//         c1 = new Creditor(mb);
//     }
    
//     function assert(bool b, bytes32 msg) {
//         if (!b) {
//             log1("UUUUUUUUUUUUUU", msg);
//             // int[] memory i;
//             // i[100] = 1; // generate exception
//         }
//     }
//     function assert(bool b) {
//         if (!b) {
//             log0("UUUUUUUUUUUUUU");
//             // int[] memory i;
//             // i[100] = 1; // generate exception
//         }
//     }
    
//     function test1() {
//         d1.reg();

//             assert(mb.getDebtorActiveAsksCount(d1) == 0);
//             assert(mb.getActiveDebtorsCount() == 0);
//         uint32 id1 = d1.addAsk(0x1111);
//             assert(mb.getDebtorActiveAsksCount(d1) == 1);
//             assert(mb.getActiveDebtorsCount() == 1);
//         uint32 id2 = d1.addAsk(0x2222);
//             assert(mb.getDebtorActiveAsksCount(d1) == 2);
//         d1.cancelAsk(id1);
//             assert(mb.getDebtorActiveAsksCount(d1) == 1);
//         uint32 askId = mb.getDebtorActiveAsk(d1, 0);
//             assert(id2 == askId);
//             assert(mb.getActiveDebtorsCount() == 1);
//         d1.cancelAsk(id2);
//             assert(mb.getDebtorActiveAsksCount(d1) == 0);
//             assert(mb.getActiveDebtorsCount() == 0);
        
//         log0("dddddddddddddd");
//     }
    
//     function test2() {
//         mb.setNow(1);
//         c1.send(0x88888);
//         d1.send(0x222);
//         d1.reg();
//         c1.deposit(0x3333);
//             assert(mb.getCreditorBalance(c1) == 0x3333, 0x111111);
//         uint32 askId = d1.addAsk(0x2000);
//             assert(askId > 0, 0x111112);
//         uint32 bidId = c1.addBid(askId, 0x1555, 1000);
//             assert(bidId > 0, 0x111113);
//         uint oldBalance = d1.balance;
//         uint32 dealId = d1.acceptBid(bidId, 0x1111);
//             assert(dealId > 0, 0x111114);
//             assert(d1.balance > oldBalance, 0x111115);
//         bytes32 ret = c1.cancelBid(bidId);
//             assert(ret != 0, 0x111116);
//             assert(mb.getDebtorActiveAsksCount(d1) > 0, 0x111118);
//         bidId = c1.addBid(askId, 0x2000, 2000);
//         dealId = d1.acceptBid(bidId, 0x2000 - 0x1111);
//             assert(d1.balance - oldBalance == 0x2000, 0x111119);
//             assert(mb.getDebtorActiveAsksCount(d1) == 0, 0x111120);
//             assert(d1.cancelAsk(askId) != 0, 0x111121);
//         uint rem = mb.getAskRemainingAmount(askId);
//         log1(0x77777, bytes32(rem));
//         uint ref = d1.refund(0xE00);
//         log1(0x77777, bytes32(ref));
//         rem = mb.getAskRemainingAmount(askId);
//             assert(rem < 0x2000 && rem > 0, 0x111122);
//         log1(0x77777, bytes32(rem));
//         mb.setNow(mb.getNow() + 2 days);
//         ref = d1.refund(0x1200);
//         rem = mb.getAskRemainingAmount(askId);
//             assert(rem < 0x200 && rem > 0, 0x111123);
//         ref = d1.refund(rem);
//         rem = mb.getAskRemainingAmount(askId);
//             assert(rem == 0, 0x111124);

//         log0("dddddddddddddd");
//     }
    
//     function test3() {
//         mb.setNow(1);
//         c1.send(0x88888);
//         d1.reg();
//         c1.deposit(0x3333);
//         uint32 askId = d1.addAsk(0x2000);
//         uint32 bidId = c1.addBid(askId, 0x1500, 1000);
//         uint32 dealId = d1.acceptBid(bidId, 0x1000);
        
//         uint rem = mb.getAskRemainingAmount(askId);
//         log1(0x77777, bytes32(rem));
//         mb.setNow(mb.getNow() + 4 days);
//         uint ref = d1.refund(0x1000);
//         log1(0x77777, bytes32(ref));
//         rem = mb.getAskRemainingAmount(askId);
//         log1(0x77777, bytes32(rem));
//         d1.send(0x1000);  // adding for interest pay off
//         d1.refund(rem);
//         log1(0x77777, bytes32(mb.getAskRemainingAmount(askId)));

        
//         log0("dddddddddddddd");
//     }

//     Set_ui32 set;
//     struct A {
//         Set_ui32 s;
//     }
//     mapping(uint => A) a;

//     function testSet() {
//         setAdd(set, 0x5555);
//         setAdd(set, 0x7777);
//         setRemove(set, 0x5555);
//         uint size = setCompact(set);
//         log0(bytes32(size));
//         setRemove(set, 0x7777);
        
//         size = setCompact(set);
//         log0(bytes32(size));
//         setAdd(a[1].s, 0x6666);
//     }
// }
