require 'time'

module OVSImager
  class TcpDump
    SIZE = 400
    def initialize(ping=false, from=nil, to=nil)
      throw 'must be root.' if Process::UID.eid != 0
      @ping = ping
      @from = from
      @to = to
    end

    def test(ifaces)
      result = {}
      ping = nil
      if @ping
        puts "Sending ping from #{@from||'default'} to #{@to} ..."
        ping = IO.popen("ping -s #{SIZE} -c 15 #{@from?'-I '+@from:''} #{@to} >/dev/null", "r")
      end

      threads = ifaces.map do |(iface, iref)|
        Thread.new do
          Thread.current[:iface] = iface
          ns = iref[:ns]
          nscmd = ns == :root ? '' : "ip netns exec #{ns} "
          dump = IO.popen("exec #{nscmd}tcpdump -v -l -n -nn -i #{iface} \\( icmp or udp port 4789 or proto gre \\) and greater #{SIZE} 2>&1", "r")
          puts dump.gets
          time_end = Time.now + 5
          req_from = req_to = rep_from = rep_to = nil
          cap_from = cap_to = cap_type = cap_id = nil
          cap = false
          cap_line = 0
          while (waitmax = time_end - Time.now) > 0 do
            rs, ws, = IO.select([dump], [], [], waitmax)
            break unless rs
            if r = rs[0]
              msg = r.gets
              break unless msg
              # puts msg
              if msg.match(/([\da-f\.:]+)\.\d+ > ([\da-f\.:]+)\.\d+: (VXLAN).*vni (\d+)/) ||
                  msg.match(/([\da-f\.:]+) > ([\da-f\.:]+): (GRE).*key=([\da-f]+)/)
                cap_from = $1
                cap_to = $2
                cap_type = $3
                cap_id = $4
                cap_line = 3
              elsif msg.match(/length #{SIZE+8}/) &&
                  msg.match(/([\da-f\.:]+) > ([\da-f\.:]+): ICMP echo (request|reply)/)
                if $3 == 'request'
                  req_from = $1
                  req_to = $2
                else
                  rep_from = $1
                  rep_to = $2
                end
                if cap_line > 0
                  if $3 == 'request'
                    cap = [cap_from, cap_to, cap_type, cap_id]
                  else
                    cap = [cap_to, cap_from, cap_type, cap_id]
                  end
                end
                break if req_from && req_to && rep_from && rep_to
              end
              cap_line -= 1 if cap_line > 0
            end
          end
          puts "Killing tcpdump(#{dump.pid}) on interface #{iface}."
          Process.kill('TERM', dump.pid)
          dump.close
          result[iface] = [req_from, req_to, rep_from, rep_to, {}]
          result[iface][4][:cap] = cap if cap
        end
      end
      threads.each {|th| th.join(10)}
      if @ping
        Process.kill('TERM', ping.pid)
        ping.close
      end
      return result
    end
  end
end
