import { HexString } from 'aptos'

export const DEVNET_NODE_URL = 'https://fullnode.devnet.aptoslabs.com/v1'
export const DEVNET_FAUCET_URL = 'https://faucet.devnet.aptoslabs.com'

export const DEVNET_ADMIN_PRIV_KEY = new HexString(
  '0x3d926e326e419fdd759e4826d2e85f1d116c19ef499f8b0dd4672bdfd52d467c'
).toUint8Array()
export const DEVNET_CONTRACT_ADDRESS =
  '4723ae199cbcf97347e7d4c2d4e720df379834dd6be8b0743cc8f581502ee4dc'
