
# Velocore V2 Integration Guide

# Introduction
Velocore V2 is a flexible base layer for generic token exchange and ve(3,3) incentive distribution.


## Concepts

**Vault:** A singleton contract storing user-deposited tokens. It stores balances of pools and depositors. Users mainly interact with this contract.

**Pool:** A class of smart contracts holding their tokens in the vault and implementing certain callbacks. Liquidity pools, gauges, and bribes are all types of `Pool`s.

**Token:** Velocore V2 supports not only ERC20 but also ERC721, ERC1155, and native tokens. Tokens are represented as a wrapped bytes32 (`Token`), specifically:
- 1 byte of token type
	- `0x00`: ERC20
	- `0x01`: erc721
	- `0x02`: erc1155
- 11 bytes of token id:
	- always 0 for ERC20
	- nft id or token id for ERC721 and erc1155
	- token ids greater than 2^11 - 1 is unsupported
- 20 bytes of token address

- native token is represented as 0xeeeee...eeeee.

**VelocoreOperation:** An abstraction of the swap process. Users send VelocoreOperations to the Vault to perform swaps. Each operation includes operation type (e.g., swap, stake, vote), the pool to interact with, and details like `Token`, desired amount, and nature of the amount.

An example of a transaction that pays USDC to buy ETH is conceptualized as:

```
type: swap
pool: USDC-ETH pool
details: [
    (USDC, "exactly +1000000"),
    (ETH, "at most -1000")
]
```


## Interaction with Velocore V2

### Vault.execute()

`Vault.execute()` is the main function for transactions with Velocore V2. This function receives `VelocoreOperation` from the user, executes them in sequence while tracking the user's virtual balance, and finally carries out token transfers.


Tokens are transferred only after all operations are executed, and the virtual balance can even go negative, which indicates an impending payment by the user.


```solidity
function  execute(
    Token[]  tokenRef,
    int128[]  deposit,
    VelocoreOperation[]  ops
)
```

**tokenRef** is an array of `Token` (less than 256 elements), listing all tokens involved in transactions. For instance, [USDC, ETH, VC].

**deposit** is an array of positive `int128` matching the length of tokenRef. Vault withdraws specified amounts from the user before transactions and credits these to the virtual balances. It's useful for selling tax-on-transfer tokens. Usually, this is an array of zeroes.

### VelocoreOperation
```solidity
struct  VelocoreOperation {
	bytes32 poolId;
	bytes32[] tokenInformations;
	bytes data;
}
```
We use a compressed encoding to optimize calldata usage.

- `poolId`: A bytes32 combination of
	- 1 byte of operation type:
		- 0x00: swap
		- 0x01: stake
		- 0x02: convert
		- 0x03: vote
		- 0x04: userBalance operations
	- (11 bytes of unused bytes)
	- 20 bytes of `Pool` address
- `tokenInformation`: A bytes32 combination of:
	- 1 byte (uint8) of the index of the `Token` in `tokenRef`
	- 1 byte of `amountType`
		- 0x00: exactly
		- 0x01: at least
		- 0x02: equal to the virtual balance
	- 14 bytes of unused bytes
	- 16 bytes of `int128`, the `desiredAmount`
		- the transaction will fail, regardless of the `amountType`, if the   pool returns less than this.
- `data`: Auxiliary data, typically empty bytes. 

`tokenInformation` must contain for all tokens involved, including VC emitted during (un)staking and veVC deposited/withdrawn during voting.

Pool implementations define specific requirements for operationType, tokenInformation, and data. The Vault only ensures the result is less than desiredAmount. Each VelocoreOperation can be viewed as a desired token balance change vector, with auxiliary data.

Beware of malicious pools that might confiscate deposited tokens. Users shouldn't use Pool addresses blindly.

### Operation Type Differences
**Swap** applies to any token exchanges not involving VC emission or voting. It includes swap, veVC conversion, and LP deposit/withdrawal.
- `ISwap` refers to pools supporting this opertaion
- For **CPMM** and **Wombat pools**, LP deposit/withdrawal can be performed by 'buying/selling' LP tokens from/to underlying tokens.
- **VC** and **veVC** are ISwap; VC can be 'bought' with old VC; and veVC can be bought with old veNFTs or new VC.
- the plan is to make veVC act as the liquidity pool for veVC; this is not implemented yet.

**Stake** diverges from `swap` as the Vault calculates and emits VC before operation. It is used for interacting with gauges.
- `IGauge` refers to pools supporting this opertaion
- **CPMM** is both `ISwap` and `IGauge`. 
- **Wombat** pools have multiple gauges; one for each lp token.
- Harvesting can usually be performed by specifying [VC, at most, 0], without any lp tokens.

**Convert** involves actual token transfer, different from swap. The Vault transfers `desiredAmount` to the pool before calling the pool, and the pool sends the output to the vault.

- `IConverter` refers to pools supporting this opertaion.
- Vault only monitors specified tokens balance changes; any unspecified tokens received will be lost.
- This is useful for converting tokens to/from wrapped tokens (e.g. WETH or rfUSDC) or for flash loans.

**Vote** is significantly different from swap. This operation requires the pool to be `IGauge`, and `tokenInformation` must include veVC and any bribe tokens user wants to receive. Like stake, it sends VC emission and calculates and sends any bribes attached to the gauge. To (un)vote, users must specify the `desiredAmount` of the veVC. Any bribes not included in `tokenInformation` will be credited to `userBalance` instead.
- Harvesting can usually be performed by specifying [veVC, exactly, 0], along with bribe tokens.
    
**userBalance**: Pool in this operation can be any address, allowing depositing any tokens to any address. Withdrawal is only possible from your userBalance.


### Vault.query()
```solidity
function query(
    address user,
    Token[] memory tokenRef,
    int128[] memory deposit,
    VelocoreOperation[] calldata ops
) public returns (int128[] memory)
```
To determine the expected amounts received from transactions, use `Vault.query()`. The function parameters are the same as before, with the addition of user, which specifies the transaction maker. The function returns an array of int128 representing the final transactional changes in token balances.


### Typescript Example
```typescript
// helper functions

const toToken = (spec: string, id: BigNumber, addr: string) =>
	solidityPack(
		["uint8", "uint120", "address"],
		[["erc20", "erc721", "erc1155"].indexOf(spec), id, addr]
	)
const poolId = (poolAddress: string) =>
    solidityPack(
	    ["bytes1", "uint120", "address"],
	    ["0x00", 0, poolAddress]
    )

const tokenInformation = (index: number, amountType: string, amount: BigNumber) =>
	solidityPack(["uint8", "uint8", "uint112", "int128"], [
		index,
		["exactly", "at most", "all"].indexOf(amountType),
		0,
		amount
	]
)

const compileAndExecute = (ops) => {
	const tokenRef = [...new  Set(ops.map(x => x[1].map(i => i[0])))].sort();
	return vault.execute(
		tokenRef,
		(new  Array(tokenRef.length)).fill(0),
		ops.map(op => ({
			poolId: op[0]
			tokenInforamtions: op[1].map(i => tokenInformation(tokenRef.indexOf(i[0]), i[1], i[2])).sort(),
			data: []
		}))
	);
}


const usdc = toToken("erc20", 0, "0xUSDC");
const usdt = toToken("erc20", 0, "0xUSDT");
const eth = "0xEEE...EEE";

// actually make transactions
await compileAndExecute([
	[poolId("0x12311..."), [
		[usdc, "exactly", 1234],
		[usdt, "at most", 0]
	]],
	[poolId("0x1ab3234..."), [
		[usdt, "all", INT128_MAX],
		[eth, "at most", -1234],
	]]
])
```