`timescale 1ns/1ps

// Common traditional XALI0/RTRGT1 BFM for DWC PCIe 5.40a--6.60a.
// Application-side model; all tasks live in this interface; no class.
// Version/configuration-specific optional ports are intentionally excluded.
interface dwc_pcie_native_common_bfm #(
  parameter int DATA_WIDTH = 256,
  parameter int TAG_WIDTH = 10,
  parameter int ATTR_WIDTH = 3,
  parameter int FUNC_NUM_WIDTH = 3,
  parameter int BFM_MAX_PAYLOAD_BYTES = 4096,
  parameter int BFM_XALI_HALT_TIMEOUT_CYCLES = 10000,
  parameter int BFM_TRGT_HALT_LATENCY_CYCLES = 4,
  parameter int BFM_RX_QUEUE_DEPTH = 64
) (input logic core_clk, input logic core_rst_n);

  localparam int DWORD_LANES = DATA_WIDTH/32;
  localparam int BYTE_LANES  = DATA_WIDTH/8;

  // XALI0: application -> controller
  logic client0_addr_align_en;
  logic [7:0] client0_tlp_byte_en;
  logic [15:0] client0_remote_req_id;
  logic [11:0] client0_cpl_byte_cnt;
  logic [2:0] client0_tlp_tc;
  logic [ATTR_WIDTH-1:0] client0_tlp_attr;
  logic [2:0] client0_cpl_status;
  logic client0_cpl_bcm;
  logic client0_tlp_dv, client0_tlp_eot, client0_tlp_bad_eot;
  logic client0_tlp_hv;
  logic [1:0] client0_tlp_fmt;
  logic [4:0] client0_tlp_type;
  logic client0_tlp_td, client0_tlp_ep;
  logic [12:0] client0_tlp_byte_len;
  logic [63:0] client0_tlp_addr;
  logic [TAG_WIDTH-1:0] client0_tlp_tid;
  logic [DATA_WIDTH-1:0] client0_tlp_data;
  logic [FUNC_NUM_WIDTH-1:0] client0_tlp_func_num;
  logic xadm_client0_halt;

  // RTRGT1: controller -> application
  logic radm_trgt1_hv, radm_trgt1_dv, radm_trgt1_eot;
  logic radm_trgt1_tlp_abort, radm_trgt1_dllp_abort;
  logic radm_trgt1_ecrc_err;
  logic [DATA_WIDTH-1:0] radm_trgt1_data;
  logic [DWORD_LANES-1:0] radm_trgt1_dwen;
  logic [1:0] radm_trgt1_fmt;
  logic [4:0] radm_trgt1_type;
  logic [2:0] radm_trgt1_tc;
  logic [ATTR_WIDTH-1:0] radm_trgt1_attr;
  logic [15:0] radm_trgt1_reqid;
  logic [TAG_WIDTH-1:0] radm_trgt1_tag;
  logic [FUNC_NUM_WIDTH-1:0] radm_trgt1_func_num;
  logic radm_trgt1_td, radm_trgt1_poisoned;
  logic [9:0] radm_trgt1_dw_len;
  logic [3:0] radm_trgt1_first_be, radm_trgt1_last_be;
  logic [63:0] radm_trgt1_addr;
  logic [2:0] radm_trgt1_cpl_status;
  logic radm_trgt1_bcm;
  logic [11:0] radm_trgt1_byte_cnt;
  logic [15:0] radm_trgt1_cmpltr_id;
  logic trgt1_radm_halt;
  logic [2:0] trgt1_radm_pkt_halt; // [0]=P, [1]=NP, [2]=CPL
  logic [2:0] radm_grant_tlp_type;

  // Drive and sample through separate clocking blocks to avoid DUT/BFM races.
  clocking mcb @(posedge core_clk);
    default input #1step output #0;
    input  xadm_client0_halt;
    output client0_addr_align_en, client0_tlp_byte_en;
    output client0_remote_req_id, client0_cpl_byte_cnt;
    output client0_tlp_tc, client0_tlp_attr, client0_cpl_status;
    output client0_cpl_bcm, client0_tlp_dv, client0_tlp_eot;
    output client0_tlp_bad_eot, client0_tlp_hv, client0_tlp_fmt;
    output client0_tlp_type, client0_tlp_td, client0_tlp_ep;
    output client0_tlp_byte_len, client0_tlp_addr, client0_tlp_tid;
    output client0_tlp_data, client0_tlp_func_num;
    output trgt1_radm_halt, trgt1_radm_pkt_halt;
  endclocking

  clocking pcb @(posedge core_clk);
    default input #1step output #0;
    input client0_addr_align_en, client0_tlp_byte_en;
    input client0_remote_req_id, client0_cpl_byte_cnt, client0_tlp_tc;
    input client0_tlp_attr, client0_cpl_status, client0_cpl_bcm;
    input client0_tlp_dv, client0_tlp_eot, client0_tlp_bad_eot;
    input client0_tlp_hv, client0_tlp_fmt, client0_tlp_type;
    input client0_tlp_td, client0_tlp_ep, client0_tlp_byte_len;
    input client0_tlp_addr, client0_tlp_tid, client0_tlp_data;
    input client0_tlp_func_num, xadm_client0_halt;
    input radm_trgt1_hv, radm_trgt1_dv, radm_trgt1_eot;
    input radm_trgt1_tlp_abort, radm_trgt1_dllp_abort;
    input radm_trgt1_ecrc_err, radm_trgt1_data, radm_trgt1_dwen;
    input radm_trgt1_fmt, radm_trgt1_type, radm_trgt1_tc;
    input radm_trgt1_attr, radm_trgt1_reqid, radm_trgt1_tag;
    input radm_trgt1_func_num, radm_trgt1_td, radm_trgt1_poisoned;
    input radm_trgt1_dw_len, radm_trgt1_first_be, radm_trgt1_last_be;
    input radm_trgt1_addr, radm_trgt1_cpl_status, radm_trgt1_bcm;
    input radm_trgt1_byte_cnt, radm_trgt1_cmpltr_id;
    input trgt1_radm_halt, trgt1_radm_pkt_halt, radm_grant_tlp_type;
  endclocking

  typedef struct {
    logic addr_align_en;
    logic [7:0] byte_en;
    logic [15:0] remote_req_id;
    logic [11:0] cpl_byte_cnt;
    logic [2:0] tc;
    logic [ATTR_WIDTH-1:0] attr;
    logic [2:0] cpl_status;
    logic cpl_bcm;
    logic [1:0] fmt;
    logic [4:0] tlp_type;
    logic td, ep;
    logic [12:0] byte_len;
    logic [63:0] addr;
    logic [TAG_WIDTH-1:0] tid;
    logic [FUNC_NUM_WIDTH-1:0] func_num;
  } xali_header_t;

  typedef struct {
    logic [1:0] fmt;
    logic [4:0] tlp_type;
    logic [2:0] tc;
    logic [ATTR_WIDTH-1:0] attr;
    logic [15:0] reqid;
    logic [TAG_WIDTH-1:0] tag;
    logic [FUNC_NUM_WIDTH-1:0] func_num;
    logic td, poisoned;
    logic [9:0] dw_len;
    logic [3:0] first_be, last_be;
    logic [63:0] addr;
    logic [2:0] cpl_status;
    logic bcm;
    logic [11:0] byte_cnt;
    logic [15:0] cmpltr_id;
  } trgt_header_t;

  typedef struct {
    xali_header_t header;
    bit bad_eot;
    int unsigned payload_size;
    byte unsigned payload[BFM_MAX_PAYLOAD_BYTES];
  } xali_packet_t;

  typedef struct {
    trgt_header_t header;
    bit tlp_abort, dllp_abort, ecrc_err;
    bit payload_valid;
    int unsigned payload_size;
    byte unsigned payload[BFM_MAX_PAYLOAD_BYTES];
  } trgt_packet_t;

  typedef struct packed {
    logic addr_align_en;
    logic [7:0] byte_en;
    logic [15:0] remote_req_id;
    logic [11:0] cpl_byte_cnt;
    logic [2:0] tc;
    logic [ATTR_WIDTH-1:0] attr;
    logic [2:0] cpl_status;
    logic cpl_bcm, dv, eot, bad_eot, hv;
    logic [1:0] fmt;
    logic [4:0] tlp_type;
    logic td, ep;
    logic [12:0] byte_len;
    logic [63:0] addr;
    logic [TAG_WIDTH-1:0] tid;
    logic [DATA_WIDTH-1:0] data;
    logic [FUNC_NUM_WIDTH-1:0] func_num;
  } xali_snapshot_t;

  typedef struct packed {
    logic hv, dv, eot, tlp_abort, dllp_abort, ecrc_err;
    logic [DATA_WIDTH-1:0] data;
    logic [DWORD_LANES-1:0] dwen;
    logic [1:0] fmt;
    logic [4:0] tlp_type;
    logic [2:0] tc;
    logic [ATTR_WIDTH-1:0] attr;
    logic [15:0] reqid;
    logic [TAG_WIDTH-1:0] tag;
    logic [FUNC_NUM_WIDTH-1:0] func_num;
    logic td, poisoned;
    logic [9:0] dw_len;
    logic [3:0] first_be, last_be;
    logic [63:0] addr;
    logic [2:0] cpl_status;
    logic bcm;
    logic [11:0] byte_cnt;
    logic [15:0] cmpltr_id;
  } trgt_snapshot_t;

  xali_packet_t xali_rx_queue[$];
  trgt_packet_t trgt_rx_queue[$];
  int unsigned error_count, xali_packet_count, trgt_packet_count;
  bit checker_enable, monitors_started;

  function automatic int unsigned decode_dw_length(input logic [9:0] n);
    return (n == 0) ? 1024 : int'(n);
  endfunction

  function automatic bit dwen_is_legal(input logic [DWORD_LANES-1:0] n);
    logic [DWORD_LANES:0] x;
    x = {1'b0,n};
    return (n != 0) && ((x & (x+1'b1)) == 0);
  endfunction

  function automatic bit is_completion(input logic [4:0] tlp_type);
    return tlp_type == 5'b01010;
  endfunction

  function automatic bit is_message(input logic [4:0] tlp_type);
    return tlp_type[4:3] == 2'b10;
  endfunction

  function automatic logic [3:0] low_mask(input int unsigned count);
    logic [4:0] tmp;
    tmp = (5'b00001 << count) - 1'b1;
    return tmp[3:0];
  endfunction

  function automatic void protocol_error(input string s);
    error_count++; $error("DWC_PCIE_NATIVE_BFM: %s",s);
  endfunction

  task automatic drive_xali_idle();
    mcb.client0_addr_align_en<=0; mcb.client0_tlp_byte_en<='0;
    mcb.client0_remote_req_id<='0; mcb.client0_cpl_byte_cnt<='0;
    mcb.client0_tlp_tc<='0; mcb.client0_tlp_attr<='0;
    mcb.client0_cpl_status<='0; mcb.client0_cpl_bcm<=0;
    mcb.client0_tlp_dv<=0; mcb.client0_tlp_eot<=0;
    mcb.client0_tlp_bad_eot<=0; mcb.client0_tlp_hv<=0;
    mcb.client0_tlp_fmt<='0; mcb.client0_tlp_type<='0;
    mcb.client0_tlp_td<=0; mcb.client0_tlp_ep<=0;
    mcb.client0_tlp_byte_len<='0; mcb.client0_tlp_addr<='0;
    mcb.client0_tlp_tid<='0; mcb.client0_tlp_data<='0;
    mcb.client0_tlp_func_num<='0;
  endtask

  task automatic drive_xali_header(input xali_header_t h);
    mcb.client0_addr_align_en<=h.addr_align_en;
    mcb.client0_tlp_byte_en<=h.byte_en;
    mcb.client0_remote_req_id<=h.remote_req_id;
    mcb.client0_cpl_byte_cnt<=h.cpl_byte_cnt;
    mcb.client0_tlp_tc<=h.tc; mcb.client0_tlp_attr<=h.attr;
    mcb.client0_cpl_status<=h.cpl_status; mcb.client0_cpl_bcm<=h.cpl_bcm;
    mcb.client0_tlp_fmt<=h.fmt; mcb.client0_tlp_type<=h.tlp_type;
    mcb.client0_tlp_td<=h.td; mcb.client0_tlp_ep<=h.ep;
    mcb.client0_tlp_byte_len<=h.byte_len; mcb.client0_tlp_addr<=h.addr;
    mcb.client0_tlp_tid<=h.tid; mcb.client0_tlp_func_num<=h.func_num;
  endtask

  task automatic init();
    drive_xali_idle(); mcb.trgt1_radm_halt<=0; mcb.trgt1_radm_pkt_halt<='0;
    xali_rx_queue.delete(); trgt_rx_queue.delete();
    error_count=0; xali_packet_count=0; trgt_packet_count=0;
    checker_enable=1;
  endtask

  task automatic wait_reset_release();
    while (core_rst_n !== 1'b1) @(pcb);
  endtask

  // h.addr and h.byte_len describe the logical byte request. Unless raw_format
  // is selected, this task performs the section 4.1.3 address formatting.
  task automatic send_xali(input xali_header_t h,
      input byte unsigned payload[], input bit bad_eot=0,
      input bit raw_format=0);
    xali_header_t wh;
    byte unsigned wire_payload[];
    int off,lane,n,timeout,addr_off,logical_len,wire_len;
    int first_count,last_count;
    logic [DATA_WIDTH-1:0] beat;
    if (core_rst_n !== 1) wait_reset_release();
    if (payload.size()>BFM_MAX_PAYLOAD_BYTES) $fatal(1,"payload too large");
    if (h.fmt[1] != (payload.size()!=0))
      protocol_error("XALI Fmt data bit disagrees with payload presence");
    if(is_message(h.tlp_type)&&!raw_format)
      $fatal(1,"Message TLP requires raw_format because byte_en/address carry message fields");

    wh = h;
    logical_len = (payload.size()!=0) ? payload.size() : h.byte_len;
    if (raw_format) begin
      wire_payload = new[payload.size()];
      foreach(payload[i]) wire_payload[i]=payload[i];
    end else if (h.addr_align_en) begin
      if(is_completion(h.tlp_type))
        protocol_error("XALI address alignment must be off for Completions");
      if(h.td)
        protocol_error("XALI address alignment must be off for TLPs carrying ECRC (TD=1)");
      wh.byte_en='0;
      wh.byte_len=logical_len;
      wire_payload=new[payload.size()];
      foreach(payload[i]) wire_payload[i]=payload[i];
    end else begin
      addr_off=h.addr[1:0];
      wire_len=((addr_off+logical_len+3)/4)*4;
      wh.addr={h.addr[63:2],2'b00};
      wh.byte_len=wire_len;
      first_count=(logical_len < (4-addr_off)) ? logical_len : (4-addr_off);
      wh.byte_en[3:0]=low_mask(first_count)<<addr_off;
      if(addr_off+logical_len<=4) wh.byte_en[7:4]=4'b0000;
      else begin
        last_count=(addr_off+logical_len)%4;
        if(last_count==0) last_count=4;
        wh.byte_en[7:4]=low_mask(last_count);
      end
      wire_payload=new[(payload.size()==0)?0:wire_len];
      foreach(wire_payload[i]) wire_payload[i]='0;
      foreach(payload[i]) wire_payload[addr_off+i]=payload[i];
    end

    if(wire_payload.size()>BFM_MAX_PAYLOAD_BYTES)
      $fatal(1,"formatted XALI payload exceeds BFM limit");

    if (wire_payload.size()==0) begin
      @(mcb); drive_xali_header(wh);
      mcb.client0_tlp_hv<=1; mcb.client0_tlp_dv<=0;
      mcb.client0_tlp_eot<=1; mcb.client0_tlp_bad_eot<=bad_eot;
      timeout=0;
      do begin @(mcb);
        if (++timeout>BFM_XALI_HALT_TIMEOUT_CYCLES) $fatal(1,"XALI halt timeout");
      end while (mcb.xadm_client0_halt!==0);
    end else begin
      off=0;
      while (off<wire_payload.size()) begin
        beat='0; n=wire_payload.size()-off; if(n>BYTE_LANES)n=BYTE_LANES;
        for(lane=0;lane<n;lane++) beat[lane*8+:8]=wire_payload[off+lane];
        @(mcb); drive_xali_header(wh); mcb.client0_tlp_data<=beat;
        mcb.client0_tlp_hv<=(off==0); mcb.client0_tlp_dv<=1;
        mcb.client0_tlp_eot<=(off+n==wire_payload.size());
        mcb.client0_tlp_bad_eot<=bad_eot&&(off+n==wire_payload.size());
        timeout=0;
        do begin @(mcb);
          if(++timeout>BFM_XALI_HALT_TIMEOUT_CYCLES)$fatal(1,"XALI halt timeout");
        end while(mcb.xadm_client0_halt!==0);
        off+=n;
      end
    end
    @(mcb); drive_xali_idle();
  endtask

  task automatic set_trgt_halt(input bit halt);
    @(mcb); mcb.trgt1_radm_halt<=halt;
  endtask
  task automatic set_trgt_packet_halt(input logic[2:0] mask);
    @(mcb); mcb.trgt1_radm_pkt_halt<=mask;
  endtask
  task automatic random_trgt_backpressure(input int unsigned cycles,
      input int unsigned halt_percent=20);
    if(halt_percent>100)$fatal(1,"halt_percent must be <= 100");
    repeat(cycles)begin
      @(mcb);mcb.trgt1_radm_halt<=($urandom_range(99,0)<halt_percent);
    end
    @(mcb);mcb.trgt1_radm_halt<=0;
  endtask
  task automatic get_xali_packet(output xali_packet_t p);
    wait(xali_rx_queue.size()); p=xali_rx_queue.pop_front();
  endtask
  task automatic get_trgt_packet(output trgt_packet_t p);
    wait(trgt_rx_queue.size()); p=trgt_rx_queue.pop_front();
  endtask

  task automatic sample_trgt_header(output trgt_header_t h);
    h.fmt=pcb.radm_trgt1_fmt; h.tlp_type=pcb.radm_trgt1_type;
    h.tc=pcb.radm_trgt1_tc; h.attr=pcb.radm_trgt1_attr;
    h.reqid=pcb.radm_trgt1_reqid; h.tag=pcb.radm_trgt1_tag;
    h.func_num=pcb.radm_trgt1_func_num; h.td=pcb.radm_trgt1_td;
    h.poisoned=pcb.radm_trgt1_poisoned; h.dw_len=pcb.radm_trgt1_dw_len;
    h.first_be=pcb.radm_trgt1_first_be; h.last_be=pcb.radm_trgt1_last_be;
    h.addr=pcb.radm_trgt1_addr; h.cpl_status=pcb.radm_trgt1_cpl_status;
    h.bcm=pcb.radm_trgt1_bcm; h.byte_cnt=pcb.radm_trgt1_byte_cnt;
    h.cmpltr_id=pcb.radm_trgt1_cmpltr_id;
  endtask

  task automatic sample_xali_snapshot(output xali_snapshot_t s);
    s='{pcb.client0_addr_align_en,pcb.client0_tlp_byte_en,
      pcb.client0_remote_req_id,pcb.client0_cpl_byte_cnt,pcb.client0_tlp_tc,
      pcb.client0_tlp_attr,pcb.client0_cpl_status,pcb.client0_cpl_bcm,
      pcb.client0_tlp_dv,pcb.client0_tlp_eot,pcb.client0_tlp_bad_eot,
      pcb.client0_tlp_hv,pcb.client0_tlp_fmt,pcb.client0_tlp_type,
      pcb.client0_tlp_td,pcb.client0_tlp_ep,pcb.client0_tlp_byte_len,
      pcb.client0_tlp_addr,pcb.client0_tlp_tid,pcb.client0_tlp_data,
      pcb.client0_tlp_func_num};
  endtask

  task automatic sample_trgt_snapshot(output trgt_snapshot_t s);
    s='{pcb.radm_trgt1_hv,pcb.radm_trgt1_dv,pcb.radm_trgt1_eot,
      pcb.radm_trgt1_tlp_abort,pcb.radm_trgt1_dllp_abort,
      pcb.radm_trgt1_ecrc_err,pcb.radm_trgt1_data,pcb.radm_trgt1_dwen,
      pcb.radm_trgt1_fmt,pcb.radm_trgt1_type,pcb.radm_trgt1_tc,
      pcb.radm_trgt1_attr,pcb.radm_trgt1_reqid,pcb.radm_trgt1_tag,
      pcb.radm_trgt1_func_num,pcb.radm_trgt1_td,pcb.radm_trgt1_poisoned,
      pcb.radm_trgt1_dw_len,pcb.radm_trgt1_first_be,
      pcb.radm_trgt1_last_be,pcb.radm_trgt1_addr,
      pcb.radm_trgt1_cpl_status,pcb.radm_trgt1_bcm,
      pcb.radm_trgt1_byte_cnt,pcb.radm_trgt1_cmpltr_id};
  endtask

  task automatic run_xali_monitor();
    xali_packet_t p; bit active; int count,lane,n;
    active=0;
    forever begin @(pcb);
      if(!core_rst_n) active=0;
      else if(!pcb.xadm_client0_halt) begin
        if(checker_enable&&active&&!pcb.client0_tlp_dv)
          protocol_error("XALI payload bubble while not halted");
        if(checker_enable&&pcb.client0_tlp_dv&&!active&&!pcb.client0_tlp_hv)
          protocol_error("XALI DV observed outside a TLP");
        if(pcb.client0_tlp_hv) begin
          if(checker_enable&&active)protocol_error("XALI HV before EOT");
          p.header='{pcb.client0_addr_align_en,pcb.client0_tlp_byte_en,
            pcb.client0_remote_req_id,pcb.client0_cpl_byte_cnt,
            pcb.client0_tlp_tc,pcb.client0_tlp_attr,pcb.client0_cpl_status,
            pcb.client0_cpl_bcm,pcb.client0_tlp_fmt,pcb.client0_tlp_type,
            pcb.client0_tlp_td,pcb.client0_tlp_ep,pcb.client0_tlp_byte_len,
            pcb.client0_tlp_addr,pcb.client0_tlp_tid,
            pcb.client0_tlp_func_num};
          if(checker_enable&&!pcb.client0_addr_align_en&&
              !is_message(pcb.client0_tlp_type)&&
              (pcb.client0_tlp_addr[1:0]!=0||pcb.client0_tlp_byte_len[1:0]!=0))
            protocol_error("XALI alignment-off address/byte_len is not DWORD aligned");
          if(checker_enable&&pcb.client0_addr_align_en&&
              pcb.client0_tlp_byte_en!=0)
            protocol_error("XALI byte_en must be zero with address alignment on");
          p.bad_eot=0; p.payload_size=0; count=0; active=1;
        end
        if(pcb.client0_tlp_dv&&active) begin
          n=p.header.byte_len-count; if(n>BYTE_LANES)n=BYTE_LANES;if(n<0)n=0;
          for(lane=0;lane<n;lane++) if(count<BFM_MAX_PAYLOAD_BYTES)
            p.payload[count++]=pcb.client0_tlp_data[lane*8+:8];
        end
        if(checker_enable&&pcb.client0_tlp_bad_eot&&!pcb.client0_tlp_eot)
          protocol_error("XALI bad_eot outside EOT");
        if(pcb.client0_tlp_eot&&(pcb.client0_tlp_hv||pcb.client0_tlp_dv)) begin
          p.bad_eot=pcb.client0_tlp_bad_eot;p.payload_size=count;
          if(xali_rx_queue.size()<BFM_RX_QUEUE_DEPTH)xali_rx_queue.push_back(p);
          else protocol_error("XALI queue overflow");
          xali_packet_count++;active=0;
        end
      end
    end
  endtask

  task automatic run_trgt_monitor();
    trgt_packet_t p;
    trgt_snapshot_t current_bus, frozen_bus;
    bit active,prev_halt,accept,frozen;
    int left,count,expected,lane,b;
    active=0;prev_halt=0;left=0;frozen=0;
    forever begin @(pcb);
      sample_trgt_snapshot(current_bus);
      if(!core_rst_n)begin active=0;prev_halt=0;left=0;frozen=0;end
      else begin
        if(pcb.trgt1_radm_halt&&!prev_halt)begin
          left=BFM_TRGT_HALT_LATENCY_CYCLES; frozen=0;
        end
        accept=!pcb.trgt1_radm_halt||(left>0);
        if(pcb.trgt1_radm_halt&&left>0)left--;
        if(pcb.trgt1_radm_halt&&left==0)begin
          if(!frozen)begin frozen_bus=current_bus;frozen=1;end
          else if(current_bus!==frozen_bus)begin
            protocol_error("RTRGT1 outputs changed beyond configured halt drain window");
            // Recover the unexpected advancing beat instead of silently dropping it.
            accept=pcb.radm_trgt1_hv||pcb.radm_trgt1_dv;
            frozen_bus=current_bus;
          end
        end else frozen=0;
        prev_halt=pcb.trgt1_radm_halt;
        if(accept) begin
          if(pcb.radm_trgt1_hv) begin
            if(checker_enable&&active)protocol_error("RTRGT1 HV before EOT");
            sample_trgt_header(p.header);p.tlp_abort=0;p.dllp_abort=0;
            p.ecrc_err=0;p.payload_valid=1;p.payload_size=0;count=0;
            expected=p.header.fmt[1]?decode_dw_length(p.header.dw_len)*4:0;
            active=1;
          end
          if(checker_enable&&pcb.radm_trgt1_dv&&!active&&!pcb.radm_trgt1_hv)
            protocol_error("RTRGT1 DV observed outside a TLP");
          // Databook L.1: dwen is unreliable on a DLLP-aborted EOT beat.
          if(pcb.radm_trgt1_dv&&active&&
              !(pcb.radm_trgt1_eot&&pcb.radm_trgt1_dllp_abort))begin
            if(checker_enable&&!dwen_is_legal(pcb.radm_trgt1_dwen))
              protocol_error("RTRGT1 illegal dwen encoding");
            for(lane=0;lane<DWORD_LANES;lane++)if(pcb.radm_trgt1_dwen[lane])
              for(b=0;b<4;b++)begin
                if(count<BFM_MAX_PAYLOAD_BYTES&&count<expected)
                  p.payload[count]=pcb.radm_trgt1_data[lane*32+b*8+:8];
                count++;
              end
          end
          if(checker_enable&&(pcb.radm_trgt1_tlp_abort||
              pcb.radm_trgt1_dllp_abort)&&!pcb.radm_trgt1_eot)
            protocol_error("RTRGT1 abort outside EOT");
          if(pcb.radm_trgt1_eot&&(pcb.radm_trgt1_hv||pcb.radm_trgt1_dv))begin
            p.tlp_abort=pcb.radm_trgt1_tlp_abort;
            p.dllp_abort=pcb.radm_trgt1_dllp_abort;
            p.ecrc_err=pcb.radm_trgt1_ecrc_err;
            if(p.dllp_abort)p.payload_valid=0;
            p.payload_size=(count>expected)?expected:count;
            if(checker_enable&&p.header.fmt[1]&&count<expected&&
                !p.tlp_abort&&!p.dllp_abort)protocol_error("RTRGT1 short payload");
            if(trgt_rx_queue.size()<BFM_RX_QUEUE_DEPTH)trgt_rx_queue.push_back(p);
            else protocol_error("RTRGT1 queue overflow");
            trgt_packet_count++;active=0;
          end
        end
      end
    end
  endtask

  task automatic run_xali_halt_checker();
    xali_snapshot_t current_bus, previous_bus;
    bit previous_halted_valid;
    previous_halted_valid=0;
    forever begin @(pcb);
      sample_xali_snapshot(current_bus);
      if(!core_rst_n) previous_halted_valid=0;
      else begin
        if(checker_enable&&previous_halted_valid&&pcb.xadm_client0_halt&&
            current_bus!==previous_bus)
          protocol_error("XALI signals changed while xadm_client0_halt asserted");
        previous_halted_valid=pcb.xadm_client0_halt&&
                              (pcb.client0_tlp_hv||pcb.client0_tlp_dv);
        previous_bus=current_bus;
      end
    end
  endtask

  task automatic start();
    if(!monitors_started)begin monitors_started=1;
      fork
        run_xali_monitor();
        run_trgt_monitor();
        run_xali_halt_checker();
      join_none
    end
  endtask

  initial begin
    if(DATA_WIDTH<32||DATA_WIDTH%32)$fatal(1,"DATA_WIDTH must be multiple of 32");
    monitors_started=0;init();
  end

  modport dut(
    input client0_addr_align_en,client0_tlp_byte_en,client0_remote_req_id,
      client0_cpl_byte_cnt,client0_tlp_tc,client0_tlp_attr,client0_cpl_status,
      client0_cpl_bcm,client0_tlp_dv,client0_tlp_eot,client0_tlp_bad_eot,
      client0_tlp_hv,client0_tlp_fmt,client0_tlp_type,client0_tlp_td,
      client0_tlp_ep,client0_tlp_byte_len,client0_tlp_addr,client0_tlp_tid,
      client0_tlp_data,client0_tlp_func_num,trgt1_radm_halt,
      trgt1_radm_pkt_halt,
    output xadm_client0_halt,radm_trgt1_hv,radm_trgt1_dv,radm_trgt1_eot,
      radm_trgt1_tlp_abort,radm_trgt1_dllp_abort,radm_trgt1_ecrc_err,
      radm_trgt1_data,radm_trgt1_dwen,radm_trgt1_fmt,radm_trgt1_type,
      radm_trgt1_tc,radm_trgt1_attr,radm_trgt1_reqid,radm_trgt1_tag,
      radm_trgt1_func_num,radm_trgt1_td,radm_trgt1_poisoned,
      radm_trgt1_dw_len,radm_trgt1_first_be,radm_trgt1_last_be,
      radm_trgt1_addr,radm_trgt1_cpl_status,radm_trgt1_bcm,
      radm_trgt1_byte_cnt,radm_trgt1_cmpltr_id,radm_grant_tlp_type);
endinterface
