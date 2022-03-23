var MyContract=artifacts.require("./MyToken.sol");
module.exports=function(deployer)
{
    deployer.deploy(MyContract,10000,10);
}