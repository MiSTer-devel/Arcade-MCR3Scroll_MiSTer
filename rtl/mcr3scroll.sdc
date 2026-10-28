# Core-specific timing exceptions (loaded after sys/sys_top.sdc)

# hps_io video_calc: video statistics measured on CLK_VIDEO (80MHz) and sampled
# on clk_sys (40MHz) for the HPS info screen. Slow, quasi-static values, no
# functional dependency => not a real timing path.
set_false_path -from {*|hps_io|video_calc|vid_*} -to {*|hps_io|video_calc|dout[*]}
