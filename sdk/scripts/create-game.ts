import { AptosClient, FaucetClient, AptosAccount } from 'aptos'
import { Contract } from '../src/contract'
import { Network } from '../src/network'
import { DEVNET_ADMIN_PRIV_KEY, DEVNET_FAUCET_URL, DEVNET_NODE_URL } from '../src/static'
import { sleep } from '../src/utils'

const main = async () => {
  const aptosClient = new AptosClient(DEVNET_NODE_URL)
  const faucetClient = new FaucetClient(DEVNET_NODE_URL, DEVNET_FAUCET_URL)
  const admin = new AptosAccount(DEVNET_ADMIN_PRIV_KEY)
  const contract = new Contract(Network.DEVNET)

  await faucetClient.fundAccount(admin.address(), 1_000_000_000)
  await sleep(2000)

  const coinType = '0x1::aptos_coin::AptosCoin'
  const gameName = 'MyNewGame'
  const amountPerDepositor = 10 ^ 8
  const withdrawalFractions = [5555, 3000, 1445]
  const joinDuration = 60 * 60 * 24 * 7

  let txHash = await contract.createGame(
    coinType,
    gameName,
    amountPerDepositor,
    withdrawalFractions,
    joinDuration
  )
  await sleep(2000)

  console.log('TxHash: ', txHash)
}

main()
