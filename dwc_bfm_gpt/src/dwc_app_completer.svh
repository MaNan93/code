//======================================================================
// dwc_app_completer.svh
//   A minimal "target completer" application: it drains inbound requests
//   from a TRGT1 receiver, services them against a sparse byte memory,
//   and pushes Completions back out on an XALI driver.
//
//   Non-Posted requests are completed through the Target Completion LUT
//   (Databook 4.1.4): the application stores trgt_lookup_id from the
//   inbound request and replays it on clienti_cpl_lookup_id, so it never
//   has to re-supply remote_req_id / cpl_byte_cnt / attr / addr / tid / tc.
//   Set use_cpl_lut = 0 to model TRGT_CPL_LUT_EN = 0 instead.
//======================================================================
class dwc_app_completer;

  dwc_trgt1_receiver          rx;
  dwc_xali_driver             tx;
  string                      name;

  bit                         use_cpl_lut   = 1;
  int unsigned                cpl_latency   = 4;   // clocks, request -> Cpl
  bit                         verbose       = 0;

  int unsigned                n_posted      = 0;
  int unsigned                n_completed   = 0;
  int unsigned                n_dropped     = 0;   // aborted / errored TLPs

  protected byte unsigned     mem[bit [63:0]];

  function new(dwc_trgt1_receiver rx, dwc_xali_driver tx,
               string name = "app_completer");
    this.rx   = rx;
    this.tx   = tx;
    this.name = name;
  endfunction

  function void poke(bit [63:0] a, byte unsigned d);
    mem[a] = d;
  endfunction

  function byte unsigned peek(bit [63:0] a);
    return mem.exists(a) ? mem[a] : 8'h00;
  endfunction

  task automatic run();
    dwc_tlp_item  req;
    dwc_tlp_item  cpl;
    byte unsigned d[$];

    forever begin
      rx.out_mb.get(req);

      // Errored TLPs must not be serviced.  Credit policy per Table 3-43:
      //   tlp_abort  -> credit MUST be returned
      //   dllp_abort -> credit need not be returned
      if (req.tlp_abort || req.dllp_abort) begin
        n_dropped++;
        continue;
      end

      case (req.fc())
        FC_P: begin                      // MWr / MsgD: absorb, no response
          foreach (req.payload[i])
            mem[req.addr + i] = req.payload[i];
          n_posted++;
        end

        FC_NP: begin                     // MRd / IORd / CfgRd: complete it
          repeat (cpl_latency) @(rx.vif.scb);
          d.delete();
          for (int unsigned i = 0; i < req.byte_len; i++)
            d.push_back(peek(req.addr + i));

          if (use_cpl_lut) begin
            cpl = dwc_tlp_item::cpld_via_lut(req.lookup_id, d);
          end
          else begin
            cpl               = new();
            cpl.tlp_type      = DWC_TLP_CPLD;
            cpl.fmt           = 3'b010;
            cpl.payload       = d;
            cpl.byte_len      = 13'(d.size());
            cpl.addr_align_en = 1'b0;             // never for Completions
            cpl.req_id        = req.req_id;       // remote_req_id
            cpl.tag           = req.tag;
            cpl.tc            = req.tc;
            cpl.attr          = req.attr;
            cpl.cpl_byte_cnt  = 13'(d.size());
            // Cpl lower address bits [6:0] come from the DWORD-aligned
            // address plus FBE of the original request (Databook 4.1.3 note).
            cpl.addr          = req.addr;
            cpl.byte_en       = cpl.calc_byte_en();
          end

          cpl.func_num     = req.func_num;
          cpl.vfunc_num    = req.vfunc_num;
          cpl.vfunc_active = req.vfunc_active;
          tx.send(cpl);
          n_completed++;
          if (verbose)
            $display("[%0t] %s -> Cpl for lookup_id=%0d (%0d bytes)",
                     $time, name, req.lookup_id, d.size());
        end

        default: n_dropped++;            // inbound Cpl: nothing to do here
      endcase
    end
  endtask

  function void report();
    $display("%s: posted=%0d completed=%0d dropped=%0d",
             name, n_posted, n_completed, n_dropped);
  endfunction

endclass : dwc_app_completer
