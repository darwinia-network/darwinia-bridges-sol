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
    "accountProof": laneIDProof.accountProof,
    "laneNonceProof": laneNonceProof.storageProof[0].proof,
    "laneRelayersProof": laneRelayersProof.storageProof.map((p) => p.proof),
  }
  return ethers.utils.defaultAbiCoder.encode([
    "tuple(bytes[] accountProof, bytes[] laneNonceProof, bytes[][] laneRelayersProof)"
    ], [ proof ])
}

const generate_storage_proof = async (client, begin, end, block_number) => {
  const addr = client.outbound.address
  const laneIdProof = await get_storage_proof(client, addr, [LANE_IDENTIFY_SLOT], block_number)
  const laneNonceProof = await get_storage_proof(client, addr, [LANE_NONCE_SLOT], block_number)
  const keys = build_message_keys(begin, end)
  const laneMessageProof = await get_storage_proof(client, addr, keys, block_number)
  const proof = {
    "accountProof": laneIdProof.accountProof,
    "laneNonceProof": laneNonceProof.storageProof[0].proof,
    "laneMessagesProof": laneMessageProof.storageProof.map((p) => p.proof),
  }
  return ethers.utils.defaultAbiCoder.encode([
    "tuple(bytes[] accountProof, bytes[] laneIDProof, bytes[] laneNonceProof, bytes[][] laneMessagesProof)"
    ], [ proof ])
}

const generate_parallel_lane_storage_proof = async (client, block_number) => {
  const addr = client.parallel_outbound.address
  const laneRootProof = await get_storage_proof(client, addr, [LANE_ROOT_SLOT], block_number)
  const proof = {
    "accountProof": laneRootProof.accountProof,
    "laneRootProof": laneRootProof.storageProof[0].proof
  }
  const p = ethers.utils.defaultAbiCoder.encode([
    "tuple(bytes[] accountProof, bytes[] laneRootProof)"
  ], [ proof ])
  return {
    proof: p,
    root: laneRootProof.storageProof[0].value
  }
}

const generate_message_proof = async (chain_committer, lane_committer, lane_pos, block_number) => {
  const bridgedChainPos = await lane_committer.BRIDGED_CHAIN_POSITION()
  const proof = await chain_committer.prove(bridgedChainPos, lane_pos, {
    blockTag: block_number
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

const fetch_old_msgs = (from) => {
  if (from == 'eth') {
    const msg0 = {
      encoded_key: "0x0000000000000000000000010000000200000000000000030000000000000000",
      payload: {
        source: '0x3DFe30fb7b46b99e234Ed0F725B5304257F78992',
        target: '0x0000000000000000000000000000000000000000',
        encoded: '0x'
      }
    }
    const msg1 = {
      encoded_key: "0x0000000000000000000000010000000200000000000000030000000000000001",
      payload: {
        source: '0x3DFe30fb7b46b99e234Ed0F725B5304257F78992',
        target: '0x4DBdC9767F03dd078B5a1FC05053Dd0C071Cc005',
        encoded: '0x'
      }
    }
    return [messageHash(msg0), messageHash(msg1)]
  } else {
    const msg0 = {
      encoded_key: "0x0000000000000000000000000000000200000001000000030000000000000000",
      payload: {
        source: '0x3DFe30fb7b46b99e234Ed0F725B5304257F78992',
        target: '0xbB8Ac813748e57B6e8D2DfA7cB79b641bD0524c1',
        encoded: '0x'
      }
    }
    return []
  }
}

const compute_fork_version = (epoch) => {
  const target  = process.env.TARGET || 'local'
  if(target == 'local' || target == 'prod') throw new Error("no config")
  else if (target == 'test') {
    if(epoch >= 162304)
        return "0x03001020"
    if(epoch >= 112260)
        return "0x02001020"
    if(epoch >= 36660)
        return "0x01001020"
    return "0x00001020"
  }
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
    this.eth2 = eth2Client
  }

  async enroll_relayer() {
    // await this.eth.enroll_relayer()
    // await this.bsc.enroll_relayer()
    await this.sub.eth.enroll_relayer()
    // await this.sub.bsc.enroll_relayer()
  }

  async deposit() {
    await this.eth.deposit()
    await this.bsc.deposit()
    await this.sub.eth.deposit()
    await this.sub.bsc.deposit()
  }

  async build_finalized_header_update(finality_update) {
    const finalized_header = finality_update.finalized_header.beacon
    const finalized_header_root = await this.eth2.get_beacon_block_root(finalized_header.slot)
    const current_sync_committee = (await this.eth2.get_bootstrap(finalized_header_root)).current_sync_committee

    let signature_slot = finality_update.signature_slot
    const sync_aggregate_epoch = signature_slot / 32
    const fork_version = compute_fork_version(~~sync_aggregate_epoch)

    let sync_aggregate = finality_update.sync_aggregate
    let sync_committee_bits = []
    sync_committee_bits.push(sync_aggregate.sync_committee_bits.slice(0, 66))
    sync_committee_bits.push('0x' + sync_aggregate.sync_committee_bits.slice(66))
    sync_aggregate.sync_committee_bits = sync_committee_bits;

    const LogsBloom = new ByteVectorType(256)
    const ExtraData = new ByteListType(32)

    const attested_execution = finality_update.attested_header.execution
    attested_execution.logs_bloom = hash(LogsBloom, attested_execution.logs_bloom)
    attested_execution.extra_data = hash(ExtraData, attested_execution.extra_data)

    const finalized_execution = finality_update.finalized_header.execution
    finalized_execution.logs_bloom = hash(LogsBloom, finalized_execution.logs_bloom)
    finalized_execution.extra_data = hash(ExtraData, finalized_execution.extra_data)

    const finalized_header_update = {
      attested_header:           {
        beacon:                  finality_update.attested_header.beacon,
        execution:               attested_execution,
        execution_branch:        finality_update.attested_header.execution_branch
      },
      signature_sync_committee:  current_sync_committee,
      finalized_header:          {
        beacon:                  finality_update.finalized_header.beacon,
        execution:               finalized_execution,
        execution_branch:        finality_update.finalized_header.execution_branch
      },
      finality_branch:           finality_update.finality_branch,
      sync_aggregate:            sync_aggregate,
      fork_version:              fork_version,
      signature_slot:            signature_slot
    }
    console.log(JSON.stringify(finalized_header_update,null,2))
    return finalized_header_update
  }

  async blc_import_finalized_header() {
    const old_finalized_header = await this.sub.eth.lightclient.finalized_header()
    if (~~finality_update.finalized_header.beacon.slot == ~~old_finalized_header.slot) throw new Error("!new")

    const finality_update = await this.eth2.get_finality_update()
    const finalized_header_update = await this.build_finalized_header_update(finality_update)

    const tx = await this.sub.eth.lightclient.import_finalized_header(finalized_header_update, {
      gasLimit: 16000000,
      gasPrice: 2000000000000,
    })
    return [tx, finalized_header_update]
  }

  async blc_import_next_sync_committee(start_period) {
    let s = await this.sub.eth.lightclient.sync_committee_roots(start_period + 1)
    if (s != "0x0000000000000000000000000000000000000000000000000000000000000000") return [null,null]

    const sync_change = await this.eth2.get_sync_committee_period_update(start_period, 1)
    const next_sync = sync_change[0].data
    const finalized_header_update = await this.build_finalized_header_update(next_sync)
    const sync_committee_period_update = {
      next_sync_committee: next_sync.next_sync_committee,
      next_sync_committee_branch: next_sync.next_sync_committee_branch
    }

    const tx = await this.sub.eth.lightclient.import_next_sync_committee(finalized_header_update, sync_committee_period_update, {
      gasLimit: 16000000,
      gasPrice: 2000000000000,
    })
    return [tx, sync_committee_period_update]
  }

  async blc_import_sync_committees(start_period, count) {
    for (let i = 0; i < count; i++) {
      this.blc_import_next_sync_committee(start_period+count, 1)
    }
  }

  async relay_eth_header() {
    const old_finalized_header = await this.sub.eth.lightclient.finalized_header()
    const finality_update = await this.eth2.get_finality_update()
    let attested_header = finality_update.attested_header.beacon
    let finalized_header = finality_update.finalized_header.beacon
    const old_period = ~~old_finalized_header.slot.div(32).div(256)
    const now_period = ~~(finalized_header.slot / 32 / 256)
    if (old_period == now_period) {
      await this.blc_import_finalized_header()
    } else {
      await this.blc_import_sync_committees(old_period, now_period - old_period)
      await this.blc_import_finalized_header()
    }
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
    const finality_block_number = (await c.lightClient.block_number()).toNumber()
    const proof = await generate_message_proof(this.sub.chainMessageCommitter, this.sub[to].LaneMessageCommitter, info[1], finality_block_number)
    return await c.inbound.receive_messages_proof(data, proof, data.messages.length)
  }

  async dispatch_parallel_message_from_sub(to, msg) {
    const c = this[to]
    const info = await this.sub[to].parallel_outbound.getLaneInfo()
    const finality_block_number = (await c.lightClient.block_number()).toNumber()
    const lane_root = await this.sub[to].parallel_outbound.commitment({blockTag: finality_block_number})
    const lane_proof = await generate_message_proof(this.sub.chainMessageCommitter, this.sub[to].LaneMessageCommitter, info[1], finality_block_number)

    const old_msgs = fetch_old_msgs('sub')
    const msgs = old_msgs.concat([messageHash(msg)])
    console.log(msgs)
    const t = new IncrementalMerkleTree(msgs)
    const msg_proof = t.getSingleHexProof(msgs.length - 1)
    console.log(msg_proof)
    return await c.parallel_inbound.receive_message(lane_root, lane_proof, msg, msg_proof)
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
    const old_msgs = fetch_old_msgs(from)
    const msgs = old_msgs.concat([msg_hash])
    const t = new IncrementalMerkleTree(msgs)
    const msg_proof = t.getSingleHexProof(msgs.length - 1)
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
      const finality_block = await this.eth2.get_beacon_block(finalized_header.slot)
      return finality_block.body.execution_payload.block_number
    } else if (from == 'bsc') {
      const finalized_header = await this.subClient.bscLightClient.finalized_checkpoint()
      return finalized_header.number
    } else { throw new Error("invalid from") }
  }
}

module.exports.Bridge = Bridge
