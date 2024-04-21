import hre from "hardhat"

async function main() {
  // Deploy Mock Pool
  const mockPoolFactory = await hre.ethers.getContractFactory(
    "SimpleStakingPool"
  )

  const mockPool = await mockPoolFactory.deploy(
    "0x12373B5085e3b42D42C1D4ABF3B3Cf4Df0E0Fa01",
    "0x82405D1a189bd6cE4667809C35B37fBE136A4c5B",
    "0x3A203B14CF8749a1e3b7314c6c49004B77Ee667A",
    "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d"
  )

  console.debug({
    mockPool: mockPool.address,
  })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
