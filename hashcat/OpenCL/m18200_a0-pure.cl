/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

//shared mem too small
//#define NEW_SIMD_CODE

#include "inc_vendor.cl"
#include "inc_hash_constants.h"
#include "inc_hash_functions.cl"
#include "inc_types.cl"
#include "inc_common.cl"
#include "inc_rp.h"
#include "inc_rp.cl"
#include "inc_hash_md4.cl"
#include "inc_hash_md5.cl"

typedef struct
{
  u8 S[256];

  u32 wtf_its_faster;

} RC4_KEY;

DECLSPEC void swap (__local RC4_KEY *rc4_key, const u8 i, const u8 j)
{
  u8 tmp;

  tmp           = rc4_key->S[i];
  rc4_key->S[i] = rc4_key->S[j];
  rc4_key->S[j] = tmp;
}

DECLSPEC void rc4_init_16 (__local RC4_KEY *rc4_key, const u32 *data)
{
  u32 v = 0x03020100;
  u32 a = 0x04040404;

  __local u32 *ptr = (__local u32 *) rc4_key->S;

  #ifdef _unroll
  #pragma unroll
  #endif
  for (u32 i = 0; i < 64; i++)
  {
    *ptr++ = v; v += a;
  }

  u32 j = 0;

  for (u32 i = 0; i < 16; i++)
  {
    u32 idx = i * 16;

    u32 v;

    v = data[0];

    j += rc4_key->S[idx] + (v >>  0); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >>  8); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 16); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 24); swap (rc4_key, idx, j); idx++;

    v = data[1];

    j += rc4_key->S[idx] + (v >>  0); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >>  8); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 16); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 24); swap (rc4_key, idx, j); idx++;

    v = data[2];

    j += rc4_key->S[idx] + (v >>  0); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >>  8); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 16); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 24); swap (rc4_key, idx, j); idx++;

    v = data[3];

    j += rc4_key->S[idx] + (v >>  0); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >>  8); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 16); swap (rc4_key, idx, j); idx++;
    j += rc4_key->S[idx] + (v >> 24); swap (rc4_key, idx, j); idx++;
  }
}

DECLSPEC u8 rc4_next_16 (__local RC4_KEY *rc4_key, u8 i, u8 j, const __global u32 *in, u32 *out)
{
  #ifdef _unroll
  #pragma unroll
  #endif
  for (u32 k = 0; k < 4; k++)
  {
    u32 xor4 = 0;

    u8 idx;

    i += 1;
    j += rc4_key->S[i];

    swap (rc4_key, i, j);

    idx = rc4_key->S[i] + rc4_key->S[j];

    xor4 |= rc4_key->S[idx] <<  0;

    i += 1;
    j += rc4_key->S[i];

    swap (rc4_key, i, j);

    idx = rc4_key->S[i] + rc4_key->S[j];

    xor4 |= rc4_key->S[idx] <<  8;

    i += 1;
    j += rc4_key->S[i];

    swap (rc4_key, i, j);

    idx = rc4_key->S[i] + rc4_key->S[j];

    xor4 |= rc4_key->S[idx] << 16;

    i += 1;
    j += rc4_key->S[i];

    swap (rc4_key, i, j);

    idx = rc4_key->S[i] + rc4_key->S[j];

    xor4 |= rc4_key->S[idx] << 24;

    out[k] = in[k] ^ xor4;
  }

  return j;
}

DECLSPEC int decrypt_and_check (__local RC4_KEY *rc4_key, u32 *data, __global const u32 *edata2, const u32 edata2_len, const u32 *K2, const u32 *checksum)
{
  rc4_init_16 (rc4_key, data);

  u32 out0[4];

  /*
    8 first bytes are nonce, then ASN1 structs (DER encoding: TLV)

    The first byte is always 0x79 (01 1 11001, where 01 = "class=APPLICATION", 1 = "form=constructed", 11001 is application type 25)
    The next byte is the length:

    if length < 128 bytes:
        length is on 1 byte, and the next byte is 0x30 (class=SEQUENCE)
    else if length <= 256:
        length is on 2 bytes, the first byte is 0x81, and the third byte is 0x30 (class=SEQUENCE)
    else if length > 256:
        length is on 3 bytes, the first byte is 0x82, and the fourth byte is 0x30 (class=SEQUENCE)
  */

  rc4_next_16 (rc4_key, 0, 0, edata2 + 0, out0);

  if (((out0[2] & 0x00ff80ff) != 0x00300079) &&
      ((out0[2] & 0xFF00FFFF) != 0x30008179) &&
      ((out0[2] & 0x0000FFFF) != 0x00008279 || (out0[3] & 0x000000FF) != 0x00000030))
      return 0;

  rc4_init_16 (rc4_key, data);

  u8 i = 0;
  u8 j = 0;

  // init hmac

  u32 w0[4];
  u32 w1[4];
  u32 w2[4];
  u32 w3[4];

  w0[0] = K2[0];
  w0[1] = K2[1];
  w0[2] = K2[2];
  w0[3] = K2[3];
  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;
  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;
  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  md5_hmac_ctx_t ctx;

  md5_hmac_init_64 (&ctx, w0, w1, w2, w3);

  int edata2_left;

  for (edata2_left = edata2_len; edata2_left >= 64; edata2_left -= 64)
  {
    j = rc4_next_16 (rc4_key, i, j, edata2, w0); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w1); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w2); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w3); i += 16; edata2 += 4;

    md5_hmac_update_64 (&ctx, w0, w1, w2, w3, 64);
  }

  w0[0] = 0;
  w0[1] = 0;
  w0[2] = 0;
  w0[3] = 0;
  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;
  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;
  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  if (edata2_left < 16)
  {
    j = rc4_next_16 (rc4_key, i, j, edata2, w0); i += 16; edata2 += 4;

    truncate_block_4x4_le_S (w0, edata2_left & 0xf);
  }
  else if (edata2_left < 32)
  {
    j = rc4_next_16 (rc4_key, i, j, edata2, w0); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w1); i += 16; edata2 += 4;

    truncate_block_4x4_le_S (w1, edata2_left & 0xf);
  }
  else if (edata2_left < 48)
  {
    j = rc4_next_16 (rc4_key, i, j, edata2, w0); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w1); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w2); i += 16; edata2 += 4;

    truncate_block_4x4_le_S (w2, edata2_left & 0xf);
  }
  else
  {
    j = rc4_next_16 (rc4_key, i, j, edata2, w0); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w1); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w2); i += 16; edata2 += 4;
    j = rc4_next_16 (rc4_key, i, j, edata2, w3); i += 16; edata2 += 4;

    truncate_block_4x4_le_S (w3, edata2_left & 0xf);
  }

  md5_hmac_update_64 (&ctx, w0, w1, w2, w3, edata2_left);

  md5_hmac_final (&ctx);

  if (checksum[0] != ctx.opad.h[0]) return 0;
  if (checksum[1] != ctx.opad.h[1]) return 0;
  if (checksum[2] != ctx.opad.h[2]) return 0;
  if (checksum[3] != ctx.opad.h[3]) return 0;

  return 1;
}

DECLSPEC void kerb_prepare (const u32 *K, const u32 *checksum, u32 *digest, u32 *K2)
{
  // K1=MD5_HMAC(K,1); with 1 encoded as little indian on 4 bytes (01000000 in hexa);

  u32 w0[4];
  u32 w1[4];
  u32 w2[4];
  u32 w3[4];

  w0[0] = K[0];
  w0[1] = K[1];
  w0[2] = K[2];
  w0[3] = K[3];
  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;
  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;
  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  md5_hmac_ctx_t ctx1;

  md5_hmac_init_64 (&ctx1, w0, w1, w2, w3);

  w0[0] = 8;
  w0[1] = 0;
  w0[2] = 0;
  w0[3] = 0;
  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;
  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;
  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  md5_hmac_update_64 (&ctx1, w0, w1, w2, w3, 4);

  md5_hmac_final (&ctx1);

  w0[0] = ctx1.opad.h[0];
  w0[1] = ctx1.opad.h[1];
  w0[2] = ctx1.opad.h[2];
  w0[3] = ctx1.opad.h[3];
  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;
  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;
  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  md5_hmac_ctx_t ctx;

  md5_hmac_init_64 (&ctx, w0, w1, w2, w3);

  w0[0] = checksum[0];
  w0[1] = checksum[1];
  w0[2] = checksum[2];
  w0[3] = checksum[3];
  w1[0] = 0;
  w1[1] = 0;
  w1[2] = 0;
  w1[3] = 0;
  w2[0] = 0;
  w2[1] = 0;
  w2[2] = 0;
  w2[3] = 0;
  w3[0] = 0;
  w3[1] = 0;
  w3[2] = 0;
  w3[3] = 0;

  md5_hmac_update_64 (&ctx, w0, w1, w2, w3, 16);

  md5_hmac_final (&ctx);

  digest[0] = ctx.opad.h[0];
  digest[1] = ctx.opad.h[1];
  digest[2] = ctx.opad.h[2];
  digest[3] = ctx.opad.h[3];

  K2[0] = ctx1.opad.h[0];
  K2[1] = ctx1.opad.h[1];
  K2[2] = ctx1.opad.h[2];
  K2[3] = ctx1.opad.h[3];
}

__kernel void __attribute__((reqd_work_group_size(64, 1, 1))) m18200_mxx (KERN_ATTR_RULES_ESALT (krb5asrep_t))
{
  /**
   * modifier
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);

  if (gid >= gid_max) return;

  /**
   * base
   */

  COPY_PW (pws[gid]);

  __local RC4_KEY rc4_keys[64];

  __local RC4_KEY *rc4_key = &rc4_keys[lid];

  u32 checksum[4];

  checksum[0] = esalt_bufs[digests_offset].checksum[0];
  checksum[1] = esalt_bufs[digests_offset].checksum[1];
  checksum[2] = esalt_bufs[digests_offset].checksum[2];
  checksum[3] = esalt_bufs[digests_offset].checksum[3];

  /**
   * loop
   */

  for (u32 il_pos = 0; il_pos < il_cnt; il_pos++)
  {
    pw_t tmp = PASTE_PW;

    tmp.pw_len = apply_rules (rules_buf[il_pos].cmds, tmp.i, tmp.pw_len);

    md4_ctx_t ctx;

    md4_init (&ctx);

    md4_update_utf16le (&ctx, tmp.i, tmp.pw_len);

    md4_final (&ctx);

    u32 digest[4];

    u32 K2[4];

    kerb_prepare (ctx.h, checksum, digest, K2);

    if (decrypt_and_check (rc4_key, digest, esalt_bufs[digests_offset].edata2, esalt_bufs[digests_offset].edata2_len, K2, checksum) == 1)
    {
      if (atomic_inc (&hashes_shown[digests_offset]) == 0)
      {
        mark_hash (plains_buf, d_return_buf, salt_pos, digests_cnt, 0, digests_offset + 0, gid, il_pos);
      }
    }
  }
}

__kernel void __attribute__((reqd_work_group_size(64, 1, 1))) m18200_sxx (KERN_ATTR_RULES_ESALT (krb5asrep_t))
{
  /**
   * modifier
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);

  if (gid >= gid_max) return;

  /**
   * base
   */

  COPY_PW (pws[gid]);

  __local RC4_KEY rc4_keys[64];

  __local RC4_KEY *rc4_key = &rc4_keys[lid];

  u32 checksum[4];

  checksum[0] = esalt_bufs[digests_offset].checksum[0];
  checksum[1] = esalt_bufs[digests_offset].checksum[1];
  checksum[2] = esalt_bufs[digests_offset].checksum[2];
  checksum[3] = esalt_bufs[digests_offset].checksum[3];

  /**
   * loop
   */

  for (u32 il_pos = 0; il_pos < il_cnt; il_pos++)
  {
    pw_t tmp = PASTE_PW;

    tmp.pw_len = apply_rules (rules_buf[il_pos].cmds, tmp.i, tmp.pw_len);

    md4_ctx_t ctx;

    md4_init (&ctx);

    md4_update_utf16le (&ctx, tmp.i, tmp.pw_len);

    md4_final (&ctx);

    u32 digest[4];

    u32 K2[4];

    kerb_prepare (ctx.h, checksum, digest, K2);

    if (decrypt_and_check (rc4_key, digest, esalt_bufs[digests_offset].edata2, esalt_bufs[digests_offset].edata2_len, K2, checksum) == 1)
    {
      if (atomic_inc (&hashes_shown[digests_offset]) == 0)
      {
        mark_hash (plains_buf, d_return_buf, salt_pos, digests_cnt, 0, digests_offset + 0, gid, il_pos);
      }
    }
  }
}
