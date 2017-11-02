float4 conv1x3_s1(const float *input_ptr,
                  const float *filter_ptr);
float4 conv1x3_s2(const float *input_ptr,
                  const float *filter_ptr);
float conv3x3(const float *input_ptr,
              const float *filter_ptr,
              const int row_width);

void kernel conv_2d_3x3(global const float *input,
                        global const float *filter,
                        global const float *bias,
                        global float *output,
                        private const uint in_chan_num,
                        private const uint out_chan_num,
                        private const uint in_height,
                        private const uint in_width,
                        private const uint out_height,
                        private const uint out_width,
                        private const uint stride_h,
                        private const uint stride_w) {
  int batch = get_global_id(0);
  int out_chan_blk = get_global_id(1);
  int out_pixel_blk = get_global_id(2);

  const uint in_pixel = in_height * in_width;
  const uint out_pixel = out_height * out_width;

  const uint round_out_width = (out_width + 3) / 4;
  const uint out_pixel_height = out_pixel_blk / round_out_width;
  const uint out_pixel_width = out_pixel_blk % round_out_width;

  const uint out_chan_begin = out_chan_blk * 4;
  const uint out_chan_end = min(out_chan_begin + 4, out_chan_num);
  const uint out_pixel_begin = out_pixel_height * out_width + out_pixel_width * 4;
  const uint out_pixel_end = min(out_pixel_begin + 4, (out_pixel_height + 1) * out_width);
  const uint in_pixel_begin = out_pixel_height * stride_h * in_width + out_pixel_width * stride_w * 4;

  const uint in_offset = batch * in_chan_num * in_pixel;
  const uint out_offset = batch * out_chan_num * out_pixel;
  const float *input_base = input + in_offset + in_pixel_begin;
  float *output_base = output + out_offset + out_pixel_begin;

  uint pixels = out_pixel_end - out_pixel_begin;

  for (uint i = out_chan_begin; i < out_chan_end; ++i) {
    float4 res = (float4)bias[i];
    float *output_ptr = output_base + i * out_pixel;
    const float *filter_base = filter + i * in_chan_num * 9;
    if (pixels == 4) {
      for (uint in_chan_idx = 0; in_chan_idx < in_chan_num; ++in_chan_idx) {
        const float* input_ptr = input_base + in_chan_idx * in_pixel;
        const float* filter_ptr = filter_base + in_chan_idx * 9;
        if (stride_w == 1) {
          res += conv1x3_s1(input_ptr + 0 * in_width, filter_ptr + 0 * 3);
          res += conv1x3_s1(input_ptr + 1 * in_width, filter_ptr + 1 * 3);
          res += conv1x3_s1(input_ptr + 2 * in_width, filter_ptr + 2 * 3);
        } else {
          res += conv1x3_s2(input_ptr + 0 * in_width, filter_ptr + 0 * 3);
          res += conv1x3_s2(input_ptr + 1 * in_width, filter_ptr + 1 * 3);
          res += conv1x3_s2(input_ptr + 2 * in_width, filter_ptr + 2 * 3);
        }
      }
      vstore4(res, 0, output_ptr);
    } else {
      for (uint p = 0; p < pixels; ++p) {
        float res = bias[i];
        for (uint in_chan_idx = 0; in_chan_idx < in_chan_num; ++in_chan_idx) {
          const float* input_ptr = input_base + in_chan_idx * in_pixel + p * stride_w;
          const float* filter_ptr = filter_base + in_chan_idx * 9;
          res += conv3x3(input_ptr, filter_ptr, in_width);
        }
        output_ptr[p] = res;
      }
    }
  }
}
