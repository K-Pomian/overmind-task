import { AptosClient, Types, AptosAccount } from 'aptos'
import { Network } from './network'
import { DEVNET_ADMIN_PRIV_KEY, DEVNET_CONTRACT_ADDRESS, DEVNET_NODE_URL } from './static'
import { TestWallet, Wallet } from './wallet'

export class Contract {
  public aptosClient: AptosClient
  public contractAddress: string
  public wallet: Wallet

  public constructor(network: Network) {
    switch (network) {
      case Network.DEVNET: {
        this.aptosClient = new AptosClient(DEVNET_NODE_URL)
        this.contractAddress = DEVNET_CONTRACT_ADDRESS
        this.wallet = new TestWallet(new AptosAccount(DEVNET_ADMIN_PRIV_KEY), this.aptosClient)
      }
    }
  }

  public async createGame(
    coinType: string,
    gameName: string,
    amountPerDepositor: number,
    withdrawalFractions: number[],
    joinDuration: number
  ) {
    return await this.signAndSend(
      await this.createGamePayload(
        coinType,
        gameName,
        amountPerDepositor,
        withdrawalFractions,
        joinDuration
      )
    )
  }

  public async createGamePayload(
    coinType: string,
    gameName: string,
    amountPerDepositor: number,
    withdrawalFractions: number[],
    joinDuration: number
  ) {
    const entryFunctionPayload: Types.TransactionPayload_EntryFunctionPayload = {
      type: 'entry_function_payload',
      function: `0x${this.contractAddress}::core::create_game`,
      type_arguments: [coinType],
      arguments: [gameName, amountPerDepositor, withdrawalFractions, joinDuration]
    }

    return entryFunctionPayload
  }

  async signAndSend(rawTx: Types.TransactionPayload_EntryFunctionPayload) {
    const signedTx = await this.wallet.signTransaction(rawTx)
    const res = await this.aptosClient.submitSignedBCSTransaction(signedTx)
    await this.aptosClient.waitForTransaction(res.hash)

    return Promise.resolve(res.hash)
  }
}
