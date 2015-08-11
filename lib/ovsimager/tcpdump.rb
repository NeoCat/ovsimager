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
          dump = IO.popen("exec #{nscmd}tcpdump -v -l -n -nn -i #{iface} \\( icmp or udp port 4789 \\) and greater #{SIZE} 2>&1", "r")
          puts dump.gets
          time_end = Time.now + 5
          req_from = req_to = rep_from = rep_to = nil
          vxlan_from = vxlan_to = nil
          vxlan_cap = false
          vxlan_line = 0
          while (waitmax = time_end - Time.now) > 0 do
            rs, ws, = IO.select([dump], [], [], waitmax)
            break unless rs
            if r = rs[0]
              msg = r.gets
              break unless msg
              # puts msg
              if msg.match(/([\da-f\.:]+)\.\d+ > ([\da-f\.:]+)\.\d+: VXLAN/)
                vxlan_from = $1
                vxlan_to = $2
                vxlan_line = 3
              elsif msg.match(/length #{SIZE+8}/) &&
                  msg.match(/([\da-f\.:]+) > ([\da-f\.:]+): ICMP echo (request|reply)/)
                if $3 == 'request'
                  req_from = $1
                  req_to = $2
                else
                  rep_from = $1
                  rep_to = $2
                end
                if vxlan_line > 0
                  if $3 == 'request'
                    vxlan_cap = [vxlan_from, vxlan_to]
                  else
                    vxlan_cap = [vxlan_to, vxlan_from]
                  end
                end
                break if req_from && req_to && rep_from && rep_to
              end
              vxlan_line -= 1 if vxlan_line > 0
            end
          end
          puts "Killing tcpdump(#{dump.pid}) on interface #{iface}."
          Process.kill('TERM', dump.pid)
          dump.close
          result[iface] = [req_from, req_to, rep_from, rep_to, {}]
          result[iface][4][:vxlan] = vxlan_cap if vxlan_cap
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
