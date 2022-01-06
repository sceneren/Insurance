var MyContract=artifacts.require("./Insure.sol");
module.exports=function(deployer)
{
    deployer.deploy(MyContract,10,1000);
}