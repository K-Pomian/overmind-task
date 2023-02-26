import { AptosAccount, AptosClient, Types } from 'aptos'

export interface Wallet {
  signTransaction: (tx: Types.TransactionPayload_EntryFunctionPayload) => Promise<Uint8Array>
  signAllTransactions: (
    txs: Types.TransactionPayload_EntryFunctionPayload[]
  ) => Promise<Uint8Array[]>
}

export class TestWallet implements Wallet {
  account: AptosAccount
  aptosClient: AptosClient

  public constructor(account: AptosAccount, aptosClient: AptosClient) {
    this.account = account
    this.aptosClient = aptosClient
  }

  async signTransaction(
    tx: Types.TransactionPayload_EntryFunctionPayload,
    max_gas_amount?: string
  ): Promise<Uint8Array> {
    const rawTx = await this.aptosClient.generateTransaction(this.account.address(), tx, {
      max_gas_amount
    })
    const signedTx = await this.aptosClient.signTransaction(this.account, rawTx)
    return signedTx
  }

  async signAllTransactions(
    txs: Types.TransactionPayload_EntryFunctionPayload[]
  ): Promise<Uint8Array[]> {
    const { sequence_number: sequenceNumber } = await this.aptosClient.getAccount(
      this.account.address()
    )

    const signedTxs: Promise<Uint8Array[]> = Promise.all(
      txs.map(async (tx, index) => {
        const rawTx = await this.aptosClient.generateTransaction(this.account.address(), tx, {
          sequence_number: Number(Number(sequenceNumber) + index).toString()
        })
        return await this.aptosClient.signTransaction(this.account, rawTx)
      })
    )
    return signedTxs
  }
}
