const { toHexString, ListCompositeType, ByteVectorType, ByteListType } = require('@chainsafe/ssz')
const { BigNumber } = require("ethers")
const { IncrementalMerkleTree } = require("./imt")
const { messageHash } = require('./msg')
const rlp = require("rlp")

const LANE_IDENTIFY_SLOT="0x0000000000000000000000000000000000000000000000000000000000000000"
const LANE_NONCE_SLOT="0x0000000000000000000000000000000000000000000000000000000000000001"
const LANE_MESSAGE_SLOT="0x0000000000000000000000000000000000000000000000000000000000000002"

const LANE_ROOT_SLOT="0x0000000000000000000000000000000000000000000000000000000000000001"

const get_storage_proof = async (client, addr, storageKeys, blockNumber = 'latest') => {
  if (blockNumber != 'latest') {
    blockNumber = "0x" + Number(blockNumber).toString(16)
  }
  return await client.provider.send("eth_getProof",
    [
      addr,
      storageKeys,
      blockNumber
    ]
  )
}

const build_message_keys = (front, end) => {
  const keys = []
  for (let index=front; index<=end; index++) {
    const newKey = ethers.utils.concat([
      ethers.utils.hexZeroPad(index, 32),
      LANE_MESSAGE_SLOT
    ])
    keys.push(ethers.utils.keccak256(newKey))
  }
  return keys
}

const build_relayer_keys = (front, end) => {
  const keys = []
  for (let index=front; index<=end; index++) {
    const newKey = ethers.utils.concat([
      ethers.utils.hexZeroPad(index, 32),
      LANE_MESSAGE_SLOT
    ])
    const key0 = ethers.utils.keccak256(newKey)
    const key1 = BigNumber.from(key0).add(1).toHexString()
    keys.push(key0)
    keys.push(key1)
  }
  return keys
}

const generate_storage_delivery_proof = async (client, front, end, block_number) => {
  const addr = client.inbound.address
  const laneIDProof = await get_storage_proof(client, addr, [LANE_IDENTIFY_SLOT], block_number)
  const laneNonceProof = await get_storage_proof(client, addr, [LANE_NONCE_SLOT], block_number)
  const keys = build_relayer_keys(front, end)
  const laneRelayersProof = await get_storage_proof(client, addr, keys, block_number)
  const proof = {
    "accountProof": toHexString(rlp.encode(laneIDProof.accountProof)),
    "laneNonceProof": toHexString(rlp.encode(laneNonceProof.storageProof[0].proof)),
    "laneRelayersProof": laneRelayersProof.storageProof.map((p) => toHexString(rlp.encode(p.proof))),
  }
  return ethers.utils.defaultAbiCoder.encode([
    "tuple(bytes accountProof, bytes laneNonceProof, bytes[] laneRelayersProof)"
    ], [ proof ])
}

const generate_storage_proof = async (client, begin, end, block_number) => {
  const addr = client.outbound.address
  const laneIdProof = await get_storage_proof(client, addr, [LANE_IDENTIFY_SLOT], block_number)
  const laneNonceProof = await get_storage_proof(client, addr, [LANE_NONCE_SLOT], block_number)
  const keys = build_message_keys(begin, end)
  const laneMessageProof = await get_storage_proof(client, addr, keys, block_number)
  const proof = {
    "accountProof": toHexString(rlp.encode(laneIdProof.accountProof)),
    "laneIDProof": toHexString(rlp.encode(laneIdProof.storageProof[0].proof)),
    "laneNonceProof": toHexString(rlp.encode(laneNonceProof.storageProof[0].proof)),
    "laneMessagesProof": laneMessageProof.storageProof.map((p) => toHexString(rlp.encode(p.proof))),
  }
  return ethers.utils.defaultAbiCoder.encode([
    "tuple(bytes accountProof, bytes laneIDProof, bytes laneNonceProof, bytes[] laneMessagesProof)"
    ], [ proof ])
}

const generate_parallel_lane_storage_proof = async (client, block_number) => {
  const addr = client.parallel_outbound.address
  const laneRootProof = await get_storage_proof(client, addr, [LANE_ROOT_SLOT], block_number)
  console.log(laneRootProof)
  const proof = {
    "accountProof": toHexString(rlp.encode(laneRootProof.accountProof)),
    "laneRootProof": toHexString(rlp.encode(laneRootProof.storageProof[0].proof))
  }
  const p = ethers.utils.defaultAbiCoder.encode([
    "tuple(bytes accountProof, bytes laneRootProof)"
  ], [ proof ])
  return {
    proof: p,
    root: laneRootProof.storageProof[0].value
  }
}

const generate_message_proof = async (chain_committer, lane_committer, lane_pos, block_number) => {
  const bridgedChainPos = await lane_committer.bridgedChainPosition()
  const proof = await chain_committer.prove(bridgedChainPos, lane_pos, {
    blockNumber: block_number
  })
  return ethers.utils.defaultAbiCoder.encode([
    "tuple(tuple(bytes32,bytes32[]),tuple(bytes32,bytes32[]))"
    ], [
      [
        [proof.chainProof.root, proof.chainProof.proof],
        [proof.laneProof.root, proof.laneProof.proof]
      ]
    ])
}

const get_ssz_type = (forks, sszTypeName, forkName) => {
  return forks[forkName][sszTypeName]
}

const hash_tree_root = (forks, sszTypeName, forkName, input) => {
  const type = get_ssz_type(forks, sszTypeName, forkName)
  const value = type.fromJson(input)
  return toHexString(type.hashTreeRoot(value))
}

const hash = (typ, input) => {
  const value = typ.fromJson(input)
  return toHexString(typ.hashTreeRoot(value))
}

/**
 * The Mock Bridge for testing
 */
class Bridge {
  constructor(ethClient, bscClient, eth2Client, subClient) {
    this.ethClient = ethClient
    this.bscClient = bscClient
    this.eth2Client = eth2Client
    this.subClient = subClient
    this.eth = ethClient
    this.bsc = bscClient
    this.sub = subClient
  }

  async enroll_relayer() {
    await this.eth.enroll_relayer()
    await this.bsc.enroll_relayer()
    await this.sub.eth.enroll_relayer()
    await this.sub.bsc.enroll_relayer()
  }

  async deposit() {
    await this.eth.deposit()
    await this.sub.deposit()
    await this.sub.eth.deposit()
    await this.sub.bsc.deposit()
  }

  async relay_eth_header() {
    const old_finalized_header = await this.subClient.beaconLightClient.finalized_header()
    const finality_update = await this.eth2Client.get_finality_update()
    let attested_header = finality_update.attested_header
    let finalized_header = finality_update.finalized_header
    const period = Number(finalized_header.slot) / 32 / 256
    const sync_change = await this.eth2Client.get_sync_committee_period_update(~~period - 1, 1)
    const next_sync = sync_change[0].data
    const current_sync_committee = next_sync.next_sync_committee

    let sync_aggregate_slot = Number(attested_header.slot) + 1
    let sync_aggregate_header = await this.eth2Client.get_header(sync_aggregate_slot)
    while (!sync_aggregate_header) {
      sync_aggregate_slot = Number(sync_aggregate_slot) + 1
      sync_aggregate_header = await this.eth2Client.get_header(sync_aggregate_slot)
    }

    const fork_version = await this.eth2Client.get_fork_version(sync_aggregate_slot)

    let sync_aggregate = finality_update.sync_aggregate
    let sync_committee_bits = []
    sync_committee_bits.push(sync_aggregate.sync_committee_bits.slice(0, 66))
    sync_committee_bits.push('0x' + sync_aggregate.sync_committee_bits.slice(66))
    sync_aggregate.sync_committee_bits = sync_committee_bits;

    const finalized_header_update = {
      attested_header: attested_header,
      signature_sync_committee: current_sync_committee,
      finalized_header: finalized_header,
      finality_branch: finality_update.finality_branch,
      sync_aggregate: sync_aggregate,
      fork_version: fork_version.current_version,
      signature_slot: sync_aggregate_slot
    }

    const tx = await this.subClient.beaconLightClient.import_finalized_header(finalized_header_update,
      {
        gasPrice: 1000000000,
        gasLimit: 5000000
      })

    // const new_finalized_header = await this.subClient.beaconLightClient.finalized_header()
  }

  async relay_eth_execution_payload() {
    const x = await import("@chainsafe/lodestar-types")
    const ssz = x.ssz
    const BeaconBlockBody = ssz.allForks.bellatrix.BeaconBlockBody

    const finalized_header = await this.subClient.beaconLightClient.finalized_header()

    const block = await this.eth2Client.get_beacon_block(finalized_header.slot)
    const b = block.body
    const p = b.execution_payload

    const ProposerSlashing = get_ssz_type(ssz, 'ProposerSlashing', 'phase0')
    const ProposerSlashings = new ListCompositeType(ProposerSlashing, 16)
    const AttesterSlashing = get_ssz_type(ssz, 'AttesterSlashing', 'phase0')
    const AttesterSlashings = new ListCompositeType(AttesterSlashing, 2)
    const Attestation = get_ssz_type(ssz, 'Attestation', 'phase0')
    const Attestations = new ListCompositeType(Attestation, 128)
    const Deposit = get_ssz_type(ssz, 'Deposit', 'phase0')
    const Deposits = new ListCompositeType(Deposit, 16)
    const SignedVoluntaryExit = get_ssz_type(ssz, 'SignedVoluntaryExit', 'phase0')
    const SignedVoluntaryExits = new ListCompositeType(SignedVoluntaryExit, 16)

    const LogsBloom = new ByteVectorType(256)
    const ExtraData = new ByteListType(32)

    const body = {
        randao_reveal:       hash_tree_root(x, 'BLSSignature', 'ssz', b.randao_reveal),
        eth1_data:           hash_tree_root(ssz, 'Eth1Data', 'phase0', b.eth1_data),
        graffiti:            b.graffiti,
        proposer_slashings:  hash(ProposerSlashings, b.proposer_slashings),
        attester_slashings:  hash(AttesterSlashings, b.attester_slashings),
        attestations:        hash(Attestations, b.attestations),
        deposits:            hash(Deposits, b.deposits),
        voluntary_exits:     hash(SignedVoluntaryExits, b.voluntary_exits),
        sync_aggregate:      hash_tree_root(ssz, 'SyncAggregate', 'altair', b.sync_aggregate),

        execution_payload:   {
          parent_hash:       p.parent_hash,
          fee_recipient:     p.fee_recipient,
          state_root:        p.state_root,
          receipts_root:     p.receipts_root,
          logs_bloom:        hash(LogsBloom, p.logs_bloom),
          prev_randao:       p.prev_randao,
          block_number:      p.block_number,
          gas_limit:         p.gas_limit,
          gas_used:          p.gas_used,
          timestamp:         p.timestamp,
          extra_data:        hash(ExtraData, p.extra_data),
          base_fee_per_gas:  p.base_fee_per_gas,
          block_hash:        p.block_hash,
          transactions:      hash_tree_root(ssz, 'Transactions', 'bellatrix', p.transactions)
        }
    }

    const tx = await this.subClient.executionLayer.import_latest_execution_payload_state_root(body)
    // console.log(tx)
  }

  async relay_bsc_header() {
    const old_finalized_checkpoint = await this.subClient.bscLightClient.finalized_checkpoint()
    const finalized_checkpoint_number = old_finalized_checkpoint.number.add(200)
    const finalized_checkpoint = await this.bscClient.get_block('0x' + finalized_checkpoint_number.toNumber().toString(16))
    const length = await this.subClient.bscLightClient.length_of_finalized_authorities()
    let headers = [finalized_checkpoint]
    let number = finalized_checkpoint_number
    for (let i=0; i < ~~length.div(2); i++) {
      number = number.add(1)
      const header = await this.bscClient.get_block('0x' + number.toNumber().toString(16))
      headers.push(header)
    }
    const tx = await this.subClient.bscLightClient.import_finalized_epoch_header(headers)
    console.log(tx)
  }

  async relay_sub_header() {
    const header = await this.sub.block_header()
    const message_root = await this.sub.chainMessageCommitter['commitment()']()
    const nonce = await this.sub.ecdsa_authority_nonce(header.hash)
    const block_number = header.number.toNumber()
    const message = {
      block_number,
      message_root,
      nonce: nonce.toNumber()
    }
    const signs = await this.sub.sign_message_commitment(message)
    await this.eth.ecdsa_relay_header(message, signs)
    await this.bsc.ecdsa_relay_header(message, signs)
    return await this.ethClient.relay_header(message_root, header.number.toString())
  }

  async relay_eth_messages(data) {
    await relay_eth_header()
    await dispatch_messages_to_sub('eth', data)
    await relay_sub_header()
    await confirm_messages_to_sub('eth')
  }

  async relay_sub_messages_to_eth(data) {
    await relay_sub_header()
    await dispatch_messages_from_sub('eth', data)
    await relay_eth_header()
    await confirm_messages_from_sub('eth')
  }

  async dispatch_messages_from_sub(to, data) {
    const c = this[to]
    const info = await this.sub[to].outbound.getLaneInfo()
    const finality_block_number = await c.lightClient.block_number()
    const proof = await generate_message_proof(this.sub.chainMessageCommitter, this.sub[to].LaneMessageCommitter, info[1])
    return await c.inbound.receive_messages_proof(data, proof, data.messages.length)
  }

  async confirm_messages_from_sub(to) {
    const c = this[to]
    const i = await c.inbound.data()
    const nonce = await c.inbound.inboundLaneNonce()
    const finality_block_number = await this.finality_block_number(to)
    const front = nonce.relayer_range_front.toHexString()
    const end = nonce.relayer_range_back.toHexString()
    const proof = await generate_storage_delivery_proof(c, front, end, finality_block_number)
    return await this.sub[to].outbound.receive_messages_delivery_proof(i, proof, { gasLimit: 6000000 })
  }

  async dispatch_messages_to_sub(from, data) {
    const c = this[from]
    const nonce = await c.outbound.outboundLaneNonce()
    const begin = nonce.latest_received_nonce.add(1).toHexString()
    const end = nonce.latest_generated_nonce.toHexString()
    const finality_block_number = await this.finality_block_number(from)
    const proof = await generate_storage_proof(c, begin, end, finality_block_number)
    return this.sub[from].inbound.receive_messages_proof(data, proof, data.messages.length, { gasLimit: 6000000 })
  }

  async confirm_messages_to_sub(from) {
    const c = this[from]
    const i = await this.sub[from].inbound.data()
    const info = await this.sub[from].inbound.getLaneInfo()
    const o = await c.outbound.outboundLaneNonce()
    const finality_block_number = c.lightClient.block_number()
    const proof = await generate_message_proof(this.sub.chainMessageCommitter, this.sub[from].LaneMessageCommitter, info[1])
    return await c.outbound.receive_messages_delivery_proof(i, proof)
  }

  async dispatch_parallel_message_to_sub(from, msg) {
    const c = this[from]
    const finality_block_number = await this.finality_block_number(from)
    const p = await generate_parallel_lane_storage_proof(c, finality_block_number)
    const msg_hash = messageHash(msg)
    const msg_size = await c.parallel_outbound.message_size()
    const leaves = Array(msg_size).fill(Buffer.from(msg_hash))
    const t = new IncrementalMerkleTree(leaves)
    const msg_proof = t.getSingleHexProof(msg_size - 1)
    return await this.sub[from].parallel_inbound.receive_message(
      p.root,
      p.proof,
      msg,
      msg_proof
    )
  }

  async finality_block_number(from) {
    if (from == 'eth') {
      const finalized_header = await this.sub.beaconLightClient.finalized_header()
      const finality_block = await this.eth2Client.get_beacon_block(finalized_header.slot)
      return finality_block.body.execution_payload.block_number
    } else if (from == 'bsc') {
      const finalized_header = await this.subClient.bscLightClient.finalized_checkpoint()
      return finalized_header.number
    } else { throw new Error("invalid from") }
  }
}

module.exports.Bridge = Bridge
