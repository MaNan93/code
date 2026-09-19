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
    int unsigned payload_size;
    byte unsigned payload[BFM_MAX_PAYLOAD_BYTES];
  } trgt_packet_t;

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

  function automatic void protocol_error(input string s);
    error_count++; $error("DWC_PCIE_NATIVE_BFM: %s",s);
  endfunction

  task automatic drive_xali_idle();
    client0_addr_align_en<=0; client0_tlp_byte_en<='0;
    client0_remote_req_id<='0; client0_cpl_byte_cnt<='0;
    client0_tlp_tc<='0; client0_tlp_attr<='0;
    client0_cpl_status<='0; client0_cpl_bcm<=0;
    client0_tlp_dv<=0; client0_tlp_eot<=0; client0_tlp_bad_eot<=0;
    client0_tlp_hv<=0; client0_tlp_fmt<='0; client0_tlp_type<='0;
    client0_tlp_td<=0; client0_tlp_ep<=0; client0_tlp_byte_len<='0;
    client0_tlp_addr<='0; client0_tlp_tid<='0; client0_tlp_data<='0;
    client0_tlp_func_num<='0;
  endtask

  task automatic drive_xali_header(input xali_header_t h);
    client0_addr_align_en<=h.addr_align_en; client0_tlp_byte_en<=h.byte_en;
    client0_remote_req_id<=h.remote_req_id; client0_cpl_byte_cnt<=h.cpl_byte_cnt;
    client0_tlp_tc<=h.tc; client0_tlp_attr<=h.attr;
    client0_cpl_status<=h.cpl_status; client0_cpl_bcm<=h.cpl_bcm;
    client0_tlp_fmt<=h.fmt; client0_tlp_type<=h.tlp_type;
    client0_tlp_td<=h.td; client0_tlp_ep<=h.ep;
    client0_tlp_byte_len<=h.byte_len; client0_tlp_addr<=h.addr;
    client0_tlp_tid<=h.tid; client0_tlp_func_num<=h.func_num;
  endtask

  task automatic init();
    drive_xali_idle(); trgt1_radm_halt<=0; trgt1_radm_pkt_halt<='0;
    xali_rx_queue.delete(); trgt_rx_queue.delete();
    error_count=0; xali_packet_count=0; trgt_packet_count=0;
    checker_enable=1;
  endtask

  task automatic wait_reset_release();
    while (core_rst_n !== 1'b1) @(posedge core_clk);
  endtask

  task automatic send_xali(input xali_header_t h,
      input byte unsigned payload[], input bit bad_eot=0);
    int off,lane,n,timeout; logic [DATA_WIDTH-1:0] beat;
    if (core_rst_n !== 1) wait_reset_release();
    if (payload.size()>BFM_MAX_PAYLOAD_BYTES) $fatal(1,"payload too large");
    if (h.fmt[1] != (payload.size()!=0))
      protocol_error("XALI Fmt data bit disagrees with payload presence");
    if (payload.size()==0) begin
      @(negedge core_clk); drive_xali_header(h);
      client0_tlp_hv<=1; client0_tlp_dv<=0; client0_tlp_eot<=1;
      client0_tlp_bad_eot<=bad_eot; timeout=0;
      do begin @(posedge core_clk);
        if (++timeout>BFM_XALI_HALT_TIMEOUT_CYCLES) $fatal(1,"XALI halt timeout");
      end while (xadm_client0_halt!==0);
    end else begin
      off=0;
      while (off<payload.size()) begin
        beat='0; n=payload.size()-off; if(n>BYTE_LANES)n=BYTE_LANES;
        for(lane=0;lane<n;lane++) beat[lane*8+:8]=payload[off+lane];
        @(negedge core_clk); drive_xali_header(h); client0_tlp_data<=beat;
        client0_tlp_hv<=(off==0); client0_tlp_dv<=1;
        client0_tlp_eot<=(off+n==payload.size());
        client0_tlp_bad_eot<=bad_eot&&(off+n==payload.size()); timeout=0;
        do begin @(posedge core_clk);
          if(++timeout>BFM_XALI_HALT_TIMEOUT_CYCLES)$fatal(1,"XALI halt timeout");
        end while(xadm_client0_halt!==0);
        off+=n;
      end
    end
    @(negedge core_clk); drive_xali_idle();
  endtask

  task automatic set_trgt_halt(input bit halt);
    @(negedge core_clk); trgt1_radm_halt<=halt;
  endtask
  task automatic set_trgt_packet_halt(input logic[2:0] mask);
    @(negedge core_clk); trgt1_radm_pkt_halt<=mask;
  endtask
  task automatic get_xali_packet(output xali_packet_t p);
    wait(xali_rx_queue.size()); p=xali_rx_queue.pop_front();
  endtask
  task automatic get_trgt_packet(output trgt_packet_t p);
    wait(trgt_rx_queue.size()); p=trgt_rx_queue.pop_front();
  endtask

  task automatic sample_trgt_header(output trgt_header_t h);
    h.fmt=radm_trgt1_fmt; h.tlp_type=radm_trgt1_type; h.tc=radm_trgt1_tc;
    h.attr=radm_trgt1_attr; h.reqid=radm_trgt1_reqid; h.tag=radm_trgt1_tag;
    h.func_num=radm_trgt1_func_num; h.td=radm_trgt1_td;
    h.poisoned=radm_trgt1_poisoned; h.dw_len=radm_trgt1_dw_len;
    h.first_be=radm_trgt1_first_be; h.last_be=radm_trgt1_last_be;
    h.addr=radm_trgt1_addr; h.cpl_status=radm_trgt1_cpl_status;
    h.bcm=radm_trgt1_bcm; h.byte_cnt=radm_trgt1_byte_cnt;
    h.cmpltr_id=radm_trgt1_cmpltr_id;
  endtask

  task automatic run_xali_monitor();
    xali_packet_t p; bit active; int count,lane,n;
    active=0;
    forever begin @(posedge core_clk);
      if(!core_rst_n) active=0;
      else if(!xadm_client0_halt) begin
        if(client0_tlp_hv) begin
          if(checker_enable&&active)protocol_error("XALI HV before EOT");
          p.header='{client0_addr_align_en,client0_tlp_byte_en,
            client0_remote_req_id,client0_cpl_byte_cnt,client0_tlp_tc,
            client0_tlp_attr,client0_cpl_status,client0_cpl_bcm,
            client0_tlp_fmt,client0_tlp_type,client0_tlp_td,client0_tlp_ep,
            client0_tlp_byte_len,client0_tlp_addr,client0_tlp_tid,
            client0_tlp_func_num};
          p.bad_eot=0; p.payload_size=0; count=0; active=1;
        end
        if(client0_tlp_dv&&active) begin
          n=p.header.byte_len-count; if(n>BYTE_LANES)n=BYTE_LANES;if(n<0)n=0;
          for(lane=0;lane<n;lane++) if(count<BFM_MAX_PAYLOAD_BYTES)
            p.payload[count++]=client0_tlp_data[lane*8+:8];
        end
        if(checker_enable&&client0_tlp_bad_eot&&!client0_tlp_eot)
          protocol_error("XALI bad_eot outside EOT");
        if(client0_tlp_eot&&(client0_tlp_hv||client0_tlp_dv)) begin
          p.bad_eot=client0_tlp_bad_eot;p.payload_size=count;
          if(xali_rx_queue.size()<BFM_RX_QUEUE_DEPTH)xali_rx_queue.push_back(p);
          else protocol_error("XALI queue overflow");
          xali_packet_count++;active=0;
        end
      end
    end
  endtask

  task automatic run_trgt_monitor();
    trgt_packet_t p; bit active,prev_halt,accept;
    int left,count,expected,lane,b;
    active=0;prev_halt=0;left=0;
    forever begin @(posedge core_clk);
      if(!core_rst_n)begin active=0;prev_halt=0;left=0;end
      else begin
        if(trgt1_radm_halt&&!prev_halt)left=BFM_TRGT_HALT_LATENCY_CYCLES;
        accept=!trgt1_radm_halt||(left>0);
        if(trgt1_radm_halt&&left>0)left--; prev_halt=trgt1_radm_halt;
        if(accept) begin
          if(radm_trgt1_hv) begin
            if(checker_enable&&active)protocol_error("RTRGT1 HV before EOT");
            sample_trgt_header(p.header);p.tlp_abort=0;p.dllp_abort=0;
            p.ecrc_err=0;p.payload_size=0;count=0;
            expected=p.header.fmt[1]?decode_dw_length(p.header.dw_len)*4:0;
            active=1;
          end
          if(radm_trgt1_dv&&active)begin
            if(checker_enable&&!dwen_is_legal(radm_trgt1_dwen))
              protocol_error("RTRGT1 illegal dwen encoding");
            for(lane=0;lane<DWORD_LANES;lane++)if(radm_trgt1_dwen[lane])
              for(b=0;b<4;b++)begin
                if(count<BFM_MAX_PAYLOAD_BYTES&&count<expected)
                  p.payload[count]=radm_trgt1_data[lane*32+b*8+:8];
                count++;
              end
          end
          if(checker_enable&&(radm_trgt1_tlp_abort||radm_trgt1_dllp_abort)
              &&!radm_trgt1_eot)protocol_error("RTRGT1 abort outside EOT");
          if(radm_trgt1_eot&&(radm_trgt1_hv||radm_trgt1_dv))begin
            p.tlp_abort=radm_trgt1_tlp_abort;p.dllp_abort=radm_trgt1_dllp_abort;
            p.ecrc_err=radm_trgt1_ecrc_err;
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

  task automatic start();
    if(!monitors_started)begin monitors_started=1;
      fork run_xali_monitor();run_trgt_monitor();join_none
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
