contract Test {
    uint a = 256;
    
    function set(uint s) {
        a = s;
    }
    
    function get() returns (uint) {
        return a;
    }
}