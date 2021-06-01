/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

#define NEW_SIMD_CODE

#include "inc_vendor.cl"
#include "inc_hash_constants.h"
#include "inc_hash_functions.cl"
#include "inc_types.cl"
#include "inc_common.cl"
#include "inc_simd.cl"
#include "inc_hash_sha384.cl"

__kernel void m10800_mxx (KERN_ATTR_VECTOR ())
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

  const u32 pw_len = pws[gid].pw_len & 255;

  u32x w[64] = { 0 };

  for (int i = 0, idx = 0; i < pw_len; i += 4, idx += 1)
  {
    w[idx] = pws[gid].i[idx];
  }

  /**
   * loop
   */

  u32x w0l = w[0];

  for (u32 il_pos = 0; il_pos < il_cnt; il_pos += VECT_SIZE)
  {
    const u32x w0r = words_buf_r[il_pos / VECT_SIZE];

    const u32x w0 = w0l | w0r;

    w[0] = w0;

    sha384_ctx_vector_t ctx;

    sha384_init_vector (&ctx);

    sha384_update_vector (&ctx, w, pw_len);

    sha384_final_vector (&ctx);

    const u32x r0 = l32_from_64 (ctx.h[3]);
    const u32x r1 = h32_from_64 (ctx.h[3]);
    const u32x r2 = l32_from_64 (ctx.h[2]);
    const u32x r3 = h32_from_64 (ctx.h[2]);

    COMPARE_M_SIMD (r0, r1, r2, r3);
  }
}

__kernel void m10800_sxx (KERN_ATTR_VECTOR ())
{
  /**
   * modifier
   */

  const u64 lid = get_local_id (0);
  const u64 gid = get_global_id (0);

  if (gid >= gid_max) return;

  /**
   * digest
   */

  const u32 search[4] =
  {
    digests_buf[digests_offset].digest_buf[DGST_R0],
    digests_buf[digests_offset].digest_buf[DGST_R1],
    digests_buf[digests_offset].digest_buf[DGST_R2],
    digests_buf[digests_offset].digest_buf[DGST_R3]
  };

  /**
   * base
   */

  const u32 pw_len = pws[gid].pw_len & 255;

  u32x w[64] = { 0 };

  for (int i = 0, idx = 0; i < pw_len; i += 4, idx += 1)
  {
    w[idx] = pws[gid].i[idx];
  }

  /**
   * loop
   */

  u32x w0l = w[0];

  for (u32 il_pos = 0; il_pos < il_cnt; il_pos += VECT_SIZE)
  {
    const u32x w0r = words_buf_r[il_pos / VECT_SIZE];

    const u32x w0 = w0l | w0r;

    w[0] = w0;

    sha384_ctx_vector_t ctx;

    sha384_init_vector (&ctx);

    sha384_update_vector (&ctx, w, pw_len);

    sha384_final_vector (&ctx);

    const u32x r0 = l32_from_64 (ctx.h[3]);
    const u32x r1 = h32_from_64 (ctx.h[3]);
    const u32x r2 = l32_from_64 (ctx.h[2]);
    const u32x r3 = h32_from_64 (ctx.h[2]);

    COMPARE_S_SIMD (r0, r1, r2, r3);
  }
}
