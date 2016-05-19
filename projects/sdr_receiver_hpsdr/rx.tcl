# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_0 {
  DIN_WIDTH 8 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 224 DIN_FROM 15 DIN_TO 0 DOUT_WIDTH 16
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 4
} {
  m_axis_tready const_0/dout
  m_axis_aclk /ps_0/FCLK_CLK0
  m_axis_aresetn /rst_0/peripheral_aresetn
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_0 {
  NUM_PORTS 6
}

set prop_list {}
for {set i 0} {$i <= 5} {incr i} {
  lappend prop_list IN${i}_WIDTH 32
}
set_property -dict $prop_list [get_bd_cells concat_0]

for {set i 0} {$i <= 5} {incr i} {
  connect_bd_net [get_bd_pins concat_0/In$i] [get_bd_pins fifo_0/m_axis_tdata]
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_1 {
  NUM_PORTS 12
}

set prop_list {}
for {set i 0} {$i <= 11} {incr i} {
  lappend prop_list IN${i}_WIDTH 1
}
set_property -dict $prop_list [get_bd_cells concat_1]

for {set i 0} {$i <= 11} {incr i} {
  connect_bd_net [get_bd_pins concat_1/In$i] [get_bd_pins fifo_0/m_axis_tvalid]
}

# Create axis_switch
cell xilinx.com:ip:axis_switch:1.1 switch_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 2
  ROUTING_MODE 1
  NUM_SI 12
  NUM_MI 6
} {
  s_axis_tdata concat_0/dout
  s_axis_tvalid concat_1/dout
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

set prop_list {}
for {set i 0} {$i <= 5} {incr i} {
  for {set j 0} {$j <= 11} {incr j} {
    if {$i == $j / 2} continue
    lappend prop_list CONFIG.M[format %02d $i]_S[format %02d $j]_CONNECTIVITY 0
  }
}
set_property -dict $prop_list [get_bd_cells switch_0]

unset prop_list

for {set i 0} {$i <= 5} {incr i} {

  # Create xlslice
  cell xilinx.com:ip:xlslice:1.0 slice_[expr $i + 2] {
    DIN_WIDTH 224 DIN_FROM [expr 32 * $i + 63] DIN_TO [expr 32 * $i + 32] DOUT_WIDTH 32
  }

  # Create axis_constant
  cell pavel-demin:user:axis_constant:1.0 phase_$i {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data slice_[expr $i + 2]/Dout
    aclk /ps_0/FCLK_CLK0
  }

  # Create dds_compiler
  cell xilinx.com:ip:dds_compiler:6.0 dds_$i {
    DDS_CLOCK_RATE 125
    SPURIOUS_FREE_DYNAMIC_RANGE 120
    FREQUENCY_RESOLUTION 0.2
    PHASE_INCREMENT Streaming
    HAS_TREADY true
    HAS_PHASE_OUT false
    PHASE_WIDTH 30
    OUTPUT_WIDTH 21
    NEGATIVE_SINE true
  } {
    S_AXIS_PHASE phase_$i/M_AXIS
    aclk /ps_0/FCLK_CLK0
  }

  # Create axis_lfsr
  cell pavel-demin:user:axis_lfsr:1.0 lfsr_$i {} {
    aclk /ps_0/FCLK_CLK0
    aresetn /rst_0/peripheral_aresetn
  }

  # Create cmpy
  cell xilinx.com:ip:cmpy:6.0 mult_$i {
    FLOWCONTROL Blocking
    APORTWIDTH.VALUE_SRC USER
    BPORTWIDTH.VALUE_SRC USER
    APORTWIDTH 14
    BPORTWIDTH 21
    ROUNDMODE Random_Rounding
    OUTPUTWIDTH 25
  } {
    S_AXIS_A switch_0/M0${i}_AXIS
    S_AXIS_B dds_$i/M_AXIS_DATA
    S_AXIS_CTRL lfsr_$i/M_AXIS
    aclk /ps_0/FCLK_CLK0
  }

  # Create axis_broadcaster
  cell xilinx.com:ip:axis_broadcaster:1.1 bcast_$i {
    S_TDATA_NUM_BYTES.VALUE_SRC USER
    M_TDATA_NUM_BYTES.VALUE_SRC USER
    S_TDATA_NUM_BYTES 8
    M_TDATA_NUM_BYTES 3
    M00_TDATA_REMAP {tdata[23:0]}
    M01_TDATA_REMAP {tdata[55:32]}
  } {
    S_AXIS mult_$i/M_AXIS_DOUT
    aclk /ps_0/FCLK_CLK0
    aresetn /rst_0/peripheral_aresetn
  }

}

for {set i 0} {$i <= 11} {incr i} {

  # Create axis_variable
  cell pavel-demin:user:axis_variable:1.0 rate_$i {
    AXIS_TDATA_WIDTH 16
  } {
    cfg_data slice_1/Dout
    aclk /ps_0/FCLK_CLK0
    aresetn /rst_0/peripheral_aresetn
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler:4.0 cic_$i {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Decimation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Programmable
    MINIMUM_RATE 125
    MAXIMUM_RATE 2000
    FIXED_OR_INITIAL_RATE 500
    INPUT_SAMPLE_FREQUENCY 125
    CLOCK_FREQUENCY 125
    INPUT_DATA_WIDTH 24
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 24
    USE_XTREME_DSP_SLICE false
    HAS_DOUT_TREADY true
    HAS_ARESETN true
  } {
    S_AXIS_DATA bcast_[expr $i / 2]/M0[expr $i % 2]_AXIS
    S_AXIS_CONFIG rate_$i/M_AXIS
    aclk /ps_0/FCLK_CLK0
    aresetn /rst_0/peripheral_aresetn
  }

}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner:1.1 comb_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 3
  NUM_SI 12
} {
  S00_AXIS cic_0/M_AXIS_DATA
  S01_AXIS cic_1/M_AXIS_DATA
  S02_AXIS cic_2/M_AXIS_DATA
  S03_AXIS cic_3/M_AXIS_DATA
  S04_AXIS cic_4/M_AXIS_DATA
  S05_AXIS cic_5/M_AXIS_DATA
  S06_AXIS cic_6/M_AXIS_DATA
  S07_AXIS cic_7/M_AXIS_DATA
  S08_AXIS cic_8/M_AXIS_DATA
  S09_AXIS cic_9/M_AXIS_DATA
  S10_AXIS cic_10/M_AXIS_DATA
  S11_AXIS cic_11/M_AXIS_DATA
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 36
  M_TDATA_NUM_BYTES 3
} {
  S_AXIS comb_0/M_AXIS
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler:7.2 fir_0 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 24
  COEFFICIENTVECTOR {1.1961245066e-08, 1.2656108167e-08, 1.3309353571e-08, 1.3941028874e-08, 1.4577279025e-08, 1.5250460331e-08, 1.5999119963e-08, 1.6867826841e-08, 1.7906841259e-08, 1.9171612419e-08, 2.0722095181e-08, 2.2621879857e-08, 2.4937131678e-08, 2.7735339695e-08, 3.1083878269e-08, 3.5048387923e-08, 3.9690986153e-08, 4.5068322788e-08, 5.1229498494e-08, 5.8213869173e-08, 6.6048762982e-08, 7.4747140729e-08, 8.4305234107e-08, 9.4700199781e-08, 1.0588783054e-07, 1.1780036751e-07, 1.3034445969e-07, 1.4339931898e-07, 1.5681511974e-07, 1.7041169269e-07, 1.8397756236e-07, 1.9726937647e-07, 2.1001177348e-07, 2.2189773177e-07, 2.3258944045e-07, 2.4171972680e-07, 2.4889407015e-07, 2.5369322559e-07, 2.5567647341e-07, 2.5438550268e-07, 2.4934892788e-07, 2.4008742888e-07, 2.2611949400e-07, 2.0696773561e-07, 1.8216573725e-07, 1.5126537985e-07, 1.1384458395e-07, 6.9515393959e-08, 1.7932319579e-08, -4.1199160230e-08, -1.0811403513e-07, -1.8297925609e-07, -2.6588540362e-07, -3.5683865869e-07, -4.5575320867e-07, -5.6244422446e-07, -6.7662154650e-07, -7.9788421816e-07, -9.2571600254e-07, -1.0594820156e-06, -1.1984266018e-06, -1.3416725718e-06, -1.4882219093e-06, -1.6369580433e-06, -1.7866497683e-06, -1.9359568745e-06, -2.0834375358e-06, -2.2275574799e-06, -2.3667009437e-06, -2.4991833931e-06, -2.6232659609e-06, -2.7371715321e-06, -2.8391023766e-06, -2.9272592053e-06, -2.9998614945e-06, -3.0551689028e-06, -3.0915035709e-06, -3.1072730774e-06, -3.1009937957e-06, -3.0713143764e-06, -3.0170390631e-06, -2.9371505298e-06, -2.8308319185e-06, -2.6974877428e-06, -2.5367633207e-06, -2.3485623953e-06, -2.1330626091e-06, -1.8907284997e-06, -1.6223217031e-06, -1.3289080634e-06, -1.0118613734e-06, -6.7286349537e-07, -3.1390064680e-07, 6.2744330652e-08, 4.5450385566e-07, 8.5854173791e-07, 1.2717735970e-06, 1.6908915579e-06, 2.1123931561e-06, 2.5326143242e-06, 2.9477662746e-06, 3.3539760273e-06, 3.7473302740e-06, 4.1239222030e-06, 4.4799008547e-06, 4.8115225143e-06, 5.1152035966e-06, 5.3875744241e-06, 5.6255332554e-06, 5.8262998780e-06, 5.9874680465e-06, 6.1070560204e-06, 6.1835544346e-06, 6.2159707293e-06, 6.2038693619e-06, 6.1474070329e-06, 6.0473621801e-06, 5.9051580216e-06, 5.7228784708e-06, 5.5032763002e-06, 5.2497729887e-06, 4.9664497653e-06, 4.6580294439e-06, 4.3298487341e-06, 3.9878208223e-06, 3.6383881208e-06, 3.2884652057e-06, 2.9453720871e-06, 2.6167580855e-06, 2.3105167192e-06, 2.0346921477e-06, 1.7973778467e-06, 1.6066083302e-06, 1.4702448653e-06, 1.3958562538e-06, 1.3905958769e-06, 1.4610763121e-06, 1.6132429361e-06, 1.8522480178e-06, 2.1823268856e-06, 2.6066778149e-06, 3.1273473287e-06, 3.7451226329e-06, 4.4594329156e-06, 5.2682612301e-06, 6.1680686450e-06, 7.1537322944e-06, 8.2184988774e-06, 9.3539550616e-06, 1.0550016118e-05, 1.1794933972e-05, 1.3075325685e-05, 1.4376223195e-05, 1.5681144940e-05, 1.6972189756e-05, 1.8230153205e-05, 1.9434666227e-05, 2.0564355758e-05, 2.1597026644e-05, 2.2509863950e-05, 2.3279654423e-05, 2.3883025624e-05, 2.4296700925e-05, 2.4497768329e-05, 2.4463960766e-05, 2.4173945299e-05, 2.3607618414e-05, 2.2746404378e-05, 2.1573553434e-05, 2.0074436473e-05, 1.8236832669e-05, 1.6051206476e-05, 1.3510970340e-05, 1.0612729430e-05, 7.3565047648e-06, 3.7459311219e-06, -2.1157373450e-07, -4.5046718270e-06, -9.1180028640e-06, -1.4032120137e-05, -1.9223467001e-05, -2.4664396187e-05, -3.0323233834e-05, -3.6164389688e-05, -4.2148514504e-05, -4.8232705175e-05, -5.4370757623e-05, -6.0513466940e-05, -6.6608973738e-05, -7.2603155076e-05, -7.8440057785e-05, -8.4062371427e-05, -8.9411937561e-05, -9.4430291431e-05, -9.9059231671e-05, -1.0324141308e-04, -1.0692095708e-04, -1.1004407399e-04, -1.1255969092e-04, -1.1442007866e-04, -1.1558147072e-04, -1.1600466749e-04, -1.1565561822e-04, -1.1450597358e-04, -1.1253360148e-04, -1.0972305893e-04, -1.0606601291e-04, -1.0156160349e-04, -9.6216742676e-05, -9.0046343017e-05, -8.3073470457e-05, -7.5329416481e-05, -6.6853685336e-05, -5.7693892821e-05, -4.7905573966e-05, -3.7551897816e-05, -2.6703288469e-05, -1.5436952505e-05, -3.8363139815e-06, 8.0096407494e-06, 2.0007105101e-05, 3.2058276750e-05, 4.4062259067e-05, 5.5916032885e-05, 6.7515490953e-05, 7.8756526415e-05, 8.9536165679e-05, 9.9753735148e-05, 1.0931205045e-04, 1.1811861606e-04, 1.2608682262e-04, 1.3313712860e-04, 1.3919821272e-04, 1.4420808314e-04, 1.4811512926e-04, 1.5087910214e-04, 1.5247200951e-04, 1.5287891179e-04, 1.5209860590e-04, 1.5014418435e-04, 1.4704345786e-04, 1.4283923068e-04, 1.3758941891e-04, 1.3136700327e-04, 1.2425980938e-04, 1.1637010987e-04, 1.0781404442e-04, 9.8720855572e-05, 8.9231940053e-05, 7.9499717050e-05, 6.9686317232e-05, 5.9962098023e-05, 5.0503992897e-05, 4.1493704457e-05, 3.3115753143e-05, 2.5555395434e-05, 1.8996427397e-05, 1.3618891281e-05, 9.5967046990e-06, 7.0952335593e-06, 6.2688314555e-06, 7.2583695702e-06, 1.0188782321e-05, 1.5166654945e-05, 2.2277879967e-05, 3.1585410007e-05, 4.3127134636e-05, 5.6913909010e-05, 7.2927761717e-05, 9.1120308728e-05, 1.1141139952e-04, 1.3368802032e-04, 1.5780347798e-04, 1.8357688632e-04, 2.1079297497e-04, 2.3920223810e-04, 2.6852143849e-04, 2.9843447925e-04, 3.2859365272e-04, 3.5862127298e-04, 3.8811169485e-04, 4.1663371924e-04, 4.4373338044e-04, 4.6893710791e-04, 4.9175525092e-04, 5.1168595069e-04, 5.2821934111e-04, 5.4084205492e-04, 5.4904200902e-04, 5.5231343861e-04, 5.5016214675e-04, 5.4211093240e-04, 5.2770515714e-04, 5.0651840800e-04, 4.7815821114e-04, 4.4227174930e-04, 3.9855153363e-04, 3.4674097954e-04, 2.8663983471e-04, 2.1810940719e-04, 1.4107754080e-04, 5.5543285854e-05, -3.8418786621e-05, -1.4065467735e-04, -2.5092750685e-04, -3.6891456558e-04, -4.9420491034e-04, -6.2629754784e-04, -7.6460024308e-04, -9.0842898607e-04, -1.0570081464e-03, -1.2094713400e-03, -1.3648630285e-03, -1.5221408641e-03, -1.6801787908e-03, -1.8377709026e-03, -1.9936360574e-03, -2.1464232367e-03, -2.2947176355e-03, -2.4370474604e-03, -2.5718914099e-03, -2.6976867996e-03, -2.8128382946e-03, -2.9157272026e-03, -3.0047212747e-03, -3.0781849584e-03, -3.1344900397e-03, -3.1720266076e-03, -3.1892142704e-03, -3.1845135487e-03, -3.1564373671e-03, -3.1035625641e-03, -3.0245413366e-03, -2.9181125367e-03, -2.7831127328e-03, -2.6184869521e-03, -2.4232990185e-03, -2.1967414023e-03, -1.9381444998e-03, -1.6469852638e-03, -1.3228951082e-03, -9.6566701483e-04, -5.7526177425e-04, -1.5181329794e-04, 3.0436705551e-04, 7.9278719108e-04, 1.3127720694e-03, 1.8634626169e-03, 2.4438157851e-03, 3.0526057782e-03, 3.6884264660e-03, 4.3496949844e-03, 5.0346565220e-03, 5.7413902800e-03, 6.4678165856e-03, 7.2117051287e-03, 7.9706842849e-03, 8.7422514784e-03, 9.5237845309e-03, 1.0312553935e-02, 1.1105735981e-02, 1.1900426663e-02, 1.2693656283e-02, 1.3482404659e-02, 1.4263616846e-02, 1.5034219280e-02, 1.5791136222e-02, 1.6531306423e-02, 1.7251699879e-02, 1.7949334580e-02, 1.8621293136e-02, 1.9264739177e-02, 1.9876933407e-02, 2.0455249216e-02, 2.0997187730e-02, 2.1500392215e-02, 2.1962661719e-02, 2.2381963874e-02, 2.2756446754e-02, 2.3084449725e-02, 2.3364513198e-02, 2.3595387227e-02, 2.3776038880e-02, 2.3905658354e-02, 2.3983663763e-02, 2.4009704590e-02, 2.3983663763e-02, 2.3905658354e-02, 2.3776038880e-02, 2.3595387227e-02, 2.3364513198e-02, 2.3084449725e-02, 2.2756446754e-02, 2.2381963874e-02, 2.1962661719e-02, 2.1500392215e-02, 2.0997187730e-02, 2.0455249216e-02, 1.9876933407e-02, 1.9264739177e-02, 1.8621293136e-02, 1.7949334580e-02, 1.7251699879e-02, 1.6531306423e-02, 1.5791136222e-02, 1.5034219280e-02, 1.4263616846e-02, 1.3482404659e-02, 1.2693656283e-02, 1.1900426663e-02, 1.1105735981e-02, 1.0312553935e-02, 9.5237845309e-03, 8.7422514784e-03, 7.9706842849e-03, 7.2117051287e-03, 6.4678165856e-03, 5.7413902800e-03, 5.0346565220e-03, 4.3496949844e-03, 3.6884264660e-03, 3.0526057782e-03, 2.4438157851e-03, 1.8634626169e-03, 1.3127720694e-03, 7.9278719108e-04, 3.0436705551e-04, -1.5181329794e-04, -5.7526177425e-04, -9.6566701483e-04, -1.3228951082e-03, -1.6469852638e-03, -1.9381444998e-03, -2.1967414023e-03, -2.4232990185e-03, -2.6184869521e-03, -2.7831127328e-03, -2.9181125367e-03, -3.0245413366e-03, -3.1035625641e-03, -3.1564373671e-03, -3.1845135487e-03, -3.1892142704e-03, -3.1720266076e-03, -3.1344900397e-03, -3.0781849584e-03, -3.0047212747e-03, -2.9157272026e-03, -2.8128382946e-03, -2.6976867996e-03, -2.5718914099e-03, -2.4370474604e-03, -2.2947176355e-03, -2.1464232367e-03, -1.9936360574e-03, -1.8377709026e-03, -1.6801787908e-03, -1.5221408641e-03, -1.3648630285e-03, -1.2094713400e-03, -1.0570081464e-03, -9.0842898607e-04, -7.6460024308e-04, -6.2629754784e-04, -4.9420491034e-04, -3.6891456558e-04, -2.5092750685e-04, -1.4065467735e-04, -3.8418786621e-05, 5.5543285854e-05, 1.4107754080e-04, 2.1810940719e-04, 2.8663983471e-04, 3.4674097954e-04, 3.9855153363e-04, 4.4227174930e-04, 4.7815821114e-04, 5.0651840800e-04, 5.2770515714e-04, 5.4211093240e-04, 5.5016214675e-04, 5.5231343861e-04, 5.4904200902e-04, 5.4084205492e-04, 5.2821934111e-04, 5.1168595069e-04, 4.9175525092e-04, 4.6893710791e-04, 4.4373338044e-04, 4.1663371924e-04, 3.8811169485e-04, 3.5862127298e-04, 3.2859365272e-04, 2.9843447925e-04, 2.6852143849e-04, 2.3920223810e-04, 2.1079297497e-04, 1.8357688632e-04, 1.5780347798e-04, 1.3368802032e-04, 1.1141139952e-04, 9.1120308728e-05, 7.2927761717e-05, 5.6913909010e-05, 4.3127134636e-05, 3.1585410007e-05, 2.2277879967e-05, 1.5166654945e-05, 1.0188782321e-05, 7.2583695702e-06, 6.2688314555e-06, 7.0952335593e-06, 9.5967046990e-06, 1.3618891281e-05, 1.8996427397e-05, 2.5555395434e-05, 3.3115753143e-05, 4.1493704457e-05, 5.0503992897e-05, 5.9962098023e-05, 6.9686317232e-05, 7.9499717050e-05, 8.9231940053e-05, 9.8720855572e-05, 1.0781404442e-04, 1.1637010987e-04, 1.2425980938e-04, 1.3136700327e-04, 1.3758941891e-04, 1.4283923068e-04, 1.4704345786e-04, 1.5014418435e-04, 1.5209860590e-04, 1.5287891179e-04, 1.5247200951e-04, 1.5087910214e-04, 1.4811512926e-04, 1.4420808314e-04, 1.3919821272e-04, 1.3313712860e-04, 1.2608682262e-04, 1.1811861606e-04, 1.0931205045e-04, 9.9753735148e-05, 8.9536165679e-05, 7.8756526415e-05, 6.7515490953e-05, 5.5916032885e-05, 4.4062259067e-05, 3.2058276750e-05, 2.0007105101e-05, 8.0096407494e-06, -3.8363139815e-06, -1.5436952505e-05, -2.6703288469e-05, -3.7551897816e-05, -4.7905573966e-05, -5.7693892821e-05, -6.6853685336e-05, -7.5329416481e-05, -8.3073470457e-05, -9.0046343017e-05, -9.6216742676e-05, -1.0156160349e-04, -1.0606601291e-04, -1.0972305893e-04, -1.1253360148e-04, -1.1450597358e-04, -1.1565561822e-04, -1.1600466749e-04, -1.1558147072e-04, -1.1442007866e-04, -1.1255969092e-04, -1.1004407399e-04, -1.0692095708e-04, -1.0324141308e-04, -9.9059231671e-05, -9.4430291431e-05, -8.9411937561e-05, -8.4062371427e-05, -7.8440057785e-05, -7.2603155076e-05, -6.6608973738e-05, -6.0513466940e-05, -5.4370757623e-05, -4.8232705175e-05, -4.2148514504e-05, -3.6164389688e-05, -3.0323233834e-05, -2.4664396187e-05, -1.9223467001e-05, -1.4032120137e-05, -9.1180028640e-06, -4.5046718270e-06, -2.1157373450e-07, 3.7459311219e-06, 7.3565047648e-06, 1.0612729430e-05, 1.3510970340e-05, 1.6051206476e-05, 1.8236832669e-05, 2.0074436473e-05, 2.1573553434e-05, 2.2746404378e-05, 2.3607618414e-05, 2.4173945299e-05, 2.4463960766e-05, 2.4497768329e-05, 2.4296700925e-05, 2.3883025624e-05, 2.3279654423e-05, 2.2509863950e-05, 2.1597026644e-05, 2.0564355758e-05, 1.9434666227e-05, 1.8230153205e-05, 1.6972189756e-05, 1.5681144940e-05, 1.4376223195e-05, 1.3075325685e-05, 1.1794933972e-05, 1.0550016118e-05, 9.3539550616e-06, 8.2184988774e-06, 7.1537322944e-06, 6.1680686450e-06, 5.2682612301e-06, 4.4594329156e-06, 3.7451226329e-06, 3.1273473287e-06, 2.6066778149e-06, 2.1823268856e-06, 1.8522480178e-06, 1.6132429361e-06, 1.4610763121e-06, 1.3905958769e-06, 1.3958562538e-06, 1.4702448653e-06, 1.6066083302e-06, 1.7973778467e-06, 2.0346921477e-06, 2.3105167192e-06, 2.6167580855e-06, 2.9453720871e-06, 3.2884652057e-06, 3.6383881208e-06, 3.9878208223e-06, 4.3298487341e-06, 4.6580294439e-06, 4.9664497653e-06, 5.2497729887e-06, 5.5032763002e-06, 5.7228784708e-06, 5.9051580216e-06, 6.0473621801e-06, 6.1474070329e-06, 6.2038693619e-06, 6.2159707293e-06, 6.1835544346e-06, 6.1070560204e-06, 5.9874680465e-06, 5.8262998780e-06, 5.6255332554e-06, 5.3875744241e-06, 5.1152035966e-06, 4.8115225143e-06, 4.4799008547e-06, 4.1239222030e-06, 3.7473302740e-06, 3.3539760273e-06, 2.9477662746e-06, 2.5326143242e-06, 2.1123931561e-06, 1.6908915579e-06, 1.2717735970e-06, 8.5854173791e-07, 4.5450385566e-07, 6.2744330652e-08, -3.1390064680e-07, -6.7286349537e-07, -1.0118613734e-06, -1.3289080634e-06, -1.6223217031e-06, -1.8907284997e-06, -2.1330626091e-06, -2.3485623953e-06, -2.5367633207e-06, -2.6974877428e-06, -2.8308319185e-06, -2.9371505298e-06, -3.0170390631e-06, -3.0713143764e-06, -3.1009937957e-06, -3.1072730774e-06, -3.0915035709e-06, -3.0551689028e-06, -2.9998614945e-06, -2.9272592053e-06, -2.8391023766e-06, -2.7371715321e-06, -2.6232659609e-06, -2.4991833931e-06, -2.3667009437e-06, -2.2275574799e-06, -2.0834375358e-06, -1.9359568745e-06, -1.7866497683e-06, -1.6369580433e-06, -1.4882219093e-06, -1.3416725718e-06, -1.1984266018e-06, -1.0594820156e-06, -9.2571600254e-07, -7.9788421816e-07, -6.7662154650e-07, -5.6244422446e-07, -4.5575320867e-07, -3.5683865869e-07, -2.6588540362e-07, -1.8297925609e-07, -1.0811403513e-07, -4.1199160230e-08, 1.7932319579e-08, 6.9515393959e-08, 1.1384458395e-07, 1.5126537985e-07, 1.8216573725e-07, 2.0696773561e-07, 2.2611949400e-07, 2.4008742888e-07, 2.4934892788e-07, 2.5438550268e-07, 2.5567647341e-07, 2.5369322559e-07, 2.4889407015e-07, 2.4171972680e-07, 2.3258944045e-07, 2.2189773177e-07, 2.1001177348e-07, 1.9726937647e-07, 1.8397756236e-07, 1.7041169269e-07, 1.5681511974e-07, 1.4339931898e-07, 1.3034445969e-07, 1.1780036751e-07, 1.0588783054e-07, 9.4700199781e-08, 8.4305234107e-08, 7.4747140729e-08, 6.6048762982e-08, 5.8213869173e-08, 5.1229498494e-08, 4.5068322788e-08, 3.9690986153e-08, 3.5048387923e-08, 3.1083878269e-08, 2.7735339695e-08, 2.4937131678e-08, 2.2621879857e-08, 2.0722095181e-08, 1.9171612419e-08, 1.7906841259e-08, 1.6867826841e-08, 1.5999119963e-08, 1.5250460331e-08, 1.4577279025e-08, 1.3941028874e-08, 1.3309353571e-08, 1.2656108167e-08, 1.1961245066e-08}
  COEFFICIENT_WIDTH 24
  QUANTIZATION Maximize_Dynamic_Range
  BESTPRECISION true
  FILTER_TYPE Decimation
  RATE_CHANGE_TYPE Fixed_Fractional
  INTERPOLATION_RATE 24
  DECIMATION_RATE 25
  NUMBER_CHANNELS 12
  NUMBER_PATHS 1
  SAMPLE_FREQUENCY 1.0
  CLOCK_FREQUENCY 125
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 25
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA conv_0/M_AXIS
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 subset_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 3
  TDATA_REMAP {tdata[23:0]}
} {
  S_AXIS fir_0/M_AXIS_DATA
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler:7.2 fir_1 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 24
  COEFFICIENTVECTOR {3.1510738100e-09, -6.7479865873e-09, -1.6133664125e-08, -2.2416870221e-08, -2.3718628905e-08, -1.9292508290e-08, -9.6174168542e-09, 3.7555123983e-09, 1.8454427798e-08, 3.1534918180e-08, 3.9745334832e-08, 3.9943687057e-08, 2.9811802898e-08, 8.8714888403e-09, -2.0451046381e-08, -5.2221193673e-08, -7.7449406562e-08, -8.5993206240e-08, -6.9785214388e-08, -2.6585997378e-08, 3.7109737124e-08, 1.0553704815e-07, 1.5654245404e-07, 1.6784289288e-07, 1.2521437045e-07, 2.9950472396e-08, -9.7521323957e-08, -2.2028313557e-07, -2.9440377563e-07, -2.8330054933e-07, -1.7268922538e-07, 1.9374920887e-08, 2.4219414231e-07, 4.2402455251e-07, 4.9369250885e-07, 4.0622379033e-07, 1.6382572605e-07, -1.7633053598e-07, -5.1275397350e-07, -7.2806861891e-07, -7.2796837379e-07, -4.7835670298e-07, -2.6982996518e-08, 5.0066210178e-07, 9.3369997553e-07, 1.1091534301e-06, 9.3023613610e-07, 4.0960212352e-07, -3.1993213186e-07, -1.0354725084e-06, -1.4897836295e-06, -1.4941495247e-06, -9.9134817368e-07, -9.1808887328e-08, 9.4429490393e-07, 1.7792668521e-06, 2.1055536806e-06, 1.7553133763e-06, 7.7384700090e-07, -5.7271861678e-07, -1.8653214254e-06, -2.6598735509e-06, -2.6370405857e-06, -1.7241912059e-06, -1.4450444581e-07, 1.6308815038e-06, 3.0204430208e-06, 3.5205182605e-06, 2.8840042895e-06, 1.2271291662e-06, -9.7874111711e-07, -3.0373339266e-06, -4.2453153459e-06, -4.1302781766e-06, -2.6289938120e-06, -1.4025822243e-07, 2.5753423082e-06, 4.6259752774e-06, 5.2802839800e-06, 4.2252196029e-06, 1.6998388511e-06, -1.5488320135e-06, -4.4845653586e-06, -6.1122032640e-06, -5.8142893914e-06, -3.5803107470e-06, -4.4606083446e-08, 3.6907340115e-06, 6.3998627227e-06, 7.1366486888e-06, 5.5644054666e-06, 2.0969795263e-06, -2.2053023924e-06, -5.9608852219e-06, -7.9135163167e-06, -7.3548222401e-06, -4.3798891371e-06, 1.1627442659e-07, 4.7093340218e-06, 7.9013048001e-06, 8.6141827121e-06, 6.5571420669e-06, 2.3409427568e-06, -2.7048254700e-06, -6.9568946317e-06, -9.0282441787e-06, -8.2273091938e-06, -4.7919923096e-06, 1.8218599568e-07, 5.0982471835e-06, 8.3806677143e-06, 8.9906823687e-06, 6.7618588014e-06, 2.4447265932e-06, -2.5519376712e-06, -6.6328694656e-06, -8.5397349316e-06, -7.7498279814e-06, -4.6195373148e-06, -2.3217914137e-07, 3.9880051684e-06, 6.7557076311e-06, 7.3312741704e-06, 5.7198669808e-06, 2.6076065295e-06, -9.2524845799e-07, -3.7972395600e-06, -5.2774918022e-06, -5.1746726048e-06, -3.8113674775e-06, -1.8178711579e-06, 1.5305012946e-07, 1.6657960026e-06, 2.6008503148e-06, 3.0865492220e-06, 3.3154529085e-06, 3.3507594867e-06, 3.0331364055e-06, 2.0506176943e-06, 1.5285351602e-07, -2.5888580771e-06, -5.6154526234e-06, -7.9265738121e-06, -8.3769149819e-06, -6.1465540987e-06, -1.2106684715e-06, 5.4043393215e-06, 1.1742901607e-05, 1.5456810693e-05, 1.4625508257e-05, 8.5870451935e-06, -1.5489194400e-06, -1.2967391097e-05, -2.1872823851e-05, -2.4709562826e-05, -1.9498796775e-05, -6.8097583970e-06, 1.0051713891e-05, 2.5822264067e-05, 3.4879904022e-05, 3.3192776794e-05, 1.9957970084e-05, -1.7006388713e-06, -2.5343458669e-05, -4.3074923396e-05, -4.8135763069e-05, -3.7390701894e-05, -1.2819212068e-05, 1.8624563166e-05, 4.6904808404e-05, 6.2064674305e-05, 5.7673778846e-05, 3.3385412278e-05, -4.3730359405e-06, -4.3989648722e-05, -7.2191292521e-05, -7.8449213324e-05, -5.8817377470e-05, -1.7828767302e-05, 3.2364715456e-05, 7.5533778781e-05, 9.6586177750e-05, 8.6789838921e-05, 4.7211972902e-05, -1.0936020738e-05, -6.9387745654e-05, -1.0852865169e-04, -1.1394918918e-04, -8.1663421490e-05, -2.0125847225e-05, 5.1845248574e-05, 1.1078618684e-04, 1.3622472120e-04, 1.1775399574e-04, 5.9108947314e-05, -2.2307560149e-05, -1.0053938525e-04, -1.4934964209e-04, -1.5101640956e-04, -1.0270312117e-04, -1.8129808633e-05, 7.6246440808e-05, 1.4951040496e-04, 1.7643760861e-04, 1.4617440650e-04, 6.6461651596e-05, -3.8205509248e-05, -1.3410620435e-04, -1.8919946970e-04, -1.8386734509e-04, -1.1787995488e-04, -1.1112425508e-05, 1.0243507472e-04, 1.8552142260e-04, 2.0995211782e-04, 1.6619217297e-04, 6.7009643296e-05, -5.6226120270e-05, -1.6353239694e-04, -2.1938887370e-04, -2.0459240130e-04, -1.2290110020e-04, -1.5102288781e-07, 1.2398389600e-04, 2.0894342750e-04, 2.2667724152e-04, 1.7101401313e-04, 5.9834648368e-05, -7.0730850437e-05, -1.7818819071e-04, -2.2769494252e-04, -2.0352603975e-04, -1.1415692892e-04, 1.0716831436e-05, 1.3018327474e-04, 2.0573694330e-04, 2.1391892035e-04, 1.5374741510e-04, 4.6526009946e-05, -7.1763889632e-05, -1.6276390717e-04, -1.9846619690e-04, -1.7005204359e-04, -8.9968418149e-05, 1.3224229063e-05, 1.0518999200e-04, 1.5757142899e-04, 1.5703973904e-04, 1.0864156338e-04, 3.2594351448e-05, -4.3939078188e-05, -9.6833385579e-05, -1.1301037302e-04, -9.3681964513e-05, -5.1984134189e-05, -6.3558769649e-06, 2.7394018357e-05, 4.2018506980e-05, 4.0424005351e-05, 3.2501804643e-05, 2.8852559317e-05, 3.4427394725e-05, 4.5185423350e-05, 4.9576845997e-05, 3.4497674886e-05, -6.7878473685e-06, -6.8463602021e-05, -1.3107772706e-04, -1.6703059492e-04, -1.5132922457e-04, -7.3727467420e-05, 5.2883189241e-05, 1.9220907824e-04, 2.9408029820e-04, 3.1162746860e-04, 2.2048158078e-04, 3.2646384841e-05, -2.0134275495e-04, -4.0473432259e-04, -4.9889658282e-04, -4.3223443720e-04, -2.0343933818e-04, 1.3045935867e-04, 4.6636610734e-04, 6.8594860888e-04, 6.9616608186e-04, 4.6595396291e-04, 4.5260964785e-05, -4.4260454834e-04, -8.3575791572e-04, -9.8635547032e-04, -8.1429454422e-04, -3.4300655947e-04, 2.9731541813e-04, 9.0369053242e-04, 1.2634551645e-03, 1.2273028724e-03, 7.6762822405e-04, 2.7738939561e-07, -8.4147811539e-04, -1.4762661175e-03, -1.6672033786e-03, -1.3077416482e-03, -4.7036541599e-04, 6.0209209335e-04, 1.5646344677e-03, 2.0794788201e-03, 1.9324768920e-03, 1.1170799362e-03, -1.4579287560e-04, -1.4641798141e-03, -2.3947453400e-03, -2.5898389339e-03, -1.9237912214e-03, -5.5356514470e-04, 1.1121849726e-03, 2.5322837502e-03, 3.2066469942e-03, 2.8493519493e-03, 1.5021678136e-03, -4.5462215038e-04, -2.4055363054e-03, -3.6907865866e-03, -3.8264377350e-03, -2.6812888538e-03, -5.4731763556e-04, 1.9279600609e-03, 3.9343466863e-03, 4.7608300520e-03, 4.0428732072e-03, 1.9105078203e-03, -1.0198766160e-03, -3.8184141277e-03, -5.5327014646e-03, -5.5070900169e-03, -3.6247697532e-03, -3.8568020018e-04, 3.2175655909e-03, 5.9982887261e-03, 6.9608670405e-03, 5.6491510556e-03, 2.3386383892e-03, -2.0031331097e-03, -5.9911830921e-03, -8.2574678896e-03, -7.9110945349e-03, -4.8723056897e-03, 4.0507028286e-05, 5.3177717169e-03, 9.2121385286e-03, 1.0305326660e-02, 8.0080524590e-03, 2.8216914567e-03, -3.7433059553e-03, -9.5913740604e-03, -1.2694025699e-02, -1.1772146376e-02, -6.7851668981e-03, 9.4985923288e-04, 9.0786168700e-03, 1.4900245690e-02, 1.6232794919e-02, 1.2184973591e-02, 3.5740778924e-03, -7.1772204957e-03, -1.6678686344e-02, -2.1587958386e-02, -1.9712415627e-02, -1.0853277130e-02, 2.9014232139e-03, 1.7581909904e-02, 2.8383086392e-02, 3.1093311197e-02, 2.3507403024e-02, 6.3961990155e-03, -1.6298878122e-02, -3.8176661628e-02, -5.1869882834e-02, -5.0965283203e-02, -3.1848440172e-02, 5.0392274709e-03, 5.4910696550e-02, 1.0944509722e-01, 1.5854311078e-01, 1.9260927992e-01, 2.0479189660e-01, 1.9260927992e-01, 1.5854311078e-01, 1.0944509722e-01, 5.4910696550e-02, 5.0392274709e-03, -3.1848440172e-02, -5.0965283203e-02, -5.1869882834e-02, -3.8176661628e-02, -1.6298878122e-02, 6.3961990155e-03, 2.3507403024e-02, 3.1093311197e-02, 2.8383086392e-02, 1.7581909904e-02, 2.9014232139e-03, -1.0853277130e-02, -1.9712415627e-02, -2.1587958386e-02, -1.6678686344e-02, -7.1772204957e-03, 3.5740778924e-03, 1.2184973591e-02, 1.6232794919e-02, 1.4900245690e-02, 9.0786168700e-03, 9.4985923288e-04, -6.7851668981e-03, -1.1772146376e-02, -1.2694025699e-02, -9.5913740604e-03, -3.7433059553e-03, 2.8216914567e-03, 8.0080524590e-03, 1.0305326660e-02, 9.2121385286e-03, 5.3177717169e-03, 4.0507028286e-05, -4.8723056897e-03, -7.9110945349e-03, -8.2574678896e-03, -5.9911830921e-03, -2.0031331097e-03, 2.3386383892e-03, 5.6491510556e-03, 6.9608670405e-03, 5.9982887261e-03, 3.2175655909e-03, -3.8568020018e-04, -3.6247697532e-03, -5.5070900169e-03, -5.5327014646e-03, -3.8184141277e-03, -1.0198766160e-03, 1.9105078203e-03, 4.0428732072e-03, 4.7608300520e-03, 3.9343466863e-03, 1.9279600609e-03, -5.4731763556e-04, -2.6812888538e-03, -3.8264377350e-03, -3.6907865866e-03, -2.4055363054e-03, -4.5462215038e-04, 1.5021678136e-03, 2.8493519493e-03, 3.2066469942e-03, 2.5322837502e-03, 1.1121849726e-03, -5.5356514470e-04, -1.9237912214e-03, -2.5898389339e-03, -2.3947453400e-03, -1.4641798141e-03, -1.4579287560e-04, 1.1170799362e-03, 1.9324768920e-03, 2.0794788201e-03, 1.5646344677e-03, 6.0209209335e-04, -4.7036541599e-04, -1.3077416482e-03, -1.6672033786e-03, -1.4762661175e-03, -8.4147811539e-04, 2.7738939561e-07, 7.6762822405e-04, 1.2273028724e-03, 1.2634551645e-03, 9.0369053242e-04, 2.9731541813e-04, -3.4300655947e-04, -8.1429454422e-04, -9.8635547032e-04, -8.3575791572e-04, -4.4260454834e-04, 4.5260964785e-05, 4.6595396291e-04, 6.9616608186e-04, 6.8594860888e-04, 4.6636610734e-04, 1.3045935867e-04, -2.0343933818e-04, -4.3223443720e-04, -4.9889658282e-04, -4.0473432259e-04, -2.0134275495e-04, 3.2646384841e-05, 2.2048158078e-04, 3.1162746860e-04, 2.9408029820e-04, 1.9220907824e-04, 5.2883189241e-05, -7.3727467420e-05, -1.5132922457e-04, -1.6703059492e-04, -1.3107772706e-04, -6.8463602021e-05, -6.7878473685e-06, 3.4497674886e-05, 4.9576845997e-05, 4.5185423350e-05, 3.4427394725e-05, 2.8852559317e-05, 3.2501804643e-05, 4.0424005351e-05, 4.2018506980e-05, 2.7394018357e-05, -6.3558769649e-06, -5.1984134189e-05, -9.3681964513e-05, -1.1301037302e-04, -9.6833385579e-05, -4.3939078188e-05, 3.2594351448e-05, 1.0864156338e-04, 1.5703973904e-04, 1.5757142899e-04, 1.0518999200e-04, 1.3224229063e-05, -8.9968418149e-05, -1.7005204359e-04, -1.9846619690e-04, -1.6276390717e-04, -7.1763889632e-05, 4.6526009946e-05, 1.5374741510e-04, 2.1391892035e-04, 2.0573694330e-04, 1.3018327474e-04, 1.0716831436e-05, -1.1415692892e-04, -2.0352603975e-04, -2.2769494252e-04, -1.7818819071e-04, -7.0730850437e-05, 5.9834648368e-05, 1.7101401313e-04, 2.2667724152e-04, 2.0894342750e-04, 1.2398389600e-04, -1.5102288781e-07, -1.2290110020e-04, -2.0459240130e-04, -2.1938887370e-04, -1.6353239694e-04, -5.6226120270e-05, 6.7009643296e-05, 1.6619217297e-04, 2.0995211782e-04, 1.8552142260e-04, 1.0243507472e-04, -1.1112425508e-05, -1.1787995488e-04, -1.8386734509e-04, -1.8919946970e-04, -1.3410620435e-04, -3.8205509248e-05, 6.6461651596e-05, 1.4617440650e-04, 1.7643760861e-04, 1.4951040496e-04, 7.6246440808e-05, -1.8129808633e-05, -1.0270312117e-04, -1.5101640956e-04, -1.4934964209e-04, -1.0053938525e-04, -2.2307560149e-05, 5.9108947314e-05, 1.1775399574e-04, 1.3622472120e-04, 1.1078618684e-04, 5.1845248574e-05, -2.0125847225e-05, -8.1663421490e-05, -1.1394918918e-04, -1.0852865169e-04, -6.9387745654e-05, -1.0936020738e-05, 4.7211972902e-05, 8.6789838921e-05, 9.6586177750e-05, 7.5533778781e-05, 3.2364715456e-05, -1.7828767302e-05, -5.8817377470e-05, -7.8449213324e-05, -7.2191292521e-05, -4.3989648722e-05, -4.3730359405e-06, 3.3385412278e-05, 5.7673778846e-05, 6.2064674305e-05, 4.6904808404e-05, 1.8624563166e-05, -1.2819212068e-05, -3.7390701894e-05, -4.8135763069e-05, -4.3074923396e-05, -2.5343458669e-05, -1.7006388713e-06, 1.9957970084e-05, 3.3192776794e-05, 3.4879904022e-05, 2.5822264067e-05, 1.0051713891e-05, -6.8097583970e-06, -1.9498796775e-05, -2.4709562826e-05, -2.1872823851e-05, -1.2967391097e-05, -1.5489194400e-06, 8.5870451935e-06, 1.4625508257e-05, 1.5456810693e-05, 1.1742901607e-05, 5.4043393215e-06, -1.2106684715e-06, -6.1465540987e-06, -8.3769149819e-06, -7.9265738121e-06, -5.6154526234e-06, -2.5888580771e-06, 1.5285351601e-07, 2.0506176943e-06, 3.0331364055e-06, 3.3507594867e-06, 3.3154529085e-06, 3.0865492220e-06, 2.6008503148e-06, 1.6657960026e-06, 1.5305012946e-07, -1.8178711579e-06, -3.8113674775e-06, -5.1746726048e-06, -5.2774918022e-06, -3.7972395600e-06, -9.2524845800e-07, 2.6076065295e-06, 5.7198669808e-06, 7.3312741704e-06, 6.7557076311e-06, 3.9880051684e-06, -2.3217914137e-07, -4.6195373148e-06, -7.7498279814e-06, -8.5397349316e-06, -6.6328694656e-06, -2.5519376712e-06, 2.4447265932e-06, 6.7618588014e-06, 8.9906823687e-06, 8.3806677143e-06, 5.0982471835e-06, 1.8218599568e-07, -4.7919923096e-06, -8.2273091938e-06, -9.0282441787e-06, -6.9568946317e-06, -2.7048254700e-06, 2.3409427568e-06, 6.5571420669e-06, 8.6141827121e-06, 7.9013048001e-06, 4.7093340218e-06, 1.1627442659e-07, -4.3798891371e-06, -7.3548222401e-06, -7.9135163167e-06, -5.9608852219e-06, -2.2053023924e-06, 2.0969795263e-06, 5.5644054666e-06, 7.1366486888e-06, 6.3998627227e-06, 3.6907340115e-06, -4.4606083446e-08, -3.5803107470e-06, -5.8142893914e-06, -6.1122032640e-06, -4.4845653586e-06, -1.5488320135e-06, 1.6998388511e-06, 4.2252196029e-06, 5.2802839800e-06, 4.6259752774e-06, 2.5753423082e-06, -1.4025822243e-07, -2.6289938120e-06, -4.1302781766e-06, -4.2453153459e-06, -3.0373339266e-06, -9.7874111711e-07, 1.2271291662e-06, 2.8840042895e-06, 3.5205182605e-06, 3.0204430208e-06, 1.6308815038e-06, -1.4450444581e-07, -1.7241912059e-06, -2.6370405857e-06, -2.6598735509e-06, -1.8653214254e-06, -5.7271861677e-07, 7.7384700090e-07, 1.7553133763e-06, 2.1055536806e-06, 1.7792668521e-06, 9.4429490393e-07, -9.1808887328e-08, -9.9134817368e-07, -1.4941495247e-06, -1.4897836295e-06, -1.0354725084e-06, -3.1993213186e-07, 4.0960212352e-07, 9.3023613610e-07, 1.1091534301e-06, 9.3369997553e-07, 5.0066210178e-07, -2.6982996518e-08, -4.7835670298e-07, -7.2796837379e-07, -7.2806861891e-07, -5.1275397350e-07, -1.7633053598e-07, 1.6382572605e-07, 4.0622379033e-07, 4.9369250885e-07, 4.2402455251e-07, 2.4219414231e-07, 1.9374920887e-08, -1.7268922538e-07, -2.8330054933e-07, -2.9440377563e-07, -2.2028313557e-07, -9.7521323957e-08, 2.9950472396e-08, 1.2521437045e-07, 1.6784289288e-07, 1.5654245404e-07, 1.0553704815e-07, 3.7109737124e-08, -2.6585997378e-08, -6.9785214388e-08, -8.5993206240e-08, -7.7449406562e-08, -5.2221193673e-08, -2.0451046381e-08, 8.8714888403e-09, 2.9811802898e-08, 3.9943687057e-08, 3.9745334832e-08, 3.1534918180e-08, 1.8454427798e-08, 3.7555123983e-09, -9.6174168542e-09, -1.9292508290e-08, -2.3718628905e-08, -2.2416870221e-08, -1.6133664125e-08, -6.7479865873e-09, 3.1510738100e-09}
  COEFFICIENT_WIDTH 24
  QUANTIZATION Maximize_Dynamic_Range
  BESTPRECISION true
  FILTER_TYPE Decimation
  RATE_CHANGE_TYPE Fixed_Fractional
  INTERPOLATION_RATE 2
  DECIMATION_RATE 5
  NUMBER_CHANNELS 12
  NUMBER_PATHS 1
  SAMPLE_FREQUENCY 0.96
  CLOCK_FREQUENCY 125
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 25
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA subset_0/M_AXIS
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 48
} {
  S_AXIS fir_1/M_AXIS_DATA
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster:1.1 bcast_6 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 48
  M_TDATA_NUM_BYTES 8
  NUM_MI 6
  M00_TDATA_REMAP {tdata[23:16],tdata[39:32],tdata[47:40],tdata[55:48],16'b0000000000000000,tdata[7:0],tdata[15:8]}
  M01_TDATA_REMAP {tdata[87:80],tdata[103:96],tdata[111:104],tdata[119:112],16'b0000000000000000,tdata[71:64],tdata[79:72]}
  M02_TDATA_REMAP {tdata[151:144],tdata[167:160],tdata[175:168],tdata[183:176],16'b0000000000000000,tdata[135:128],tdata[143:136]}
  M03_TDATA_REMAP {tdata[215:208],tdata[231:224],tdata[239:232],tdata[247:240],16'b0000000000000000,tdata[199:192],tdata[207:200]}
  M04_TDATA_REMAP {tdata[279:272],tdata[295:288],tdata[303:296],tdata[311:304],16'b0000000000000000,tdata[263:256],tdata[271:264]}
  M05_TDATA_REMAP {tdata[343:336],tdata[359:352],tdata[367:360],tdata[375:368],16'b0000000000000000,tdata[327:320],tdata[335:328]}
} {
  S_AXIS conv_1/M_AXIS
  aclk /ps_0/FCLK_CLK0
  aresetn /rst_0/peripheral_aresetn
}

for {set i 0} {$i <= 5} {incr i} {

  # Create fifo_generator
  cell xilinx.com:ip:fifo_generator:13.1 fifo_generator_$i {
    PERFORMANCE_OPTIONS First_Word_Fall_Through
    INPUT_DATA_WIDTH 64
    INPUT_DEPTH 1024
    OUTPUT_DATA_WIDTH 32
    OUTPUT_DEPTH 2048
    READ_DATA_COUNT true
    READ_DATA_COUNT_WIDTH 12
  } {
    clk /ps_0/FCLK_CLK0
    srst slice_0/Dout
  }

  # Create axis_fifo
  cell pavel-demin:user:axis_fifo:1.0 fifo_[expr $i + 1] {
    S_AXIS_TDATA_WIDTH 64
    M_AXIS_TDATA_WIDTH 32
  } {
    S_AXIS bcast_6/M0${i}_AXIS
    FIFO_READ fifo_generator_$i/FIFO_READ
    FIFO_WRITE fifo_generator_$i/FIFO_WRITE
    aclk /ps_0/FCLK_CLK0
  }

  # Create axi_axis_reader
  cell pavel-demin:user:axi_axis_reader:1.0 reader_$i {
    AXI_DATA_WIDTH 32
  } {
    S_AXIS fifo_[expr $i + 1]/M_AXIS
    aclk /ps_0/FCLK_CLK0
    aresetn /rst_0/peripheral_aresetn
  }

}
