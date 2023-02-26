import { AptosClient, Types } from 'aptos'
import { Wallet } from './wallet'

export class Contract {
  public aptosClient: AptosClient
  public contractAddress: string
  public wallet: Wallet

  public async createGame(
    coin_type: string,
    game_name: string,
    amountPerDepositor: number,
    withdrawalFractions: number[],
    joinDuration: number
  ) {
    return await this.signAndSend(
      await this.createGamePayload(
        coin_type,
        game_name,
        amountPerDepositor,
        withdrawalFractions,
        joinDuration
      )
    )
  }

  public async createGamePayload(
    coin_type: string,
    game_name: string,
    amountPerDepositor: number,
    withdrawalFractions: number[],
    joinDuration: number
  ) {
    const entryFunctionPayload: Types.TransactionPayload_EntryFunctionPayload = {
      type: 'entry_function_payload',
      function: `${this.contractAddress}::core::create_game`,
      type_arguments: [coin_type],
      arguments: [game_name, amountPerDepositor, withdrawalFractions, joinDuration]
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
