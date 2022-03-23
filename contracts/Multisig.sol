//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract MultiSigWallet {
    event Deposit(address sender, uint amount, uint balance); //when ether is deposited into the multi-sig wallet
    event Submit(uint txId); //when a transaction is submitted waiting for other owners to approve
    event Approve(address owner, uint txId); //Transaction approval by other owners
    event Revoke(address owner, uint txId); // Transaction revoke due to change of mind
    event Execute(uint txId);

    struct Transaction {
        address to; //address where the transaction is executed
        uint value; //amount of ether sent to address 
        bytes data;  //data to be sent to the to address
        bool executed; //Set to true once the transaction is executed
}
     
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required; //number of approvals required before a transaction is executed

    //store all of the data in a struct
    Transaction[] public transactions;
    //each transaction can be executed if the number of approval is greater than or equal to requied
    mapping(uint => mapping(address => bool)) public approved;
    //We will store the approval of each transaction by each owner in mapping

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only owner can call function"); //if the msg.sender is not the owner of the multisig
        _;
    }

    modifier transactionExists(uint _txId) {
        require(_txId < transactions.length, "Transaction does not exists");
        _; //execute if the transaction exists
    }

    modifier isNotApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "Transaction already approved");
        _;
    }

    modifier isNotExecuted(uint _txId) {
        require(transactions[_txId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require( required > 0 && _required <= _owners.length, "Invalid number of owners");

       //to make sure that the owner is not equal to the address 0
        for (uint i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner"); //owner not equal to 0
            require(!isOwner[owner],"owner is not unique"); //to make sure that owner is not included in isOwner

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    //only the owners will be able to submit  the transaction, once the transaction is submitted and has enough approvals, then any of the owners will be able to execute the transaction
    function submit(address _to, uint _value, bytes calldata _data)
         external
         onlyOwner{
             transactions .push(Transaction({
                 to: _to,
                 value: _value,
                 data: _data,
                 executed: false
             }));
             emit Submit(transactions.length - 1); //index where transaction is stored
         }

         function approve(uint _txId)
           external
           onlyOwner
           transactionExists(_txId) 
           isNotApproved(_txId)
           isNotExecuted(_txId)
           {
               approved[_txId][msg.sender] = true;
               emit Approve(msg.sender, _txId);
           }

           //We need to make that the number of approved is greater than the numbe of required
            function getApprovalCount(uint _txId) private view returns (uint count) {
                for (uint i; i < owners.length; i++) {
                    if (approved[_txId][owners[i]]) { //if owners of i has approved the transaction with _txId
                        count += 1;
                    }
                }
            }

            //function to execute the transaction

             function execute( uint _txId) external transactionExists(_txId) isNotExecuted(_txId) {
                require(getApprovalCount(_txId) >= required, "approvals < required");
                Transaction storage transaction = transactions[_txId];

                transaction.executed = true;

                (bool success, ) = transaction.to.call{value: transaction.value}(
                    transaction.data);
                require(success, "Transaction unsuccessful");

                emit Execute(_txId);
            }

            //Function if a owner wants to revoke the transaction before it is executed
            function revoke(uint _txId)
                external onlyOwner 
                transactionExists(_txId) 
                isNotExecuted(_txId)
            {
                require(approved[_txId][msg.sender], "Transaction not approved");
                approved[_txId][msg.sender] = false;
                emit Revoke(msg.sender, _txId);

            }


}
    