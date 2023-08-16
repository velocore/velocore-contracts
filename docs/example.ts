const toToken = (spec: string, id: BigInt, addr: Address) => solidityPack(["uint8", "uint120", "address"], [["erc20", "erc721", "erc1155"].indexOf(spec), id, addr])
const poolId = (pool: Address) => solidityPack(["bytes1", "uint120", "address"], ["0x00", 0, pool])
const gaugeId = (gauge: Address) => solidityPack(["bytes1", "uint120", "address"], ["0x01", 0, gauge])



// positive amount ==> user pays
// negative amount ==> user receives
const tokenInformation = (index: number, amountKind: string, amount: BigInt) => solidityPack(["uint8", "uint8", "uint112", "uint128"], [
  index,
  ["exactly", "at most", "all"].indexOf(amountKind),
  0,
  amount,
])

const toVelocoreOperation = (id: bytes32, tokenInformations: Array<bytes32>) => ({
  poolId: id, // poolId or gaugeId
  tokenInforamtions,
  data: []
})



vault.execute(Token[] calldata tokenRef, int128[] memory deposit, VelocoreOperation[] calldata ops)


const compileAndExecute = (ops) => {
  const tokenRef = [...new Set(ops.map(x => x[1].map(i => i[0])))].sort();
  return vault.execute(tokenRef, (new Array(tokenRef.length)).fill(0n), ops.map((op => ({
    poolId: op[0]
    tokenInforamtions: op[1].map(i => tokenInformation(tokenRef.indexOf(i[0]), i[1], i[2])),
    data: []
  }))))
}



await compileAndExecute([
  [
    poolId(usdcusdtPool),
    [
      [usdc, "exactly", 1234n],
      [usdt, "at most", 1 - (2n << 127n)]
    ]
  ],
  [
    poolId(usdtethPool),
    [
      [usdt, "all", 1 - (2n << 127n)],
      [eth, "at most", -1235n],
    ]
  ]
])