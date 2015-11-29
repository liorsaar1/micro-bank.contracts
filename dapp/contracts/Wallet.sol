import "std.sol";

contract Oracle is named("Oracle") {
    event Notify(string phone, uint value);
    
    function Oracle() {
        log1("Oracle: owner", bytes32(msg.sender));
    }
    
    function notify(string phone, uint value){
        log1("Oracle: notify", bytes32(msg.sender));
        Notify(phone, value);
    }
    
    function confirmed(string phone, uint value) {
        log0("Oracle: confirmed");
    }
}

contract Wallet is named("Wallet") {

    Oracle oracle;
    string phone;
    event Feedback(string text);
    
    function Wallet() {
        log1("wallet: owner", bytes32(msg.sender));
    }
    
    function setPhone(string _phone) {
        log0("wallet: phone");
        phone = _phone;
    }
    
    function setOracle(address oracleAddress) {
        log1("walet: set oracle", bytes32(msg.sender));
        oracle = Oracle(oracleAddress);
        Feedback( "wallet: done: setOracle");
    }
    
    function spend(uint value){
        log1("wallet: spend", bytes32(msg.sender));
        oracle.notify(phone, value);
        Feedback( "wallet: done: spend ");
    }
}