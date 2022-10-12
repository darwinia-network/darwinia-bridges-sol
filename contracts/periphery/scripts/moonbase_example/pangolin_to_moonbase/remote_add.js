process.env.HARDHAT_NETWORK = "pangolin"
const hre = require("hardhat");

async function main() {
    const caller_address = process.argv[2]
    const callee_adderss = process.argv[3]
    console.log(`caller: ${caller_address}, callee: ${callee_adderss}`);

    const caller = await hre.ethers.getContractAt("RemoteExecute_FromPangolinToMoonbase", caller_address);

    const fee = hre.ethers.utils.parseEther("300");
    const tx = await caller.remoteAdd(callee_adderss, { value: fee })
    console.log(tx.hash)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});