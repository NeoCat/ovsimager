require 'optparse'
require_relative 'ovsvs'
require_relative 'linuxbridge'
require_relative 'ipnetns'
require_relative 'tcpdump'
require_relative 'dotwriter'

module OVSImager
  class OVSImager
    DOT_FILENAME = 'interfaces.dot'
    PNG_FILENAME = 'interfaces.png'

    def initialize(dump_mode=false, ping_from=nil, ping_to=nil)
      @netns = IPNetNS.new
      @ifaces = @netns.ifaces_hash
      @linbr = LinuxBridge.new
      @ovsvs = OVSVS.new

      @dotwriter = DotWriter.new(DOT_FILENAME)

      @dump_mode = dump_mode
      @mark = {}
      @dump_result = {}
      @ping_from = ping_from
      @ping_to = ping_to
      @done = {'lo' => true}
    end

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: #$0 [options]"
        opts.on("-d", "--dump",
                "enable dump mode (trace ping -s 400 packets)") do
          @dump_mode = true
        end
        opts.on("-f ADDRESS", "--from ADDRESS",
                "send ping from specified address") do |v|
          @ping_from = v
        end
        opts.on("-t ADDRESS", "--to ADDRESS",
                "send ping to specified address") do |v|
          @ping_to = v
        end
      end.parse!
    end

    def execute_dump
      return unless @dump_mode
      tcpdump = TcpDump.new(@ping_from && @ping_to, @ping_from, @ping_to)
      @dump_result = tcpdump.test(@ifaces)
      @dump_result.each do |(iface, result)|
        if result[0] && result[2]
          @mark[iface] = '*'
        elsif result[0]
          @mark[iface] = '>'
        elsif result[2]
          @mark[iface] = '<'
        end
      end
    end

    def show_all
      show_ovsvs
      puts '-' * 80
      show_linbr
      puts '-' * 80
      show_netns
      @dotwriter.finish(PNG_FILENAME) if @dotwriter
      @dotwriter = nil
    end

    private
    def show_iface_common(name, inet, patch, tag='', ns='')
      puts "    [#{@mark[name]||' '}] #{name}#{tag}#{patch}\t" +
        "#{inet.join(',')}\t#{ns}"
    end

    def show_iface(iface)
      patch = iface[:peer] ? " <-> #{iface[:peer]}" : ''
      show_iface_common(iface[:name], iface[:inet], patch)
    end

    def show_ovsvs
      @ovsvs.to_hash[:bridges].each do |br|
        puts "OVS Bridge #{br[:name]}:"
        @dotwriter.br_begin(br[:name], 'OVS ')

        br[:ports].each do |port|
          name = port[:name]
          iface = @ifaces[name] || {}
          inet = iface[:inet] || []
          tag = port[:tag] ? ' (tag=' + port[:tag] + ')' : ''
          peer = port[:peer] || iface[:peer]
          remote = port[:remote_ip] ?
            " #{port[:local_ip] || ''} => #{port[:remote_ip]}" : ''
          patch = peer ? ' <-> ' + peer : remote
          ns = iface[:ns] == :root ? '' : iface[:ns]

          show_iface_common(name, inet, patch, tag, ns)
          @dotwriter.br_iface(name, @mark[name], @dump_result[name],
                             inet, tag, peer, remote)
          @done[name] = true
        end
        @dotwriter.br_end
      end
    end

    def show_linbr
      @linbr.to_hash.each do |name, br|
        puts "Bridge #{name}"
        @dotwriter.br_begin(name, '')
        br[:interfaces].each do |ifname|
          iface = @ifaces[ifname]
          @dotwriter.br_iface(ifname, @mark[ifname], @dump_result[ifname],
                              iface[:inet], iface[:tag], iface[:peer])
          show_iface iface
          @done[ifname] = true
        end
        @dotwriter.br_end
      end
    end

    def show_netns
      @netns.to_hash.each do |name, ifaces|
        puts "Namespace #{name}"
        @dotwriter.ns_begin(name)
        ifaces.each do |iface|
          ifname = iface[:name]
          if ifname != 'lo' and !iface[:inet].empty?
            if @done[ifname]
              @dotwriter.ns_br_iface(ifname)
            else
              @dotwriter.ns_iface(ifname, @mark[ifname], @dump_result[ifname],
                                  iface[:inet], iface[:tag], iface[:peer])
            end
          end
          show_iface iface unless @done[iface[:name]]
          @done[iface[:name]] = true
        end
        @dotwriter.ns_end
      end
    end

  end
end
